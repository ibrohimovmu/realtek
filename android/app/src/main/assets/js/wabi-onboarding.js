/**
 * WABI ONBOARDING — LIQUID GLASS LENS SWIPE & VERLET 2D BUBBLE PHYSICS
 * 100% 1-to-1 implementation matching the 2nd video ("Meet Wabi").
 */
class WabiOnboarding {
    constructor(canvasId, options = {}) {
        this.canvas = document.getElementById(canvasId);
        this.ctx = this.canvas.getContext('2d');
        this.onRoleSelect = options.onRoleSelect || (() => {});

        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.dpr = Math.min(window.devicePixelRatio || 1, 2);

        this.initialRadius = 220;
        this.minRadius = 72;
        this.currentRadius = this.initialRadius;

        this.initialY = this.height + 40;
        this.lockedY = this.height * 0.40;
        this.currentY = this.initialY;
        this.targetY = this.initialY;

        this.isDragging = false;
        this.isLocked = false;
        this.dragStartY = 0;

        // 35 Verlet Physics Bubbles
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

        this.initialY = this.height + 20;
        this.lockedY = this.height * 0.40;
        if (!this.isLocked && !this.isDragging) {
            this.currentY = this.initialY;
            this.targetY = this.initialY;
        }
    }

    initBubbles() {
        const icons = [
            "👨‍👩‍👧", "📖", "⚔️", "🌸", "🕌", "⭐️", "🏆", "🎯", "🧠", "🦁",
            "🛡️", "💎", "☀️", "🌙", "🕊️", "🌱", "🔥", "⚡️", "👑", "🤲",
            "❤️", "💡", "🎨", "📚", "🏹", "🏔️", "🥇", "🧭", "🚀", "✨",
            "🎁", "💪", "🤝", "🌟", "🌍"
        ];
        const colors = [
            "#D5B895", "#E5B81B", "#76B843", "#F26419", "#3D82E2",
            "#A871E3", "#E65D7B", "#38B2AC", "#F6AD55", "#68D391"
        ];

        this.bubbles = [];
        for (let i = 0; i < 35; i++) {
            const r = 16 + Math.random() * 26; // 16px to 42px
            this.bubbles.push({
                x: this.width * 0.5 + (Math.random() - 0.5) * 40,
                y: this.lockedY,
                vx: (Math.random() - 0.5) * 5,
                vy: -3 - Math.random() * 4.5,
                r: r,
                icon: icons[i % icons.length],
                color: colors[i % colors.length],
                scale: 0.05,
                active: false
            });
        }
    }

    bindEvents() {
        window.addEventListener('resize', () => this.resize());

        const onStart = (e) => {
            const clientY = e.touches ? e.touches[0].clientY : e.clientY;
            const clientX = e.touches ? e.touches[0].clientX : e.clientX;

            const dx = clientX - this.width * 0.5;
            const dy = clientY - this.currentY;
            const dist = Math.hypot(dx, dy);

            if (dist < this.currentRadius + 60 || clientY > this.height - 180) {
                this.isDragging = true;
                this.dragStartY = clientY;
                if (window.AndroidNative) window.AndroidNative.triggerHaptic(3);
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

            const threshold = this.initialY - (this.initialY - this.lockedY) * 0.45;
            if (this.currentY < threshold) {
                this.targetY = this.lockedY;
                this.isLocked = true;
                this.burstBubbles();
                if (window.AndroidNative) window.AndroidNative.triggerHaptic(2);
                document.getElementById('onboarding-buttons').classList.add('visible');
            } else {
                this.targetY = this.initialY;
                this.isLocked = false;
                this.collapseBubbles();
                document.getElementById('onboarding-buttons').classList.remove('visible');
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
            const angle = (Math.PI * 0.7) + (i / 34) * (Math.PI * 1.6);
            const speed = 4.0 + Math.random() * 4.5;
            b.vx = Math.cos(angle) * speed;
            b.vy = -Math.abs(Math.sin(angle) * speed * 1.3);
            b.active = true;
            b.scale = 0.2;
        });
    }

    collapseBubbles() {
        this.bubbles.forEach(b => {
            b.active = false;
        });
    }

    updatePhysics() {
        // Spring easing for lens movement
        const spring = 0.18;
        this.currentY += (this.targetY - this.currentY) * spring;

        const progress = Math.max(0, Math.min(1, (this.initialY - this.currentY) / (this.initialY - this.lockedY)));
        this.currentRadius = this.initialRadius - progress * (this.initialRadius - this.minRadius);

        // Update 35 Verlet Bubbles
        if (this.isLocked) {
            const restitution = 0.78;
            const gravityY = -0.10; // negative gravity: floating upwards

            for (let i = 0; i < this.bubbles.length; i++) {
                const b = this.bubbles[i];
                if (!b.active) continue;

                b.scale += (1 - b.scale) * 0.12;
                b.vy += gravityY;
                b.vx *= 0.985;
                b.vy *= 0.985;
                b.x += b.vx;
                b.y += b.vy;

                // Ceiling and boundary collisions
                if (b.x - b.r < 12) { b.x = b.r + 12; b.vx *= -restitution; }
                if (b.x + b.r > this.width - 12) { b.x = this.width - b.r - 12; b.vx *= -restitution; }
                if (b.y - b.r < 40) { b.y = b.r + 40; b.vy *= -restitution; }
                if (b.y + b.r > this.lockedY - 10) { b.y = this.lockedY - b.r - 10; b.vy *= -restitution; }

                // Circle-to-circle collision resolution
                for (let j = i + 1; j < this.bubbles.length; j++) {
                    const b2 = this.bubbles[j];
                    if (!b2.active) continue;
                    const dx = b2.x - b.x;
                    const dy = b2.y - b.y;
                    const dist = Math.hypot(dx, dy);
                    const minDist = (b.r + b2.r) * Math.min(b.scale, b2.scale);

                    if (dist < minDist && dist > 0.001) {
                        const overlap = (minDist - dist) * 0.5;
                        const nx = dx / dist;
                        const ny = dy / dist;
                        b.x -= nx * overlap;
                        b.y -= ny * overlap;
                        b2.x += nx * overlap;
                        b2.y += ny * overlap;

                        const dvx = b2.vx - b.vx;
                        const dvy = b2.vy - b.vy;
                        const p = (dvx * nx + dvy * ny) * restitution;
                        b.vx += p * nx;
                        b.vy += p * ny;
                        b2.vx -= p * nx;
                        b2.vy -= p * ny;
                    }
                }
            }
        }
    }

    draw() {
        this.ctx.clearRect(0, 0, this.width, this.height);

        const cx = this.width * 0.5;
        const cy = this.currentY;
        const progress = Math.max(0, Math.min(1, (this.initialY - cy) / (this.initialY - this.lockedY)));

        // 1. Draw 35 Verlet Physics Bubbles
        if (this.isLocked || progress > 0.6) {
            for (let i = 0; i < this.bubbles.length; i++) {
                const b = this.bubbles[i];
                if (!b.active && b.scale < 0.05) continue;
                const r = b.r * b.scale;

                this.ctx.save();
                this.ctx.beginPath();
                this.ctx.arc(b.x, b.y, r, 0, Math.PI * 2);

                const grad = this.ctx.createRadialGradient(
                    b.x - r * 0.3, b.y - r * 0.3, r * 0.1,
                    b.x, b.y, r
                );
                grad.addColorStop(0, "#FFF");
                grad.addColorStop(0.35, b.color);
                grad.addColorStop(1, "rgba(20, 17, 15, 0.85)");
                this.ctx.fillStyle = grad;
                this.ctx.shadowColor = b.color;
                this.ctx.shadowBlur = 16;
                this.ctx.fill();

                this.ctx.lineWidth = 1.5;
                this.ctx.strokeStyle = "rgba(255, 255, 255, 0.4)";
                this.ctx.stroke();

                // Emoji / Icon
                this.ctx.font = `${Math.floor(r * 0.85)}px sans-serif`;
                this.ctx.textAlign = "center";
                this.ctx.textBaseline = "middle";
                this.ctx.fillText(b.icon, b.x, b.y);

                this.ctx.restore();
            }
        }

        // 2. Optical Refraction Lens & Chromatic Aberration Rim
        const r = this.currentRadius;

        // Outer Iridescent Rainbow Rim (Blue-Violet-Yellow chromatic aberration)
        this.ctx.save();
        this.ctx.globalCompositeOperation = "screen";

        const rimGrad = this.ctx.createRadialGradient(cx, cy, r * 0.75, cx, cy, r + 4);
        rimGrad.addColorStop(0, "rgba(0, 0, 0, 0)");
        rimGrad.addColorStop(0.80, "rgba(80, 160, 255, 0.5)");
        rimGrad.addColorStop(0.92, "rgba(180, 90, 240, 0.6)");
        rimGrad.addColorStop(0.98, "rgba(240, 210, 80, 0.7)");
        rimGrad.addColorStop(1, "rgba(0, 0, 0, 0)");

        this.ctx.beginPath();
        this.ctx.arc(cx, cy, r + 4, 0, Math.PI * 2);
        this.ctx.fillStyle = rimGrad;
        this.ctx.fill();
        this.ctx.restore();

        // 3. Convex Glass Body (Specular Highlight & Refractive Depth)
        this.ctx.save();
        const glassGrad = this.ctx.createRadialGradient(
            cx - r * 0.35, cy - r * 0.35, 4,
            cx, cy, r
        );
        glassGrad.addColorStop(0, "rgba(255, 255, 255, 0.55)");
        glassGrad.addColorStop(0.25, "rgba(245, 240, 235, 0.28)");
        glassGrad.addColorStop(0.70, "rgba(220, 210, 200, 0.15)");
        glassGrad.addColorStop(0.95, "rgba(213, 184, 149, 0.40)");
        glassGrad.addColorStop(1, "rgba(255, 255, 255, 0.65)");

        this.ctx.beginPath();
        this.ctx.arc(cx, cy, r, 0, Math.PI * 2);
        this.ctx.fillStyle = glassGrad;
        this.ctx.shadowColor = "rgba(0, 0, 0, 0.15)";
        this.ctx.shadowBlur = 24;
        this.ctx.fill();

        // Specular highlight crescent
        this.ctx.beginPath();
        this.ctx.ellipse(cx, cy - r * 0.45, r * 0.55, r * 0.22, 0, 0, Math.PI * 2);
        this.ctx.fillStyle = "rgba(255, 255, 255, 0.35)";
        this.ctx.fill();

        // Lens center label
        this.ctx.font = "bold 13px Plus Jakarta Sans, sans-serif";
        this.ctx.textAlign = "center";
        this.ctx.textBaseline = "middle";
        this.ctx.fillStyle = "#14110F";

        if (this.isLocked) {
            this.ctx.fillText("✨ WABI INTIZOM", cx, cy);
        } else {
            this.ctx.fillText("▲ TEPAGA SURING ▲", cx, cy);
        }

        this.ctx.restore();
    }

    animate() {
        this.updatePhysics();
        this.draw();
        requestAnimationFrame(() => this.animate());
    }
}

window.WabiOnboarding = WabiOnboarding;
