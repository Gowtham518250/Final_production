package notification.listener.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import android.os.Build;

/**
 * Receives the explicit in-app notification relay and forwards it to Flutter's
 * temporary EventChannel receiver when one exists. There is no process-wide
 * receiver registration here; events aren't buffered across a missing engine.
 */
public final class NotificationRelayReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        Intent relay = new Intent(NotificationConstants.INTENT);
        relay.setPackage(context.getPackageName());
        relay.putExtras(intent);
        context.sendBroadcast(relay);
    }
}
