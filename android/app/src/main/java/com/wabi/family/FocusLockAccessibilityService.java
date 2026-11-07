package com.wabi.family;

import android.accessibilityservice.AccessibilityService;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.view.accessibility.AccessibilityEvent;

import java.util.HashSet;
import java.util.Set;

/**
 * FocusLockAccessibilityService (Hard App Lock Engine).
 * Intercepts prohibited apps (Instagram, TikTok, Games) in real time
 * and launches the Warm Espresso Focus Lock HUD when limits are exceeded.
 */
public class FocusLockAccessibilityService extends AccessibilityService {

    private static FocusLockAccessibilityService instance;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private static final Set<String> lockedPackages = new HashSet<>();
    private static long lastLockTime = 0L;

    public static FocusLockAccessibilityService getInstance() {
        return instance;
    }

    public static boolean isServiceRunning() {
        return instance != null;
    }

    public static synchronized void updateLockedPackages(Set<String> pkgs) {
        lockedPackages.clear();
        if (pkgs != null) {
            lockedPackages.addAll(pkgs);
        }
    }

    public static synchronized void lockPackage(String pkg) {
        lockedPackages.add(pkg);
    }

    public static synchronized void unlockPackage(String pkg) {
        lockedPackages.remove(pkg);
    }

    @Override
    public void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
        loadSavedLocks();
    }

    private void loadSavedLocks() {
        try {
            SharedPreferences sp = getSharedPreferences("wabi_locks", Context.MODE_PRIVATE);
            Set<String> saved = sp.getStringSet("locked_packages", null);
            if (saved != null) {
                lockedPackages.addAll(saved);
            }
        } catch (Throwable ignored) {}
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null || event.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return;
        }

        CharSequence pkgNameChar = event.getPackageName();
        if (pkgNameChar == null) return;
        String currentPkg = pkgNameChar.toString();

        if (getPackageName().equals(currentPkg)) {
            return; // Don't lock WABI itself
        }

        if (isPackageLocked(currentPkg)) {
            triggerLockInterception(currentPkg);
        }
    }

    private boolean isPackageLocked(String pkg) {
        return lockedPackages.contains(pkg);
    }

    private void triggerLockInterception(String blockedPkg) {
        long now = System.currentTimeMillis();
        if (now - lastLockTime < 1500) {
            return; // Debounce
        }
        lastLockTime = now;

        // Perform global home action to kick user out of blocked app
        performGlobalAction(GLOBAL_ACTION_HOME);

        // Launch FocusLockActivity
        handler.postDelayed(() -> {
            try {
                Intent lockIntent = new Intent(this, FocusLockActivity.class);
                lockIntent.putExtra("blocked_pkg", blockedPkg);
                lockIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(lockIntent);
            } catch (Throwable ignored) {}
        }, 150);
    }

    @Override
    public void onInterrupt() {
        // Required callback
    }

    @Override
    public void onDestroy() {
        instance = null;
        super.onDestroy();
    }
}
