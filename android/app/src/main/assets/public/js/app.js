/**
 * WABI MAIN APPLICATION CONTROLLER
 * - Dual Role: Parent Mode vs Kid Mode.
 * - Zero Mock / 100% Real Backend & Native Integration.
 */

let supabaseClient;
let wabiLens;
let furryVibe;
let selectedRole = 'parent';
let currentFamily = null;
let currentProfile = null;

document.addEventListener('DOMContentLoaded', async () => {
    supabaseClient = new WabiSupabaseClient();

    // 1. Initialize Wabi Lens Swipe (2-video)
    wabiLens = new WabiLens('lens-canvas', {
        onUnlock: () => {
            handleLensUnlocked();
        }
    });

    // 2. Initialize 3D Furry Character (1-video)
    furryVibe = new FurryVibe('furry-canvas', 'vibe-slider', {
        onVibeChange: (score) => {
            // Live vibe preview
        }
    });

    // 3. Check existing profile & family
    currentFamily = supabaseClient.getCachedFamily();
    currentProfile = supabaseClient.getCachedProfile();

    if (currentProfile && currentFamily) {
        document.getElementById('welcome-screen').classList.add('hidden');
        renderDashboard();
    }

    // 4. Load Namangan prayer times
    loadPrayerTimes();

    // 5. Check Native Permissions
    updatePermissionPills();
});

// ============================================================================
// WELCOME SCREEN & SETUP FLOW
// ============================================================================
function handleLensUnlocked() {
    setTimeout(() => {
        if (!currentProfile || !currentFamily) {
            document.getElementById('setup-modal').classList.add('active');
        } else {
            document.getElementById('welcome-screen').classList.add('hidden');
            renderDashboard();
        }
    }, 450);
}

function selectRole(role) {
    selectedRole = role;
    document.getElementById('role-parent').classList.toggle('selected', role === 'parent');
    document.getElementById('role-kid').classList.toggle('selected', role === 'kid');
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(1);
}

async function confirmSetup() {
    const nameInput = document.getElementById('input-user-name');
    const codeInput = document.getElementById('input-family-code');

    const name = nameInput.value.trim() || (selectedRole === 'parent' ? 'Ota-ona' : 'Farzand');
    const code = codeInput.value.trim();

    try {
        if (code && code.length === 6) {
            // Join existing family room
            currentFamily = await supabaseClient.findFamilyByCode(code);
            if (!currentFamily) {
                // If not found in cloud, create with that code
                currentFamily = await supabaseClient.createFamily(name + ' Oilasi');
            }
        } else {
            // Create brand new family room
            currentFamily = await supabaseClient.createFamily(name + ' Oilasi');
        }

        // Register profile
        const avatar = selectedRole === 'parent' ? '👑' : '🧒';
        currentProfile = await supabaseClient.registerProfile(
            currentFamily.id,
            name,
            selectedRole,
            avatar
        );

        document.getElementById('setup-modal').classList.remove('active');
        document.getElementById('welcome-screen').classList.add('hidden');

        if (window.WabiBridge) window.WabiBridge.triggerHaptic(2);

        renderDashboard();
    } catch (e) {
        alert('Xatolik yuz berdi: ' + e.message);
    }
}

// ============================================================================
// DASHBOARD RENDERING
// ============================================================================
async function renderDashboard() {
    if (!currentFamily || !currentProfile) return;

    // Header info
    document.getElementById('header-family-name').textContent = currentFamily.family_name || 'Bizning Oila';
    document.getElementById('header-family-code').textContent = `KOD: ${currentFamily.family_code}`;
    document.getElementById('header-user-status').textContent = `${currentProfile.name} • ${currentProfile.role === 'parent' ? 'Ota-ona' : 'Farzand'}`;
    document.getElementById('header-avatar').textContent = currentProfile.avatar_url || (currentProfile.role === 'parent' ? '👑' : '🧒');

    // Sync Furry Vibe score
    if (currentProfile.current_vibe_score) {
        furryVibe.setScore(currentProfile.current_vibe_score);
    }

    // Refresh UI components
    renderUsageStats();
    renderTasks();
    renderFamilyMembers();
    renderAppLimits();
    updatePermissionPills();
}

function copyFamilyCode() {
    if (!currentFamily) return;
    navigator.clipboard.writeText(currentFamily.family_code).then(() => {
        alert(`Oila kodi nusxalandi: ${currentFamily.family_code}\nBuni farzandingiz telefoniga kiriting!`);
    }).catch(() => {
        alert(`Oila kodi: ${currentFamily.family_code}`);
    });
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(1);
}

// ============================================================================
// NAMANGAN PRAYER TIMES
// ============================================================================
async function loadPrayerTimes() {
    try {
        const timings = await supabaseClient.fetchNamanganPrayerTimes();
        if (timings) {
            document.querySelector('#p-fajr .prayer-time').textContent = timings.fajr;
            document.querySelector('#p-dhuhr .prayer-time').textContent = timings.dhuhr;
            document.querySelector('#p-asr .prayer-time').textContent = timings.asr;
            document.querySelector('#p-maghrib .prayer-time').textContent = timings.maghrib;
            document.querySelector('#p-isha .prayer-time').textContent = timings.isha;
        }
    } catch (ignored) {}
}

// ============================================================================
// SCREEN TIME & REAL USAGE STATS
// ============================================================================
function renderUsageStats() {
    const list = document.getElementById('usage-list');
    list.innerHTML = '';

    if (!window.WabiBridge || !window.WabiBridge.isUsageStatsPermissionGranted()) {
        list.innerHTML = `
            <div style="text-align: center; padding: 14px 0; color: var(--text-secondary); font-size: 13px;">
                Haqiqiy ilovalar vaqtini ko'rish uchun ruxsat bering.
                <button class="btn-primary" style="margin-top: 10px; padding: 8px 18px; font-size: 12px; width: auto;" onclick="requestUsagePermission()">
                    Usage Access Ruxsatini Yoqish
                </button>
            </div>
        `;
        return;
    }

    try {
        const statsJson = window.WabiBridge.getTodayUsageStats();
        const stats = JSON.parse(statsJson || '[]');

        if (stats.length === 0) {
            list.innerHTML = `
                <div style="text-align: center; padding: 12px 0; color: var(--text-muted); font-size: 13px;">
                    Bugun hali og'ir ilovalar ochilmadi.
                </div>
            `;
            return;
        }

        // Sort descending by usage minutes
        stats.sort((a, b) => b.usedMinutes - a.usedMinutes);

        stats.slice(0, 5).forEach(app => {
            const row = document.createElement('div');
            row.className = 'usage-app-row';
            row.innerHTML = `
                <div class="usage-app-left">
                    <div class="usage-app-icon">📱</div>
                    <div>
                        <div class="usage-app-name">${escapeHtml(app.appName)}</div>
                        <div style="font-size: 11px; color: var(--text-muted);">${escapeHtml(app.packageName)}</div>
                    </div>
                </div>
                <div class="usage-app-time">${app.usedMinutes} daqiqa</div>
            `;
            list.appendChild(row);
        });
    } catch (e) {
        list.innerHTML = `<div style="font-size: 13px; color: var(--text-muted); text-align: center;">Ma'lumot olinmoqda...</div>`;
    }
}

function requestUsagePermission() {
    if (window.WabiBridge) {
        window.WabiBridge.openUsageStatsSettings();
    } else {
        alert("Bu funksiya Android qurilmasida haqiqiy UsageStatsManager orqali ishlaydi.");
    }
}

function requestAccessibilityPermission() {
    if (window.WabiBridge) {
        window.WabiBridge.openAccessibilitySettings();
    } else {
        alert("AccessibilityService sozlamalarini ochish.");
    }
}

function updatePermissionPills() {
    if (!window.WabiBridge) return;

    const isUsage = window.WabiBridge.isUsageStatsPermissionGranted();
    const usageBtn = document.getElementById('usage-permission-btn');
    if (usageBtn) {
        usageBtn.textContent = isUsage ? '✓ Faol' : 'Ruxsat berish';
        usageBtn.style.color = isUsage ? 'var(--accent-green)' : 'var(--gold)';
    }

    const isAccess = window.WabiBridge.isAccessibilityEnabled();
    const accessBadge = document.getElementById('accessibility-badge');
    if (accessBadge) {
        accessBadge.textContent = isAccess ? '✓ Himoya: Faol' : 'Himoya: O\'chiq';
        accessBadge.style.color = isAccess ? 'var(--accent-green)' : 'var(--accent-red)';
    }
}

// ============================================================================
// TASKS & HABITS
// ============================================================================
async function renderTasks() {
    if (!currentFamily) return;

    const tasks = await supabaseClient.getTasks(currentFamily.id, currentProfile ? currentProfile.id : null);
    const fullList = document.getElementById('full-tasks-list');
    const quickList = document.getElementById('quick-tasks-list');

    fullList.innerHTML = '';
    quickList.innerHTML = '';

    if (tasks.length === 0) {
        const emptyHtml = `
            <div style="text-align: center; padding: 24px 0; color: var(--text-secondary); font-size: 14px;">
                Hozircha birorta ham vazifa belgilanmagan.<br>
                ${currentProfile && currentProfile.role === 'parent' ? '<b style="color: var(--gold)">"+ Yangi Vazifa"</b> tugmasini bosib vazifa qo\'shing!' : 'Ota-onangiz sizga vazifa berishini kuting.'}
            </div>
        `;
        fullList.innerHTML = emptyHtml;
        quickList.innerHTML = emptyHtml;
        return;
    }

    tasks.forEach(t => {
        const item = document.createElement('div');
        item.className = `task-item ${t.is_completed ? 'completed' : ''}`;

        const isParent = currentProfile && currentProfile.role === 'parent';

        item.innerHTML = `
            <div style="display: flex; align-items: center; width: 100%;">
                <div class="task-checkbox ${t.is_completed ? 'checked' : ''}" onclick="toggleTask('${t.id}', ${!t.is_completed})">
                    ${t.is_completed ? '✓' : ''}
                </div>
                <div class="task-info">
                    <div class="task-title">${escapeHtml(t.title)}</div>
                    <div class="task-meta">
                        <span class="task-bounty">+${t.reward_points} ball</span>
                        <span>Muxlat: ${t.deadline || 'Bugun'}</span>
                        ${t.verified_by_parent ? '<span style="color: var(--accent-green)">✓ Tasdiqlangan</span>' : ''}
                    </div>
                </div>
                ${(isParent && t.is_completed && !t.verified_by_parent) ? `
                    <button class="btn-verify" onclick="verifyTask('${t.id}', '${t.kid_id}', ${t.reward_points})">Tasdiqlash</button>
                ` : ''}
            </div>
        `;

        fullList.appendChild(item.cloneNode(true));
        if (quickList.children.length < 3) {
            quickList.appendChild(item);
        }
    });
}

async function toggleTask(taskId, newStatus) {
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(1);
    await supabaseClient.toggleTaskCompletion(taskId, newStatus);
    renderTasks();
}

async function verifyTask(taskId, kidId, rewardPoints) {
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(2);
    await supabaseClient.verifyTask(taskId, kidId, rewardPoints);
    alert("Vazifa muvaffaqiyatli tasdiqlandi va ball berildi! ⭐️");
    renderTasks();
}

function openNewTaskModal() {
    document.getElementById('new-task-modal').style.display = 'flex';
}

function closeNewTaskModal() {
    document.getElementById('new-task-modal').style.display = 'none';
}

async function submitNewTask() {
    const title = document.getElementById('task-title-input').value.trim();
    const points = parseInt(document.getElementById('task-points-input').value, 10) || 50;
    const deadline = document.getElementById('task-deadline-input').value.trim() || '19:00';

    if (!title) {
        alert("Vazifa nomini kiriting!");
        return;
    }

    await supabaseClient.createTask(
        currentFamily.id,
        currentProfile.id,
        title,
        points,
        deadline
    );

    document.getElementById('task-title-input').value = '';
    closeNewTaskModal();
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(2);
    renderTasks();
}

// ============================================================================
// VIBE SAVING (1-VIDEO)
// ============================================================================
async function saveCurrentVibe() {
    if (!currentProfile) return;
    const score = furryVibe.score;
    await supabaseClient.updateVibeScore(currentProfile.id, score);
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(2);
    alert(`Kayfiyatingiz (${score}%) muvaffaqiyatli saqlandi va oilangizga ko'rindi! ✨`);
}

// ============================================================================
// FAMILY & APP LIMITS
// ============================================================================
async function renderFamilyMembers() {
    if (!currentFamily) return;
    const members = await supabaseClient.getFamilyMembers(currentFamily.id);
    const list = document.getElementById('family-members-list');
    list.innerHTML = '';

    members.forEach(m => {
        const row = document.createElement('div');
        row.className = 'usage-app-row';
        row.innerHTML = `
            <div class="usage-app-left">
                <div class="usage-app-icon">${m.avatar_url || (m.role === 'parent' ? '👑' : '🧒')}</div>
                <div>
                    <div class="usage-app-name">${escapeHtml(m.name)}</div>
                    <div style="font-size: 11px; color: var(--text-muted);">${m.role === 'parent' ? 'Ota-ona' : 'Farzand'} • ${m.total_points || 0} ball</div>
                </div>
            </div>
            <div class="card-badge" style="background: rgba(106, 181, 71, 0.15); color: var(--accent-green);">
                Vibe: ${m.current_vibe_score || 75}%
            </div>
        `;
        list.appendChild(row);
    });
}

async function renderAppLimits() {
    const list = document.getElementById('app-limits-list');
    list.innerHTML = '';

    let installed = [];
    if (window.WabiBridge) {
        try {
            installed = JSON.parse(window.WabiBridge.getInstalledApps() || '[]');
        } catch (ignored) {}
    }

    if (installed.length === 0) {
        // Default target apps for smart discipline
        installed = [
            { packageName: 'com.instagram.android', appName: 'Instagram' },
            { packageName: 'com.zhiliaoapp.musically', appName: 'TikTok' },
            { packageName: 'com.google.android.youtube', appName: 'YouTube' },
            { packageName: 'org.telegram.messenger', appName: 'Telegram' },
            { packageName: 'com.dts.freefireth', appName: 'Free Fire' }
        ];
    }

    const limits = currentFamily ? await supabaseClient.getAppLimits(currentFamily.id, currentProfile ? currentProfile.id : null) : [];

    installed.slice(0, 6).forEach(app => {
        const saved = limits.find(l => l.package_name === app.packageName);
        const isLocked = saved ? saved.is_locked : false;
        const maxMinutes = saved ? saved.max_minutes_per_day : 30;

        const row = document.createElement('div');
        row.className = 'usage-app-row';
        row.innerHTML = `
            <div class="usage-app-left">
                <div class="usage-app-icon">🛡️</div>
                <div>
                    <div class="usage-app-name">${escapeHtml(app.appName)}</div>
                    <div style="font-size: 11px; color: var(--text-muted);">${escapeHtml(app.packageName)}</div>
                </div>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
                <span style="font-size: 12px; color: var(--gold); font-weight: 700;">${maxMinutes}m</span>
                <button class="btn-verify" style="background: ${isLocked ? 'var(--accent-red)' : 'rgba(255,255,255,0.08)'}; color: #FFF;" onclick="toggleLock('${app.packageName}', '${escapeHtml(app.appName)}', ${!isLocked}, ${maxMinutes})">
                    ${isLocked ? 'Qulflangan 🔒' : 'Qulflash 🔓'}
                </button>
            </div>
        `;
        list.appendChild(row);
    });
}

async function toggleLock(pkg, appName, newLocked, maxMinutes) {
    if (!currentFamily || !currentProfile) return;
    await supabaseClient.saveAppLimit(currentFamily.id, currentProfile.id, pkg, appName, maxMinutes, newLocked);
    if (window.WabiBridge) window.WabiBridge.triggerHaptic(2);
    renderAppLimits();
}

// ============================================================================
// TAB NAVIGATION
// ============================================================================
function switchTab(tabName) {
    document.querySelectorAll('.view-container').forEach(v => v.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));

    const view = document.getElementById(`view-${tabName}`);
    const nav = document.getElementById(`nav-${tabName}`);
    if (view) view.classList.add('active');
    if (nav) nav.classList.add('active');

    if (window.WabiBridge) window.WabiBridge.triggerHaptic(1);

    if (tabName === 'vibe' && furryVibe) {
        setTimeout(() => furryVibe.resize(), 50);
    }
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
