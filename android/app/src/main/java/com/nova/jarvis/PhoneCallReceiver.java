package com.nova.jarvis;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.telephony.TelephonyManager;

/**
 * Intercepts incoming phone calls (CALL_STATE_RINGING) for the 6-Gudok Call Secretary
 * and starts the 24/7 Hands-Free Wake-Word service on device boot.
 */
public class PhoneCallReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) return;
        String action = intent.getAction();

        if (Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            boolean handsFree = "true".equals(
                    NovaMemoryVault.getInstance(context).getMemory("hands_free_enabled", "true")
            );
            if (handsFree) {
                Intent svc = new Intent(context, NovaVoiceForegroundService.class);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(svc);
                } else {
                    context.startService(svc);
                }
            }
            return;
        }

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
