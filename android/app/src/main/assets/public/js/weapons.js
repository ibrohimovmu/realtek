/**
 * RealStrike AR - Weapons Arsenal & Armory Engine
 */
const WEAPONS_DATABASE = {
  m416: {
    id: 'm416',
    name: 'M416 TACTICAL',
    caliber: '5.56x45mm NATO',
    category: 'ASSAULT RIFLE',
    damage: 25,
    magSize: 30,
    reserveAmmo: 120,
    fireRateMs: 110, // ~550 RPM
    reloadTimeMs: 2200,
    recoilStrength: 8,
    accuracy: 92,
    unlocked: true,
    price: 0,
    description: 'Universal German assault carbine. Low recoil, rapid cycling, optimal balance for medium-range laser engagement.',
    blueprintSvg: `<svg viewBox="0 0 200 60" fill="none" stroke="currentColor" stroke-width="1.8">
      <path d="M15 32 L35 32 L40 22 L75 22 L80 20 L155 20 L170 24 L190 24 L190 28 L175 28 L175 34 L120 34 L110 46 L95 46 L102 34 L65 34 L55 52 L38 52 L45 34 L15 34 Z" fill="rgba(255,152,0,0.06)"/>
      <line x1="80" y1="20" x2="80" y2="15" stroke-width="2"/>
      <line x1="130" y1="20" x2="130" y2="16" stroke-width="2"/>
      <path d="M98 34 L108 48 L118 48 L108 34" fill="none" stroke-width="1.2"/>
      <circle cx="103" cy="38" r="1.5" fill="currentColor"/>
    </svg>`
  },
  akm: {
    id: 'akm',
    name: 'AKM 7.62 SOVIET',
    caliber: '7.62x39mm M43',
    category: 'HEAVY ASSAULT',
    damage: 35,
    magSize: 30,
    reserveAmmo: 90,
    fireRateMs: 145, // ~420 RPM
    reloadTimeMs: 2700,
    recoilStrength: 15,
    accuracy: 82,
    unlocked: false,
    price: 600,
    description: 'Devastating kinetic punch with heavy 7.62mm simulated round. Fierce recoil requiring steady grip and burst discipline.',
    blueprintSvg: `<svg viewBox="0 0 200 60" fill="none" stroke="currentColor" stroke-width="1.8">
      <path d="M12 36 L30 36 L38 25 L80 25 L90 22 L160 22 L172 26 L195 26 L195 29 L180 29 L180 34 L125 34 L108 55 L88 55 L98 34 L62 34 L50 54 L32 54 L42 36 L12 38 Z" fill="rgba(255,152,0,0.06)"/>
      <path d="M95 34 Q 102 46 108 55" stroke-width="2"/>
      <line x1="72" y1="25" x2="72" y2="17" stroke-width="2"/>
      <line x1="165" y1="22" x2="165" y2="16" stroke-width="2"/>
      <circle cx="98" cy="36" r="1.5" fill="currentColor"/>
    </svg>`
  },
  awm: {
    id: 'awm',
    name: 'AWM .300 MAGNUM',
    caliber: '.300 Winchester Mag',
    category: 'SNIPER SYSTEM',
    damage: 85,
    magSize: 5,
    reserveAmmo: 25,
    fireRateMs: 1200, // Bolt action cycle delay
    reloadTimeMs: 3600,
    recoilStrength: 24,
    accuracy: 99,
    unlocked: false,
    price: 1500,
    description: 'Supreme precision sniper platform. Devastating 85 HP one-shot capability. Manual bolt cycle between shots.',
    blueprintSvg: `<svg viewBox="0 0 200 60" fill="none" stroke="currentColor" stroke-width="1.8">
      <path d="M8 35 L28 35 L34 26 L70 26 L80 23 L185 23 L198 25 L198 28 L185 28 L185 32 L115 32 L108 45 L94 45 L98 32 L58 32 L52 48 L36 48 L42 35 L8 36 Z" fill="rgba(255,152,0,0.06)"/>
      <!-- Optical Scope -->
      <rect x="75" y="11" width="55" height="7" rx="2" stroke-width="1.5"/>
      <line x1="82" y1="18" x2="85" y2="23" stroke-width="1.8"/>
      <line x1="120" y1="18" x2="118" y2="23" stroke-width="1.8"/>
      <line x1="60" y1="23" x2="68" y2="18" stroke-width="2"/> <!-- Bolt handle -->
      <!-- Bipod legs -->
      <line x1="170" y1="28" x2="165" y2="52" stroke-dasharray="2 2" stroke-width="1.2"/>
    </svg>`
  }
};

class ArmoryManager {
  constructor() {
    this.weapons = JSON.parse(JSON.stringify(WEAPONS_DATABASE));
    this.selectedWeaponId = 'm416';
    this.currentAmmo = 30;
    this.currentReserve = 120;
    this.isReloading = false;
    this.lastShotTimestamp = 0;
    this.loadState();
  }

  loadState() {
    try {
      const saved = localStorage.getItem('realstrike_armory');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed.unlockedWeapons) {
          parsed.unlockedWeapons.forEach(id => {
            if (this.weapons[id]) this.weapons[id].unlocked = true;
          });
        }
        if (parsed.selectedWeaponId && this.weapons[parsed.selectedWeaponId]) {
          this.selectedWeaponId = parsed.selectedWeaponId;
        }
      }
    } catch (e) {
      console.warn('Armory state restore fallback:', e);
    }
    this.resetAmmo();
  }

  saveState() {
    try {
      const unlockedWeapons = Object.keys(this.weapons).filter(k => this.weapons[k].unlocked);
      localStorage.setItem('realstrike_armory', JSON.stringify({
        unlockedWeapons,
        selectedWeaponId: this.selectedWeaponId
      }));
    } catch (e) {
      console.error('Failed to save armory state:', e);
    }
  }

  getActiveWeapon() {
    return this.weapons[this.selectedWeaponId] || this.weapons.m416;
  }

  selectWeapon(weaponId) {
    if (!this.weapons[weaponId] || !this.weapons[weaponId].unlocked) return false;
    this.selectedWeaponId = weaponId;
    this.resetAmmo();
    this.saveState();
    return true;
  }

  unlockWeapon(weaponId, coinBalance) {
    const weapon = this.weapons[weaponId];
    if (!weapon || weapon.unlocked) return { success: false, reason: 'ALREADY_UNLOCKED' };
    if (coinBalance < weapon.price) return { success: false, reason: 'INSUFFICIENT_FUNDS' };

    weapon.unlocked = true;
    this.saveState();
    return { success: true, price: weapon.price };
  }

  resetAmmo() {
    const w = this.getActiveWeapon();
    this.currentAmmo = w.magSize;
    this.currentReserve = w.reserveAmmo;
    this.isReloading = false;
  }

  canFire() {
    if (this.isReloading) return { ready: false, reason: 'RELOADING' };
    const now = Date.now();
    const w = this.getActiveWeapon();
    if (now - this.lastShotTimestamp < w.fireRateMs) return { ready: false, reason: 'CYCLING' };
    if (this.currentAmmo <= 0) return { ready: false, reason: 'EMPTY' };
    return { ready: true };
  }

  consumeAmmo() {
    if (this.currentAmmo > 0) {
      this.currentAmmo--;
      this.lastShotTimestamp = Date.now();
      return true;
    }
    return false;
  }

  reload(onProgress, onComplete) {
    if (this.isReloading) return;
    const w = this.getActiveWeapon();
    if (this.currentAmmo >= w.magSize) return;
    if (this.currentReserve <= 0) return;

    this.isReloading = true;
    const reloadDuration = w.reloadTimeMs;
    const start = Date.now();

    const interval = setInterval(() => {
      const elapsed = Date.now() - start;
      const progress = Math.min(100, Math.floor((elapsed / reloadDuration) * 100));
      if (onProgress) onProgress(progress);

      if (elapsed >= reloadDuration) {
        clearInterval(interval);
        const needed = w.magSize - this.currentAmmo;
        const toLoad = Math.min(needed, this.currentReserve);
        this.currentAmmo += toLoad;
        this.currentReserve -= toLoad;
        this.isReloading = false;
        if (onComplete) onComplete();
      }
    }, 50);
  }
}

window.armory = new ArmoryManager();
