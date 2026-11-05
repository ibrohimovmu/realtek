import 'package:flutter/material.dart';
import '../services/store.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (_, __) {
        final s = Store.i;

        Widget stat(IconData i, String k, String v) => Expanded(
              child: card(
                Column(
                  children: [
                    Icon(i, color: kPurple, size: 22),
                    const SizedBox(height: 6),
                    Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(k, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                pad: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              ),
            );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: kBg,
            elevation: 0,
            title: const Text('Operator Profili', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _openSettings(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Avatar & Name Card
              card(
                Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: kPurple,
                      child: Text(
                        s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(s.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: tierColor(tierOf(s.xp)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tierColor(tierOf(s.xp))),
                      ),
                      child: Text(
                        '${tierOf(s.xp)} • LVL ${levelOf(s.xp)}',
                        style: TextStyle(
                          color: tierColor(tierOf(s.xp)),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Daily Streak Box ("5 days straight" style)
              _buildDailyStreakCard(context, s),
              const SizedBox(height: 12),

              // Combat Stats Grid
              Row(
                children: [
                  stat(Icons.bolt, 'Tajriba (XP)', '${s.xp}'),
                  const SizedBox(width: 8),
                  stat(Icons.gps_fixed, 'Qatl (Kills)', '${s.kills}'),
                  const SizedBox(width: 8),
                  stat(Icons.monetization_on, 'Tangalar', '${s.coins}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  stat(Icons.shield, 'Kevlar Zirh', '${s.armor}%'),
                  const SizedBox(width: 8),
                  stat(Icons.medical_services, 'Aptechka', '${s.medkits}'),
                  const SizedBox(width: 8),
                  stat(Icons.healing, 'Bog\'lam', '${s.bandages}'),
                ],
              ),
              const SizedBox(height: 16),

              // Achievements & Badges
              const Text('Harbiy Nishonlar (Badges)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildBadgesSection(s),
              const SizedBox(height: 20),

              // Actions
              OutlinedButton.icon(
                onPressed: () => _rename(context),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Taxallusni O\'zgartirish'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.delete_forever, size: 18, color: kRed),
                label: const Text('Taraqqiyotni Qayta Tiklash (Reset)', style: TextStyle(color: kRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kRed),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyStreakCard(BuildContext context, Store s) {
    final canClaim = s.canClaimDaily();
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: kOrange, size: 24),
              const SizedBox(width: 8),
              Text(
                '${s.dailyStreak} Kunlik Qatnov (Streak)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (canClaim)
                FilledButton(
                  onPressed: () {
                    final res = s.claimDaily();
                    if (res != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('+${res['coins']} coin va +${res['xp']} XP olindi!')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(80, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Olish'),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Ertaga ochiq', style: TextStyle(fontSize: 11, color: Colors.white60)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 7-day streak boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (idx) {
              final day = idx + 1;
              final isDone = day <= s.dailyStreak;
              return Container(
                width: 38,
                height: 48,
                decoration: BoxDecoration(
                  color: isDone ? kOrange.withValues(alpha: 0.2) : Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDone ? kOrange : Colors.white12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: TextStyle(fontWeight: FontWeight.bold, color: isDone ? kOrange : Colors.white60)),
                    Icon(
                      isDone ? Icons.check_circle : Icons.lock,
                      size: 14,
                      color: isDone ? kOrange : Colors.white38,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(Store s) {
    final allBadges = [
      {'id': 'first_blood', 'name': 'Birinchi Qon', 'desc': '1 ta dushmanni yo\'q qilish', 'icon': Icons.flash_on},
      {'id': 'marksman', 'name': 'Mergon', 'desc': '10 ta dushman', 'icon': Icons.gps_fixed},
      {'id': 'reaper', 'name': 'O\'lim Farishtasi', 'desc': '50 ta dushman', 'icon': Icons.warning},
      {'id': 'silver_rank', 'name': 'Silver Jangchi', 'desc': '500 XP to\'plash', 'icon': Icons.military_tech},
      {'id': 'gold_rank', 'name': 'Gold Veteran', 'desc': '1500 XP to\'plash', 'icon': Icons.emoji_events},
      {'id': 'armorer', 'name': 'Arsenal Ustasi', 'desc': 'Kamida 3 ta qurolga ega bo\'lish', 'icon': Icons.inventory_2},
      {'id': 'dedicated', 'name': 'Sodiq Jangchi', 'desc': '5 kun ketma-ket kirish', 'icon': Icons.local_fire_department},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allBadges.map((b) {
        final unlocked = s.badges.contains(b['id']);
        return Container(
          width: 165,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: unlocked ? kPurple.withValues(alpha: 0.15) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: unlocked ? kPurple : Colors.white10),
          ),
          child: Row(
            children: [
              Icon(b['icon'] as IconData, color: unlocked ? kPurple : Colors.white30, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: unlocked ? Colors.white : Colors.white38,
                      ),
                    ),
                    Text(
                      b['desc'] as String,
                      style: const TextStyle(fontSize: 9, color: Colors.white54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _rename(BuildContext context) {
    final c = TextEditingController(text: Store.i.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Taxallusni yangilash'),
        content: TextField(
          controller: c,
          maxLength: 16,
          decoration: const InputDecoration(hintText: 'Yangi taxallus'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                Store.i.setName(c.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Taraqqiyotni o\'chirish?'),
        content: const Text('Barcha qurollar, tangalar, daraja va statistika qayta nollanadi. Bunga aminmisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () {
              Store.i.resetProgress();
              Navigator.pop(context);
            },
            child: const Text('Ha, hammasini tozalash'),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final s = Store.i;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('O\'yin Sozlamalari', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kPurple,
                  title: const Text('Ovoz effektlari (Audio)'),
                  subtitle: const Text('Qurollar ovozi va nishonga tegish signallari'),
                  value: s.soundEnabled,
                  onChanged: (v) {
                    s.setSettings(sound: v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kPurple,
                  title: const Text('Vibratsiya & Haptics'),
                  subtitle: const Text('O\'q otish va zarba tebranishi'),
                  value: s.vibrationEnabled,
                  onChanged: (v) {
                    s.setSettings(vibration: v);
                    setModalState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: kPurple,
                  title: const Text('FPS & Aniqlash Ko\'rsatkichi (Debug)'),
                  subtitle: const Text('Ekranda kamera tezligi va ML kechikishini ko\'rsatish'),
                  value: s.debugOverlayEnabled,
                  onChanged: (v) {
                    s.toggleDebugOverlay();
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Text('Nishon sezuvchanligi: ${(s.sensitivity * 100).round()}%'),
                Slider(
                  activeColor: kPurple,
                  value: s.sensitivity,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  onChanged: (v) {
                    s.setSettings(sens: v);
                    setModalState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
