import 'package:flutter/material.dart';
import '../services/store.dart';
import '../theme.dart';

class SafetyNoticeScreen extends StatelessWidget {
  const SafetyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: kPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: kPurple, width: 2),
                        ),
                        child: const Icon(Icons.security, color: kPurple, size: 38),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Xavfsizlik va Maxfiylik',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'AR Shooter o\'yinini boshlashdan avval muhim qoidalarni o\'qib chiqing va tasdiqlang.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _ruleCard(
                        icon: Icons.videogame_asset_outlined,
                        color: kPurple,
                        title: '1. Faqat Virtual O\'yin',
                        description:
                            'Bu sof mobil virtual o\'yin. Faqat o\'yinga qo\'shilgan va rozilik bergan do\'stlaringiz bilan o\'ynang.',
                      ),
                      const SizedBox(height: 12),
                      _ruleCard(
                        icon: Icons.person_off_outlined,
                        color: kRed,
                        title: '2. Begonalarga Qaratmang',
                        description:
                            'Hech qachon o\'yinda ishtirok etmayotgan notanish odamlarga yoki jamoat joyidagi begonalarga qaratmang.',
                      ),
                      const SizedBox(height: 12),
                      _ruleCard(
                        icon: Icons.block,
                        color: kOrange,
                        title: '3. Haqiqiy/O\'yinchoq Qurol Taqiqlangan',
                        description:
                            'Hech qanday haqiqiy yoki qurolga o\'xshash o\'yinchoqlardan foydalanmang. Faqat smartfon ekranidan foydalaniladi.',
                      ),
                      const SizedBox(height: 12),
                      _ruleCard(
                        icon: Icons.lock_outline,
                        color: kGreen,
                        title: '4. Kamera Maxfiyligi',
                        description:
                            'Kamera kadrlarining barchasi faqat telefoningizning o\'zida qayta ishlanadi. Hech qanday video yoki surat saqlanmaydi va tarmoqqa yuklanmaydi.',
                      ),
                      const SizedBox(height: 12),
                      _ruleCard(
                        icon: Icons.location_on_outlined,
                        color: kCyan,
                        title: '5. Geopozitsiya Xavfsizligi',
                        description:
                            'Geolokatsiya ma\'lumoti faqat xonadagi o\'yin davomida nishon hisoblash uchun do\'stlaringizga ulashiladi va xonadan chiqqach to\'xtatiladi.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              FilledButton(
                onPressed: () {
                  Store.i.acceptSafety();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: kPurple,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: const Text(
                  'Tushundim va Qoidalarga Roziman',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
