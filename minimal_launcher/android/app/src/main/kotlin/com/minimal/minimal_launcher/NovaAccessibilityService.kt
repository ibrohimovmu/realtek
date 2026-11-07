package com.minimal.minimal_launcher

import android.accessibilityservice.AccessibilityService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Lightweight, strictly-scoped Accessibility helper for Nova AI Assistant.
 * ONLY acts within 6 seconds after the user explicitly instructs Nova AI to send a Telegram message.
 * When Telegram opens the target chat with the pre-filled text (or empty input field),
 * it ensures the message text is filled and taps the "Send" / "Yuborish" / "Отправить" button once.
 */
class NovaAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: NovaAccessibilityService? = null

        @Volatile
        var pendingText: String? = null

        @Volatile
        var pendingArmedAtMs: Long = 0L

        @Volatile
        var autoSendTriggered: Boolean = false

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

        fun armAutoSend(message: String) {
            pendingText = message.trim()
            pendingArmedAtMs = System.currentTimeMillis()
            autoSendTriggered = false
        }

        fun disarm() {
            pendingText = null
            pendingArmedAtMs = 0L
            autoSendTriggered = true
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val msg = pendingText ?: return
        if (msg.isEmpty() || autoSendTriggered) return

        val elapsed = System.currentTimeMillis() - pendingArmedAtMs
        if (elapsed > 6500L) {
            disarm()
            return
        }

        val pkg = event?.packageName?.toString() ?: return
        if (!telegramPackages.contains(pkg) && !pkg.contains("telegram", ignoreCase = true)) {
            return
        }

        // Wait a short beat for Telegram's chat composer to settle, then locate Send button
        handler.postDelayed({
            tryPerformTelegramSend(msg)
        }, 420L)
    }

    private fun tryPerformTelegramSend(msg: String) {
        if (autoSendTriggered) return
        val elapsed = System.currentTimeMillis() - pendingArmedAtMs
        if (elapsed > 6500L) {
            disarm()
            return
        }

        val root = rootInActiveWindow ?: return

        // 1. Check if there is an editable text field; if it's empty, fill it with `msg`
        val editNodes = ArrayList<AccessibilityNodeInfo>()
        collectNodes(root, editNodes) { node ->
            node.isEditable || (node.className?.toString()?.contains("EditText", ignoreCase = true) == true)
        }

        for (edit in editNodes) {
            val current = edit.text?.toString()?.trim() ?: ""
            if (current.isEmpty() || !current.contains(msg.take(8), ignoreCase = true)) {
                val args = Bundle()
                args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, msg)
                edit.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            }
        }

        // 2. Find the Send button ("Send", "Yuborish", "Отправить", "Jo'natish")
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
                break
            }
        }
    }

    private fun clickNodeOrParent(node: AccessibilityNodeInfo?): Boolean {
        var cur = node
        var depth = 0
        while (cur != null && depth < 4) {
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
}
