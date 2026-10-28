package notification.listener.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Durable, app-private relay for Android notification events.
 *
 * Persist text-only events before forwarding them because Android can post a
 * notification while Flutter's EventChannel has no active listener. Events
 * remain queued until Dart acknowledges the stable event key after processing.
 */
public final class NotificationRelayReceiver extends BroadcastReceiver {
    private static final String TAG = "NotificationRelay";
    private static final String PREFS = "retailmind_notification_relay";
    private static final String PENDING = "pending_notification_events";
    private static final int MAX_PENDING_EVENTS = 300;
    private static final Object LOCK = new Object();

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getBooleanExtra(NotificationConstants.IS_REMOVED, false)) return;

        final String eventKey = intent.getStringExtra(NotificationConstants.EVENT_KEY);
        if (eventKey == null || eventKey.trim().isEmpty()) {
            Log.w(TAG, "Ignoring notification without stable event key");
            return;
        }

        Map<String, Object> event = toFlutterEvent(intent, eventKey);
        if (!persistPendingEvent(context, event)) {
            // Best-effort live delivery remains available; active-notification
            // recovery can also recover it if the notification stays visible.
            Log.w(TAG, "Could not persist notification event; forwarding live");
        }

        Intent relay = new Intent(NotificationConstants.INTENT);
        relay.setPackage(context.getPackageName());
        relay.putExtra(NotificationConstants.PACKAGE_NAME, intent.getStringExtra(NotificationConstants.PACKAGE_NAME));
        relay.putExtra(NotificationConstants.ID, intent.getIntExtra(NotificationConstants.ID, -1));
        relay.putExtra(NotificationConstants.EVENT_KEY, eventKey);
        relay.putExtra(NotificationConstants.CAN_REPLY, intent.getBooleanExtra(NotificationConstants.CAN_REPLY, false));
        relay.putExtra(NotificationConstants.IS_ONGOING, intent.getBooleanExtra(NotificationConstants.IS_ONGOING, false));
        relay.putExtra(NotificationConstants.IS_REMOVED, false);
        relay.putExtra(NotificationConstants.NOTIFICATION_TITLE, intent.getStringExtra(NotificationConstants.NOTIFICATION_TITLE));
        relay.putExtra(NotificationConstants.NOTIFICATION_CONTENT, intent.getStringExtra(NotificationConstants.NOTIFICATION_CONTENT));
        relay.putExtra(NotificationConstants.NOTIFICATION_BIG_TEXT, intent.getStringExtra(NotificationConstants.NOTIFICATION_BIG_TEXT));
        relay.putExtra(NotificationConstants.NOTIFICATION_SUB_TEXT, intent.getStringExtra(NotificationConstants.NOTIFICATION_SUB_TEXT));
        relay.putExtra(NotificationConstants.NOTIFICATION_SUMMARY_TEXT, intent.getStringExtra(NotificationConstants.NOTIFICATION_SUMMARY_TEXT));
        relay.putExtra(NotificationConstants.NOTIFICATION_TEXT_LINES, intent.getStringExtra(NotificationConstants.NOTIFICATION_TEXT_LINES));
        relay.putExtra(NotificationConstants.NOTIFICATION_TICKER, intent.getStringExtra(NotificationConstants.NOTIFICATION_TICKER));
        context.sendBroadcast(relay);
    }

    private static Map<String, Object> toFlutterEvent(Intent intent, String eventKey) {
        Map<String, Object> event = new HashMap<>();
        event.put("id", intent.getIntExtra(NotificationConstants.ID, -1));
        event.put("eventKey", eventKey);
        event.put("nativeAnnouncementHandled", false);
        event.put("packageName", intent.getStringExtra(NotificationConstants.PACKAGE_NAME));
        event.put("title", intent.getStringExtra(NotificationConstants.NOTIFICATION_TITLE));
        event.put("content", intent.getStringExtra(NotificationConstants.NOTIFICATION_CONTENT));
        event.put("bigText", intent.getStringExtra(NotificationConstants.NOTIFICATION_BIG_TEXT));
        event.put("subText", intent.getStringExtra(NotificationConstants.NOTIFICATION_SUB_TEXT));
        event.put("summaryText", intent.getStringExtra(NotificationConstants.NOTIFICATION_SUMMARY_TEXT));
        event.put("textLines", intent.getStringExtra(NotificationConstants.NOTIFICATION_TEXT_LINES));
        event.put("ticker", intent.getStringExtra(NotificationConstants.NOTIFICATION_TICKER));
        event.put("hasRemoved", false);
        event.put("canReply", intent.getBooleanExtra(NotificationConstants.CAN_REPLY, false));
        event.put("onGoing", intent.getBooleanExtra(NotificationConstants.IS_ONGOING, false));
        return event;
    }

    private static boolean persistPendingEvent(Context context, Map<String, Object> event) {
        synchronized (LOCK) {
            try {
                SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
                JSONArray current = new JSONArray(preferences.getString(PENDING, "[]"));
                String eventKey = String.valueOf(event.get("eventKey"));
                JSONObject item = new JSONObject();
                for (Map.Entry<String, Object> entry : event.entrySet()) {
                    item.put(entry.getKey(), entry.getValue() == null ? JSONObject.NULL : entry.getValue());
                }

                // Keep the latest content if Android updates the same notification
                // instance from "processing" to its final transaction state.
                for (int i = 0; i < current.length(); i++) {
                    JSONObject old = current.optJSONObject(i);
                    if (old != null && eventKey.equals(old.optString("eventKey"))) {
                        current.put(i, item);
                        return preferences.edit().putString(PENDING, current.toString()).commit();
                    }
                }

                JSONArray next = new JSONArray();
                int start = Math.max(0, current.length() - MAX_PENDING_EVENTS + 1);
                for (int i = start; i < current.length(); i++) {
                    JSONObject old = current.optJSONObject(i);
                    if (old != null) next.put(old);
                }
                next.put(item);
                return preferences.edit().putString(PENDING, next.toString()).commit();
            } catch (JSONException | RuntimeException error) {
                Log.e(TAG, "Unable to persist notification event", error);
                return false;
            }
        }
    }

    /** Snapshot unacknowledged notification events for a newly attached Flutter stream. */
    public static List<Map<String, Object>> getPendingEvents(Context context) {
        synchronized (LOCK) {
            List<Map<String, Object>> result = new ArrayList<>();
            try {
                SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
                JSONArray pending = new JSONArray(preferences.getString(PENDING, "[]"));
                for (int i = 0; i < pending.length(); i++) {
                    JSONObject item = pending.optJSONObject(i);
                    if (item == null) continue;
                    Map<String, Object> event = new HashMap<>();
                    java.util.Iterator<String> keys = item.keys();
                    while (keys.hasNext()) {
                        String key = keys.next();
                        Object value = item.opt(key);
                        event.put(key, value == JSONObject.NULL ? null : value);
                    }
                    result.add(event);
                }
            } catch (JSONException | RuntimeException error) {
                Log.e(TAG, "Unable to read pending notification events", error);
            }
            return result;
        }
    }

    /** Find an unacknowledged event by its stable native key. */
    public static Map<String, Object> getPendingEvent(Context context, String eventKey) {
        if (eventKey == null || eventKey.trim().isEmpty()) return null;
        for (Map<String, Object> event : getPendingEvents(context)) {
            if (eventKey.equals(String.valueOf(event.get("eventKey")))) return event;
        }
        return null;
    }

    public static boolean isPendingEvent(Context context, String eventKey) {
        return getPendingEvent(context, eventKey) != null;
    }

    /**
     * Persist that the native fallback has already spoken this event. Flutter
     * still processes it for history/UI, but suppresses its second announcement.
     */
    public static boolean markNativeAnnouncementHandled(
            Context context, String eventKey, boolean handled) {
        if (eventKey == null || eventKey.trim().isEmpty()) return false;
        synchronized (LOCK) {
            try {
                SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
                JSONArray pending = new JSONArray(preferences.getString(PENDING, "[]"));
                for (int i = 0; i < pending.length(); i++) {
                    JSONObject item = pending.optJSONObject(i);
                    if (item == null || !eventKey.equals(item.optString("eventKey"))) continue;
                    item.put("nativeAnnouncementHandled", handled);
                    pending.put(i, item);
                    return preferences.edit().putString(PENDING, pending.toString()).commit();
                }
                return false;
            } catch (JSONException | RuntimeException error) {
                Log.e(TAG, "Unable to mark native announcement state", error);
                return false;
            }
        }
    }

    /** Delete a queued event only after Dart has synchronously processed it. */
    public static boolean acknowledge(Context context, String eventKey) {
        if (eventKey == null || eventKey.trim().isEmpty()) return false;
        synchronized (LOCK) {
            try {
                SharedPreferences preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
                JSONArray pending = new JSONArray(preferences.getString(PENDING, "[]"));
                JSONArray remaining = new JSONArray();
                boolean removed = false;
                for (int i = 0; i < pending.length(); i++) {
                    JSONObject item = pending.optJSONObject(i);
                    if (item == null) continue;
                    if (eventKey.equals(item.optString("eventKey"))) {
                        removed = true;
                    } else {
                        remaining.put(item);
                    }
                }
                boolean saved = preferences.edit().putString(PENDING, remaining.toString()).commit();
                return saved && removed;
            } catch (JSONException | RuntimeException error) {
                Log.e(TAG, "Unable to acknowledge notification event", error);
                return false;
            }
        }
    }
}
