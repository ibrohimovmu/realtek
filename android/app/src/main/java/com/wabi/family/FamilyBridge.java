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
import android.os.Build;
import android.os.Process;
import android.os.VibrationEffect;
import android.os.Vibrator;
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
 * FamilyBridge.
 * JavaScript interface for Native Android System integration.
 */
public class FamilyBridge {

    private final MainActivity activity;

    public FamilyBridge(MainActivity activity) {
        this.activity = activity;
    }

    // ========================================================================
    // USAGE STATS & PERMISSION CHECKS
    // ========================================================================
    @JavascriptInterface
    public boolean isUsageStatsPermissionGranted() {
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
    }

    @JavascriptInterface
    public void openUsageStatsSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Throwable t) {
            try {
                Intent intent = new Intent(Settings.ACTION_SETTINGS);
                activity.startActivity(intent);
            } catch (Throwable ignored) {}
        }
    }

    @JavascriptInterface
    public boolean isAccessibilityEnabled() {
        return FocusLockAccessibilityService.isServiceRunning();
    }

    @JavascriptInterface
    public void openAccessibilitySettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Throwable t) {
            try {
                Intent intent = new Intent(Settings.ACTION_SETTINGS);
                activity.startActivity(intent);
            } catch (Throwable ignored) {}
        }
    }

    // ========================================================================
    // REAL USAGE STATS FOR TODAY
    // ========================================================================
    @JavascriptInterface
    public String getTodayUsageStats() {
        JSONArray arr = new JSONArray();
        if (!isUsageStatsPermissionGranted()) {
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
                long totalTimeMs = u.getTotalTimeInForeground();
                if (totalTimeMs < 30_000) continue; // skip apps used less than 30s

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
                obj.put("usedMinutes", totalTimeMs / 60_000L);
                arr.put(obj);
            }
        } catch (Throwable ignored) {}

        return arr.toString();
    }

    // ========================================================================
    // INSTALLED LAUNCHABLE APPS
    // ========================================================================
    @JavascriptInterface
    public String getInstalledApps() {
        JSONArray arr = new JSONArray();
        try {
            PackageManager pm = activity.getPackageManager();
            Intent mainIntent = new Intent(Intent.ACTION_MAIN, null);
            mainIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            List<android.content.pm.ResolveInfo> resolveInfos = pm.queryIntentActivities(mainIntent, 0);

            for (android.content.pm.ResolveInfo info : resolveInfos) {
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
    // APP LOCKING CONTROL
    // ========================================================================
    @JavascriptInterface
    public void setLockedPackages(String jsonArrayString) {
        try {
            JSONArray arr = new JSONArray(jsonArrayString);
            Set<String> set = new HashSet<>();
            for (int i = 0; i < arr.length(); i++) {
                set.add(arr.getString(i));
            }
            FocusLockAccessibilityService.updateLockedPackages(set);

            SharedPreferences sp = activity.getSharedPreferences("wabi_locks", Context.MODE_PRIVATE);
            sp.edit().putStringSet("locked_packages", set).apply();
        } catch (Throwable ignored) {}
    }

    // ========================================================================
    // PRAYER ALARM SCHEDULER
    // ========================================================================
    @JavascriptInterface
    public void schedulePrayerAlarm(String prayerName, int hour, int minute) {
        try {
            AlarmManager am = (AlarmManager) activity.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;

            Calendar cal = Calendar.getInstance();
            cal.set(Calendar.HOUR_OF_DAY, hour);
            cal.set(Calendar.MINUTE, minute);
            cal.set(Calendar.SECOND, 0);

            if (cal.getTimeInMillis() <= System.currentTimeMillis()) {
                cal.add(Calendar.DAY_OF_YEAR, 1); // Schedule for tomorrow if time already passed
            }

            Intent intent = new Intent(activity, PrayerAlarmReceiver.class);
            intent.putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName);

            int reqCode = (prayerName + hour).hashCode();
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
    // HAPTIC FEEDBACK & DEVICE INFO
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
