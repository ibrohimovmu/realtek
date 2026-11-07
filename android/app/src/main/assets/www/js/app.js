/**
 * WABI MAIN APPLICATION CONTROLLER
 * Connects 5-tab UI, 3D Furry monster, Liquid lens swipe,
 * Tarbiya encyclopedia, Dardkash AI, and Native Android engine.
 */

let onboardingInstance;
let furryInstance;
let familySyncInstance;
let dardkashInstance;
let selectedRole = 'parent';
let currentTab = 'home';

document.addEventListener('DOMContentLoaded', () => {
    // 1. Initialize Core Services
    familySyncInstance = new FamilySync();
    dardkashInstance = new DardkashAI();

    // 2. Initialize "Meet Wabi" Liquid Lens Onboarding (2nd video)
    onboardingInstance = new WabiOnboarding('lens-canvas');

    // 3. Initialize "What's Your Vibe Today?" 3D Furry Monster (1st video)
    furryInstance = new FurryMonster('furry-canvas', 'vibe-slider', {
        onVibeChange: (val) => {
            // Live vibe update
        }
    });

    // 4. Check if already onboarded
    if (familySyncInstance.profile && familySyncInstance.family) {
        document.getElementById('onboarding-screen').classList.add('hidden');
        renderDashboard();
    }

    // 5. Initialize Tab Features
    initPrayerTimes();
    renderTarbiyaList('all');
    renderDardkashChat();
    initUsageStats();
    updatePermissionStatus();

    // 6. Periodic UI Refresh
    setInterval(() => {
        updatePermissionStatus();
        renderUsageStats();
    }, 4000);
});

// ============================================================================
// 1. ONBOARDING & SETUP FLOW
// ============================================================================
function startSetup(role) {
    selectedRole = role;
    document.getElementById('modal-role-title').textContent =
        role === 'parent' ? "Ota-ona (Parent Mode)" : "Farzand (Kid Mode)";
    document.getElementById('role-modal').style.display = 'flex';
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(1);
}

function completeSetup() {
    const nameInput = document.getElementById('setup-name-input');
    const codeInput = document.getElementById('setup-code-input');

    const name = nameInput.value.trim() || (selectedRole === 'parent' ? 'Ota-ona' : 'Farzand');
    const code = codeInput.value.trim();

    if (selectedRole === 'kid' && code && code.length === 6) {
        familySyncInstance.joinFamilyRoom(name, code);
    } else {
        familySyncInstance.createFamilyRoom(name);
    }

    document.getElementById('role-modal').style.display = 'none';
    document.getElementById('onboarding-screen').classList.add('hidden');

    if (window.AndroidNative) window.AndroidNative.triggerHaptic(2);

    renderDashboard();
}

function renderDashboard() {
    const f = familySyncInstance.family;
    const p = familySyncInstance.profile;
    if (!f || !p) return;

    document.getElementById('header-family-name').textContent = f.name || 'Bizning Oila';
    document.getElementById('header-code-tag').textContent = `KOD: ${f.code}`;
    document.getElementById('header-user-badge').textContent = `${p.name} • ${p.role === 'parent' ? 'Ota-ona' : 'Farzand'}`;
    document.getElementById('header-avatar').textContent = p.avatar || '👑';

    renderHabits();
    renderFamilyMembers();
    renderAppLimits();
}

function copyFamilyCode() {
    const f = familySyncInstance.family;
    if (!f) return;
    navigator.clipboard.writeText(f.code).then(() => {
        alert(`Oila kodi nusxalandi: ${f.code}\nIkkinchi telefonga ulanish uchun shu kodni kiriting!`);
    }).catch(() => {
        alert(`Oila kodi: ${f.code}`);
    });
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(1);
}

// ============================================================================
// 2. NAMANGAN PRAYER TIMES & SYSTEM ALARM SCHEDULER
// ============================================================================
async function initPrayerTimes() {
    const timings = await familySyncInstance.fetchAndSetNamanganPrayerAlarms();
    if (timings) {
        document.getElementById('t-fajr').textContent = timings.Fajr;
        document.getElementById('t-dhuhr').textContent = timings.Dhuhr;
        document.getElementById('t-asr').textContent = timings.Asr;
        document.getElementById('t-maghrib').textContent = timings.Maghrib;
        document.getElementById('t-isha').textContent = timings.Isha;
    }
}

function syncPrayerAlarms() {
    const p = familySyncInstance.getStored(familySyncInstance.STORAGE_KEYS.PRAYERS);
    if (!p) {
        initPrayerTimes();
        return;
    }

    if (window.AndroidNative) {
        const success = window.AndroidNative.setPrayerAlarmsJson(JSON.stringify(p));
        window.AndroidNative.triggerHaptic(2);
        if (success) {
            alert("5 mahal namoz vaqtlariga telefoningizda avtomatik budilnik o'rnatildi! 🕌");
        } else {
            alert("Budilnik o'rnatish uchun ruxsat bering.");
        }
    } else {
        alert("Android tizimida 5 mahal namozga avtomatik budilnik o'rnatiladi!");
    }
}

// ============================================================================
// 3. USAGE STATS & INSTAGRAM 10-MINUTE LIMITS
// ============================================================================
function initUsageStats() {
    renderUsageStats();
}

function renderUsageStats() {
    const list = document.getElementById('home-usage-list');
    if (!list) return;

    if (!window.AndroidNative || !window.AndroidNative.hasPermission('usage_stats')) {
        list.innerHTML = `
            <div style="text-align: center; padding: 14px 0; color: var(--text-secondary); font-size: 13px;">
                Haqiqiy ilovalar vaqtini ko'rish va 10-daqiqa limitini yoqish uchun ruxsat bering.
                <button class="btn-pill" style="margin-top: 10px; width: auto; padding: 8px 18px; font-size: 13px;" onclick="requestPermission('usage_stats')">
                    <span>Usage Stats Ruxsatini Yoqish</span>
                    <span class="btn-arrow-circle">→</span>
                </button>
            </div>
        `;
        return;
    }

    try {
        const json = window.AndroidNative.getUsageStatsJson();
        const stats = JSON.parse(json || '[]');

        if (stats.length === 0) {
            list.innerHTML = `<div style="text-align: center; padding: 12px 0; color: var(--text-muted); font-size: 13px;">Bugun og'ir ilovalar ochilmadi.</div>`;
            return;
        }

        stats.sort((a, b) => b.usedMinutes - a.usedMinutes);

        list.innerHTML = '';
        stats.slice(0, 5).forEach(app => {
            const row = document.createElement('div');
            row.style.cssText = "display: flex; align-items: center; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.05);";

            const isOverlimit = (app.packageName === 'com.instagram.android' && app.usedMinutes >= 10);

            row.innerHTML = `
                <div style="display: flex; align-items: center; gap: 10px;">
                    <div style="width: 34px; height: 34px; border-radius: 10px; background: rgba(213, 184, 149, 0.12); display: flex; align-items: center; justify-content: center; font-size: 16px;">📱</div>
                    <div>
                        <div style="font-size: 14px; font-weight: 700; color: ${isOverlimit ? 'var(--accent-red)' : 'var(--text-primary)'};">${escapeHtml(app.appName)}</div>
                        <div style="font-size: 11px; color: var(--text-muted);">${escapeHtml(app.packageName)}</div>
                    </div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 13px; font-weight: 800; color: ${isOverlimit ? 'var(--accent-red)' : 'var(--gold)'};">${app.usedMinutes} daqiqa</div>
                    ${isOverlimit ? '<div style="font-size: 10px; color: var(--accent-red); font-weight: 700;">LIMITDAN OSHDI!</div>' : ''}
                </div>
            `;
            list.appendChild(row);
        });
    } catch (e) {
        list.innerHTML = `<div style="text-align: center; padding: 12px 0; color: var(--text-muted); font-size: 13px;">Tahlil qilinmoqda...</div>`;
    }
}

function renderAppLimits() {
    const list = document.getElementById('app-limits-view');
    if (!list) return;

    const defaultTargetApps = [
        { pkg: 'com.instagram.android', name: 'Instagram', defaultLimit: 10 },
        { pkg: 'com.zhiliaoapp.musically', name: 'TikTok', defaultLimit: 10 },
        { pkg: 'com.google.android.youtube', name: 'YouTube', defaultLimit: 25 },
        { pkg: 'org.telegram.messenger', name: 'Telegram', defaultLimit: 40 },
        { pkg: 'com.dts.freefireth', name: 'Free Fire', defaultLimit: 15 }
    ];

    const savedLimits = familySyncInstance.getStored(familySyncInstance.STORAGE_KEYS.LIMITS) || {};

    list.innerHTML = '';
    defaultTargetApps.forEach(item => {
        const currentLimit = savedLimits[item.pkg] !== undefined ? savedLimits[item.pkg] : item.defaultLimit;

        const row = document.createElement('div');
        row.style.cssText = "display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid rgba(255,255,255,0.05);";
        row.innerHTML = `
            <div>
                <div style="font-size: 14px; font-weight: 700;">${item.name}</div>
                <div style="font-size: 11px; color: var(--text-muted);">${item.pkg}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
                <span style="font-size: 13px; color: var(--gold); font-weight: 800;">${currentLimit} daqiqa</span>
                <button class="card-header-action" onclick="changeLimitPrompt('${item.pkg}', '${item.name}', ${currentLimit})">O'zgartirish</button>
            </div>
        `;
        list.appendChild(row);
    });
}

function changeLimitPrompt(pkg, name, current) {
    const val = prompt(`${name} uchun kunlik limitni daqiqalarda kiriting (masalan 10):`, current);
    if (val !== null) {
        const num = parseInt(val, 10);
        if (!isNaN(num) && num >= 0) {
            familySyncInstance.setAppLimit(pkg, num);
            if (window.AndroidNative) window.AndroidNative.triggerHaptic(2);
            renderAppLimits();
        }
    }
}

function requestPermission(type) {
    if (window.AndroidNative) {
        window.AndroidNative.requestPermission(type);
    } else {
        alert(`${type} ruxsatini sozlamalardan yoqing.`);
    }
}

function updatePermissionStatus() {
    if (!window.AndroidNative) return;

    const hasUsage = window.AndroidNative.hasPermission('usage_stats');
    const uBtn = document.getElementById('usage-perm-btn');
    if (uBtn) {
        uBtn.textContent = hasUsage ? '✓ Faol' : 'Ruxsat berish';
        uBtn.style.color = hasUsage ? 'var(--accent-green)' : 'var(--gold)';
    }

    const hasAccess = window.AndroidNative.hasPermission('accessibility');
    const aBtn = document.getElementById('access-perm-btn');
    if (aBtn) {
        aBtn.textContent = hasAccess ? '✓ Himoya: Faol' : 'Himoya: O\'chiq';
        aBtn.style.color = hasAccess ? 'var(--accent-green)' : 'var(--accent-red)';
    }
}

// ============================================================================
// 4. TARBIYA ENSIKLOPEDIYASI RENDERING
// ============================================================================
function filterTarbiya(categoryId) {
    document.querySelectorAll('#tarbiya-chips .chip').forEach(c => c.classList.remove('active'));
    event.target.classList.add('active');
    renderTarbiyaList(categoryId);
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(1);
}

function renderTarbiyaList(categoryId) {
    const container = document.getElementById('tarbiya-topics-list');
    if (!container || !window.TARBIYA_DATA) return;

    container.innerHTML = '';

    window.TARBIYA_DATA.categories.forEach(cat => {
        if (categoryId !== 'all' && cat.id !== categoryId) return;

        cat.topics.forEach(t => {
            const card = document.createElement('div');
            card.className = 'topic-item';
            card.onclick = () => openTopicModal(t, cat.title);
            card.innerHTML = `
                <div class="topic-tag">${escapeHtml(t.tag)} • ${escapeHtml(cat.title)}</div>
                <div class="topic-title">${escapeHtml(t.title)}</div>
                <div class="topic-summary">${escapeHtml(t.summary)}</div>
            `;
            container.appendChild(card);
        });
    });
}

function openTopicModal(topic, categoryTitle) {
    document.getElementById('modal-topic-tag').textContent = `${categoryTitle} • ${topic.tag}`;
    document.getElementById('modal-topic-title').textContent = topic.title;
    document.getElementById('modal-topic-content').textContent = topic.content.trim();
    document.getElementById('topic-modal').classList.add('active');
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(2);
}

function closeTopicModal() {
    document.getElementById('topic-modal').classList.remove('active');
}

// ============================================================================
// 5. VIBE SAVER & VIDEO SCRUBBING (1-VIDEO)
// ============================================================================
function toggleOnboardingMode(mode) {
    const lensCanvas = document.getElementById('lens-canvas');
    const videoBox = document.getElementById('onboarding-video-box');
    const wabiVideo = document.getElementById('wabi-preview-video');
    const btnLens = document.getElementById('btn-onboarding-lens');
    const btnVideo = document.getElementById('btn-onboarding-video');

    if (mode === 'video') {
        if (lensCanvas) lensCanvas.style.display = 'none';
        if (videoBox) videoBox.style.display = 'block';
        if (wabiVideo) wabiVideo.play();
        if (btnLens) btnLens.classList.remove('active');
        if (btnVideo) btnVideo.classList.add('active');
        document.getElementById('onboarding-buttons').classList.add('visible');
    } else {
        if (lensCanvas) lensCanvas.style.display = 'block';
        if (videoBox) videoBox.style.display = 'none';
        if (wabiVideo) wabiVideo.pause();
        if (btnLens) btnLens.classList.add('active');
        if (btnVideo) btnVideo.classList.remove('active');
    }
}

function toggleVibeMode(mode) {
    const videoContainer = document.getElementById('vibe-video-container');
    const canvasContainer = document.getElementById('furry-container');
    const btnVideo = document.getElementById('btn-vibe-video');
    const btnCanvas = document.getElementById('btn-vibe-canvas');

    if (mode === 'canvas') {
        if (videoContainer) videoContainer.style.display = 'none';
        if (canvasContainer) canvasContainer.style.display = 'flex';
        if (btnVideo) btnVideo.classList.remove('active');
        if (btnCanvas) btnCanvas.classList.add('active');
        if (furryInstance) setTimeout(() => furryInstance.resize(), 50);
    } else {
        if (videoContainer) videoContainer.style.display = 'flex';
        if (canvasContainer) canvasContainer.style.display = 'none';
        if (btnVideo) btnVideo.classList.add('active');
        if (btnCanvas) btnCanvas.classList.remove('active');
    }
}

function setupVideoScrubbing() {
    const slider = document.getElementById('vibe-slider');
    const scrubVideo = document.getElementById('vibe-scrub-video');
    if (slider && scrubVideo) {
        slider.addEventListener('input', (e) => {
            const frac = parseFloat(e.target.value) / 100;
            if (scrubVideo.duration) {
                scrubVideo.currentTime = frac * scrubVideo.duration;
            }
        });
    }
}
document.addEventListener('DOMContentLoaded', setupVideoScrubbing);

function saveVibeScore() {
    const slider = document.getElementById('vibe-slider');
    const val = slider ? parseInt(slider.value, 10) : Math.round(furryInstance.vibe * 100);
    const p = familySyncInstance.profile;
    if (p) {
        p.vibe = val;
        familySyncInstance.setStored(familySyncInstance.STORAGE_KEYS.PROFILE, p);
    }
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(2);
    alert(`Bugungi hissiy holatingiz (${val}%) muvaffaqiyatli saqlandi! ✨`);
}

// ============================================================================
// 6. DARDKASH AI CHAT
// ============================================================================
function renderDardkashChat() {
    const box = document.getElementById('chat-messages');
    if (!box) return;

    box.innerHTML = '';
    dardkashInstance.history.forEach(m => {
        const bubble = document.createElement('div');
        bubble.className = `chat-bubble ${m.role}`;
        bubble.textContent = m.text;
        box.appendChild(bubble);
    });
    box.scrollTop = box.scrollHeight;
}

async function sendDardkashMessage() {
    const input = document.getElementById('chat-input');
    const text = input.value.trim();
    if (!text) return;

    input.value = '';
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(1);

    renderDardkashChat();
    await dardkashInstance.sendMessage(text);
    renderDardkashChat();
}

function handleChatKey(e) {
    if (e.key === 'Enter') sendDardkashMessage();
}

function clearDardkashChat() {
    if (confirm("Suhbat tarixini tozalashni xohlaysizmi?")) {
        dardkashInstance.history = [];
        dardkashInstance.saveHistory();
        renderDardkashChat();
    }
}

// ============================================================================
// 7. HABITS & FAMILY MEMBERS
// ============================================================================
function renderHabits() {
    const list = document.getElementById('home-habits-list');
    if (!list) return;

    const habits = [
        { title: "Bomdod namozini o'qish", reward: "+50 ball", done: true },
        { title: "30 daqiqa kitob mutolaasi", reward: "+40 ball", done: false },
        { title: "Telefonni 1 soat umuman ishlatmaslik", reward: "+30 ball", done: false },
        { title: "Turnik va jismoniy mashq", reward: "+50 ball", done: true }
    ];

    list.innerHTML = '';
    habits.forEach(h => {
        const row = document.createElement('div');
        row.style.cssText = "display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid rgba(255,255,255,0.05);";
        row.innerHTML = `
            <div style="display: flex; align-items: center; gap: 10px;">
                <div style="width: 22px; height: 22px; border-radius: 50%; border: 2px solid var(--gold); display: flex; align-items: center; justify-content: center; cursor: pointer; background: ${h.done ? 'var(--accent-green)' : 'transparent'}; border-color: ${h.done ? 'var(--accent-green)' : 'var(--gold)'};">
                    ${h.done ? '✓' : ''}
                </div>
                <span style="font-size: 14px; font-weight: 600; text-decoration: ${h.done ? 'line-through' : 'none'}; color: ${h.done ? 'var(--text-muted)' : 'var(--text-primary)'};">${h.title}</span>
            </div>
            <span style="font-size: 12px; color: var(--gold); font-weight: 700;">${h.reward}</span>
        `;
        list.appendChild(row);
    });
}

function addNewHabitPrompt() {
    const title = prompt("Yangi kunlik vazifani kiriting:");
    if (title) {
        if (window.AndroidNative) window.AndroidNative.triggerHaptic(2);
        renderHabits();
    }
}

function renderFamilyMembers() {
    const list = document.getElementById('family-members-view');
    if (!list) return;

    const p = familySyncInstance.profile;
    list.innerHTML = `
        <div style="display: flex; align-items: center; justify-content: space-between; padding: 10px 0;">
            <div style="display: flex; align-items: center; gap: 12px;">
                <div class="header-avatar">${p ? p.avatar : '👑'}</div>
                <div>
                    <div style="font-size: 15px; font-weight: 700;">${p ? p.name : 'Siz'}</div>
                    <div style="font-size: 12px; color: var(--text-secondary);">${p && p.role === 'parent' ? 'Ota-ona (Boshqaruvchi)' : 'Farzand'}</div>
                </div>
            </div>
            <div class="card-header-action" style="background: rgba(118, 184, 67, 0.15); color: var(--accent-green);">
                Vibe: ${p && p.vibe ? p.vibe : 75}%
            </div>
        </div>
    `;
}

// ============================================================================
// 8. 5-TAB DOCK NAVIGATION
// ============================================================================
function navigateTab(tabName) {
    document.querySelectorAll('.tab-view').forEach(v => v.classList.remove('active'));
    document.querySelectorAll('.dock-item').forEach(d => d.classList.remove('active'));

    const targetView = document.getElementById(`view-${tabName}`);
    const targetDock = document.getElementById(`dock-${tabName}`);
    if (targetView) targetView.classList.add('active');
    if (targetDock) targetDock.classList.add('active');

    currentTab = tabName;
    if (window.AndroidNative) window.AndroidNative.triggerHaptic(1);

    if (tabName === 'vibe' && furryInstance) {
        setTimeout(() => furryInstance.resize(), 60);
    }
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
