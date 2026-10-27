package notification.listener.service;

import static notification.listener.service.NotificationUtils.getBitmapFromDrawable;
import static notification.listener.service.models.ActionCache.cachedNotifications;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.HashMap;

import androidx.annotation.RequiresApi;

import java.io.ByteArrayOutputStream;

import notification.listener.service.models.Action;


@SuppressLint("OverrideAbstract")
@RequiresApi(api = VERSION_CODES.JELLY_BEAN_MR2)
public class NotificationListener extends NotificationListenerService {
    private static NotificationListener instance;

    public static NotificationListener getInstance() {
        return instance;
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        if (instance == this) instance = null;
        // Ask Android to reconnect us; otherwise payment notifications stop
        // silently until the app is reopened.
        if (Build.VERSION.SDK_INT >= VERSION_CODES.N) {
            try {
                requestRebind(new android.content.ComponentName(this, NotificationListener.class));
            } catch (Throwable t) {
                Log.w("NotificationListener", "requestRebind failed", t);
            }
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationPosted(StatusBarNotification notification) {
        safeHandle(notification, false);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        safeHandle(sbn, true);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void safeHandle(StatusBarNotification sbn, boolean isRemoved) {
        try {
            if (sbn == null || sbn.getNotification() == null) return;
            // Never forward our own foreground-service notification.
            if (getPackageName().equals(sbn.getPackageName())) return;
            // Removal callbacks are not payment events. Keep the posted event
            // queued until Dart acknowledges it, even if the notification is dismissed.
            if (isRemoved) return;
            handleNotification(sbn, false);
        } catch (Throwable t) {
            // A crash here kills the listener binding and every later payment.
            Log.e("NotificationListener", "handleNotification failed", t);
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void handleNotification(StatusBarNotification notification, boolean isRemoved) {
        String packageName = notification.getPackageName();
        Bundle extras = notification.getNotification().extras;
        boolean isOngoing = (notification.getNotification().flags & Notification.FLAG_ONGOING_EVENT) != 0;
        Action action = NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName);

        // Deliver only to our own app, and never ship icons/pictures: PNG
        // bytes in a broadcast risk the Binder transaction size limit and the
        // app does not need them for payment detection.
        String eventKey = buildEventKey(notification);
        Intent intent = new Intent(this, NotificationRelayReceiver.class);
        intent.setAction(NotificationConstants.INTENT);
        intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
        intent.putExtra(NotificationConstants.ID, notification.getId());
        intent.putExtra(NotificationConstants.EVENT_KEY, eventKey);
        intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
        intent.putExtra(NotificationConstants.IS_ONGOING, isOngoing);

        if (action != null) {
            cachedNotifications.put(notification.getId(), action);
        }

        if (extras != null) {
            CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
            CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);
            CharSequence bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
            CharSequence subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT);
            CharSequence summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT);
            Object textLinesValue = extras.get("android.textLines");
            CharSequence[] textLines = textLinesValue instanceof CharSequence[]
                    ? (CharSequence[]) textLinesValue
                    : null;

            intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, title == null ? null : title.toString());
            intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, text == null ? null : text.toString());
            intent.putExtra(NotificationConstants.NOTIFICATION_BIG_TEXT, bigText == null ? null : bigText.toString());
            intent.putExtra(NotificationConstants.NOTIFICATION_SUB_TEXT, subText == null ? null : subText.toString());
            intent.putExtra(NotificationConstants.NOTIFICATION_SUMMARY_TEXT, summaryText == null ? null : summaryText.toString());
            intent.putExtra(
                    NotificationConstants.NOTIFICATION_TEXT_LINES,
                    textLines == null ? null : android.text.TextUtils.join("\n", textLines)
            );
            intent.putExtra(
                    NotificationConstants.NOTIFICATION_TICKER,
                    notification.getNotification().tickerText == null
                            ? null
                            : notification.getNotification().tickerText.toString()
            );
            intent.putExtra(NotificationConstants.IS_REMOVED, isRemoved);
            intent.putExtra(NotificationConstants.HAVE_EXTRA_PICTURE, false);
        }
        sendBroadcast(intent);
        // If no Flutter listener acknowledges this queued event, announce it natively.
        NativePaymentAnnouncementFallback.schedule(this, eventKey);
    }


    public byte[] getAppIcon(String packageName) {
        try {
            PackageManager manager = getBaseContext().getPackageManager();
            Drawable icon = manager.getApplicationIcon(packageName);
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            getBitmapFromDrawable(icon).compress(Bitmap.CompressFormat.PNG, 100, stream);
            return stream.toByteArray();
        } catch (Throwable e) {
            Log.w("NotificationListener", "getAppIcon failed", e);
            return null;
        }
    }

    @RequiresApi(api = VERSION_CODES.M)
    private byte[] getNotificationLargeIcon(Context context, Notification notification) {
        try {
            Icon largeIcon = notification.getLargeIcon();
            if (largeIcon == null) {
                return null;
            }
            Drawable iconDrawable = largeIcon.loadDrawable(context);
            Bitmap iconBitmap = ((BitmapDrawable) iconDrawable).getBitmap();
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            iconBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream);

            return outputStream.toByteArray();
        } catch (Exception e) {
            e.printStackTrace();
            Log.d("ERROR LARGE ICON", "getNotificationLargeIcon: " + e.getMessage());
            return null;
        }
    }

    /**
     * Stable per-version identity. The payload hash distinguishes an Android
     * notification that changes from a pending status to a completed payment
     * even if the package reuses the same notification id.
     */
    private String buildEventKey(StatusBarNotification sbn) {
        Notification n = sbn.getNotification();
        Bundle extras = n == null ? null : n.extras;
        String title = extras == null || extras.getCharSequence(Notification.EXTRA_TITLE) == null
                ? "" : extras.getCharSequence(Notification.EXTRA_TITLE).toString();
        String text = extras == null || extras.getCharSequence(Notification.EXTRA_TEXT) == null
                ? "" : extras.getCharSequence(Notification.EXTRA_TEXT).toString();
        String bigText = extras == null || extras.getCharSequence(Notification.EXTRA_BIG_TEXT) == null
                ? "" : extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString();
        String subText = extras == null || extras.getCharSequence(Notification.EXTRA_SUB_TEXT) == null
                ? "" : extras.getCharSequence(Notification.EXTRA_SUB_TEXT).toString();
        String version = title + "|" + text + "|" + bigText + "|" + subText;
        return sbn.getPackageName() + "|" + sbn.getId() + "|" + sbn.getPostTime()
                + "|" + Integer.toHexString(version.hashCode());
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public List<Map<String, Object>> getActiveNotificationData() {
        List<Map<String, Object>> notificationList = new ArrayList<>();
        StatusBarNotification[] activeNotifications = getActiveNotifications();
        if (activeNotifications == null) return notificationList;

        for (StatusBarNotification sbn : activeNotifications) {
            if (getPackageName().equals(sbn.getPackageName())) continue;
            Map<String, Object> notifData = new HashMap<>();
            Notification notification = sbn.getNotification();
            Bundle extras = notification.extras;

            notifData.put("id", sbn.getId());
            notifData.put("eventKey", buildEventKey(sbn));
            notifData.put("packageName", sbn.getPackageName());
            notifData.put("title", extras.getCharSequence(Notification.EXTRA_TITLE) != null
                    ? extras.getCharSequence(Notification.EXTRA_TITLE).toString()
                    : null);
            notifData.put("content", extras.getCharSequence(Notification.EXTRA_TEXT) != null
                    ? extras.getCharSequence(Notification.EXTRA_TEXT).toString()
                    : null);
            boolean isOngoing = (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            notifData.put("onGoing", isOngoing);

            notificationList.add(notifData);
        }
        return notificationList;
    }

}
