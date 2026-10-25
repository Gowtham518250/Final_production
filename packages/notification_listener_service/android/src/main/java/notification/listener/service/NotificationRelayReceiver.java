package notification.listener.service;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * App-scoped relay target for text-only notification events emitted by
 * NotificationListener. The Flutter EventChannel receiver is registered
 * separately by the plugin when Dart is actively listening.
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
