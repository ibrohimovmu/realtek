package com.nova.jarvis;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.File;
import java.io.InputStreamReader;

/**
 * Privileged Root (su) command executor with automatic non-root fallback detection.
 * Supports:
 *  - Auto-Unlock via keyevent 82 + PIN text + Enter (keyevent 66)
 *  - Force-stopping distracting packages (am force-stop com.instagram.android)
 *  - Answering calls via keyevent 5 (CALL)
 */
public final class RootExecutor {

    private static Boolean cachedRootStatus = null;

    private RootExecutor() {}

    public static boolean isRootAvailable() {
        if (cachedRootStatus != null) {
            return cachedRootStatus;
        }
        String[] paths = {
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/su/bin/su",
            "/magisk/.core/bin/su",
            "/debug_ramdisk/su"
        };
        for (String path : paths) {
            if (new File(path).exists()) {
                cachedRootStatus = true;
                return true;
            }
        }
        cachedRootStatus = false;
        return false;
    }

    public static boolean runRootCommand(String command) {
        Process process = null;
        try {
            process = Runtime.getRuntime().exec("su");
            DataOutputStream os = new DataOutputStream(process.getOutputStream());
            os.writeBytes(command + "\n");
            os.writeBytes("exit\n");
            os.flush();
            int exitValue = process.waitFor();
            return exitValue == 0;
        } catch (Throwable t) {
            return false;
        } finally {
            if (process != null) {
                try {
                    process.destroy();
                } catch (Throwable ignored) {}
            }
        }
    }

    public static String runRootCommandWithOutput(String command) {
        Process process = null;
        try {
            process = Runtime.getRuntime().exec("su");
            DataOutputStream os = new DataOutputStream(process.getOutputStream());
            os.writeBytes(command + "\n");
            os.writeBytes("exit\n");
            os.flush();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                sb.append(line).append("\n");
            }
            process.waitFor();
            return sb.toString().trim();
        } catch (Throwable t) {
            return "";
        } finally {
            if (process != null) {
                try {
                    process.destroy();
                } catch (Throwable ignored) {}
            }
        }
    }

    /**
     * Unlocks the screen using root shell commands:
     * wakes screen (224), opens keyguard (82), types PIN, and presses Enter (66).
     */
    public static boolean unlockScreenViaRoot(String pin) {
        if (!isRootAvailable()) return false;
        String cleanPin = (pin == null) ? "" : pin.replaceAll("[^0-9a-zA-Z]", "");
        String cmd;
        if (cleanPin.isEmpty()) {
            cmd = "input keyevent 224 && input keyevent 82 && input swipe 500 1600 500 400 250";
        } else {
            cmd = "input keyevent 224 && input keyevent 82 && sleep 0.3 && input text "
                    + cleanPin + " && input keyevent 66";
        }
        return runRootCommand(cmd);
    }

    /**
     * Force-stops an application package (e.g., com.instagram.android after 10 minutes).
     */
    public static boolean forceStopPackage(String packageName) {
        if (!isRootAvailable() || packageName == null || packageName.isEmpty()) return false;
        return runRootCommand("am force-stop " + packageName);
    }

    /**
     * Answers an incoming ringing call via root keyevent 5 (KEYCODE_CALL).
     */
    public static boolean acceptRingingCallViaRoot() {
        if (!isRootAvailable()) return false;
        return runRootCommand("input keyevent 5");
    }
}
