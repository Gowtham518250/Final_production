package notification.listener.service;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.util.Log;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
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

    private static TextToSpeech tts;
    private static boolean ttsInitializing;
    private static boolean ttsReady;

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
    private static final Pattern CREDIT_PATTERN = Pattern.compile(
            "\\b(?:credited|received|deposited|cashback received|money received|credit to your account)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern DEBIT_PATTERN = Pattern.compile(
            "\\b(?:debited|withdrawn|withdrawal|spent|you sent|sent to|paid to|purchase at|deducted|transferred to)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern NOT_FINAL_PATTERN = Pattern.compile(
            "\\b(?:otp|one.time.password|verification code|collect request|payment request|request received|pending|processing|initiated|failed|declined|reversed|refund|will be credited|to be credited)\\b",
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

            queueSpeak(appContext, eventKey, announcement);
        }, FALLBACK_DELAY_MS);
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
        try {
            amount = new BigDecimal(matcher.group(1).replace(",", ""))
                    .stripTrailingZeros().toPlainString();
        } catch (NumberFormatException error) {
            return null;
        }

        boolean credit = CREDIT_PATTERN.matcher(raw).find();
        boolean debit = DEBIT_PATTERN.matcher(raw).find();
        // Ambiguous wording is not spoken as a direction. The full Dart
        // classifier will still receive it when available.
        if (credit == debit) return null;

        String lang = languageTag == null ? "en" : languageTag.split("[-_]", 2)[0].toLowerCase(Locale.ROOT);
        String phrase = localizedMessage(lang, amount, credit);
        String english = credit
                ? "Payment notification reports " + amount + " rupees received. Please verify in your bank or UPI app."
                : "Payment notification reports " + amount + " rupees debited. Please verify in your bank or UPI app.";
        return new Announcement(phrase, english, lang);
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

    private static void queueSpeak(Context context, String eventKey, Announcement announcement) {
        synchronized (LOCK) {
            WAITING.add(new SpeakRequest(context.getApplicationContext(), eventKey, announcement));
            if (ttsReady) {
                drainWaiting();
            } else if (!ttsInitializing) {
                ttsInitializing = true;
                tts = new TextToSpeech(context.getApplicationContext(), status -> {
                    synchronized (LOCK) {
                        ttsInitializing = false;
                        ttsReady = status == TextToSpeech.SUCCESS && tts != null;
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

    private static void drainWaiting() {
        if (!ttsReady || tts == null) return;
        List<SpeakRequest> requests = new ArrayList<>(WAITING);
        WAITING.clear();
        for (SpeakRequest request : requests) {
            if (!NotificationRelayReceiver.isPendingEvent(request.context, request.eventKey)) {
                SCHEDULED.remove(request.eventKey);
                continue;
            }
            if (!NotificationRelayReceiver.markNativeAnnouncementHandled(
                    request.context, request.eventKey, true)) {
                SCHEDULED.remove(request.eventKey);
                continue;
            }

            Locale locale = localeFor(request.announcement.language);
            int availability = tts.isLanguageAvailable(locale);
            String message = request.announcement.localized;
            if (availability < TextToSpeech.LANG_AVAILABLE) {
                locale = new Locale("en", "IN");
                int englishAvailability = tts.isLanguageAvailable(locale);
                if (englishAvailability < TextToSpeech.LANG_AVAILABLE) locale = Locale.US;
                message = request.announcement.english;
            }
            tts.setLanguage(locale);
            java.util.HashMap<String, String> params = new java.util.HashMap<>();
            params.put(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "retailmind_" + Math.abs(request.eventKey.hashCode()));
            int result = tts.speak(message, TextToSpeech.QUEUE_ADD, params);
            if (result == TextToSpeech.ERROR) {
                NotificationRelayReceiver.markNativeAnnouncementHandled(
                        request.context, request.eventKey, false);
                Log.w(TAG, "TTS rejected native payment announcement");
            } else {
                Log.i(TAG, "Native fallback announced a payment notification; financial verification is still required.");
            }
            SCHEDULED.remove(request.eventKey);
        }
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
        Announcement(String localized, String english, String language) {
            this.localized = localized;
            this.english = english;
            this.language = language;
        }
    }

    private static final class SpeakRequest {
        final Context context;
        final String eventKey;
        final Announcement announcement;
        SpeakRequest(Context context, String eventKey, Announcement announcement) {
            this.context = context;
            this.eventKey = eventKey;
            this.announcement = announcement;
        }
    }
}
