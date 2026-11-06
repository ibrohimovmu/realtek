import 'package:flutter/material.dart';
import '../data/weapons.dart';
import '../services/store.dart';
import '../theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Widget _buildStatBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    void msg(String t) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: kCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

    return ListenableBuilder(
      listenable: s,
      builder: (_, __) => Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          elevation: 0,
          title: const Text('Do\'kon & Arsenal', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kOrange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: kOrange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${s.coins}',
                        style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Consumables Row
            Row(
              children: [
                Expanded(
                  child: _buildItemCard(
                    Icons.medical_services,
                    kGreen,
                    'Aptechka',
                    '50 🪙 • sizda ${s.medkits}',
                    '+60 HP to\'liq davolaydi',
                    'Olish',
                    () => msg(s.buyMedkit() ? 'Aptechka xarid qilindi (+1)' : 'Coin yetarli emas'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildItemCard(
                    Icons.healing,
                    kCyan,
                    'Bog\'lam',
                    '25 🪙 • sizda ${s.bandages}',
                    '+25 HP tezkor davolash',
                    'Olish',
                    () => msg(s.buyBandage() ? 'Bog\'lam xarid qilindi (+1)' : 'Coin yetarli emas'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Armor & Crate
            Row(
              children: [
                Expanded(
                  child: _buildItemCard(
                    Icons.shield,
                    Colors.purpleAccent,
                    'Kevlar Zirh',
                    '80 🪙 • ${s.armor}%',
                    'Zararni 60% yutadi',
                    'Zirh olish',
                    () => msg(s.buyArmor() ? '100% Kevlar Zirh o\'rnatildi' : 'Coin yetarli emas'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildItemCard(
                    Icons.inventory_2,
                    Colors.amber,
                    'Sovg\'a qutisi',
                    '200 🪙',
                    'Kamyob qurollar & loot',
                    'Ochish',
                    () {
                      if (s.coins < 200) {
                        msg('Coin yetarli emas');
                        return;
                      }
                      s.coins -= 200;
                      final res = s.openCrate();
                      msg('Sovg\'a: ${res['text']}');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Taktik Qurollar Arsenali',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Weapons List with Stats
            for (final w in kWeapons) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: w.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: w.color.withValues(alpha: 0.3)),
                            ),
                            child: Icon(w.icon, color: w.color, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: w.rarity.color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        w.rarity.label,
                                        style: TextStyle(color: w.rarity.color, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'DMG ${w.dmg} • Mag ${w.mag} • ${w.fireMode.label} • ${w.range.toInt()}m',
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (s.equipped == w.id)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: kPurple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kPurple),
                              ),
                              child: const Text('FAOL', style: TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 11)),
                            )
                          else if (s.owned.contains(w.id))
                            FilledButton(
                              onPressed: () => s.equip(w.id),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(80, 38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Tanlash'),
                            )
                          else
                            FilledButton(
                              onPressed: () => msg(s.buy(w) ? '${w.name} sotib olindi!' : 'Coin yetarli emas'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(85, 38),
                                backgroundColor: kOrange,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('${w.price} 🪙', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Weapon Stat Comparison Bars
                      _buildStatBar('Zarar (DMG)', w.dmg / 120.0, kRed),
                      _buildStatBar('Masofa (Range)', w.range / 200.0, kCyan),
                      _buildStatBar('O\'q Sig\'imi', w.mag / 40.0, Colors.amber),
                      _buildStatBar('Barqarorlik', (1.0 - (w.recoil / 30.0)).clamp(0.0, 1.0), kGreen),
                    ],
                  ),
                  border: s.equipped == w.id ? kPurple : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    IconData icon,
    Color color,
    String title,
    String priceSub,
    String desc,
    String btnText,
    VoidCallback onTap,
  ) {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(priceSub, style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(btnText),
          ),
        ],
      ),
    );
  }
}
