package com.wabi.family;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Vibrator;

/**
 * PrayerAlarmReceiver.
 * Triggers prayer call notifications and reminders.
 */
public class PrayerAlarmReceiver extends BroadcastReceiver {

    public static final String CHANNEL_ID = "wabi_prayer_channel";
    public static final String EXTRA_PRAYER_NAME = "prayer_name";

    @Override
    public void onReceive(Context context, Intent intent) {
        String prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME);
        if (prayerName == null || prayerName.isEmpty()) {
            prayerName = "Namoz Vaqti";
        }

        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "WABI Namoz Eslatmalari",
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Namoz vaqtlari bo'yicha bildirishnomalar");
            channel.enableLights(true);
            channel.setLightColor(Color.parseColor("#D4B996"));
            channel.enableVibration(true);
            nm.createNotificationChannel(channel);
        }

        Intent openIntent = new Intent(context, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pi = PendingIntent.getActivity(
                context, 0, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        Uri soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(context, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(context);
        }

        builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("🕌 " + prayerName + " vaqti kirdi")
                .setContentText("Alloh uchun qilingan ibodat har qanday ishdan afzaldir.")
                .setContentIntent(pi)
                .setAutoCancel(true)
                .setSound(soundUri)
                .setPriority(Notification.PRIORITY_HIGH);

        nm.notify((int) System.currentTimeMillis(), builder.build());

        try {
            Vibrator vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                vibrator.vibrate(new long[]{0, 500, 200, 500}, -1);
            }
        } catch (Throwable ignored) {}
    }
}
