import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

class CustomizationSheet extends StatefulWidget {
  final LauncherStore store;
  final VoidCallback? onReplayWelcome;

  const CustomizationSheet({
    super.key,
    required this.store,
    this.onReplayWelcome,
  });

  @override
  State<CustomizationSheet> createState() => _CustomizationSheetState();
}

class _CustomizationSheetState extends State<CustomizationSheet> {
  int _selectedTab = 0;

  static const _tabs = [
    (Icons.wallpaper_rounded, 'Fon & Rasm'),
    (Icons.widgets_rounded, 'Vidjetlar'),
    (Icons.animation_rounded, 'Animatsiya'),
    (Icons.shield_outlined, 'Xavfsizlik'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        return Container(
          height: MediaQuery.of(context).size.height * 0.84,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1D21),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.32),
              width: 1.1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF677E8A).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF122E34),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: const Color(0xFFABAFB5)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFFABAFB5),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CUSTOMIZATION STUDIO',
                              style: TextStyle(
                                color: Color(0xFFABAFB5),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            Text(
                              'Nordic Slate dizayn, haqiqiy fotolar, vidjetlar va animatsiya',
                              style: TextStyle(
                                color: Color(0xFF677E8A),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => store.setAsDefaultLauncher(),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF122E34),
                          foregroundColor: const Color(0xFFABAFB5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.home_outlined, size: 15),
                        label: const Text(
                          'Default qilish',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Overflow-proof Custom Pill Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final active = _selectedTab == i;
                      final tab = _tabs[i];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTab = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                vertical: 9,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF677E8A)
                                    : const Color(0xFF122E34),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: active
                                      ? const Color(0xFFABAFB5)
                                      : const Color(0xFF677E8A)
                                          .withValues(alpha: 0.22),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    tab.$1,
                                    size: 14,
                                    color: active
                                        ? const Color(0xFF0E1D21)
                                        : const Color(0xFFABAFB5),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      tab.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: active
                                            ? const Color(0xFF0E1D21)
                                            : const Color(0xFFABAFB5),
                                        fontSize: 11,
                                        fontWeight: active
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: switch (_selectedTab) {
                    0 => _buildWallpaperTab(store),
                    1 => _buildWidgetsTab(store),
                    2 => _buildAnimationTab(store),
                    _ => _buildSecurityTab(store),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── TAB 0: WALLPAPERS, REAL UNSPLASH PHOTOS & NORDIC PALETTE ────────────
  Widget _buildWallpaperTab(LauncherStore store) {
    final presets = [
      (
        WallpaperPreset.sageZen,
        'Nordic Mist',
        'assets/wallpapers/sage_zen.jpg',
        const Color(0xFFABAFB5),
      ),
      (
        WallpaperPreset.noirCatMoon,
        'Obsidian Slate',
        'assets/wallpapers/noir_cat_moon.jpg',
        const Color(0xFF0E1D21),
      ),
      (
        WallpaperPreset.duneEclipse,
        'Abyssal Petrol',
        'assets/wallpapers/dune_eclipse.jpg',
        const Color(0xFF122E34),
      ),
      (
        WallpaperPreset.cyberRain,
        'Steel Fog',
        'assets/wallpapers/cyber_rain.jpg',
        const Color(0xFF677E8A),
      ),
      (
        WallpaperPreset.nordicAurora,
        'Deep Fjord',
        'assets/wallpapers/nordic_aurora.jpg',
        const Color(0xFF283E47),
      ),
      (
        WallpaperPreset.bauhausArch,
        'Minimal Arch',
        'assets/wallpapers/bauhaus_arch.jpg',
        const Color(0xFF622347),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _sectionTitle('1. HAQIQIY TANLANGAN FOTOLAR (OFFLINE TO\'PLAM)'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemCount: presets.length,
          itemBuilder: (context, idx) {
            final item = presets[idx];
            final selected = store.wallpaperPreset == item.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.updateSetting(() => store.wallpaperPreset = item.$1);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFE0B4B2)
                        : const Color(0xFF677E8A).withValues(alpha: 0.28),
                    width: selected ? 2.2 : 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(item.$3, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0E1D21).withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFABAFB5),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFE0B4B2),
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 18),
        _sectionTitle('2. UNSPLASH REAL FOTOLAR VA SHAXSIY GALEREYA'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF122E34),
                  foregroundColor: const Color(0xFFABAFB5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF677E8A).withValues(alpha: 0.35),
                    ),
                  ),
                ),
                onPressed: () => store.pickCustomWallpaper(),
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: const Text(
                  'Galereyadan rasm tanlash',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 94,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: LauncherStore.curatedUnsplashWallpapers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = LauncherStore.curatedUnsplashWallpapers[i];
              return GestureDetector(
                onTap: store.isDownloadingWallpaper
                    ? null
                    : () => store.downloadCuratedWallpaper(
                          item['id']!,
                          item['url']!,
                        ),
                child: Container(
                  width: 135,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF122E34),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF677E8A).withValues(alpha: 0.30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud_download_outlined,
                            size: 15,
                            color: Color(0xFFE0B4B2),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item['title']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFABAFB5),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        item['subtitle']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF677E8A),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        store.isDownloadingWallpaper
                            ? 'Yuklanmoqda...'
                            : '1-Bosishda o\'rnatish',
                        style: const TextStyle(
                          color: Color(0xFFE0B4B2),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (store.customWallpaperPath != null &&
            File(store.customWallpaperPath!).existsSync()) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF122E34),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFFE0B4B2),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maxsus tanlangan foto-oboy faol',
                    style: TextStyle(color: Color(0xFFABAFB5), fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        _sectionTitle('3.FON QORONG\'ULIGI VA MUSHUKCHA (MASCOT)'),
        _sliderRow(
          label: 'Orqa fon qorong\'uligi (Dim)',
          value: store.wallpaperDim,
          min: 0.0,
          max: 0.75,
          display: '${(store.wallpaperDim * 100).round()}%',
          onChanged: (v) => store.updateSetting(() => store.wallpaperDim = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Chekkadan qarab turuvchi mushukcha',
            style: TextStyle(
              color: Color(0xFFABAFB5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Ko\'zlari bosilganda miltillaydi va qimirlaydi',
            style: TextStyle(color: Color(0xFF677E8A), fontSize: 11),
          ),
          value: store.showMascot,
          activeThumbColor: const Color(0xFFABAFB5),
          activeTrackColor: const Color(0xFF677E8A),
          onChanged: (v) => store.updateSetting(() => store.showMascot = v),
        ),
        if (store.showMascot)
          _sliderRow(
            label: 'Mushukcha o\'lchami',
            value: store.mascotScale,
            min: 0.55,
            max: 1.25,
            display: '${(store.mascotScale * 100).round()}%',
            onChanged: (v) => store.updateSetting(() => store.mascotScale = v),
          ),
      ],
    );
  }

  // ── TAB 1: CLOCK STYLES, MUSIC PLAYER & CALENDAR WIDGETS ────────────────
  Widget _buildWidgetsTab(LauncherStore store) {
    final clockOptions = [
      (ClockStyle.editorialRibbon, 'Editorial Ribbon (20:43 + Hafta)'),
      (ClockStyle.bauhausSplit, 'Bauhaus Arxitektura Split'),
      (ClockStyle.neonMatrix, 'Nordic Slate Matrix Kartochka'),
      (ClockStyle.minimalZen, 'Minimal Zen Tipografiya'),
      (ClockStyle.analogChrono, 'Analog Xronograf Soat'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _sectionTitle('1. SOAT USLUBI (CLOCK STYLE)'),
        const SizedBox(height: 8),
        ...clockOptions.map((opt) {
          final selected = store.clockStyle == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.updateSetting(() => store.clockStyle = opt.$1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF122E34)
                      : const Color(0xFF122E34).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFABAFB5)
                        : const Color(0xFF677E8A).withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 18,
                      color: selected
                          ? const Color(0xFFE0B4B2)
                          : const Color(0xFF677E8A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          color: const Color(0xFFABAFB5),
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        _sliderRow(
          label: 'Soat masshtabi',
          value: store.clockScale,
          min: 0.75,
          max: 1.30,
          display: '${(store.clockScale * 100).round()}%',
          onChanged: (v) => store.updateSetting(() => store.clockScale = v),
        ),

        const SizedBox(height: 12),
        _sectionTitle('2. BOSH EKRAN VIDJETLARI (MUSIC, KALENDAR, TELEMETRIYA)'),
        _switchTile(
          title: 'Minimalist Musiqa Pleyeri (Music Widget)',
          subtitle: 'Bosh ekranda jonli ekvalayzer va Oldingi / Play-Pause / Keyingi boshqaruv',
          value: store.showMusicWidget,
          onChanged: (v) =>
              store.updateSetting(() => store.showMusicWidget = v),
        ),
        _switchTile(
          title: 'Interaktiv Kalendar Vidjeti (Calendar)',
          subtitle: 'Sana tugmasini bosganda oylik Nordic kalendar jadvali ochiladi',
          value: store.showCalendarWidget,
          onChanged: (v) =>
              store.updateSetting(() => store.showCalendarWidget = v),
        ),
        _switchTile(
          title: 'Tizim Telemetriya Kapsulasi (Batareya, °C, RAM)',
          subtitle: 'Batareya foizi, qurilma harorati va RAM yuklamasini ko\'rsatadi',
          value: store.showStatusPill,
          onChanged: (v) => store.updateSetting(() => store.showStatusPill = v),
        ),
        _switchTile(
          title: 'Kunlik Maqsad va Eslatma Vidjeti',
          subtitle: 'Bosh ekranda ustiga bosib tahrirlanadigan shaxsiy eslatma',
          value: store.showDailyNoteWidget,
          onChanged: (v) =>
              store.updateSetting(() => store.showDailyNoteWidget = v),
        ),
        _switchTile(
          title: '24 soatlik vaqt formati',
          subtitle: '20:43 formatida ko\'rsatish',
          value: store.use24HourFormat,
          onChanged: (v) =>
              store.updateSetting(() => store.use24HourFormat = v),
        ),
      ],
    );
  }

  // ── TAB 2: ANIMATIONS, TRANSITIONS & ICON PACKS ─────────────────────────
  Widget _buildAnimationTab(LauncherStore store) {
    final launchStyles = [
      (LaunchAnimStyle.portalIris, 'Portal Halqa (Iris Ring)'),
      (LaunchAnimStyle.kineticSlide, 'Kinetik Silliq Siljish'),
      (LaunchAnimStyle.liquidMorph, 'Suyuq To\'lqin (Liquid Morph)'),
      (LaunchAnimStyle.shutterSplit, 'Arxitektura Parda Effekt'),
    ];

    final iconStyles = [
      (IconPackStyle.monochromeDisc, 'Obsidian Monochrome Disc (#232728)'),
      (IconPackStyle.frostedGlass, 'Nordic Frosted Glass (#122E34)'),
      (IconPackStyle.outlineMinimal, 'Minimalist Chiziqli Kontur'),
      (IconPackStyle.cyberHex, 'Geometrik Kvadrat-Hex'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _sectionTitle('1. NOODATIY WELCOME VA O\'TISH ANIMATSIYALARI'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF122E34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.view_column_rounded,
                color: Color(0xFFE0B4B2),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '6-Panelli Kinetik Welcome Animatsiyasi',
                      style: TextStyle(
                        color: Color(0xFFABAFB5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Launcher yuklanganda 6 ta Nordic Slate ustuni ochiladi',
                      style: TextStyle(color: Color(0xFF677E8A), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (widget.onReplayWelcome != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onReplayWelcome!();
                  },
                  child: const Text(
                    'Ko\'rish ▶',
                    style: TextStyle(
                      color: Color(0xFFE0B4B2),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle('2. ILOVAGA KIRISH ANIMATSIYASI (LAUNCH TRANSITION)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: launchStyles.map((st) {
            final selected = store.launchAnimStyle == st.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.updateSetting(() => store.launchAnimStyle = st.$1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF677E8A)
                      : const Color(0xFF122E34),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  st.$2,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF0E1D21)
                        : const Color(0xFFABAFB5),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        _sectionTitle('3. IKONKA DIZAYNI VA O\'LCHAMLAR'),
        const SizedBox(height: 8),
        ...iconStyles.map((ic) {
          final selected = store.iconStyle == ic.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                store.updateSetting(() => store.iconStyle = ic.$1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF122E34)
                      : const Color(0xFF122E34).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFABAFB5)
                        : const Color(0xFF677E8A).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 16,
                      color: selected
                          ? const Color(0xFFE0B4B2)
                          : const Color(0xFF677E8A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ic.$2,
                        style: const TextStyle(
                          color: Color(0xFFABAFB5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        _sliderRow(
          label: 'Ikonka o\'lchami',
          value: store.iconDiscSize,
          min: 38.0,
          max: 62.0,
          display: '${store.iconDiscSize.round()} px',
          onChanged: (v) => store.updateSetting(() => store.iconDiscSize = v),
        ),
        _sliderRow(
          label: 'Yozuv shrifti o\'lchami',
          value: store.labelFontSize,
          min: 14.0,
          max: 22.0,
          display: '${store.labelFontSize.round()} pt',
          onChanged: (v) => store.updateSetting(() => store.labelFontSize = v),
        ),
        _sliderRow(
          label: 'Ilovalar orasidagi masofa',
          value: store.itemSpacing,
          min: 56.0,
          max: 86.0,
          display: '${store.itemSpacing.round()} px',
          onChanged: (v) => store.updateSetting(() => store.itemSpacing = v),
        ),
        _sliderRow(
          label: 'Ro\'yxat egriligi (0% = Tekis Vertikal)',
          value: store.wheelCurvature,
          min: 0.0,
          max: 1.0,
          display: store.wheelCurvature < 0.05
              ? 'Tekis (0%)'
              : '${(store.wheelCurvature * 100).round()}%',
          onChanged: (v) => store.updateSetting(() => store.wheelCurvature = v),
        ),
      ],
    );
  }

  // ── TAB 3: PRIVACY, SECURITY, VAULT PIN & HIDDEN APPS ───────────────────
  Widget _buildSecurityTab(LauncherStore store) {
    final hiddenApps = store.allApps
        .where((a) => store.isHidden(a.packageName))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _sectionTitle('1. MAXFIYLIK VA XAVFSIZLIK ESLATMALARI'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF122E34),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.30),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFFE0B4B2),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '100% On-Device Maxfiylik Arxitekturasi',
                    style: TextStyle(
                      color: Color(0xFFABAFB5),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '• Ovoz Biometriyasi (Voiceprint): Sizning ovoz spektral namunangiz faqat qurilmaning ichki xotirasida 4D akustik vektor sifatida saqlanadi.\n'
                '• Accessibility (Avtonom Boshqaruv): Faqat siz ovoz yoki matn orqali buyruq berganingizda (Instagram, Telegram, WhatsApp yozish yoki Qulfni ochish) ishga tushadi.\n'
                '• Ilova Qulfi (App Vault): Maxfiy ilovalaringizni PIN-kod bilan himoyalang.',
                style: TextStyle(
                  color: Color(0xFF677E8A),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('2. ILOVALAR QULFI (APP VAULT PIN)'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF122E34),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFFABAFB5)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ilova Vault PIN kodi',
                      style: TextStyle(
                        color: Color(0xFFABAFB5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Joriy PIN: ${"•" * store.vaultPin.length} (Ilova ustini bosib turib qulflang)',
                      style: const TextStyle(
                        color: Color(0xFF677E8A),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _changeVaultPinDialog(store),
                child: const Text(
                  'O\'zgartirish',
                  style: TextStyle(color: Color(0xFFE0B4B2)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('3. YASHIRILGAN ILOVALAR (${hiddenApps.length})'),
        const SizedBox(height: 8),
        if (hiddenApps.isEmpty)
          const Text(
            'Hozircha yashirilgan ilovalar yo\'q. Bosh ekranda istalgan ilova ustini bosib turib "Ro\'yxatdan yashirish" ni tanlashingiz mumkin.',
            style: TextStyle(color: Color(0xFF677E8A), fontSize: 11.5),
          )
        else
          ...hiddenApps.map(
            (app) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                app.name,
                style: const TextStyle(color: Color(0xFFABAFB5)),
              ),
              trailing: TextButton(
                onPressed: () => store.toggleHidden(app.packageName),
                child: const Text(
                  'Qaytarish',
                  style: TextStyle(color: Color(0xFFE0B4B2)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _changeVaultPinDialog(LauncherStore store) async {
    final ctrl = TextEditingController(text: store.vaultPin);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1D21),
        title: const Text(
          'Yangi Vault PIN kodi',
          style: TextStyle(color: Color(0xFFABAFB5), fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFABAFB5)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF122E34),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(color: Color(0xFF677E8A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF677E8A),
              foregroundColor: const Color(0xFF0E1D21),
            ),
            onPressed: () {
              final clean = ctrl.text.trim();
              if (clean.length >= 4) {
                store.updateSetting(() => store.vaultPin = clean);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF677E8A),
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFABAFB5),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Color(0xFFE0B4B2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF677E8A),
              inactiveTrackColor: const Color(0xFF122E34),
              thumbColor: const Color(0xFFABAFB5),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFABAFB5),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF677E8A), fontSize: 11),
      ),
      value: value,
      activeThumbColor: const Color(0xFFABAFB5),
      activeTrackColor: const Color(0xFF677E8A),
      onChanged: onChanged,
    );
  }
}
