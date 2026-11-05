/**
 * RealStrike AR - Combat Engine & Tactical Viewfinder Manager
 */
class TacticalCombatEngine {
  constructor() {
    this.isActive = false;
    this.videoStream = null;
    this.videoEl = null;
    
    // Player State
    this.hp = 100;
    this.maxHp = 100;
    this.isDead = false;
    this.matchKills = 0;
    this.matchDamageDealt = 0;
    this.isTargetLocked = false;
    this.currentLockedTarget = null;
    
    // Recoil and Animation State
    this.recoilY = 0;
    this.recoilX = 0;
    
    // Elements Cache
    this.dom = {};
  }

  initDOM() {
    this.dom = {
      viewfinder: document.getElementById('viewfinder-screen'),
      video: document.getElementById('camera-feed'),
      reticle: document.getElementById('tac-crosshair'),
      lockIndicator: document.getElementById('tac-lock-status'),
      distanceTag: document.getElementById('tac-distance-tag'),
      targetBox: document.getElementById('tac-target-bbox'),
      muzzleFlash: document.getElementById('muzzle-flash'),
      hitmarker: document.getElementById('tac-hitmarker'),
      floatingDamageContainer: document.getElementById('floating-damage-container'),
      bloodOverlay: document.getElementById('blood-vignette'),
      hpBarFill: document.getElementById('tac-hp-fill'),
      hpValue: document.getElementById('tac-hp-value'),
      ammoCurrent: document.getElementById('tac-ammo-current'),
      ammoReserve: document.getElementById('tac-ammo-reserve'),
      weaponName: document.getElementById('tac-weapon-name'),
      reloadIndicator: document.getElementById('tac-reload-ring'),
      fireBtn: document.getElementById('btn-fire-trigger'),
      reloadBtn: document.getElementById('btn-reload-trigger'),
      droneElement: document.getElementById('ar-drone-target'),
      matchOverlay: document.getElementById('match-outcome-overlay'),
      outcomeTitle: document.getElementById('outcome-title'),
      outcomeSub: document.getElementById('outcome-sub'),
      outcomeStats: document.getElementById('outcome-stats')
    };
  }

  async startCombat(isSoloPractice = false) {
    this.initDOM();
    this.isActive = true;
    this.hp = 100;
    this.isDead = false;
    this.matchKills = 0;
    this.matchDamageDealt = 0;
    this.isTargetLocked = false;
    this.updateHUD();

    // Setup Video Camera
    try {
      const constraints = {
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
          frameRate: { ideal: 60, min: 30 }
        },
        audio: false
      };
      
      this.videoStream = await navigator.mediaDevices.getUserMedia(constraints);
      this.dom.video.srcObject = this.videoStream;
      await this.dom.video.play();
    } catch (err) {
      console.warn('Camera access fallback or denied:', err);
      // In case camera is disabled or browser test, keep feed dark tactical with grid
      this.dom.video.classList.add('camera-simulated');
    }

    // Start Computer Vision Tracking
    window.cvTracker.start(this.dom.video, (locked, bbox) => {
      this.onLockStateChanged(locked, bbox);
    });

    if (isSoloPractice) {
      window.cvTracker.enableDroneSim(true);
      if (this.dom.droneElement) {
        this.dom.droneElement.style.display = 'block';
      }
      this.startDroneAI();
    } else {
      window.cvTracker.enableDroneSim(false);
      if (this.dom.droneElement) {
        this.dom.droneElement.style.display = 'none';
      }
    }

    this.bindControls();
    this.startHUDTicker();
  }

  stopCombat() {
    this.isActive = false;
    if (this.videoStream) {
      this.videoStream.getTracks().forEach(t => t.stop());
      this.videoStream = null;
    }
    window.cvTracker.stop();
    window.tacticalAudio.stopHeartbeat();
  }

  bindControls() {
    // Fire Trigger
    if (this.dom.fireBtn) {
      this.dom.fireBtn.onpointerdown = (e) => {
        e.preventDefault();
        this.triggerShot();
      };
    }

    // Reload Trigger
    if (this.dom.reloadBtn) {
      this.dom.reloadBtn.onclick = (e) => {
        e.preventDefault();
        this.triggerReload();
      };
    }

    // Double tap on screen also fires
    let lastTap = 0;
    this.dom.viewfinder.onclick = (e) => {
      if (e.target.closest('#hud-bottom-bar') || e.target.closest('#tac-top-status')) return;
      const now = Date.now();
      if (now - lastTap < 350) {
        this.triggerShot();
      }
      lastTap = now;
    };
  }

  triggerShot() {
    if (!this.isActive || this.isDead) return;

    const canFireResult = window.armory.canFire();
    if (!canFireResult.ready) {
      if (canFireResult.reason === 'EMPTY') {
        window.tacticalAudio.playDryFire();
        this.showToast('MAGAZINE EMPTY // PRESS RELOAD');
      }
      return;
    }

    window.armory.consumeAmmo();
    const weapon = window.armory.getActiveWeapon();

    // 1. Play realistic synthesized gunshot
    window.tacticalAudio.playGunshot(weapon.id);

    // 2. Hardware Vibration
    if (navigator.vibrate) {
      try { navigator.vibrate(weapon.id === 'awm' ? [70, 30, 40] : [35]); } catch(e) {}
    }

    // 3. Recoil animation
    this.applyRecoil(weapon.recoilStrength);

    // 4. Muzzle Flash
    this.showMuzzleFlash();

    // 5. Update Ammo HUD
    this.updateHUD();

    // 6. Hit Detection
    if (this.isTargetLocked) {
      this.registerHitOnTarget(weapon);
    }

    // 7. Network Packet
    window.p2pNetwork.sendPacket({
      type: 'PLAYER_FIRE',
      weaponId: weapon.id,
      damage: weapon.damage,
      isLocked: this.isTargetLocked
    });
  }

  triggerReload() {
    if (!this.isActive || this.isDead) return;
    const w = window.armory.getActiveWeapon();
    if (window.armory.currentAmmo >= w.magSize || window.armory.currentReserve <= 0) return;

    window.tacticalAudio.playReload();
    this.dom.reloadIndicator.classList.add('active');

    window.armory.reload(
      (progress) => {
        if (this.dom.reloadIndicator) {
          this.dom.reloadIndicator.style.strokeDashoffset = 100 - progress;
        }
      },
      () => {
        if (this.dom.reloadIndicator) {
          this.dom.reloadIndicator.classList.remove('active');
          this.dom.reloadIndicator.style.strokeDashoffset = 100;
        }
        this.updateHUD();
      }
    );
  }

  applyRecoil(strength) {
    const kickY = -strength * 1.5;
    const kickX = (Math.random() - 0.5) * strength;
    this.dom.reticle.style.transform = `translate(calc(-50% + ${kickX}px), calc(-50% + ${kickY}px)) scale(1.15)`;
    
    // Quick recovery spring
    setTimeout(() => {
      this.dom.reticle.style.transform = 'translate(-50%, -50%) scale(1.0)';
    }, 120);
  }

  showMuzzleFlash() {
    const flash = this.dom.muzzleFlash;
    if (!flash) return;
    flash.style.opacity = '1';
    flash.style.transform = `scale(${1 + Math.random() * 0.4}) rotate(${Math.random() * 360}deg)`;
    setTimeout(() => {
      flash.style.opacity = '0';
    }, 45);
  }

  onLockStateChanged(locked, bbox) {
    this.isTargetLocked = locked;
    this.currentLockedTarget = bbox;

    if (locked) {
      window.tacticalAudio.playTargetLock();
      this.dom.reticle.classList.add('locked');
      this.dom.lockIndicator.textContent = '[ TARGET LOCKED ]';
      this.dom.lockIndicator.classList.add('locked');
      if (bbox && bbox.distanceMeters) {
        this.dom.distanceTag.textContent = `DIST: ${bbox.distanceMeters}M`;
      }
      if (this.dom.targetBox && bbox) {
        this.dom.targetBox.style.display = 'block';
        this.dom.targetBox.style.left = `${bbox.normX * 100}%`;
        this.dom.targetBox.style.top = `${bbox.normY * 100}%`;
        this.dom.targetBox.style.width = `${bbox.normW * 100}%`;
        this.dom.targetBox.style.height = `${bbox.normH * 100}%`;
      }
    } else {
      this.dom.reticle.classList.remove('locked');
      this.dom.lockIndicator.textContent = '[ SCANNING SECTOR ]';
      this.dom.lockIndicator.classList.remove('locked');
      this.dom.distanceTag.textContent = 'DIST: --';
      if (this.dom.targetBox) {
        this.dom.targetBox.style.display = 'none';
      }
    }
  }

  registerHitOnTarget(weapon) {
    // 1. Hitmarker Sound & Animation
    window.tacticalAudio.playHitmarker();
    this.showHitmarker();

    // 2. Floating Damage Indicator
    const isHeadshot = Math.random() < 0.28 || weapon.id === 'awm';
    const finalDamage = isHeadshot ? Math.round(weapon.damage * 1.5) : weapon.damage;
    this.spawnFloatingDamage(finalDamage, isHeadshot);

    this.matchDamageDealt += finalDamage;

    // 3. Drone AI target damage handling
    if (window.cvTracker.droneSimulationEnabled && window.cvTracker.droneState.alive) {
      window.cvTracker.droneState.hp -= finalDamage;
      if (window.cvTracker.droneState.hp <= 0) {
        window.cvTracker.droneState.alive = false;
        this.matchKills++;
        this.handleEnemyEliminated('TACTICAL_DRONE_AI', isHeadshot);
      }
    }

    // 4. Send network hit confirmation
    window.p2pNetwork.sendPacket({
      type: 'PLAYER_HIT',
      shooterCallsign: window.profile.data.callsign,
      damage: finalDamage,
      isHeadshot
    });
  }

  showHitmarker() {
    const hm = this.dom.hitmarker;
    if (!hm) return;
    hm.classList.add('active');
    setTimeout(() => {
      hm.classList.remove('active');
    }, 140);
  }

  spawnFloatingDamage(damage, isHeadshot) {
    const el = document.createElement('div');
    el.className = `floating-dmg ${isHeadshot ? 'headshot' : ''}`;
    el.textContent = `${isHeadshot ? 'CRITICAL ' : ''}-${damage} HP`;
    this.dom.floatingDamageContainer.appendChild(el);
    setTimeout(() => {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, 900);
  }

  // Incoming Damage from Opponent
  takeDamage(amount, attackerCallsign = 'ENEMY') {
    if (this.isDead) return;

    this.hp = Math.max(0, this.hp - amount);
    this.updateHUD();

    // 1. Audio
    window.tacticalAudio.playTakeDamage();

    // 2. Heavy Haptic Vibration
    if (navigator.vibrate) {
      try { navigator.vibrate([140, 50, 140, 50, 180]); } catch(e) {}
    }

    // 3. Blood Vignette Flash
    const bg = this.dom.bloodOverlay;
    if (bg) {
      bg.style.opacity = '1';
      setTimeout(() => {
        bg.style.opacity = this.hp < 30 ? '0.45' : '0';
      }, 350);
    }

    // 4. Heartbeat pulse if low HP
    if (this.hp < 30 && this.hp > 0) {
      window.tacticalAudio.startHeartbeat();
    }

    // 5. Check Elimination
    if (this.hp <= 0) {
      this.handleEliminated(attackerCallsign);
    }
  }

  handleEliminated(killerName) {
    this.isDead = true;
    window.tacticalAudio.stopHeartbeat();
    window.tacticalAudio.playEliminated();

    if (navigator.vibrate) {
      try { navigator.vibrate([400, 100, 300]); } catch(e) {}
    }

    const result = window.profile.addMatchResult({
      won: false,
      kills: this.matchKills,
      headshots: 0
    });

    this.showMatchOutcome({
      isVictory: false,
      title: 'ELIMINATED',
      subtitle: `NEUTRALIZED BY ${killerName}`,
      stats: `KILLS: ${this.matchKills} // DAMAGE: ${this.matchDamageDealt} // EXP: +${result.expGained} // COINS: +${result.coinsGained}`
    });
  }

  handleEnemyEliminated(enemyName, isHeadshot) {
    window.tacticalAudio.playVictory();
    
    const result = window.profile.addMatchResult({
      won: true,
      kills: this.matchKills,
      headshots: isHeadshot ? 1 : 0
    });

    this.showMatchOutcome({
      isVictory: true,
      title: 'WINNER WINNER CHICKEN DINNER',
      subtitle: `TARGET ${enemyName} ELIMINATED`,
      stats: `VICTORY // KILLS: ${this.matchKills} // EXP: +${result.expGained} // COINS: +${result.coinsGained}`
    });
  }

  showMatchOutcome({ isVictory, title, subtitle, stats }) {
    if (!this.dom.matchOverlay) return;
    this.dom.outcomeTitle.textContent = title;
    this.dom.outcomeTitle.style.color = isVictory ? '#ff9800' : '#ff1744';
    this.dom.outcomeSub.textContent = subtitle;
    this.dom.outcomeStats.textContent = stats;
    this.dom.matchOverlay.classList.remove('hidden');
  }

  // Solo Drone Combat AI
  startDroneAI() {
    const droneInterval = setInterval(() => {
      if (!this.isActive || this.isDead || !window.cvTracker.droneSimulationEnabled) {
        clearInterval(droneInterval);
        return;
      }

      const drone = window.cvTracker.droneState;
      if (!drone.alive) {
        clearInterval(droneInterval);
        return;
      }

      // Render Drone in Viewfinder
      if (this.dom.droneElement) {
        this.dom.droneElement.style.left = `${drone.x * 100}%`;
        this.dom.droneElement.style.top = `${drone.y * 100}%`;
      }

      // Drone Attacks every 3.5 seconds
      const now = Date.now();
      if (now - drone.lastAttack > 3200) {
        drone.lastAttack = now;
        window.tacticalAudio.playGunshot('m416');
        this.takeDamage(15, 'COMBAT_DRONE_AI');
      }
    }, 50);
  }

  updateHUD() {
    if (!this.isActive) return;
    const w = window.armory.getActiveWeapon();
    if (this.dom.hpBarFill) {
      this.dom.hpBarFill.style.width = `${Math.max(0, this.hp)}%`;
      this.dom.hpBarFill.style.background = this.hp < 30 ? '#ff1744' : '#00e5ff';
    }
    if (this.dom.hpValue) this.dom.hpValue.textContent = `${this.hp}`;
    if (this.dom.ammoCurrent) this.dom.ammoCurrent.textContent = `${window.armory.currentAmmo}`;
    if (this.dom.ammoReserve) this.dom.ammoReserve.textContent = `/ ${window.armory.currentReserve}`;
    if (this.dom.weaponName) this.dom.weaponName.textContent = w.name;
  }

  startHUDTicker() {
    // Tabular clock update
    const clockEl = document.getElementById('tac-clock');
    if (clockEl) {
      const updateClock = () => {
        const d = new Date();
        const hh = String(d.getHours()).padStart(2, '0');
        const mm = String(d.getMinutes()).padStart(2, '0');
        const ss = String(d.getSeconds()).padStart(2, '0');
        clockEl.textContent = `${hh}:${mm}:${ss}`;
      };
      updateClock();
      setInterval(updateClock, 1000);
    }
  }

  showToast(msg) {
    const banner = document.getElementById('tac-alert-banner');
    if (banner) {
      banner.textContent = msg;
      banner.classList.add('visible');
      setTimeout(() => banner.classList.remove('visible'), 2000);
    }
  }
}

window.combat = new TacticalCombatEngine();
