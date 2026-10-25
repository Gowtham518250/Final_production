package notification.listener.service;

import static notification.listener.service.NotificationConstants.*;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import androidx.annotation.RequiresApi;
import io.flutter.plugin.common.EventChannel.EventSink;
import java.util.HashMap;

/** Converts the service's text-only intent into the plugin event payload. */
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
            String packageName = intent.getStringExtra(PACKAGE_NAME);
            String title = intent.getStringExtra(NOTIFICATION_TITLE);
            String content = intent.getStringExtra(NOTIFICATION_CONTENT);
            String bigText = intent.getStringExtra(NOTIFICATION_BIG_TEXT);
            String subText = intent.getStringExtra(NOTIFICATION_SUB_TEXT);
            String summaryText = intent.getStringExtra(NOTIFICATION_SUMMARY_TEXT);
            String textLines = intent.getStringExtra(NOTIFICATION_TEXT_LINES);
            String ticker = intent.getStringExtra(NOTIFICATION_TICKER);
            boolean removed = intent.getBooleanExtra(IS_REMOVED, false);
            boolean canReply = intent.getBooleanExtra(CAN_REPLY, false);
            boolean ongoing = intent.getBooleanExtra(IS_ONGOING, false);
            int id = intent.getIntExtra(ID, -1);

            HashMap<String, Object> data = new HashMap<>();
            data.put("id", id);
            data.put("packageName", packageName);
            data.put("title", title);
            data.put("content", content);
            data.put("bigText", bigText);
            data.put("subText", subText);
            data.put("summaryText", summaryText);
            data.put("textLines", textLines);
            data.put("ticker", ticker);
            data.put("hasRemoved", removed);
            data.put("canReply", canReply);
            data.put("onGoing", ongoing);
            eventSink.success(data);
        } catch (RuntimeException error) {
            Log.e(TAG, "Failed to deliver notification event to Flutter", error);
        }
    }
}
