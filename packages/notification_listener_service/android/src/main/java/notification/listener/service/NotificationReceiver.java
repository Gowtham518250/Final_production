package notification.listener.service;

import static notification.listener.service.NotificationConstants.*;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

import androidx.annotation.RequiresApi;

import io.flutter.plugin.common.EventChannel.EventSink;

import java.util.HashMap;

/** Converts the app-private text-only relay event into a Flutter stream event. */
public class NotificationReceiver extends BroadcastReceiver {
    private static final String TAG = "NotificationReceiver";
    private final EventSink eventSink;

    public NotificationReceiver(EventSink eventSink) {
        this.eventSink = eventSink;
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR2)
    @Override
    public void onReceive(Context context, Intent intent) {
        if (eventSink == null || intent == null) return;
        try {
            HashMap<String, Object> data = new HashMap<>();
            data.put("id", intent.getIntExtra(ID, -1));
            data.put("eventKey", intent.getStringExtra(EVENT_KEY));
            data.put("packageName", intent.getStringExtra(PACKAGE_NAME));
            data.put("title", intent.getStringExtra(NOTIFICATION_TITLE));
            data.put("content", intent.getStringExtra(NOTIFICATION_CONTENT));
            data.put("bigText", intent.getStringExtra(NOTIFICATION_BIG_TEXT));
            data.put("subText", intent.getStringExtra(NOTIFICATION_SUB_TEXT));
            data.put("summaryText", intent.getStringExtra(NOTIFICATION_SUMMARY_TEXT));
            data.put("textLines", intent.getStringExtra(NOTIFICATION_TEXT_LINES));
            data.put("ticker", intent.getStringExtra(NOTIFICATION_TICKER));
            data.put("hasRemoved", intent.getBooleanExtra(IS_REMOVED, false));
            data.put("canReply", intent.getBooleanExtra(CAN_REPLY, false));
            data.put("onGoing", intent.getBooleanExtra(IS_ONGOING, false));
            eventSink.success(data);
        } catch (RuntimeException error) {
            Log.e(TAG, "Failed to deliver notification event to Flutter", error);
        }
    }
}
