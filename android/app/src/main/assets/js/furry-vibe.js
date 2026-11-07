/**
 * WABI PROCEDURAL 3D FURRY VIBE CHARACTER (1-video implementation)
 * - 60 FPS Procedural Fur Shell / Instanced Hair Strands on HTML5 Canvas.
 * - Real-time mood interpolation from 0 (Dark Red / Angry) to 100 (Fresh Green / Joy).
 * - Morphing facial features (eyebrows tilt, pupil dilation, eye squint/sparkle).
 * - Breathing harmonic physics and touch repulsion.
 */
class FurryVibe {
    constructor(canvasId, sliderId, options = {}) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.slider = document.getElementById(sliderId);
        this.onVibeChange = options.onVibeChange || (() => {});

        this.width = this.canvas.parentElement ? this.canvas.parentElement.clientWidth : 320;
        this.height = 320;
        this.dpr = Math.min(window.devicePixelRatio || 1, 2);

        this.score = 75; // 0 to 100
        this.baseRadius = 78;
        this.strandCount = 1200;
        this.strands = [];

        this.time = 0;
        this.touchX = -9999;
        this.touchY = -9999;
        this.isTouched = false;

        this.initStrands();
        this.resize();
        this.bindEvents();
        this.animate();
    }

    resize() {
        if (!this.canvas.parentElement) return;
        this.width = this.canvas.parentElement.clientWidth || 320;
        this.height = Math.min(340, this.width);
        this.canvas.width = this.width * this.dpr;
        this.canvas.height = this.height * this.dpr;
        this.ctx.scale(this.dpr, this.dpr);
    }

    initStrands() {
        this.strands = [];
        for (let i = 0; i < this.strandCount; i++) {
            const angle = Math.random() * Math.PI * 2;
            const length = 18 + Math.random() * 26;
            const baseThickness = 1.4 + Math.random() * 1.2;
            const freq = 1.5 + Math.random() * 2.5;
            const phase = Math.random() * Math.PI * 2;
            this.strands.push({ angle, length, baseThickness, freq, phase });
        }
    }

    bindEvents() {
        window.addEventListener('resize', () => this.resize());

        if (this.slider) {
            this.slider.addEventListener('input', (e) => {
                this.score = parseInt(e.target.value, 10);
                if (window.WabiBridge) window.WabiBridge.triggerHaptic(3);
                this.onVibeChange(this.score);
            });
        }

        const onTouch = (e) => {
            const rect = this.canvas.getBoundingClientRect();
            const clientX = e.touches ? e.touches[0].clientX : e.clientX;
            const clientY = e.touches ? e.touches[0].clientY : e.clientY;
            this.touchX = clientX - rect.left;
            this.touchY = clientY - rect.top;
            this.isTouched = true;
            if (window.WabiBridge) window.WabiBridge.triggerHaptic(1);
        };

        const onEnd = () => {
            this.isTouched = false;
            this.touchX = -9999;
            this.touchY = -9999;
        };

        this.canvas.addEventListener('touchstart', onTouch, { passive: true });
        this.canvas.addEventListener('touchmove', onTouch, { passive: true });
        this.canvas.addEventListener('touchend', onEnd);
        this.canvas.addEventListener('mousedown', onTouch);
        this.canvas.addEventListener('mousemove', (e) => { if (this.isTouched) onTouch(e); });
        this.canvas.addEventListener('mouseup', onEnd);
    }

    setScore(val) {
        this.score = Math.max(0, Math.min(100, val));
        if (this.slider) this.slider.value = this.score;
    }

    getMoodColor() {
        // Red (#D91B1B) -> Orange (#F26419) -> Gold (#E6B800) -> Green (#6AB547)
        const t = this.score / 100;
        let r, g, b;

        if (t < 0.33) {
            const k = t / 0.33;
            r = Math.round(217 + (242 - 217) * k);
            g = Math.round(27 + (100 - 27) * k);
            b = Math.round(27 + (25 - 27) * k);
        } else if (t < 0.66) {
            const k = (t - 0.33) / 0.33;
            r = Math.round(242 + (230 - 242) * k);
            g = Math.round(100 + (184 - 100) * k);
            b = Math.round(25 + (0 - 25) * k);
        } else {
            const k = (t - 0.66) / 0.34;
            r = Math.round(230 + (106 - 230) * k);
            g = Math.round(184 + (181 - 184) * k);
            b = Math.round(0 + (71 - 0) * k);
        }

        return {
            main: `rgb(${r}, ${g}, ${b})`,
            glow: `rgba(${r}, ${g}, ${b}, 0.35)`,
            dark: `rgb(${Math.max(0, r - 70)}, ${Math.max(0, g - 70)}, ${Math.max(0, b - 70)})`
        };
    }

    draw() {
        this.ctx.clearRect(0, 0, this.width, this.height);

        const cx = this.width * 0.5;
        const cy = this.height * 0.5;
        const mood = this.getMoodColor();

        // Breathing harmonic oscillation
        const breathe = Math.sin(this.time * 2.2) * 3;
        const currentRadius = this.baseRadius + breathe;

        // 1. Ambient Glow behind character
        const glowGrad = this.ctx.createRadialGradient(cx, cy, currentRadius * 0.5, cx, cy, currentRadius * 1.7);
        glowGrad.addColorStop(0, mood.glow);
        glowGrad.addColorStop(1, "rgba(0,0,0,0)");
        this.ctx.fillStyle = glowGrad;
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, currentRadius * 1.7, 0, Math.PI * 2);
        this.ctx.fill();

        // 2. Procedural Fur Hair Strands (Shell Texturing)
        this.ctx.save();
        this.ctx.lineCap = "round";

        const tNorm = this.score / 100;

        for (let i = 0; i < this.strands.length; i++) {
            const s = this.strands[i];
            const wave = Math.sin(this.time * s.freq + s.phase) * (2 + tNorm * 3);

            const startX = cx + Math.cos(s.angle) * currentRadius;
            const startY = cy + Math.sin(s.angle) * currentRadius;

            // Hair tip position
            let tipAngle = s.angle + (wave * 0.05);
            let tipLen = s.length + (tNorm * 8);

            // Touch repulsion
            if (this.isTouched) {
                const distToTouch = Math.hypot(startX - this.touchX, startY - this.touchY);
                if (distToTouch < 70) {
                    const pushAngle = Math.atan2(startY - this.touchY, startX - this.touchX);
                    tipAngle = pushAngle;
                    tipLen += (70 - distToTouch) * 0.35;
                }
            }

            const endX = cx + Math.cos(tipAngle) * (currentRadius + tipLen);
            const endY = cy + Math.sin(tipAngle) * (currentRadius + tipLen);

            this.ctx.beginPath();
            this.ctx.moveTo(startX, startY);
            this.ctx.lineTo(endX, endY);
            this.ctx.strokeStyle = (i % 3 === 0) ? mood.dark : mood.main;
            this.ctx.lineWidth = s.baseThickness;
            this.ctx.stroke();
        }
        this.ctx.restore();

        // 3. Central Core Body
        this.ctx.save();
        const bodyGrad = this.ctx.createRadialGradient(cx - 15, cy - 20, 10, cx, cy, currentRadius);
        bodyGrad.addColorStop(0, mood.main);
        bodyGrad.addColorStop(1, mood.dark);
        this.ctx.fillStyle = bodyGrad;
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, currentRadius, 0, Math.PI * 2);
        this.ctx.fill();
        this.ctx.restore();

        // 4. Morphing Eyes & Facial Features
        this.drawFace(cx, cy, tNorm);
    }

    drawFace(cx, cy, t) {
        // Eye spacing and vertical position
        const eyeOffsetX = 24;
        const eyeOffsetY = -8;

        // Eye state morphing:
        // t = 0: Eyelids droop, angry slit (-35 deg), tired
        // t = 1: Big wide sparkling eyes, pupils dilated, joyous
        const eyeSize = 10 + t * 8; // 10 to 18
        const pupilSize = 4 + t * 5; // 4 to 9

        // Blinking
        const blinkCycle = Math.sin(this.time * 0.8);
        const isBlinking = blinkCycle > 0.96;
        const scaleY = isBlinking ? 0.1 : 1;

        // Draw Left and Right Eyes
        [-1, 1].forEach(side => {
            const ex = cx + side * eyeOffsetX;
            const ey = cy + eyeOffsetY;

            this.ctx.save();
            this.ctx.translate(ex, ey);
            this.ctx.scale(1, scaleY);

            // Sclera (White eye background)
            this.ctx.beginPath();
            this.ctx.arc(0, 0, eyeSize, 0, Math.PI * 2);
            this.ctx.fillStyle = "#FFFFFF";
            this.ctx.fill();

            // Pupil (Black with sparkle reflection)
            const pupilShiftX = (this.isTouched ? (this.touchX - ex) * 0.05 : 0);
            const pupilShiftY = (this.isTouched ? (this.touchY - ey) * 0.05 : 0);

            this.ctx.beginPath();
            this.ctx.arc(pupilShiftX, pupilShiftY, pupilSize, 0, Math.PI * 2);
            this.ctx.fillStyle = "#12100E";
            this.ctx.fill();

            // High-energy eye sparkle (twinkle)
            if (t > 0.4 && !isBlinking) {
                this.ctx.beginPath();
                this.ctx.arc(pupilShiftX - pupilSize * 0.35, pupilShiftY - pupilSize * 0.35, pupilSize * 0.35, 0, Math.PI * 2);
                this.ctx.fillStyle = "#FFFFFF";
                this.ctx.fill();
            }

            // Eyebrow Morphing (Angry tilt when t < 0.4, arching joy when t > 0.7)
            const browTilt = (1 - t) * 0.45 * side; // tilt down towards center if angry
            this.ctx.beginPath();
            this.ctx.moveTo(-eyeSize * 0.8, -eyeSize * 1.2 + (side === -1 ? browTilt * 10 : -browTilt * 10));
            this.ctx.lineTo(eyeSize * 0.8, -eyeSize * 1.2 + (side === 1 ? -browTilt * 10 : browTilt * 10));
            this.ctx.strokeStyle = "#12100E";
            this.ctx.lineWidth = 2.8;
            this.ctx.lineCap = "round";
            this.ctx.stroke();

            this.ctx.restore();
        });

        // Cute Mouth / Smile Morphing
        this.ctx.save();
        this.ctx.beginPath();
        const mouthY = cy + 18;
        if (t < 0.3) {
            // Frown / Pout
            this.ctx.arc(cx, mouthY + 8, 10, Math.PI * 1.2, Math.PI * 1.8);
        } else if (t < 0.7) {
            // Small subtle smile
            this.ctx.arc(cx, mouthY, 9, Math.PI * 0.15, Math.PI * 0.85);
        } else {
            // Big open beaming happy smile
            this.ctx.arc(cx, mouthY - 2, 14, Math.PI * 0.1, Math.PI * 0.9);
            this.ctx.fillStyle = "#8B1E1E";
            this.ctx.fill();
        }
        this.ctx.strokeStyle = "#12100E";
        this.ctx.lineWidth = 2.6;
        this.ctx.lineCap = "round";
        this.ctx.stroke();
        this.ctx.restore();
    }

    animate() {
        this.time += 0.035;
        this.draw();
        requestAnimationFrame(() => this.animate());
    }
}

window.FurryVibe = FurryVibe;
