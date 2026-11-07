import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Complete 4-Tab Customization Studio for Minimal Launcher:
/// 1. Orqa Fon & AI (Bundled Art, Live Scenes, Solid Palettes, AI Generator, Gallery Picker, Blur/Dim)
/// 2. Yarim Oy & Ikonka (Icon Styles, Crescent Curvature, Left/Right Hand Mode, Icon Size)
/// 3. Soat & Vidjetlar (6 Clock Styles, System Pulse Widget, Daily Note Widget, Recent Strip)
/// 4. Animatsiya & Mushuk (6 Particle Engines, Realistic Cat Toggle, Cat Size Slider, Cat Eye Color)
class CustomizationSheet extends StatefulWidget {
  const CustomizationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const CustomizationSheet(),
    );
  }

  @override
  State<CustomizationSheet> createState() => _CustomizationSheetState();
}

class _CustomizationSheetState extends State<CustomizationSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _aiPromptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiPromptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: LauncherStore.i,
      builder: (context, _) {
        final store = LauncherStore.i;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: size.height * 0.88,
              decoration: BoxDecoration(
                color: const Color(0xFF181B20).withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6C259).withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE6C259), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shaxsiylashtirish Studiyasi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Orqa fon, yarim oy, soat, vidjet va animatsiyalar',
                                  style: TextStyle(color: Colors.white54, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              store.openHomeSettings();
                            },
                            icon: const Icon(Icons.home_rounded, size: 15),
                            label: const Text('Default qilish', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4 Category Tabs
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        indicator: BoxDecoration(
                          color: const Color(0xFF2D333B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        tabs: const [
                          Tab(text: '🖼 Orqa Fon & AI'),
                          Tab(text: '🌙 Yarim Oy & Ikonka'),
                          Tab(text: '⌚ Soat & Vidjet'),
                          Tab(text: '🐈‍⬛ Mushuk & Effekt'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildWallpaperTab(store),
                          _buildWheelAndIconsTab(store),
                          _buildClockAndWidgetsTab(store),
                          _buildCatAndParticlesTab(store),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // TAB 1: Wallpapers, Live Scenes, AI Generator & Gallery
  Widget _buildWallpaperTab(LauncherStore store) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        _sectionTitle('1. KREATIV RASSOMLIK FONLARI (OFFLINE HD)'),
        const SizedBox(height: 10),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: LauncherStore.bundledWallpapers.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = LauncherStore.bundledWallpapers[index];
              final selected = store.wallpaperType == WallpaperType.bundledArt &&
                  store.bundledAsset == item.asset;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.setBundledWallpaper(item.asset);
                },
                child: Container(
                  width: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? const Color(0xFFE6C259) : Colors.white12,
                      width: selected ? 2.5 : 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(item.asset, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          item.title,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFFE6C259),
                            child: Icon(Icons.check_rounded, size: 13, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
        _sectionTitle('2. AI ORQA FON YARATUVCHI & GALEREYA'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _aiPromptCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Masalan: Tungi tog\' va yulduzli osmon minimalizm...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.25),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6C259),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: store.generatingWallpaper
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              await store.generateAiWallpaper(_aiPromptCtrl.text);
                            },
                      icon: store.generatingWallpaper
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.auto_fix_high_rounded, size: 17),
                      label: Text(
                        store.generatingWallpaper ? 'Yaratilmoqda...' : 'AI Fon Yaratish',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => store.pickGalleryWallpaper(),
                      icon: const Icon(Icons.photo_library_outlined, size: 17),
                      label: const Text('Galereyadan', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _sectionTitle('3. JONLI 60FPS ANIMATSIYALI SAHNALAR'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(LauncherStore.liveScenes.length, (i) {
            final scene = LauncherStore.liveScenes[i];
            final selected =
                store.wallpaperType == WallpaperType.liveScene && store.liveSceneIndex == i;
            return ChoiceChip(
              label: Text(scene.title),
              selected: selected,
              selectedColor: const Color(0xFF5CE0D8).withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF5CE0D8) : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                store.setLiveScene(i);
              },
            );
          }),
        ),

        const SizedBox(height: 20),
        _sectionTitle('4. MINIMALIST BIR XIL RANGLAR'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: LauncherStore.backgrounds.map((c) {
            final selected =
                store.wallpaperType == WallpaperType.solid && store.background == c;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.setSolidBackground(c);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? const Color(0xFFE6C259) : Colors.white24,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFFE6C259))
                    : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        _sectionTitle('5. RASM XIRALIGI VA QORAYTIRISH'),
        _sliderTile(
          label: 'Fonni qoraytirish (Dim)',
          value: store.wallpaperDim,
          min: 0.0,
          max: 0.70,
          display: '${(store.wallpaperDim * 100).round()}%',
          onChanged: store.setWallpaperDim,
        ),
        _sliderTile(
          label: 'Fonni xiralashtirish (Blur)',
          value: store.wallpaperBlur,
          min: 0.0,
          max: 15.0,
          display: store.wallpaperBlur.toStringAsFixed(1),
          onChanged: store.setWallpaperBlur,
        ),
      ],
    );
  }

  // TAB 2: Crescent Wheel Geometry & Icon Styles
  Widget _buildWheelAndIconsTab(LauncherStore store) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        _sectionTitle('YARIM OY (CRESCENT WHEEL) SOZLAMALARI'),
        const SizedBox(height: 8),
        _sliderTile(
          label: 'Yarim oy egrilik darajasi',
          value: store.wheelCurvature,
          min: 0.0,
          max: 1.0,
          display: '${(store.wheelCurvature * 100).round()}%',
          onChanged: store.setWheelCurvature,
        ),
        _sliderTile(
          label: 'Ikonkalar o\'lchami',
          value: store.iconScale,
          min: 0.75,
          max: 1.35,
          display: '${(store.iconScale * 100).round()}%',
          onChanged: store.setIconScale,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: const Color(0xFF5CE0D8),
            title: const Text(
              'Yarim oyni chap tomonda joylashtirish',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              store.wheelLeftSide
                  ? 'Hozir: Ilovalar chapda, mushukcha o\'ngda'
                  : 'Hozir: Ilovalar o\'ngda, mushukcha chapda',
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
            value: store.wheelLeftSide,
            onChanged: store.setWheelLeftSide,
          ),
        ),

        const SizedBox(height: 22),
        _sectionTitle('IKONKA DIZAYN USLUBLARI (6 XIL)'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: IconStyle.values.map((style) {
            final selected = store.iconStyle == style;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.setIconStyle(style);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF5CE0D8).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? const Color(0xFF5CE0D8) : Colors.white12,
                    width: selected ? 1.8 : 1.0,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 17,
                      color: selected ? const Color(0xFF5CE0D8) : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        style.title,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // TAB 3: Clock Styles & Home Screen Widgets
  Widget _buildClockAndWidgetsTab(LauncherStore store) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        _sectionTitle('SOAT USLUBLARI (6 XIL KREATIV DIZAYN)'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: ClockStyle.values.map((style) {
            final selected = store.clockStyle == style;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.setClockStyle(style);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE6C259).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? const Color(0xFFE6C259) : Colors.white12,
                    width: selected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 17,
                      color: selected ? const Color(0xFFE6C259) : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        style.title,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),
        _sectionTitle('ASOSIY EKRAN VIDJETLARI'),
        const SizedBox(height: 8),
        _switchCard(
          title: 'Batareya va RAM ko\'rsatkichi (System Pulse)',
          subtitle: 'Soat ostida real vaqtdagi quvvat va xotira holati',
          value: store.showSystemPulse,
          onChanged: store.setShowSystemPulse,
        ),
        const SizedBox(height: 8),
        _switchCard(
          title: 'Kunlik Maqsad va Eslatma vidjeti',
          subtitle: 'Ustiga bosib o\'zgartirish mumkin bo\'lgan matn vidjeti',
          value: store.showQuickNote,
          onChanged: store.setShowQuickNote,
        ),
        const SizedBox(height: 8),
        _switchCard(
          title: 'Oxirgi kirilgan ilovalar tezkor qatori',
          subtitle: 'Ekranning pastki qismida so\'nggi faol ilovalar',
          value: store.showRecentStrip,
          onChanged: store.setShowRecentStrip,
        ),
      ],
    );
  }

  // TAB 4: Realistic Cat Mascot & Particle Animations
  Widget _buildCatAndParticlesTab(LauncherStore store) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        _sectionTitle('HAQIQIY QORA MUSHUKCHA SOZLAMALARI'),
        const SizedBox(height: 8),
        _switchCard(
          title: 'Mo\'ralovchi mushukcha animatsiyasi',
          subtitle: 'Barmog\'ingizni kuzatuvchi jonli qora mushukcha',
          value: store.catEnabled,
          onChanged: store.setCat,
        ),
        if (store.catEnabled) ...[
          const SizedBox(height: 10),
          _sliderTile(
            label: 'Mushukcha o\'lchami (Kichik <-> Katta)',
            value: store.catScale,
            min: 0.55,
            max: 1.20,
            display: '${(store.catScale * 100).round()}%',
            onChanged: store.setCatScale,
          ),
          const SizedBox(height: 10),
          const Text(
            'Mushuk ko\'zining rangi',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: LauncherStore.catEyeColors.map((eye) {
              final selected = store.catEyeColor == eye.color;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.setCatEyeColor(eye.color);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Color(eye.color) : Colors.white12,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(eye.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        eye.name,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 22),
        _sectionTitle('ATROF-MUHIT ZARRACHALARI (7 XIL ANIMATSIYA)'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ParticleType.values.map((pt) {
            final selected = store.particleType == pt;
            return ChoiceChip(
              label: Text(pt.title),
              selected: selected,
              selectedColor: const Color(0xFF5CE0D8).withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF5CE0D8) : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                store.setParticleType(pt);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(
              display,
              style: const TextStyle(
                color: Color(0xFF5CE0D8),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF5CE0D8),
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF5CE0D8).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: const Color(0xFF5CE0D8),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
