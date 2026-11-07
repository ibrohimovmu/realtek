/**
 * ============================================================================
 * NOVA — 100% NATIVE SPEECH + SPRING 3D LIQUID PLASMA ORB ENGINE (www/js/app.js)
 * ============================================================================
 * - 100% Native Android SpeechRecognizer via NovaBridge.startNativeListening("uz-UZ")
 *   (NO HTML5 webkitSpeechRecognition!)
 * - Real-time callbacks invoked directly by MainActivity.java:
 *     * window.onNativeSpeech(text, isFinal)
 *     * window.onVoiceLevel(rmsdB)
 * - Boxless Blur-Fade Neon-White Words while speaking (#live-speech-stream)
 * - Minimalist Dark Glassmorphic Capsule expands ONLY when AI responds (#ai-response-capsule)
 * - 60fps Additive-Blended 3D Liquid Plasma Sphere + 4-Sided Neon Edge Glow
 * ============================================================================
 */
(function () {
  'use strict';

  // Ensure both window.NovaBridge and window.NovaNative point to the native bridge
  if (window.NovaNative && !window.NovaBridge) {
    window.NovaBridge = window.NovaNative;
  } else if (window.NovaBridge && !window.NovaNative) {
    window.NovaNative = window.NovaBridge;
  }

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

  class NovaLiveOverlay {
    constructor() {
      this.voiceEnergy = 0.08;
      this.smoothedEnergy = 0.08;
      this.phase = 0;
      this.renderedWords = [];
      this.chatHistory = [];
      this.mistParticles = this._initMistParticles(95);
    }

    init() {
      this._bindGlobalNativeCallbacks();
      this._bindUI();
      this._loadSavedKeys();
      this.refreshPermissionsUI();
      this._start60FpsLoop();

      // Start 100% Native Android SpeechRecognizer immediately on load
      this.startListening();
    }

    // ------------------------------------------------------------------------
    // 1. REAL-TIME NATIVE CALLBACKS FROM MainActivity.java
    //    - window.onNativeSpeech(text, isFinal)
    //    - window.onVoiceLevel(rmsdB)
    // ------------------------------------------------------------------------
    _bindGlobalNativeCallbacks() {
      window.onVoiceLevel = (rmsdB) => {
        const db = Number(rmsdB);
        if (!isNaN(db)) {
          const norm = Math.max(0.05, Math.min(1.0, (db + 2.0) / 11.5));
          this.voiceEnergy = norm;
          document.body.setAttribute(
            'data-speaking-active',
            norm > 0.22 ? 'true' : 'false'
          );
        }
      };

      window.onNativeSpeech = (text, isFinal) => {
        const clean = String(text || '').trim();
        if (!clean) return;

        // Hide AI capsule while user is speaking
        this._hideAiCapsule();

        // Render boxless neon-white words with smooth blur-fade animation
        this._renderLiveWords(clean);

        if (isFinal) {
          document.body.setAttribute('data-speaking-active', 'false');
          this.voiceEnergy = 0.08;
          this.processFinalSpeech(clean);
        }
      };

      window.NovaEvents.on('tts:start', () => {
        this.voiceEnergy = 0.52;
        document.body.setAttribute('data-speaking-active', 'true');
      });

      window.NovaEvents.on('tts:done', () => {
        this.voiceEnergy = 0.08;
        document.body.setAttribute('data-speaking-active', 'false');
        // Resume native listening smoothly after TTS finishes speaking
        setTimeout(() => {
          this.startListening(true);
        }, 350);
      });

      window.NovaEvents.on('onAppResumed', () => {
        this.refreshPermissionsUI();
      });

      window.NovaEvents.on('onPermissionsUpdated', () => {
        this.refreshPermissionsUI();
      });
    }

    startListening(keepCapsule = false) {
      if (!keepCapsule) {
        // Keep screen clean
      }
      const bridge = window.NovaBridge || window.NovaNative;
      if (bridge && typeof bridge.startNativeListening === 'function') {
        try {
          bridge.startNativeListening('uz-UZ');
        } catch (e) {}
      }
    }

    // ------------------------------------------------------------------------
    // 2. BOXLESS BLUR-FADE WORD RENDERER & AI GLASS CAPSULE
    // ------------------------------------------------------------------------
    _renderLiveWords(sentence) {
      const container = document.getElementById('live-speech-stream');
      if (!container) return;

      const words = sentence.split(/\s+/).filter(Boolean);
      // Append or update words without re-creating existing word spans so animation is smooth
      for (let i = 0; i < words.length; i++) {
        if (i < container.children.length) {
          const existing = container.children[i];
          if (existing.textContent !== words[i]) {
            existing.textContent = words[i];
          }
        } else {
          const span = document.createElement('span');
          span.className = 'speech-word';
          span.textContent = words[i];
          container.appendChild(span);
        }
      }
      while (container.children.length > words.length) {
        container.removeChild(container.lastChild);
      }
    }

    _clearLiveWords() {
      const container = document.getElementById('live-speech-stream');
      if (container) container.innerHTML = '';
    }

    _showAiCapsule(replyText) {
      const capsule = document.getElementById('ai-response-capsule');
      const textEl = document.getElementById('ai-response-text');
      if (!capsule || !textEl) return;
      textEl.textContent = replyText;
      capsule.classList.add('expanded');
    }

    _hideAiCapsule() {
      const capsule = document.getElementById('ai-response-capsule');
      if (capsule) capsule.classList.remove('expanded');
    }

    // ------------------------------------------------------------------------
    // 3. UI GESTURES (Dismiss Zone, Orb Tap / Long-Press, Settings Sheet)
    // ------------------------------------------------------------------------
    _bindUI() {
      const dismissZone = document.getElementById('transparent-dismiss-zone');
      if (dismissZone) {
        dismissZone.addEventListener('click', () => this.dismissOverlay());
      }

      const orbBtn = document.getElementById('plasma-orb-btn');
      if (orbBtn) {
        let holdTimer = null;
        let longPressed = false;

        const clearHold = () => {
          if (holdTimer) {
            clearTimeout(holdTimer);
            holdTimer = null;
          }
        };

        orbBtn.addEventListener('pointerdown', () => {
          longPressed = false;
          clearHold();
          holdTimer = setTimeout(() => {
            longPressed = true;
            if (navigator.vibrate) navigator.vibrate(40);
            this.openSettingsSheet();
          }, 850);
        });

        orbBtn.addEventListener('pointerup', () => {
          clearHold();
          if (!longPressed) {
            this._clearLiveWords();
            this._hideAiCapsule();
            this.startListening();
          }
        });

        orbBtn.addEventListener('pointercancel', clearHold);
      }

      // Tapping AI capsule also opens settings if desired or re-triggers listening
      const aiCapsule = document.getElementById('ai-response-capsule');
      if (aiCapsule) {
        aiCapsule.addEventListener('click', () => {
          this._hideAiCapsule();
          this.startListening();
        });
      }

      // Settings Sheet controls
      const sheetCloseBtn = document.getElementById('sheet-close-btn');
      const sheetBackdrop = document.getElementById('settings-sheet-backdrop');
      if (sheetCloseBtn) {
        sheetCloseBtn.addEventListener('click', () => this.closeSettingsSheet());
      }
      if (sheetBackdrop) {
        sheetBackdrop.addEventListener('click', (e) => {
          if (e.target === sheetBackdrop) this.closeSettingsSheet();
        });
      }

      const btnSaveKeys = document.getElementById('btn-save-api-keys');
      if (btnSaveKeys) {
        btnSaveKeys.addEventListener('click', () => {
          const gemKey = (document.getElementById('input-gemini-key')?.value || '').trim();
          const groqKey = (document.getElementById('input-groq-key')?.value || '').trim();
          localStorage.setItem('nova_gemini_api_key', gemKey);
          localStorage.setItem('nova_groq_api_key', groqKey);
          const bridge = window.NovaBridge || window.NovaNative;
          try {
            if (bridge && typeof bridge.setMemory === 'function') {
              bridge.setMemory('nova_gemini_api_key', gemKey);
              bridge.setMemory('nova_groq_api_key', groqKey);
            }
          } catch (e) {}
          btnSaveKeys.textContent = '✓ Saqlandi!';
          setTimeout(() => {
            btnSaveKeys.textContent = 'API Kalitlarni Saqlash';
          }, 1500);
        });
      }

      document.querySelectorAll('[data-perm]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const perm = btn.getAttribute('data-perm');
          const bridge = window.NovaBridge || window.NovaNative;
          try {
            if (bridge && typeof bridge.openPermissionSettings === 'function') {
              bridge.openPermissionSettings(perm);
            }
          } catch (e) {}
          setTimeout(() => this.refreshPermissionsUI(), 1500);
        });
      });
    }

    // ------------------------------------------------------------------------
    // 4. REAL DEVICE COMMANDS & GEMINI / GROQ FETCH
    // ------------------------------------------------------------------------
    async processFinalSpeech(text) {
      const deviceRes = this._tryDeviceAction(text);
      if (deviceRes) {
        this._clearLiveWords();
        this._showAiCapsule(deviceRes.reply);
        this.speak(deviceRes.reply);
        if (deviceRes.autoDismiss) {
          setTimeout(() => this.dismissOverlay(), 1000);
        }
        return;
      }

      const aiReply = await this._fetchAiReply(text);
      this._clearLiveWords();
      this._showAiCapsule(aiReply);
      this.speak(aiReply);
    }

    _tryDeviceAction(text) {
      const bridge = window.NovaBridge || window.NovaNative;
      const lower = text.toLowerCase().replace(/[‘’ʻʼ`´]/g, "'").trim();

      // 1) Open App ("Telegram Plus'ni och", "Instagramni och", "YouTube'ni och", "och ...")
      const openMatch =
        lower.match(/^(.+?)(?:'ni|ni|nı|\s+ilovasini)?\s+(?:och(?:ib\s+ber)?|ishga\s+tushir|yoq)$/i) ||
        lower.match(/^(?:och|open|открой|запусти)\s+(.+)$/i);

      if (openMatch) {
        let appQuery = openMatch[1].replace(/^(ilova|dastur|app)\s+/i, '').trim();
        if (appQuery.includes('qulf') || appQuery.includes('ekran')) {
          try {
            if (bridge && typeof bridge.unlockDevice === 'function') bridge.unlockDevice('');
          } catch (e) {}
          return { reply: 'Ekran qulfini ochdim!', autoDismiss: true };
        }

        let launched = '';
        try {
          if (bridge && typeof bridge.launchInstalledApp === 'function') {
            launched = bridge.launchInstalledApp(appQuery) || '';
          }
        } catch (e) {}

        if (launched) {
          return { reply: `${launched} ochilmoqda...`, autoDismiss: true };
        }
        return { reply: `"${appQuery}" ilovasi topilmadi.`, autoDismiss: false };
      }

      // 2) Send Telegram Plus Message ("Jamshidga salom deb yoz")
      const tgMatch = text.match(
        /(?:telegram(?: plus)?da\s+)?([a-zA-Z0-9_ʻʼ'‘’]+?)(?:ga|ka)\s+(.+?)\s+(?:deb\s+)?(?:yoz(?:ib\s+qo'y)?|jo'nat|yubor)/i
      );
      if (tgMatch) {
        const contact = tgMatch[1].trim();
        const msg = tgMatch[2].trim();
        try {
          if (bridge && typeof bridge.sendTelegramMessage === 'function') {
            bridge.sendTelegramMessage('org.telegram.plus', contact, msg);
          }
        } catch (e) {}
        return {
          reply: `Telegram Plus orqali ${contact}ga "${msg}" deb yozib yuboryapman.`,
          autoDismiss: false,
        };
      }

      // 3) Set System Alarm ("Soat 06:30 ga budilnik qo'y")
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
          if (bridge && typeof bridge.setSystemAlarm === 'function') {
            bridge.setSystemAlarm(h, m, 'NOVA Budilnik', true);
          }
        } catch (e) {}
        return {
          reply: `Soat ${hh}:${mm} ga budilnik o'rnatdim!`,
          autoDismiss: false,
        };
      }

      return null;
    }

    async _fetchAiReply(userText) {
      const geminiKey = (localStorage.getItem('nova_gemini_api_key') || '').trim();
      const groqKey =
        (localStorage.getItem('nova_groq_api_key') || '').trim() ||
        getDefaultGroqKey();

      const systemPrompt = `Sen NOVA — Android smartfonining shaffof ustki qatlamida ishlovchi jonli ovozli AI yordamchisan.
Qoidalar:
1. O'zbek tilida (yoki savol berilgan tilda) qisqa, aniq va samimiy (1-2 jumla) javob ber.
2. Agar foydalanuvchi ilova ochishni, budilnik qo'yishni yoki Telegramda xabar yozishni so'rasa, javob oxirida ACTION_JSON qo'sh:
   ACTION_JSON:{"action":"OPEN_APP","app":"Telegram Plus"}
   yoki ACTION_JSON:{"action":"SET_ALARM","hour":6,"minute":30,"label":"Bomdod"}
   yoki ACTION_JSON:{"action":"SEND_TG","contact":"Jamshid","text":"Salom"}`;

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
              generationConfig: { temperature: 0.55, maxOutputTokens: 200 },
            }),
          });
          if (resp.ok) {
            const data = await resp.json();
            const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
            if (raw.trim()) return this._handleActionTag(raw.trim());
          }
        } catch (e) {}
      }

      if (groqKey) {
        try {
          this.chatHistory.push({ role: 'user', content: userText });
          if (this.chatHistory.length > 8) this.chatHistory = this.chatHistory.slice(-8);

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
                max_tokens: 200,
              }),
            }
          );
          if (resp.ok) {
            const data = await resp.json();
            const raw = data?.choices?.[0]?.message?.content || '';
            if (raw.trim()) {
              const cleaned = this._handleActionTag(raw.trim());
              this.chatHistory.push({ role: 'assistant', content: cleaned });
              return cleaned;
            }
          }
        } catch (e) {}
      }

      return "Eshityapman! Buyrug'ingizni ayting.";
    }

    _handleActionTag(rawReply) {
      const bridge = window.NovaBridge || window.NovaNative;
      let cleanText = rawReply;
      const idx = rawReply.indexOf('ACTION_JSON:');
      if (idx !== -1) {
        cleanText = rawReply.slice(0, idx).trim();
        const jsonStr = rawReply.slice(idx + 12).trim();
        try {
          const act = JSON.parse(jsonStr);
          if (act.action === 'OPEN_APP' && act.app && bridge?.launchInstalledApp) {
            bridge.launchInstalledApp(act.app);
            setTimeout(() => this.dismissOverlay(), 1000);
          } else if (act.action === 'SET_ALARM' && bridge?.setSystemAlarm) {
            bridge.setSystemAlarm(
              Number(act.hour || 7),
              Number(act.minute || 0),
              act.label || 'NOVA Budilnik',
              true
            );
          } else if (act.action === 'SEND_TG' && bridge?.sendTelegramMessage) {
            bridge.sendTelegramMessage(
              'org.telegram.plus',
              act.contact || 'Jamshid',
              act.text || 'Salom!'
            );
          }
        } catch (e) {}
      }
      return cleanText || 'Bajarildi!';
    }

    speak(text) {
      const bridge = window.NovaBridge || window.NovaNative;
      try {
        if (bridge && typeof bridge.speakUzbek === 'function') {
          bridge.speakUzbek(text);
        }
      } catch (e) {}
    }

    // ------------------------------------------------------------------------
    // 5. SETTINGS & PERMISSIONS SHEET
    // ------------------------------------------------------------------------
    _loadSavedKeys() {
      const gemInput = document.getElementById('input-gemini-key');
      const groqInput = document.getElementById('input-groq-key');
      if (gemInput) gemInput.value = localStorage.getItem('nova_gemini_api_key') || '';
      if (groqInput) groqInput.value = localStorage.getItem('nova_groq_api_key') || '';
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
      const bridge = window.NovaBridge || window.NovaNative;
      let status = {};
      try {
        if (bridge && typeof bridge.getPermissionsStatusJson === 'function') {
          status = JSON.parse(bridge.getPermissionsStatusJson() || '{}');
        }
      } catch (e) {}

      ['microphone', 'accessibility', 'overlay', 'phoneCalls', 'usageStats'].forEach((k) => {
        const btn = document.getElementById(`perm-btn-${k}`);
        if (!btn) return;
        const ok = !!status[k];
        btn.classList.toggle('granted', ok);
        btn.textContent = ok ? '✓ Yoqilgan' : 'Yoqish';
      });
    }

    dismissOverlay() {
      const bridge = window.NovaBridge || window.NovaNative;
      try {
        if (bridge && typeof bridge.hideOverlay === 'function') {
          bridge.hideOverlay();
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
    // 6. 60 FPS ADDITIVE-BLENDED 3D LIQUID PLASMA SPHERE & EDGE PARTICLE MIST
    // ------------------------------------------------------------------------
    _initMistParticles(count) {
      const list = [];
      for (let i = 0; i < count; i++) {
        list.push({
          x: Math.random(),
          y: Math.random(),
          r: 0.9 + Math.random() * 1.8,
          vy: 0.0018 + Math.random() * 0.0035,
          alpha: 0.25 + Math.random() * 0.65,
          seed: Math.random() * Math.PI * 2,
        });
      }
      return list;
    }

    _start60FpsLoop() {
      const orbCanvas = document.getElementById('plasma-orb-canvas');
      const orbCtx = orbCanvas ? orbCanvas.getContext('2d') : null;

      const mistCanvas = document.getElementById('bottom-mist-canvas');
      const mistCtx = mistCanvas ? mistCanvas.getContext('2d') : null;

      const resizeMist = () => {
        if (!mistCanvas) return;
        mistCanvas.width = window.innerWidth;
        mistCanvas.height = 240;
      };
      resizeMist();
      window.addEventListener('resize', resizeMist);

      const animate = () => {
        requestAnimationFrame(animate);

        this.smoothedEnergy =
          this.smoothedEnergy * 0.82 + this.voiceEnergy * 0.18;
        this.phase += 0.038 + this.smoothedEnergy * 0.11;

        if (orbCtx && orbCanvas) {
          this._draw3DLiquidPlasmaSphere(orbCtx, orbCanvas.width, orbCanvas.height);
        }
        if (mistCtx && mistCanvas) {
          this._drawBottomMist(mistCtx, mistCanvas.width, mistCanvas.height);
        }
      };

      requestAnimationFrame(animate);
    }

    _draw3DLiquidPlasmaSphere(ctx, w, h) {
      ctx.clearRect(0, 0, w, h);
      const cx = w * 0.5;
      const cy = h * 0.5;
      const baseR = w * 0.37;
      const energy = this.smoothedEnergy;

      ctx.save();

      // 1. Outer organic morphing liquid sphere clip
      ctx.beginPath();
      const steps = 80;
      for (let i = 0; i <= steps; i++) {
        const a = (i / steps) * Math.PI * 2;
        const deform =
          Math.sin(a * 3 + this.phase * 1.2) * (2.5 + energy * 8.5) +
          Math.cos(a * 4 - this.phase * 0.9) * (1.8 + energy * 6.0);
        const r = baseR + deform;
        const x = cx + Math.cos(a) * r;
        const y = cy + Math.sin(a) * r;
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.closePath();
      ctx.clip();

      // 2. Deep 3D volumetric sphere base gradient
      const coreGrad = ctx.createRadialGradient(
        cx - baseR * 0.3,
        cy - baseR * 0.35,
        baseR * 0.08,
        cx,
        cy,
        baseR * 1.18
      );
      coreGrad.addColorStop(0, '#7df9ff');
      coreGrad.addColorStop(0.35, '#0099ff');
      coreGrad.addColorStop(0.75, '#0038e8');
      coreGrad.addColorStop(1, '#00e1ff');
      ctx.fillStyle = coreGrad;
      ctx.fillRect(0, 0, w, h);

      // 3. Additive-blended multi-layer internal plasma waves
      ctx.globalCompositeOperation = 'lighter';
      const layers = [
        { color: 'rgba(0, 245, 255, 0.78)', width: 3.6, speed: 1.4, amp: 8 + energy * 18 },
        { color: 'rgba(120, 220, 255, 0.58)', width: 2.6, speed: -1.1, amp: 6 + energy * 14 },
        { color: 'rgba(255, 255, 255, 0.65)', width: 1.8, speed: 1.8, amp: 4 + energy * 11 },
      ];

      for (let l = 0; l < layers.length; l++) {
        const ly = layers[l];
        ctx.beginPath();
        for (let x = 0; x <= w; x += 3) {
          const normX = x / w;
          const envelope = Math.sin(normX * Math.PI);
          const wy =
            cy +
            Math.sin(normX * Math.PI * 2.5 + this.phase * ly.speed + l) *
              ly.amp *
              envelope;
          if (x === 0) ctx.moveTo(x, wy);
          else ctx.lineTo(x, wy);
        }
        ctx.strokeStyle = ly.color;
        ctx.lineWidth = ly.width;
        ctx.shadowColor = '#00f7ff';
        ctx.shadowBlur = 12 + energy * 14;
        ctx.stroke();
      }

      // 4. Top-left 3D specular highlight
      const spec = ctx.createRadialGradient(
        cx - baseR * 0.32,
        cy - baseR * 0.38,
        1,
        cx - baseR * 0.32,
        cy - baseR * 0.38,
        baseR * 0.55
      );
      spec.addColorStop(0, 'rgba(255, 255, 255, 0.55)');
      spec.addColorStop(1, 'rgba(255, 255, 255, 0)');
      ctx.fillStyle = spec;
      ctx.fillRect(0, 0, w, h);

      ctx.restore();
    }

    _drawBottomMist(ctx, w, h) {
      ctx.clearRect(0, 0, w, h);
      const energy = this.smoothedEnergy;

      const glow = ctx.createLinearGradient(0, h, 0, 0);
      glow.addColorStop(0, `rgba(0, 195, 255, ${0.22 + energy * 0.25})`);
      glow.addColorStop(0.5, 'rgba(0, 110, 255, 0.06)');
      glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = glow;
      ctx.fillRect(0, 0, w, h);

      for (const p of this.mistParticles) {
        p.y -= p.vy * (1 + energy * 2.4);
        if (p.y < 0) {
          p.y = 1;
          p.x = Math.random();
        }
        const px = p.x * w + Math.sin(this.phase + p.seed) * 5;
        const py = p.y * h;
        const fade = Math.sin(p.y * Math.PI);
        ctx.fillStyle = `rgba(186, 238, 255, ${p.alpha * fade})`;
        ctx.beginPath();
        ctx.arc(px, py, p.r, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  window.addEventListener('DOMContentLoaded', () => {
    const app = new NovaLiveOverlay();
    app.init();
    window.NovaHud = app;
  });
})();
