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
import 'payment_detection_service.dart';
import 'payment_event.dart';
import 'online_payment_history_service.dart';
import 'sms_background_receiver.dart';

StreamSubscription<Map<String, dynamic>?>? _paymentEventSubscription;
StreamSubscription<PaymentEvent>? _paymentForwardSubscription;

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
  final payload = forwardedEvent.toJson();
  payload['history_handled'] = historyHandled;
  service.invoke('payment_detected', payload);
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
      unawaited(_persistPaymentHistoryThenForward(service, event));
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
    await pds.start(persistedPaymentHistory: persistedPaymentHistory);
    pdsReady = true;
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
          pds.handleSms(sender, body);
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
