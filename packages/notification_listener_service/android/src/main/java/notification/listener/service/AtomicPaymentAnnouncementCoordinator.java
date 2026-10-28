package notification.listener.service;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

import org.json.JSONArray;

import java.math.BigDecimal;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Atomic announcement idempotency gate shared by all Flutter engines and the
 * native TTS fallback. SQLite serializes write transactions across threads and
 * app processes; SharedPreferences read/modify/write is not an atomic claim.
 *
 * This class suppresses announcement echoes only. It is not proof of payment
 * settlement and must never update sales or invoices.
 */
public final class AtomicPaymentAnnouncementCoordinator extends SQLiteOpenHelper {
    private static final String TAG = "RetailMindAnnouncementGate";
    private static final String DB_NAME = "retailmind_announcement_gate.db";
    private static final int DB_VERSION = 1;
    private static final String TABLE = "announcement_observations";
    private static final long MAX_AGE_MS = 24L * 60L * 60L * 1000L;
    private static final long CROSS_APP_MS = 10L * 60L * 1000L;
    private static final long SMS_ECHO_MS = 3L * 60L * 60L * 1000L;
    private static final long EXACT_TEXT_REPLAY_MS = 2000L;
    private static final int MAX_ROWS = 500;
    private static final Pattern ACCOUNT_PATTERN = Pattern.compile(
            "(?:account|a/c|acct)[^0-9]{0,12}(?:x{2,})?([0-9]{4})|x{2,}([0-9]{4})",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern PAYER_FROM_PATTERN = Pattern.compile(
            "\\b(?:from|received from|transfer from)\\s+([\\p{L}][\\p{L} .'-]{1,50}?)(?=\\s+(?:to|via|for|on|using|upi|utr|reference|ref|txn|id|credited|sent|paid|account|a/c)\\b|[.,;]|₹|$)",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern PAYER_SENT_PATTERN = Pattern.compile(
            "^\\s*([\\p{L}][\\p{L} .'-]{1,50}?)\\s+(?:sent|paid|transferred)\\b",
            Pattern.CASE_INSENSITIVE);

    private static volatile AtomicPaymentAnnouncementCoordinator instance;
    private static final Object INSTANCE_LOCK = new Object();

    public static boolean shouldSuppress(Context context, Map<?, ?> event) {
        try {
            return getInstance(context).evaluate(event);
        } catch (RuntimeException error) {
            // Fail open: never block payment detection because the local gate
            // is unavailable. The Dart in-isolate guard remains as fallback.
            Log.e(TAG, "Atomic announcement gate failed; allowing candidate", error);
            return false;
        }
    }

    public static void releaseSourceIdentity(Context context, String sourceIdentity) {
        if (sourceIdentity == null || sourceIdentity.trim().isEmpty()) return;
        try {
            getInstance(context).releaseIdentity(sourceIdentity);
        } catch (RuntimeException error) {
            Log.w(TAG, "Could not release failed native announcement claim", error);
        }
    }

    private static AtomicPaymentAnnouncementCoordinator getInstance(Context context) {
        AtomicPaymentAnnouncementCoordinator value = instance;
        if (value != null) return value;
        synchronized (INSTANCE_LOCK) {
            if (instance == null) {
                instance = new AtomicPaymentAnnouncementCoordinator(context.getApplicationContext());
            }
            return instance;
        }
    }

    private AtomicPaymentAnnouncementCoordinator(Context context) {
        super(context, DB_NAME, null, DB_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + TABLE + " (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT," +
                "source_identity TEXT," +
                "reference_hash TEXT," +
                "amount_cents INTEGER NOT NULL," +
                "direction TEXT NOT NULL," +
                "channel TEXT NOT NULL," +
                "origin TEXT NOT NULL," +
                "payer_hash TEXT," +
                "account_hash TEXT," +
                "text_hash TEXT," +
                "seen_at INTEGER NOT NULL," +
                "claimed_channels TEXT NOT NULL)");
        db.execSQL("CREATE INDEX announcement_time_idx ON " + TABLE + "(seen_at)");
        db.execSQL("CREATE INDEX announcement_ref_idx ON " + TABLE + "(reference_hash)");
        db.execSQL("CREATE INDEX announcement_source_idx ON " + TABLE + "(source_identity)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        // No released schema exists yet. Keep this forward-compatible if the
        // table is upgraded in a later app version.
    }

    private boolean evaluate(Map<?, ?> input) {
        final double amount = number(input.get("amount"), 0.0);
        if (Double.isNaN(amount) || Double.isInfinite(amount) || amount <= 0.0) return false;

        final long amountCents;
        try {
            amountCents = BigDecimal.valueOf(amount).movePointRight(2).setScale(0,
                    java.math.RoundingMode.HALF_UP).longValueExact();
        } catch (ArithmeticException error) {
            return false;
        }

        final String direction = clean(value(input.get("direction"))).toLowerCase(Locale.ROOT);
        final String origin = normalizeOrigin(value(input.get("origin")));
        final String channel = firstNonEmpty(value(input.get("channel")),
                origin + "|" + firstNonEmpty(value(input.get("packageName")), value(input.get("app"))));
        final String rawText = value(input.get("rawText"));
        final String referenceHash = hash(normalizeReference(value(input.get("referenceId"))));
        final String sourceIdentity = resolveSourceIdentity(input, origin, rawText);
        final String payerHash = hash(normalizePayer(firstNonEmpty(
                value(input.get("payerName")), extractPayer(rawText))));
        final String accountHash = hash(normalizeAccount(firstNonEmpty(
                value(input.get("accountSuffix")), extractAccount(rawText))));
        final String textHash = hash(normalizeText(rawText));
        final long now = (long) number(input.get("timestamp"), System.currentTimeMillis());

        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete(TABLE, "seen_at < ?", new String[]{String.valueOf(now - MAX_AGE_MS)});
            List<Observation> observations = readObservations(db, now - MAX_AGE_MS);
            Observation uniqueCandidate = null;
            boolean ambiguous = false;

            for (Observation old : observations) {
                if (old.amountCents != amountCents || !old.direction.equals(direction)) {
                    continue;
                }

                if (notEmpty(sourceIdentity) && sourceIdentity.equals(old.sourceIdentity)) {
                    if (notEmpty(referenceHash) && notEmpty(old.referenceHash)
                            && !referenceHash.equals(old.referenceHash)) {
                        // An updated/reused notification identity carries a
                        // different authoritative transaction: preserve it.
                        continue;
                    }
                    db.setTransactionSuccessful();
                    return true;
                }

                if (notEmpty(referenceHash) || notEmpty(old.referenceHash)) {
                    // Only a shared reference may pair reference-bearing
                    // events. A missing/different reference is not an echo.
                    if (notEmpty(referenceHash) && referenceHash.equals(old.referenceHash)) {
                        db.setTransactionSuccessful();
                        return true;
                    }
                    continue;
                }

                long age = Math.abs(now - old.seenAt);
                if (old.channel.equals(channel)) {
                    // Distinct native notification posts in the same channel
                    // always remain separate payment candidates.
                    if (notEmpty(sourceIdentity) || notEmpty(old.sourceIdentity)) continue;
                    if (age <= EXACT_TEXT_REPLAY_MS &&
                            notEmpty(textHash) && textHash.equals(old.textHash)) {
                        db.setTransactionSuccessful();
                        return true;
                    }
                    continue;
                }

                long allowedAge = ("sms".equals(origin) || "sms".equals(old.origin))
                        ? SMS_ECHO_MS : CROSS_APP_MS;
                if (age > allowedAge) continue;

                if (notEmpty(accountHash) && notEmpty(old.accountHash)
                        && !accountHash.equals(old.accountHash)) continue;
                if (notEmpty(payerHash) && notEmpty(old.payerHash)
                        && !payerHash.equals(old.payerHash)) continue;

                boolean sameAccount = notEmpty(accountHash) && accountHash.equals(old.accountHash);
                boolean samePayer = notEmpty(payerHash) && payerHash.equals(old.payerHash);
                if (!sameAccount && !samePayer) continue;
                if (old.claimedChannels.contains(channel)) continue;

                if (uniqueCandidate != null && uniqueCandidate.id != old.id) {
                    ambiguous = true;
                    break;
                }
                uniqueCandidate = old;
            }

            if (uniqueCandidate != null && !ambiguous) {
                uniqueCandidate.claimedChannels.add(channel);
                ContentValues values = new ContentValues();
                values.put("claimed_channels", toJson(uniqueCandidate.claimedChannels));
                db.update(TABLE, values, "id = ?",
                        new String[]{String.valueOf(uniqueCandidate.id)});
                db.setTransactionSuccessful();
                return true;
            }

            ContentValues values = new ContentValues();
            values.put("source_identity", emptyToNull(sourceIdentity));
            values.put("reference_hash", emptyToNull(referenceHash));
            values.put("amount_cents", amountCents);
            values.put("direction", direction);
            values.put("channel", channel);
            values.put("origin", origin);
            values.put("payer_hash", emptyToNull(payerHash));
            values.put("account_hash", emptyToNull(accountHash));
            values.put("text_hash", emptyToNull(textHash));
            values.put("seen_at", now);
            values.put("claimed_channels", "[]");
            db.insertOrThrow(TABLE, null, values);
            db.execSQL("DELETE FROM " + TABLE + " WHERE id NOT IN " +
                    "(SELECT id FROM " + TABLE + " ORDER BY seen_at DESC LIMIT " + MAX_ROWS + ")");
            db.setTransactionSuccessful();
            return false;
        } finally {
            db.endTransaction();
        }
    }

    private void releaseIdentity(String sourceIdentity) {
        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete(TABLE, "source_identity = ?", new String[]{sourceIdentity});
            db.setTransactionSuccessful();
        } finally {
            db.endTransaction();
        }
    }

    private List<Observation> readObservations(SQLiteDatabase db, long minTime) {
        List<Observation> items = new ArrayList<>();
        Cursor cursor = db.query(TABLE,
                new String[]{"id", "source_identity", "reference_hash", "amount_cents",
                        "direction", "channel", "origin", "payer_hash", "account_hash",
                        "text_hash", "seen_at", "claimed_channels"},
                "seen_at >= ?", new String[]{String.valueOf(minTime)},
                null, null, "seen_at DESC", String.valueOf(MAX_ROWS));
        try {
            while (cursor.moveToNext()) {
                Observation item = new Observation();
                item.id = cursor.getLong(0);
                item.sourceIdentity = cursor.getString(1);
                item.referenceHash = cursor.getString(2);
                item.amountCents = cursor.getLong(3);
                item.direction = value(cursor.getString(4));
                item.channel = value(cursor.getString(5));
                item.origin = value(cursor.getString(6));
                item.payerHash = cursor.getString(7);
                item.accountHash = cursor.getString(8);
                item.textHash = cursor.getString(9);
                item.seenAt = cursor.getLong(10);
                item.claimedChannels = parseJsonSet(cursor.getString(11));
                items.add(item);
            }
        } finally {
            cursor.close();
        }
        return items;
    }

    private static String resolveSourceIdentity(Map<?, ?> input, String origin, String rawText) {
        String identity = firstNonEmpty(value(input.get("sourceIdentity")), value(input.get("sourceEventIdentity")));
        if (notEmpty(identity)) return identity;

        String eventKey = value(input.get("sourceEventKey"));
        if (notEmpty(eventKey)) {
            String[] parts = eventKey.split("\\|");
            if (parts.length >= 4) {
                StringBuilder stable = new StringBuilder();
                for (int i = 0; i < parts.length - 1; i++) {
                    if (i > 0) stable.append('|');
                    stable.append(parts[i]);
                }
                return stable.toString();
            }
            return eventKey;
        }

        long sourceTimestamp = number(input.get("sourceTimestamp"), 0.0).longValue();
        if ("sms".equals(origin) && sourceTimestamp > 0L) {
            return "sms|" + sourceTimestamp + "|" + hash(normalizeText(rawText));
        }
        return null;
    }

    private static String normalizeOrigin(String source) {
        String value = source.toLowerCase(Locale.ROOT).trim();
        if (value.startsWith("notification+sms")) return "notification+sms";
        if (value.startsWith("notification")) return "notification";
        if (value.startsWith("sms")) return "sms";
        if (value.startsWith("accessibility")) return "accessibility";
        if (value.startsWith("truecaller_notification")) return "truecaller_notification";
        int colon = value.indexOf(':');
        return colon >= 0 ? value.substring(0, colon) : value;
    }

    private static String normalizeReference(String value) {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT)
                .replaceAll("[^A-Z0-9]", "");
    }

    private static String normalizePayer(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT)
                .replaceAll("[^\\p{L}\\p{N}]+", " ").trim();
    }

    private static String normalizeAccount(String value) {
        return value == null ? "" : value.replaceAll("[^0-9]", "");
    }

    private static String normalizeText(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT)
                .replaceAll("\\s+", " ").trim();
    }

    private static String extractPayer(String raw) {
        if (raw == null || raw.isEmpty()) return "";
        Matcher sent = PAYER_SENT_PATTERN.matcher(raw);
        if (sent.find()) return sent.group(1).trim();
        Matcher from = PAYER_FROM_PATTERN.matcher(raw);
        return from.find() ? from.group(1).trim() : "";
    }

    private static String extractAccount(String raw) {
        if (raw == null || raw.isEmpty()) return "";
        Matcher matcher = ACCOUNT_PATTERN.matcher(raw);
        if (!matcher.find()) return "";
        return firstNonEmpty(matcher.group(1), matcher.group(2));
    }

    private static Set<String> parseJsonSet(String raw) {
        Set<String> items = new HashSet<>();
        try {
            JSONArray array = new JSONArray(firstNonEmpty(raw, "[]"));
            for (int i = 0; i < array.length(); i++) items.add(array.optString(i));
        } catch (org.json.JSONException ignored) {}
        return items;
    }

    private static String toJson(Set<String> values) {
        JSONArray array = new JSONArray();
        for (String value : values) array.put(value);
        return array.toString();
    }

    private static String hash(String value) {
        if (value == null || value.isEmpty()) return "";
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(Charset.forName("UTF-8")));
            StringBuilder out = new StringBuilder(digest.length * 2);
            for (byte b : digest) out.append(String.format(Locale.ROOT, "%02x", b & 0xff));
            return out.toString();
        } catch (NoSuchAlgorithmException impossible) {
            return "";
        }
    }

    private static double number(Object value, double fallback) {
        return value instanceof Number ? ((Number) value).doubleValue() : fallback;
    }

    private static String value(Object value) {
        return value == null ? "" : String.valueOf(value).trim();
    }

    private static String firstNonEmpty(String a, String b) {
        return a == null || a.trim().isEmpty() ? (b == null ? "" : b.trim()) : a.trim();
    }

    private static String emptyToNull(String value) {
        return value == null || value.isEmpty() ? null : value;
    }

    private static boolean notEmpty(String value) {
        return value != null && !value.isEmpty();
    }

    private static final class Observation {
        long id;
        String sourceIdentity;
        String referenceHash;
        long amountCents;
        String direction;
        String channel;
        String origin;
        String payerHash;
        String accountHash;
        String textHash;
        long seenAt;
        Set<String> claimedChannels = Collections.emptySet();
    }
}
