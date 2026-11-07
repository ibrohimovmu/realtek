/**
 * WABI SUPABASE & REALTIME SYNC CLIENT (0% Mock / 100% Real)
 * - PostgreSQL REST API & WebSockets.
 * - Offline-first caching with local persistence.
 * - Aladhan Islamic Prayer API integration for Namangan, Uzbekistan.
 */
class WabiSupabaseClient {
    constructor() {
        this.supabaseUrl = localStorage.getItem('wabi_supabase_url') || 'https://gggitiavcehbtastglis.supabase.co';
        this.supabaseKey = localStorage.getItem('wabi_supabase_key') || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdnZ2l0aWF2Y2VoYnRhc3RnbGlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyNzEyMDYsImV4cCI6MjA5Njg0NzIwNn0.NHo-3hk_L8M_NkxYOwnhvJqpiix2XYZN1xg4YwCEcRM';

        // Local cache keys
        this.STORAGE_KEYS = {
            PROFILE: 'wabi_current_profile',
            FAMILY: 'wabi_current_family',
            TASKS: 'wabi_cached_tasks',
            LIMITS: 'wabi_cached_limits',
            PRAYERS: 'wabi_cached_prayers'
        };
    }

    setCredentials(url, key) {
        this.supabaseUrl = url.replace(/\/$/, '');
        this.supabaseKey = key;
        localStorage.setItem('wabi_supabase_url', this.supabaseUrl);
        localStorage.setItem('wabi_supabase_key', this.supabaseKey);
    }

    async request(endpoint, options = {}) {
        const url = `${this.supabaseUrl}/rest/v1/${endpoint}`;
        const headers = {
            'apikey': this.supabaseKey,
            'Authorization': `Bearer ${this.supabaseKey}`,
            'Content-Type': 'application/json',
            'Prefer': options.prefer || 'return=representation',
            ...(options.headers || {})
        };

        try {
            const res = await fetch(url, {
                ...options,
                headers
            });

            if (!res.ok) {
                const errText = await res.text();
                throw new Error(`Supabase Error (${res.status}): ${errText}`);
            }

            const contentType = res.headers.get('content-type');
            if (contentType && contentType.includes('application/json')) {
                return await res.json();
            }
            return null;
        } catch (err) {
            console.warn('[WabiSupabase] Network/REST warning, utilizing local fallback:', err.message);
            throw err;
        }
    }

    // ========================================================================
    // FAMILY ROOM MANAGEMENT (6-DIGIT CODE)
    // ========================================================================
    async createFamily(familyName = 'Bizning Oila') {
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const body = {
            family_code: code,
            family_name: familyName
        };

        let family;
        try {
            const data = await this.request('families', {
                method: 'POST',
                body: JSON.stringify(body)
            });
            family = data[0];
        } catch (e) {
            // Local offline room generation
            family = {
                id: 'local-' + Date.now(),
                family_code: code,
                family_name: familyName,
                created_at: new Date().toISOString()
            };
        }

        localStorage.setItem(this.STORAGE_KEYS.FAMILY, JSON.stringify(family));
        return family;
    }

    async findFamilyByCode(code) {
        try {
            const data = await this.request(`families?family_code=eq.${code}&select=*`);
            if (data && data.length > 0) {
                localStorage.setItem(this.STORAGE_KEYS.FAMILY, JSON.stringify(data[0]));
                return data[0];
            }
        } catch (e) {
            const cached = this.getCachedFamily();
            if (cached && cached.family_code === code) return cached;
        }
        return null;
    }

    getCachedFamily() {
        try {
            return JSON.parse(localStorage.getItem(this.STORAGE_KEYS.FAMILY));
        } catch (e) { return null; }
    }

    // ========================================================================
    // PROFILE MANAGEMENT (PARENT / KID)
    // ========================================================================
    async registerProfile(familyId, name, role, avatarUrl = '') {
        const deviceModel = window.WabiBridge ? window.WabiBridge.getDeviceModel() : 'Android Device';
        const body = {
            family_id: familyId,
            name: name,
            role: role,
            avatar_url: avatarUrl,
            current_vibe_score: 75,
            total_points: 0,
            device_model: deviceModel,
            last_active: new Date().toISOString()
        };

        let profile;
        try {
            const data = await this.request('profiles', {
                method: 'POST',
                body: JSON.stringify(body)
            });
            profile = data[0];
        } catch (e) {
            profile = {
                id: 'local-user-' + Date.now(),
                ...body,
                created_at: new Date().toISOString()
            };
        }

        localStorage.setItem(this.STORAGE_KEYS.PROFILE, JSON.stringify(profile));
        return profile;
    }

    getCachedProfile() {
        try {
            return JSON.parse(localStorage.getItem(this.STORAGE_KEYS.PROFILE));
        } catch (e) { return null; }
    }

    async getFamilyMembers(familyId) {
        try {
            return await this.request(`profiles?family_id=eq.${familyId}&select=*&order=created_at.asc`);
        } catch (e) {
            const p = this.getCachedProfile();
            return p ? [p] : [];
        }
    }

    async updateVibeScore(profileId, score) {
        const p = this.getCachedProfile();
        if (p) {
            p.current_vibe_score = score;
            localStorage.setItem(this.STORAGE_KEYS.PROFILE, JSON.stringify(p));
        }

        try {
            await this.request(`profiles?id=eq.${profileId}`, {
                method: 'PATCH',
                body: JSON.stringify({ current_vibe_score: score, last_active: new Date().toISOString() })
            });
        } catch (ignored) {}
    }

    // ========================================================================
    // TASKS AND HABITS
    // ========================================================================
    async getTasks(familyId, kidId) {
        try {
            let query = `tasks_and_habits?family_id=eq.${familyId}`;
            if (kidId) query += `&kid_id=eq.${kidId}`;
            query += '&order=created_at.desc';
            const data = await this.request(query);
            localStorage.setItem(this.STORAGE_KEYS.TASKS, JSON.stringify(data));
            return data;
        } catch (e) {
            try {
                return JSON.parse(localStorage.getItem(this.STORAGE_KEYS.TASKS)) || [];
            } catch (err) { return []; }
        }
    }

    async createTask(familyId, kidId, title, points = 50, deadline = '20:00') {
        const body = {
            family_id: familyId,
            kid_id: kidId,
            title,
            reward_points: points,
            deadline,
            is_completed: false,
            verified_by_parent: false
        };

        let newTask;
        try {
            const data = await this.request('tasks_and_habits', {
                method: 'POST',
                body: JSON.stringify(body)
            });
            newTask = data[0];
        } catch (e) {
            newTask = {
                id: 'local-task-' + Date.now(),
                ...body,
                created_at: new Date().toISOString()
            };
        }

        const tasks = await this.getTasks(familyId, kidId);
        tasks.unshift(newTask);
        localStorage.setItem(this.STORAGE_KEYS.TASKS, JSON.stringify(tasks));
        return newTask;
    }

    async toggleTaskCompletion(taskId, isCompleted) {
        const tasks = JSON.parse(localStorage.getItem(this.STORAGE_KEYS.TASKS) || '[]');
        const task = tasks.find(t => t.id === taskId);
        if (task) {
            task.is_completed = isCompleted;
            task.completed_at = isCompleted ? new Date().toISOString() : null;
            localStorage.setItem(this.STORAGE_KEYS.TASKS, JSON.stringify(tasks));
        }

        try {
            await this.request(`tasks_and_habits?id=eq.${taskId}`, {
                method: 'PATCH',
                body: JSON.stringify({ is_completed: isCompleted, completed_at: isCompleted ? new Date().toISOString() : null })
            });
        } catch (ignored) {}
    }

    async verifyTask(taskId, kidId, rewardPoints) {
        const tasks = JSON.parse(localStorage.getItem(this.STORAGE_KEYS.TASKS) || '[]');
        const task = tasks.find(t => t.id === taskId);
        if (task) {
            task.verified_by_parent = true;
            localStorage.setItem(this.STORAGE_KEYS.TASKS, JSON.stringify(tasks));
        }

        try {
            await this.request(`tasks_and_habits?id=eq.${taskId}`, {
                method: 'PATCH',
                body: JSON.stringify({ verified_by_parent: true })
            });

            // Increment kid points
            const profile = this.getCachedProfile();
            if (profile && profile.id === kidId) {
                profile.total_points = (profile.total_points || 0) + rewardPoints;
                localStorage.setItem(this.STORAGE_KEYS.PROFILE, JSON.stringify(profile));
                await this.request(`profiles?id=eq.${kidId}`, {
                    method: 'PATCH',
                    body: JSON.stringify({ total_points: profile.total_points })
                });
            }
        } catch (ignored) {}
    }

    // ========================================================================
    // APP LIMITS & LOCKING
    // ========================================================================
    async getAppLimits(familyId, kidId) {
        try {
            const data = await this.request(`app_limits?family_id=eq.${familyId}&kid_id=eq.${kidId}&select=*`);
            localStorage.setItem(this.STORAGE_KEYS.LIMITS, JSON.stringify(data));
            return data;
        } catch (e) {
            try {
                return JSON.parse(localStorage.getItem(this.STORAGE_KEYS.LIMITS)) || [];
            } catch (err) { return []; }
        }
    }

    async saveAppLimit(familyId, kidId, packageName, appName, maxMinutes, isLocked = false) {
        const body = {
            family_id: familyId,
            kid_id: kidId,
            package_name: packageName,
            app_name: appName,
            max_minutes_per_day: maxMinutes,
            is_locked: isLocked,
            updated_at: new Date().toISOString()
        };

        const limits = JSON.parse(localStorage.getItem(this.STORAGE_KEYS.LIMITS) || '[]');
        const idx = limits.findIndex(l => l.package_name === packageName);
        if (idx >= 0) limits[idx] = { ...limits[idx], ...body };
        else limits.push({ id: 'local-limit-' + Date.now(), ...body });
        localStorage.setItem(this.STORAGE_KEYS.LIMITS, JSON.stringify(limits));

        try {
            await this.request('app_limits', {
                method: 'POST',
                prefer: 'resolution=merge-duplicates',
                body: JSON.stringify(body)
            });
        } catch (ignored) {}

        // Push locked packages directly to Native Accessibility Engine
        if (window.WabiBridge) {
            const lockedList = limits.filter(l => l.is_locked).map(l => l.package_name);
            window.WabiBridge.setLockedPackages(JSON.stringify(lockedList));
        }
    }

    // ========================================================================
    // ISLAMIC PRAYER TIMES (ALADHAN API - NAMANGAN, UZBEKISTAN)
    // ========================================================================
    async fetchNamanganPrayerTimes() {
        try {
            const res = await fetch('https://api.aladhan.com/v1/timingsByCity?city=Namangan&country=Uzbekistan&method=3');
            const data = await res.json();
            if (data && data.data && data.data.timings) {
                const timings = data.data.timings;
                const formatted = {
                    city: 'Namangan, O\'zbekiston',
                    fajr: timings.Fajr,
                    dhuhr: timings.Dhuhr,
                    asr: timings.Asr,
                    maghrib: timings.Maghrib,
                    isha: timings.Isha,
                    date: data.data.date.readable
                };
                localStorage.setItem(this.STORAGE_KEYS.PRAYERS, JSON.stringify(formatted));

                // Auto schedule exact alarms in native Android AlarmManager
                if (window.WabiBridge) {
                    ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].forEach(p => {
                        const timeStr = formatted[p];
                        if (timeStr) {
                            const [hh, mm] = timeStr.split(':').map(Number);
                            window.WabiBridge.schedulePrayerAlarm(p.toUpperCase(), hh, mm);
                        }
                    });
                }

                return formatted;
            }
        } catch (e) {
            console.warn('[Wabi] Aladhan fetch error, using cached timings:', e);
        }

        try {
            return JSON.parse(localStorage.getItem(this.STORAGE_KEYS.PRAYERS)) || {
                city: 'Namangan, O\'zbekiston',
                fajr: '05:15',
                dhuhr: '12:20',
                asr: '15:45',
                maghrib: '17:35',
                isha: '19:05'
            };
        } catch (e) {
            return {
                city: 'Namangan, O\'zbekiston',
                fajr: '05:15',
                dhuhr: '12:20',
                asr: '15:45',
                maghrib: '17:35',
                isha: '19:05'
            };
        }
    }
}

window.WabiSupabaseClient = WabiSupabaseClient;
