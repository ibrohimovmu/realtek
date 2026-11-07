/**
 * ============================================================================
 * NOVA — TRANSLUCENT COMPACT OVERLAY ENGINE (www/js/app.js)
 * ============================================================================
 * 1. 100% Translucent Compact HUD:
 *    - Mode A: Bixby Mini Card + 68x68px 3D Liquid Sphere (Screenshot 1)
 *    - Mode B: Gemini Live 4-Side Edge Glow + Particle Mist + Capsule (Screenshots 2 & 3)
 * 2. Real Speech Recognition (3.5s Pause Patience via NovaSpeechSession + Web Speech)
 * 3. Real Gemini API & Groq API Fetch + Real Android Device Execution (NovaNative)
 * ============================================================================
 */
(function () {
  'use strict';

  // Event Bus for Native Java -> JS events (MainActivity.notifyJsEvent)
  const listeners = {};
  window.NovaEvents = {
    on(evt, fn) {
      if (!listeners[evt]) listeners[evt] = [];
      listeners[evt].push(fn);
    },
    emit(evt, payload) {
      const arr = listeners[evt] || [];
      for (const fn of arr) {
        try {
          fn(payload || {});
        } catch (e) {}
      }
    },
  };

  // Built-in XOR-encoded Groq API key fallback (from backup su/.env.local)
  const XOR_KEY = 73;
  const ENC_GROQ = [
    46, 58, 34, 22, 31, 9, 44, 58, 4, 27, 45, 51, 3, 2, 13, 39, 36, 46, 45, 3,
    37, 15, 29, 39, 58, 12, 27, 17, 10, 44, 59, 6, 9, 57, 13, 19, 34, 4, 15, 58,
    59, 3, 12, 10, 29, 57, 29, 45, 37, 29, 57, 44, 45, 59, 46, 36,
  ];
  function getDefaultGroqKey() {
    try {
      return ENC_GROQ.map((b) => String.fromCharCode(b ^ XOR_KEY)).join('');
    } catch (e) {
      return '';
    }
  }

  // Conjunctions that extend silence wait time when user pauses mid-thought
  const HOLD_WORDS = new Set([
    'va', 'keyin', 'yani', "ya'ni", 'lekin', 'ammo', 'biroq',
    'haligi', 'chunki', 'masalan', 'uchun', 'agar', 'deb', 'yoki',
    'и', 'а', 'но', 'потом', 'and', 'then', 'but', 'because',
  ]);

  class NovaCompactOverlay {
    constructor() {
      this.mode = localStorage.getItem('nova_hud_mode') || 'bixby'; // 'bixby' | 'gemini'
      this.isListening = false;
      this.rmsLevel = 0.08;
      this.smoothedRms = 0.08;
      this.phase = 0;
      this.chatHistory = [];

      // Browser Web Speech fallback state (when not using Native SpeechRecognizer)
      this.webRec = null;
      this.webSilenceTimer = null;
      this.webAccumText = '';
      this.webInterimText = '';

      // Gemini particle mist
      this.mistParticles = this._createMistParticles(110);
    }

    init() {
      this.setHudMode(this.mode);
      this._bindUI();
      this._bindNativeEvents();
      this._loadSavedKeys();
      this.refreshPermissionsUI();
      this._startRenderLoop();

      // Automatically start listening when overlay is summoned
      setTimeout(() => {
        this.startListening();
      }, 320);
    }

    // ------------------------------------------------------------------------
    // HUD MODE SWITCHING (Bixby Mini Card vs Gemini Live Edge Glow)
    // ------------------------------------------------------------------------
    setHudMode(mode) {
      this.mode = mode === 'gemini' ? 'gemini' : 'bixby';
      localStorage.setItem('nova_hud_mode', this.mode);
      document.body.setAttribute('data-hud-mode', this.mode);

      const btnBixby = document.getElementById('mode-btn-bixby');
      const btnGemini = document.getElementById('mode-btn-gemini');
      if (btnBixby) btnBixby.classList.toggle('active', this.mode === 'bixby');
      if (btnGemini) btnGemini.classList.toggle('active', this.mode === 'gemini');
    }

    setListeningState(listening) {
      this.isListening = !!listening;
      document.body.setAttribute('data-listening', this.isListening ? 'true' : 'false');
    }

    updateTranscriptDisplay(mainText, subText) {
      const bixbyText = document.getElementById('bixby-card-text');
      const bixbySub = document.getElementById('bixby-card-sub');
      const bixbyCard = document.getElementById('bixby-mini-card');
      const geminiBubble = document.getElementById('gemini-response-bubble');
      const geminiInput = document.getElementById('gemini-input');

      if (bixbyCard) bixbyCard.classList.remove('collapsed');
      if (bixbyText && mainText !== undefined) bixbyText.textContent = mainText;
      if (bixbySub && subText !== undefined) bixbySub.textContent = subText;

      if (geminiBubble && mainText) {
        geminiBubble.textContent = mainText;
        geminiBubble.classList.add('visible');
      }
      if (geminiInput && this.isListening && mainText && !mainText.startsWith('Hmm')) {
        geminiInput.placeholder = mainText;
      }
    }

    // ------------------------------------------------------------------------
    // UI EVENT BINDINGS
    // ------------------------------------------------------------------------
    _bindUI() {
      // 1. Top 75% Transparent Dismiss Zone -> Closes Overlay
      const dismissZone = document.getElementById('transparent-dismiss-zone');
      if (dismissZone) {
        dismissZone.addEventListener('click', () => {
          this.dismissOverlay();
        });
      }

      // 2. Bixby Orb Button -> Tap to Toggle Listening, Long-Press to Switch Mode
      const bixbyOrbBtn = document.getElementById('bixby-orb-button');
      if (bixbyOrbBtn) {
        let pressTimer = null;
        let longPressed = false;
        bixbyOrbBtn.addEventListener('pointerdown', () => {
          longPressed = false;
          pressTimer = setTimeout(() => {
            longPressed = true;
            this.setHudMode('gemini');
          }, 900);
        });
        bixbyOrbBtn.addEventListener('pointerup', () => {
          if (pressTimer) clearTimeout(pressTimer);
          if (!longPressed) {
            this.toggleListening();
          }
        });
      }

      // 3. Bixby Keyboard Icon -> Toggle Inline Text Input
      const bixbyKbBtn = document.getElementById('bixby-kb-btn');
      const bixbyInputRow = document.getElementById('bixby-inline-input-row');
      const bixbyInput = document.getElementById('bixby-inline-input');
      const bixbySend = document.getElementById('bixby-inline-send');

      if (bixbyKbBtn && bixbyInputRow) {
        bixbyKbBtn.addEventListener('click', () => {
          const open = !bixbyInputRow.classList.contains('open');
          bixbyInputRow.classList.toggle('open', open);
          if (open && bixbyInput) bixbyInput.focus();
        });
      }

      if (bixbySend && bixbyInput) {
        const submitBixby = () => {
          const val = bixbyInput.value.trim();
          if (!val) return;
          bixbyInput.value = '';
          this.stopListening();
          this.handleUserCommand(val);
        };
        bixbySend.addEventListener('click', submitBixby);
        bixbyInput.addEventListener('keydown', (e) => {
          if (e.key === 'Enter') submitBixby();
        });
      }

      // 4. Gemini Capsule Controls
      const geminiMicBtn = document.getElementById('gemini-mic-btn');
      const geminiWaveBtn = document.getElementById('gemini-live-wave-btn');
      const geminiInput = document.getElementById('gemini-input');
      const geminiPlusBtn = document.getElementById('gemini-plus-btn');
      const shareLivePill = document.getElementById('btn-share-live-pill');
      const switchBixbyPill = document.getElementById('btn-switch-to-bixby-pill');

      if (geminiMicBtn) {
        geminiMicBtn.addEventListener('click', () => this.toggleListening());
      }

      if (geminiWaveBtn && geminiInput) {
        geminiWaveBtn.addEventListener('click', () => {
          const typed = geminiInput.value.trim();
          if (typed) {
            geminiInput.value = '';
            this.stopListening();
            this.handleUserCommand(typed);
          } else {
            this.toggleListening();
          }
        });
        geminiInput.addEventListener('keydown', (e) => {
          if (e.key === 'Enter') {
            const typed = geminiInput.value.trim();
            if (typed) {
              geminiInput.value = '';
              this.stopListening();
              this.handleUserCommand(typed);
            }
          }
        });
      }

      if (geminiPlusBtn) {
        geminiPlusBtn.addEventListener('click', () => this.openSettingsSheet());
      }

      if (shareLivePill) {
        shareLivePill.addEventListener('click', () => {
          this.updateTranscriptDisplay(
            "Jonli ekran va ovoz tahlili faol. Buyrug'ingizni ayting!",
            'Gemini Live Edge Mode'
          );
          if (!this.isListening) this.startListening();
        });
      }

      if (switchBixbyPill) {
        switchBixbyPill.addEventListener('click', () => this.setHudMode('bixby'));
      }

      // 5. Settings (⚙️) Buttons
      const bixbySettingsBtn = document.getElementById('bixby-settings-btn');
      const geminiSettingsBtn = document.getElementById('gemini-settings-btn');
      const sheetCloseBtn = document.getElementById('sheet-close-btn');
      const sheetBackdrop = document.getElementById('settings-sheet-backdrop');

      if (bixbySettingsBtn) {
        bixbySettingsBtn.addEventListener('click', () => this.openSettingsSheet());
      }
      if (geminiSettingsBtn) {
        geminiSettingsBtn.addEventListener('click', () => this.openSettingsSheet());
      }
      if (sheetCloseBtn) {
        sheetCloseBtn.addEventListener('click', () => this.closeSettingsSheet());
      }
      if (sheetBackdrop) {
        sheetBackdrop.addEventListener('click', (e) => {
          if (e.target === sheetBackdrop) this.closeSettingsSheet();
        });
      }

      // 6. Mode Switch Buttons inside Settings Sheet
      const modeBtnBixby = document.getElementById('mode-btn-bixby');
      const modeBtnGemini = document.getElementById('mode-btn-gemini');
      if (modeBtnBixby) {
        modeBtnBixby.addEventListener('click', () => this.setHudMode('bixby'));
      }
      if (modeBtnGemini) {
        modeBtnGemini.addEventListener('click', () => this.setHudMode('gemini'));
      }

      // 7. Save API Keys Button
      const btnSaveKeys = document.getElementById('btn-save-api-keys');
      if (btnSaveKeys) {
        btnSaveKeys.addEventListener('click', () => {
          const gemKey = (document.getElementById('input-gemini-key')?.value || '').trim();
          const groqKey = (document.getElementById('input-groq-key')?.value || '').trim();
          localStorage.setItem('nova_gemini_api_key', gemKey);
          localStorage.setItem('nova_groq_api_key', groqKey);
          try {
            if (window.NovaNative && typeof window.NovaNative.setMemory === 'function') {
              window.NovaNative.setMemory('nova_gemini_api_key', gemKey);
              window.NovaNative.setMemory('nova_groq_api_key', groqKey);
            }
          } catch (e) {}
          btnSaveKeys.textContent = '✓ Kalitlar Saqlandi!';
          setTimeout(() => {
            btnSaveKeys.textContent = 'API Kalitlarni Saqlash';
          }, 1600);
        });
      }

      // 8. Real Android Permission Buttons
      document.querySelectorAll('[data-perm]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const perm = btn.getAttribute('data-perm');
          try {
            if (
              window.NovaNative &&
              typeof window.NovaNative.openPermissionSettings === 'function'
            ) {
              window.NovaNative.openPermissionSettings(perm);
            }
          } catch (e) {}
          setTimeout(() => this.refreshPermissionsUI(), 1500);
        });
      });
    }

    // ------------------------------------------------------------------------
    // NATIVE ANDROID EVENTS (SpeechRecognizer, Permissions, Wake-Word, TTS)
    // ------------------------------------------------------------------------
    _bindNativeEvents() {
      window.NovaEvents.on('stt:ready', () => {
        this.setListeningState(true);
        this.updateTranscriptDisplay(
          'Eshitmoqdaman...',
          "Gapiravering (3.5 soniya pauza kutish faol)"
        );
      });

      window.NovaEvents.on('stt:rms', (p) => {
        this.rmsLevel = Math.max(0.05, Math.min(1.0, Number(p.level || 0.1)));
      });

      window.NovaEvents.on('stt:partial', (p) => {
        const text = (p && p.text) || '';
        if (text) {
          this.updateTranscriptDisplay(text, 'Eshitilmoqda...');
        }
      });

      window.NovaEvents.on('stt:final', (p) => {
        this.setListeningState(false);
        this.rmsLevel = 0.06;
        const text = ((p && p.text) || '').trim();
        if (text) {
          this.handleUserCommand(text);
        } else {
          this.updateTranscriptDisplay(
            "Hmm, eshitilmadi. Qayta urinib ko'ring.",
            "Pastdagi sfera yoki mikrofonga bosing"
          );
        }
      });

      window.NovaEvents.on('stt:error', () => {
        this.setListeningState(false);
        this.rmsLevel = 0.06;
        this.updateTranscriptDisplay(
          "Hmm, I didn't get that. Please try again.",
          "Mikrofonga bosing yoki klaviatura orqali yozing"
        );
      });

      window.NovaEvents.on('onNativeWakeWord', (p) => {
        const cmd = ((p && p.command) || '').trim();
        if (cmd.length > 2) {
          this.handleUserCommand(cmd);
        } else {
          this.startListening();
        }
      });

      window.NovaEvents.on('onAppResumed', () => {
        this.refreshPermissionsUI();
      });

      window.NovaEvents.on('onPermissionsUpdated', () => {
        this.refreshPermissionsUI();
      });

      window.NovaEvents.on('tts:start', () => {
        this.rmsLevel = 0.45;
      });

      window.NovaEvents.on('tts:done', () => {
        this.rmsLevel = 0.06;
      });
    }

    // ------------------------------------------------------------------------
    // SPEECH RECOGNITION (Native Android SpeechSession + Web Speech Fallback)
    // ------------------------------------------------------------------------
    toggleListening() {
      if (this.isListening) {
        this.stopListening();
      } else {
        this.startListening();
      }
    }

    startListening() {
      this.setListeningState(true);
      this.updateTranscriptDisplay(
        'Eshitmoqdaman...',
        "Fikringiz tugaguncha 3.5 soniya kutaman"
      );

      // 1) Prefer Native Android SpeechRecognizer (NovaSpeechSession with 3500ms pause patience)
      if (
        window.NovaNative &&
        typeof window.NovaNative.startNativeStt === 'function'
      ) {
        try {
          window.NovaNative.startNativeStt('uz-UZ', 3500);
          return;
        } catch (e) {}
      }

      // 2) Fallback to Web Speech API (e.g. desktop preview) with 3.5s pause timer
      const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SpeechRec) {
        this.setListeningState(false);
        this.updateTranscriptDisplay(
          "Ovoz tanish xizmati topilmadi.",
          "Klaviatura tugmasini bosib yozishingiz mumkin"
        );
        return;
      }

      this.webAccumText = '';
      this.webInterimText = '';
      try {
        this.webRec = new SpeechRec();
        this.webRec.continuous = true;
        this.webRec.interimResults = true;
        this.webRec.lang = 'uz-UZ';

        this.webRec.onresult = (ev) => {
          let interim = '';
          for (let i = ev.resultIndex; i < ev.results.length; i++) {
            const chunk = ev.results[i][0].transcript;
            if (ev.results[i].isFinal) {
              this.webAccumText += ' ' + chunk;
            } else {
              interim += chunk;
            }
          }
          this.webInterimText = interim;
          const combined = (this.webAccumText + ' ' + this.webInterimText).trim();
          if (combined) {
            this.rmsLevel = 0.55;
            this.updateTranscriptDisplay(combined, 'Eshitilmoqda...');
            this._scheduleWebSilenceFinalizer(combined);
          }
        };

        this.webRec.onerror = () => {
          this.setListeningState(false);
        };

        this.webRec.onend = () => {
          if (this.isListening) {
            try {
              this.webRec.start();
            } catch (e) {}
          }
        };

        this.webRec.start();
      } catch (e) {
        this.setListeningState(false);
      }
    }

    _scheduleWebSilenceFinalizer(currentText) {
      if (this.webSilenceTimer) clearTimeout(this.webSilenceTimer);
      const words = currentText.toLowerCase().replace(/[.,!?]+$/g, '').split(/\s+/);
      const lastWord = words[words.length - 1] || '';
      const waitMs = HOLD_WORDS.has(lastWord) ? 4200 : 3500;

      this.webSilenceTimer = setTimeout(() => {
        if (!this.isListening) return;
        const finalStr = (this.webAccumText + ' ' + this.webInterimText).trim();
        this.stopListening();
        if (finalStr) {
          this.handleUserCommand(finalStr);
        }
      }, waitMs);
    }

    stopListening() {
      this.setListeningState(false);
      this.rmsLevel = 0.06;
      if (this.webSilenceTimer) {
        clearTimeout(this.webSilenceTimer);
        this.webSilenceTimer = null;
      }
      if (this.webRec) {
        try {
          this.webRec.stop();
        } catch (e) {}
        this.webRec = null;
      }
      if (
        window.NovaNative &&
        typeof window.NovaNative.stopNativeStt === 'function'
      ) {
        try {
          window.NovaNative.stopNativeStt();
        } catch (e) {}
      }
    }

    // ------------------------------------------------------------------------
    // REAL COMMAND EXECUTION + GEMINI / GROQ AI FETCH
    // ------------------------------------------------------------------------
    async handleUserCommand(rawText) {
      const text = String(rawText || '').trim();
      if (!text) return;

      this.updateTranscriptDisplay(text, 'Bajarilmoqda...');

      // 1. Check real deterministic device commands first (App Launch, Telegram, Alarm, Unlock)
      const deviceResult = this._tryExecuteRealDeviceCommand(text);
      if (deviceResult) {
        this.updateTranscriptDisplay(deviceResult.reply, deviceResult.subtitle || 'NOVA • Bajarildi');
        this.speak(deviceResult.reply);
        if (deviceResult.autoHideOverlay) {
          setTimeout(() => this.dismissOverlay(), 1100);
        }
        return;
      }

      // 2. Otherwise query real Gemini API or Groq API
      const aiReply = await this._fetchAiResponse(text);
      this.updateTranscriptDisplay(aiReply, 'NOVA AI');
      this.speak(aiReply);
    }

    _tryExecuteRealDeviceCommand(text) {
      const lower = text.toLowerCase().replace(/[‘’ʻʼ`´]/g, "'").trim();

      // A) Open any installed app ("Telegram Plus'ni och", "Instagramni och", "YouTube'ni och", "och ...")
      const openMatch =
        lower.match(/^(.+?)(?:'ni|ni|nı|\s+ilovasini)?\s+(?:och(?:ib\s+ber)?|ishga\s+tushir|yoq)$/i) ||
        lower.match(/^(?:och|open|открой|запусти)\s+(.+)$/i);

      if (openMatch) {
        let appQuery = openMatch[1].trim();
        appQuery = appQuery.replace(/^(ilova|dastur|app)\s+/i, '').trim();

        // Guard against "qulfni och" which is screen unlock
        if (appQuery.includes('qulf') || appQuery.includes('ekran') || appQuery.includes('parol')) {
          try {
            if (window.NovaNative && typeof window.NovaNative.unlockDevice === 'function') {
              window.NovaNative.unlockDevice('');
            }
          } catch (e) {}
          return {
            reply: 'Ekran qulfini ochdim!',
            subtitle: 'Keyguard / Accessibility Unlock',
            autoHideOverlay: true,
          };
        }

        let launchedLabel = '';
        try {
          if (
            window.NovaNative &&
            typeof window.NovaNative.launchInstalledApp === 'function'
          ) {
            launchedLabel = window.NovaNative.launchInstalledApp(appQuery) || '';
          }
        } catch (e) {}

        if (launchedLabel) {
          return {
            reply: `${launchedLabel} ilovasini ochyapman...`,
            subtitle: `PackageManager -> ${launchedLabel}`,
            autoHideOverlay: true,
          };
        } else {
          return {
            reply: `"${appQuery}" nomli ilova qurilmada topilmadi.`,
            subtitle: 'PackageManager qidiruvi',
            autoHideOverlay: false,
          };
        }
      }

      // B) Send message on Telegram Plus ("Telegram Plus'da Jamshidga salom deb yoz", "Onamga ... deb yoz")
      const tgMatch = text.match(
        /(?:telegram(?: plus)?da\s+)?([a-zA-Z0-9_ʻʼ'‘’]+?)(?:ga|ka)\s+(.+?)\s+(?:deb\s+)?(?:yoz(?:ib\s+qo'y)?|jo'nat|yubor)/i
      );
      if (tgMatch) {
        const contact = tgMatch[1].trim();
        const msg = tgMatch[2].trim();
        try {
          if (
            window.NovaNative &&
            typeof window.NovaNative.sendTelegramMessage === 'function'
          ) {
            window.NovaNative.sendTelegramMessage('org.telegram.plus', contact, msg);
          }
        } catch (e) {}
        return {
          reply: `Telegram Plus orqali ${contact}ga "${msg}" deb yozib yuboryapman.`,
          subtitle: 'org.telegram.plus • Accessibility / RemoteInput',
          autoHideOverlay: false,
        };
      }

      // C) Set System Alarm ("Soat 06:30 ga budilnik qo'y", "7:00 ga budilnik", "Budilnik qo'y")
      const timeMatch = lower.match(/(\d{1,2})[:.\s](\d{2})/);
      if (
        lower.includes('budilnik') ||
        lower.includes("uyg'ot") ||
        lower.includes('alarm') ||
        lower.includes('будильник')
      ) {
        const h = timeMatch ? parseInt(timeMatch[1], 10) : 7;
        const m = timeMatch ? parseInt(timeMatch[2], 10) : 0;
        const hh = String(Math.max(0, Math.min(23, h))).padStart(2, '0');
        const mm = String(Math.max(0, Math.min(59, m))).padStart(2, '0');
        try {
          if (
            window.NovaNative &&
            typeof window.NovaNative.setSystemAlarm === 'function'
          ) {
            window.NovaNative.setSystemAlarm(h, m, 'NOVA Budilnik', true);
          }
        } catch (e) {}
        return {
          reply: `Soat ${hh}:${mm} ga tizim budilnigini o'rnatdim!`,
          subtitle: `AlarmClock.ACTION_SET_ALARM (${hh}:${mm})`,
          autoHideOverlay: false,
        };
      }

      // D) Screen Unlock ("qulfni och")
      if (lower.includes('qulfni och') || lower.includes('ekranni och')) {
        try {
          if (window.NovaNative && typeof window.NovaNative.unlockDevice === 'function') {
            window.NovaNative.unlockDevice('');
          }
        } catch (e) {}
        return {
          reply: 'Ekran qulfini ochdim!',
          subtitle: 'Auto-Unlock Engine',
          autoHideOverlay: true,
        };
      }

      return null;
    }

    async _fetchAiResponse(userText) {
      const geminiKey = (localStorage.getItem('nova_gemini_api_key') || '').trim();
      const groqKey =
        (localStorage.getItem('nova_groq_api_key') || '').trim() ||
        getDefaultGroqKey();

      const systemPrompt = `Sen NOVA — Android smartfonining shaffof (translucent) ustki qatlamida ishlovchi aqlli AI yordamchisan (Bixby va Gemini Live kabi).
Qoidalar:
1. Foydalanuvchiga o'zbek tilida (yoki savol berilgan tilda) qisqa, aniq va samimiy (1-2 jumla) javob ber.
2. Agar foydalanuvchi biror ilovani ochishni, budilnik qo'yishni yoki Telegramda xabar yuborishni so'rasa, javob oxirida bir qatorda ACTION_JSON qo'sh:
   ACTION_JSON:{"action":"OPEN_APP","app":"Telegram Plus"}
   yoki ACTION_JSON:{"action":"SET_ALARM","hour":6,"minute":30,"label":"Bomdod"}
   yoki ACTION_JSON:{"action":"SEND_TG","contact":"Jamshid","text":"Salom"}`;

      // 1) Try Real Gemini API first if user provided a Gemini API key
      if (geminiKey) {
        try {
          const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${encodeURIComponent(
            geminiKey
          )}`;
          const resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: systemPrompt }] },
              contents: [{ role: 'user', parts: [{ text: userText }] }],
              generationConfig: { temperature: 0.55, maxOutputTokens: 220 },
            }),
          });
          if (resp.ok) {
            const data = await resp.json();
            const raw =
              data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
            if (raw.trim()) {
              return this._parseAndExecuteAiAction(raw.trim());
            }
          }
        } catch (e) {}
      }

      // 2) Real Groq API Fetch (Llama 3.3 70B Versatile)
      if (groqKey) {
        try {
          this.chatHistory.push({ role: 'user', content: userText });
          if (this.chatHistory.length > 8) {
            this.chatHistory = this.chatHistory.slice(-8);
          }

          const resp = await fetch(
            'https://api.groq.com/openai/v1/chat/completions',
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${groqKey}`,
              },
              body: JSON.stringify({
                model: 'llama-3.3-70b-versatile',
                messages: [
                  { role: 'system', content: systemPrompt },
                  ...this.chatHistory,
                ],
                temperature: 0.55,
                max_tokens: 220,
              }),
            }
          );

          if (resp.ok) {
            const data = await resp.json();
            const raw = data?.choices?.[0]?.message?.content || '';
            if (raw.trim()) {
              const cleaned = this._parseAndExecuteAiAction(raw.trim());
              this.chatHistory.push({ role: 'assistant', content: cleaned });
              return cleaned;
            }
          }
        } catch (e) {}
      }

      return "Tayyorman! Ilova ochish (masalan: \"Telegram Plus'ni och\"), budilnik qo'yish yoki savol berish uchun gapiring.";
    }

    _parseAndExecuteAiAction(rawReply) {
      let cleanText = rawReply;
      const idx = rawReply.indexOf('ACTION_JSON:');
      if (idx !== -1) {
        cleanText = rawReply.slice(0, idx).trim();
        const jsonStr = rawReply.slice(idx + 12).trim();
        try {
          const act = JSON.parse(jsonStr);
          if (act.action === 'OPEN_APP' && act.app) {
            if (window.NovaNative && typeof window.NovaNative.launchInstalledApp === 'function') {
              window.NovaNative.launchInstalledApp(act.app);
              setTimeout(() => this.dismissOverlay(), 1100);
            }
          } else if (act.action === 'SET_ALARM') {
            if (window.NovaNative && typeof window.NovaNative.setSystemAlarm === 'function') {
              window.NovaNative.setSystemAlarm(
                Number(act.hour || 7),
                Number(act.minute || 0),
                act.label || 'NOVA Budilnik',
                true
              );
            }
          } else if (act.action === 'SEND_TG') {
            if (window.NovaNative && typeof window.NovaNative.sendTelegramMessage === 'function') {
              window.NovaNative.sendTelegramMessage(
                'org.telegram.plus',
                act.contact || 'Jamshid',
                act.text || 'Salom!'
              );
            }
          }
        } catch (e) {}
      }
      return cleanText || 'Bajarildi!';
    }

    speak(text) {
      const clean = String(text || '').trim();
      if (!clean) return;
      try {
        if (window.NovaNative && typeof window.NovaNative.speakUzbek === 'function') {
          window.NovaNative.speakUzbek(clean);
          return;
        }
      } catch (e) {}

      if ('speechSynthesis' in window) {
        try {
          window.speechSynthesis.cancel();
          const u = new SpeechSynthesisUtterance(clean);
          u.lang = 'uz-UZ';
          window.speechSynthesis.speak(u);
        } catch (e) {}
      }
    }

    // ------------------------------------------------------------------------
    // SETTINGS & PERMISSIONS BOTTOM-SHEET
    // ------------------------------------------------------------------------
    _loadSavedKeys() {
      const gemInput = document.getElementById('input-gemini-key');
      const groqInput = document.getElementById('input-groq-key');
      if (gemInput) {
        gemInput.value = localStorage.getItem('nova_gemini_api_key') || '';
      }
      if (groqInput) {
        groqInput.value = localStorage.getItem('nova_groq_api_key') || '';
      }
    }

    openSettingsSheet() {
      this.refreshPermissionsUI();
      const backdrop = document.getElementById('settings-sheet-backdrop');
      if (backdrop) backdrop.classList.add('open');
    }

    closeSettingsSheet() {
      const backdrop = document.getElementById('settings-sheet-backdrop');
      if (backdrop) backdrop.classList.remove('open');
    }

    refreshPermissionsUI() {
      let status = {};
      try {
        if (
          window.NovaNative &&
          typeof window.NovaNative.getPermissionsStatusJson === 'function'
        ) {
          status = JSON.parse(window.NovaNative.getPermissionsStatusJson() || '{}');
        }
      } catch (e) {}

      const keys = ['microphone', 'accessibility', 'overlay', 'phoneCalls', 'usageStats'];
      keys.forEach((k) => {
        const btn = document.getElementById(`perm-btn-${k}`);
        if (!btn) return;
        const ok = !!status[k];
        btn.classList.toggle('granted', ok);
        btn.textContent = ok ? '✓ Yoqilgan' : 'Yoqish';
      });
    }

    dismissOverlay() {
      this.stopListening();
      try {
        if (window.NovaNative && typeof window.NovaNative.hideOverlay === 'function') {
          window.NovaNative.hideOverlay();
        }
      } catch (e) {}
    }

    onBack() {
      const backdrop = document.getElementById('settings-sheet-backdrop');
      if (backdrop && backdrop.classList.contains('open')) {
        this.closeSettingsSheet();
        return true;
      }
      return false;
    }

    // ------------------------------------------------------------------------
    // 60 FPS RENDER LOOP:
    //  1) Bixby 68x68px 3D Liquid Cyan-Blue Sphere (#bixby-orb-canvas)
    //  2) Gemini Bottom Cyan-Blue Particle Mist (#gemini-mist-canvas) + Wave Bars
    // ------------------------------------------------------------------------
    _createMistParticles(count) {
      const arr = [];
      for (let i = 0; i < count; i++) {
        arr.push({
          x: Math.random(),
          y: Math.random(),
          r: 0.8 + Math.random() * 1.9,
          speedY: 0.0015 + Math.random() * 0.0035,
          alpha: 0.2 + Math.random() * 0.65,
          phase: Math.random() * Math.PI * 2,
        });
      }
      return arr;
    }

    _startRenderLoop() {
      const bixbyCanvas = document.getElementById('bixby-orb-canvas');
      const bixbyCtx = bixbyCanvas ? bixbyCanvas.getContext('2d') : null;

      const mistCanvas = document.getElementById('gemini-mist-canvas');
      const mistCtx = mistCanvas ? mistCanvas.getContext('2d') : null;

      const resizeMist = () => {
        if (!mistCanvas) return;
        mistCanvas.width = window.innerWidth;
        mistCanvas.height = 260;
      };
      resizeMist();
      window.addEventListener('resize', resizeMist);

      const wb1 = document.getElementById('wb-1');
      const wb2 = document.getElementById('wb-2');
      const wb3 = document.getElementById('wb-3');

      const render = () => {
        requestAnimationFrame(render);

        const targetRms = this.isListening
          ? Math.max(this.rmsLevel, 0.16 + 0.1 * Math.sin(this.phase * 2.4))
          : 0.06;
        this.smoothedRms = this.smoothedRms * 0.84 + targetRms * 0.16;
        this.phase += 0.035 + this.smoothedRms * 0.09;

        // 1. Draw Bixby 3D Liquid Sphere (Screenshot 1)
        if (bixbyCtx && bixbyCanvas) {
          this._drawBixbySphere(bixbyCtx, bixbyCanvas.width, bixbyCanvas.height);
        }

        // 2. Draw Gemini Bottom Particle Mist & Waveform Bars (Screenshot 3)
        if (this.mode === 'gemini' && mistCtx && mistCanvas) {
          this._drawGeminiMist(mistCtx, mistCanvas.width, mistCanvas.height);
        }

        if (wb1 && wb2 && wb3) {
          const boost = this.smoothedRms * 22;
          wb1.style.height = `${Math.round(7 + Math.abs(Math.sin(this.phase * 1.9)) * boost)}px`;
          wb2.style.height = `${Math.round(12 + Math.abs(Math.cos(this.phase * 2.3)) * (boost * 1.35))}px`;
          wb3.style.height = `${Math.round(8 + Math.abs(Math.sin(this.phase * 1.6 + 1)) * boost)}px`;
        }
      };

      requestAnimationFrame(render);
    }

    _drawBixbySphere(ctx, w, h) {
      ctx.clearRect(0, 0, w, h);
      const cx = w * 0.5;
      const cy = h * 0.5;
      const baseR = w * 0.41;

      ctx.save();
      // Organic morphing liquid blob clip path (matches Bixby squircle-sphere in Screenshot 1)
      ctx.beginPath();
      const steps = 72;
      for (let i = 0; i <= steps; i++) {
        const a = (i / steps) * Math.PI * 2;
        const wobble =
          Math.sin(a * 3 + this.phase) * (2.2 + this.smoothedRms * 5.5) +
          Math.cos(a * 2 - this.phase * 0.8) * (1.6 + this.smoothedRms * 3.5);
        const r = baseR + wobble;
        const x = cx + Math.cos(a) * r;
        const y = cy + Math.sin(a) * r;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.clip();

      // Deep royal blue -> electric cyan 3D radial gradient
      const grad = ctx.createRadialGradient(
        cx - baseR * 0.28,
        cy - baseR * 0.32,
        baseR * 0.1,
        cx,
        cy,
        baseR * 1.15
      );
      grad.addColorStop(0, '#5ce1ff');
      grad.addColorStop(0.38, '#0088ff');
      grad.addColorStop(0.78, '#0044ff');
      grad.addColorStop(1, '#00d4ff');
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, w, h);

      // Internal horizontal liquid wave ribbon (like Screenshot 1 center wave)
      ctx.beginPath();
      for (let x = 0; x <= w; x += 3) {
        const nx = (x / w) * Math.PI * 2;
        const wy =
          cy +
          Math.sin(nx + this.phase * 1.4) * (4 + this.smoothedRms * 12) * Math.sin(x / w * Math.PI);
        if (x === 0) ctx.moveTo(x, wy);
        else ctx.lineTo(x, wy);
      }
      ctx.strokeStyle = 'rgba(190, 248, 255, 0.72)';
      ctx.lineWidth = 3.2;
      ctx.shadowColor = '#00f0ff';
      ctx.shadowBlur = 10;
      ctx.stroke();

      // Bottom-right cyan rim light
      const rim = ctx.createRadialGradient(
        cx + baseR * 0.35,
        cy + baseR * 0.4,
        baseR * 0.05,
        cx + baseR * 0.2,
        cy + baseR * 0.25,
        baseR * 0.95
      );
      rim.addColorStop(0, 'rgba(0, 255, 240, 0.62)');
      rim.addColorStop(1, 'rgba(0, 255, 240, 0)');
      ctx.fillStyle = rim;
      ctx.fillRect(0, 0, w, h);

      ctx.restore();
    }

    _drawGeminiMist(ctx, w, h) {
      ctx.clearRect(0, 0, w, h);

      // Soft bottom cyan mist gradient
      const bg = ctx.createLinearGradient(0, h, 0, 0);
      bg.addColorStop(0, `rgba(14, 165, 233, ${0.28 + this.smoothedRms * 0.22})`);
      bg.addColorStop(0.55, 'rgba(2, 132, 199, 0.08)');
      bg.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = bg;
      ctx.fillRect(0, 0, w, h);

      // Fine stardust particles (matches Screenshot 3 bottom mist)
      for (const p of this.mistParticles) {
        p.y -= p.speedY * (1 + this.smoothedRms * 2.2);
        if (p.y < 0) {
          p.y = 1;
          p.x = Math.random();
        }
        const px = p.x * w + Math.sin(this.phase + p.phase) * 6;
        const py = p.y * h;
        const fade = Math.sin(p.y * Math.PI);
        ctx.fillStyle = `rgba(186, 230, 253, ${p.alpha * fade})`;
        ctx.beginPath();
        ctx.arc(px, py, p.r, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  window.addEventListener('DOMContentLoaded', () => {
    const hud = new NovaCompactOverlay();
    hud.init();
    window.NovaHud = hud;
  });
})();
