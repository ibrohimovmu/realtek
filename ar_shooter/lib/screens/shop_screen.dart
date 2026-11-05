import 'package:flutter/material.dart';
import '../data/weapons.dart';
import '../services/store.dart';
import '../theme.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

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
                    '50 coin • sizda ${s.medkits}',
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
                    'Bog\'lam (Bandage)',
                    '25 coin • sizda ${s.bandages}',
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
                    '80 coin • ${s.armor}%',
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
                    '200 coin',
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

            // Weapons List
            for (final w in kWeapons)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card(
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
                              'DMG ${w.dmg} • Mag ${w.mag} • ${w.isAuto ? 'Auto' : 'Semi'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (s.equipped == w.id)
                        const Chip(
                          label: Text('FAOL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          backgroundColor: kPurple,
                        )
                      else if (s.owned.contains(w.id))
                        FilledButton(
                          onPressed: () => s.equip(w.id),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(80, 42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Tanlash'),
                        )
                      else
                        FilledButton(
                          onPressed: () => msg(s.buy(w) ? '${w.name} sotib olindi!' : 'Coin yetarli emas'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(90, 42),
                            backgroundColor: kOrange,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('${w.price} 🪙', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  border: s.equipped == w.id ? kPurple : null,
                ),
              ),
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
