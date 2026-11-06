import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/weapons.dart';
import '../theme.dart';
import 'lan.dart';

class Store extends ChangeNotifier {
  static final i = Store._();
  Store._();

  static const int currentSchemaVersion = 3;
  late SharedPreferences _p;

  String name = '';
  String team = 'blue';
  String equipped = 'pistol';
  int xp = 0;
  int coins = 200;
  int kills = 0;
  int deaths = 0;
  int medkits = 1;
  int bandages = 2;
  int grenades = 2;
  int armor = 50; // 0 to 100%
  List<String> owned = ['pistol'];

  // Profile Customization
  String avatar = 'operator_1';
  String region = 'Toshkent';
  String playStyle = 'Hujumkor (Assault)';
  String favoriteWeapon = 'm416';
  String language = 'uz';

  // Settings
  bool soundEnabled = true;
  bool vibrationEnabled = true;
  double sensitivity = 1.0;
  bool safetyAccepted = false;
  bool debugOverlayEnabled = true;
  bool gpsSharingEnabled = true;
  String serverUrl = 'http://localhost:7860';

  // Daily Streak
  int dailyStreak = 1;
  int lastDailyEpoch = 0;

  // Badges / Achievements
  List<String> badges = [];

  // Rank-Up Notification Callback / ValueNotifier
  final ValueNotifier<String?> rankUpNotifier = ValueNotifier<String?>(null);

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();

    // Check schema version migration
    final schema = _p.getInt('schema_version') ?? 1;
    if (schema < currentSchemaVersion) {
      _p.setInt('schema_version', currentSchemaVersion);
    }

    name = _p.getString('name') ?? '';
    team = _p.getString('team') ?? 'blue';
    equipped = _p.getString('eq') ?? 'pistol';
    xp = _p.getInt('xp') ?? 0;
    coins = _p.getInt('coins') ?? 200;
    kills = _p.getInt('kills') ?? 0;
    deaths = _p.getInt('deaths') ?? 0;
    medkits = _p.getInt('med') ?? 1;
    bandages = _p.getInt('bandages') ?? 2;
    grenades = _p.getInt('grenades') ?? 2;
    armor = _p.getInt('armor') ?? 50;
    owned = _p.getStringList('owned') ?? ['pistol'];

    avatar = _p.getString('avatar') ?? 'operator_1';
    region = _p.getString('region') ?? 'Toshkent';
    playStyle = _p.getString('play_style') ?? 'Hujumkor (Assault)';
    favoriteWeapon = _p.getString('fav_weapon') ?? 'm416';
    language = _p.getString('language') ?? 'uz';

    soundEnabled = _p.getBool('sound') ?? true;
    vibrationEnabled = _p.getBool('vibe') ?? true;
    sensitivity = _p.getDouble('sens') ?? 1.0;
    safetyAccepted = _p.getBool('safety_accepted') ?? false;
    debugOverlayEnabled = _p.getBool('debug_overlay') ?? true;
    gpsSharingEnabled = _p.getBool('gps_sharing') ?? true;
    serverUrl = _p.getString('server_url') ?? 'http://localhost:7860';

    dailyStreak = _p.getInt('daily_streak') ?? 1;
    lastDailyEpoch = _p.getInt('last_daily') ?? 0;
    badges = _p.getStringList('badges') ?? [];

    checkBadges();
  }

  void save() {
    _p.setString('name', name);
    _p.setString('team', team);
    _p.setString('eq', equipped);
    _p.setInt('xp', xp);
    _p.setInt('coins', coins);
    _p.setInt('kills', kills);
    _p.setInt('deaths', deaths);
    _p.setInt('med', medkits);
    _p.setInt('bandages', bandages);
    _p.setInt('grenades', grenades);
    _p.setInt('armor', armor);
    _p.setStringList('owned', owned);

    _p.setString('avatar', avatar);
    _p.setString('region', region);
    _p.setString('play_style', playStyle);
    _p.setString('fav_weapon', favoriteWeapon);
    _p.setString('language', language);

    _p.setBool('sound', soundEnabled);
    _p.setBool('vibe', vibrationEnabled);
    _p.setDouble('sens', sensitivity);
    _p.setBool('debug_overlay', debugOverlayEnabled);
    _p.setBool('gps_sharing', gpsSharingEnabled);
    _p.setString('server_url', serverUrl);

    _p.setInt('daily_streak', dailyStreak);
    _p.setInt('last_daily', lastDailyEpoch);
    _p.setStringList('badges', badges);

    notifyListeners();
    Lan.i.push();
  }

  Weapon get weapon => weaponOf(equipped);

  void setName(String n) {
    name = n;
    save();
  }

  void setTeam(String t) {
    team = t;
    save();
  }

  void acceptSafety() {
    safetyAccepted = true;
    _p.setBool('safety_accepted', true);
    notifyListeners();
  }

  void toggleDebugOverlay() {
    debugOverlayEnabled = !debugOverlayEnabled;
    save();
  }

  void addKill() {
    kills++;
    xp += 15;
    coins += 10;
    checkBadges();
    save();
  }

  void addDeath() {
    deaths++;
    save();
  }

  void addCoins(int c) {
    coins += c;
    save();
  }

  void addXp(int x) {
    final oldTier = tierOf(xp);
    xp += x;
    final newTier = tierOf(xp);
    if (oldTier != newTier) {
      rankUpNotifier.value = newTier;
    }
    checkBadges();
    save();
  }

  bool useMedkit() {
    if (medkits <= 0) return false;
    medkits--;
    save();
    return true;
  }

  void addMedkit([int n = 1]) {
    medkits += n;
    save();
  }

  bool buyMedkit() {
    if (coins < 50) return false;
    coins -= 50;
    medkits++;
    save();
    return true;
  }

  bool useBandage() {
    if (bandages <= 0) return false;
    bandages--;
    save();
    return true;
  }

  void addBandages([int n = 1]) {
    bandages += n;
    save();
  }

  bool buyBandage() {
    if (coins < 25) return false;
    coins -= 25;
    bandages++;
    save();
    return true;
  }

  bool buyArmor() {
    if (coins < 80) return false;
    coins -= 80;
    armor = 100;
    save();
    return true;
  }

  /// Reduces damage taking armor into account. Returns remaining damage to HP.
  int absorbDamage(int dmg) {
    if (armor > 0) {
      final absorbed = min(armor, (dmg * 0.6).round());
      armor -= absorbed;
      final remaining = max(1, dmg - absorbed);
      save();
      return remaining;
    }
    return dmg;
  }

  bool useGrenade() {
    if (grenades <= 0) return false;
    grenades--;
    save();
    return true;
  }

  void addGrenades(int count) {
    grenades += count;
    save();
  }

  bool buy(Weapon w) {
    if (owned.contains(w.id) || coins < w.price) return false;
    coins -= w.price;
    owned.add(w.id);
    equipped = w.id;
    checkBadges();
    save();
    return true;
  }

  void equip(String id) {
    equipped = id;
    save();
  }

  /// Sovg'a qutisi: kamyoblik (rarity) hisobga olinadi
  Map<String, dynamic> openCrate() {
    final r = Random();
    final roll = r.nextDouble();

    Rarity rarity;
    if (roll < 0.50) {
      rarity = Rarity.common;
    } else if (roll < 0.80) {
      rarity = Rarity.rare;
    } else if (roll < 0.95) {
      rarity = Rarity.epic;
    } else {
      rarity = Rarity.legendary;
    }

    String rewardDesc;
    final locked = kWeapons.where((w) => !owned.contains(w.id)).toList();

    if (rarity == Rarity.legendary && locked.any((w) => w.rarity == Rarity.legendary)) {
      final w = locked.firstWhere((w) => w.rarity == Rarity.legendary);
      owned.add(w.id);
      equipped = w.id;
      rewardDesc = 'Afsonaviy qurol: ${w.name}!';
    } else if (rarity == Rarity.epic && locked.any((w) => w.rarity == Rarity.epic)) {
      final w = locked.firstWhere((w) => w.rarity == Rarity.epic);
      owned.add(w.id);
      rewardDesc = 'Epik qurol: ${w.name}!';
    } else {
      switch (rarity) {
        case Rarity.common:
          final b = 1 + r.nextInt(2);
          bandages += b;
          final c = 20 + r.nextInt(40);
          coins += c;
          rewardDesc = '+$b bog\'lam, +$c coin';
          break;
        case Rarity.rare:
          final m = 1 + r.nextInt(2);
          medkits += m;
          armor = min(100, armor + 35);
          final c = 50 + r.nextInt(60);
          coins += c;
          rewardDesc = '+$m aptechka, +35% zirh, +$c coin';
          break;
        case Rarity.epic:
          medkits += 2;
          armor = 100;
          final c = 120 + r.nextInt(100);
          coins += c;
          rewardDesc = '+2 aptechka, to\'liq zirh, +$c coin';
          break;
        case Rarity.legendary:
          medkits += 4;
          bandages += 5;
          armor = 100;
          coins += 300;
          rewardDesc = 'AFSONAVIY QUTI: Max zaxira va +300 coin!';
          break;
      }
    }

    checkBadges();
    save();
    return {
      'rarity': rarity,
      'text': rewardDesc,
    };
  }

  // Daily Streak Reward
  bool canClaimDaily() {
    final now = DateTime.now().millisecondsSinceEpoch;
    const cooldown = 24 * 60 * 60 * 1000;
    return (now - lastDailyEpoch) >= cooldown;
  }

  Map<String, dynamic>? claimDaily() {
    if (!canClaimDaily()) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    const twoDays = 48 * 60 * 60 * 1000;

    if (lastDailyEpoch > 0 && (now - lastDailyEpoch) > twoDays) {
      dailyStreak = 1; // Streak reset if missed
    } else {
      dailyStreak = min(7, dailyStreak + 1);
    }

    lastDailyEpoch = now;
    final rewardCoin = 50 * dailyStreak;
    final rewardXp = 25 * dailyStreak;

    coins += rewardCoin;
    xp += rewardXp;
    save();

    return {
      'streak': dailyStreak,
      'coins': rewardCoin,
      'xp': rewardXp,
    };
  }

  void setSettings({bool? sound, bool? vibration, double? sens, String? newName}) {
    if (sound != null) soundEnabled = sound;
    if (vibration != null) vibrationEnabled = vibration;
    if (sens != null) sensitivity = sens;
    if (newName != null && newName.trim().isNotEmpty) name = newName.trim();
    save();
  }

  void checkBadges() {
    bool changed = false;
    void add(String id) {
      if (!badges.contains(id)) {
        badges.add(id);
        changed = true;
      }
    }

    if (kills >= 1) add('first_blood');
    if (kills >= 10) add('marksman');
    if (kills >= 50) add('reaper');
    if (xp >= 500) add('silver_rank');
    if (xp >= 1500) add('gold_rank');
    if (xp >= 3500) add('diamond_rank');
    if (owned.length >= 3) add('armorer');
    if (dailyStreak >= 5) add('dedicated');

    if (changed) save();
  }

  void resetProgress() {
    name = '';
    equipped = 'pistol';
    xp = 0;
    coins = 200;
    kills = 0;
    deaths = 0;
    medkits = 1;
    bandages = 2;
    grenades = 2;
    armor = 50;
    owned = ['pistol'];
    avatar = 'operator_1';
    region = 'Toshkent';
    playStyle = 'Hujumkor (Assault)';
    favoriteWeapon = 'm416';
    dailyStreak = 1;
    lastDailyEpoch = 0;
    badges.clear();
    save();
  }

  /// Exports player progress and settings into a formatted JSON string.
  String exportToJson() {
    final data = {
      'schema_version': currentSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': {
        'name': name,
        'team': team,
        'avatar': avatar,
        'region': region,
        'play_style': playStyle,
        'fav_weapon': favoriteWeapon,
        'language': language,
      },
      'stats': {
        'xp': xp,
        'coins': coins,
        'kills': kills,
        'deaths': deaths,
        'medkits': medkits,
        'bandages': bandages,
        'grenades': grenades,
        'armor': armor,
        'equipped': equipped,
        'owned': owned,
        'daily_streak': dailyStreak,
        'last_daily_epoch': lastDailyEpoch,
        'badges': badges,
      },
      'settings': {
        'sound_enabled': soundEnabled,
        'vibration_enabled': vibrationEnabled,
        'sensitivity': sensitivity,
        'debug_overlay': debugOverlayEnabled,
        'gps_sharing': gpsSharingEnabled,
        'server_url': serverUrl,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Imports player progress and settings from a JSON string.
  /// Returns true if successful, false if JSON is malformed or invalid.
  bool importFromJson(String jsonStr) {
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is! Map<String, dynamic>) return false;

      if (decoded.containsKey('profile') && decoded['profile'] is Map) {
        final p = decoded['profile'] as Map<String, dynamic>;
        name = p['name'] as String? ?? name;
        team = p['team'] as String? ?? team;
        avatar = p['avatar'] as String? ?? avatar;
        region = p['region'] as String? ?? region;
        playStyle = p['play_style'] as String? ?? playStyle;
        favoriteWeapon = p['fav_weapon'] as String? ?? favoriteWeapon;
        language = p['language'] as String? ?? language;
      }

      if (decoded.containsKey('stats') && decoded['stats'] is Map) {
        final s = decoded['stats'] as Map<String, dynamic>;
        xp = (s['xp'] as num?)?.toInt() ?? xp;
        coins = (s['coins'] as num?)?.toInt() ?? coins;
        kills = (s['kills'] as num?)?.toInt() ?? kills;
        deaths = (s['deaths'] as num?)?.toInt() ?? deaths;
        medkits = (s['medkits'] as num?)?.toInt() ?? medkits;
        bandages = (s['bandages'] as num?)?.toInt() ?? bandages;
        grenades = (s['grenades'] as num?)?.toInt() ?? grenades;
        armor = (s['armor'] as num?)?.toInt() ?? armor;
        equipped = s['equipped'] as String? ?? equipped;
        if (s['owned'] is List) {
          owned = List<String>.from(s['owned'] as List);
        }
        dailyStreak = (s['daily_streak'] as num?)?.toInt() ?? dailyStreak;
        lastDailyEpoch = (s['last_daily_epoch'] as num?)?.toInt() ?? lastDailyEpoch;
        if (s['badges'] is List) {
          badges = List<String>.from(s['badges'] as List);
        }
      }

      if (decoded.containsKey('settings') && decoded['settings'] is Map) {
        final set = decoded['settings'] as Map<String, dynamic>;
        soundEnabled = set['sound_enabled'] as bool? ?? soundEnabled;
        vibrationEnabled = set['vibration_enabled'] as bool? ?? vibrationEnabled;
        sensitivity = (set['sensitivity'] as num?)?.toDouble() ?? sensitivity;
        debugOverlayEnabled = set['debug_overlay'] as bool? ?? debugOverlayEnabled;
        gpsSharingEnabled = set['gps_sharing'] as bool? ?? gpsSharingEnabled;
        serverUrl = set['server_url'] as String? ?? serverUrl;
      }

      save();
      return true;
    } catch (_) {
      return false;
    }
  }
}
