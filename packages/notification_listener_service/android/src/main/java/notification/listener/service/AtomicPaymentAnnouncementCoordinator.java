package notification.listener.service;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

import java.math.BigDecimal;
import java.nio.charset.Charset;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

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
    private static final long STRONG_CROSS_SOURCE_MS = 10L * 60L * 1000L;
    private static final int MAX_ROWS = 500;

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

        final String direction = value(input.get("direction")).toLowerCase(Locale.ROOT);
        final String origin = normalizeOrigin(value(input.get("origin")));
        final String channel = firstNonEmpty(value(input.get("channel")),
                origin + "|" + firstNonEmpty(value(input.get("packageName")), value(input.get("app"))));
        final String rawText = value(input.get("rawText"));
        final String referenceHash = hash(normalizeReference(value(input.get("referenceId"))));
        final String sourceIdentity = resolveSourceIdentity(input, origin, rawText);
        final String payerHash = hash(normalizePayer(value(input.get("payerName"))));
        final String accountHash = hash(normalizeAccount(value(input.get("accountSuffix"))));
        final long now = (long) number(input.get("timestamp"), System.currentTimeMillis());

        SQLiteDatabase db = getWritableDatabase();
        db.beginTransaction();
        try {
            db.delete(TABLE, "seen_at < ?", new String[]{String.valueOf(now - MAX_AGE_MS)});
            List<Observation> observations = readObservations(db, now - MAX_AGE_MS);
            List<Observation> strongMatches = new ArrayList<>();
            for (Observation old : observations) {
                if (old.amountCents != amountCents) continue;
                boolean sameDirection = old.direction.equals(direction);
                boolean identityDirectionCompatible = sameDirection
                        || "unknown".equals(direction)
                        || "unknown".equals(old.direction);

                if (notEmpty(sourceIdentity) && sourceIdentity.equals(old.sourceIdentity)) {
                    if (notEmpty(referenceHash) && notEmpty(old.referenceHash)
                            && !referenceHash.equals(old.referenceHash)) {
                        // An updated/reused notification identity carries a
                        // different authoritative transaction: preserve it.
                        continue;
                    }
                    if (identityDirectionCompatible) {
                        db.setTransactionSuccessful();
                        return true;
                    }
                    continue;
                }

                if (notEmpty(referenceHash) && notEmpty(old.referenceHash)) {
                    // A shared reference plus compatible amount/direction is
                    // enough even if one source cannot infer the direction.
                    // Two different references are always two payments.
                    if (referenceHash.equals(old.referenceHash)
                            && identityDirectionCompatible) {
                        db.setTransactionSuccessful();
                        return true;
                    }
                    continue;
                }

                if (old.channel.equals(channel)
                        || !sameDirection
                        || "unknown".equals(direction)
                        || Math.abs(now - old.seenAt) > STRONG_CROSS_SOURCE_MS
                        || hasClaim(old.claimedChannels, channel)) {
                    continue;
                }
                boolean payerConflict = notEmpty(payerHash) && notEmpty(old.payerHash)
                        && !payerHash.equals(old.payerHash);
                boolean accountConflict = notEmpty(accountHash) && notEmpty(old.accountHash)
                        && !accountHash.equals(old.accountHash);
                boolean samePayer = notEmpty(payerHash) && payerHash.equals(old.payerHash);
                boolean sameAccount = notEmpty(accountHash) && accountHash.equals(old.accountHash);
                if (!payerConflict && !accountConflict && (samePayer || sameAccount)) {
                    strongMatches.add(old);
                }
            }

            if (strongMatches.size() == 1) {
                Observation match = strongMatches.get(0);
                ContentValues claim = new ContentValues();
                claim.put("claimed_channels", addClaim(match.claimedChannels, channel));
                db.update(TABLE, claim, "id = ?", new String[]{String.valueOf(match.id)});
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
            values.put("seen_at", now);
            values.put("claimed_channels", "\n");
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
                        "direction", "channel", "payer_hash", "account_hash",
                        "seen_at", "claimed_channels"},
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
                item.payerHash = value(cursor.getString(6));
                item.accountHash = value(cursor.getString(7));
                item.seenAt = cursor.getLong(8);
                item.claimedChannels = value(cursor.getString(9));
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

        long sourceTimestamp = (long) number(input.get("sourceTimestamp"), 0.0);
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

    private static boolean hasClaim(String claims, String channel) {
        return claims != null && claims.contains("\n" + channel + "\n");
    }

    private static String addClaim(String claims, String channel) {
        if (hasClaim(claims, channel)) return claims;
        String normalized = claims == null || !claims.startsWith("\n") ? "\n" : claims;
        if (!normalized.endsWith("\n")) normalized += "\n";
        return normalized + channel + "\n";
    }

    private static String normalizeText(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT)
                .replaceAll("\\s+", " ").trim();
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
        String payerHash;
        String accountHash;
        long seenAt;
        String claimedChannels;
    }
}
