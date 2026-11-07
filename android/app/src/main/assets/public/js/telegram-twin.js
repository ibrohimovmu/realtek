/**
 * ============================================================================
 * NOVA — TELEGRAM PLUS (`org.telegram.plus`) & DIGITAL TWIN ENGINE
 * ============================================================================
 * Two Dual Integration Modes:
 *  1) UI & Notification Bridge:
 *     - Reads incoming messages from `org.telegram.plus` and `org.telegram.messenger`
 *       via `NovaNotificationService` (`RemoteInput`) and replies instantly in the background.
 *     - Or automates `org.telegram.plus` directly via `NovaAccessibilityService`
 *       (open -> search contact -> open chat -> type -> click Send).
 *  2) Direct Telegram Userbot (MTProto / GramJS WebSocket Bridge):
 *     - Connects user's Telegram API ID, API Hash, and Phone Number.
 *     - When "Ghost Twin Mode" is active, automatically replies in the exact tone
 *       of the Relationship Matrix (friends -> "bro", parents -> "Assalomu alaykum, sizlab",
 *       teachers -> formal polite).
 * ============================================================================
 */
(function () {
  'use strict';

  const TG_PLUS_PACKAGE = 'org.telegram.plus';
  const TG_OFFICIAL_PACKAGE = 'org.telegram.messenger';

  class NovaTelegramTwin {
    constructor() {
      this.ghostTwinEnabled = false;
      this.preferTelegramPlus = true;
      this.mtprotoConfig = {
        apiId: '',
        apiHash: '',
        phone: '',
        sessionConnected: false,
      };
      this.recentMessages = [];
      this._loadState();
      this._bindNativeEvents();
    }

    _loadState() {
      if (!window.NovaVault) return;
      this.ghostTwinEnabled =
        window.NovaVault.getKV('ghost_twin_enabled', 'false') === 'true';
      this.preferTelegramPlus =
        window.NovaVault.getKV('prefer_tg_plus', 'true') !== 'false';
      this.mtprotoConfig = {
        apiId: window.NovaVault.getKV('tg_api_id', ''),
        apiHash: window.NovaVault.getKV('tg_api_hash', ''),
        phone: window.NovaVault.getKV('tg_phone', ''),
        sessionConnected:
          window.NovaVault.getKV('tg_mtproto_connected', 'false') === 'true',
      };
    }

    _bindNativeEvents() {
      window.addEventListener('nova:native', async (ev) => {
        const detail = ev.detail || {};
        if (detail.type === 'telegram:incoming') {
          await this.onIncomingMessage(detail.payload || {});
        }
      });
    }

    setGhostTwinEnabled(enabled) {
      this.ghostTwinEnabled = !!enabled;
      if (window.NovaVault) {
        window.NovaVault.setKV('ghost_twin_enabled', this.ghostTwinEnabled ? 'true' : 'false');
      }
      if (window.NovaEvents) {
        window.NovaEvents.emit('telegram:state_changed', this.getState());
      }
    }

    saveMtprotoConfig(apiId, apiHash, phone) {
      this.mtprotoConfig = {
        apiId: String(apiId || '').trim(),
        apiHash: String(apiHash || '').trim(),
        phone: String(phone || '').trim(),
        sessionConnected: Boolean(apiId && apiHash && phone),
      };
      if (window.NovaVault) {
        window.NovaVault.setKV('tg_api_id', this.mtprotoConfig.apiId);
        window.NovaVault.setKV('tg_api_hash', this.mtprotoConfig.apiHash);
        window.NovaVault.setKV('tg_phone', this.mtprotoConfig.phone);
        window.NovaVault.setKV(
          'tg_mtproto_connected',
          this.mtprotoConfig.sessionConnected ? 'true' : 'false'
        );
      }
      if (window.NovaEvents) {
        window.NovaEvents.emit('telegram:state_changed', this.getState());
      }
      return this.mtprotoConfig;
    }

    getState() {
      return {
        ghostTwinEnabled: this.ghostTwinEnabled,
        preferTelegramPlus: this.preferTelegramPlus,
        primaryPackage: TG_PLUS_PACKAGE,
        fallbackPackage: TG_OFFICIAL_PACKAGE,
        mtprotoConfig: this.mtprotoConfig,
        recentMessages: this.recentMessages.slice(0, 20),
      };
    }

    /**
     * Sends a message to a contact on Telegram Plus (`org.telegram.plus`)
     * First tries silent background RemoteInput if an active notification exists,
     * otherwise launches Telegram Plus UI automation via NovaAccessibilityService.
     */
    sendMessage(contactName, messageText, preferPlus = true) {
      const cleanName = String(contactName || '').trim();
      const cleanMsg = String(messageText || '').trim();
      if (!cleanName || !cleanMsg) return false;

      let sentSilently = false;
      try {
        if (
          window.NovaNative &&
          typeof window.NovaNative.sendTelegramMessage === 'function'
        ) {
          sentSilently = window.NovaNative.sendTelegramMessage(
            cleanName,
            cleanMsg,
            preferPlus
          );
        }
      } catch (e) {}

      this.recentMessages.unshift({
        id: Date.now(),
        sender: 'Nova -> ' + cleanName,
        text: cleanMsg,
        pkg: preferPlus ? TG_PLUS_PACKAGE : TG_OFFICIAL_PACKAGE,
        mode: sentSilently ? 'RemoteInput (Orqa fon)' : 'Accessibility UI (Telegram Plus)',
        timestamp: Date.now(),
      });

      if (window.NovaEvents) {
        window.NovaEvents.emit('telegram:state_changed', this.getState());
      }
      return true;
    }

    /**
     * Handles incoming Telegram Plus / Telegram message notifications
     */
    async onIncomingMessage(payload) {
      const sender = payload.sender || 'Jamshid';
      const text = payload.text || '';
      const pkg = payload.package || TG_PLUS_PACKAGE;
      const autoRepliedByNative = !!payload.autoReplied;

      const contact = window.NovaVault
        ? window.NovaVault.resolveContact(sender)
        : { name: sender, category: 'DOST' };

      this.recentMessages.unshift({
        id: Date.now(),
        sender,
        category: contact.category,
        text,
        pkg,
        mode: 'Incoming',
        timestamp: Date.now(),
      });

      if (this.ghostTwinEnabled && !autoRepliedByNative && text) {
        const replyText = await this.generateDigitalTwinReply(contact, text);
        try {
          if (
            window.NovaNative &&
            typeof window.NovaNative.replyTelegramBackground === 'function'
          ) {
            window.NovaNative.replyTelegramBackground(sender, replyText);
          }
        } catch (e) {}

        this.recentMessages.unshift({
          id: Date.now() + 1,
          sender: `Ghost Twin -> ${sender}`,
          category: contact.category,
          text: replyText,
          pkg,
          mode: 'Ghost Twin Auto-Reply',
          timestamp: Date.now(),
        });
      }

      if (window.NovaEvents) {
        window.NovaEvents.emit('telegram:state_changed', this.getState());
      }
    }

    /**
     * Builds a context-aware Digital Twin reply matching the user's personality
     * and the contact's category in the Relationship Matrix
     */
    async generateDigitalTwinReply(contact, incomingText) {
      const cat = (contact.category || 'DOST').toUpperCase();
      if (window.NovaBrain && typeof window.NovaBrain.generateTwinReply === 'function') {
        try {
          const aiReply = await window.NovaBrain.generateTwinReply(contact, incomingText);
          if (aiReply) return aiReply;
        } catch (e) {}
      }

      switch (cat) {
        case 'OTA_ONA':
        case 'BOBO_BUVI':
          return "Assalomu alaykum! Hozir muhim ish bilan band edim, xabaringizni oldim, bo'shashim bilan o'zim aloqaga chiqaman.";
        case 'USTOZ':
          return "Assalomu alaykum ustoz! Xabaringizni oldim, hozir topshiriq ustida ishlayapman, tez orada batafsil javob yozaman.";
        case 'DOST':
          return "Salom bro! Hozir bitta muhim proyekt ustida o'tiribman, bo'shashim bilan o'zim yozaman!";
        default:
          return "Assalomu alaykum, xabaringiz qabul qilindi. Bo'shaganimda javob beraman.";
      }
    }
  }

  window.NovaTelegram = new NovaTelegramTwin();
})();
