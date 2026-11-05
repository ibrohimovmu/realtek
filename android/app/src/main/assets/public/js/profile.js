/**
 * RealStrike AR - Tactical Operator Profile & Progression Engine
 */
const TACTICAL_RANKS = [
  { name: 'BRONZE', minExp: 0, icon: '🛡️', color: '#cd7f32', tier: 'V' },
  { name: 'SILVER', minExp: 500, icon: '⚔️', color: '#c0c0c0', tier: 'IV' },
  { name: 'GOLD', minExp: 1000, icon: '🎖️', color: '#ffd700', tier: 'III' },
  { name: 'PLATINUM', minExp: 2000, icon: '💎', color: '#00e5ff', tier: 'II' },
  { name: 'DIAMOND', minExp: 3500, icon: '🔷', color: '#3d84ff', tier: 'I' },
  { name: 'ACE', minExp: 5500, icon: '👑', color: '#ff5252', tier: 'ELITE' },
  { name: 'CONQUEROR', minExp: 8000, icon: '⚡', color: '#ff9800', tier: 'TOP 500' }
];

const DEFAULT_AVATARS = [
  { id: 'ghost', name: 'GHOST-01', color: '#ff9800' },
  { id: 'reaper', name: 'REAPER-9', color: '#00e5ff' },
  { id: 'viper', name: 'VIPER-4', color: '#4caf50' },
  { id: 'phantom', name: 'PHANTOM-7', color: '#e91e63' }
];

class ProfileManager {
  constructor() {
    this.data = {
      callsign: 'OPERATOR_' + Math.floor(1000 + Math.random() * 9000),
      avatarType: 'preset', // 'preset' or 'custom'
      avatarId: 'ghost',
      customAvatarData: null,
      exp: 120,
      coins: 450,
      matchesPlayed: 0,
      victories: 0,
      kills: 0,
      deaths: 0,
      headshots: 0,
      createdAt: Date.now()
    };
    this.loadProfile();
  }

  loadProfile() {
    try {
      const saved = localStorage.getItem('realstrike_profile');
      if (saved) {
        this.data = { ...this.data, ...JSON.parse(saved) };
      }
    } catch (e) {
      console.warn('Profile restore error:', e);
    }
  }

  saveProfile() {
    try {
      localStorage.setItem('realstrike_profile', JSON.stringify(this.data));
    } catch (e) {
      console.error('Failed to save profile:', e);
    }
  }

  getRankInfo() {
    const exp = this.data.exp;
    let currentRank = TACTICAL_RANKS[0];
    let nextRank = TACTICAL_RANKS[1];

    for (let i = TACTICAL_RANKS.length - 1; i >= 0; i--) {
      if (exp >= TACTICAL_RANKS[i].minExp) {
        currentRank = TACTICAL_RANKS[i];
        nextRank = TACTICAL_RANKS[i + 1] || null;
        break;
      }
    }

    const expForNext = nextRank ? nextRank.minExp - currentRank.minExp : 1000;
    const progressInRank = nextRank ? exp - currentRank.minExp : expForNext;
    const rankPercent = nextRank ? Math.min(100, Math.floor((progressInRank / expForNext) * 100)) : 100;

    const level = Math.floor(exp / 350) + 1;

    return {
      rank: currentRank,
      nextRank,
      rankPercent,
      level,
      totalExp: exp
    };
  }

  getStats() {
    const d = this.data;
    const kd = d.deaths > 0 ? (d.kills / d.deaths).toFixed(2) : d.kills.toFixed(2);
    const winRate = d.matchesPlayed > 0 ? ((d.victories / d.matchesPlayed) * 100).toFixed(1) : '0.0';
    return {
      matches: d.matchesPlayed,
      victories: d.victories,
      kills: d.kills,
      deaths: d.deaths,
      kd,
      winRate: `${winRate}%`,
      headshots: d.headshots,
      coins: d.coins
    };
  }

  updateCallsign(name) {
    if (!name || name.trim().length === 0) return false;
    this.data.callsign = name.trim().toUpperCase().substring(0, 16);
    this.saveProfile();
    return true;
  }

  setPresetAvatar(avatarId) {
    this.data.avatarType = 'preset';
    this.data.avatarId = avatarId;
    this.saveProfile();
  }

  setCustomAvatar(base64Data) {
    this.data.avatarType = 'custom';
    this.data.customAvatarData = base64Data;
    this.saveProfile();
  }

  getAvatarHtml() {
    if (this.data.avatarType === 'custom' && this.data.customAvatarData) {
      return `<img src="${this.data.customAvatarData}" class="tac-avatar-img" alt="Operator Avatar"/>`;
    }
    const preset = DEFAULT_AVATARS.find(a => a.id === this.data.avatarId) || DEFAULT_AVATARS[0];
    return `<div class="tac-avatar-preset" style="border-color:${preset.color}">
      <span class="tac-avatar-initials">${this.data.callsign.substring(0, 2)}</span>
      <span class="tac-avatar-sub">${preset.id.toUpperCase()}</span>
    </div>`;
  }

  addMatchResult({ won, kills, headshots }) {
    this.data.matchesPlayed++;
    this.data.kills += kills;
    this.data.headshots += (headshots || 0);

    let expGained = kills * 60;
    let coinsGained = kills * 35;

    if (won) {
      this.data.victories++;
      expGained += 200;
      coinsGained += 150;
    } else {
      this.data.deaths++;
      expGained += 40;
      coinsGained += 25;
    }

    this.data.exp += expGained;
    this.data.coins += coinsGained;
    this.saveProfile();

    return {
      won,
      expGained,
      coinsGained,
      newTotalCoins: this.data.coins,
      newTotalExp: this.data.exp
    };
  }

  deductCoins(amount) {
    if (this.data.coins >= amount) {
      this.data.coins -= amount;
      this.saveProfile();
      return true;
    }
    return false;
  }
}

window.profile = new ProfileManager();
