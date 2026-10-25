package notification.listener.service;

import android.annotation.SuppressLint;
import androidx.annotation.RequiresApi;
import android.app.Notification;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import notification.listener.service.models.Action;
import notification.listener.service.models.ActionCache;

/**
 * Relays notification text to the in-process plugin receiver.
 * Keep this Intent text-only: icon/picture blobs can exceed Binder's
 * transaction limit and crash delivery before Dart sees the payment.
 */
@SuppressLint("OverrideAbstract")
@RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR2)
public class NotificationListener extends NotificationListenerService {
    private static final String TAG = "NotificationListener";
    private static NotificationListener instance;

    public static NotificationListener getInstance() { return instance; }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
        Log.i(TAG, "Notification listener connected");
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        instance = null;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            requestRebind(new android.content.ComponentName(this, NotificationListener.class));
        }
        Log.w(TAG, "Notification listener disconnected; rebind requested");
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        handleNotificationSafely(sbn, false);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        handleNotificationSafely(sbn, true);
    }

    private void handleNotificationSafely(StatusBarNotification sbn, boolean removed) {
        try {
            if (sbn == null) return;
            // Ignore our own app/service notifications to avoid feedback loops.
            if (getPackageName().equals(sbn.getPackageName())) return;

            Notification notification = sbn.getNotification();
            Bundle extras = notification == null ? null : notification.extras;
            boolean ongoing = notification != null && (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            Action action = notification == null ? null : NotificationUtils.getQuickReplyAction(notification, sbn.getPackageName());
            if (action != null) ActionCache.cachedNotifications.put(sbn.getId(), action);

            Intent intent = new Intent(NotificationConstants.INTENT);
            // Restrict delivery to this app; do not send a system-wide implicit broadcast.
            intent.setPackage(getPackageName());
            intent.putExtra(NotificationConstants.PACKAGE_NAME, sbn.getPackageName());
            intent.putExtra(NotificationConstants.ID, sbn.getId());
            intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
            intent.putExtra(NotificationConstants.IS_ONGOING, ongoing);
            intent.putExtra(NotificationConstants.IS_REMOVED, removed);

            if (extras != null) {
                putText(intent, NotificationConstants.NOTIFICATION_TITLE,
                        extras.getCharSequence(Notification.EXTRA_TITLE));
                putText(intent, NotificationConstants.NOTIFICATION_CONTENT,
                        extras.getCharSequence(Notification.EXTRA_TEXT));
                putText(intent, NotificationConstants.NOTIFICATION_BIG_TEXT,
                        extras.getCharSequence(Notification.EXTRA_BIG_TEXT));
                putText(intent, NotificationConstants.NOTIFICATION_SUB_TEXT,
                        extras.getCharSequence(Notification.EXTRA_SUB_TEXT));
                putText(intent, NotificationConstants.NOTIFICATION_SUMMARY_TEXT,
                        extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT));
                Object lines = extras.get("android.textLines");
                if (lines instanceof CharSequence[]) {
                    intent.putExtra(NotificationConstants.NOTIFICATION_TEXT_LINES,
                            android.text.TextUtils.join("\n", (CharSequence[]) lines));
                }
                putText(intent, NotificationConstants.NOTIFICATION_TICKER, notification.tickerText);
            }

            sendBroadcast(intent);
        } catch (Throwable error) {
            // Never allow an unsupported vendor Notification/Drawable to kill the listener.
            Log.e(TAG, "Failed to relay notification event", error);
        }
    }

    private static void putText(Intent intent, String key, CharSequence value) {
        if (value != null) intent.putExtra(key, value.toString());
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public List<Map<String, Object>> getActiveNotificationData() {
        List<Map<String, Object>> result = new ArrayList<>();
        StatusBarNotification[] active = getActiveNotifications();
        if (active == null) return result;
        for (StatusBarNotification sbn : active) {
            Map<String, Object> item = new HashMap<>();
            Notification n = sbn.getNotification();
            Bundle extras = n == null ? null : n.extras;
            item.put("id", sbn.getId());
            item.put("packageName", sbn.getPackageName());
            item.put("title", extras == null || extras.getCharSequence(Notification.EXTRA_TITLE) == null
                    ? null : extras.getCharSequence(Notification.EXTRA_TITLE).toString());
            item.put("content", extras == null || extras.getCharSequence(Notification.EXTRA_TEXT) == null
                    ? null : extras.getCharSequence(Notification.EXTRA_TEXT).toString());
            item.put("onGoing", n != null && (n.flags & Notification.FLAG_ONGOING_EVENT) != 0);
            result.add(item);
        }
        return result;
    }
}
