import 'package:flutter/material.dart';
import '../services/store.dart';
import '../theme.dart';

class Mission {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int coins;
  final int xp;
  final int Function(Store) current;
  final int goal;

  const Mission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.coins,
    required this.xp,
    required this.current,
    required this.goal,
  });
}

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  static final List<Mission> _dailyMissions = [
    Mission(
      id: 'd_kills_5',
      title: '5 ta dushmanni yo\'q qil',
      subtitle: 'AR krossxeyr orqali aniq nishonga ol',
      icon: Icons.gps_fixed,
      color: kRed,
      coins: 80,
      xp: 40,
      current: (s) => s.kills,
      goal: 5,
    ),
    Mission(
      id: 'd_xp_150',
      title: '150 XP to\'pla',
      subtitle: 'Janglarda qatnashib tajriba oshir',
      icon: Icons.bolt,
      color: Colors.amber,
      coins: 100,
      xp: 50,
      current: (s) => s.xp,
      goal: 150,
    ),
    Mission(
      id: 'd_armor_buy',
      title: 'Kevlar zirh bilan qurollan',
      subtitle: 'Do\'kondan 100% zirh o\'rnat',
      icon: Icons.shield,
      color: Colors.purpleAccent,
      coins: 60,
      xp: 30,
      current: (s) => s.armor >= 100 ? 1 : 0,
      goal: 1,
    ),
    Mission(
      id: 'd_grenades_use',
      title: 'Granata yoki o\'lja ishlat',
      subtitle: 'Maydonda aptechka yoki granata qo\'lla',
      icon: Icons.healing,
      color: kGreen,
      coins: 70,
      xp: 35,
      current: (s) => s.medkits + s.bandages >= 1 ? 1 : 0,
      goal: 1,
    ),
  ];

  static final List<Mission> _weeklyMissions = [
    Mission(
      id: 'w_kills_25',
      title: '25 ta raqibni yeng',
      subtitle: 'Haftalik peshqadamlik janglari',
      icon: Icons.military_tech,
      color: kOrange,
      coins: 300,
      xp: 150,
      current: (s) => s.kills,
      goal: 25,
    ),
    Mission(
      id: 'w_guns_3',
      title: 'Kamida 3 ta qurolga ega bo\'l',
      subtitle: 'Arsenaldan yangi avtomat yoki snayper sotib ol',
      icon: Icons.inventory_2,
      color: kCyan,
      coins: 250,
      xp: 100,
      current: (s) => s.owned.length,
      goal: 3,
    ),
    Mission(
      id: 'w_xp_1000',
      title: '1000 XP to\'plash',
      subtitle: 'Oltin jangchi darajasiga yaqinlash',
      icon: Icons.workspace_premium,
      color: const Color(0xFFFFD700),
      coins: 500,
      xp: 250,
      current: (s) => s.xp,
      goal: 1000,
    ),
  ];

  Widget _buildMissionList(BuildContext context, Store s, List<Mission> list) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final m = list[idx];
        final cur = m.current(s);
        final isGoalReached = cur >= m.goal;
        final isClaimed = s.claimedMissions.contains(m.id);
        final progress = (cur / m.goal).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: m.color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(m.icon, color: m.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.subtitle,
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Reward chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kOrange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on, color: kOrange, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '+${m.coins}',
                            style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress and action button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${cur.clamp(0, m.goal)}/${m.goal}',
                                style: TextStyle(
                                  color: isGoalReached ? kGreen : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              color: isGoalReached ? kGreen : kPurple,
                              backgroundColor: Colors.white12,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (isClaimed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 14, color: kGreen),
                            SizedBox(width: 4),
                            Text('Olingan', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (isGoalReached)
                      FilledButton(
                        onPressed: () {
                          final ok = s.claimMission(m.id, m.coins, m.xp);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Vazifa bajarildi! +${m.coins} tanga va +${m.xp} XP qo\'shildi!'),
                                backgroundColor: kGreen,
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Olish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Bajarilmoqda', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(
              backgroundColor: kBg,
              elevation: 0,
              title: const Text('Jangovar Vazifalar', style: TextStyle(fontWeight: FontWeight.bold)),
              bottom: const TabBar(
                indicatorColor: kPurple,
                indicatorWeight: 3,
                labelColor: kPurple,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(text: 'Kunlik Missiyalar'),
                  Tab(text: 'Haftalik Missiyalar'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildMissionList(context, s, _dailyMissions),
                _buildMissionList(context, s, _weeklyMissions),
              ],
            ),
          ),
        );
      },
    );
  }
}
