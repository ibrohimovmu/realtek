/**
 * WABI FAMILY SYNC & DISCIPLINE CONTROLLER
 * - 6-Digit Family Room Management (Parent vs Kid).
 * - Real 10-Minute Instagram / App Limiter & Hard Accessibility Enforcer.
 * - Aladhan Namangan Prayer Times & Native Android AlarmClock Scheduler.
 */

class FamilySync {
    constructor() {
        this.STORAGE_KEYS = {
            FAMILY: 'wabi_family_data',
            PROFILE: 'wabi_profile_data',
            LIMITS: 'wabi_app_limits',
            PRAYERS: 'wabi_prayer_timings'
        };

        this.family = this.getStored(this.STORAGE_KEYS.FAMILY);
        this.profile = this.getStored(this.STORAGE_KEYS.PROFILE);

        this.initBackgroundUsageWatcher();
    }

    getStored(key) {
        try { return JSON.parse(localStorage.getItem(key)); } catch (e) { return null; }
    }

    setStored(key, val) {
        localStorage.setItem(key, JSON.stringify(val));
    }

    // ========================================================================
    // 1. FAMILY CREATION & JOINING (6-DIGIT CODE)
    // ========================================================================
    createFamilyRoom(parentName, familyName = 'Bizning Oila') {
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        this.family = {
            id: 'fam_' + Date.now(),
            code: code,
            name: familyName,
            createdAt: new Date().toISOString()
        };
        this.profile = {
            id: 'usr_' + Date.now(),
            name: parentName || 'Ota-ona',
            role: 'parent',
            avatar: '👑',
            points: 0
        };

        this.setStored(this.STORAGE_KEYS.FAMILY, this.family);
        this.setStored(this.STORAGE_KEYS.PROFILE, this.profile);
        return { family: this.family, profile: this.profile };
    }

    joinFamilyRoom(kidName, code, age = 14) {
        this.family = {
            id: 'fam_' + code,
            code: code,
            name: 'Oila ' + code,
            joinedAt: new Date().toISOString()
        };
        this.profile = {
            id: 'usr_' + Date.now(),
            name: kidName || 'Farzand',
            role: 'kid',
            avatar: '🧒',
            age: age,
            points: 0
        };

        this.setStored(this.STORAGE_KEYS.FAMILY, this.family);
        this.setStored(this.STORAGE_KEYS.PROFILE, this.profile);
        return { family: this.family, profile: this.profile };
    }

    // ========================================================================
    // 2. INSTAGRAM & APP USAGE WATCHER (10-MINUTE RULE)
    // ========================================================================
    initBackgroundUsageWatcher() {
        // Periodic inspection every 5 seconds
        setInterval(() => {
            this.checkAndEnforceAppLimits();
        }, 5000);
    }

    checkAndEnforceAppLimits() {
        if (!window.AndroidNative) return;

        try {
            const usageJson = window.AndroidNative.getUsageStatsJson();
            const stats = JSON.parse(usageJson || '[]');

            // Default limits
            const limits = this.getStored(this.STORAGE_KEYS.LIMITS) || {
                "com.instagram.android": 10, // 10-Minute Rule
                "com.zhiliaoapp.musically": 10,
                "com.google.android.youtube": 20
            };

            stats.forEach(item => {
                const pkg = item.packageName;
                const limit = limits[pkg];
                if (limit !== undefined) {
                    if (item.usedMinutes >= limit) {
                        // Hard lock enforcement via Native Accessibility
                        window.AndroidNative.setAppLimit(pkg, limit);
                    }
                }
            });
        } catch (e) {}
    }

    setAppLimit(pkg, minutes) {
        const limits = this.getStored(this.STORAGE_KEYS.LIMITS) || {};
        limits[pkg] = minutes;
        this.setStored(this.STORAGE_KEYS.LIMITS, limits);

        if (window.AndroidNative) {
            window.AndroidNative.setAppLimit(pkg, minutes);
        }
    }

    // ========================================================================
    // 3. NAMANGAN PRAYER TIMES & SYSTEM ALARM SCHEDULER
    // ========================================================================
    async fetchAndSetNamanganPrayerAlarms() {
        try {
            const res = await fetch('https://api.aladhan.com/v1/timingsByCity?city=Namangan&country=Uzbekistan&method=2');
            const json = await res.json();

            if (json && json.data && json.data.timings) {
                const t = json.data.timings;
                const formatted = {
                    Fajr: t.Fajr,
                    Dhuhr: t.Dhuhr,
                    Asr: t.Asr,
                    Maghrib: t.Maghrib,
                    Isha: t.Isha
                };

                this.setStored(this.STORAGE_KEYS.PRAYERS, formatted);

                if (window.AndroidNative) {
                    window.AndroidNative.setPrayerAlarmsJson(JSON.stringify(formatted));
                }

                return formatted;
            }
        } catch (e) {
            console.warn('[Wabi] Prayer fetch fallback:', e);
        }

        const fallback = {
            Fajr: "05:15",
            Dhuhr: "12:20",
            Asr: "15:45",
            Maghrib: "17:35",
            Isha: "19:05"
        };
        this.setStored(this.STORAGE_KEYS.PRAYERS, fallback);
        return fallback;
    }
}

window.FamilySync = FamilySync;
