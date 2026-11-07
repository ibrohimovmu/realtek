package com.minimal.minimal_launcher

import android.app.Activity
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.Calendar
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "minimal_launcher/apps"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPickResult: MethodChannel.Result? = null
    private val pickImageRequestCode = 9401

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getApps" -> {
                            executor.execute {
                                val apps = try { loadApps() } catch (e: Throwable) { emptyList() }
                                mainHandler.post { result.success(apps) }
                            }
                        }
                        "launch" -> {
                            val pkg = call.argument<String>("package") ?: ""
                            result.success(launchApp(pkg))
                        }
                        "appInfo" -> {
                            val pkg = call.argument<String>("package") ?: ""
                            safeStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))
                            result.success(true)
                        }
                        "uninstall" -> {
                            val pkg = call.argument<String>("package") ?: ""
                            safeStart(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
                            result.success(true)
                        }
                        "expandNotifications" -> {
                            result.success(expandNotifications())
                        }
                        "openWallpaperSettings" -> {
                            safeStart(Intent(Settings.ACTION_HOME_SETTINGS))
                            result.success(true)
                        }
                        "getSystemInfo" -> {
                            result.success(getSystemInfo())
                        }
                        "hasUsagePermission" -> {
                            result.success(hasUsagePermission())
                        }
                        "openUsageSettings" -> {
                            safeStart(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(true)
                        }
                        "getUsageStats" -> {
                            executor.execute {
                                val stats = try { querySystemUsage() } catch (e: Throwable) { emptyMap<String, Any>() }
                                mainHandler.post { result.success(stats) }
                            }
                        }
                        "pickImage" -> {
                            pickWallpaperImage(result)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Throwable) {
                    result.success(null)
                }
            }
    }

    private fun pickWallpaperImage(result: MethodChannel.Result) {
        try {
            pendingPickResult?.success(null)
            pendingPickResult = result
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(Intent.createChooser(intent, "Orqa fon rasmini tanlang"), pickImageRequestCode)
        } catch (e: Throwable) {
            pendingPickResult = null
            result.success(null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickImageRequestCode) {
            val res = pendingPickResult
            pendingPickResult = null
            if (res == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                res.success(null)
                return
            }
            val uri = data.data!!
            executor.execute {
                val savedPath = try { copyAndScaleWallpaper(uri) } catch (e: Throwable) { null }
                mainHandler.post { res.success(savedPath) }
            }
        }
    }

    private fun copyAndScaleWallpaper(uri: Uri): String? {
        val input = contentResolver.openInputStream(uri) ?: return null
        val raw = BitmapFactory.decodeStream(input)
        input.close()
        if (raw == null) return null
        val maxW = 1080
        val maxH = 1920
        val ratio = minOf(maxW.toFloat() / raw.width, maxH.toFloat() / raw.height, 1.0f)
        val w = (raw.width * ratio).toInt().coerceAtLeast(1)
        val h = (raw.height * ratio).toInt().coerceAtLeast(1)
        val scaled = if (ratio < 1.0f) Bitmap.createScaledBitmap(raw, w, h, true) else raw
        val outFile = File(filesDir, "custom_wallpaper_${System.currentTimeMillis()}.jpg")
        // Remove older custom wallpapers
        filesDir.listFiles()?.forEach {
            if (it.name.startsWith("custom_wallpaper_")) {
                try { it.delete() } catch (_: Throwable) {}
            }
        }
        FileOutputStream(outFile).use { out ->
            scaled.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }
        return outFile.absolutePath
    }

    private fun getSystemInfo(): Map<String, Any> {
        var battery = 85
        var charging = false
        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (bm != null) {
                val lvl = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (lvl in 1..100) battery = lvl
                charging = bm.isCharging
            }
        } catch (_: Throwable) {}

        var ramUsedMb = 0L
        var ramTotalMb = 4096L
        var ramPercent = 45
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (am != null) {
                val mi = ActivityManager.MemoryInfo()
                am.getMemoryInfo(mi)
                ramTotalMb = (mi.totalMem / (1024 * 1024)).coerceAtLeast(1L)
                ramUsedMb = ((mi.totalMem - mi.availMem) / (1024 * 1024)).coerceAtLeast(0L)
                ramPercent = ((ramUsedMb * 100L) / ramTotalMb).toInt().coerceIn(1, 99)
            }
        } catch (_: Throwable) {}

        return mapOf(
            "battery" to battery,
            "charging" to charging,
            "ramUsedMb" to ramUsedMb,
            "ramTotalMb" to ramTotalMb,
            "ramPercent" to ramPercent,
            "device" to (Build.MODEL ?: "Android")
        )
    }

    @Suppress("DEPRECATION")
    private fun hasUsagePermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            false
        }
    }

    private fun querySystemUsage(): Map<String, Any> {
        if (!hasUsagePermission()) return mapOf("granted" to false)
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf("granted" to false)

        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDay = cal.timeInMillis

        val statsList = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now) ?: emptyList()
        val totals = HashMap<String, Long>()
        val lastUsed = HashMap<String, Long>()
        for (st in statsList) {
            val pkg = st.packageName ?: continue
            if (pkg == packageName) continue
            val fg = st.totalTimeInForeground
            if (fg > 0) {
                totals[pkg] = (totals[pkg] ?: 0L) + fg
            }
            if (st.lastTimeUsed > (lastUsed[pkg] ?: 0L)) {
                lastUsed[pkg] = st.lastTimeUsed
            }
        }

        // Also collect recent foreground events from the last 12 hours
        val eventsOut = ArrayList<Map<String, Any>>()
        try {
            val events = usm.queryEvents(now - 12L * 3600L * 1000L, now)
            val ev = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(ev)
                if (ev.eventType == UsageEvents.Event.ACTIVITY_RESUMED && ev.packageName != null && ev.packageName != packageName) {
                    eventsOut.add(
                        mapOf(
                            "package" to ev.packageName,
                            "timestamp" to ev.timeStamp
                        )
                    )
                }
            }
        } catch (_: Throwable) {}

        // Keep last 80 events in reverse chronological order
        eventsOut.reverse()
        val trimmedEvents = if (eventsOut.size > 80) eventsOut.subList(0, 80) else eventsOut

        return mapOf(
            "granted" to true,
            "totalsMs" to totals,
            "lastUsedMs" to lastUsed,
            "events" to trimmedEvents
        )
    }

    private fun safeStart(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Throwable) {
            false
        }
    }

    private fun launchApp(pkg: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        return safeStart(intent)
    }

    @Suppress("DEPRECATION")
    private fun loadApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val infos: List<ResolveInfo> = pm.queryIntentActivities(intent, 0)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any>>()
        for (info in infos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seen.add(pkg)) continue
            val label = try { info.loadLabel(pm).toString() } catch (e: Throwable) { pkg }
            val icon = try { drawableToPng(info.loadIcon(pm)) } catch (e: Throwable) { ByteArray(0) }
            out.add(mapOf("label" to label, "package" to pkg, "icon" to icon))
        }
        out.sortBy { (it["label"] as String).lowercase() }
        return out
    }

    private fun drawableToPng(drawable: Drawable): ByteArray {
        val size = 96
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    private fun expandNotifications(): Boolean {
        return try {
            val service = getSystemService("statusbar") ?: return false
            val clazz = Class.forName("android.app.StatusBarManager")
            clazz.getMethod("expandNotificationsPanel").invoke(service)
            true
        } catch (e: Throwable) {
            false
        }
    }
}
