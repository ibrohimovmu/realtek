import 'package:flutter/material.dart';
import '../services/store.dart';
import '../theme.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (_, __) {
          final s = Store.i;

          Widget buildMissionCard(
            IconData icon,
            Color color,
            String title,
            String reward,
            int current,
            int goal,
          ) {
            final isCompleted = current >= goal;
            final progress = (current / goal).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card(
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Text(
                                reward,
                                style: const TextStyle(
                                  color: kOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              color: isCompleted ? kGreen : kPurple,
                              backgroundColor: Colors.white12,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? kGreen.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${current.clamp(0, goal)}/$goal',
                        style: TextStyle(
                          color: isCompleted ? kGreen : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Scaffold(
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
                    Tab(text: 'Faxriy Unvonlar'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      buildMissionCard(Icons.gps_fixed, kRed, '10 ta dushmanni yo\'q qil', '+150 Coin', s.kills, 10),
                      buildMissionCard(Icons.bolt, Colors.amber, '100 XP to\'pla', '+100 Coin', s.xp, 100),
                      buildMissionCard(Icons.local_fire_department, kOrange, '50 ta dushmanni mag\'lub et', '+500 Coin', s.kills, 50),
                      buildMissionCard(Icons.storefront, Colors.cyan, 'Kamida 2 ta qurol och', '+200 Coin', s.owned.length, 2),
                      buildMissionCard(Icons.shield, Colors.purpleAccent, '100% Zirh sotib ol', '+80 Coin', s.armor >= 100 ? 1 : 0, 1),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      buildMissionCard(Icons.emoji_events, Colors.amber, 'Bronza Jangchi: 500 XP', 'Silver unvoni', s.xp, 500),
                      buildMissionCard(Icons.military_tech, Colors.purpleAccent, 'Oltin Elita: 1500 XP', 'Gold unvoni', s.xp, 1500),
                      buildMissionCard(Icons.military_tech, kCyan, 'Olmos Mergan: 3500 XP', 'Diamond unvoni', s.xp, 3500),
                      buildMissionCard(Icons.shield, kGreen, 'Haqiqiy Veteran: 100 dushman', 'Master Medali', s.kills, 100),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
}
