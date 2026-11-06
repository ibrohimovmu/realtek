import 'package:flutter/material.dart';
import '../data/teams.dart';
import '../services/store.dart';
import '../theme.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();

  int _currentStep = 0;
  static const int _totalSteps = 5;

  String _selectedAvatar = 'operator_1';
  String _selectedRegion = 'Toshkent';
  String _selectedTeam = 'blue';
  String _selectedStyle = 'Hujumkor (Assault)';
  String _selectedWeapon = 'm416';

  final List<Map<String, dynamic>> _avatars = const [
    {'id': 'operator_1', 'name': 'Alpha', 'icon': Icons.security},
    {'id': 'operator_2', 'name': 'Specter', 'icon': Icons.visibility},
    {'id': 'operator_3', 'name': 'Valkyrie', 'icon': Icons.flash_on},
    {'id': 'operator_4', 'name': 'Ghost', 'icon': Icons.radar},
    {'id': 'operator_5', 'name': 'Titan', 'icon': Icons.shield},
    {'id': 'operator_6', 'name': 'Cyber', 'icon': Icons.memory},
  ];

  final List<String> _regions = const [
    'Toshkent',
    'Samarqand',
    'Farg\'ona',
    'Buxoro',
    'Andijon',
    'Namangan',
    'Qashqadaryo',
    'Surxondaryo',
    'Xorazm',
    'Navoiy',
    'Jizzax',
    'Sirdaryo',
    'Qoraqalpog\'iston',
  ];

  final List<String> _playStyles = const [
    'Hujumkor (Assault)',
    'Snayper (Sniper)',
    'Taktik (Tactical)',
    'Himoyachi (Support)',
  ];

  final List<Map<String, String>> _weapons = const [
    {'id': 'm416', 'name': 'M416 Avtomat'},
    {'id': 'pistol', 'name': 'P92 To\'pponcha'},
    {'id': 'ump45', 'name': 'UMP45 PP'},
    {'id': 'awm', 'name': 'AWM Snayper'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _finish() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final s = Store.i;
    s.name = name;
    s.avatar = _selectedAvatar;
    s.region = _selectedRegion;
    s.team = _selectedTeam;
    s.playStyle = _selectedStyle;
    s.favoriteWeapon = _selectedWeapon;
    s.save();
  }

  void _next() {
    if (_currentStep == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, jangovar taxallusingizni kiriting!')),
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Steps & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Step Indicator Dots
                  Row(
                    children: List.generate(_totalSteps, (index) {
                      final isActive = index == _currentStep;
                      final isPassed = index < _currentStep;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? kPurple
                              : (isPassed ? kPurple.withValues(alpha: 0.4) : Colors.white12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('O\'tkazib yuborish', style: TextStyle(color: Colors.white60)),
                    ),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentStep = page),
                children: [
                  _buildNicknameStep(),
                  _buildAvatarStep(),
                  _buildRegionStep(),
                  _buildTeamStep(),
                  _buildPlayStyleStep(),
                ],
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(60, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        _currentStep == _totalSteps - 1 ? 'Jangga Kirish' : 'Davom Etish',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 0: Callsign / Nickname
  Widget _buildNicknameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: kPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: kPurple, width: 2),
              boxShadow: [
                BoxShadow(color: kPurple.withValues(alpha: 0.35), blurRadius: 20),
              ],
            ),
            child: const Icon(Icons.gps_fixed, size: 48, color: kPurple),
          ),
          const SizedBox(height: 24),
          Text(
            'Xush Kelibsiz, Operator',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Smartfon kamerasi orqali real hayotda do\'stlar bilan AR Laser Tag jangi. Birinchi bo\'lib nishonga oling!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            maxLength: 16,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Jangovar taxallus (Callsign)',
              prefixIcon: Icon(Icons.person, color: kPurple),
            ),
            onSubmitted: (_) => _next(),
          ),
        ],
      ),
    );
  }

  // STEP 1: Avatar selection
  Widget _buildAvatarStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operator Shakli',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Boshqa o\'yinchilarga ko\'rinadigan jangovar profil ikonkasini tanlang.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: _avatars.length,
            itemBuilder: (context, idx) {
              final av = _avatars[idx];
              final isSel = _selectedAvatar == av['id'];
              return card(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      av['icon'] as IconData,
                      size: 36,
                      color: isSel ? kPurple : Colors.white70,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      av['name'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.white : Colors.white70,
                      ),
                    ),
                  ],
                ),
                color: isSel ? kPurple.withValues(alpha: 0.2) : kCard,
                border: isSel ? kPurple : Colors.transparent,
                onTap: () => setState(() => _selectedAvatar = av['id'] as String),
              );
            },
          ),
        ],
      ),
    );
  }

  // STEP 2: Region selection
  Widget _buildRegionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jangovar Mintaqa',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lokal peshqadamlar jadvali va hududiy statistika uchun.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _regions.map((reg) {
              final isSel = _selectedRegion == reg;
              return ChoiceChip(
                label: Text(reg),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _selectedRegion = reg);
                },
                selectedColor: kPurple,
                backgroundColor: kCard,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.white70,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // STEP 3: Team color
  Widget _buildTeamStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jamoa Rangi (Taktik Forma)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kamera orqali do\'stona o\'t ochishni oldini olish va jamoadoshlarni aniqlash uchun.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Column(
            children: TeamColor.values.where((t) => t != TeamColor.unknown).map((t) {
              final isSel = _selectedTeam == t.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card(
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: t.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: t.color.withValues(alpha: 0.4), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        t.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      if (isSel)
                        const Icon(Icons.check_circle, color: kPurple)
                      else
                        const Icon(Icons.radio_button_unchecked, color: Colors.white24),
                    ],
                  ),
                  color: isSel ? kPurple.withValues(alpha: 0.15) : kCard,
                  border: isSel ? kPurple : Colors.transparent,
                  onTap: () => setState(() => _selectedTeam = t.id),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // STEP 4: Play style & Favorite weapon
  Widget _buildPlayStyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O\'yin Uslubi & Asosiy Qurol',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'O\'z taktik jang strategiyangizni belgilang.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text('Jangovar Uslub:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _playStyles.map((style) {
              final isSel = _selectedStyle == style;
              return ChoiceChip(
                label: Text(style),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _selectedStyle = style);
                },
                selectedColor: kPurple,
                backgroundColor: kCard,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.white70,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Sevimli Qurol:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _weapons.map((w) {
              final isSel = _selectedWeapon == w['id'];
              return ChoiceChip(
                label: Text(w['name']!),
                selected: isSel,
                onSelected: (val) {
                  if (val) setState(() => _selectedWeapon = w['id']!);
                },
                selectedColor: kPurple,
                backgroundColor: kCard,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.white70,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
