package notification.listener.service;

import static notification.listener.service.NotificationUtils.isPermissionGranted;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.ActivityNotFoundException;
import android.content.IntentFilter;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

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

import java.util.List;
import java.util.Map;

public class NotificationListenerServicePlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener, EventChannel.StreamHandler {

    private static final String CHANNEL_TAG = "x-slayer/notifications_channel";
    private static final String EVENT_TAG = "x-slayer/notifications_event";

    private MethodChannel channel;
    private EventChannel eventChannel;
    private NotificationReceiver notificationReceiver;
    private BroadcastReceiver relayReceiver;
    private Context context;
    private Activity mActivity;

    private Result pendingResult;
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
        pendingResult = result;
        if (call.method.equals("isPermissionGranted")) {
            result.success(isPermissionGranted(context));
        } else if (call.method.equals("requestPermission")) {
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            try {
                mActivity.startActivityForResult(intent, REQUEST_CODE_FOR_NOTIFICATIONS);
                result.success(null);
            } catch (ActivityNotFoundException e) {
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
                Log.w("NotificationPlugin", "Notification reply action was cancelled", e);
            }
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

        // Recover still-active notifications that arrived while this Dart
        // engine was reconnecting. Exact recent replays are filtered in Dart.
        NotificationListener service = NotificationListener.getInstance();
        if (service != null) {
            for (Map<String, Object> item : service.getActiveNotificationData()) {
                HashMap<String, Object> replay = new HashMap<>(item);
                replay.put("hasRemoved", false);
                replay.put("canReply", false);
                replay.put("bigText", null);
                replay.put("subText", null);
                replay.put("summaryText", null);
                replay.put("textLines", null);
                replay.put("ticker", null);
                replay.put("onGoing", item.get("onGoing"));
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
            if (resultCode == Activity.RESULT_OK) {
                pendingResult.success(true);
            } else if (resultCode == Activity.RESULT_CANCELED) {
                pendingResult.success(isPermissionGranted(context));
            } else {
                pendingResult.success(false);
            }
            return true;
        }
        return false;
    }
}
