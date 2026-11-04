package notification.listener.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.Manifest;
import android.content.pm.PackageManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.media.AudioAttributes;
import android.media.RingtoneManager;
import android.os.Build;
import android.os.PowerManager;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.util.Log;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Spoken fallback for payment notifications that arrive while no Flutter
 * notification-stream subscriber is running. The normal Dart detector gets
 * the first chance to handle every event; this fallback runs only while the
 * durable native event is still unacknowledged.
 *
 * This deliberately announces what the notification reports, not verified
 * settlement. Retail Mind's normal detector still processes the durable event
 * later for history/review, without repeating its voice alert.
 */
final class NativePaymentAnnouncementFallback {
    private static final String TAG = "RetailMindNativeSpeech";
    private static final long FALLBACK_DELAY_MS = 2500L;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final Object LOCK = new Object();
    private static final Set<String> SCHEDULED =
            Collections.synchronizedSet(new HashSet<String>());
    private static final List<SpeakRequest> WAITING = new ArrayList<SpeakRequest>();
    private static final Map<String, SpeakRequest> IN_FLIGHT =
            new HashMap<String, SpeakRequest>();
    private static final Set<String> RETRIED =
            Collections.synchronizedSet(new HashSet<String>());

    private static TextToSpeech tts;
    private static boolean ttsInitializing;
    private static boolean ttsReady;
    private static PowerManager.WakeLock announcementWakeLock;

    private static final Set<String> PAYMENT_PACKAGES = new HashSet<String>(Arrays.asList(
            "com.google.android.apps.nbu.paisa.user",
            "com.google.android.apps.nbu.paisa.merchant",
            "net.one97.paytm",
            "com.paytm.business",
            "com.phonepe.app",
            "com.phonepe.app.business",
            "com.phonepe.app.merchant",
            "com.phonepe.business",
            "in.amazon.mShop.android.shopping",
            "in.amazon.seller",
            "in.org.npci.upiapp",
            "com.dreamplug.androidapp",
            "com.hdfcbank.payzapp",
            "com.pockets.hdfc",
            "com.icicibank.imobile",
            "com.sbi.imobile",
            "com.axis.mobile",
            "com.hdfcbank.smartbuy",
            "com.indusind.mobilebanking",
            "com.yes.mobile",
            "com.baroda.mpassbook",
            "com.canarabank.mobility",
            "com.freecharge.android",
            "com.freecharge.merchant",
            "com.mobikwik_new",
            "com.jupiter.app",
            "com.epifi.fi",
            "com.bharatpe.app",
            "com.bharatpe.merchant",
            "com.slicepay",
            "com.kotak.mobile.banking",
            "com.snapwork.pnb",
            "com.infrasofttech.unionbankofindia",
            "com.idfcfirstbank.optimus",
            "com.rblbank.mobank",
            "com.abcl.mobibank",
            "com.enstage.wibmo.hdfc",
            "com.csam.icici.bank.imobile",
            "com.snapwork.IDBI",
            "com.truecaller"
    ));

    private static final Pattern AMOUNT_PATTERN = Pattern.compile(
            "(?:₹\\s*|\\bINR\\s*|\\bRs\\.?\\s*)([0-9][0-9,]*(?:\\.[0-9]{1,2})?)",
            Pattern.CASE_INSENSITIVE);
    // Only cross-source suppress when the notification exposes a transaction reference.
    // Never deduplicate native announcements by amount alone: two customers can pay
    // the same amount at nearly the same time.
    private static final Pattern REFERENCE_PATTERN = Pattern.compile(
            "(?:\\b(?:utr|rrn|ref(?:erence)?|txn|transaction\\s*(?:id|no\\.?|number)|upi\\s*(?:ref(?:erence)?|txn|transaction))\\b\\s*(?:(?:no\\.?|number|id)\\b\\s*)?[:#=\\-]?\\s*)([A-Z0-9]{8,30})",
            Pattern.CASE_INSENSITIVE);

    private static final Pattern CREDIT_PATTERN = Pattern.compile(
            "\\b(?:credited|received|deposited|cashback received|money received|credit to your account)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern DEBIT_PATTERN = Pattern.compile(
            "\\b(?:debited|withdrawn|withdrawal|spent|you sent|sent to|paid to|purchase at|deducted|transferred to)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern NOT_FINAL_PATTERN = Pattern.compile(
            "\\b(?:otp|one.time.password|verification code|collect request|payment request|request received|pending|processing|initiated|failed|declined|reversed|refund|will be credited|to be credited)\\b",
            Pattern.CASE_INSENSITIVE);

    // Own-account cues, mirrored from lib/payment_direction_speech.dart. A bank
    // SMS can say "debited from A/c ... credited to <beneficiary>": the cue on
    // the user's own account decides, so a debit is never spoken as a credit.
    private static final Pattern OWN_DEBIT_PATTERN = Pattern.compile(
            "\\b(?:debited|deducted|withdrawn)\\b[^.]{0,50}?\\bfrom\\s+(?:your\\b|a/c|acct|account)",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern OWN_CREDIT_PATTERN = Pattern.compile(
            "\\bcredited\\b[^.]{0,30}?\\b(?:to|in)\\s+your\\b",
            Pattern.CASE_INSENSITIVE);

    private NativePaymentAnnouncementFallback() {}

    static void schedule(Context context, String eventKey) {
        if (eventKey == null || eventKey.trim().isEmpty() || !SCHEDULED.add(eventKey)) return;
        final Context appContext = context.getApplicationContext();
        MAIN.postDelayed(() -> {
            Map<String, Object> event = NotificationRelayReceiver.getPendingEvent(appContext, eventKey);
            if (event == null || Boolean.TRUE.equals(event.get("nativeAnnouncementHandled"))) {
                SCHEDULED.remove(eventKey);
                return;
            }

            String packageName = value(event.get("packageName"));
            if (!PAYMENT_PACKAGES.contains(packageName)) {
                SCHEDULED.remove(eventKey);
                return;
            }

            SharedPreferences prefs = appContext.getSharedPreferences(
                    "FlutterSharedPreferences", Context.MODE_PRIVATE);
            if (!prefs.getBoolean("flutter.payment_sound_enabled", true)) {
                SCHEDULED.remove(eventKey);
                return;
            }

            Announcement announcement = buildAnnouncement(event, prefs.getString(
                    "flutter.payment_sound_lang", "en-US"));
            if (announcement == null) {
                SCHEDULED.remove(eventKey);
                return;
            }

            // Acquire a short wake lock only after this notification passed amount/status/direction parsing.
            holdCpuForAnnouncement(appContext);
            queueSpeak(appContext, eventKey, announcement, event);
        }, FALLBACK_DELAY_MS);
    }

    private static void holdCpuForAnnouncement(Context context) {
        try {
            synchronized (LOCK) {
                if (announcementWakeLock == null) {
                    PowerManager manager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
                    if (manager == null) return;
                    announcementWakeLock = manager.newWakeLock(
                            PowerManager.PARTIAL_WAKE_LOCK, "retailmind:payment-announcement");
                    announcementWakeLock.setReferenceCounted(false);
                }
                if (announcementWakeLock.isHeld()) announcementWakeLock.release();
                announcementWakeLock.acquire(30_000L);
            }
        } catch (RuntimeException error) {
            Log.w(TAG, "Could not hold CPU awake for payment speech", error);
        }
    }

    private static String value(Object raw) {
        return raw == null ? "" : String.valueOf(raw);
    }

    private static Announcement buildAnnouncement(Map<String, Object> event, String languageTag) {
        String raw = (value(event.get("title")) + " " + value(event.get("content")) + " "
                + value(event.get("bigText")) + " " + value(event.get("subText")) + " "
                + value(event.get("summaryText")) + " " + value(event.get("textLines"))).trim();
        if (raw.isEmpty() || NOT_FINAL_PATTERN.matcher(raw).find()) return null;

        Matcher matcher = AMOUNT_PATTERN.matcher(raw);
        if (!matcher.find()) return null;
        String amount;
        double numericAmount;
        try {
            BigDecimal parsedAmount = new BigDecimal(matcher.group(1).replace(",", ""))
                    .stripTrailingZeros();
            amount = parsedAmount.toPlainString();
            numericAmount = parsedAmount.doubleValue();
        } catch (NumberFormatException error) {
            return null;
        }

        boolean credit = CREDIT_PATTERN.matcher(raw).find();
        boolean debit = DEBIT_PATTERN.matcher(raw).find();
        // No direction cue at all (offers, reminders): stay silent.
        if (!credit && !debit) return null;
        String direction;
        if (credit != debit) {
            direction = credit ? "credit" : "debit";
        } else {
            // Both cues in one message: let the user's own-account cue decide.
            boolean ownDebit = OWN_DEBIT_PATTERN.matcher(raw).find();
            boolean ownCredit = OWN_CREDIT_PATTERN.matcher(raw).find();
            if (ownDebit && !ownCredit) direction = "debit";
            else if (ownCredit && !ownDebit) direction = "credit";
            else direction = "unknown"; // say so; never guess "received"
        }

        String lang = languageTag == null ? "en" : languageTag.split("[-_]", 2)[0].toLowerCase(Locale.ROOT);
        String phrase;
        String english;
        if ("unknown".equals(direction)) {
            phrase = neutralMessage(lang, amount);
            english = neutralMessage("en", amount);
        } else {
            boolean isCredit = "credit".equals(direction);
            phrase = localizedMessage(lang, amount, isCredit);
            english = isCredit
                    ? "Payment notification reports " + amount + " rupees received. Please verify in your bank or UPI app."
                    : "Payment notification reports " + amount + " rupees debited. Please verify in your bank or UPI app.";
        }
        Matcher referenceMatcher = REFERENCE_PATTERN.matcher(raw);
        String referenceId = referenceMatcher.find()
                ? referenceMatcher.group(1).replaceAll("[^A-Z0-9]", "").toUpperCase(Locale.ROOT)
                : null;
        return new Announcement(
                phrase, english, lang, referenceId, numericAmount,
                direction, raw);
    }

    /** Direction-neutral alert. Mirrors lib/payment_direction_speech.dart. */
    private static String neutralMessage(String lang, String amount) {
        switch (lang) {
            case "hi": return amount + " रुपये का भुगतान संदेश। जमा हुआ या कटा, ऐप में जांचें।";
            case "ta": return amount + " ரூபாய் பணப் பரிவர்த்தனை அறிவிப்பு. வரவா அல்லது பற்றா என்று சரிபார்க்கவும்.";
            case "te": return amount + " రూపాయల లావాదేవీ నోటిఫికేషన్. జమ అయిందో డెబిట్ అయిందో చెక్ చేయండి.";
            case "kn": return amount + " ರೂಪಾಯಿ ವಹಿವಾಟು ಸೂಚನೆ. ಜಮಾ ಆಗಿದೆಯೇ ಅಥವಾ ಡೆಬಿಟ್ ಆಗಿದೆಯೇ ಎಂದು ಪರಿಶೀಲಿಸಿ.";
            case "mr": return amount + " रुपये व्यवहाराची सूचना. जमा झाले की वजा झाले ते तपासा.";
            case "gu": return amount + " રૂપિયા વ્યવહારની સૂચના. જમા થયું કે કપાયું તે ચકાસો.";
            case "bn": return amount + " টাকা লেনদেনের বিজ্ঞপ্তি। জমা হয়েছে নাকি কাটা হয়েছে যাচাই করুন।";
            case "pa": return amount + " ਰੁਪਏ ਲੈਣ-ਦੇਣ ਦੀ ਸੂਚਨਾ। ਜਮ੍ਹਾਂ ਹੋਈ ਜਾਂ ਕੱਟੀ ਗਈ, ਜਾਂਚ ਕਰੋ।";
            case "ml": return amount + " രൂപ ഇടപാട് അറിയിപ്പ്. ക്രെഡിറ്റ് ആണോ ഡെബിറ്റ് ആണോ എന്ന് പരിശോധിക്കുക.";
            default:
                return "Payment alert of " + amount + " rupees. Could not tell if it was credited or debited. Please check.";
        }
    }

    private static String localizedMessage(String lang, String amount, boolean credit) {
        switch (lang) {
            case "hi":
                return credit
                        ? "भुगतान सूचना: " + amount + " रुपये खाते में जमा होने की सूचना है। बैंक या UPI ऐप में जांचें।"
                        : "भुगतान सूचना: " + amount + " रुपये खाते से डेबिट होने की सूचना है। बैंक या UPI ऐप में जांचें।";
            case "te":
                return credit
                        ? "చెల్లింపు నోటిఫికేషన్: " + amount + " రూపాయలు జమ అయినట్లు ఉంది. బ్యాంక్ లేదా UPI యాప్‌లో నిర్ధారించండి."
                        : "చెల్లింపు నోటిఫికేషన్: " + amount + " రూపాయలు డెబిట్ అయినట్లు ఉంది. బ్యాంక్ లేదా UPI యాప్‌లో నిర్ధారించండి.";
            case "ta":
                return credit
                        ? "பணம் வரவு அறிவிப்பு: " + amount + " ரூபாய் வரவு செய்யப்பட்டதாக தெரிகிறது. வங்கி அல்லது UPI செயலியில் சரிபார்க்கவும்."
                        : "பணம் செலுத்தல் அறிவிப்பு: " + amount + " ரூபாய் பற்று செய்யப்பட்டதாக தெரிகிறது. வங்கி அல்லது UPI செயலியில் சரிபார்க்கவும்.";
            case "kn":
                return credit
                        ? "ಪಾವತಿ ಸೂಚನೆ: " + amount + " ರೂಪಾಯಿ ಜಮೆಯಾದಂತೆ ಕಾಣುತ್ತದೆ. ಬ್ಯಾಂಕ್ ಅಥವಾ UPI ಆ್ಯಪ್‌ನಲ್ಲಿ ಪರಿಶೀಲಿಸಿ."
                        : "ಪಾವತಿ ಸೂಚನೆ: " + amount + " ರೂಪಾಯಿ ಡೆಬಿಟ್ ಆದಂತೆ ಕಾಣುತ್ತದೆ. ಬ್ಯಾಂಕ್ ಅಥವಾ UPI ಆ್ಯಪ್‌ನಲ್ಲಿ ಪರಿಶೀಲಿಸಿ.";
            case "ml":
                return credit
                        ? "പേയ്മെന്റ് അറിയിപ്പ്: " + amount + " രൂപ ലഭിച്ചതായി കാണിക്കുന്നു. ബാങ്ക് അല്ലെങ്കിൽ UPI ആപ്പിൽ പരിശോധിക്കുക."
                        : "പേയ്മെന്റ് അറിയിപ്പ്: " + amount + " രൂപ ഡെബിറ്റ് ആയതായി കാണിക്കുന്നു. ബാങ്ക് അല്ലെങ്കിൽ UPI ആപ്പിൽ പരിശോധിക്കുക.";
            case "mr":
                return credit
                        ? "पेमेंट सूचना: " + amount + " रुपये जमा झाल्याचे दिसते. बँक किंवा UPI ॲपमध्ये तपासा."
                        : "पेमेंट सूचना: " + amount + " रुपये डेबिट झाल्याचे दिसते. बँक किंवा UPI ॲपमध्ये तपासा.";
            case "bn":
                return credit
                        ? "পেমেন্ট বিজ্ঞপ্তি: " + amount + " টাকা জমা হয়েছে বলে মনে হচ্ছে। ব্যাংক বা UPI অ্যাপে যাচাই করুন।"
                        : "পেমেন্ট বিজ্ঞপ্তি: " + amount + " টাকা ডেবিট হয়েছে বলে মনে হচ্ছে। ব্যাংক বা UPI অ্যাপে যাচাই করুন।";
            case "gu":
                return credit
                        ? "ચુકવણી સૂચના: " + amount + " રૂપિયા જમા થયાની સૂચના છે. બેંક અથવા UPI એપમાં ચકાસો."
                        : "ચુકવણી સૂચના: " + amount + " રૂપિયા ડેબિટ થયાની સૂચના છે. બેંક અથવા UPI એપમાં ચકાસો.";
            case "pa":
                return credit
                        ? "ਭੁਗਤਾਨ ਸੂਚਨਾ: " + amount + " ਰੁਪਏ ਜਮ੍ਹਾਂ ਹੋਣ ਦੀ ਸੂਚਨਾ ਹੈ। ਬੈਂਕ ਜਾਂ UPI ਐਪ ਵਿੱਚ ਜਾਂਚੋ।"
                        : "ਭੁਗਤਾਨ ਸੂਚਨਾ: " + amount + " ਰੁਪਏ ਡੈਬਿਟ ਹੋਣ ਦੀ ਸੂਚਨਾ ਹੈ। ਬੈਂਕ ਜਾਂ UPI ਐਪ ਵਿੱਚ ਜਾਂਚੋ।";
            default:
                return credit
                        ? "Payment notification reports " + amount + " rupees received. Please verify in your bank or UPI app."
                        : "Payment notification reports " + amount + " rupees debited. Please verify in your bank or UPI app.";
        }
    }

    private static void queueSpeak(Context context, String eventKey, Announcement announcement, Map<String, Object> event) {
        synchronized (LOCK) {
            WAITING.add(new SpeakRequest(context.getApplicationContext(), eventKey, announcement, event));
            if (ttsReady) {
                drainWaiting();
            } else if (!ttsInitializing) {
                ttsInitializing = true;
                tts = new TextToSpeech(context.getApplicationContext(), status -> {
                    synchronized (LOCK) {
                        ttsInitializing = false;
                        ttsReady = status == TextToSpeech.SUCCESS && tts != null;
                        if (ttsReady && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            // Speak as guidance, not media: audible over a playing
                            // song and on a locked screen.
                            tts.setAudioAttributes(new AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .build());
                        }
                        if (ttsReady) {
                            installProgressListener();
                        }
                        if (!ttsReady) {
                            for (SpeakRequest request : WAITING) SCHEDULED.remove(request.eventKey);
                            WAITING.clear();
                            Log.w(TAG, "Android TTS is unavailable; Flutter will process the queued payment event when available.");
                            return;
                        }
                        drainWaiting();
                    }
                });
            }
        }
    }

    private static void installProgressListener() {
        if (tts == null) return;
        tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
            @Override
            public void onStart(String utteranceId) {
                // The event remains claimed until onDone or onError.
            }

            @Override
            public void onDone(String utteranceId) {
                completeUtterance(utteranceId);
            }

            @Override
            public void onError(String utteranceId) {
                failUtterance(utteranceId, "tts_callback_error");
            }
        });
    }

    private static void completeUtterance(String utteranceId) {
        SpeakRequest request;
        synchronized (LOCK) {
            request = IN_FLIGHT.remove(utteranceId);
        }
        if (request == null) return;

        NotificationRelayReceiver.markNativeAnnouncementHandled(
                request.context, request.eventKey, true);
        RETRIED.remove(request.eventKey);
        SCHEDULED.remove(request.eventKey);
        releaseWakeLockIfIdle();
        Log.i(TAG, "Native payment speech completed.");
    }

    private static void failUtterance(String utteranceId, String reason) {
        SpeakRequest request;
        synchronized (LOCK) {
            request = IN_FLIGHT.remove(utteranceId);
        }
        if (request == null) return;
        handleRequestFailure(request, reason);
    }

    private static void handleRequestFailure(SpeakRequest request, String reason) {
        NotificationRelayReceiver.markNativeAnnouncementHandled(
                request.context, request.eventKey, false);
        AtomicPaymentAnnouncementCoordinator.releaseSourceIdentity(
                request.context, stableIdentity(request.eventKey));
        SCHEDULED.remove(request.eventKey);
        releaseWakeLockIfIdle();

        final boolean stillPending = NotificationRelayReceiver.isPendingEvent(
                request.context, request.eventKey);
        if (stillPending && RETRIED.add(request.eventKey)) {
            Log.w(TAG, "Native TTS failed (" + reason + "); scheduling one retry.");
            MAIN.postDelayed(
                    () -> schedule(request.context, request.eventKey),
                    1000L);
            return;
        }

        // If Flutter already acknowledged the event, its durable queue is no
        // longer available for replay. Post a separate sounding OS alert so a
        // TTS callback failure cannot make a payment notification disappear.
        if (postAudibleFallback(request, reason)) {
            Log.w(TAG, "Posted audible OS fallback after native TTS failure.");
        } else {
            Log.w(TAG, "Native TTS fallback failed; durable event remains unacknowledged.");
        }
    }

    private static boolean postAudibleFallback(SpeakRequest request, String reason) {
        try {
            Context context = request.context;
            NotificationManager manager = (NotificationManager)
                    context.getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager == null) return false;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                    !manager.areNotificationsEnabled()) {
                Log.w(TAG, "System notifications are disabled; retain the payment event.");
                return false;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                            != PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "POST_NOTIFICATIONS permission is not granted; retain the payment event.");
                return false;
            }

            final String channelId = "retailmind_native_payment_fallback";
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationChannel channel = new NotificationChannel(
                        channelId,
                        "Payment alerts",
                        NotificationManager.IMPORTANCE_HIGH);
                channel.setDescription(
                        "Audible fallback when payment announcement speech is unavailable.");
                channel.enableVibration(true);
                channel.setVibrationPattern(new long[]{0L, 250L, 150L, 250L});
                channel.setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                        new AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build());
                manager.createNotificationChannel(channel);
            }

            String amount = BigDecimal.valueOf(request.announcement.amountValue)
                    .stripTrailingZeros().toPlainString();
            boolean debit = "debit".equalsIgnoreCase(request.announcement.direction);
            String title = debit ? "Debit detected" : "Payment detected";
            String body = debit
                    ? "₹" + amount + " debited. Verify in your bank or UPI app."
                    : "₹" + amount + " credit reported. Verify in your bank or UPI app.";

            Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                    ? new Notification.Builder(context, channelId)
                    : new Notification.Builder(context);
            builder.setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setStyle(new Notification.BigTextStyle().bigText(body))
                    .setPriority(Notification.PRIORITY_HIGH)
                    .setAutoCancel(true);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setCategory(Notification.CATEGORY_MESSAGE);
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                builder.setDefaults(Notification.DEFAULT_ALL)
                        .setSound(RingtoneManager.getDefaultUri(
                                RingtoneManager.TYPE_NOTIFICATION))
                        .setVibrate(new long[]{0L, 250L, 150L, 250L});
            }

            int notificationId = request.eventKey.hashCode() & 0x7fffffff;
            manager.notify(notificationId, builder.build());

            // If the native event is still queued, this marker prevents Flutter
            // from producing a second speech/alert while it still writes history.
            NotificationRelayReceiver.markNativeAnnouncementHandled(
                    context, request.eventKey, true);
            RETRIED.remove(request.eventKey);
            return true;
        } catch (SecurityException error) {
            Log.w(TAG, "Notification permission denied for audible fallback", error);
            return false;
        } catch (RuntimeException error) {
            Log.e(TAG, "Unable to post audible payment fallback (" + reason + ")", error);
            return false;
        }
    }

    private static void releaseWakeLockIfIdle() {
        synchronized (LOCK) {
            if (!IN_FLIGHT.isEmpty() || !WAITING.isEmpty()) return;
            if (announcementWakeLock != null && announcementWakeLock.isHeld()) {
                try {
                    announcementWakeLock.release();
                } catch (RuntimeException error) {
                    Log.w(TAG, "Unable to release native announcement wake lock", error);
                }
            }
        }
    }

    private static void drainWaiting() {
        if (!ttsReady || tts == null) return;
        List<SpeakRequest> requests = new ArrayList<>(WAITING);
        WAITING.clear();
        for (SpeakRequest request : requests) {
            String utteranceId = null;
            try {
                if (!NotificationRelayReceiver.isPendingEvent(request.context, request.eventKey)) {
                    SCHEDULED.remove(request.eventKey);
                    continue;
                }
                Map<String, Object> claim = new java.util.HashMap<>();
                String packageName = value(request.event.get("packageName"));
                claim.put("amount", request.announcement.amountValue);
                claim.put("direction", request.announcement.direction);
                claim.put("referenceId", request.announcement.referenceId);
                claim.put("sourceEventKey", request.eventKey);
                claim.put("sourceIdentity", stableIdentity(request.eventKey));
                claim.put("sourceTimestamp", postedAt(request.eventKey));
                claim.put("timestamp", System.currentTimeMillis());
                claim.put("origin", "notification");
                claim.put("channel", "notification|" + packageName);
                claim.put("packageName", packageName);
                claim.put("payerName", extractPayer(request.announcement.rawText));
                claim.put("accountSuffix", extractAccount(request.announcement.rawText));
                claim.put("rawText", request.announcement.rawText);
                if (AtomicPaymentAnnouncementCoordinator.shouldSuppress(request.context, claim)) {
                    // Another Flutter/native worker already owns this announcement.
                    NotificationRelayReceiver.markNativeAnnouncementHandled(
                            request.context, request.eventKey, true);
                    SCHEDULED.remove(request.eventKey);
                    continue;
                }
                if (!NotificationRelayReceiver.markNativeAnnouncementHandled(
                        request.context, request.eventKey, true)) {
                    AtomicPaymentAnnouncementCoordinator.releaseSourceIdentity(
                            request.context, stableIdentity(request.eventKey));
                    SCHEDULED.remove(request.eventKey);
                    continue;
                }

                Locale locale = localeFor(request.announcement.language);
                int availability = tts.isLanguageAvailable(locale);
                String message = request.announcement.localized;
                if (availability < TextToSpeech.LANG_AVAILABLE) {
                    locale = new Locale("en", "IN");
                    int englishAvailability = tts.isLanguageAvailable(locale);
                    if (englishAvailability < TextToSpeech.LANG_AVAILABLE) {
                        locale = Locale.US;
                    }
                    message = request.announcement.english;
                }

                int languageResult = tts.setLanguage(locale);
                if (languageResult == TextToSpeech.LANG_MISSING_DATA ||
                        languageResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                    locale = Locale.US;
                    message = request.announcement.english;
                    languageResult = tts.setLanguage(locale);
                }
                if (languageResult == TextToSpeech.ERROR) {
                    throw new IllegalStateException("Android TTS rejected the selected language.");
                }

                utteranceId = "retailmind_" +
                        Integer.toHexString(request.eventKey.hashCode()) + "_" +
                        System.nanoTime();
                java.util.HashMap<String, String> params = new java.util.HashMap<>();
                params.put(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId);
                synchronized (LOCK) {
                    IN_FLIGHT.put(utteranceId, request);
                }

                final String scheduledUtteranceId = utteranceId;
                // A broken OEM TTS engine can fail to call either onDone or onError.
                // The watchdog releases the claim after a bounded wait.
                MAIN.postDelayed(
                        () -> failUtterance(scheduledUtteranceId, "tts_completion_timeout"),
                        45000L);

                int result = tts.speak(message, TextToSpeech.QUEUE_ADD, params);
                if (result == TextToSpeech.ERROR) {
                    failUtterance(utteranceId, "tts_speak_rejected");
                }
            } catch (RuntimeException error) {
                Log.e(TAG, "Unable to queue native payment speech", error);
                if (utteranceId != null) {
                    failUtterance(utteranceId, "tts_queue_exception");
                } else {
                    handleRequestFailure(request, "tts_setup_exception");
                }
            }
        }
        releaseWakeLockIfIdle();
    }

    private static String stableIdentity(String eventKey) {
        if (eventKey == null) return "";
        String[] parts = eventKey.split("\\|");
        if (parts.length < 4) return eventKey;
        StringBuilder value = new StringBuilder();
        for (int i = 0; i < parts.length - 1; i++) {
            if (i > 0) value.append('|');
            value.append(parts[i]);
        }
        return value.toString();
    }

    private static long postedAt(String eventKey) {
        if (eventKey == null) return 0L;
        String[] parts = eventKey.split("\\|");
        if (parts.length < 4) return 0L;
        try { return Long.parseLong(parts[parts.length - 2]); }
        catch (NumberFormatException error) { return 0L; }
    }

    private static String extractPayer(String raw) {
        if (raw == null) return "";
        Matcher sent = Pattern.compile("^\\s*([\\p{L}][\\p{L} .'-]{1,50}?)\\s+(?:sent|paid|transferred)\\b",
                Pattern.CASE_INSENSITIVE).matcher(raw);
        if (sent.find()) return sent.group(1).trim();
        Matcher from = Pattern.compile("\\b(?:from|received from|transfer from)\\s+([\\p{L}][\\p{L} .'-]{1,50}?)(?=\\s+(?:to|via|for|upi|utr|ref|txn|id|credited|sent|paid|account|a/c)\\b|[.,;]|₹|$)",
                Pattern.CASE_INSENSITIVE).matcher(raw);
        return from.find() ? from.group(1).trim() : "";
    }

    private static String extractAccount(String raw) {
        if (raw == null) return "";
        Matcher matcher = Pattern.compile("(?:account|a/c|acct)[^0-9]{0,12}(?:x{2,})?([0-9]{4})|x{2,}([0-9]{4})",
                Pattern.CASE_INSENSITIVE).matcher(raw);
        if (!matcher.find()) return "";
        return matcher.group(1) == null ? matcher.group(2) : matcher.group(1);
    }

    private static Locale localeFor(String lang) {
        switch (lang) {
            case "hi": return new Locale("hi", "IN");
            case "te": return new Locale("te", "IN");
            case "ta": return new Locale("ta", "IN");
            case "kn": return new Locale("kn", "IN");
            case "ml": return new Locale("ml", "IN");
            case "mr": return new Locale("mr", "IN");
            case "bn": return new Locale("bn", "IN");
            case "gu": return new Locale("gu", "IN");
            case "pa": return new Locale("pa", "IN");
            default: return new Locale("en", "IN");
        }
    }

    private static final class Announcement {
        final String localized;
        final String english;
        final String language;
        final String referenceId;
        final double amountValue;
        final String direction;
        final String rawText;
        Announcement(String localized, String english, String language, String referenceId,
                     double amountValue, String direction, String rawText) {
            this.localized = localized;
            this.english = english;
            this.language = language;
            this.referenceId = referenceId;
            this.amountValue = amountValue;
            this.direction = direction;
            this.rawText = rawText;
        }
    }

    private static final class SpeakRequest {
        final Context context;
        final String eventKey;
        final Announcement announcement;
        final Map<String, Object> event;
        SpeakRequest(Context context, String eventKey, Announcement announcement, Map<String, Object> event) {
            this.context = context;
            this.eventKey = eventKey;
            this.announcement = announcement;
            this.event = new java.util.HashMap<>(event);
        }
    }
}
