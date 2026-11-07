/**
 * ============================================================================
 * NOVA — MASTER ZERO-UI CONTROLLER & HIDDEN NOVA STUDIO ENGINE (`app.js`)
 * ============================================================================
 * Coordinates:
 *  - Pure Zero-UI Main Screen & Bixby-style Compact Bottom Pill Mode
 *  - 60/120 FPS Additive-Blended Orb Renderer (4 skins)
 *  - Voice Biometric Lock (3 samples) + Semantic End-of-Turn VAD
 *  - Hidden Nova Studio Glassmorphic Sheet (opened ONLY via 1.5s Long-Press
 *    on the Orb or Two-Finger Swipe Up)
 *  - Relationship Matrix, 6-Gudok Call Secretary, Telegram Plus Digital Twin,
 *    Focus Guardian (Instagram 10m blocker), 5-Mahal Namoz Alarms, and
 *    1-Tap Permission Center.
 * ============================================================================
 */
(function () {
  'use strict';

  // Global lightweight Event Bus
  class NovaEventBus {
    constructor() {
      this.listeners = {};
    }
    on(event, fn) {
      if (!this.listeners[event]) this.listeners[event] = [];
      this.listeners[event].push(fn);
    }
    emit(event, payload) {
      const list = this.listeners[event] || [];
      for (const fn of list) {
        try {
          fn(payload);
        } catch (e) {}
      }
    }
  }

  window.NovaEvents = new NovaEventBus();

  class NovaAppController {
    constructor() {
      this.orb = null;
      this.vad = null;
      this.isCompactPill = false;
      this.studioOpen = false;
      this.longPressTimer = null;
      this.twoFingerStartY = null;
    }

    init() {
      this._initOrb();
      this._initVoiceEngine();
      this._bindZeroUiGestures();
      this._bindStudioUI();
      this._bindSystemEvents();
      this._refreshAllStudioPanels();
    }

    _initOrb() {
      const canvas = document.getElementById('orb-canvas');
      if (!canvas || !window.NovaOrbRenderer) return;
      this.orb = new window.NovaOrbRenderer(canvas);
      window.NovaOrb = this.orb;

      const savedSkin = window.NovaVault
        ? window.NovaVault.getKV('orb_skin', 'cyan_ring')
        : 'cyan_ring';
      this.orb.setSkin(savedSkin || 'cyan_ring');
      this._highlightSkinCard(savedSkin || 'cyan_ring');
    }

    _initVoiceEngine() {
      if (!window.NovaVoiceEngine) return;
      this.vad = new window.NovaVoiceEngine({
        onSpectrum: (bins, rms) => {
          if (this.orb) this.orb.feedAudioSpectrum(bins, rms);
        },
        onStateChange: (state, info) => {
          if (this.orb) this.orb.setState(state);
          this._updateCenterTypography(state, info);
        },
        onPartialTranscript: (partial, semanticHold) => {
          const sub = document.getElementById('orb-subtitle');
          if (sub) {
            sub.textContent = semanticHold
              ? `${partial} ... (fikr davom etmoqda)`
              : partial;
            sub.classList.add('visible');
          }
        },
        onFinalUtterance: async (finalText, meta) => {
          const head = document.getElementById('orb-headline');
          const sub = document.getElementById('orb-subtitle');
          if (head) head.textContent = 'Nova';
          if (sub) {
            sub.textContent = finalText;
            sub.classList.add('visible');
          }
          if (window.NovaBrain) {
            await window.NovaBrain.processCommand(finalText, meta);
          }
        },
        onBiometricStatus: (bio) => {
          this._updateBiometricUI(bio);
        },
      });
      window.NovaVAD = this.vad;
    }

    _updateCenterTypography(state, info = {}) {
      const head = document.getElementById('orb-headline');
      const sub = document.getElementById('orb-subtitle');
      const pillText = document.getElementById('pill-transcript');
      if (!head || !sub) return;

      if (state === 'IDLE') {
        head.textContent = 'Hi';
        if (!info.keepSubtitle) {
          sub.classList.remove('visible');
        }
        if (pillText) pillText.textContent = 'Hi, Nova tayyor...';
      } else if (state === 'LISTENING') {
        head.textContent = 'Listening';
        if (info.message) {
          sub.textContent = info.message;
          sub.classList.add('visible');
        }
        if (pillText) pillText.textContent = 'Eshitmoqdaman bro...';
      } else if (state === 'THINKING') {
        head.textContent = 'Thinking';
        if (pillText) pillText.textContent = 'Tahlil qilmoqdaman...';
      } else if (state === 'SPEAKING') {
        head.textContent = 'Nova';
      }
    }

    // ------------------------------------------------------------------------
    // ZERO-UI GESTURE ENGINE
    // - Single tap on Orb: Start/toggle Hands-Free listening
    // - 1.5s Long-Press on Orb: Open hidden Nova Studio
    // - Two-Finger Swipe Up anywhere: Open hidden Nova Studio
    // - Swipe Down on Orb: Toggle Bixby-style Compact Bottom Pill mode
    // ------------------------------------------------------------------------
    _bindZeroUiGestures() {
      const stage = document.getElementById('zero-ui-stage');
      const hitTarget = document.getElementById('orb-hit-target');
      const pillBar = document.getElementById('compact-pill-bar');

      if (hitTarget) {
        let pressMoved = false;
        let startX = 0;
        let startY = 0;
        let longPressTriggered = false;

        const clearPress = () => {
          if (this.longPressTimer) {
            clearTimeout(this.longPressTimer);
            this.longPressTimer = null;
          }
        };

        hitTarget.addEventListener('pointerdown', (e) => {
          pressMoved = false;
          longPressTriggered = false;
          startX = e.clientX;
          startY = e.clientY;
          clearPress();
          this.longPressTimer = setTimeout(() => {
            longPressTriggered = true;
            this.openStudio();
          }, 1500);
        });

        hitTarget.addEventListener('pointermove', (e) => {
          if (Math.hypot(e.clientX - startX, e.clientY - startY) > 22) {
            pressMoved = true;
            clearPress();
          }
        });

        hitTarget.addEventListener('pointerup', (e) => {
          clearPress();
          const dy = e.clientY - startY;
          if (!longPressTriggered && dy > 95) {
            this.setCompactPillMode(true);
            return;
          }
          if (!longPressTriggered && !pressMoved) {
            this.toggleListening();
          }
        });

        hitTarget.addEventListener('pointercancel', clearPress);
      }

      // Two-Finger Swipe Up anywhere on Zero-UI stage opens Nova Studio
      if (stage) {
        stage.addEventListener(
          'touchstart',
          (e) => {
            if (e.touches && e.touches.length === 2) {
              this.twoFingerStartY =
                (e.touches[0].clientY + e.touches[1].clientY) * 0.5;
            } else {
              this.twoFingerStartY = null;
            }
          },
          { passive: true }
        );

        stage.addEventListener(
          'touchend',
          (e) => {
            if (this.twoFingerStartY !== null && e.changedTouches.length >= 1) {
              const endY = e.changedTouches[0].clientY;
              if (this.twoFingerStartY - endY > 70) {
                this.openStudio();
              }
              this.twoFingerStartY = null;
            }
          },
          { passive: true }
        );
      }

      // Compact Bottom Pill tap -> expand or listen
      if (pillBar) {
        let pillPressTimer = null;
        pillBar.addEventListener('pointerdown', () => {
          pillPressTimer = setTimeout(() => {
            this.setCompactPillMode(false);
          }, 800);
        });
        pillBar.addEventListener('pointerup', () => {
          if (pillPressTimer) {
            clearTimeout(pillPressTimer);
            pillPressTimer = null;
          }
          this.toggleListening();
        });
      }
    }

    toggleListening() {
      if (!this.vad) return;
      if (this.vad.isListening) {
        this.vad.stopListening();
      } else {
        this.vad.startListening();
      }
    }

    setCompactPillMode(enabled) {
      this.isCompactPill = !!enabled;
      const stage = document.getElementById('zero-ui-stage');
      if (stage) {
        stage.classList.toggle('compact-pill', this.isCompactPill);
      }
    }

    openStudio() {
      this.studioOpen = true;
      const backdrop = document.getElementById('nova-studio-backdrop');
      if (backdrop) {
        backdrop.classList.add('open');
      }
      this._refreshAllStudioPanels();
    }

    closeStudio() {
      this.studioOpen = false;
      const backdrop = document.getElementById('nova-studio-backdrop');
      if (backdrop) {
        backdrop.classList.remove('open');
      }
    }

    // ------------------------------------------------------------------------
    // SYSTEM & BRAIN EVENT LISTENERS
    // ------------------------------------------------------------------------
    _bindSystemEvents() {
      window.NovaEvents.on('brain:thinking', () => {
        if (this.orb) this.orb.setState('THINKING');
        this._updateCenterTypography('THINKING');
      });

      window.NovaEvents.on('brain:response', (res) => {
        const head = document.getElementById('orb-headline');
        const sub = document.getElementById('orb-subtitle');
        const pillText = document.getElementById('pill-transcript');
        if (head) head.textContent = res.headline || 'Nova';
        if (sub) {
          sub.textContent = res.reply || '';
          sub.classList.add('visible');
        }
        if (pillText) pillText.textContent = res.reply || '';
      });

      window.NovaEvents.on('tts:start', () => {
        if (this.orb) this.orb.setState('SPEAKING');
      });

      window.NovaEvents.on('tts:end', () => {
        if (this.orb) {
          this.orb.setState(
            this.vad && this.vad.isListening ? 'LISTENING' : 'IDLE'
          );
        }
        setTimeout(() => {
          if (!this.vad || !this.vad.isListening) {
            const head = document.getElementById('orb-headline');
            if (head) head.textContent = 'Hi';
          }
        }, 1800);
      });

      window.NovaEvents.on('secretary:status', (st) => {
        const head = document.getElementById('orb-headline');
        const sub = document.getElementById('orb-subtitle');
        if (head && st.headline) head.textContent = st.headline;
        if (sub && st.subtitle) {
          sub.textContent = st.subtitle;
          sub.classList.add('visible');
        }
        if (this.orb) {
          this.orb.setState(st.state === 'FINISHED' ? 'IDLE' : 'SPEAKING');
        }
      });

      window.NovaEvents.on('secretary:logs_updated', () => {
        this._renderCallSecretaryLogs();
      });

      window.NovaEvents.on('telegram:state_changed', () => {
        this._renderTelegramTwinPanel();
      });

      window.NovaEvents.on('focus:state_changed', () => {
        this._renderFocusAndPrayerPanel();
      });

      window.NovaEvents.on('focus:blocked', (payload) => {
        const head = document.getElementById('orb-headline');
        const sub = document.getElementById('orb-subtitle');
        if (head) head.textContent = 'Focus Lock';
        if (sub) {
          sub.textContent = payload.message;
          sub.classList.add('visible');
        }
      });

      // Native wake-word or lockscreen command hook
      window.addEventListener('nova:native', (ev) => {
        const detail = ev.detail || {};
        if (detail.type === 'voice:wake_triggered') {
          const cmd =
            (detail.payload && detail.payload.command) || '';
          if (cmd && window.NovaBrain) {
            window.NovaBrain.processCommand(cmd, { fromWakeService: true });
          } else if (this.vad && !this.vad.isListening) {
            this.vad.startListening();
          }
        }
      });
    }

    // ------------------------------------------------------------------------
    // HIDDEN NOVA STUDIO UI BINDINGS
    // ------------------------------------------------------------------------
    _bindStudioUI() {
      const closeBtn = document.getElementById('btn-close-studio');
      const backdrop = document.getElementById('nova-studio-backdrop');
      if (closeBtn) {
        closeBtn.addEventListener('click', () => this.closeStudio());
      }
      if (backdrop) {
        backdrop.addEventListener('click', (e) => {
          if (e.target === backdrop) this.closeStudio();
        });
      }

      // Studio Tabs
      const tabs = document.querySelectorAll('.studio-tab');
      tabs.forEach((btn) => {
        btn.addEventListener('click', () => {
          const target = btn.getAttribute('data-tab');
          tabs.forEach((b) => b.classList.remove('active'));
          btn.classList.add('active');
          document.querySelectorAll('.studio-panel').forEach((p) => {
            p.classList.toggle('active', p.id === `panel-${target}`);
          });
        });
      });

      // 1) Orb Skin Cards
      document.querySelectorAll('.skin-card').forEach((card) => {
        card.addEventListener('click', () => {
          const skin = card.getAttribute('data-skin');
          if (this.orb && skin) {
            this.orb.setSkin(skin);
            if (window.NovaVault) window.NovaVault.setKV('orb_skin', skin);
            this._highlightSkinCard(skin);
          }
        });
      });

      // Toggle Compact Pill Mode from Studio
      const btnTogglePill = document.getElementById('btn-toggle-pill-mode');
      if (btnTogglePill) {
        btnTogglePill.addEventListener('click', () => {
          this.setCompactPillMode(!this.isCompactPill);
          this.closeStudio();
        });
      }

      // Quick Command Input inside Studio
      const btnRunCmd = document.getElementById('btn-run-quick-cmd');
      const inputQuickCmd = document.getElementById('input-quick-cmd');
      if (btnRunCmd && inputQuickCmd) {
        btnRunCmd.addEventListener('click', async () => {
          const val = inputQuickCmd.value.trim();
          if (!val) return;
          inputQuickCmd.value = '';
          this.closeStudio();
          if (window.NovaBrain) {
            await window.NovaBrain.processCommand(val);
          }
        });
      }

      // 2) Voice Biometrics Enrollment (3 Samples) & Auto-Unlock PIN
      const btnEnrollVoice = document.getElementById('btn-enroll-voice');
      const btnResetVoice = document.getElementById('btn-reset-voice');
      const btnSavePin = document.getElementById('btn-save-unlock-pin');
      const btnTestUnlock = document.getElementById('btn-test-unlock');

      if (btnEnrollVoice) {
        btnEnrollVoice.addEventListener('click', async () => {
          if (!this.vad) return;
          btnEnrollVoice.textContent = 'Ovozingiz yozilmoqda (3 soniya gapiring)...';
          const res = await this.vad.enrollVoiceSample();
          btnEnrollVoice.textContent =
            res.samplesCount >= 3
              ? 'Ovoz biometrikasi faol (3/3)'
              : `Ovoz namunasini yozish (${res.samplesCount}/3)`;
          this._updateBiometricUI(res);
        });
      }

      if (btnResetVoice) {
        btnResetVoice.addEventListener('click', () => {
          if (this.vad) {
            this.vad.resetBiometrics();
            this._updateBiometricUI({ samplesCount: 0, lockedToOwner: false });
          }
        });
      }

      if (btnSavePin) {
        btnSavePin.addEventListener('click', () => {
          const pinInput = document.getElementById('input-unlock-pin');
          const pin = (pinInput && pinInput.value.trim()) || '0000';
          if (window.NovaVault) window.NovaVault.setKV('unlock_pin', pin);
          try {
            if (
              window.NovaNative &&
              typeof window.NovaNative.saveUnlockPin === 'function'
            ) {
              window.NovaNative.saveUnlockPin(pin);
            }
          } catch (e) {}
          btnSavePin.textContent = 'PIN Saqlandi!';
          setTimeout(() => {
            btnSavePin.textContent = 'PIN Saqlash';
          }, 1500);
        });
      }

      if (btnTestUnlock) {
        btnTestUnlock.addEventListener('click', () => {
          const pin = window.NovaVault
            ? window.NovaVault.getKV('unlock_pin', '0000')
            : '0000';
          try {
            if (
              window.NovaNative &&
              typeof window.NovaNative.unlockDevice === 'function'
            ) {
              window.NovaNative.unlockDevice(pin);
            }
          } catch (e) {}
          this.closeStudio();
          if (window.NovaBrain) {
            window.NovaBrain.speak(
              'Ovozli qulf ochish tizimi ishga tushirildi bro!'
            );
          }
        });
      }

      // 3) 6-Gudok Call Secretary & Relationship Matrix
      const btnAddContact = document.getElementById('btn-add-matrix-contact');
      const btnSimCall = document.getElementById('btn-simulate-6gudok');
      if (btnAddContact) {
        btnAddContact.addEventListener('click', () => {
          const nameEl = document.getElementById('matrix-name');
          const phoneEl = document.getElementById('matrix-phone');
          const catEl = document.getElementById('matrix-category');
          const name = nameEl ? nameEl.value.trim() : '';
          const phone = phoneEl ? phoneEl.value.trim() : '';
          const category = catEl ? catEl.value : 'DOST';
          if (!name) return;
          if (window.NovaVault) {
            window.NovaVault.upsertContact({ name, phone, category });
          }
          if (nameEl) nameEl.value = '';
          if (phoneEl) phoneEl.value = '';
          this._renderRelationshipMatrix();
        });
      }

      if (btnSimCall) {
        btnSimCall.addEventListener('click', () => {
          const simTarget =
            document.getElementById('select-sim-caller')?.value || 'Onam';
          this.closeStudio();
          if (window.NovaSecretary) {
            window.NovaSecretary.simulateIncomingCall(simTarget);
          }
        });
      }

      // 4) Telegram Plus (`org.telegram.plus`) & Ghost Twin Mode
      const toggleGhostTwin = document.getElementById('toggle-ghost-twin');
      const btnSendTgPlus = document.getElementById('btn-send-tg-plus');
      const btnSaveMtproto = document.getElementById('btn-save-mtproto');

      if (toggleGhostTwin) {
        toggleGhostTwin.addEventListener('click', () => {
          const next = !toggleGhostTwin.classList.contains('on');
          toggleGhostTwin.classList.toggle('on', next);
          if (window.NovaTelegram) window.NovaTelegram.setGhostTwinEnabled(next);
        });
      }

      if (btnSendTgPlus) {
        btnSendTgPlus.addEventListener('click', () => {
          const contact =
            document.getElementById('tg-target-contact')?.value.trim() ||
            'Jamshid';
          const msg =
            document.getElementById('tg-target-msg')?.value.trim() ||
            'Salom bro, nima gap?';
          if (window.NovaTelegram) {
            window.NovaTelegram.sendMessage(contact, msg, true);
          }
          const msgEl = document.getElementById('tg-target-msg');
          if (msgEl) msgEl.value = '';
          this._renderTelegramTwinPanel();
        });
      }

      if (btnSaveMtproto) {
        btnSaveMtproto.addEventListener('click', () => {
          const apiId = document.getElementById('tg-api-id')?.value || '';
          const apiHash = document.getElementById('tg-api-hash')?.value || '';
          const phone = document.getElementById('tg-phone')?.value || '';
          if (window.NovaTelegram) {
            window.NovaTelegram.saveMtprotoConfig(apiId, apiHash, phone);
          }
          btnSaveMtproto.textContent = 'Userbot Ulandi!';
          setTimeout(() => {
            btnSaveMtproto.textContent = 'MTProto Userbotni Saqlash';
          }, 1500);
        });
      }

      // 5) Focus Guardian (Instagram 10m Blocker) & 5-Mahal Namoz Alarms
      const toggleFocusGuard = document.getElementById('toggle-focus-guard');
      const btnTestIgBlock = document.getElementById('btn-test-ig-block');
      const btnSyncNamoz = document.getElementById('btn-sync-namoz-alarms');
      const btnAddPlan = document.getElementById('btn-add-daily-plan');

      if (toggleFocusGuard) {
        toggleFocusGuard.addEventListener('click', () => {
          const next = !toggleFocusGuard.classList.contains('on');
          toggleFocusGuard.classList.toggle('on', next);
          if (window.NovaFocusScheduler) {
            window.NovaFocusScheduler.setFocusGuardEnabled(next);
          }
        });
      }

      if (btnTestIgBlock) {
        btnTestIgBlock.addEventListener('click', () => {
          this.closeStudio();
          if (window.NovaFocusScheduler) {
            window.NovaFocusScheduler.triggerInstagramBlockNow();
          }
        });
      }

      if (btnSyncNamoz) {
        btnSyncNamoz.addEventListener('click', async () => {
          const cityInput = document.getElementById('input-prayer-city');
          const city = (cityInput && cityInput.value.trim()) || 'Namangan';
          btnSyncNamoz.textContent = "Vaqtlar olinmoqda va budilnik o'rnatilmoqda...";
          if (window.NovaFocusScheduler) {
            await window.NovaFocusScheduler.fetchPrayerTimes(city, true);
          }
          btnSyncNamoz.textContent = "5 Mahal Namoz Budilniklari O'rnatildi!";
          setTimeout(() => {
            btnSyncNamoz.textContent =
              "5 Mahal Namozga Avto-Budilnik O'rnatish";
          }, 2000);
          this._renderFocusAndPrayerPanel();
        });
      }

      if (btnAddPlan) {
        btnAddPlan.addEventListener('click', () => {
          const titleEl = document.getElementById('plan-title');
          const timeEl = document.getElementById('plan-time');
          const title = titleEl ? titleEl.value.trim() : '';
          const timeStr = timeEl ? timeEl.value.trim() : '07:00';
          if (!title) return;
          const parts = timeStr.split(':');
          const h = parseInt(parts[0] || '7', 10);
          const m = parseInt(parts[1] || '0', 10);
          if (window.NovaFocusScheduler) {
            window.NovaFocusScheduler.setSystemAlarm(h, m, title);
          }
          if (titleEl) titleEl.value = '';
          this._renderFocusAndPrayerPanel();
        });
      }

      // 6) 1-Tap Permission Center Buttons
      document.querySelectorAll('[data-perm-action]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const act = btn.getAttribute('data-perm-action');
          try {
            if (
              window.NovaNative &&
              typeof window.NovaNative.openPermissionSettings === 'function'
            ) {
              window.NovaNative.openPermissionSettings(act);
            }
          } catch (e) {}
          setTimeout(() => this._renderPermissionsStatus(), 1200);
        });
      });
    }

    _highlightSkinCard(skinName) {
      document.querySelectorAll('.skin-card').forEach((c) => {
        c.classList.toggle('selected', c.getAttribute('data-skin') === skinName);
      });
    }

    _refreshAllStudioPanels() {
      this._renderRelationshipMatrix();
      this._renderCallSecretaryLogs();
      this._renderTelegramTwinPanel();
      this._renderFocusAndPrayerPanel();
      this._renderPermissionsStatus();
      if (this.vad) {
        this._updateBiometricUI(this.vad.getBiometricState());
      }
    }

    _updateBiometricUI(bio = {}) {
      const badge = document.getElementById('bio-status-badge');
      const btnEnroll = document.getElementById('btn-enroll-voice');
      const count = Number(bio.samplesCount || 0);
      if (badge) {
        if (count >= 3) {
          badge.className = 'badge badge-ok';
          badge.textContent = `Tasdiqlangan (${count}/3 ovoz namunasi)`;
        } else {
          badge.className = 'badge badge-warn';
          badge.textContent = `${count}/3 namuna yozilgan`;
        }
      }
      if (btnEnroll) {
        btnEnroll.textContent =
          count >= 3
            ? 'Ovoz Biometrikasi Faol (Yangilash)'
            : `Ovoz Namunasini Yozish (${count}/3)`;
      }
    }

    _renderRelationshipMatrix() {
      const container = document.getElementById('relationship-matrix-list');
      if (!container || !window.NovaVault) return;
      const contacts = window.NovaVault.getContacts();
      container.innerHTML = contacts
        .map(
          (c) => `
        <div class="studio-row">
          <div class="studio-row-info">
            <div class="studio-row-title">${this._esc(c.name)} <span class="badge badge-cyan">${this._esc(c.category)}</span></div>
            <div class="studio-row-sub">${this._esc(c.phone || 'Raqam kiritilmagan')} • ${this._esc(c.relationLabel || '')}</div>
          </div>
          <button class="studio-btn" data-del-contact="${this._esc(c.name)}">O'chirish</button>
        </div>
      `
        )
        .join('');

      container.querySelectorAll('[data-del-contact]').forEach((btn) => {
        btn.addEventListener('click', () => {
          const name = btn.getAttribute('data-del-contact');
          window.NovaVault.removeContact(name);
          this._renderRelationshipMatrix();
        });
      });
    }

    _renderCallSecretaryLogs() {
      const container = document.getElementById('call-secretary-logs');
      if (!container || !window.NovaVault) return;
      const logs = window.NovaVault.getCallLogs();
      if (!logs.length) {
        container.innerHTML = `<div class="studio-row"><div class="studio-row-sub">Hozircha 6-gudok kotib yozuvlari yo'q. Yuqoridagi "6-Gudok Simulyatsiya" tugmasini bosing.</div></div>`;
        return;
      }
      container.innerHTML = logs
        .slice(0, 8)
        .map(
          (l) => `
        <div class="studio-card" style="padding:10px; margin-bottom:8px;">
          <div class="studio-row-title">${this._esc(l.callerName)} (${this._esc(l.category)}) — ${l.ringsCount} gudok</div>
          <div class="studio-row-sub" style="margin-top:4px; white-space:pre-line;">${this._esc(l.transcriptSummary)}</div>
        </div>
      `
        )
        .join('');
    }

    _renderTelegramTwinPanel() {
      if (!window.NovaTelegram) return;
      const st = window.NovaTelegram.getState();
      const toggle = document.getElementById('toggle-ghost-twin');
      if (toggle) toggle.classList.toggle('on', !!st.ghostTwinEnabled);

      const logBox = document.getElementById('tg-recent-messages');
      if (logBox) {
        if (!st.recentMessages.length) {
          logBox.innerHTML = `<div class="studio-row-sub">Telegram Plus (org.telegram.plus) ko'prigi tayyor.</div>`;
        } else {
          logBox.innerHTML = st.recentMessages
            .slice(0, 6)
            .map(
              (m) => `
            <div class="studio-row" style="margin-bottom:6px;">
              <div class="studio-row-info">
                <div class="studio-row-title">${this._esc(m.sender)} <span class="badge badge-cyan">${this._esc(m.mode)}</span></div>
                <div class="studio-row-sub">${this._esc(m.text)}</div>
              </div>
            </div>
          `
            )
            .join('');
        }
      }
    }

    _renderFocusAndPrayerPanel() {
      if (!window.NovaFocusScheduler) return;
      const st = window.NovaFocusScheduler.getState();
      const toggle = document.getElementById('toggle-focus-guard');
      if (toggle) toggle.classList.toggle('on', !!st.focusGuardEnabled);

      const cityInput = document.getElementById('input-prayer-city');
      if (cityInput && !cityInput.value) cityInput.value = st.city || 'Namangan';

      const grid = document.getElementById('prayer-times-grid');
      if (grid && st.prayerTimes) {
        const items = [
          { name: 'Bomdod', time: st.prayerTimes.Fajr },
          { name: 'Peshin', time: st.prayerTimes.Dhuhr },
          { name: 'Asr', time: st.prayerTimes.Asr },
          { name: 'Shom', time: st.prayerTimes.Maghrib },
          { name: 'Xufton', time: st.prayerTimes.Isha },
        ];
        grid.innerHTML = items
          .map(
            (i) => `
          <div class="prayer-pill">
            <div class="prayer-name">${i.name}</div>
            <div class="prayer-time">${i.time}</div>
          </div>
        `
          )
          .join('');
      }

      const plansBox = document.getElementById('daily-plans-list');
      if (plansBox && Array.isArray(st.plans)) {
        plansBox.innerHTML = st.plans
          .map(
            (p) => `
          <div class="studio-row" style="margin-bottom:6px;">
            <div class="studio-row-info">
              <div class="studio-row-title">${this._esc(p.title)}</div>
              <div class="studio-row-sub">Soat ${this._esc(p.timeStr)} • ${p.isPrayer ? '5-Mahal Namoz' : 'Shaxsiy reja'}</div>
            </div>
            <span class="badge ${p.isPrayer ? 'badge-cyan' : 'badge-ok'}">${this._esc(p.timeStr)}</span>
          </div>
        `
          )
          .join('');
      }
    }

    _renderPermissionsStatus() {
      let status = {
        accessibility: false,
        notificationListener: false,
        overlay: false,
        usageStats: false,
        rootAvailable: false,
      };
      try {
        if (
          window.NovaNative &&
          typeof window.NovaNative.getPermissionsStatus === 'function'
        ) {
          status = JSON.parse(window.NovaNative.getPermissionsStatus() || '{}');
        }
      } catch (e) {}

      const map = {
        'perm-badge-accessibility': status.accessibility,
        'perm-badge-notification': status.notificationListener,
        'perm-badge-overlay': status.overlay,
        'perm-badge-usage': status.usageStats,
        'perm-badge-root': status.rootAvailable,
      };

      Object.keys(map).forEach((id) => {
        const el = document.getElementById(id);
        if (!el) return;
        const ok = !!map[id];
        el.className = `badge ${ok ? 'badge-ok' : 'badge-warn'}`;
        el.textContent = ok ? 'Yoqilgan' : 'Ruxsat berish';
      });
    }

    _esc(str) {
      return String(str || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }
  }

  window.addEventListener('DOMContentLoaded', () => {
    const app = new NovaAppController();
    app.init();
    window.NovaApp = app;
  });
})();
