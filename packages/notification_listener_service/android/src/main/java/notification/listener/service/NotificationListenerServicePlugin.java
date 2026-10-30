package notification.listener.service;

import static notification.listener.service.NotificationUtils.isPermissionGranted;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.content.ActivityNotFoundException;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import notification.listener.service.models.Action;
import notification.listener.service.models.ActionCache;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class NotificationListenerServicePlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener, EventChannel.StreamHandler {

    private static final String CHANNEL_TAG = "x-slayer/notifications_channel";
    private static final String EVENT_TAG = "x-slayer/notifications_event";

    private MethodChannel channel;
    private EventChannel eventChannel;
    private NotificationReceiver notificationReceiver;
    private Context context;
    private Activity mActivity;

    private Result pendingNotificationPermissionResult;
    final int REQUEST_CODE_FOR_NOTIFICATIONS = 1199;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_TAG);
        channel.setMethodCallHandler(this);
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EVENT_TAG);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("isPermissionGranted")) {
            result.success(isPermissionGranted(context));
        } else if (call.method.equals("requestPermission")) {
            if (mActivity == null) {
                result.error("ACTIVITY_UNAVAILABLE", "Notification settings require a foreground activity", null);
                return;
            }
            if (pendingNotificationPermissionResult != null) {
                result.error("REQUEST_IN_PROGRESS", "A notification-access request is already in progress", null);
                return;
            }

            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            pendingNotificationPermissionResult = result;
            try {
                // Complete the Dart Future only when Android returns from Settings.
                // The caller then receives the actual permission state, not null.
                mActivity.startActivityForResult(intent, REQUEST_CODE_FOR_NOTIFICATIONS);
            } catch (ActivityNotFoundException e) {
                pendingNotificationPermissionResult = null;
                Log.e("NotificationPlugin", "ActivityNotFoundException: " + e.getMessage());
                result.error("ACTIVITY_NOT_FOUND", "No activity found to handle notification listener settings", null);
            }
        } else if (call.method.equals("sendReply")) {
            final String message = call.argument("message");
            final int notificationId = call.argument("notificationId");

            final Action action = ActionCache.cachedNotifications.get(notificationId);
            if (action == null) {
                result.error("Notification", "Can't find this cached notification", null);
                return;
            }
            try {
                action.sendReply(context, message);
                result.success(true);
            } catch (PendingIntent.CanceledException e) {
                result.success(false);
                e.printStackTrace();
            }
        } else if (call.method.equals("shouldSuppressPaymentAnnouncement")) {
            if (!(call.arguments instanceof Map)) {
                result.error("InvalidAnnouncement", "Announcement payload is required", null);
                return;
            }
            result.success(AtomicPaymentAnnouncementCoordinator.shouldSuppress(
                    context, (Map<?, ?>) call.arguments));
        } else if (call.method.equals("acknowledgeNotification")) {
            final String eventKey = call.argument("eventKey");
            if (eventKey == null || eventKey.trim().isEmpty()) {
                result.error("InvalidEventKey", "eventKey is required", null);
                return;
            }
            result.success(NotificationRelayReceiver.acknowledge(context, eventKey));
        } else if (call.method.equals("getActiveNotifications")) {
            NotificationListener service = NotificationListener.getInstance();
            if (service != null) {
                List<Map<String, Object>> notifications = service.getActiveNotificationData();
                result.success(notifications);
            } else {
                result.error("ServiceUnavailable", "NotificationService not running", null);
            }
        }
        else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
        if (notificationReceiver != null) {
            try { context.unregisterReceiver(notificationReceiver); }
            catch (IllegalArgumentException ignored) {}
            notificationReceiver = null;
        }
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        this.mActivity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        this.mActivity = null;
    }
    @SuppressLint("WrongConstant")
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        if (notificationReceiver != null) {
            try { context.unregisterReceiver(notificationReceiver); }
            catch (IllegalArgumentException ignored) {}
            notificationReceiver = null;
        }

        IntentFilter intentFilter = new IntentFilter(NotificationConstants.INTENT);
        notificationReceiver = new NotificationReceiver(events);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(notificationReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(notificationReceiver, intentFilter);
        }

        // Replay unacknowledged notification events first. They remain in
        // private SharedPreferences until Dart acknowledges processing them.
        Set<String> pendingEventKeys = new HashSet<>();
        for (Map<String, Object> pending : NotificationRelayReceiver.getPendingEvents(context)) {
            Object key = pending.get("eventKey");
            if (key != null) pendingEventKeys.add(String.valueOf(key));
            events.success(pending);
        }

        // Recover notifications already active before the durable queue existed,
        // without replaying an event already returned from the pending queue.
        NotificationListener service = NotificationListener.getInstance();
        if (service != null) {
            for (Map<String, Object> item : service.getActiveNotificationData()) {
                Object key = item.get("eventKey");
                if (key != null && pendingEventKeys.contains(String.valueOf(key))) continue;
                // Already routed by Dart before this (re)attach: replaying it
                // would re-detect, and possibly re-announce, the same payment.
                if (key != null && NotificationRelayReceiver.wasAcknowledged(
                        context, String.valueOf(key))) continue;
                HashMap<String, Object> replay = new HashMap<>(item);
                replay.put("hasRemoved", false);
                replay.put("canReply", false);
                replay.put("bigText", null);
                replay.put("subText", null);
                replay.put("summaryText", null);
                replay.put("textLines", null);
                replay.put("ticker", null);
                events.success(replay);
            }
        }
        Log.i("NotificationPlugin", "Notification event stream subscribed.");
    }

    @Override
    public void onCancel(Object arguments) {
        if (notificationReceiver != null) {
            try { context.unregisterReceiver(notificationReceiver); }
            catch (IllegalArgumentException ignored) {}
            notificationReceiver = null;
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_FOR_NOTIFICATIONS) {
            Result permissionResult = pendingNotificationPermissionResult;
            pendingNotificationPermissionResult = null;
            if (permissionResult != null) {
                // Activity result codes vary across Android versions/OEMs.
                // Check the actual notification-listener permission instead.
                permissionResult.success(isPermissionGranted(context));
            }
            return true;
        }
        return false;
    }
}
