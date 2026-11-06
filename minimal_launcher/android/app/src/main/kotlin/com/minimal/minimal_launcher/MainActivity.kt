package com.minimal.minimal_launcher

import android.content.Intent
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "minimal_launcher/apps"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

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
                        else -> result.notImplemented()
                    }
                } catch (e: Throwable) {
                    result.success(null)
                }
            }
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
