package com.nova.jarvis;

import android.app.Notification;
import android.app.PendingIntent;
import android.app.RemoteInput;
import android.content.Intent;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

import org.json.JSONObject;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Intercepts incoming messages from:
 *  - Telegram Plus (org.telegram.plus) — Primary Messenger
 *  - Standard Telegram (org.telegram.messenger)
 *  - WhatsApp (com.whatsapp)
 *  - Instagram Direct (com.instagram.android)
 *
 * When "Ghost Twin Mode" (Digital Twin Auto-Reply) is active, replies directly in the background
 * via RemoteInput using the sender's Relationship Matrix category (respectful "siz" for parents/teachers,
 * friendly "bro" for friends).
 */
public class NovaNotificationService extends NotificationListenerService {

    private static NovaNotificationService instance;

    private static class ReplyActionHolder {
        final PendingIntent pendingIntent;
        final RemoteInput[] remoteInputs;

        ReplyActionHolder(PendingIntent pi, RemoteInput[] ri) {
            this.pendingIntent = pi;
            this.remoteInputs = ri;
        }
    }

    private final Map<String, ReplyActionHolder> activeReplyTargets = new ConcurrentHashMap<>();

    public static NovaNotificationService getInstance() {
        return instance;
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
    }

    @Override
    public void onListenerDisconnected() {
        instance = null;
        super.onListenerDisconnected();
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null) return;
        String pkg = sbn.getPackageName();
        if (pkg == null) return;

        boolean isTelegramPlus = "org.telegram.plus".equals(pkg);
        boolean isTelegram = "org.telegram.messenger".equals(pkg) || "org.thunderdog.challegram".equals(pkg);
        boolean isWhatsApp = "com.whatsapp".equals(pkg);
        boolean isInstagram = "com.instagram.android".equals(pkg);

        if (!isTelegramPlus && !isTelegram && !isWhatsApp && !isInstagram) {
            return;
        }

        Notification notif = sbn.getNotification();
        if (notif == null || notif.extras == null) return;
        if ((notif.flags & Notification.FLAG_GROUP_SUMMARY) != 0) return;

        CharSequence titleCs = notif.extras.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence textCs = notif.extras.getCharSequence(Notification.EXTRA_TEXT);
        String sender = titleCs == null ? "" : titleCs.toString().trim();
        String message = textCs == null ? "" : textCs.toString().trim();

        if (sender.isEmpty() || message.isEmpty() || "You".equalsIgnoreCase(sender)) return;

        // Extract RemoteInput reply action if present
        ReplyActionHolder holder = extractReplyAction(notif);
        if (holder != null) {
            activeReplyTargets.put(sender.toLowerCase(), holder);
            activeReplyTargets.put("__latest__", holder);
        }

        // Resolve sender in Relationship Matrix
        NovaMemoryVault vault = NovaMemoryVault.getInstance(this);
        JSONObject profile = vault.resolveCallerProfile(this, sender);
        String category = profile.optString("category", "DOST");

        // Forward live event to Zero-UI / Digital Twin JS engine
        try {
            JSONObject payload = new JSONObject();
            payload.put("package", pkg);
            payload.put("appLabel", isTelegramPlus ? "Telegram Plus" : (isTelegram ? "Telegram" : (isWhatsApp ? "WhatsApp" : "Instagram")));
            payload.put("sender", sender);
            payload.put("message", message);
            payload.put("category", category);
            payload.put("canReplyInline", holder != null);
            MainActivity.notifyJsEvent("onIncomingMessengerNotification", payload.toString());
        } catch (Throwable ignored) {}

        // If native offline Ghost Twin auto-reply is enabled and JS is asleep, auto-reply immediately
        boolean ghostTwinEnabled = "true".equals(vault.getMemory("ghost_twin_enabled", "false"));
        if (ghostTwinEnabled && holder != null && !MainActivity.isWebViewActive()) {
            String autoReply = buildTwinAutoReply(category, sender, message, vault.getMemory("owner_name", "Muhammadnosir"));
            sendInlineReply(sender, autoReply);
        }
    }

    public boolean sendInlineReply(String senderOrLatest, String replyText) {
        if (replyText == null || replyText.trim().isEmpty()) return false;
        String key = (senderOrLatest == null || senderOrLatest.isEmpty())
                ? "__latest__" : senderOrLatest.toLowerCase().trim();
        ReplyActionHolder holder = activeReplyTargets.get(key);
        if (holder == null) {
            holder = activeReplyTargets.get("__latest__");
        }
        if (holder == null || holder.pendingIntent == null || holder.remoteInputs == null) {
            return false;
        }

        try {
            Intent intent = new Intent();
            Bundle bundle = new Bundle();
            for (RemoteInput ri : holder.remoteInputs) {
                bundle.putCharSequence(ri.getResultKey(), replyText);
            }
            RemoteInput.addResultsToIntent(holder.remoteInputs, intent, bundle);
            holder.pendingIntent.send(this, 0, intent);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    public static String buildTwinAutoReply(String category, String sender, String incomingMsg, String ownerName) {
        switch (category) {
            case "OTA_ONA":
            case "BOBO_BUVI":
                return "Assalomu alaykum! Hozir muhim ish ustida edim, xabaringizni oldim. Ozginadan keyin o'zim aloqaga chiqaman 🙏";
            case "USTOZ":
                return "Assalomu alaykum Ustoz! Xabaringizni qabul qildim, hozir topshiriq ustida ishlayapman, tez orada javobini yuboraman.";
            case "DOST":
                return "Salom bro! Hozir ozgina bandroqman, bo'shashim bilan yozaman 🤝";
            default:
                return "Assalomu alaykum, xabaringiz qabul qilindi. Tez orada javob qaytaraman.";
        }
    }

    private ReplyActionHolder extractReplyAction(Notification notif) {
        if (notif.actions == null) return null;
        for (Notification.Action action : notif.actions) {
            if (action == null || action.getRemoteInputs() == null) continue;
            RemoteInput[] inputs = action.getRemoteInputs();
            if (inputs.length > 0 && action.actionIntent != null) {
                return new ReplyActionHolder(action.actionIntent, inputs);
            }
        }
        return null;
    }
}
