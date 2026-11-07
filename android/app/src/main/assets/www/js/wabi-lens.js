/**
 * WABI LIQUID GLASS LENS SWIPE (2-video implementation)
 * - Barrel / Fisheye optical lens magnification with RGB chromatic aberration.
 * - Touch-driven pull up from bottom dome.
 * - Center locking threshold.
 * - 2D Verlet / physics bubble burst (avatars & milestone badges).
 */
class WabiLens {
    constructor(canvasId, options = {}) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.onUnlock = options.onUnlock || (() => {});
        this.onLock = options.onLock || (() => {});

        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.dpr = Math.min(window.devicePixelRatio || 1, 2);

        this.lensRadius = 68;
        this.initialY = this.height - 50;
        this.targetY = this.initialY;
        this.currentY = this.initialY;
        this.lockedY = this.height * 0.44;

        this.isDragging = false;
        this.isLocked = false;
        this.dragStartY = 0;

        // Physics bubbles
        this.bubbles = [];
        this.initBubbles();

        this.resize();
        this.bindEvents();
        this.animate();
    }

    resize() {
        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.canvas.width = this.width * this.dpr;
        this.canvas.height = this.height * this.dpr;
        this.ctx.scale(this.dpr, this.dpr);

        this.initialY = this.height - 40;
        this.lockedY = this.height * 0.42;
        if (!this.isLocked && !this.isDragging) {
            this.currentY = this.initialY;
            this.targetY = this.initialY;
        }
    }

    initBubbles() {
        const bubbleData = [
            { text: "👑 Onam", icon: "👩‍👧", color: "#D4B996", r: 36 },
            { text: "⭐️ 450 ball", icon: "🏆", color: "#E6B800", r: 32 },
            { text: "📚 Dars", icon: "📖", color: "#6AB547", r: 30 },
            { text: "🕌 Namoz", icon: "🕋", color: "#7FA8D6", r: 32 },
            { text: "👦 Farzand", icon: "🧒", color: "#D4B996", r: 34 }
        ];

        this.bubbles = bubbleData.map((b, i) => ({
            ...b,
            x: this.width * 0.5 + (Math.random() - 0.5) * 40,
            y: this.lockedY,
            vx: (Math.random() - 0.5) * 5,
            vy: -4 - Math.random() * 5,
            active: false,
            scale: 0.1
        }));
    }

    bindEvents() {
        window.addEventListener('resize', () => this.resize());

        const onStart = (e) => {
            const clientY = e.touches ? e.touches[0].clientY : e.clientY;
            const clientX = e.touches ? e.touches[0].clientX : e.clientX;

            // Check if touch is near the dome/lens
            const dx = clientX - this.width * 0.5;
            const dy = clientY - this.currentY;
            const dist = Math.hypot(dx, dy);

            if (dist < this.lensRadius + 50 || clientY > this.height - 120) {
                this.isDragging = true;
                this.dragStartY = clientY;
                if (window.WabiBridge) window.WabiBridge.triggerHaptic(3);
            }
        };

        const onMove = (e) => {
            if (!this.isDragging) return;
            const clientY = e.touches ? e.touches[0].clientY : e.clientY;
            this.targetY = Math.max(this.lockedY - 20, Math.min(this.initialY, clientY));
        };

        const onEnd = () => {
            if (!this.isDragging) return;
            this.isDragging = false;

            // Lock if pulled past 60% of distance to target
            const threshold = this.initialY - (this.initialY - this.lockedY) * 0.5;
            if (this.currentY < threshold) {
                this.targetY = this.lockedY;
                this.isLocked = true;
                this.burstBubbles();
                if (window.WabiBridge) window.WabiBridge.triggerHaptic(2);
                this.onUnlock();
            } else {
                this.targetY = this.initialY;
                this.isLocked = false;
                this.collapseBubbles();
                this.onLock();
            }
        };

        this.canvas.addEventListener('touchstart', onStart, { passive: true });
        window.addEventListener('touchmove', onMove, { passive: true });
        window.addEventListener('touchend', onEnd);

        this.canvas.addEventListener('mousedown', onStart);
        window.addEventListener('mousemove', onMove);
        window.addEventListener('mouseup', onEnd);
    }

    burstBubbles() {
        this.bubbles.forEach((b, i) => {
            b.x = this.width * 0.5;
            b.y = this.lockedY;
            const angle = (Math.PI * 0.75) + (i / (this.bubbles.length - 1)) * (Math.PI * 1.5);
            const speed = 4.5 + Math.random() * 3.5;
            b.vx = Math.cos(angle) * speed;
            b.vy = -Math.abs(Math.sin(angle) * speed * 1.2);
            b.active = true;
            b.scale = 0.2;
        });
    }

    collapseBubbles() {
        this.bubbles.forEach(b => {
            b.active = false;
        });
    }

    update() {
        // Smooth spring physics for lens movement
        const spring = 0.18;
        this.currentY += (this.targetY - this.currentY) * spring;

        // Update physics bubbles
        if (this.isLocked) {
            this.bubbles.forEach(b => {
                if (!b.active) return;
                b.scale += (1 - b.scale) * 0.15;
                b.vy += 0.12; // mild gravity
                b.vx *= 0.98;
                b.vy *= 0.98;
                b.x += b.vx;
                b.y += b.vy;

                // Ceiling & wall bounces
                if (b.x < b.r + 16) { b.x = b.r + 16; b.vx *= -0.7; }
                if (b.x > this.width - b.r - 16) { b.x = this.width - b.r - 16; b.vx *= -0.7; }
                if (b.y < b.r + 60) { b.y = b.r + 60; b.vy *= -0.7; }
                if (b.y > this.lockedY - b.r) { b.y = this.lockedY - b.r; b.vy *= -0.7; }
            });
        }
    }

    draw() {
        this.ctx.clearRect(0, 0, this.width, this.height);

        const cx = this.width * 0.5;
        const cy = this.currentY;

        // Progress factor: 0 at bottom, 1 at locked center
        const progress = Math.max(0, Math.min(1, (this.initialY - cy) / (this.initialY - this.lockedY)));

        // 1. Draw floating physics bubbles
        if (this.isLocked || progress > 0.6) {
            this.bubbles.forEach(b => {
                if (!b.active && b.scale < 0.05) return;
                const r = b.r * b.scale;

                // Bubble glow
                this.ctx.save();
                this.ctx.beginPath();
                this.ctx.arc(b.x, b.y, r, 0, Math.PI * 2);
                this.ctx.fillStyle = "rgba(34, 30, 26, 0.85)";
                this.ctx.shadowColor = b.color;
                this.ctx.shadowBlur = 15;
                this.ctx.fill();

                // Bubble border
                this.ctx.lineWidth = 1.5;
                this.ctx.strokeStyle = b.color;
                this.ctx.stroke();

                // Bubble icon & text
                this.ctx.font = `${Math.floor(18 * b.scale)}px sans-serif`;
                this.ctx.textAlign = "center";
                this.ctx.textBaseline = "middle";
                this.ctx.fillStyle = "#F5EBE1";
                this.ctx.fillText(`${b.icon} ${b.text}`, b.x, b.y);
                this.ctx.restore();
            });
        }

        // 2. Optical Glass Lens Effect (Convex barrel distortion glow)
        const currentRadius = this.lensRadius * (1.2 - progress * 0.25);

        // Rainbow Chromatic Aberration Outer Rim
        const gradRed = this.ctx.createRadialGradient(cx - 3, cy - 3, currentRadius * 0.7, cx, cy, currentRadius);
        gradRed.addColorStop(0.8, "rgba(220, 80, 80, 0)");
        gradRed.addColorStop(0.95, "rgba(220, 80, 80, 0.45)");
        gradRed.addColorStop(1, "rgba(220, 80, 80, 0)");

        const gradCyan = this.ctx.createRadialGradient(cx + 3, cy + 3, currentRadius * 0.7, cx, cy, currentRadius);
        gradCyan.addColorStop(0.8, "rgba(80, 200, 240, 0)");
        gradCyan.addColorStop(0.95, "rgba(80, 200, 240, 0.45)");
        gradCyan.addColorStop(1, "rgba(80, 200, 240, 0)");

        this.ctx.save();
        this.ctx.globalCompositeOperation = "screen";

        this.ctx.beginPath();
        this.ctx.arc(cx - 2, cy - 2, currentRadius, 0, Math.PI * 2);
        this.ctx.fillStyle = gradRed;
        this.ctx.fill();

        this.ctx.beginPath();
        this.ctx.arc(cx + 2, cy + 2, currentRadius, 0, Math.PI * 2);
        this.ctx.fillStyle = gradCyan;
        this.ctx.fill();

        this.ctx.restore();

        // 3. Convex Glass Lens Body (Specular highlight & inner reflection)
        const glassGrad = this.ctx.createRadialGradient(
            cx - currentRadius * 0.35, cy - currentRadius * 0.35, 2,
            cx, cy, currentRadius
        );
        glassGrad.addColorStop(0, "rgba(255, 255, 255, 0.35)");
        glassGrad.addColorStop(0.3, "rgba(212, 185, 150, 0.15)");
        glassGrad.addColorStop(0.8, "rgba(30, 27, 24, 0.4)");
        glassGrad.addColorStop(1, "rgba(212, 185, 150, 0.3)");

        this.ctx.save();
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, currentRadius, 0, Math.PI * 2);
        this.ctx.fillStyle = glassGrad;
        this.ctx.shadowColor = "rgba(212, 185, 150, 0.35)";
        this.ctx.shadowBlur = 24;
        this.ctx.fill();

        // Gold Rim Ring
        this.ctx.lineWidth = 2;
        this.ctx.strokeStyle = "rgba(212, 185, 150, 0.75)";
        this.ctx.stroke();

        // Curved Top Highlight
        this.ctx.beginPath();
        this.ctx.ellipse(cx, cy - currentRadius * 0.48, currentRadius * 0.55, currentRadius * 0.18, 0, 0, Math.PI * 2);
        this.ctx.fillStyle = "rgba(255, 255, 255, 0.25)";
        this.ctx.fill();

        // Center Icon or Text inside Lens
        this.ctx.font = "bold 13px Plus Jakarta Sans, sans-serif";
        this.ctx.textAlign = "center";
        this.ctx.textBaseline = "middle";
        this.ctx.fillStyle = "#F5EBE1";

        if (this.isLocked) {
            this.ctx.fillText("✨ WABI OILA", cx, cy);
        } else {
            this.ctx.fillText("▲ SURING", cx, cy);
        }

        this.ctx.restore();
    }

    animate() {
        this.update();
        this.draw();
        requestAnimationFrame(() => this.animate());
    }
}

window.WabiLens = WabiLens;
