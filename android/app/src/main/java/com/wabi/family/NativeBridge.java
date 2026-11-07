package com.wabi.family;

import android.app.AlarmManager;
import android.app.AppOpsManager;
import android.app.PendingIntent;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Process;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.AlarmClock;
import android.provider.Settings;
import android.webkit.JavascriptInterface;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * NativeBridge (@JavascriptInterface window.AndroidNative).
 * Complete native Android integration for App usage, hard locks,
 * system alarms, and settings navigation.
 */
public class NativeBridge {

    private final MainActivity activity;

    public NativeBridge(MainActivity activity) {
        this.activity = activity;
    }

    // ========================================================================
    // PERMISSIONS MANAGEMENT
    // ========================================================================
    @JavascriptInterface
    public boolean hasPermission(String type) {
        if ("usage_stats".equalsIgnoreCase(type) || "usagestats".equalsIgnoreCase(type)) {
            try {
                AppOpsManager appOps = (AppOpsManager) activity.getSystemService(Context.APP_OPS_SERVICE);
                int mode = appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        activity.getPackageName()
                );
                return mode == AppOpsManager.MODE_ALLOWED;
            } catch (Throwable t) {
                return false;
            }
        } else if ("accessibility".equalsIgnoreCase(type)) {
            return FocusLockAccessibilityService.isServiceRunning();
        } else if ("overlay".equalsIgnoreCase(type)) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return Settings.canDrawOverlays(activity);
            }
            return true;
        } else if ("alarm".equalsIgnoreCase(type)) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                AlarmManager am = (AlarmManager) activity.getSystemService(Context.ALARM_SERVICE);
                return am != null && am.canScheduleExactAlarms();
            }
            return true;
        }
        return false;
    }

    @JavascriptInterface
    public void requestPermission(String type) {
        try {
            if ("usage_stats".equalsIgnoreCase(type) || "usagestats".equalsIgnoreCase(type)) {
                Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(intent);
            } else if ("accessibility".equalsIgnoreCase(type)) {
                Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(intent);
            } else if ("overlay".equalsIgnoreCase(type)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Intent intent = new Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:" + activity.getPackageName())
                    );
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(intent);
                }
            } else if ("alarm".equalsIgnoreCase(type)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Intent intent = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM);
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(intent);
                }
            }
        } catch (Throwable t) {
            try {
                Intent intent = new Intent(Settings.ACTION_SETTINGS);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(intent);
            } catch (Throwable ignored) {}
        }
    }

    // ========================================================================
    // 1. getInstalledAppsJson()
    // ========================================================================
    @JavascriptInterface
    public String getInstalledAppsJson() {
        JSONArray arr = new JSONArray();
        try {
            PackageManager pm = activity.getPackageManager();
            Intent mainIntent = new Intent(Intent.ACTION_MAIN, null);
            mainIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> resolveInfos = pm.queryIntentActivities(mainIntent, 0);

            for (ResolveInfo info : resolveInfos) {
                String pkg = info.activityInfo.packageName;
                if (pkg.equals(activity.getPackageName())) continue;

                String label = info.loadLabel(pm).toString();
                JSONObject obj = new JSONObject();
                obj.put("packageName", pkg);
                obj.put("appName", label);
                arr.put(obj);
            }
        } catch (Throwable ignored) {}
        return arr.toString();
    }

    // ========================================================================
    // 2. getUsageStatsJson()
    // ========================================================================
    @JavascriptInterface
    public String getUsageStatsJson() {
        JSONArray arr = new JSONArray();
        if (!hasPermission("usage_stats")) {
            return arr.toString();
        }

        try {
            UsageStatsManager usm = (UsageStatsManager) activity.getSystemService(Context.USAGE_STATS_SERVICE);
            if (usm == null) return arr.toString();

            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.HOUR_OF_DAY, 0);
            cal.set(Calendar.MINUTE, 0);
            cal.set(Calendar.SECOND, 0);
            cal.set(Calendar.MILLISECOND, 0);
            long startOfDay = cal.getTimeInMillis();
            long now = System.currentTimeMillis();

            Map<String, UsageStats> stats = usm.queryAndAggregateUsageStats(startOfDay, now);
            PackageManager pm = activity.getPackageManager();

            for (Map.Entry<String, UsageStats> entry : stats.entrySet()) {
                UsageStats u = entry.getValue();
                long totalMs = u.getTotalTimeInForeground();
                if (totalMs < 15_000) continue; // skip negligible foreground usage

                String pkg = entry.getKey();
                String label = pkg;
                try {
                    ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
                    CharSequence cs = pm.getApplicationLabel(ai);
                    if (cs != null) label = cs.toString();
                } catch (Throwable ignored) {}

                JSONObject obj = new JSONObject();
                obj.put("packageName", pkg);
                obj.put("appName", label);
                obj.put("usedMinutes", totalMs / 60_000L);
                obj.put("lastTimeUsed", u.getLastTimeUsed());
                arr.put(obj);
            }
        } catch (Throwable ignored) {}

        return arr.toString();
    }

    // ========================================================================
    // 3. setAppLimit(String pkg, int maxMinutes)
    // ========================================================================
    @JavascriptInterface
    public void setAppLimit(String pkg, int maxMinutes) {
        try {
            SharedPreferences sp = activity.getSharedPreferences("wabi_limits", Context.MODE_PRIVATE);
            sp.edit().putInt("limit_" + pkg, maxMinutes).apply();

            // Check if app has already exceeded limit
            long currentMinutes = getAppUsedMinutesToday(pkg);
            if (currentMinutes >= maxMinutes && maxMinutes > 0) {
                FocusLockAccessibilityService.lockPackage(pkg);
            } else {
                FocusLockAccessibilityService.unlockPackage(pkg);
            }
        } catch (Throwable ignored) {}
    }

    private long getAppUsedMinutesToday(String targetPkg) {
        try {
            UsageStatsManager usm = (UsageStatsManager) activity.getSystemService(Context.USAGE_STATS_SERVICE);
            if (usm == null) return 0;
            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.HOUR_OF_DAY, 0);
            cal.set(Calendar.MINUTE, 0);
            cal.set(Calendar.SECOND, 0);
            long start = cal.getTimeInMillis();
            Map<String, UsageStats> stats = usm.queryAndAggregateUsageStats(start, System.currentTimeMillis());
            UsageStats u = stats.get(targetPkg);
            return u != null ? (u.getTotalTimeInForeground() / 60_000L) : 0;
        } catch (Throwable t) {
            return 0;
        }
    }

    // ========================================================================
    // 4. setPrayerAlarmsJson(String timingsJson)
    // ========================================================================
    @JavascriptInterface
    public boolean setPrayerAlarmsJson(String timingsJson) {
        try {
            JSONObject obj = new JSONObject(timingsJson);
            String[] prayers = new String[]{"Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"};
            String[] uzNames = new String[]{"Bomdod", "Peshin", "Asr", "Shom", "Xufton"};

            for (int i = 0; i < prayers.length; i++) {
                String pKey = prayers[i];
                if (!obj.has(pKey)) continue;

                String timeStr = obj.getString(pKey); // e.g. "05:15"
                String[] parts = timeStr.split(":");
                int hour = Integer.parseInt(parts[0].trim());
                int min = Integer.parseInt(parts[1].trim());

                try {
                    Intent alarmIntent = new Intent(AlarmClock.ACTION_SET_ALARM);
                    alarmIntent.putExtra(AlarmClock.EXTRA_MESSAGE, "🕌 " + uzNames[i] + " Namozi (WABI)");
                    alarmIntent.putExtra(AlarmClock.EXTRA_HOUR, hour);
                    alarmIntent.putExtra(AlarmClock.EXTRA_MINUTES, min);
                    alarmIntent.putExtra(AlarmClock.EXTRA_SKIP_UI, true);
                    alarmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    activity.startActivity(alarmIntent);
                } catch (Throwable t) {
                    // Fallback to custom PrayerAlarmReceiver via AlarmManager
                    scheduleExactPrayerAlarm(uzNames[i], hour, min);
                }
            }
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    private void scheduleExactPrayerAlarm(String prayerName, int hour, int minute) {
        try {
            AlarmManager am = (AlarmManager) activity.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;

            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.HOUR_OF_DAY, hour);
            cal.set(Calendar.MINUTE, minute);
            cal.set(Calendar.SECOND, 0);

            if (cal.getTimeInMillis() <= System.currentTimeMillis()) {
                cal.add(Calendar.DAY_OF_YEAR, 1);
            }

            Intent intent = new Intent(activity, PrayerAlarmReceiver.class);
            intent.putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName);

            int reqCode = (prayerName + hour + minute).hashCode();
            PendingIntent pi = PendingIntent.getBroadcast(
                    activity, reqCode, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
            );

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.getTimeInMillis(), pi);
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, cal.getTimeInMillis(), pi);
            }
        } catch (Throwable ignored) {}
    }

    // ========================================================================
    // 5. Haptic Feedback & Device Info
    // ========================================================================
    @JavascriptInterface
    public void triggerHaptic(int type) {
        try {
            Vibrator v = (Vibrator) activity.getSystemService(Context.VIBRATOR_SERVICE);
            if (v == null || !v.hasVibrator()) return;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                int effect = VibrationEffect.EFFECT_CLICK;
                if (type == 2) effect = VibrationEffect.EFFECT_HEAVY_CLICK;
                else if (type == 3) effect = VibrationEffect.EFFECT_TICK;
                v.vibrate(VibrationEffect.createPredefined(effect));
            } else {
                v.vibrate(type == 2 ? 40 : 15);
            }
        } catch (Throwable ignored) {}
    }

    @JavascriptInterface
    public String getDeviceModel() {
        return Build.MANUFACTURER + " " + Build.MODEL;
    }
}
