/**
 * ============================================================================
 * NOVA — LOCAL MEMORY VAULT (SQLite Bridge + IndexedDB Dual Storage)
 * ============================================================================
 * Stores:
 *  - Relationship Matrix (OTA_ONA, BOBO_BUVI, USTOZ, DOST, BEGONA)
 *  - 6-Gudok Call Secretary Audio & Transcript Logs
 *  - Daily Plans, Namoz Alarms & Habit Trackers
 *  - Voice Biometric Vector & User Preferences
 * ============================================================================
 */
(function () {
  'use strict';

  const DB_NAME = 'NovaJarvisVaultDB';
  const DB_VERSION = 2;

  const DEFAULT_CONTACTS = [
    {
      name: 'Onam',
      phone: '+998901112233',
      category: 'OTA_ONA',
      relationLabel: 'Ona (Eng yuqori ehtirom)',
      greetingTone:
        "Assalomu alaykum onajon! Hozir Muhammadnosir muhim ish bilan band edilar, men yordamchilariman. Nima deb yetkazib qo'yay, hozir bo'shashlari bilan o'zlari sizga qo'ng'iroq qiladilar.",
    },
    {
      name: 'Dadam',
      phone: '+998901112244',
      category: 'OTA_ONA',
      relationLabel: 'Ota (Eng yuqori ehtirom)',
      greetingTone:
        "Assalomu alaykum dadajon! Hozir Muhammadnosir muhim ish bilan band edilar, men yordamchilariman. Nima deb yetkazib qo'yay, hozir bo'shashlari bilan o'zlari sizga qo'ng'iroq qiladilar.",
    },
    {
      name: 'Bobom',
      phone: '+998902223344',
      category: 'BOBO_BUVI',
      relationLabel: 'Bobo (Duo va ehtirom)',
      greetingTone:
        "Assalomu alaykum bobojon! Nabirangiz hozir dars yoki ish bilan band edilar. Nima gap borligini menga aytsangiz, darhol yetkazib qo'yaman.",
    },
    {
      name: 'Buvim',
      phone: '+998902223355',
      category: 'BOBO_BUVI',
      relationLabel: 'Buvi (Duo va ehtirom)',
      greetingTone:
        "Assalomu alaykum buvijon! Nabirangiz hozir band edilar, men yordamchilariman. Nima deb yetkazib qo'yay?",
    },
    {
      name: 'Ustoz',
      phone: '+998903334455',
      category: 'USTOZ',
      relationLabel: 'Ustoz (Rasmiy va odobli)',
      greetingTone:
        "Assalomu alaykum ustoz! Shogirdingiz hozir band edilar, men ularning raqamli yordamchisiman. Xabaringizni qoldirsangiz, albatta yetkazib qo'yaman.",
    },
    {
      name: 'Jamshid',
      phone: '+998904445566',
      category: 'DOST',
      relationLabel: "Yaqin do'st (Samimiy bro)",
      greetingTone:
        "Salom bro! Hozir o'rtog'ing ozgina band edi, men uning Nova yordamchisiman. Nima gap o'zi? Aytaver, yozib olib o'ziga yetkazaman!",
    },
  ];

  class NovaMemoryVault {
    constructor() {
      this.idb = null;
      this.kvCache = {};
      this.readyPromise = this._init();
    }

    async _init() {
      await this._openIDB();
      this._hydrateFromNative();
    }

    _openIDB() {
      return new Promise((resolve) => {
        if (!window.indexedDB) {
          resolve();
          return;
        }
        const req = window.indexedDB.open(DB_NAME, DB_VERSION);
        req.onupgradeneeded = (e) => {
          const db = e.target.result;
          if (!db.objectStoreNames.contains('kv')) {
            db.createObjectStore('kv', { keyPath: 'key' });
          }
          if (!db.objectStoreNames.contains('contacts')) {
            db.createObjectStore('contacts', { keyPath: 'name' });
          }
          if (!db.objectStoreNames.contains('call_logs')) {
            db.createObjectStore('call_logs', { keyPath: 'id', autoIncrement: true });
          }
          if (!db.objectStoreNames.contains('plans')) {
            db.createObjectStore('plans', { keyPath: 'id', autoIncrement: true });
          }
        };
        req.onsuccess = (e) => {
          this.idb = e.target.result;
          resolve();
        };
        req.onerror = () => resolve();
      });
    }

    _hydrateFromNative() {
      try {
        if (window.NovaNative && typeof window.NovaNative.getRelationshipMatrix === 'function') {
          const raw = window.NovaNative.getRelationshipMatrix();
          if (raw) {
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed) && parsed.length > 0) {
              localStorage.setItem('nova_contacts_cache', JSON.stringify(parsed));
            }
          }
        }
      } catch (e) {
        // Fallback to localStorage / defaults
      }
    }

    // ------------------------------------------------------------------------
    // KV Store (Sync + Native SQLite Backup)
    // ------------------------------------------------------------------------
    getKV(key, defaultVal = '') {
      if (this.kvCache[key] !== undefined) return this.kvCache[key];
      try {
        if (window.NovaNative && typeof window.NovaNative.vaultGet === 'function') {
          const nativeVal = window.NovaNative.vaultGet(key, '__NULL__');
          if (nativeVal !== '__NULL__' && nativeVal !== null && nativeVal !== undefined) {
            this.kvCache[key] = nativeVal;
            return nativeVal;
          }
        }
      } catch (e) {}

      const localVal = localStorage.getItem('nova_kv_' + key);
      if (localVal !== null) {
        this.kvCache[key] = localVal;
        return localVal;
      }
      return defaultVal;
    }

    setKV(key, value) {
      const strVal = typeof value === 'string' ? value : JSON.stringify(value);
      this.kvCache[key] = strVal;
      try {
        localStorage.setItem('nova_kv_' + key, strVal);
      } catch (e) {}

      try {
        if (window.NovaNative && typeof window.NovaNative.vaultSet === 'function') {
          window.NovaNative.vaultSet(key, strVal);
        }
      } catch (e) {}

      if (this.idb) {
        try {
          const tx = this.idb.transaction('kv', 'readwrite');
          tx.objectStore('kv').put({ key, value: strVal, updatedAt: Date.now() });
        } catch (e) {}
      }
    }

    // ------------------------------------------------------------------------
    // Relationship Matrix
    // ------------------------------------------------------------------------
    getContacts() {
      try {
        if (window.NovaNative && typeof window.NovaNative.getRelationshipMatrix === 'function') {
          const raw = window.NovaNative.getRelationshipMatrix();
          const list = JSON.parse(raw || '[]');
          if (Array.isArray(list) && list.length > 0) {
            localStorage.setItem('nova_contacts_cache', JSON.stringify(list));
            return list;
          }
        }
      } catch (e) {}

      try {
        const cached = JSON.parse(localStorage.getItem('nova_contacts_cache') || 'null');
        if (Array.isArray(cached) && cached.length > 0) return cached;
      } catch (e) {}

      localStorage.setItem('nova_contacts_cache', JSON.stringify(DEFAULT_CONTACTS));
      return DEFAULT_CONTACTS.slice();
    }

    upsertContact(contact) {
      if (!contact || !contact.name) return this.getContacts();
      const category = (contact.category || 'DOST').toUpperCase();
      const greetingTone =
        contact.greetingTone || this.buildDefaultGreeting(contact.name, category);
      const relationLabel =
        contact.relationLabel || this.getCategoryLabel(category);

      try {
        if (window.NovaNative && typeof window.NovaNative.upsertRelationshipContact === 'function') {
          window.NovaNative.upsertRelationshipContact(
            contact.name.trim(),
            (contact.phone || '').trim(),
            category,
            relationLabel,
            greetingTone
          );
        }
      } catch (e) {}

      const list = this.getContacts();
      const idx = list.findIndex(
        (c) =>
          c.name.toLowerCase() === contact.name.trim().toLowerCase() ||
          (contact.phone && c.phone && c.phone === contact.phone.trim())
      );
      const entry = {
        name: contact.name.trim(),
        phone: (contact.phone || '').trim(),
        category,
        relationLabel,
        greetingTone,
      };
      if (idx >= 0) {
        list[idx] = entry;
      } else {
        list.unshift(entry);
      }
      localStorage.setItem('nova_contacts_cache', JSON.stringify(list));
      return list;
    }

    removeContact(name) {
      try {
        if (window.NovaNative && typeof window.NovaNative.deleteRelationshipContact === 'function') {
          window.NovaNative.deleteRelationshipContact(name);
        }
      } catch (e) {}

      const list = this.getContacts().filter(
        (c) => c.name.toLowerCase() !== String(name || '').toLowerCase()
      );
      localStorage.setItem('nova_contacts_cache', JSON.stringify(list));
      return list;
    }

    resolveContact(identifier) {
      const q = String(identifier || '').trim().toLowerCase();
      const list = this.getContacts();
      if (q) {
        for (const c of list) {
          const cName = (c.name || '').toLowerCase();
          const cPhone = (c.phone || '').replace(/\s+/g, '');
          const qDigits = q.replace(/\D+/g, '');
          if (
            cName === q ||
            q.includes(cName) ||
            (qDigits.length >= 7 && cPhone.endsWith(qDigits.slice(-7)))
          ) {
            return c;
          }
        }
      }
      return {
        name: identifier || "Noma'lum raqam",
        phone: identifier || '',
        category: 'BEGONA',
        relationLabel: 'Begona / Tekshiruv',
        greetingTone:
          "Assalomu alaykum, kimni so'rayapsiz va qanday masala bo'yicha qo'ng'iroq qildingiz? Men raqamli yordamchiman, xabaringizni yozib olaman.",
      };
    }

    getCategoryLabel(category) {
      switch ((category || '').toUpperCase()) {
        case 'OTA_ONA':
          return 'Ota-Ona (Eng yuqori ehtirom)';
        case 'BOBO_BUVI':
          return 'Bobo-Buvi (Duo va ehtirom)';
        case 'USTOZ':
          return 'Ustoz (Rasmiy va odobli)';
        case 'DOST':
          return "Do'st (Samimiy bro)";
        default:
          return 'Begona (Ehtiyotkor tekshiruv)';
      }
    }

    buildDefaultGreeting(name, category) {
      switch ((category || '').toUpperCase()) {
        case 'OTA_ONA':
          return `Assalomu alaykum ${name}! Hozir Muhammadnosir muhim ish bilan band edilar, men yordamchilariman. Nima deb yetkazib qo'yay, hozir bo'shashlari bilan o'zlari sizga qo'ng'iroq qiladilar.`;
        case 'BOBO_BUVI':
          return `Assalomu alaykum ${name}! Nabirangiz hozir band edilar, men yordamchilariman. Nima deb yetkazib qo'yay?`;
        case 'USTOZ':
          return `Assalomu alaykum ${name}! Shogirdingiz hozir band edilar, men ularning raqamli yordamchisiman. Xabaringizni qoldirsangiz, albatta yetkazib qo'yaman.`;
        case 'DOST':
          return `Salom bro (${name})! Hozir o'rtog'ing ozgina band edi, nima gap o'zi? Aytaver, yozib olib o'ziga yetkazaman!`;
        default:
          return "Assalomu alaykum, kimni so'rayapsiz va qanday masala bo'yicha qo'ng'iroq qildingiz?";
      }
    }

    // ------------------------------------------------------------------------
    // Call Secretary Logs
    // ------------------------------------------------------------------------
    getCallLogs() {
      try {
        if (window.NovaNative && typeof window.NovaNative.getCallSecretaryLogs === 'function') {
          const raw = window.NovaNative.getCallSecretaryLogs();
          const list = JSON.parse(raw || '[]');
          if (Array.isArray(list) && list.length > 0) {
            localStorage.setItem('nova_call_logs_cache', JSON.stringify(list));
            return list;
          }
        }
      } catch (e) {}

      try {
        const cached = JSON.parse(localStorage.getItem('nova_call_logs_cache') || '[]');
        if (Array.isArray(cached)) return cached;
      } catch (e) {}
      return [];
    }

    addCallLog(entry) {
      const list = this.getCallLogs();
      const item = {
        id: Date.now(),
        callerNumber: entry.callerNumber || '+998901112233',
        callerName: entry.callerName || 'Onam',
        category: entry.category || 'OTA_ONA',
        ringsCount: entry.ringsCount || 6,
        transcriptSummary: entry.transcriptSummary || '',
        audioPath: entry.audioPath || '',
        timestamp: entry.timestamp || Date.now(),
      };
      list.unshift(item);
      localStorage.setItem('nova_call_logs_cache', JSON.stringify(list.slice(0, 50)));
      return list;
    }

    // ------------------------------------------------------------------------
    // Daily Plans & Alarms
    // ------------------------------------------------------------------------
    getDailyPlans() {
      try {
        if (window.NovaNative && typeof window.NovaNative.getDailyPlans === 'function') {
          const raw = window.NovaNative.getDailyPlans();
          const list = JSON.parse(raw || '[]');
          if (Array.isArray(list) && list.length > 0) {
            localStorage.setItem('nova_plans_cache', JSON.stringify(list));
            return list;
          }
        }
      } catch (e) {}

      try {
        const cached = JSON.parse(localStorage.getItem('nova_plans_cache') || 'null');
        if (Array.isArray(cached)) return cached;
      } catch (e) {}

      const seedPlans = [
        { id: 1, title: 'Bomdod namozi va tilovat', timeStr: '05:15', isPrayer: true, completed: false },
        { id: 2, title: 'Deep Work: Dasturlash va fokus', timeStr: '09:00', isPrayer: false, completed: false },
        { id: 3, title: 'Peshin namozi', timeStr: '12:40', isPrayer: true, completed: false },
        { id: 4, title: 'Asr namozi', timeStr: '16:15', isPrayer: true, completed: false },
        { id: 5, title: 'Shom namozi', timeStr: '18:10', isPrayer: true, completed: false },
        { id: 6, title: 'Xufton namozi va kun sarhisobi', timeStr: '19:35', isPrayer: true, completed: false },
      ];
      localStorage.setItem('nova_plans_cache', JSON.stringify(seedPlans));
      return seedPlans;
    }

    addDailyPlan(title, timeStr, isPrayer = false) {
      try {
        if (window.NovaNative && typeof window.NovaNative.addDailyPlan === 'function') {
          window.NovaNative.addDailyPlan(title, timeStr, !!isPrayer);
        }
      } catch (e) {}

      const list = this.getDailyPlans();
      list.push({
        id: Date.now(),
        title,
        timeStr,
        isPrayer: !!isPrayer,
        completed: false,
      });
      list.sort((a, b) => String(a.timeStr).localeCompare(String(b.timeStr)));
      localStorage.setItem('nova_plans_cache', JSON.stringify(list));
      return list;
    }
  }

  window.NovaVault = new NovaMemoryVault();
})();
