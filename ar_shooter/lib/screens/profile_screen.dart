import 'dart:math';
import 'package:flutter/material.dart';
import '../data/achievements.dart';
import '../services/store.dart';
import '../theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Store.i.rankUpNotifier.addListener(_onRankUp);
  }

  @override
  void dispose() {
    Store.i.rankUpNotifier.removeListener(_onRankUp);
    super.dispose();
  }

  void _onRankUp() {
    final newTier = Store.i.rankUpNotifier.value;
    if (newTier != null && mounted) {
      _showRankCelebration(newTier);
    }
  }

  void _showRankCelebration(String tier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tierColor(tier).withValues(alpha: 0.2),
                border: Border.all(color: tierColor(tier), width: 3),
                boxShadow: [
                  BoxShadow(color: tierColor(tier).withValues(alpha: 0.6), blurRadius: 24),
                ],
              ),
              child: Icon(Icons.workspace_premium, size: 48, color: tierColor(tier)),
            ),
            const SizedBox(height: 16),
            const Text(
              'YANGI DARAJA!',
              style: TextStyle(color: kPurple, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              tier,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: tierColor(tier)),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tabriklaymiz, jangovar mahoratingiz yangi bosqichga ko\'tarildi! Barcha jamoadoshlar sizni yangi unvon bilan ko\'rishadi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tierColor(tier),
                foregroundColor: Colors.black,
                minimumSize: const Size(160, 46),
              ),
              onPressed: () {
                Store.i.rankUpNotifier.value = null;
                Navigator.pop(context);
              },
              child: const Text('Qabul Qilish', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _avatarIcon(String av) {
    switch (av) {
      case 'operator_1':
        return Icons.security;
      case 'operator_2':
        return Icons.visibility;
      case 'operator_3':
        return Icons.flash_on;
      case 'operator_4':
        return Icons.radar;
      case 'operator_5':
        return Icons.shield;
      case 'operator_6':
        return Icons.memory;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final currentTier = tierOf(s.xp);
        final color = tierColor(currentTier);

        int nextThreshold = 500;
        int prevThreshold = 0;
        if (s.xp < 500) {
          prevThreshold = 0;
          nextThreshold = 500;
        } else if (s.xp < 1500) {
          prevThreshold = 500;
          nextThreshold = 1500;
        } else if (s.xp < 3500) {
          prevThreshold = 1500;
          nextThreshold = 3500;
        } else if (s.xp < 6000) {
          prevThreshold = 3500;
          nextThreshold = 6000;
        } else if (s.xp < 10000) {
          prevThreshold = 6000;
          nextThreshold = 10000;
        } else {
          prevThreshold = 10000;
          nextThreshold = 20000;
        }

        final progress = ((s.xp - prevThreshold) / max(1, nextThreshold - prevThreshold)).clamp(0.0, 1.0);

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
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kBg,
            elevation: 0,
            title: const Text('Operator Profili', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Sozlamalar',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
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
                      radius: 42,
                      backgroundColor: kPurple.withValues(alpha: 0.2),
                      child: Icon(_avatarIcon(s.avatar), size: 44, color: kPurple),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.name.isEmpty ? 'Noma\'lum Operator' : s.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            '$currentTier • LVL ${levelOf(s.xp)}',
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.region,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.playStyle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Rank Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Keyingi darajagacha:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text('${s.xp} / $nextThreshold XP', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Daily Streak Card
              _buildDailyStreakCard(context, s),
              const SizedBox(height: 12),

              // Stats Grid
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAchievements.map((ach) {
        final unlocked = s.badges.contains(ach.id);
        return Container(
          width: (MediaQuery.of(context).size.width - 48) / 2,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: unlocked ? ach.color.withValues(alpha: 0.15) : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: unlocked ? ach.color : Colors.white10),
          ),
          child: Row(
            children: [
              Icon(ach.icon, color: unlocked ? ach.color : Colors.white30, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ach.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: unlocked ? Colors.white : Colors.white38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      ach.description,
                      style: const TextStyle(fontSize: 9, color: Colors.white54),
                      maxLines: 2,
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
}
