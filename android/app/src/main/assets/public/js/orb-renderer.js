/**
 * ============================================================================
 * NOVA ORB ENGINE (60/120 FPS Canvas 2D Additive-Blending Visualizer)
 * ============================================================================
 * 4 Minimalist FFT Audio-Reactive Skins:
 *   1. 'cyan_ring'      -> Nova Cyan Ring (#00F0FF, #0066FF) 4-layer liquid plasma
 *   2. 'solar_eclipse'  -> Solar Eclipse (#FF5500, #FFFFFF) coronal ring around pitch black
 *   3. 'quantum_sphere' -> Quantum Particle Sphere (1,500 3D projected particles)
 *   4. 'violet_aura'    -> Violet Aura (#7B2CBF, #3A86FF) soft pulsing harmonic ring
 *
 * Zero-UI Hidden Gestures:
 *   - Tap on Orb: Toggle Voice Listening
 *   - 1.5s Long-Press on Orb: Open Hidden "Nova Studio"
 *   - 2-Finger Swipe Up: Open Hidden "Nova Studio"
 *   - 1-Finger Swipe Down on Orb: Toggle Compact Bottom Pill Mode
 */
(function (global) {
  'use strict';

  class NovaOrbRenderer {
    constructor(canvasOrId) {
      this.canvas = typeof canvasOrId === 'string'
        ? document.getElementById(canvasOrId)
        : canvasOrId;
      this.ctx = this.canvas.getContext('2d', { alpha: true });
      this.skin = localStorage.getItem('nova_orb_skin') || 'cyan_ring';
      this.compactMode = false;
      this.state = 'idle'; // 'idle' | 'listening' | 'thinking' | 'speaking'
      this.phase = 0;

      // Audio FFT bins (64 bins normalized 0..1)
      this.fftBins = new Float32Array(64);
      this.rmsEnergy = 0.04;
      this.smoothedEnergy = 0.04;

      // 1,500 3D Fibonacci sphere particles for 'quantum_sphere'
      this.particles = this._initQuantumParticles(1500);

      // Long-Press (1.5s) & Multi-Touch Gesture state
      this.longPressTimer = null;
      this.longPressStartMs = 0;
      this.longPressActive = false;
      this.longPressProgress = 0;
      this.touchStartY = 0;
      this.touchStartX = 0;
      this.twoFingerStartY = null;

      this.onOrbTap = null;
      this.onOpenStudio = null;
      this.onToggleCompact = null;

      this._resize();
      window.addEventListener('resize', () => this._resize());
      this._bindGestures();
      this._animate = this._animate.bind(this);
      requestAnimationFrame(this._animate);
    }

    _initQuantumParticles(count) {
      const pts = [];
      const goldenAngle = Math.PI * (3 - Math.sqrt(5));
      for (let i = 0; i < count; i++) {
        const y = 1 - (i / (count - 1)) * 2;
        const radius = Math.sqrt(1 - y * y);
        const theta = goldenAngle * i;
        const x = Math.cos(theta) * radius;
        const z = Math.sin(theta) * radius;
        pts.push({
          bx: x,
          by: y,
          bz: z,
          seed: (i % 64),
          size: 1.0 + (i % 3) * 0.45
        });
      }
      return pts;
    }

    _resize() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
      this.width = window.innerWidth;
      this.height = window.innerHeight;
      this.canvas.width = Math.floor(this.width * dpr);
      this.canvas.height = Math.floor(this.height * dpr);
      this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    setSkin(skinName) {
      this.skin = skinName;
      localStorage.setItem('nova_orb_skin', skinName);
    }

    setState(newState) {
      this.state = String(newState || 'idle').toLowerCase();
    }

    feedAudioSpectrum(byteFreqArray, rms) {
      this.feedAudioFrequencyData(byteFreqArray, rms);
    }

    setCompactMode(compact) {
      this.compactMode = !!compact;
      document.body.classList.toggle('compact-pill-mode', this.compactMode);
    }

    feedAudioFrequencyData(byteFreqArray, rms) {
      if (!byteFreqArray || !byteFreqArray.length) {
        this.rmsEnergy = 0.03;
        return;
      }
      const step = Math.max(1, Math.floor(byteFreqArray.length / 64));
      for (let i = 0; i < 64; i++) {
        const val = (byteFreqArray[i * step] || 0) / 255.0;
        this.fftBins[i] = this.fftBins[i] * 0.72 + val * 0.28;
      }
      this.rmsEnergy = Math.min(1.0, Math.max(0.02, rms || 0.05));
    }

    _bindGestures() {
      const clearHold = () => {
        if (this.longPressTimer) {
          clearTimeout(this.longPressTimer);
          this.longPressTimer = null;
        }
        this.longPressActive = false;
        this.longPressProgress = 0;
      };

      this.canvas.addEventListener('pointerdown', (e) => {
        this.touchStartX = e.clientX;
        this.touchStartY = e.clientY;
        this.longPressStartMs = performance.now();
        this.longPressActive = true;

        clearTimeout(this.longPressTimer);
        this.longPressTimer = setTimeout(() => {
          this.longPressActive = false;
          this.longPressProgress = 0;
          if (navigator.vibrate) navigator.vibrate(45);
          if (typeof this.onOpenStudio === 'function') {
            this.onOpenStudio();
          }
        }, 1500);
      });

      this.canvas.addEventListener('pointermove', (e) => {
        if (!this.longPressActive) return;
        const dx = e.clientX - this.touchStartX;
        const dy = e.clientY - this.touchStartY;
        if (Math.hypot(dx, dy) > 28) {
          clearHold();
          // Single-finger swipe down toggles Compact Bottom Pill Mode
          if (dy > 75 && Math.abs(dx) < 50) {
            this.setCompactMode(!this.compactMode);
            if (typeof this.onToggleCompact === 'function') {
              this.onToggleCompact(this.compactMode);
            }
          }
        }
      });

      this.canvas.addEventListener('pointerup', (e) => {
        const elapsed = performance.now() - this.longPressStartMs;
        const wasHolding = this.longPressActive;
        clearHold();
        if (wasHolding && elapsed < 550) {
          const dx = Math.abs(e.clientX - this.touchStartX);
          const dy = Math.abs(e.clientY - this.touchStartY);
          if (dx < 22 && dy < 22 && typeof this.onOrbTap === 'function') {
            this.onOrbTap();
          }
        }
      });

      this.canvas.addEventListener('pointercancel', clearHold);

      // 2-Finger Swipe Up Gesture to Open Nova Studio
      window.addEventListener('touchstart', (e) => {
        if (e.touches && e.touches.length === 2) {
          clearHold();
          this.twoFingerStartY = (e.touches[0].clientY + e.touches[1].clientY) * 0.5;
        }
      }, { passive: true });

      window.addEventListener('touchmove', (e) => {
        if (e.touches && e.touches.length === 2 && this.twoFingerStartY !== null) {
          const curY = (e.touches[0].clientY + e.touches[1].clientY) * 0.5;
          if (this.twoFingerStartY - curY > 70) {
            this.twoFingerStartY = null;
            if (navigator.vibrate) navigator.vibrate(35);
            if (typeof this.onOpenStudio === 'function') {
              this.onOpenStudio();
            }
          }
        }
      }, { passive: true });
    }

    _animate(now) {
      requestAnimationFrame(this._animate);
      const ctx = this.ctx;
      const w = this.width;
      const h = this.height;

      // Smooth audio energy + synthetic breathing when idle/speaking
      let targetEnergy = this.rmsEnergy;
      if (this.state === 'thinking') {
        targetEnergy = 0.25 + 0.15 * Math.sin(now * 0.006);
      } else if (this.state === 'speaking') {
        targetEnergy = Math.max(this.rmsEnergy, 0.32 + 0.22 * Math.abs(Math.sin(now * 0.009)));
      } else if (this.state === 'idle') {
        targetEnergy = 0.05 + 0.025 * Math.sin(now * 0.0022);
      }
      this.smoothedEnergy = this.smoothedEnergy * 0.86 + targetEnergy * 0.14;
      this.phase += 0.014 + this.smoothedEnergy * 0.045;

      ctx.clearRect(0, 0, w, h);

      const cx = w * 0.5;
      const cy = this.compactMode ? (h - 115) : (h * 0.48);
      const baseRadius = this.compactMode
        ? Math.min(w, h) * 0.17
        : Math.min(w, h) * 0.31;

      switch (this.skin) {
        case 'solar_eclipse':
          this._drawSolarEclipse(ctx, cx, cy, baseRadius);
          break;
        case 'quantum_sphere':
          this._drawQuantumSphere(ctx, cx, cy, baseRadius);
          break;
        case 'violet_aura':
          this._drawVioletAura(ctx, cx, cy, baseRadius);
          break;
        case 'cyan_ring':
        default:
          this._drawCyanRing(ctx, cx, cy, baseRadius);
          break;
      }

      // Draw subtle radial progress arc during 1.5s Long-Press for Nova Studio
      if (this.longPressActive) {
        const heldMs = performance.now() - this.longPressStartMs;
        if (heldMs > 180) {
          const prog = Math.min(1.0, (heldMs - 180) / 1320);
          ctx.save();
          ctx.beginPath();
          ctx.arc(cx, cy, baseRadius * 1.18, -Math.PI / 2, -Math.PI / 2 + prog * Math.PI * 2);
          ctx.strokeStyle = 'rgba(0, 240, 255, 0.75)';
          ctx.lineWidth = 2.5;
          ctx.stroke();
          ctx.restore();
        }
      }
    }

    /**
     * SKIN 1: "Nova Cyan Ring" (#00F0FF, #0066FF)
     * 4 overlapping additive-blended liquid plasma rings.
     */
    _drawCyanRing(ctx, cx, cy, baseR) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';

      // Soft outer atmospheric bloom
      const bloomGrad = ctx.createRadialGradient(cx, cy, baseR * 0.65, cx, cy, baseR * 1.45);
      bloomGrad.addColorStop(0, 'rgba(0, 102, 255, 0.0)');
      bloomGrad.addColorStop(0.5, `rgba(0, 240, 255, ${0.12 + this.smoothedEnergy * 0.22})`);
      bloomGrad.addColorStop(1, 'rgba(0, 102, 255, 0.0)');
      ctx.fillStyle = bloomGrad;
      ctx.beginPath();
      ctx.arc(cx, cy, baseR * 1.45, 0, Math.PI * 2);
      ctx.fill();

      const layers = [
        { color: '#0066FF', alpha: 0.65, width: 6.5, speed: 1.0, freq: 3, amp: 14 },
        { color: '#00F0FF', alpha: 0.85, width: 3.2, speed: -1.35, freq: 4, amp: 18 },
        { color: '#0099FF', alpha: 0.55, width: 4.5, speed: 0.75, freq: 5, amp: 12 },
        { color: '#E0FFFF', alpha: 0.90, width: 1.8, speed: -0.9, freq: 6, amp: 9 }
      ];

      const segments = 120;
      for (let l = 0; l < layers.length; l++) {
        const layer = layers[l];
        ctx.beginPath();
        for (let i = 0; i <= segments; i++) {
          const angle = (i / segments) * Math.PI * 2;
          const binIdx = Math.floor(((i / segments) * 64)) % 64;
          const fftBoost = this.fftBins[binIdx] * (baseR * 0.24);
          const wave1 = Math.sin(angle * layer.freq + this.phase * layer.speed + l) * layer.amp * (0.35 + this.smoothedEnergy * 1.4);
          const wave2 = Math.cos(angle * (layer.freq + 2) - this.phase * layer.speed * 0.8) * (layer.amp * 0.5) * (0.25 + this.smoothedEnergy);
          const r = baseR + wave1 + wave2 + fftBoost * (l % 2 === 0 ? 1 : -0.6);

          const x = cx + Math.cos(angle) * r;
          const y = cy + Math.sin(angle) * r;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
        ctx.strokeStyle = layer.color;
        ctx.globalAlpha = layer.alpha;
        ctx.lineWidth = layer.width + this.smoothedEnergy * 3.0;
        ctx.shadowColor = layer.color;
        ctx.shadowBlur = 22 + this.smoothedEnergy * 24;
        ctx.stroke();
      }

      ctx.restore();
    }

    /**
     * SKIN 2: "Solar Eclipse" (#FF5500, #FFFFFF)
     * Pitch-black core with blazing coronal flares & thin white-hot horizon.
     */
    _drawSolarEclipse(ctx, cx, cy, baseR) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';

      // Coronal orange-amber outer glow
      const coronaGrad = ctx.createRadialGradient(cx, cy, baseR * 0.92, cx, cy, baseR * 1.55);
      coronaGrad.addColorStop(0, `rgba(255, 255, 255, ${0.55 + this.smoothedEnergy * 0.35})`);
      coronaGrad.addColorStop(0.18, `rgba(255, 85, 0, ${0.48 + this.smoothedEnergy * 0.35})`);
      coronaGrad.addColorStop(0.55, `rgba(180, 30, 0, ${0.15 + this.smoothedEnergy * 0.2})`);
      coronaGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = coronaGrad;
      ctx.beginPath();
      ctx.arc(cx, cy, baseR * 1.55, 0, Math.PI * 2);
      ctx.fill();

      // Dynamic solar prominences reacting to FFT
      const segments = 140;
      for (let pass = 0; pass < 2; pass++) {
        ctx.beginPath();
        for (let i = 0; i <= segments; i++) {
          const angle = (i / segments) * Math.PI * 2;
          const bin = this.fftBins[i % 64];
          const flare = Math.sin(angle * 7 + this.phase * (pass === 0 ? 1.2 : -1.5)) * (6 + this.smoothedEnergy * 22) + bin * 18;
          const r = baseR + Math.max(0, flare);
          const x = cx + Math.cos(angle) * r;
          const y = cy + Math.sin(angle) * r;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
        ctx.strokeStyle = pass === 0 ? '#FF5500' : '#FFFFFF';
        ctx.lineWidth = pass === 0 ? 4.2 : 1.6;
        ctx.shadowColor = '#FF5500';
        ctx.shadowBlur = 26;
        ctx.stroke();
      }

      // Pitch-black eclipse occluder disc
      ctx.globalCompositeOperation = 'source-over';
      ctx.fillStyle = '#020108';
      ctx.beginPath();
      ctx.arc(cx, cy, baseR * 0.96, 0, Math.PI * 2);
      ctx.fill();

      ctx.restore();
    }

    /**
     * SKIN 3: "Quantum Particle Sphere" (1,500 3D Projected Particles)
     * Rotates in 3D space and ripples with harmonic frequency bins.
     */
    _drawQuantumSphere(ctx, cx, cy, baseR) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';

      const rotY = this.phase * 0.45;
      const rotX = Math.sin(this.phase * 0.25) * 0.35;
      const cosY = Math.cos(rotY);
      const sinY = Math.sin(rotY);
      const cosX = Math.cos(rotX);
      const sinX = Math.sin(rotX);

      const sphereR = baseR * 1.08;
      const pts = this.particles;
      const len = pts.length;

      for (let i = 0; i < len; i++) {
        const p = pts[i];
        const fftVal = this.fftBins[p.seed];
        const ripple = 1.0 + Math.sin(p.by * 6 + this.phase * 2.2) * (0.04 + this.smoothedEnergy * 0.18) + fftVal * 0.22;

        const px = p.bx * ripple;
        const py = p.by * ripple;
        const pz = p.bz * ripple;

        // 3D rotation around Y then X
        const x1 = px * cosY - pz * sinY;
        const z1 = pz * cosY + px * sinY;
        const y2 = py * cosX - z1 * sinX;
        const z2 = z1 * cosX + py * sinX;

        // Perspective projection
        const depth = 2.6 / (2.6 - z2 * 0.85);
        const sx = cx + x1 * sphereR * depth;
        const sy = cy + y2 * sphereR * depth;

        const alpha = Math.max(0.08, Math.min(0.95, (z2 + 1.15) * 0.46));
        const dotR = p.size * depth * (0.85 + fftVal * 0.6);

        ctx.fillStyle = z2 > 0.25
          ? `rgba(255, 255, 255, ${alpha})`
          : `rgba(140, 220, 255, ${alpha * 0.7})`;
        ctx.fillRect(sx - dotR * 0.5, sy - dotR * 0.5, dotR, dotR);
      }

      ctx.restore();
    }

    /**
     * SKIN 4: "Violet Aura" (#7B2CBF, #3A86FF)
     * Soft multi-lobed violet-blue harmonic aura rings.
     */
    _drawVioletAura(ctx, cx, cy, baseR) {
      ctx.save();
      ctx.globalCompositeOperation = 'lighter';

      const auraGrad = ctx.createRadialGradient(cx, cy, baseR * 0.5, cx, cy, baseR * 1.5);
      auraGrad.addColorStop(0, 'rgba(123, 44, 191, 0.0)');
      auraGrad.addColorStop(0.55, `rgba(123, 44, 191, ${0.18 + this.smoothedEnergy * 0.25})`);
      auraGrad.addColorStop(0.8, `rgba(58, 134, 255, ${0.12 + this.smoothedEnergy * 0.2})`);
      auraGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');
      ctx.fillStyle = auraGrad;
      ctx.beginPath();
      ctx.arc(cx, cy, baseR * 1.5, 0, Math.PI * 2);
      ctx.fill();

      const lobes = [
        { color: '#7B2CBF', width: 7.0, speed: 0.8, k: 3, amp: 16 },
        { color: '#3A86FF', width: 4.0, speed: -1.1, k: 4, amp: 20 },
        { color: '#C77DFF', width: 2.2, speed: 1.4, k: 5, amp: 12 }
      ];

      const segs = 120;
      for (let l = 0; l < lobes.length; l++) {
        const lb = lobes[l];
        ctx.beginPath();
        for (let i = 0; i <= segs; i++) {
          const a = (i / segs) * Math.PI * 2;
          const fft = this.fftBins[i % 64] * (baseR * 0.22);
          const dr = Math.sin(a * lb.k + this.phase * lb.speed) * lb.amp * (0.4 + this.smoothedEnergy * 1.3) + fft;
          const r = baseR + dr;
          const x = cx + Math.cos(a) * r;
          const y = cy + Math.sin(a) * r;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.closePath();
        ctx.strokeStyle = lb.color;
        ctx.lineWidth = lb.width + this.smoothedEnergy * 2.5;
        ctx.shadowColor = lb.color;
        ctx.shadowBlur = 28;
        ctx.stroke();
      }

      ctx.restore();
    }
  }

  global.NovaOrbRenderer = NovaOrbRenderer;
})(window);
