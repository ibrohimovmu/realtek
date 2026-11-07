/**
 * ============================================================================
 * NOVA — FOCUS GUARDIAN (INSTAGRAM 10-MIN BLOCKER) & 5-MAHAL NAMOZ SCHEDULER
 * ============================================================================
 * 1) Focus Guardian:
 *    - Monitors `com.instagram.android` continuous usage via UsageStatsManager +
 *      NovaAccessibilityService.
 *    - At 10 minutes continuous usage, speaks:
 *      "Bro, Instagramda 10 minutdan beri o'tiribsan, maqsadlardan chalg'ima, yopamiz!"
 *    - Closes Instagram (`GLOBAL_ACTION_HOME` + `su -c am force-stop com.instagram.android`)
 *      and locks Instagram for 30 minutes.
 * 2) 5-Mahal Namoz & Daily Plan Scheduler:
 *    - Fetches daily prayer times from Aladhan API (`city=Namangan&country=Uzbekistan&method=2`
 *      or custom city).
 *    - Automatically sets silent-UI system alarms (`AlarmClock.ACTION_SET_ALARM` with
 *      `EXTRA_SKIP_UI = true`) for Bomdod, Peshin, Asr, Shom, Xufton and user plans.
 * ============================================================================
 */
(function () {
  'use strict';

  const DEFAULT_PRAYER_TIMES = {
    Fajr: '05:12',
    Dhuhr: '12:38',
    Asr: '16:18',
    Maghrib: '18:12',
    Isha: '19:38',
  };

  class NovaFocusAndPrayerScheduler {
    constructor() {
      this.city = 'Namangan';
      this.country = 'Uzbekistan';
      this.prayerTimes = Object.assign({}, DEFAULT_PRAYER_TIMES);
      this.focusGuardEnabled = true;
      this.instagramUsageSec = 0;
      this.instagramLockedUntil = 0;
      this._loadState();
      this._bindNativeEvents();
      this.fetchPrayerTimes(this.city, false);
    }

    _loadState() {
      if (!window.NovaVault) return;
      this.city = window.NovaVault.getKV('prayer_city', 'Namangan') || 'Namangan';
      this.focusGuardEnabled =
        window.NovaVault.getKV('focus_guard_enabled', 'true') !== 'false';
      try {
        const cachedPrayers = JSON.parse(
          window.NovaVault.getKV('prayer_times_json', 'null')
        );
        if (cachedPrayers && cachedPrayers.Fajr) {
          this.prayerTimes = cachedPrayers;
        }
      } catch (e) {}
    }

    _bindNativeEvents() {
      window.addEventListener('nova:native', (ev) => {
        const detail = ev.detail || {};
        const type = detail.type;
        const payload = detail.payload || {};

        if (type === 'focus:instagram_blocked') {
          this.instagramLockedUntil = Number(
            payload.lockedUntil || Date.now() + 30 * 60 * 1000
          );
          const msg =
            payload.message ||
            "Bro, Instagramda 10 minutdan beri o'tiribsan, maqsadlardan chalg'ima, yopamiz!";
          if (window.NovaEvents) {
            window.NovaEvents.emit('focus:blocked', {
              lockedUntil: this.instagramLockedUntil,
              message: msg,
            });
          }
        } else if (type === 'focus:usage_tick') {
          this.instagramUsageSec = Number(payload.continuousSeconds || 0);
          if (window.NovaEvents) {
            window.NovaEvents.emit('focus:tick', {
              continuousSeconds: this.instagramUsageSec,
              limitSeconds: 600,
            });
          }
        }
      });
    }

    setFocusGuardEnabled(enabled) {
      this.focusGuardEnabled = !!enabled;
      if (window.NovaVault) {
        window.NovaVault.setKV(
          'focus_guard_enabled',
          this.focusGuardEnabled ? 'true' : 'false'
        );
      }
      try {
        if (
          window.NovaNative &&
          typeof window.NovaNative.setFocusGuardEnabled === 'function'
        ) {
          window.NovaNative.setFocusGuardEnabled(this.focusGuardEnabled);
        }
      } catch (e) {}
      if (window.NovaEvents) {
        window.NovaEvents.emit('focus:state_changed', this.getState());
      }
    }

    triggerInstagramBlockNow() {
      const msg =
        "Bro, Instagramda 10 minutdan beri o'tiribsan, maqsadlardan chalg'ima, yopamiz!";
      this.instagramLockedUntil = Date.now() + 30 * 60 * 1000;

      try {
        if (
          window.NovaNative &&
          typeof window.NovaNative.triggerInstagramBlockTest === 'function'
        ) {
          window.NovaNative.triggerInstagramBlockTest();
        }
      } catch (e) {}

      if (window.NovaBrain && typeof window.NovaBrain.speak === 'function') {
        window.NovaBrain.speak(msg);
      }

      if (window.NovaEvents) {
        window.NovaEvents.emit('focus:blocked', {
          lockedUntil: this.instagramLockedUntil,
          message: msg,
        });
        window.NovaEvents.emit('focus:state_changed', this.getState());
      }
    }

    async fetchPrayerTimes(city = 'Namangan', autoScheduleAlarms = false) {
      this.city = String(city || 'Namangan').trim();
      if (window.NovaVault) {
        window.NovaVault.setKV('prayer_city', this.city);
      }

      try {
        const url = `https://api.aladhan.com/v1/timingsByCity?city=${encodeURIComponent(
          this.city
        )}&country=Uzbekistan&method=2`;
        const resp = await fetch(url);
        if (resp.ok) {
          const json = await resp.json();
          const timings = (json && json.data && json.data.timings) || null;
          if (timings) {
            this.prayerTimes = {
              Fajr: this._cleanTime(timings.Fajr),
              Dhuhr: this._cleanTime(timings.Dhuhr),
              Asr: this._cleanTime(timings.Asr),
              Maghrib: this._cleanTime(timings.Maghrib),
              Isha: this._cleanTime(timings.Isha),
            };
            if (window.NovaVault) {
              window.NovaVault.setKV(
                'prayer_times_json',
                JSON.stringify(this.prayerTimes)
              );
            }
          }
        }
      } catch (e) {
        // Fallback to cached or default Namangan timings
      }

      if (autoScheduleAlarms) {
        this.syncPrayerAlarmsToSystem();
      }

      if (window.NovaEvents) {
        window.NovaEvents.emit('focus:state_changed', this.getState());
      }
      return this.prayerTimes;
    }

    _cleanTime(raw) {
      return String(raw || '05:00')
        .split(' ')[0]
        .trim();
    }

    /**
     * Automatically sets silent-UI Android system alarms (`EXTRA_SKIP_UI = true`)
     * for all 5 daily prayers (or a specific prayer/plan)
     */
    syncPrayerAlarmsToSystem() {
      const map = [
        { key: 'Fajr', label: 'Bomdod namozi (Nova)' },
        { key: 'Dhuhr', label: 'Peshin namozi (Nova)' },
        { key: 'Asr', label: 'Asr namozi (Nova)' },
        { key: 'Maghrib', label: 'Shom namozi (Nova)' },
        { key: 'Isha', label: 'Xufton namozi (Nova)' },
      ];

      let count = 0;
      map.forEach((item, idx) => {
        const t = this.prayerTimes[item.key] || '05:15';
        const parts = t.split(':');
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        if (!isNaN(h) && !isNaN(m)) {
          setTimeout(() => {
            this.setSystemAlarm(h, m, item.label);
          }, idx * 280);
          count++;
        }
      });
      return count;
    }

    setSystemAlarm(hour, minute, label) {
      const h = Math.max(0, Math.min(23, Number(hour) || 0));
      const m = Math.max(0, Math.min(59, Number(minute) || 0));
      const cleanLabel = String(label || 'Nova Budilnik').trim();

      try {
        if (
          window.NovaNative &&
          typeof window.NovaNative.setSystemAlarm === 'function'
        ) {
          window.NovaNative.setSystemAlarm(h, m, cleanLabel);
        }
      } catch (e) {}

      if (window.NovaVault) {
        const hh = String(h).padStart(2, '0');
        const mm = String(m).padStart(2, '0');
        window.NovaVault.addDailyPlan(
          cleanLabel,
          `${hh}:${mm}`,
          cleanLabel.toLowerCase().includes('namoz') ||
            cleanLabel.toLowerCase().includes('bomdod') ||
            cleanLabel.toLowerCase().includes('peshin') ||
            cleanLabel.toLowerCase().includes('asr') ||
            cleanLabel.toLowerCase().includes('shom') ||
            cleanLabel.toLowerCase().includes('xufton')
        );
      }

      if (window.NovaEvents) {
        window.NovaEvents.emit('focus:state_changed', this.getState());
      }
      return true;
    }

    getState() {
      return {
        city: this.city,
        prayerTimes: this.prayerTimes,
        focusGuardEnabled: this.focusGuardEnabled,
        instagramUsageSec: this.instagramUsageSec,
        instagramLockedUntil: this.instagramLockedUntil,
        plans: window.NovaVault ? window.NovaVault.getDailyPlans() : [],
      };
    }
  }

  window.NovaFocusScheduler = new NovaFocusAndPrayerScheduler();
})();
