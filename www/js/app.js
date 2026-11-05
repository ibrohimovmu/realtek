/**
 * RealStrike AR - Main Application Coordinator & Tactical Navigation
 */
document.addEventListener('DOMContentLoaded', () => {
  // Navigation Screens
  const navItems = document.querySelectorAll('.tac-nav-item');
  const screens = document.querySelectorAll('.screen-panel');

  function navigateTo(screenId) {
    window.tacticalAudio.playMenuClick();

    // If leaving combat, stop combat engine
    if (window.combat.isActive && screenId !== 'combat-screen') {
      window.combat.stopCombat();
    }

    screens.forEach(s => s.classList.remove('active'));
    navItems.forEach(n => n.classList.remove('active'));

    const targetScreen = document.getElementById(screenId);
    if (targetScreen) targetScreen.classList.add('active');

    const activeNav = document.querySelector(`.tac-nav-item[data-screen="${screenId}"]`);
    if (activeNav) activeNav.classList.add('active');

    // Screen specific refreshes
    if (screenId === 'profile-screen') {
      renderProfileScreen();
    } else if (screenId === 'armory-screen') {
      renderArmoryScreen();
    } else if (screenId === 'lobby-screen') {
      renderLobbyScreen();
    } else if (screenId === 'combat-screen') {
      // Check if started from match or solo practice
      window.combat.startCombat(true);
    }
  }

  // Bind sidebar nav clicks
  navItems.forEach(item => {
    item.addEventListener('click', () => {
      const target = item.getAttribute('data-screen');
      if (target) navigateTo(target);
    });
  });

  // Top Bar Status Update
  function updateTopBar() {
    const topCoin = document.getElementById('top-bar-coins');
    const topRank = document.getElementById('top-bar-rank');
    const topCallsign = document.getElementById('top-bar-callsign');

    if (topCoin) topCoin.textContent = `${window.profile.data.coins} CR`;
    if (topRank) {
      const r = window.profile.getRankInfo();
      topRank.textContent = `${r.rank.name} ${r.rank.tier} (LVL ${r.level})`;
    }
    if (topCallsign) topCallsign.textContent = window.profile.data.callsign;
  }

  // Profile Screen Rendering
  function renderProfileScreen() {
    updateTopBar();
    const rankInfo = window.profile.getRankInfo();
    const stats = window.profile.getStats();

    // Call sign input
    const inputCallsign = document.getElementById('profile-callsign-input');
    if (inputCallsign) inputCallsign.value = window.profile.data.callsign;

    // Avatar preview
    const avatarSlot = document.getElementById('profile-avatar-display');
    if (avatarSlot) avatarSlot.innerHTML = window.profile.getAvatarHtml();

    // Rank Card
    const rankBadge = document.getElementById('profile-rank-badge');
    const rankProgress = document.getElementById('profile-rank-progress');
    const rankPctText = document.getElementById('profile-rank-percent');

    if (rankBadge) {
      rankBadge.textContent = `${rankInfo.rank.icon} ${rankInfo.rank.name} ${rankInfo.rank.tier}`;
      rankBadge.style.borderColor = rankInfo.rank.color;
      rankBadge.style.color = rankInfo.rank.color;
    }
    if (rankProgress) rankProgress.style.width = `${rankInfo.rankPercent}%`;
    if (rankPctText) rankPctText.textContent = `${rankInfo.rankPercent}% TO ${rankInfo.nextRank ? rankInfo.nextRank.name : 'MAX'}`;

    // Stats Grid
    document.getElementById('stat-matches').textContent = stats.matches;
    document.getElementById('stat-wins').textContent = stats.victories;
    document.getElementById('stat-kills').textContent = stats.kills;
    document.getElementById('stat-deaths').textContent = stats.deaths;
    document.getElementById('stat-kd').textContent = stats.kd;
    document.getElementById('stat-winrate').textContent = stats.winRate;
  }

  // Profile Event Listeners
  const btnSaveCallsign = document.getElementById('btn-save-callsign');
  if (btnSaveCallsign) {
    btnSaveCallsign.onclick = () => {
      const val = document.getElementById('profile-callsign-input').value;
      if (window.profile.updateCallsign(val)) {
        window.tacticalAudio.playMenuClick();
        renderProfileScreen();
        window.combat.showToast('CALLSIGN UPDATED // AUTH CONFIRMED');
      }
    };
  }

  // Avatar Image Upload
  const avatarFileInput = document.getElementById('avatar-file-input');
  if (avatarFileInput) {
    avatarFileInput.onchange = (e) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (re) => {
          window.profile.setCustomAvatar(re.target.result);
          renderProfileScreen();
          window.combat.showToast('OPERATOR BIOMETRICS STORED');
        };
        reader.readAsDataURL(file);
      }
    };
  }

  // Armory Screen Rendering
  function renderArmoryScreen() {
    updateTopBar();
    const container = document.getElementById('armory-weapons-list');
    if (!container) return;
    container.innerHTML = '';

    const activeW = window.armory.getActiveWeapon();

    Object.values(window.armory.weapons).forEach(w => {
      const isSelected = w.id === activeW.id;
      const card = document.createElement('div');
      card.className = `tac-weapon-card ${isSelected ? 'active-selected' : ''} ${!w.unlocked ? 'locked' : ''}`;
      
      card.innerHTML = `
        <div class="tac-card-header">
          <span class="tac-weapon-name">${w.name}</span>
          <span class="tac-weapon-cat">${w.category}</span>
        </div>
        <div class="tac-weapon-blueprint">
          ${w.blueprintSvg}
        </div>
        <div class="tac-stats-row">
          <div class="tac-stat-bar-group">
            <span class="lbl">DMG ${w.damage}</span>
            <div class="bar"><div class="fill" style="width:${(w.damage/100)*100}%"></div></div>
          </div>
          <div class="tac-stat-bar-group">
            <span class="lbl">ACC ${w.accuracy}%</span>
            <div class="bar"><div class="fill" style="width:${w.accuracy}%"></div></div>
          </div>
          <div class="tac-stat-bar-group">
            <span class="lbl">REC ${w.recoilStrength}</span>
            <div class="bar"><div class="fill" style="width:${(w.recoilStrength/30)*100}%; background:#ff5252;"></div></div>
          </div>
          <div class="tac-stat-bar-group">
            <span class="lbl">MAG ${w.magSize}</span>
            <div class="bar"><div class="fill" style="width:${(w.magSize/30)*100}%"></div></div>
          </div>
        </div>
        <div class="tac-card-actions">
          ${w.unlocked ? `
            <button class="tac-btn ${isSelected ? 'active-btn' : ''}" data-action="equip" data-id="${w.id}">
              ${isSelected ? 'EQUIPPED // ACTIVE' : 'EQUIP WEAPON'}
            </button>
          ` : `
            <button class="tac-btn buy-btn" data-action="unlock" data-id="${w.id}" data-price="${w.price}">
              UNLOCK // ${w.price} COINS
            </button>
          `}
        </div>
      `;

      container.appendChild(card);
    });

    // Bind equip & unlock clicks
    container.querySelectorAll('button[data-action="equip"]').forEach(btn => {
      btn.onclick = () => {
        const id = btn.getAttribute('data-id');
        window.armory.selectWeapon(id);
        window.tacticalAudio.playReload();
        renderArmoryScreen();
      };
    });

    container.querySelectorAll('button[data-action="unlock"]').forEach(btn => {
      btn.onclick = () => {
        const id = btn.getAttribute('data-id');
        const price = parseInt(btn.getAttribute('data-price'), 10);
        if (window.profile.data.coins >= price) {
          window.profile.deductCoins(price);
          window.armory.unlockWeapon(id, window.profile.data.coins + price);
          window.tacticalAudio.playVictory();
          window.combat.showToast('NEW ARSENAL PLATFORM ACQUIRED');
          renderArmoryScreen();
        } else {
          window.tacticalAudio.playDryFire();
          window.combat.showToast('INSUFFICIENT REQUISITION COINS');
        }
      };
    });
  }

  // Lobby Screen Rendering
  function renderLobbyScreen() {
    updateTopBar();
    const pinDisplay = document.getElementById('lobby-pin-display');
    const playerList = document.getElementById('lobby-roster-list');
    const btnStartBattle = document.getElementById('btn-lobby-start');

    if (window.p2pNetwork.roomPin) {
      if (pinDisplay) pinDisplay.textContent = `ROOM PIN: ${window.p2pNetwork.roomPin}`;
      if (playerList) {
        playerList.innerHTML = '';
        window.p2pNetwork.connectedPeers.forEach(p => {
          const item = document.createElement('div');
          item.className = 'lobby-player-row';
          item.innerHTML = `
            <span class="tac-p-callsign">${p.callsign}</span>
            <span class="tac-p-rank">${p.rank} (LVL ${p.level})</span>
            <span class="tac-p-ping">${p.pingMs}ms P2P</span>
            <span class="tac-p-status">${p.isHost ? '[HOST]' : '[READY]'}</span>
          `;
          playerList.appendChild(item);
        });
      }
      if (btnStartBattle) {
        btnStartBattle.style.display = window.p2pNetwork.isHost ? 'inline-block' : 'none';
      }
    } else {
      if (pinDisplay) pinDisplay.textContent = 'STANDBY // NOT CONNECTED';
      if (playerList) {
        playerList.innerHTML = `<div class="tac-empty-notice">SELECT "CREATE ROOM" OR ENTER PIN TO JOIN SQUAD</div>`;
      }
      if (btnStartBattle) btnStartBattle.style.display = 'none';
    }
  }

  // Lobby Buttons
  const btnCreateRoom = document.getElementById('btn-create-room');
  if (btnCreateRoom) {
    btnCreateRoom.onclick = () => {
      window.tacticalAudio.playMenuClick();
      const res = window.p2pNetwork.createRoom();
      window.combat.showToast(`TACTICAL ROOM ESTABLISHED: ${res.pin}`);
      renderLobbyScreen();
    };
  }

  const btnJoinRoom = document.getElementById('btn-join-room');
  if (btnJoinRoom) {
    btnJoinRoom.onclick = () => {
      const pin = prompt('ENTER 4-DIGIT ROOM PIN:');
      if (pin && pin.trim().length === 4) {
        window.tacticalAudio.playMenuClick();
        window.p2pNetwork.joinRoom(pin);
        window.combat.showToast(`JOINING SQUAD PIN: ${pin}...`);
        renderLobbyScreen();
      }
    };
  }

  const btnStartLobby = document.getElementById('btn-lobby-start');
  if (btnStartLobby) {
    btnStartLobby.onclick = () => {
      window.tacticalAudio.playVictory();
      window.p2pNetwork.startMatch();
      navigateTo('combat-screen');
      window.combat.startCombat(false);
    };
  }

  // Solo Practice Launch
  const btnSoloPractice = document.getElementById('btn-solo-practice');
  if (btnSoloPractice) {
    btnSoloPractice.onclick = () => {
      navigateTo('combat-screen');
      window.combat.startCombat(true); // Drone AI Target enabled
    };
  }

  // Outcomes & Post Match Navigation
  const btnMatchExit = document.getElementById('btn-outcome-exit');
  if (btnMatchExit) {
    btnMatchExit.onclick = () => {
      window.tacticalAudio.playMenuClick();
      document.getElementById('match-outcome-overlay').classList.add('hidden');
      navigateTo('profile-screen');
    };
  }

  // P2P Incoming Packet Router
  window.p2pNetwork.onPacketReceived = (packet) => {
    if (packet.type === 'PLAYER_HIT') {
      window.combat.takeDamage(packet.damage, packet.shooterCallsign || 'RIVAL_OPERATOR');
    }
  };

  window.p2pNetwork.onMatchStart = () => {
    window.combat.showToast('TACTICAL ENGAGEMENT COMMENCING');
    navigateTo('combat-screen');
    window.combat.startCombat(false);
  };

  window.p2pNetwork.onConnectionStateChange = () => {
    renderLobbyScreen();
  };

  // Initial Load
  updateTopBar();
  renderProfileScreen();
  renderArmoryScreen();
});
