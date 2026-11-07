/**
 * WABI 3D PROCEDURAL FURRY MONSTER (1-video 1:1 implementation)
 * - 3,500 procedural fur strands using 3D Fibonacci sphere distribution.
 * - Multi-segment quadraticCurveTo hair rendering with Ambient Occlusion & Rim lighting.
 * - Continuous mood morphing (0.0 Red/Angry -> 0.5 Orange/Gold -> 1.0 Soft Green/Joyful).
 * - Interactive gaze tracking, touch wind simulation, and dynamic background morphing.
 */
class FurryMonster {
    constructor(canvasId, sliderId, options = {}) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.slider = document.getElementById(sliderId);
        this.onVibeChange = options.onVibeChange || (() => {});

        this.width = 340;
        this.height = 340;
        this.dpr = Math.min(window.devicePixelRatio || 1, 2);

        this.vibe = 0.75; // 0.0 to 1.0
        this.targetVibe = 0.75;
        this.baseRadius = 76;
        this.strandCount = 3500;
        this.strands = [];

        this.time = 0;
        this.touchX = -9999;
        this.touchY = -9999;
        this.isInteracting = false;

        this.initFibonacciStrands();
        this.resize();
        this.bindEvents();
        this.animate();
    }

    resize() {
        const parent = this.canvas.parentElement;
        this.width = parent ? Math.min(parent.clientWidth - 16, 360) : 340;
        this.height = this.width;
        this.canvas.width = this.width * this.dpr;
        this.canvas.height = this.height * this.dpr;
        this.ctx.scale(this.dpr, this.dpr);
    }

    initFibonacciStrands() {
        this.strands = [];
        const goldenRatio = (1 + Math.sqrt(5)) / 2;

        for (let i = 0; i < this.strandCount; i++) {
            // Fibonacci spherical mapping
            const theta = 2 * Math.PI * i / goldenRatio;
            const phi = Math.acos(1 - 2 * (i + 0.5) / this.strandCount);

            // Project sphere normal to 2D
            const x = Math.sin(phi) * Math.cos(theta);
            const y = Math.sin(phi) * Math.sin(theta);
            const z = Math.cos(phi);

            // Only render front-facing and silhouette strands
            const angle2D = Math.atan2(y, x);
            const length = 16 + Math.random() * 26;
            const thickness = 1.2 + Math.random() * 1.4;
            const curl = (Math.random() - 0.5) * 0.4;
            const freq = 1.8 + Math.random() * 2.2;
            const phase = Math.random() * Math.PI * 2;

            this.strands.push({
                x, y, z,
                angle2D,
                length,
                thickness,
                curl,
                freq,
                phase
            });
        }

        // Sort back to front for proper occlusion
        this.strands.sort((a, b) => a.z - b.z);
    }

    bindEvents() {
        window.addEventListener('resize', () => this.resize());

        if (this.slider) {
            this.slider.addEventListener('input', (e) => {
                this.targetVibe = parseFloat(e.target.value) / 100;
                if (window.AndroidNative) window.AndroidNative.triggerHaptic(3);
                this.onVibeChange(this.targetVibe);
            });
        }

        const handlePointer = (e) => {
            const rect = this.canvas.getBoundingClientRect();
            const clientX = e.touches ? e.touches[0].clientX : e.clientX;
            const clientY = e.touches ? e.touches[0].clientY : e.clientY;
            this.touchX = clientX - rect.left;
            this.touchY = clientY - rect.top;
            this.isInteracting = true;
        };

        const handleEnd = () => {
            this.isInteracting = false;
            this.touchX = -9999;
            this.touchY = -9999;
        };

        this.canvas.addEventListener('touchstart', handlePointer, { passive: true });
        this.canvas.addEventListener('touchmove', handlePointer, { passive: true });
        this.canvas.addEventListener('touchend', handleEnd);
        this.canvas.addEventListener('mousedown', handlePointer);
        this.canvas.addEventListener('mousemove', (e) => { if (this.isInteracting) handlePointer(e); });
        this.canvas.addEventListener('mouseup', handleEnd);
    }

    getColors(v) {
        // Mood Palette interpolation
        // 0.0 - 0.33: Red (#D91414 -> #FF3B1F)
        // 0.34 - 0.66: Orange to Gold (#FF7700 -> #E5B81B)
        // 0.67 - 1.0: Soft Green (#76B843 -> #8FD158)
        let r, g, b;
        let bgR, bgG, bgB;

        if (v < 0.33) {
            const t = v / 0.33;
            r = Math.round(217 + (255 - 217) * t);
            g = Math.round(20 + (59 - 20) * t);
            b = Math.round(20 + (31 - 20) * t);
            // Background: Peach Pink (#F3B29E)
            bgR = 243; bgG = 178; bgB = 158;
        } else if (v < 0.66) {
            const t = (v - 0.33) / 0.33;
            r = Math.round(255 + (229 - 255) * t);
            g = Math.round(119 + (184 - 119) * t);
            b = Math.round(0 + (27 - 0) * t);
            // Background: Warm Sand (#DFCBB2)
            bgR = 223; bgG = 203; bgB = 178;
        } else {
            const t = (v - 0.66) / 0.34;
            r = Math.round(118 + (143 - 118) * t);
            g = Math.round(184 + (209 - 184) * t);
            b = Math.round(67 + (88 - 67) * t);
            // Background: Soft Sage Green (#CFD8C4)
            bgR = 207; bgG = 216; bgB = 196;
        }

        return {
            root: `rgb(${Math.max(0, r - 75)}, ${Math.max(0, g - 75)}, ${Math.max(0, b - 75)})`,
            body: `rgb(${r}, ${g}, ${b})`,
            tip: `rgb(${Math.min(255, r + 50)}, ${Math.min(255, g + 50)}, ${Math.min(255, b + 50)})`,
            glow: `rgba(${r}, ${g}, ${b}, 0.38)`,
            bg: `rgb(${bgR}, ${bgG}, ${bgB})`
        };
    }

    draw() {
        this.ctx.clearRect(0, 0, this.width, this.height);

        // Smooth vibe transition
        this.vibe += (this.targetVibe - this.vibe) * 0.12;

        const cx = this.width * 0.5;
        const cy = this.height * 0.5;
        const colors = this.getColors(this.vibe);

        // Update container background color smoothly matching the 1st video
        const container = this.canvas.parentElement;
        if (container) {
            container.style.backgroundColor = colors.bg;
            container.style.borderRadius = "24px";
            container.style.transition = "background-color 0.4s ease";
        }

        // Breathing oscillation
        const breathe = Math.sin(this.time * 2.2) * 3.5;
        const radius = this.baseRadius + breathe;

        // 1. Ambient Glow
        this.ctx.save();
        const glowGrad = this.ctx.createRadialGradient(cx, cy, radius * 0.4, cx, cy, radius * 1.8);
        glowGrad.addColorStop(0, colors.glow);
        glowGrad.addColorStop(1, "rgba(0,0,0,0)");
        this.ctx.fillStyle = glowGrad;
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, radius * 1.8, 0, Math.PI * 2);
        this.ctx.fill();
        this.ctx.restore();

        // 2. Procedural Fur Strands (3500 Strands with Ambient Occlusion)
        this.ctx.save();
        this.ctx.lineCap = "round";

        for (let i = 0; i < this.strands.length; i++) {
            const s = this.strands[i];
            const distFromCenter = Math.hypot(s.x, s.y);

            // Starting point on sphere surface
            const startX = cx + s.x * radius;
            const startY = cy + s.y * radius;

            // Wind & breathing motion
            const sway = Math.sin(this.time * s.freq + s.phase) * (2.5 + (1 - this.vibe) * 3);

            let tipAngle = s.angle2D + s.curl + (sway * 0.04);
            let tipLen = s.length * (0.85 + (1 - s.z * 0.3));

            // Touch deflection
            if (this.isInteracting) {
                const distToTouch = Math.hypot(startX - this.touchX, startY - this.touchY);
                if (distToTouch < 80) {
                    const pushAngle = Math.atan2(startY - this.touchY, startX - this.touchX);
                    tipAngle = pushAngle;
                    tipLen += (80 - distToTouch) * 0.3;
                }
            }

            // Mid control point for quadratic curve
            const midX = startX + Math.cos(tipAngle) * (tipLen * 0.5) + (sway * 0.5);
            const midY = startY + Math.sin(tipAngle) * (tipLen * 0.5);

            // Tip end point
            const endX = startX + Math.cos(tipAngle) * tipLen;
            const endY = startY + Math.sin(tipAngle) * tipLen;

            // Draw Strand
            this.ctx.beginPath();
            this.ctx.moveTo(startX, startY);
            this.ctx.quadraticCurveTo(midX, midY, endX, endY);

            // Gradient: dark root -> rim tip
            this.ctx.strokeStyle = (distFromCenter < 0.6) ? colors.root : colors.tip;
            this.ctx.lineWidth = s.thickness * (0.6 + (1 - s.z * 0.4));
            this.ctx.stroke();
        }
        this.ctx.restore();

        // 3. Central Body Core
        this.ctx.save();
        const coreGrad = this.ctx.createRadialGradient(
            cx - 16, cy - 20, 10,
            cx, cy, radius
        );
        coreGrad.addColorStop(0, colors.tip);
        coreGrad.addColorStop(0.5, colors.body);
        coreGrad.addColorStop(1, colors.root);
        this.ctx.fillStyle = coreGrad;
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        this.ctx.fill();
        this.ctx.restore();

        // 4. Morphing Eyes & Eyebrows
        this.drawFace(cx, cy, radius);
    }

    drawFace(cx, cy, radius) {
        const eyeSpacing = 28;
        const eyeY = cy - 8;

        // Vibe 0.0: Eyebrows tilt down +32deg (Angry/Tired), pupils small
        // Vibe 1.0: Eyebrows arch up -12deg (Joyful/Kind), pupils dilated sparkling
        const eyeSize = 13 + this.vibe * 9; // 13px to 22px
        const pupilSize = 6 + this.vibe * 7; // 6px to 13px

        // Eye gaze tracking towards touch pointer
        let gazeX = 0;
        let gazeY = 0;
        if (this.isInteracting) {
            const angle = Math.atan2(this.touchY - eyeY, this.touchX - cx);
            const dist = Math.min(6, Math.hypot(this.touchX - cx, this.touchY - eyeY) * 0.08);
            gazeX = Math.cos(angle) * dist;
            gazeY = Math.sin(angle) * dist;
        }

        // Eyebrow Angle (-12deg happy to +32deg angry)
        const browAngleRad = (32 - this.vibe * 44) * (Math.PI / 180);

        [-1, 1].forEach(side => {
            const ex = cx + side * eyeSpacing;

            // 1. Sclera (White eye background)
            this.ctx.save();
            this.ctx.beginPath();
            this.ctx.arc(ex, eyeY, eyeSize, 0, Math.PI * 2);
            this.ctx.fillStyle = "#FFFFFF";
            this.ctx.shadowColor = "rgba(0,0,0,0.2)";
            this.ctx.shadowBlur = 8;
            this.ctx.fill();

            // 2. Pupil (Dark with specular gleam)
            this.ctx.beginPath();
            this.ctx.arc(ex + gazeX, eyeY + gazeY, pupilSize, 0, Math.PI * 2);
            this.ctx.fillStyle = (this.vibe < 0.33) ? "#3A0D0D" : "#14110F";
            this.ctx.fill();

            // Specular reflection (gleam)
            this.ctx.beginPath();
            this.ctx.arc(ex + gazeX - pupilSize * 0.35, eyeY + gazeY - pupilSize * 0.35, pupilSize * 0.38, 0, Math.PI * 2);
            this.ctx.fillStyle = "#FFFFFF";
            this.ctx.fill();

            // 3. Eyebrows (Thick expressive fur brows)
            this.ctx.translate(ex, eyeY - eyeSize * 1.15);
            this.ctx.rotate(browAngleRad * side);

            this.ctx.beginPath();
            this.ctx.moveTo(-eyeSize * 0.85, 0);
            this.ctx.quadraticCurveTo(0, -5, eyeSize * 0.85, 0);
            this.ctx.strokeStyle = "#14110F";
            this.ctx.lineWidth = 4.2;
            this.ctx.lineCap = "round";
            this.ctx.stroke();

            this.ctx.restore();
        });

        // 5. Cute Nose / Snout
        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.arc(cx, eyeY + 14, 4.5, 0, Math.PI * 2);
        this.ctx.fillStyle = "#14110F";
        this.ctx.fill();
        this.ctx.restore();
    }

    animate() {
        this.time += 0.035;
        this.draw();
        requestAnimationFrame(() => this.animate());
    }
}

window.FurryMonster = FurryMonster;
