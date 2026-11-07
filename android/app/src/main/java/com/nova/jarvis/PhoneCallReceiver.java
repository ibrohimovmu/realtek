package com.nova.jarvis;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.telephony.TelephonyManager;

/**
 * Intercepts incoming phone calls (CALL_STATE_RINGING) for the 6-Gudok Call Secretary.
 * Does NOT start any background microphone service so the microphone is never locked.
 */
public class PhoneCallReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        String action = intent.getAction();

        if (TelephonyManager.ACTION_PHONE_STATE_CHANGED.equals(action)) {
            String state = intent.getStringExtra(TelephonyManager.EXTRA_STATE);
            String incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER);

            Intent secIntent = new Intent(context, NovaCallSecretaryService.class);
            secIntent.putExtra("call_state", state == null ? "" : state);
            secIntent.putExtra("incoming_number", incomingNumber == null ? "" : incomingNumber);

            try {
                if (TelephonyManager.EXTRA_STATE_RINGING.equals(state)) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(secIntent);
                    } else {
                        context.startService(secIntent);
                    }
                } else {
                    context.startService(secIntent);
                }
            } catch (Throwable ignored) {}
        }
    }
}
