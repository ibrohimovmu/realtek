/**
 * RealStrike AR - Tactical Sound Synthesizer Engine
 * 100% Offline Web Audio API Synthesizer (Zero external file dependencies)
 */
class TacticalAudioEngine {
  constructor() {
    this.ctx = null;
    this.masterGain = null;
    this.muted = false;
    this.heartbeatTimer = null;
    this.initAudioContext();
  }

  initAudioContext() {
    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (AudioContextClass) {
        this.ctx = new AudioContextClass();
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.setValueAtTime(0.85, this.ctx.currentTime);
        this.masterGain.connect(this.ctx.destination);
      }
    } catch (e) {
      console.warn('Web Audio init postponed until user gesture', e);
    }
  }

  ensureContext() {
    if (!this.ctx) {
      this.initAudioContext();
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  // Create White/Pink Noise Buffer for Gunshots and Mechanical FX
  createNoiseBuffer(duration = 0.5) {
    if (!this.ctx) return null;
    const bufferSize = this.ctx.sampleRate * duration;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    return buffer;
  }

  // Gunshots
  playGunshot(weaponType = 'm416') {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    if (weaponType === 'akm') {
      // AKM 7.62 - Heavy bass blast, aggressive punch
      // 1. Low Thud (Oscillator sweep)
      const osc = this.ctx.createOscillator();
      const oscGain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(140, t);
      osc.frequency.exponentialRampToValueAtTime(32, t + 0.22);
      oscGain.gain.setValueAtTime(1.0, t);
      oscGain.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
      osc.connect(oscGain);
      oscGain.connect(this.masterGain);
      osc.start(t);
      osc.stop(t + 0.25);

      // 2. Heavy Noise Blast
      const noise = this.ctx.createBufferSource();
      noise.buffer = this.createNoiseBuffer(0.3);
      const filter = this.ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.setValueAtTime(1600, t);
      filter.frequency.exponentialRampToValueAtTime(250, t + 0.28);
      const noiseGain = this.ctx.createGain();
      noiseGain.gain.setValueAtTime(0.9, t);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, t + 0.28);
      noise.connect(filter);
      filter.connect(noiseGain);
      noiseGain.connect(this.masterGain);
      noise.start(t);

    } else if (weaponType === 'awm') {
      // AWM Magnum - Massive explosive crack + long tail + bolt action rack
      const osc = this.ctx.createOscillator();
      const oscGain = this.ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(180, t);
      osc.frequency.exponentialRampToValueAtTime(25, t + 0.45);
      oscGain.gain.setValueAtTime(1.2, t);
      oscGain.gain.exponentialRampToValueAtTime(0.001, t + 0.5);
      osc.connect(oscGain);
      oscGain.connect(this.masterGain);
      osc.start(t);
      osc.stop(t + 0.5);

      // Blast
      const noise = this.ctx.createBufferSource();
      noise.buffer = this.createNoiseBuffer(0.65);
      const filter = this.ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.frequency.setValueAtTime(2200, t);
      filter.frequency.exponentialRampToValueAtTime(120, t + 0.6);
      const noiseGain = this.ctx.createGain();
      noiseGain.gain.setValueAtTime(1.1, t);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, t + 0.65);
      noise.connect(filter);
      filter.connect(noiseGain);
      noiseGain.connect(this.masterGain);
      noise.start(t);

      // Bolt Action Mechanical Cycle sound at +350ms
      setTimeout(() => this.playBoltAction(), 320);

    } else {
      // M416 - Fast tactical 5.56 NATO burst
      const osc = this.ctx.createOscillator();
      const oscGain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(160, t);
      osc.frequency.exponentialRampToValueAtTime(45, t + 0.16);
      oscGain.gain.setValueAtTime(0.8, t);
      oscGain.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
      osc.connect(oscGain);
      oscGain.connect(this.masterGain);
      osc.start(t);
      osc.stop(t + 0.18);

      const noise = this.ctx.createBufferSource();
      noise.buffer = this.createNoiseBuffer(0.2);
      const filter = this.ctx.createBiquadFilter();
      filter.type = 'highpass';
      filter.frequency.setValueAtTime(800, t);
      const noiseGain = this.ctx.createGain();
      noiseGain.gain.setValueAtTime(0.75, t);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
      noise.connect(filter);
      filter.connect(noiseGain);
      noiseGain.connect(this.masterGain);
      noise.start(t);
    }
  }

  // Bolt-action mechanical sound for AWM
  playBoltAction() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    
    // Bolt open click
    const osc1 = this.ctx.createOscillator();
    const g1 = this.ctx.createGain();
    osc1.type = 'square';
    osc1.frequency.setValueAtTime(950, t);
    osc1.frequency.setValueAtTime(1400, t + 0.04);
    g1.gain.setValueAtTime(0.2, t);
    g1.gain.exponentialRampToValueAtTime(0.001, t + 0.09);
    osc1.connect(g1);
    g1.connect(this.masterGain);
    osc1.start(t);
    osc1.stop(t + 0.09);

    // Bolt slide & lock
    const osc2 = this.ctx.createOscillator();
    const g2 = this.ctx.createGain();
    osc2.type = 'sawtooth';
    osc2.frequency.setValueAtTime(480, t + 0.18);
    osc2.frequency.setValueAtTime(1200, t + 0.24);
    g2.gain.setValueAtTime(0.001, t);
    g2.gain.setValueAtTime(0.25, t + 0.18);
    g2.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
    osc2.connect(g2);
    g2.connect(this.masterGain);
    osc2.start(t + 0.18);
    osc2.stop(t + 0.3);
  }

  // PUBG Metallic Hitmarker Sound
  playHitmarker() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(2600, t);
    osc.frequency.setValueAtTime(2100, t + 0.03);
    gain.gain.setValueAtTime(0.4, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.08);

    osc.connect(gain);
    gain.connect(this.masterGain);
    osc.start(t);
    osc.stop(t + 0.08);
  }

  // Tactical Target Lock Beep
  playTargetLock() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    // Double high-tech beep
    for (let i = 0; i < 2; i++) {
      const dt = t + i * 0.07;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(1950, dt);
      gain.gain.setValueAtTime(0.25, dt);
      gain.gain.exponentialRampToValueAtTime(0.001, dt + 0.045);
      osc.connect(gain);
      gain.connect(this.masterGain);
      osc.start(dt);
      osc.stop(dt + 0.045);
    }
  }

  // Take Damage Flesh Impact
  playTakeDamage() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    // Sub thump
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(110, t);
    osc.frequency.exponentialRampToValueAtTime(30, t + 0.25);
    gain.gain.setValueAtTime(0.8, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.28);
    osc.connect(gain);
    gain.connect(this.masterGain);
    osc.start(t);
    osc.stop(t + 0.28);

    // Crunch noise
    const noise = this.ctx.createBufferSource();
    noise.buffer = this.createNoiseBuffer(0.18);
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(600, t);
    const nGain = this.ctx.createGain();
    nGain.gain.setValueAtTime(0.5, t);
    nGain.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
    noise.connect(filter);
    filter.connect(nGain);
    nGain.connect(this.masterGain);
    noise.start(t);
  }

  // Tactical Reload Sequence
  playReload() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    // Step 1: Mag ejection click
    const osc1 = this.ctx.createOscillator();
    const g1 = this.ctx.createGain();
    osc1.type = 'square';
    osc1.frequency.setValueAtTime(700, t);
    g1.gain.setValueAtTime(0.3, t);
    g1.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
    osc1.connect(g1);
    g1.connect(this.masterGain);
    osc1.start(t);
    osc1.stop(t + 0.12);

    // Step 2: Mag insertion at +600ms
    setTimeout(() => {
      if (!this.ctx || this.muted) return;
      const t2 = this.ctx.currentTime;
      const osc2 = this.ctx.createOscillator();
      const g2 = this.ctx.createGain();
      osc2.type = 'sawtooth';
      osc2.frequency.setValueAtTime(450, t2);
      osc2.frequency.setValueAtTime(900, t2 + 0.08);
      g2.gain.setValueAtTime(0.35, t2);
      g2.gain.exponentialRampToValueAtTime(0.001, t2 + 0.15);
      osc2.connect(g2);
      g2.connect(this.masterGain);
      osc2.start(t2);
      osc2.stop(t2 + 0.15);
    }, 600);

    // Step 3: Chamber racking at +1200ms
    setTimeout(() => {
      this.playBoltAction();
    }, 1100);
  }

  // Dry Fire Empty Click
  playDryFire() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(1400, t);
    gain.gain.setValueAtTime(0.3, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.04);
    osc.connect(gain);
    gain.connect(this.masterGain);
    osc.start(t);
    osc.stop(t + 0.04);
  }

  // UI Tactile Click
  playMenuClick() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(900, t);
    gain.gain.setValueAtTime(0.12, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.03);
    osc.connect(gain);
    gain.connect(this.masterGain);
    osc.start(t);
    osc.stop(t + 0.03);
  }

  // Low HP Heartbeat
  startHeartbeat() {
    if (this.heartbeatTimer) return;
    const beat = () => {
      this.ensureContext();
      if (!this.ctx || this.muted) return;
      const t = this.ctx.currentTime;
      // Lub
      const o1 = this.ctx.createOscillator();
      const g1 = this.ctx.createGain();
      o1.type = 'sine';
      o1.frequency.setValueAtTime(58, t);
      o1.frequency.exponentialRampToValueAtTime(35, t + 0.12);
      g1.gain.setValueAtTime(0.6, t);
      g1.gain.exponentialRampToValueAtTime(0.001, t + 0.14);
      o1.connect(g1);
      g1.connect(this.masterGain);
      o1.start(t);
      o1.stop(t + 0.14);

      // Dub at +150ms
      const o2 = this.ctx.createOscillator();
      const g2 = this.ctx.createGain();
      o2.type = 'sine';
      o2.frequency.setValueAtTime(64, t + 0.15);
      o2.frequency.exponentialRampToValueAtTime(32, t + 0.28);
      g2.gain.setValueAtTime(0.001, t);
      g2.gain.setValueAtTime(0.7, t + 0.15);
      g2.gain.exponentialRampToValueAtTime(0.001, t + 0.32);
      o2.connect(g2);
      g2.connect(this.masterGain);
      o2.start(t + 0.15);
      o2.stop(t + 0.32);
    };

    beat();
    this.heartbeatTimer = setInterval(beat, 850);
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  // Victory Fanfare
  playVictory() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    const notes = [392, 523.25, 659.25, 783.99, 1046.5]; // G4, C5, E5, G5, C6
    notes.forEach((freq, i) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, t + i * 0.14);
      gain.gain.setValueAtTime(0.35, t + i * 0.14);
      gain.gain.exponentialRampToValueAtTime(0.001, t + i * 0.14 + 0.35);
      osc.connect(gain);
      gain.connect(this.masterGain);
      osc.start(t + i * 0.14);
      osc.stop(t + i * 0.14 + 0.35);
    });
  }

  // Defeat / Elimination Static Drone
  playEliminated() {
    this.ensureContext();
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(140, t);
    osc.frequency.exponentialRampToValueAtTime(35, t + 1.2);
    gain.gain.setValueAtTime(0.5, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 1.3);
    osc.connect(gain);
    gain.connect(this.masterGain);
    osc.start(t);
    osc.stop(t + 1.3);
  }
}

// Global Audio Instance
window.tacticalAudio = new TacticalAudioEngine();
