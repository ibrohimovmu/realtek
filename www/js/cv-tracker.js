/**
 * RealStrike AR - Real-time Computer Vision & Target Lock Engine
 * Operates 100% locally on-device without cloud models or external downloads.
 */
class TacticalCVTracker {
  constructor() {
    this.videoElement = null;
    this.analysisCanvas = document.createElement('canvas');
    this.analysisCtx = this.analysisCanvas.getContext('2d', { willReadFrequently: true });
    
    this.analysisCanvas.width = 160;
    this.analysisCanvas.height = 120;
    
    this.prevFrameData = null;
    this.isTracking = false;
    this.animationFrameId = null;
    
    // Target Lock State
    this.targetLocked = false;
    this.lockConfidence = 0; // 0.0 - 1.0
    this.lockLostTimer = 0;
    this.targetBBox = null; // { x, y, width, height, distanceMeters }
    
    // Drone Simulation for Solo Combat / Practice
    this.droneSimulationEnabled = false;
    this.droneState = {
      x: 0.5, // 0.0 to 1.0
      y: 0.45,
      targetX: 0.5,
      targetY: 0.45,
      speed: 0.008,
      hp: 100,
      alive: true,
      lastAttack: Date.now()
    };
    
    this.onLockChange = null; // Callback (isLocked, bbox)
  }

  start(videoEl, onLockChangeCallback) {
    this.videoElement = videoEl;
    this.onLockChange = onLockChangeCallback;
    this.isTracking = true;
    this.prevFrameData = null;
    this.targetLocked = false;
    this.lockConfidence = 0;
    
    this.loop();
  }

  stop() {
    this.isTracking = false;
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
  }

  enableDroneSim(enabled = true) {
    this.droneSimulationEnabled = enabled;
    this.droneState.hp = 100;
    this.droneState.alive = true;
    this.droneState.x = 0.5;
    this.droneState.y = 0.45;
  }

  loop() {
    if (!this.isTracking) return;

    if (this.videoElement && this.videoElement.readyState >= 2) {
      this.processCurrentFrame();
    } else if (this.droneSimulationEnabled) {
      this.processDroneSimulation();
    }

    this.animationFrameId = requestAnimationFrame(() => this.loop());
  }

  processCurrentFrame() {
    const w = this.analysisCanvas.width;
    const h = this.analysisCanvas.height;

    try {
      this.analysisCtx.drawImage(this.videoElement, 0, 0, w, h);
      const frame = this.analysisCtx.getImageData(0, 0, w, h);
      const data = frame.data;

      // Central Engagement Zone: Center 40% width and 50% height
      const zX1 = Math.floor(w * 0.30);
      const zX2 = Math.floor(w * 0.70);
      const zY1 = Math.floor(h * 0.25);
      const zY2 = Math.floor(h * 0.75);

      let totalDiff = 0;
      let motionPixels = 0;
      let targetCentroidX = 0;
      let targetCentroidY = 0;
      let humanColorScore = 0;

      if (this.prevFrameData) {
        const prev = this.prevFrameData.data;

        for (let y = zY1; y < zY2; y += 2) {
          for (let x = zX1; x < zX2; x += 2) {
            const idx = (y * w + x) * 4;
            const r = data[idx];
            const g = data[idx + 1];
            const b = data[idx + 2];

            const pr = prev[idx];
            const pg = prev[idx + 1];
            const pb = prev[idx + 2];

            const diff = Math.abs(r - pr) + Math.abs(g - pg) + Math.abs(b - pb);
            if (diff > 45) {
              totalDiff += diff;
              motionPixels++;
              targetCentroidX += x;
              targetCentroidY += y;
            }

            // Human skin / body silhouette tone contrast ratio
            if (r > 60 && g > 40 && b > 20 && r > g && (r - g) >= 12 && (r - b) >= 15) {
              humanColorScore++;
            }
          }
        }
      }

      this.prevFrameData = frame;

      // Evaluation of Target Lock
      const inspectedPixels = ((zX2 - zX1) / 2) * ((zY2 - zY1) / 2);
      const motionRatio = motionPixels / inspectedPixels;
      const humanRatio = humanColorScore / inspectedPixels;

      let detected = false;
      let calculatedBBox = null;

      // If drone mode is on, drone takes priority or supplements
      if (this.droneSimulationEnabled && this.droneState.alive) {
        this.updateDronePosition();
        // Check if crosshair (0.5, 0.5) is on drone
        const dx = Math.abs(this.droneState.x - 0.5);
        const dy = Math.abs(this.droneState.y - 0.5);
        if (dx < 0.12 && dy < 0.14) {
          detected = true;
          this.lockConfidence = Math.min(1.0, this.lockConfidence + 0.25);
          calculatedBBox = {
            normX: this.droneState.x - 0.08,
            normY: this.droneState.y - 0.09,
            normW: 0.16,
            normH: 0.18,
            distanceMeters: (12 + dx * 20).toFixed(1),
            type: 'TACTICAL_COMBAT_DRONE'
          };
        }
      }

      // Optical Vision Lock on real human silhouette or substantial motion in crosshair corridor
      if (!detected && (motionRatio > 0.06 || humanRatio > 0.12)) {
        detected = true;
        this.lockConfidence = Math.min(1.0, this.lockConfidence + 0.15);
        
        const avgX = motionPixels > 0 ? (targetCentroidX / motionPixels) / w : 0.5;
        const avgY = motionPixels > 0 ? (targetCentroidY / motionPixels) / h : 0.5;
        
        calculatedBBox = {
          normX: Math.max(0.2, avgX - 0.15),
          normY: Math.max(0.15, avgY - 0.25),
          normW: 0.30,
          normH: 0.50,
          distanceMeters: (8.4 + (1 - motionRatio) * 6).toFixed(1),
          type: 'HOSTILE_OPERATOR'
        };
      }

      if (!detected) {
        this.lockConfidence = Math.max(0, this.lockConfidence - 0.08);
      }

      const previouslyLocked = this.targetLocked;
      this.targetLocked = this.lockConfidence > 0.45;
      this.targetBBox = this.targetLocked ? calculatedBBox : null;

      if (this.targetLocked !== previouslyLocked && this.onLockChange) {
        this.onLockChange(this.targetLocked, this.targetBBox);
      }
    } catch (err) {
      // Ignore intermittent drawImage frame errors
    }
  }

  updateDronePosition() {
    const s = this.droneState;
    if (!s.alive) return;

    // Smooth wandering in central combat view
    s.x += (s.targetX - s.x) * s.speed;
    s.y += (s.targetY - s.y) * s.speed;

    if (Math.hypot(s.targetX - s.x, s.targetY - s.y) < 0.03) {
      s.targetX = 0.35 + Math.random() * 0.30;
      s.targetY = 0.35 + Math.random() * 0.25;
    }
  }

  processDroneSimulation() {
    this.updateDronePosition();
    const dx = Math.abs(this.droneState.x - 0.5);
    const dy = Math.abs(this.droneState.y - 0.5);
    const isOver = dx < 0.12 && dy < 0.14 && this.droneState.alive;

    if (isOver) {
      this.lockConfidence = Math.min(1.0, this.lockConfidence + 0.25);
    } else {
      this.lockConfidence = Math.max(0, this.lockConfidence - 0.1);
    }

    const previouslyLocked = this.targetLocked;
    this.targetLocked = this.lockConfidence > 0.45;
    this.targetBBox = this.targetLocked ? {
      normX: this.droneState.x - 0.08,
      normY: this.droneState.y - 0.09,
      normW: 0.16,
      normH: 0.18,
      distanceMeters: '14.2',
      type: 'TACTICAL_COMBAT_DRONE'
    } : null;

    if (this.targetLocked !== previouslyLocked && this.onLockChange) {
      this.onLockChange(this.targetLocked, this.targetBBox);
    }
  }
}

window.cvTracker = new TacticalCVTracker();
