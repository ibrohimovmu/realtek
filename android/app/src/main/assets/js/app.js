/**
 * AURA Next-Gen Music Player
 * 120 FPS Vinyl Turntable, Dynamic Ambient Mesh Glow & Audio Engine Bridge
 */

(function () {
  'use strict';

  // Global event bus for native callbacks
  window.AuraEvents = {
    _handlers: {},
    on(event, fn) {
      if (!this._handlers[event]) this._handlers[event] = [];
      this._handlers[event].push(fn);
    },
    emit(event, payload) {
      const list = this._handlers[event];
      if (list) {
        for (let i = 0; i < list.length; i++) {
          try {
            list[i](payload);
          } catch (e) {}
        }
      }
    },
  };

  class AuraPlayer {
    constructor() {
      this.playlist = [];
      this.currentIndex = 0;
      this.isPlaying = false;
      this.currentTimeMs = 0;
      this.durationMs = 0;
      this.isShuffle = false;
      this.repeatMode = 1; // 0 = off, 1 = all, 2 = one
      this.favorites = new Set(
        JSON.parse(localStorage.getItem('aura_favorites') || '[]')
      );

      this.currentPalette = {
        primary: '#00f0ff',
        secondary: '#9d4edd',
        tertiary: '#ff2a85',
      };

      this.phase = 0;
      this.beatEnergy = 0.2;

      this._init();
    }

    _init() {
      this._bindUi();
      this._bindNativeBridge();
      this._startAmbientCanvasLoop();
      this._startSpectrumVisualizerLoop();
      this._setupVinylScratchInteractions();

      // Initial request for tracks
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.getPlaylistJson === 'function') {
        try {
          const raw = bridge.getPlaylistJson();
          if (raw && raw !== '[]') {
            this.setPlaylist(JSON.parse(raw));
          }
        } catch (e) {}
      }
    }

    // ========================================================================
    // 1. UI & CONTROL BINDINGS
    // ========================================================================
    _bindUi() {
      // Stage view mode tabs (Vinyl | Visualizer | Lyrics)
      const tabs = document.querySelectorAll('.mode-tab');
      tabs.forEach((tab) => {
        tab.addEventListener('click', () => {
          tabs.forEach((t) => t.classList.remove('active'));
          tab.classList.add('active');
          const target = tab.dataset.target;
          document.body.setAttribute('data-mode', target);
          document.querySelectorAll('.stage-section').forEach((sec) => {
            sec.classList.remove('active');
          });
          const activeSec = document.getElementById(`stage-${target}`);
          if (activeSec) activeSec.classList.add('active');
        });
      });

      // Transport Buttons
      const playBtn = document.getElementById('btn-play-pause');
      if (playBtn) {
        playBtn.addEventListener('click', () => this.togglePlayPause());
      }

      const nextBtn = document.getElementById('btn-next');
      if (nextBtn) {
        nextBtn.addEventListener('click', () => this.nextTrack());
      }

      const prevBtn = document.getElementById('btn-prev');
      if (prevBtn) {
        prevBtn.addEventListener('click', () => this.prevTrack());
      }

      const shuffleBtn = document.getElementById('btn-shuffle');
      if (shuffleBtn) {
        shuffleBtn.addEventListener('click', () => this.toggleShuffle());
      }

      const repeatBtn = document.getElementById('btn-repeat');
      if (repeatBtn) {
        repeatBtn.addEventListener('click', () => this.toggleRepeat());
      }

      const favBtn = document.getElementById('btn-favorite');
      if (favBtn) {
        favBtn.addEventListener('click', () => this.toggleFavorite());
      }

      // Seek Bar
      const seekContainer = document.getElementById('seek-container');
      if (seekContainer) {
        const handleSeek = (e) => {
          const rect = seekContainer.getBoundingClientRect();
          const clientX = e.touches ? e.touches[0].clientX : e.clientX;
          const pos = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
          const targetMs = Math.round(pos * this.durationMs);
          this.seekTo(targetMs);
        };

        seekContainer.addEventListener('mousedown', handleSeek);
        seekContainer.addEventListener('touchstart', handleSeek, { passive: true });
      }

      // Drawers: Library
      const btnOpenLibrary = document.getElementById('btn-open-library');
      const libraryDrawer = document.getElementById('library-drawer-backdrop');
      if (btnOpenLibrary && libraryDrawer) {
        btnOpenLibrary.addEventListener('click', () => {
          libraryDrawer.classList.add('open');
        });
        libraryDrawer.addEventListener('click', (e) => {
          if (e.target === libraryDrawer) libraryDrawer.classList.remove('open');
        });
      }

      const btnScan = document.getElementById('btn-scan-device');
      if (btnScan) {
        btnScan.addEventListener('click', () => {
          const bridge = window.AuraBridge || window.AuraNative;
          if (bridge && typeof bridge.scanLocalAudio === 'function') {
            bridge.scanLocalAudio();
          }
        });
      }

      const searchInput = document.getElementById('input-search-tracks');
      if (searchInput) {
        searchInput.addEventListener('input', (e) => {
          this.renderTrackList(e.target.value.toLowerCase().trim());
        });
      }

      // Drawers: Equalizer
      const btnOpenEq = document.getElementById('btn-open-eq');
      const eqBackdrop = document.getElementById('eq-modal-backdrop');
      const btnCloseEq = document.getElementById('btn-close-eq');
      if (btnOpenEq && eqBackdrop) {
        btnOpenEq.addEventListener('click', () => eqBackdrop.classList.add('open'));
        if (btnCloseEq) {
          btnCloseEq.addEventListener('click', () => eqBackdrop.classList.remove('open'));
        }
        eqBackdrop.addEventListener('click', (e) => {
          if (e.target === eqBackdrop) eqBackdrop.classList.remove('open');
        });
      }

      // Equalizer Sliders
      document.querySelectorAll('.vertical-slider').forEach((slider) => {
        slider.addEventListener('input', (e) => {
          const band = parseInt(e.target.dataset.band, 10);
          const val = parseInt(e.target.value, 10);
          const bridge = window.AuraBridge || window.AuraNative;
          if (bridge && typeof bridge.setEqualizerBand === 'function') {
            bridge.setEqualizerBand(band, val);
          }
        });
      });

      // Bass Boost Slider
      const bassSlider = document.getElementById('slider-bass-boost');
      const bassValText = document.getElementById('bass-strength-value');
      if (bassSlider) {
        bassSlider.addEventListener('input', (e) => {
          const val = parseInt(e.target.value, 10);
          if (bassValText) {
            bassValText.textContent = `${Math.round(val / 10)}% quvvat`;
          }
          const bridge = window.AuraBridge || window.AuraNative;
          if (bridge && typeof bridge.setBassBoost === 'function') {
            bridge.setBassBoost(val);
          }
        });
      }

      // Drawers: Sleep Timer
      const btnOpenTimer = document.getElementById('btn-open-timer');
      const timerBackdrop = document.getElementById('timer-modal-backdrop');
      const btnCloseTimer = document.getElementById('btn-close-timer');
      if (btnOpenTimer && timerBackdrop) {
        btnOpenTimer.addEventListener('click', () => timerBackdrop.classList.add('open'));
        if (btnCloseTimer) {
          btnCloseTimer.addEventListener('click', () => timerBackdrop.classList.remove('open'));
        }
        timerBackdrop.addEventListener('click', (e) => {
          if (e.target === timerBackdrop) timerBackdrop.classList.remove('open');
        });
      }

      document.querySelectorAll('.timer-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
          const mins = parseInt(btn.dataset.minutes, 10);
          const bridge = window.AuraBridge || window.AuraNative;
          if (bridge && typeof bridge.setSleepTimer === 'function') {
            bridge.setSleepTimer(mins);
          }
          if (timerBackdrop) timerBackdrop.classList.remove('open');
        });
      });

      // Lock Screen Ambient Mode Toggle
      const ambientBtn = document.getElementById('btn-toggle-ambient-mode');
      if (ambientBtn) {
        let isAmbientActive = true;
        ambientBtn.addEventListener('click', () => {
          isAmbientActive = !isAmbientActive;
          ambientBtn.classList.toggle('active', isAmbientActive);
          const bridge = window.AuraBridge || window.AuraNative;
          if (bridge && typeof bridge.setLockscreenAmbient === 'function') {
            bridge.setLockscreenAmbient(isAmbientActive);
          }
        });
      }
    }

    // ========================================================================
    // 2. NATIVE BRIDGE EVENTS
    // ========================================================================
    _bindNativeBridge() {
      window.AuraEvents.on('onTracksLoaded', (data) => {
        if (Array.isArray(data)) {
          this.setPlaylist(data);
        }
      });

      window.AuraEvents.on('onTrackChanged', (track) => {
        this.updateCurrentTrackUi(track);
      });

      window.AuraEvents.on('onPlaybackState', (info) => {
        this.isPlaying = info.state === 'playing';
        this.currentTimeMs = info.position || 0;
        this.durationMs = info.duration || this.durationMs;
        this.updatePlayPauseUi();
        this.updateProgressUi();
      });

      window.AuraEvents.on('onPlaybackProgress', (prog) => {
        this.currentTimeMs = prog.position || 0;
        this.durationMs = prog.duration || this.durationMs;
        this.updateProgressUi();
      });

      window.AuraEvents.on('onSleepTimerTick', (info) => {
        const badge = document.getElementById('timer-active-badge');
        const text = document.getElementById('timer-countdown-text');
        if (!badge || !text) return;
        if (info.remainingSeconds > 0) {
          badge.classList.remove('hidden');
          const m = Math.floor(info.remainingSeconds / 60);
          const s = info.remainingSeconds % 60;
          text.textContent = `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
        } else {
          badge.classList.add('hidden');
        }
      });
    }

    // ========================================================================
    // 3. PLAYLIST & TRACK RENDERING
    // ========================================================================
    setPlaylist(tracks) {
      if (!tracks || !tracks.length) return;
      this.playlist = tracks;

      const countPill = document.getElementById('library-count-pill');
      if (countPill) {
        countPill.textContent = `${tracks.length} trek`;
      }

      this.renderTrackList('');

      if (!this.isPlaying && tracks[0]) {
        this.updateCurrentTrackUi(tracks[0]);
      }
    }

    renderTrackList(filterQuery = '') {
      const container = document.getElementById('track-list');
      if (!container) return;
      container.innerHTML = '';

      const filtered = this.playlist.filter((t) => {
        if (!filterQuery) return true;
        const q = filterQuery.toLowerCase();
        return (
          (t.title && t.title.toLowerCase().includes(q)) ||
          (t.artist && t.artist.toLowerCase().includes(q)) ||
          (t.album && t.album.toLowerCase().includes(q))
        );
      });

      filtered.forEach((track, idx) => {
        const item = document.createElement('div');
        item.className = 'track-item' + (idx === this.currentIndex ? ' active' : '');

        const img = document.createElement('img');
        img.className = 'track-thumb';
        img.src =
          track.albumArt ||
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&q=80';
        img.onerror = () => {
          img.src = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&q=80';
        };

        const infoCol = document.createElement('div');
        infoCol.className = 'track-info-col';

        const title = document.createElement('div');
        title.className = 'track-item-title';
        title.textContent = track.title || 'Noma\'lum trek';

        const sub = document.createElement('div');
        sub.className = 'track-item-sub';
        sub.textContent = `${track.artist || 'AURA'} • ${track.album || ''}`;

        infoCol.appendChild(title);
        infoCol.appendChild(sub);

        const dur = document.createElement('div');
        dur.className = 'track-dur';
        dur.textContent = this.formatTime(track.duration || 0);

        item.appendChild(img);
        item.appendChild(infoCol);
        item.appendChild(dur);

        item.addEventListener('click', () => {
          this.playIndex(this.playlist.indexOf(track));
          const backdrop = document.getElementById('library-drawer-backdrop');
          if (backdrop) backdrop.classList.remove('open');
        });

        container.appendChild(item);
      });
    }

    // ========================================================================
    // 4. PLAYBACK CONTROLLER
    // ========================================================================
    playIndex(index) {
      if (index < 0 || index >= this.playlist.size) return;
      this.currentIndex = index;
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.playTrack === 'function') {
        bridge.playTrack(index);
      }
    }

    togglePlayPause() {
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.togglePlayPause === 'function') {
        bridge.togglePlayPause();
      } else {
        this.isPlaying = !this.isPlaying;
        this.updatePlayPauseUi();
      }
    }

    nextTrack() {
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.next === 'function') {
        bridge.next();
      }
    }

    prevTrack() {
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.prev === 'function') {
        bridge.prev();
      }
    }

    seekTo(ms) {
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.seekTo === 'function') {
        bridge.seekTo(ms);
      }
    }

    toggleShuffle() {
      this.isShuffle = !this.isShuffle;
      const btn = document.getElementById('btn-shuffle');
      if (btn) btn.classList.toggle('active', this.isShuffle);
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.setShuffle === 'function') {
        bridge.setShuffle(this.isShuffle);
      }
    }

    toggleRepeat() {
      this.repeatMode = (this.repeatMode + 1) % 3;
      const btn = document.getElementById('btn-repeat');
      if (btn) {
        btn.classList.toggle('active', this.repeatMode > 0);
      }
      const bridge = window.AuraBridge || window.AuraNative;
      if (bridge && typeof bridge.setRepeatMode === 'function') {
        bridge.setRepeatMode(this.repeatMode);
      }
    }

    toggleFavorite() {
      const track = this.playlist[this.currentIndex];
      if (!track) return;
      const idStr = String(track.id);
      const btn = document.getElementById('btn-favorite');
      if (this.favorites.has(idStr)) {
        this.favorites.delete(idStr);
        if (btn) btn.classList.remove('active');
      } else {
        this.favorites.add(idStr);
        if (btn) btn.classList.add('active');
      }
      localStorage.setItem('aura_favorites', JSON.stringify([...this.favorites]));
    }

    // ========================================================================
    // 5. UI UPDATERS
    // ========================================================================
    updateCurrentTrackUi(track) {
      if (!track) return;
      const title = document.getElementById('track-title');
      const artist = document.getElementById('track-artist');
      const vinylImg = document.getElementById('vinyl-album-img');
      const favBtn = document.getElementById('btn-favorite');

      if (title) title.textContent = track.title || 'Noma\'lum trek';
      if (artist) artist.textContent = `${track.artist || 'AURA'} • ${track.album || ''}`;

      const art =
        track.albumArt ||
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&q=80';
      if (vinylImg) {
        vinylImg.src = art;
        vinylImg.onerror = () => {
          vinylImg.src = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&q=80';
        };
      }

      if (favBtn) {
        favBtn.classList.toggle('active', this.favorites.has(String(track.id)));
      }

      this.durationMs = track.duration || 0;
      const timeDur = document.getElementById('time-duration');
      if (timeDur) timeDur.textContent = this.formatTime(this.durationMs);

      // Morph ambient colors based on track title hash
      this._morphColorsForTrack(track);

      // Highlight active in tracklist
      document.querySelectorAll('.track-item').forEach((item, idx) => {
        item.classList.toggle('active', idx === this.currentIndex);
      });
    }

    updatePlayPauseUi() {
      document.body.setAttribute('data-playing', this.isPlaying ? 'true' : 'false');
      const iconPlay = document.getElementById('icon-play');
      const iconPause = document.getElementById('icon-pause');
      if (iconPlay && iconPause) {
        if (this.isPlaying) {
          iconPlay.classList.add('hidden');
          iconPause.classList.remove('hidden');
        } else {
          iconPlay.classList.remove('hidden');
          iconPause.classList.add('hidden');
        }
      }
    }

    updateProgressUi() {
      const timeCur = document.getElementById('time-current');
      const timeDur = document.getElementById('time-duration');
      const fill = document.getElementById('seek-bar-fill');
      const thumb = document.getElementById('seek-thumb');

      if (timeCur) timeCur.textContent = this.formatTime(this.currentTimeMs);
      if (timeDur && this.durationMs > 0) {
        timeDur.textContent = this.formatTime(this.durationMs);
      }

      if (this.durationMs > 0) {
        const pct = Math.min(100, Math.max(0, (this.currentTimeMs / this.durationMs) * 100));
        if (fill) fill.style.width = `${pct}%`;
        if (thumb) thumb.style.left = `${pct}%`;
      }
    }

    formatTime(ms) {
      const totalSec = Math.floor(ms / 1000);
      const min = Math.floor(totalSec / 60);
      const sec = totalSec % 60;
      return `${min}:${String(sec).padStart(2, '0')}`;
    }

    _morphColorsForTrack(track) {
      const palettes = [
        { primary: '#00f0ff', secondary: '#9d4edd', tertiary: '#ff2a85' },
        { primary: '#ff007f', secondary: '#7928ca', tertiary: '#00f0ff' },
        { primary: '#00ffa3', secondary: '#0070f3', tertiary: '#7928ca' },
        { primary: '#ff6b00', secondary: '#ff0055', tertiary: '#6800ff' },
      ];
      const code = Math.abs(String(track.id || track.title).charCodeAt(0) || 0);
      this.currentPalette = palettes[code % palettes.length];
    }

    // ========================================================================
    // 6. 3D TURNTABLE DJ SCRATCH INTERACTION
    // ========================================================================
    _setupVinylScratchInteractions() {
      const disc = document.getElementById('vinyl-disc');
      if (!disc) return;

      let isScratching = false;
      let startAngle = 0;
      let lastScrubTime = 0;

      const getAngle = (e, rect) => {
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const x = (e.touches ? e.touches[0].clientX : e.clientX) - cx;
        const y = (e.touches ? e.touches[0].clientY : e.clientY) - cy;
        return Math.atan2(y, x);
      };

      const onStart = (e) => {
        isScratching = true;
        const rect = disc.getBoundingClientRect();
        startAngle = getAngle(e, rect);
      };

      const onMove = (e) => {
        if (!isScratching) return;
        const rect = disc.getBoundingClientRect();
        const currentAngle = getAngle(e, rect);
        const delta = currentAngle - startAngle;
        startAngle = currentAngle;

        const now = Date.now();
        if (now - lastScrubTime > 120 && this.durationMs > 0) {
          lastScrubTime = now;
          const seekOffset = delta * 4000;
          const newTarget = Math.max(0, Math.min(this.durationMs, this.currentTimeMs + seekOffset));
          this.seekTo(newTarget);
        }
      };

      const onEnd = () => {
        isScratching = false;
      };

      disc.addEventListener('mousedown', onStart);
      window.addEventListener('mousemove', onMove);
      window.addEventListener('mouseup', onEnd);

      disc.addEventListener('touchstart', onStart, { passive: true });
      window.addEventListener('touchmove', onMove, { passive: true });
      window.addEventListener('touchend', onEnd);
    }

    // ========================================================================
    // 7. 60 FPS DYNAMIC AMBIENT MESH GLOW CANVAS
    // ========================================================================
    _startAmbientCanvasLoop() {
      const canvas = document.getElementById('ambient-mesh-canvas');
      if (!canvas) return;
      const ctx = canvas.getContext('2d');

      const resize = () => {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
      };
      resize();
      window.addEventListener('resize', resize);

      let p = 0;
      const loop = () => {
        p += this.isPlaying ? 0.015 : 0.005;
        const w = canvas.width;
        const h = canvas.height;

        ctx.clearRect(0, 0, w, h);

        // Radial Mesh Blob 1 (Top Left)
        const x1 = w * 0.35 + Math.sin(p * 0.8) * 80;
        const y1 = h * 0.3 + Math.cos(p * 0.7) * 90;
        const r1 = Math.min(w, h) * 0.65;
        const g1 = ctx.createRadialGradient(x1, y1, 10, x1, y1, r1);
        g1.addColorStop(0, this.currentPalette.primary);
        g1.addColorStop(0.5, 'transparent');
        ctx.fillStyle = g1;
        ctx.fillRect(0, 0, w, h);

        // Radial Mesh Blob 2 (Center Right)
        const x2 = w * 0.7 + Math.cos(p * 0.6) * 70;
        const y2 = h * 0.45 + Math.sin(p * 0.9) * 80;
        const r2 = Math.min(w, h) * 0.55;
        const g2 = ctx.createRadialGradient(x2, y2, 10, x2, y2, r2);
        g2.addColorStop(0, this.currentPalette.secondary);
        g2.addColorStop(0.5, 'transparent');
        ctx.fillStyle = g2;
        ctx.fillRect(0, 0, w, h);

        // Radial Mesh Blob 3 (Bottom Center)
        const x3 = w * 0.5 + Math.sin(p * 0.5) * 60;
        const y3 = h * 0.75 + Math.cos(p * 0.4) * 50;
        const r3 = Math.min(w, h) * 0.7;
        const g3 = ctx.createRadialGradient(x3, y3, 10, x3, y3, r3);
        g3.addColorStop(0, this.currentPalette.tertiary);
        g3.addColorStop(0.5, 'transparent');
        ctx.fillStyle = g3;
        ctx.fillRect(0, 0, w, h);

        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    }

    // ========================================================================
    // 8. 60/120 FPS LIVE SPECTRUM VISUALIZER (Waveform + Neon Bars)
    // ========================================================================
    _startSpectrumVisualizerLoop() {
      const canvas = document.getElementById('live-spectrum-canvas');
      if (!canvas) return;
      const ctx = canvas.getContext('2d');

      const resize = () => {
        canvas.width = canvas.clientWidth || 320;
        canvas.height = canvas.clientHeight || 220;
      };
      resize();
      window.addEventListener('resize', resize);

      const barCount = 42;
      let phase = 0;

      const loop = () => {
        phase += this.isPlaying ? 0.05 : 0.01;
        const w = canvas.width;
        const h = canvas.height;
        ctx.clearRect(0, 0, w, h);

        const energy = this.isPlaying ? 0.85 : 0.15;
        const barWidth = (w / barCount) * 0.65;
        const gap = (w / barCount) * 0.35;

        // Draw Mirrored Neon Spectrum Bars
        ctx.shadowBlur = 14;
        ctx.shadowColor = this.currentPalette.primary;

        for (let i = 0; i < barCount; i++) {
          const norm = i / barCount;
          const wave =
            Math.sin(norm * Math.PI * 3 + phase * 2.5) * 0.4 +
            Math.cos(norm * Math.PI * 6 - phase * 1.8) * 0.3 +
            Math.sin(phase * 4 + i * 0.2) * 0.3;

          const barHeight = Math.max(6, Math.abs(wave) * (h * 0.45) * energy);
          const x = i * (barWidth + gap);
          const y = h / 2 - barHeight / 2;

          const grad = ctx.createLinearGradient(0, y, 0, y + barHeight);
          grad.addColorStop(0, this.currentPalette.primary);
          grad.addColorStop(0.5, this.currentPalette.secondary);
          grad.addColorStop(1, this.currentPalette.tertiary);

          ctx.fillStyle = grad;
          ctx.beginPath();
          ctx.roundRect(x, y, barWidth, barHeight, 4);
          ctx.fill();
        }

        ctx.shadowBlur = 0;
        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    }
  }

  // Initialize AURA player on DOM Ready
  window.addEventListener('DOMContentLoaded', () => {
    window.Aura = new AuraPlayer();
  });
})();
