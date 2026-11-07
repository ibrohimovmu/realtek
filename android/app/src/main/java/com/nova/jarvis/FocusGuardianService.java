package com.nova.jarvis;

import android.app.AppOpsManager;
import android.app.usage.UsageStats;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.os.Process;

import org.json.JSONObject;

import java.util.Calendar;
import java.util.List;

/**
 * Helper for UsageStatsManager queries used by Focus Guardian (Instagram 10-Min Blocker)
 * and daily productivity telemetry.
 */
public final class FocusGuardianService {

    private FocusGuardianService() {}

    public static boolean hasUsageStatsPermission(Context context) {
        try {
            AppOpsManager appOps = (AppOpsManager) context.getSystemService(Context.APP_OPS_SERVICE);
            if (appOps == null) return false;
            int mode = appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.getPackageName()
            );
            return mode == AppOpsManager.MODE_ALLOWED;
        } catch (Throwable t) {
            return false;
        }
    }

    public static String getTodayUsageSummaryJson(Context context) {
        JSONObject out = new JSONObject();
        boolean granted = hasUsageStatsPermission(context);
        long instagramMs = 0L;
        long telegramPlusMs = 0L;
        long telegramMs = 0L;
        long youtubeMs = 0L;

        if (granted) {
            try {
                UsageStatsManager usm = (UsageStatsManager) context.getSystemService(Context.USAGE_STATS_SERVICE);
                if (usm != null) {
                    Calendar cal = Calendar.getInstance();
                    cal.set(Calendar.HOUR_OF_DAY, 0);
                    cal.set(Calendar.MINUTE, 0);
                    cal.set(Calendar.SECOND, 0);
                    long startOfDay = cal.getTimeInMillis();
                    long now = System.currentTimeMillis();

                    List<UsageStats> stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now);
                    if (stats != null) {
                        for (UsageStats s : stats) {
                            if (s == null || s.getPackageName() == null) continue;
                            String pkg = s.getPackageName();
                            long fg = s.getTotalTimeInForeground();
                            if ("com.instagram.android".equals(pkg)) {
                                instagramMs += fg;
                            } else if ("org.telegram.plus".equals(pkg)) {
                                telegramPlusMs += fg;
                            } else if ("org.telegram.messenger".equals(pkg)) {
                                telegramMs += fg;
                            } else if ("com.google.android.youtube".equals(pkg)) {
                                youtubeMs += fg;
                            }
                        }
                    }
                }
            } catch (Throwable ignored) {}
        }

        long lockUntilMs = 0L;
        int limitMinutes = 10;
        try {
            NovaMemoryVault vault = NovaMemoryVault.getInstance(context);
            lockUntilMs = Long.parseLong(vault.getMemory("instagram_lock_until_ms", "0"));
            limitMinutes = Integer.parseInt(vault.getMemory("instagram_limit_minutes", "10"));
        } catch (Throwable ignored) {}

        long now = System.currentTimeMillis();
        long lockRemainingSec = lockUntilMs > now ? (lockUntilMs - now) / 1000L : 0L;

        try {
            out.put("usageGranted", granted);
            out.put("instagramMinutesToday", instagramMs / 60000L);
            out.put("telegramPlusMinutesToday", telegramPlusMs / 60000L);
            out.put("telegramMinutesToday", telegramMs / 60000L);
            out.put("youtubeMinutesToday", youtubeMs / 60000L);
            out.put("instagramLimitMinutes", limitMinutes);
            out.put("instagramLocked", lockRemainingSec > 0);
            out.put("instagramLockRemainingSeconds", lockRemainingSec);
        } catch (Throwable ignored) {}

        return out.toString();
    }
}
