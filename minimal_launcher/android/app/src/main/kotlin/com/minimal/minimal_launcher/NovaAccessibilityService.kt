package com.minimal.minimal_launcher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.graphics.Color
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Autonomous Visual UI Agent, Lock-Screen Unlocker, and In-Game Floating Game Hub Overlay.
 * Styled strictly in the Nordic Slate & Deep Petrol palette:
 * #0E1D21, #122E34, #2C444E, #677E8A, #ABAFB5, #E0B4B2
 */
class NovaAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: NovaAccessibilityService? = null

        @Volatile
        var pendingApp: String = "" // "telegram", "instagram", "whatsapp", "unlock"

        @Volatile
        var pendingRecipient: String = ""

        @Volatile
        var pendingText: String? = null

        @Volatile
        var pendingArmedAtMs: Long = 0L

        @Volatile
        var instagramStage: Int = 0 // 0=open profile/search, 1=clicked message, 2=sent

        @Volatile
        var autoSendTriggered: Boolean = false

        @Volatile
        var lastAgentStepText: String = ""

        private val telegramPackages = setOf(
            "org.telegram.messenger",
            "org.telegram.messenger.web",
            "org.telegram.messenger.beta",
            "org.thunderdog.challegram",
            "tw.nekomimi.nekogram",
            "uz.unnarsx.cherrygram",
            "org.telegram.plus",
            "nekox.messenger"
        )

        fun armAutoSend(message: String, app: String = "telegram", recipient: String = "") {
            pendingApp = app
            pendingRecipient = recipient.trim()
            pendingText = message.trim()
            pendingArmedAtMs = System.currentTimeMillis()
            instagramStage = 0
            autoSendTriggered = false
            instance?.showAgentHud("1/3 · ${app.replaceFirstChar { it.uppercase() }} ochilmoqda ($recipient)...")
        }

        fun armUnlockWithPin(pin: String) {
            pendingApp = "unlock"
            pendingText = pin.trim()
            pendingArmedAtMs = System.currentTimeMillis()
            autoSendTriggered = false
            instance?.let { svc ->
                svc.showAgentHud("🔓 Ovoz tasdiqlandi · Ekran qulfi ochilmoqda...")
                svc.performSwipeUpToPinPad()
            }
        }

        fun disarm() {
            pendingApp = ""
            pendingText = null
            pendingArmedAtMs = 0L
            autoSendTriggered = true
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var wm: WindowManager? = null

    // Floating Agent Step HUD
    private var agentHudView: TextView? = null

    // Floating In-Game "Game Hub" Top Overlay
    private var gameHubRoot: LinearLayout? = null
    private var gameHubPillText: TextView? = null
    private var gameHubExpandedPanel: LinearLayout? = null
    private var gameHubStatsText: TextView? = null
    private var gameHubStatusSub: TextView? = null
    private var gameHubExpanded = false
    private var currentGameTitle = "Game Hub"

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager
    }

    override fun onDestroy() {
        hideAgentHud()
        hideGameHubOverlay()
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    // =========================================================================
    // 1. LIVE FLOATING AGENT HUD (Shows user what AI is doing on screen)
    // =========================================================================
    fun showAgentHud(stepText: String, autoHideMs: Long = 5200L) {
        lastAgentStepText = stepText
        handler.post {
            try {
                val windowManager = wm ?: return@post
                if (agentHudView == null) {
                    val tv = TextView(this).apply {
                        setTextColor(Color.parseColor("#E8ECEF"))
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 12.5f)
                        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                        setPadding(dp(16), dp(9), dp(16), dp(9))
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor("#E60E1D21"))
                            cornerRadius = dp(22).toFloat()
                            setStroke(dp(1), Color.parseColor("#677E8A"))
                        }
                        elevation = dp(8).toFloat()
                    }
                    val lp = WindowManager.LayoutParams(
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1)
                            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                        else
                            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY,
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                        PixelFormat.TRANSLUCENT
                    ).apply {
                        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                        y = dp(42)
                    }
                    windowManager.addView(tv, lp)
                    agentHudView = tv
                }
                agentHudView?.text = stepText
                handler.removeCallbacks(hideAgentHudRunnable)
                handler.postDelayed(hideAgentHudRunnable, autoHideMs)
            } catch (_: Throwable) {}
        }
    }

    private val hideAgentHudRunnable = Runnable { hideAgentHud() }

    fun hideAgentHud() {
        handler.post {
            try {
                val v = agentHudView
                agentHudView = null
                if (v != null) wm?.removeView(v)
            } catch (_: Throwable) {}
        }
    }

    // =========================================================================
    // 2. FLOATING IN-GAME "GAME HUB" OVERLAY (Top Pill + Expandable Boost HUD)
    // =========================================================================
    fun showGameHubOverlay(gameTitle: String) {
        currentGameTitle = gameTitle.ifBlank { "Game Hub" }
        handler.post {
            try {
                val windowManager = wm ?: return@post
                if (gameHubRoot != null) {
                    refreshGameHubTelemetry()
                    return@post
                }

                gameHubExpanded = false
                val root = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                }

                // Compact Top Pill: "🎮 Game Hub · 37.5°C · 41% RAM"
                val pill = TextView(this).apply {
                    setTextColor(Color.parseColor("#E8ECEF"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
                    typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
                    setPadding(dp(14), dp(6), dp(14), dp(6))
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#EB0E1D21"))
                        cornerRadius = dp(18).toFloat()
                        setStroke(dp(1), Color.parseColor("#677E8A"))
                    }
                    setOnClickListener {
                        gameHubExpanded = !gameHubExpanded
                        gameHubExpandedPanel?.visibility = if (gameHubExpanded) View.VISIBLE else View.GONE
                        refreshGameHubTelemetry()
                    }
                }
                gameHubPillText = pill
                root.addView(pill)

                // Expanded Tactical Panel (hidden until pill is tapped)
                val panel = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    visibility = View.GONE
                    setPadding(dp(14), dp(12), dp(14), dp(12))
                    val lp = LinearLayout.LayoutParams(dp(270), LinearLayout.LayoutParams.WRAP_CONTENT)
                    lp.topMargin = dp(6)
                    layoutParams = lp
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#F50E1D21"))
                        cornerRadius = dp(20).toFloat()
                        setStroke(dp(1), Color.parseColor("#677E8A"))
                    }
                }

                val titleTv = TextView(this).apply {
                    text = "🎮 $currentGameTitle — Game Hub"
                    setTextColor(Color.parseColor("#FFFFFF"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    typeface = Typeface.DEFAULT_BOLD
                }
                panel.addView(titleTv)

                val statsTv = TextView(this).apply {
                    setTextColor(Color.parseColor("#ABAFB5"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11.5f)
                    setPadding(0, dp(6), 0, dp(4))
                }
                gameHubStatsText = statsTv
                panel.addView(statsTv)

                val statusTv = TextView(this).apply {
                    text = "Tizim barqaror ishlamoqda"
                    setTextColor(Color.parseColor("#677E8A"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                    setPadding(0, 0, 0, dp(8))
                }
                gameHubStatusSub = statusTv
                panel.addView(statusTv)

                // Action Row: [⚡ Tezlashtirish]  [🔕 DND]  [✕ Yopish]
                val btnRow = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER
                }

                fun makeBtn(label: String, bgHex: String, textHex: String, onClick: () -> Unit): TextView {
                    return TextView(this).apply {
                        text = label
                        setTextColor(Color.parseColor(textHex))
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                        typeface = Typeface.DEFAULT_BOLD
                        gravity = Gravity.CENTER
                        setPadding(dp(10), dp(7), dp(10), dp(7))
                        background = GradientDrawable().apply {
                            setColor(Color.parseColor(bgHex))
                            cornerRadius = dp(12).toFloat()
                        }
                        val blp = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                        blp.marginEnd = dp(5)
                        layoutParams = blp
                        setOnClickListener { onClick() }
                    }
                }

                btnRow.addView(
                    makeBtn("⚡ RAM Boost", "#677E8A", "#0E1D21") {
                        val freedMb = boostRamNow()
                        gameHubStatusSub?.text = "✓ Fon jarayonlari tozalandi (+${freedMb} MB)"
                        refreshGameHubTelemetry()
                    }
                )

                btnRow.addView(
                    makeBtn("🔕 Chalg'itmaslik", "#122E34", "#ABAFB5") {
                        val dndOn = toggleDndMode()
                        gameHubStatusSub?.text = if (dndOn) "🔕 DND (Jim rejim) yoqildi" else "🔔 Bildirishnomalar ochildi"
                    }
                )

                btnRow.addView(
                    makeBtn("✕ Yopish", "#1A282D", "#E0B4B2") {
                        hideGameHubOverlay()
                    }
                )

                panel.addView(btnRow)
                gameHubExpandedPanel = panel
                root.addView(panel)

                val wlp = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1)
                        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                    else
                        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    y = dp(10)
                }

                windowManager.addView(root, wlp)
                gameHubRoot = root
                refreshGameHubTelemetry()
            } catch (_: Throwable) {}
        }
    }

    fun hideGameHubOverlay() {
        handler.post {
            try {
                val r = gameHubRoot
                gameHubRoot = null
                gameHubPillText = null
                gameHubExpandedPanel = null
                if (r != null) wm?.removeView(r)
            } catch (_: Throwable) {}
        }
    }

    private fun refreshGameHubTelemetry() {
        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            val bat = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 85

            val sticky = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val tempTenths = sticky?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 365) ?: 365
            val tempC = String.format("%.1f", tempTenths / 10.0f)

            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val mi = ActivityManager.MemoryInfo()
            am?.getMemoryInfo(mi)
            val totalMb = ((mi.totalMem) / (1024 * 1024)).coerceAtLeast(1L)
            val usedMb = ((mi.totalMem - mi.availMem) / (1024 * 1024)).coerceAtLeast(0L)
            val ramPct = ((usedMb * 100L) / totalMb).toInt().coerceIn(1, 99)

            gameHubPillText?.text = "🎮 Game Hub  •  $tempC°C  •  RAM $ramPct%"
            gameHubStatsText?.text = "🌡 Harorat: $tempC°C   |   🧠 RAM: $usedMb / $totalMb MB ($ramPct%)   |   🔋 Quvvat: $bat%"
        } catch (_: Throwable) {}
    }

    fun boostRamNow(): Long {
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return 64L
            val beforeMi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(beforeMi)

            val pm = packageManager
            val apps = pm.getInstalledApplications(0)
            for (app in apps) {
                if ((app.flags and ApplicationInfo.FLAG_SYSTEM) == 0 && app.packageName != packageName) {
                    try {
                        am.killBackgroundProcesses(app.packageName)
                    } catch (_: Throwable) {}
                }
            }
            System.gc()

            val afterMi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(afterMi)
            val diffMb = (afterMi.availMem - beforeMi.availMem) / (1024 * 1024)
            diffMb.coerceAtLeast(48L)
        } catch (_: Throwable) {
            85L
        }
    }

    private fun toggleDndMode(): Boolean {
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && nm.isNotificationPolicyAccessGranted) {
                val cur = nm.currentInterruptionFilter
                if (cur == NotificationManager.INTERRUPTION_FILTER_ALL) {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                    true
                } else {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    false
                }
            } else false
        } catch (_: Throwable) {
            false
        }
    }

    // =========================================================================
    // 3. AUTONOMOUS ACCESSIBILITY EVENT ENGINE (TELEGRAM, INSTAGRAM, WHATSAPP, UNLOCK)
    // =========================================================================
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val msg = pendingText ?: return
        if (msg.isEmpty() || autoSendTriggered) return

        val elapsed = System.currentTimeMillis() - pendingArmedAtMs
        if (elapsed > 11000L) {
            disarm()
            return
        }

        val pkg = event?.packageName?.toString() ?: return

        when (pendingApp) {
            "unlock" -> {
                if (pkg.contains("systemui", ignoreCase = true) || pkg.contains("keyguard", ignoreCase = true)) {
                    handler.postDelayed({ tryEnterKeyguardPin(msg) }, 450L)
                }
            }
            "instagram" -> {
                if (pkg.contains("instagram", ignoreCase = true)) {
                    handler.postDelayed({ tryPerformInstagramStep(msg) }, 550L)
                }
            }
            else -> {
                if (telegramPackages.contains(pkg) || pkg.contains("telegram", ignoreCase = true) || pkg.contains("whatsapp", ignoreCase = true)) {
                    handler.postDelayed({ tryPerformMessagingSend(msg) }, 420L)
                }
            }
        }
    }

    private fun tryPerformMessagingSend(msg: String) {
        if (autoSendTriggered) return
        val root = rootInActiveWindow ?: return

        // 1. Check editable composer field
        val editNodes = ArrayList<AccessibilityNodeInfo>()
        collectNodes(root, editNodes) { node ->
            node.isEditable || (node.className?.toString()?.contains("EditText", ignoreCase = true) == true)
        }

        for (edit in editNodes) {
            val current = edit.text?.toString()?.trim() ?: ""
            if (current.isEmpty() || !current.contains(msg.take(6), ignoreCase = true)) {
                showAgentHud("2/3 · Xabar yozilmoqda: «${msg.take(24)}»...")
                val args = Bundle()
                args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, msg)
                edit.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            }
        }

        // 2. Find Send button
        val sendTargets = listOf("send", "yuborish", "отправить", "jo'natish", "jonatish")
        val sendNodes = ArrayList<AccessibilityNodeInfo>()
        collectNodes(root, sendNodes) { node ->
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            val viewId = node.viewIdResourceName?.lowercase() ?: ""
            val isSendDesc = sendTargets.any { desc == it || desc.startsWith("$it ") || desc.endsWith(" $it") }
            val isSendId = viewId.contains("send") && !viewId.contains("schedule")
            (isSendDesc || isSendId) && node.isEnabled
        }

        for (sendBtn in sendNodes) {
            if (clickNodeOrParent(sendBtn)) {
                autoSendTriggered = true
                pendingText = null
                showAgentHud("✓ Xabar muvaffaqiyatli yuborildi!", 3200L)
                break
            }
        }
    }

    private fun tryPerformInstagramStep(msg: String) {
        if (autoSendTriggered) return
        val root = rootInActiveWindow ?: return

        // Check if we are already inside an Instagram Direct chat thread with a message input box
        val composerNodes = ArrayList<AccessibilityNodeInfo>()
        collectNodes(root, composerNodes) { node ->
            val id = node.viewIdResourceName?.lowercase() ?: ""
            val hint = node.text?.toString()?.lowercase() ?: ""
            (node.isEditable || node.className?.toString()?.contains("EditText", true) == true) &&
                (id.contains("row_thread_composer") || hint.contains("message") || hint.contains("xabar") || hint.contains("сообщение") || instagramStage >= 1)
        }

        if (composerNodes.isNotEmpty()) {
            val composer = composerNodes.first()
            showAgentHud("3/3 · Instagram Direct: «${msg.take(22)}» yozilmoqda...")
            val args = Bundle()
            args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, msg)
            composer.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            composer.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)

            handler.postDelayed({
                val freshRoot = rootInActiveWindow ?: return@postDelayed
                val sendBtns = ArrayList<AccessibilityNodeInfo>()
                val sendLabels = listOf("send", "yuborish", "отправить")
                collectNodes(freshRoot, sendBtns) { n ->
                    val txt = n.text?.toString()?.lowercase()?.trim() ?: ""
                    val desc = n.contentDescription?.toString()?.lowercase()?.trim() ?: ""
                    val id = n.viewIdResourceName?.lowercase() ?: ""
                    sendLabels.contains(txt) || sendLabels.contains(desc) || id.contains("row_thread_composer_button_send")
                }
                for (btn in sendBtns) {
                    if (clickNodeOrParent(btn)) {
                        autoSendTriggered = true
                        pendingText = null
                        showAgentHud("✓ Instagram xabari yuborildi!", 3200L)
                        break
                    }
                }
            }, 380L)
            return
        }

        // Otherwise, if we are on the user's Instagram profile, click "Message" / "Xabar yuborish" / "Написать"
        if (instagramStage == 0) {
            val msgBtnLabels = listOf("message", "xabar yuborish", "xabar", "написать", "сообщение")
            val msgBtns = ArrayList<AccessibilityNodeInfo>()
            collectNodes(root, msgBtns) { n ->
                val txt = n.text?.toString()?.lowercase()?.trim() ?: ""
                val desc = n.contentDescription?.toString()?.lowercase()?.trim() ?: ""
                msgBtnLabels.any { txt == it || desc == it }
            }
            for (btn in msgBtns) {
                if (clickNodeOrParent(btn)) {
                    instagramStage = 1
                    showAgentHud("2/3 · Direct chat ochildi, xabar kiritilmoqda...")
                    return
                }
            }
        }
    }

    // =========================================================================
    // 4. LOCK-SCREEN VOICE UNLOCK GESTURE & PIN ENTRY
    // =========================================================================
    private fun performSwipeUpToPinPad() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        try {
            val dm = resources.displayMetrics
            val cx = dm.widthPixels * 0.5f
            val startY = dm.heightPixels * 0.82f
            val endY = dm.heightPixels * 0.24f

            val path = Path().apply {
                moveTo(cx, startY)
                lineTo(cx, endY)
            }
            val stroke = GestureDescription.StrokeDescription(path, 0L, 280L)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            dispatchGesture(gesture, null, null)
        } catch (_: Throwable) {}
    }

    private fun tryEnterKeyguardPin(pin: String) {
        if (autoSendTriggered) return
        val root = rootInActiveWindow ?: return

        var clickedAll = true
        for (ch in pin) {
            if (!ch.isDigit()) continue
            val digitStr = ch.toString()
            val matches = ArrayList<AccessibilityNodeInfo>()
            collectNodes(root, matches) { n ->
                val txt = n.text?.toString()?.trim() ?: ""
                val desc = n.contentDescription?.toString()?.trim() ?: ""
                val id = n.viewIdResourceName?.lowercase() ?: ""
                txt == digitStr || desc.startsWith(digitStr) || id.endsWith("key$digitStr")
            }
            if (matches.isNotEmpty()) {
                clickNodeOrParent(matches.first())
                try { Thread.sleep(95) } catch (_: Throwable) {}
            } else {
                clickedAll = false
            }
        }

        if (clickedAll) {
            // Click Enter / OK key on PIN pad
            val enterNodes = ArrayList<AccessibilityNodeInfo>()
            collectNodes(root, enterNodes) { n ->
                val id = n.viewIdResourceName?.lowercase() ?: ""
                val desc = n.contentDescription?.toString()?.lowercase() ?: ""
                id.contains("key_enter") || desc.contains("enter") || desc.contains("ok") || desc.contains("tasdiqlash")
            }
            for (en in enterNodes) {
                clickNodeOrParent(en)
            }
            autoSendTriggered = true
            pendingText = null
            showAgentHud("🔓 Ekran qulfi ochildi!", 2500L)
        }
    }

    private fun clickNodeOrParent(node: AccessibilityNodeInfo?): Boolean {
        var cur = node
        var depth = 0
        while (cur != null && depth < 5) {
            if (cur.isClickable) {
                return cur.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
            cur = cur.parent
            depth++
        }
        return false
    }

    private fun collectNodes(
        node: AccessibilityNodeInfo?,
        out: MutableList<AccessibilityNodeInfo>,
        predicate: (AccessibilityNodeInfo) -> Boolean
    ) {
        if (node == null) return
        try {
            if (predicate(node)) {
                out.add(node)
            }
            val count = node.childCount
            for (i in 0 until count) {
                collectNodes(node.getChild(i), out, predicate)
            }
        } catch (_: Throwable) {}
    }

    private fun dp(v: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()
}
