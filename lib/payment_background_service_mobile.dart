import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'payment_announcement_service.dart';
import 'payment_alert_deduplicator.dart';
import 'payment_detection_service.dart';
import 'payment_event.dart';
import 'online_payment_history_service.dart';
import 'sms_background_receiver.dart';

StreamSubscription<Map<String, dynamic>?>? _paymentEventSubscription;
StreamSubscription<PaymentEvent>? _paymentForwardSubscription;

final FlutterLocalNotificationsPlugin _backgroundAlertPlugin =
    FlutterLocalNotificationsPlugin();
bool _alertPluginReady = false;
final PaymentAlertDeduplicator _backgroundAlertDeduplicator =
    PaymentAlertDeduplicator();

Future<void> syncExpectedPaymentBill(double? amount) async {
  final service = FlutterBackgroundService();
  if (amount == null) {
    service.invoke('clear_expected_payment_bill');
    return;
  }
  if (!amount.isFinite || amount <= 0) {
    debugPrint('⚠️ Ignoring invalid expected payment bill amount: $amount');
    return;
  }
  service.invoke('sync_expected_payment_bill', {'amount': amount});
}

Future<void> syncRecordedBillPayment(double amount) async {
  if (!amount.isFinite || amount <= 0) {
    debugPrint('⚠️ Ignoring invalid recorded bill payment amount: $amount');
    return;
  }
  FlutterBackgroundService().invoke('sync_recorded_bill_payment', {
    'amount': amount,
  });
}

Future<void> restartBackgroundPaymentDetection() async {
  FlutterBackgroundService().invoke('restart_payment_detection');
}

Future<void> refreshPaymentDetectionDedupState() async {
  FlutterBackgroundService().invoke('refresh_payment_dedup_state');
}

void _listenForBackgroundPayments(FlutterBackgroundService service) {
  _paymentEventSubscription?.cancel();
  _paymentEventSubscription = service.on('payment_detected').listen((payload) {
    if (payload == null) return;
    try {
      final eventPayload = Map<String, dynamic>.from(payload);
      final historyHandled = eventPayload.remove('history_handled') == true;
      PaymentDetectionService().forwardPaymentEvent(
        PaymentEvent.fromJson(eventPayload),
        historyHandled: historyHandled,
      );
    } catch (error, stackTrace) {
      debugPrint('⚠️ Invalid background payment event: $error\n$stackTrace');
    }
  });
}


Future<void> _persistPaymentHistoryThenForward(
  ServiceInstance service,
  PaymentEvent event,
  PaymentDetectionService pds,
) async {
  var forwardedEvent = event;
  var historyHandled = false;
  try {
    forwardedEvent =
        await OnlinePaymentHistoryService.annotateKnownReferenceState(event);

    // An exact reference duplicate stays attached to the original history
    // row. A conflicting reference is already moved to CONFLICT_REVIEW by
    // annotateKnownReferenceState. Don't overwrite either state with the
    // second notification's pending status.
    if (!forwardedEvent.isDuplicate &&
        !forwardedEvent.hasReferenceConflict) {
      await OnlinePaymentHistoryService.recordIncomingPayment(forwardedEvent);
    }
    // Reconcile the replay cache against durable payment status. Pending
    // references get a six-hour review cooldown; confirmed/rejected references
    // keep the longer suppression window, including across service restarts.
    try {
      final savedHistory = await OnlinePaymentHistoryService.load();
      await PaymentDetectionService()
          .syncDedupWindowsFromPaymentHistory(savedHistory);
    } catch (syncError) {
      debugPrint('⚠️ Could not refresh payment review cooldowns: $syncError');
    }

    // Even when this exact reference is already present or conflicted, this
    // isolate has checked persistent history; don't repeat the same I/O in UI.
    historyHandled = true;
  } catch (error, stackTrace) {
    debugPrint('⚠️ Could not save background payment receipt: $error');
    debugPrint(stackTrace.toString());
  }

  // Carry durable reference state across isolates. This prevents a late
  // Truecaller/PhonePe/SMS replay from reopening confirmation after restart.
  if (forwardedEvent.hasReferenceConflict) {
    forwardedEvent = forwardedEvent.copyWith(
      hasReferenceConflict: true,
      isDuplicate: false,
      decision: PaymentDecision.likely,
      verificationStatus: PaymentVerificationStatus.unverified,
    );
  } else if (forwardedEvent.isDuplicate) {
    forwardedEvent = forwardedEvent.copyWith(
      isDuplicate: true,
      decision: PaymentDecision.likely,
      verificationStatus: PaymentVerificationStatus.unverified,
    );
  }
  // Persist the alert after history has classified this event, so a replay
  // marked duplicate by durable history never creates a fresh background alert.
  await _postBackgroundPaymentAlert(pds, forwardedEvent);
  final payload = forwardedEvent.toJson();
  payload['history_handled'] = historyHandled;
  service.invoke('payment_detected', payload);
}

// ───────────────────────── Background alert + outage tracking ───────────────

const String _kHeartbeatMs = 'pds_service_heartbeat_ms';
const String _kOutageNotice = 'pds_service_outage_notice';
const Duration _heartbeatEvery = Duration(minutes: 5);
const Duration _outageThreshold = Duration(minutes: 20);

Future<void> _ensureAlertPlugin() async {
  if (_alertPluginReady) return;
  await _backgroundAlertPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  _alertPluginReady = true;
}

String _clock(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
}

/// The long-lived isolate must alert even when DashboardPage is not mounted.
/// A late recovered event always gets an audible OS alert; live events rely on
/// TTS when it is enabled and use a sounding notification when voice is off.
Future<void> _postBackgroundPaymentAlert(
  PaymentDetectionService pds,
  PaymentEvent event,
) async {
  if (!Platform.isAndroid || event.isDuplicate || event.isFailed) return;
  if (_backgroundAlertDeduplicator.shouldSuppress(event)) return;

  try {
    final lateAt = pds.originalTimeIfLate(event.id);
    final isDebit =
        event.direction == PaymentTransactionDirection.outgoingDebit;
    final isCredit =
        event.direction == PaymentTransactionDirection.incomingCredit;
    final merchantVerifiedCredit =
        isCredit && event.isMerchantConfirmed;
    final needsVerify = isCredit && !merchantVerifiedCredit;
    final conflict = event.hasReferenceConflict;

    final title = isDebit
        ? 'Debit detected'
        : conflict
        ? 'Payment review required'
        : merchantVerifiedCredit
        ? 'Payment received'
        : 'Payment detected — please verify';
    final amountText = event.amount == event.amount.truncateToDouble()
        ? event.amount.toStringAsFixed(0)
        : event.amount.toStringAsFixed(2);
    var body = '₹$amountText '
        '${isDebit ? 'debited' : 'credited'} via ${event.appDisplayName}';
    if (lateAt != null) {
      body += ' — notification received at ${_clock(lateAt)} while '
          'detection was stopped. Check your bank/UPI app.';
    } else if (conflict) {
      body += ' — transaction details conflict; check your bank history.';
    } else if (needsVerify) {
      body += ' — verify before recording.';
    }

    final audible = lateAt != null ||
        !PdsConfig.isVoiceEnabled ||
        conflict;
    final channelId = audible
        ? 'payment_detection_alerts_audible'
        : 'payment_detection_alerts_silent';
    final channelName = audible ? 'Payment Alerts' : 'Payment Alerts (Silent)';

    await _ensureAlertPlugin();
    final android = _backgroundAlertPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Local payment-detection alerts from Retail Mind.',
        importance: Importance.high,
        playSound: audible,
        enableVibration: audible,
        showBadge: false,
      ),
    );
    await _backgroundAlertPlugin.show(
      event.id.hashCode & 0x7fffffff,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Local payment-detection alerts from Retail Mind.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: audible,
          enableVibration: audible,
          showWhen: true,
          when: (lateAt ?? DateTime.now()).millisecondsSinceEpoch,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: 'realtime',
    );
    debugPrint(
      '🔔 Background payment alert posted (late=${lateAt != null}, audible=$audible)',
    );
  } catch (error, stackTrace) {
    debugPrint('⚠️ Background payment alert failed: $error\n$stackTrace');
  }
}

/// Compare the last five-minute heartbeat to startup time. A long gap means
/// the Android/OEM stopped the service; retain a one-shot notice for Dashboard.
Future<void> _recordServiceStartAndOutage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final previousHeartbeat = prefs.getInt(_kHeartbeatMs);
    final now = DateTime.now();
    if (previousHeartbeat != null) {
      final from = DateTime.fromMillisecondsSinceEpoch(previousHeartbeat);
      if (now.difference(from) > _outageThreshold) {
        await prefs.setString(
          _kOutageNotice,
          '${from.millisecondsSinceEpoch}|${now.millisecondsSinceEpoch}',
        );
        debugPrint(
          '⚠️ Payment detection service outage: '
          '${now.difference(from).inMinutes} minutes',
        );
      }
    }
    await prefs.setInt(_kHeartbeatMs, now.millisecondsSinceEpoch);
  } catch (error) {
    debugPrint('⚠️ Could not record payment service startup: $error');
  }
}

void _startServiceHeartbeat(ServiceInstance service) {
  final timer = Timer.periodic(_heartbeatEvery, (_) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kHeartbeatMs, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  });
  service.on('stop').listen((_) => timer.cancel());
}

/// Returns and consumes the outage interval once, for the next visible Dashboard.
Future<(DateTime, DateTime)?> takeServiceOutageNotice() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(_kOutageNotice);
    if (raw == null) return null;
    await prefs.remove(_kOutageNotice);
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final fromMillis = int.tryParse(parts[0]);
    final toMillis = int.tryParse(parts[1]);
    if (fromMillis == null || toMillis == null) return null;
    return (
      DateTime.fromMillisecondsSinceEpoch(fromMillis),
      DateTime.fromMillisecondsSinceEpoch(toMillis),
    );
  } catch (_) {
    return null;
  }
}

Future<void> _ensurePaymentNotificationChannel() async {
  if (!Platform.isAndroid) return;
  final plugin = FlutterLocalNotificationsPlugin();
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return;
  const channel = AndroidNotificationChannel(
    'payment_detection_channel',
    'Payment Detection',
    description: 'Foreground service notification for payment detection.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );
  await android.createNotificationChannel(channel);
}

@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  var hasNotificationPermission = true;
  try {
    final status = await Permission.notification.status;
    hasNotificationPermission = status.isGranted;
  } catch (_) {
    hasNotificationPermission = false;
  }

  if (service is AndroidServiceInstance && hasNotificationPermission) {
    service.setForegroundNotificationInfo(
      title: "Retail Mind",
      content: "Listening for payments...",
    );
  }

  try {
    try {
      await PaymentAnnouncementService().init(
        config: const AnnouncementConfig(volume: 1.0),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '⚠️ Background announcement engine initialization failed: '
        '$error\n$stackTrace',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences caches are isolate-local. Refresh from disk before
    // initializing voice and payment detection so recent UI settings apply.
    await prefs.reload();
    final langCode = prefs.getString('payment_sound_lang') ?? 'en-US';

    final pds = PaymentDetectionService();
    // The foreground app and service isolates have separate voice settings.
    PdsConfig.isVoiceEnabled = prefs.getBool('payment_sound_enabled') ?? true;
    pds.setLanguage(PaymentDetectionService.mapLanguage(langCode));

    pds.onSpeak = (text) async {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('payment_sound_lang') ?? 'en-US';
      PaymentAnnouncementService().speakSimple(text, lang);
    };

    await _paymentForwardSubscription?.cancel();
    _paymentForwardSubscription = pds.onPaymentDetected.listen((event) {
      // Preserve ordering: finish the local history write (or log its failure)
      // before forwarding the event to the UI isolate. A background shutdown
      // must not silently lose the history write after the event was forwarded.
      unawaited(_persistPaymentHistoryThenForward(service, event, pds));
    });

    service.on('sync_expected_payment_bill').listen((event) {
      final amount = (event?['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        debugPrint('⚠️ Ignoring invalid expected bill amount: $amount');
        return;
      }
      pds.setBillExpected(amount);
    });
    service.on('clear_expected_payment_bill').listen((event) {
      pds.clearBill();
    });
    service.on('sync_recorded_bill_payment').listen((event) {
      final amount = (event?['amount'] as num?)?.toDouble();
      if (amount == null || !amount.isFinite || amount <= 0) {
        debugPrint('⚠️ Ignoring invalid synced bill payment amount: $amount');
        return;
      }
      pds.recordBillPayment(amount);
    });
    service.on('sync_payment_sound_enabled').listen((event) {
      final enabled = event?['enabled'] as bool?;
      if (enabled == null) return;
      PdsConfig.isVoiceEnabled = enabled;
      debugPrint(
        enabled
            ? '🔊 Background payment announcements enabled'
            : '🔇 Background payment announcements disabled',
      );
    });

    // Subscribe before startup: the Dashboard can signal that permissions
    // were granted while the service isolate is still initializing. Queue
    // such a signal rather than losing it before the listener exists.
    var pdsReady = false;
    var restartRequestedBeforeReady = false;
    var restartInProgress = false;
    service.on('restart_payment_detection').listen((event) async {
      if (!pdsReady) {
        restartRequestedBeforeReady = true;
        debugPrint(
          '⏳ Payment detection restart queued until listener startup completes',
        );
        return;
      }
      if (restartInProgress) {
        debugPrint(
          '⏳ Background isolate: restart already in progress; ignoring duplicate signal',
        );
        return;
      }

      restartInProgress = true;
      try {
        await pds.ensureChannelsRunning();
        debugPrint('✅ Background payment channels are active');
      } catch (e) {
        debugPrint('⚠️ Background isolate: restart failed: $e');
      } finally {
        restartInProgress = false;
      }
    });

    service.on('refresh_payment_dedup_state').listen((event) async {
      try {
        final savedHistory = await OnlinePaymentHistoryService.load();
        await pds.syncDedupWindowsFromPaymentHistory(savedHistory);
      } catch (error) {
        debugPrint('⚠️ Could not refresh payment dedup state: $error');
      }
    });

    List<Map<String, dynamic>> persistedPaymentHistory = <Map<String, dynamic>>[];
    try {
      persistedPaymentHistory = await OnlinePaymentHistoryService.load();
    } catch (error) {
      // App may not have a signed-in owner profile during early startup.
      debugPrint('ℹ️ Payment history cache not available during service startup: $error');
    }
    await _recordServiceStartAndOutage();
    await pds.start(persistedPaymentHistory: persistedPaymentHistory);
    pdsReady = true;
    _startServiceHeartbeat(service);
    if (restartRequestedBeforeReady) {
      restartRequestedBeforeReady = false;
      await pds.ensureChannelsRunning();
      debugPrint('✅ Applied queued payment detection restart');
    }

    // Telephony's background callback persists SMS into SharedPreferences.
    // Drain that queue from the long-lived service isolate so messages received
    // while the UI isolate is paused/killed are not left undetected forever.
    var smsQueueDrainInProgress = false;
    Future<void> drainPendingBackgroundSms() async {
      if (smsQueueDrainInProgress) return;
      smsQueueDrainInProgress = true;
      try {
        final pendingMessages = await getPendingBackgroundSms();
        for (final message in pendingMessages) {
          final sender = (message['sender'] ?? '').trim();
          final body = (message['body'] ?? '').trim();
          if (sender.isEmpty || body.isEmpty) continue;
          final receivedAtMillis = int.tryParse(message['time'] ?? '');
          pds.handleSms(
            sender,
            body,
            receivedAt: receivedAtMillis == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(receivedAtMillis),
          );
        }
        if (pendingMessages.isNotEmpty) {
          debugPrint(
            '📩 Background payment service processed '
            '${pendingMessages.length} queued SMS message(s)',
          );
        }
      } catch (error, stackTrace) {
        debugPrint('⚠️ Could not drain queued SMS: $error\n$stackTrace');
      } finally {
        smsQueueDrainInProgress = false;
      }
    }

    // Process backlog immediately, then poll the durable SMS queue at a low
    // frequency. This is separate from the removed one-second generic service
    // update loop and avoids overlapping SharedPreferences reads.
    await drainPendingBackgroundSms();
    final smsQueueDrainTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(drainPendingBackgroundSms()),
    );
    service.on('stop').listen((_) => smsQueueDrainTimer.cancel());

    try {
      final accessibilityEnabled =
          await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      debugPrint(
        accessibilityEnabled
            ? '✅ Accessibility service permission is enabled'
            : '⚠️ Accessibility service permission is NOT enabled',
      );
    } catch (e) {
      debugPrint('⚠️ Accessibility status check failed: $e');
    }

    // FIX (critical, part 2): lets the UI isolate promote this service to a
    // real foreground service the moment POST_NOTIFICATIONS is granted,
    // instead of requiring a full app reinstall to stop being killed by
    // Android. Without this, a service that started in background-only
    // mode on first launch (before permission was granted) stays
    // non-foreground — and therefore killable — forever.
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        debugPrint('⬆️ Background isolate: promoting to foreground service');
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    debugPrint('✅ Background payment services initialized');
  } catch (e) {
    debugPrint('⚠️ Background service init error: $e');
    return false;
  }

  // The old one-second generic service.update loop remains removed: only the
  // durable background-SMS queue is checked every five seconds as a fallback.

  return true;
}

Future<void> initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();

    // The background-service plugin requires a custom channel to exist before
    // configure()/startForeground() when notificationChannelId is supplied.
    await _ensurePaymentNotificationChannel();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        // Android permits foreground services without notification permission
        // on Android 13+; the service notification remains visible in system
        // task manager even when it is hidden from the notification drawer.
        isForegroundMode: true,
        notificationChannelId: 'payment_detection_channel',
        initialNotificationTitle: 'Retail Mind',
        initialNotificationContent: 'Listening for payments...',
        foregroundServiceNotificationId: 888,
        // Android 14+ / target SDK 34+ requires an explicit FGS type.
        // Payment-notification monitoring is not data transfer, location, media,
        // or another predefined category, so use the documented specialUse type.
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onStart,
      ),
    );

    _listenForBackgroundPayments(service);
    await service.startService();
    debugPrint('✅ Background service started successfully (foreground=true)');
  } catch (e) {
    debugPrint('⚠️ Failed to start background service: $e');
    await _initializeFallback();
  }
}

Future<void> _initializeFallback() async {
  try {
    await PaymentAnnouncementService().init(
      config: const AnnouncementConfig(volume: 1.0),
    );

    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences caches are isolate-local. Refresh from disk before
    // initializing voice and payment detection so recent UI settings apply.
    await prefs.reload();
    final langCode = prefs.getString('payment_sound_lang') ?? 'en-US';

    final pds = PaymentDetectionService();
    // Keep announcements enabled in fallback mode as well.
    PdsConfig.isVoiceEnabled = prefs.getBool('payment_sound_enabled') ?? true;
    pds.setLanguage(PaymentDetectionService.mapLanguage(langCode));

    pds.onSpeak = (text) async {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('payment_sound_lang') ?? 'en-US';
      PaymentAnnouncementService().speakSimple(text, lang);
    };

    List<Map<String, dynamic>> persistedPaymentHistory = <Map<String, dynamic>>[];
    try {
      persistedPaymentHistory = await OnlinePaymentHistoryService.load();
    } catch (error) {
      debugPrint('ℹ️ Payment history cache not available in fallback mode: $error');
    }
    await pds.start(persistedPaymentHistory: persistedPaymentHistory);
    debugPrint('✅ Payment services initialized (fallback mode)');
  } catch (e) {
    debugPrint('⚠️ Failed fallback initialization: $e');
  }
}
