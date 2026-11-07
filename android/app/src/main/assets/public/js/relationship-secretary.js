/**
 * ============================================================================
 * NOVA — 6-GUDOK CALL SECRETARY & RELATIONSHIP MATRIX ENGINE
 * ============================================================================
 * Handles:
 *  - Incoming call ring counting (6 rings ≈ 22s -> auto-answer on 7th ring)
 *  - Live caller dialogue tailored by Relationship Matrix category:
 *      * OTA_ONA ("Onam", "Dadam") & BOBO_BUVI ("Bobom", "Buvim") -> Highest respect ("siz")
 *      * USTOZ ("Ustoz") -> Polite, formal student-assistant tone
 *      * DOST ("Jamshid", friends) -> Friendly "bro" tone
 *      * BEGONA (Unknown caller) -> Cautious screening tone
 *  - Audio recording + transcript summary storage
 * ============================================================================
 */
(function () {
  'use strict';

  class NovaCallSecretaryController {
    constructor() {
      this.activeCall = null;
      this.ringTimer = null;
      this._bindNativeEvents();
    }

    _bindNativeEvents() {
      window.addEventListener('nova:native', (ev) => {
        const detail = ev.detail || {};
        const type = detail.type;
        const payload = detail.payload || {};

        if (type === 'call:ringing') {
          this.onIncomingRing(payload);
        } else if (type === 'call:secretary_answered') {
          this.onSecretaryAnswered(payload);
        } else if (type === 'call:secretary_finished') {
          this.onSecretaryFinished(payload);
        }
      });
    }

    onIncomingRing(payload) {
      const ring = Number(payload.ring || 1);
      const maxRings = Number(payload.maxRings || 6);
      const caller = payload.caller || '+998901112233';
      const contact = window.NovaVault
        ? window.NovaVault.resolveContact(caller)
        : { name: caller, category: 'BEGONA' };

      this.activeCall = {
        caller,
        contact,
        ring,
        maxRings,
        state: 'RINGING',
      };

      if (window.NovaEvents) {
        window.NovaEvents.emit('secretary:status', {
          state: 'RINGING',
          ring,
          maxRings,
          callerName: contact.name,
          category: contact.category,
          headline: `${contact.name} (${ring}/${maxRings} gudok)`,
          subtitle: `${maxRings} gudokdan so'ng Nova kotib javob beradi`,
        });
      }
    }

    onSecretaryAnswered(payload) {
      const callerName = payload.callerName || 'Onam';
      const category = payload.category || 'OTA_ONA';
      const greeting =
        payload.greeting ||
        (window.NovaVault
          ? window.NovaVault.buildDefaultGreeting(callerName, category)
          : '');

      this.activeCall = {
        caller: payload.callerNumber || '',
        callerName,
        category,
        greeting,
        state: 'ANSWERED',
      };

      if (window.NovaEvents) {
        window.NovaEvents.emit('secretary:status', {
          state: 'ANSWERED',
          callerName,
          category,
          greeting,
          headline: `Kotib gaplashmoqda: ${callerName}`,
          subtitle: greeting,
        });
      }
    }

    onSecretaryFinished(payload) {
      const logEntry = {
        callerNumber: payload.callerNumber || '+998901112233',
        callerName: payload.callerName || 'Onam',
        category: payload.category || 'OTA_ONA',
        ringsCount: payload.ringsCount || 6,
        transcriptSummary:
          payload.summary ||
          `${payload.callerName || 'Qo\'ng\'iroq qiluvchi'} bilan 6-gudokdan so'ng suhbat yozib olindi.`,
        audioPath: payload.audioPath || '',
        timestamp: Date.now(),
      };

      if (window.NovaVault) {
        window.NovaVault.addCallLog(logEntry);
      }

      this.activeCall = null;

      if (window.NovaEvents) {
        window.NovaEvents.emit('secretary:status', {
          state: 'FINISHED',
          logEntry,
          headline: 'Hi',
          subtitle: `Kotib xulosasi saqlandi: ${logEntry.callerName}`,
        });
        window.NovaEvents.emit('secretary:logs_updated', window.NovaVault.getCallLogs());
      }
    }

    /**
     * Live simulation / test of the 6-Gudok Call Secretary for any contact or number
     */
    simulateIncomingCall(identifier = 'Onam') {
      const contact = window.NovaVault
        ? window.NovaVault.resolveContact(identifier)
        : {
            name: identifier,
            phone: '+998901112233',
            category: 'OTA_ONA',
            greetingTone:
              "Assalomu alaykum! Hozir Muhammadnosir muhim ish bilan band edilar, men yordamchilariman.",
          };

      if (
        window.NovaNative &&
        typeof window.NovaNative.simulateSecretaryCall === 'function'
      ) {
        try {
          window.NovaNative.simulateSecretaryCall(contact.phone || contact.name);
        } catch (e) {}
      }

      if (this.ringTimer) clearInterval(this.ringTimer);
      let currentRing = 0;
      const maxRings = 6;

      this.ringTimer = setInterval(() => {
        currentRing++;
        if (currentRing <= maxRings) {
          this.onIncomingRing({
            caller: contact.name,
            ring: currentRing,
            maxRings,
          });
        } else {
          clearInterval(this.ringTimer);
          this.ringTimer = null;

          const greeting =
            contact.greetingTone ||
            window.NovaVault.buildDefaultGreeting(contact.name, contact.category);

          this.onSecretaryAnswered({
            callerNumber: contact.phone || contact.name,
            callerName: contact.name,
            category: contact.category,
            greeting,
          });

          // Speak the Relationship Matrix greeting aloud
          if (window.NovaBrain && typeof window.NovaBrain.speak === 'function') {
            window.NovaBrain.speak(greeting);
          }

          setTimeout(() => {
            const sampleReply = this._generateSimulatedCallerReply(contact);
            this.onSecretaryFinished({
              callerNumber: contact.phone || contact.name,
              callerName: contact.name,
              category: contact.category,
              ringsCount: 6,
              audioPath: `/storage/emulated/0/Android/data/com.nova.jarvis/files/CallRecordings/nova_call_${Date.now()}.m4a`,
              summary: `[Kotib aytdi]: "${greeting}"\n[${contact.name} javobi]: "${sampleReply}"`,
            });
          }, 6500);
        }
      }, 1100);
    }

    _generateSimulatedCallerReply(contact) {
      switch ((contact.category || '').toUpperCase()) {
        case 'OTA_ONA':
          return "Rahmat bolam, bo'shashi bilan menga bir qo'ng'iroq qilib yuborsin, uyda hammasi tinch.";
        case 'BOBO_BUVI':
          return "Baraka toping, o'qish va ishlariga omad tilayman, vaqti bo'lganda xabar olsin.";
        case 'USTOZ':
          return "Tushunarli, ertangi dars va loyiha bo'yicha tayyorgarlik ko'rib qo'ysin.";
        case 'DOST':
          return "Bo'ldi bro, kechki payt ko'rishamiz deb aytib qo'y!";
        default:
          return "Kechirasiz, Muhammadnosir bilan bog'lanmoqchi edim, keyinroq qo'ng'iroq qilaman.";
      }
    }
  }

  window.NovaSecretary = new NovaCallSecretaryController();
})();
