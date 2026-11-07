import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/ai_assistant_service.dart';
import '../services/launcher_store.dart';
import '../widgets/activity_sheet.dart';
import '../widgets/ai_assistant_overlay.dart';
import '../widgets/ambient_canvas.dart';
import '../widgets/clock_header.dart';
import '../widgets/crescent_wheel.dart';
import '../widgets/customization_sheet.dart';
import '../widgets/game_hub_sheet.dart';
import '../widgets/peeking_cat.dart';
import '../widgets/welcome_curtain.dart';

class HomeScreen extends StatefulWidget {
  final LauncherStore store;
  final AiAssistantService ai;

  const HomeScreen({super.key, required this.store, required this.ai});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _showWelcomeCurtain = true;
  int _lastSeenPortalCount = 0;
  late final AnimationController _portalCtrl;
  late final AnimationController _resumeBounceCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _portalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _resumeBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      value: 1.0,
    );
    widget.store.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.ai.initWakeWordListener(widget.store);
    });
  }

  void _onStoreChanged() {
    if (!mounted) return;
    if (widget.store.launchPortalCounter != _lastSeenPortalCount) {
      _lastSeenPortalCount = widget.store.launchPortalCounter;
      _portalCtrl.forward(from: 0.0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.store.refreshDeviceStats();
      widget.ai.refreshAccessibilityStatus();
      // Play smooth return transition when coming back from an app
      _portalCtrl.reverse();
      _resumeBounceCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    _portalCtrl.dispose();
    _resumeBounceCtrl.dispose();
    super.dispose();
  }

  void _openCustomization() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomizationSheet(
        store: widget.store,
        onReplayWelcome: () {
          setState(() => _showWelcomeCurtain = true);
        },
      ),
    );
  }

  void _openActivity() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivitySheet(store: widget.store),
    );
  }

  void _openGameHub() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameHubSheet(store: widget.store),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.store, widget.ai]),
      builder: (context, _) {
        final store = widget.store;
        final ai = widget.ai;
        final isDarkText = store.foregroundColor.computeLuminance() < 0.3;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDarkText ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDarkText ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: store.backgroundColor,
            resizeToAvoidBottomInset: false,
            body: GestureDetector(
              onLongPress: _openCustomization,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Curated Real Photography / Nordic Slate Background
                  AmbientCanvas(store: store),

                  // 2. Peeking Minimalist Black Cat Mascot on Right Edge
                  if (store.showMascot)
                    Positioned(
                      right: -4,
                      top: MediaQuery.of(context).size.height * 0.49,
                      child: PeekingCat(scale: store.mascotScale),
                    ),

                  // 3. Main Foreground Content with Return Kinetic Bounce
                  AnimatedBuilder(
                    animation: _resumeBounceCtrl,
                    builder: (context, child) {
                      final curved = Curves.easeOutCubic.transform(
                        _resumeBounceCtrl.value,
                      );
                      final scale = 0.96 + (0.04 * curved);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          ClockHeader(store: store),
                          const SizedBox(height: 16),
                          Expanded(
                            child: CrescentWheel(
                              store: store,
                              onOpenCustomize: _openCustomization,
                              onOpenActivity: _openActivity,
                              onOpenGameHub: _openGameHub,
                            ),
                          ),
                          _buildBottomDock(store, ai),
                        ],
                      ),
                    ),
                  ),

                  // 4. App Launch / Exit Portal Transition Overlay
                  AnimatedBuilder(
                    animation: _portalCtrl,
                    builder: (context, _) {
                      if (_portalCtrl.value <= 0.01) {
                        return const SizedBox.shrink();
                      }
                      return IgnorePointer(
                        child: CustomPaint(
                          painter: _AppLaunchPortalPainter(
                            progress: _portalCtrl.value,
                            style: store.launchAnimStyle,
                            appName: store.lastLaunchingAppName ?? '',
                          ),
                        ),
                      );
                    },
                  ),

                  // 5. Autonomous Nova AI Bottom Capsule
                  if (ai.isOverlayOpen)
                    Positioned.fill(
                      child: AiAssistantOverlay(
                        ai: ai,
                        store: store,
                        onClose: ai.closeAssistant,
                      ),
                    ),

                  // 6. Unusual 6-Panel Kinetic Architectural Welcome Curtain
                  if (_showWelcomeCurtain && store.showWelcomeAnimation)
                    Positioned.fill(
                      child: WelcomeCurtain(
                        onFinished: () {
                          if (mounted) {
                            setState(() => _showWelcomeCurtain = false);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomDock(LauncherStore store, AiAssistantService ai) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Game Hub Quick Pill
          _dockButton(
            icon: Icons.sports_esports_rounded,
            label: 'Game Hub',
            onTap: _openGameHub,
          ),
          const SizedBox(width: 8),

          // Center Nova AI Wake-Word Pill (#0E1D21 & #122E34 & #ABAFB5)
          Flexible(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ai.openAssistant(store, autoListen: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E1D21), Color(0xFF122E34)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF677E8A).withValues(alpha: 0.42),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ai.voiceBiometricOnly
                            ? const Color(0xFFE0B4B2)
                            : const Color(0xFFABAFB5),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '"${ai.customWakePhrase}" • AI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFABAFB5),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Customize Studio Quick Pill
          _dockButton(
            icon: Icons.tune_rounded,
            label: 'Sozlash',
            onTap: _openCustomization,
          ),
        ],
      ),
    );
  }

  Widget _dockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1D21).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF677E8A).withValues(alpha: 0.28),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFABAFB5)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFABAFB5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLaunchPortalPainter extends CustomPainter {
  final double progress;
  final LaunchAnimStyle style;
  final String appName;

  _AppLaunchPortalPainter({
    required this.progress,
    required this.style,
    required this.appName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress);
    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);
    final center = Offset(size.width * 0.38, size.height * 0.52);

    switch (style) {
      case LaunchAnimStyle.portalIris:
        final maxR = size.longestSide * 0.85;
        final ringPaint = Paint()
          ..color = const Color(0xFF677E8A).withValues(alpha: 0.55 * fadeOut)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 + (24.0 * t);
        canvas.drawCircle(center, maxR * t, ringPaint);
      case LaunchAnimStyle.kineticSlide:
        final rect = Rect.fromLTWH(
          0,
          size.height * (1.0 - t),
          size.width,
          size.height * t,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0xFF0E1D21).withValues(alpha: 0.42 * fadeOut),
        );
      case LaunchAnimStyle.liquidMorph:
        final r = size.longestSide * 0.75 * t;
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = const Color(0xFF122E34).withValues(alpha: 0.52 * fadeOut),
        );
      case LaunchAnimStyle.shutterSplit:
        final h = (size.height / 2) * t;
        final paint = Paint()
          ..color = const Color(0xFF0E1D21).withValues(alpha: 0.48 * fadeOut);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h), paint);
        canvas.drawRect(
          Rect.fromLTWH(0, size.height - h, size.width, h),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _AppLaunchPortalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
