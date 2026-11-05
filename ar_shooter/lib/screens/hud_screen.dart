import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/detection_service.dart';
import '../services/lan.dart';
import '../services/store.dart';
import '../theme.dart';

enum Kind { enemy, medkit, crate, bandage }

enum EnemyCategory {
  normal('HOSTILE UNIT', 100, 12, kRed, Icons.gps_fixed),
  fast('FAST SCOUT', 60, 8, kOrange, Icons.bolt),
  tank('HEAVY JUGGERNAUT', 220, 22, Colors.purpleAccent, Icons.shield);

  final String title;
  final int maxHp;
  final int dmg;
  final Color color;
  final IconData icon;
  const EnemyCategory(this.title, this.maxHp, this.dmg, this.color, this.icon);
}

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});
  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> with SingleTickerProviderStateMixin {
  final s = Store.i;
  final lan = Lan.i;
  final AudioPlayer _audioPlayer = AudioPlayer();

  CameraController? _cam;
  Timer? _spawnTimer;
  Timer? _attackTimer;
  Timer? _roundTickTimer;
  final Random _r = Random();

  // Target State
  Kind? _kind;
  EnemyCategory _enemyCategory = EnemyCategory.normal;
  Rect _targetRect = const Rect.fromLTWH(120, 200, 100, 110);
  int _enemyHp = 100;
  int _enemyMaxHp = 100;
  DateTime _lastDetectionTime = DateTime.now();
  bool _isRealPerson = false;
  double _targetDistance = 3.5;
  double _scopeZoom = 1.0;

  // Player combat state
  int _hp = 100;
  int _ammo = 12;
  int _reserve = 120;
  bool _isReloading = false;
  double _reloadProgress = 0.0;
  Timer? _reloadTimer;
  DateTime _lastShotTime = DateTime.fromMillisecondsSinceEpoch(0);

  // FX & Animation
  Offset _recoilOffset = Offset.zero;
  bool _showHitmarker = false;
  bool _showDamageBlood = false;
  String? _floatingDamageText;

  @override
  void initState() {
    super.initState();
    _ammo = s.weapon.mag;
    _initCam();
    _startSpawner();
    _startEnemyAttacks();

    _roundTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return;
      final backCam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final c = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.yuv420,
      );
      await c.initialize();
      
      final initZoom = s.weapon.id == 'sniper' ? 2.0 : 1.0;
      try {
        await c.setZoomLevel(initZoom);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _cam = c;
          _scopeZoom = initZoom;
        });
      }

      // Stream frames for ML Kit real person detection (~5 FPS throttled)
      await c.startImageStream((image) => _onCameraImage(image));
    } catch (_) {}
  }

  void _onCameraImage(CameraImage image) {
    if (!mounted || _cam == null) return;
    final size = MediaQuery.maybeOf(context)?.size ?? const Size(380, 700);

    DetectionService.i.processFrame(
      image: image,
      camera: _cam!.description,
      screenSize: size,
    ).then((person) {
      if (!mounted) return;
      if (person != null) {
        setState(() {
          _kind = Kind.enemy;
          _targetRect = person.screenRect;
          _targetDistance = person.distanceMeters;
          _isRealPerson = true;
          _lastDetectionTime = DateTime.now();
        });
      }
    }).catchError((_) {});
  }

  Future<void> _toggleScope() async {
    if (_cam == null) return;
    double nextZoom;
    if (_scopeZoom < 1.9) {
      nextZoom = 2.0;
    } else if (_scopeZoom < 3.9) {
      nextZoom = 4.0;
    } else {
      nextZoom = 1.0;
    }

    try {
      final maxZoom = await _cam!.getMaxZoomLevel();
      final targetZoom = min(nextZoom, maxZoom);
      await _cam!.setZoomLevel(targetZoom);
      if (mounted) {
        setState(() => _scopeZoom = targetZoom);
      }
    } catch (_) {}
  }

  void _startSpawner() {
    _spawnTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_kind != null) {
        final elapsed = DateTime.now().difference(_lastDetectionTime).inSeconds;
        if (!_isRealPerson && elapsed > 8) {
          setState(() => _kind = null);
        } else if (_isRealPerson && elapsed > 5) {
          setState(() {
            _isRealPerson = false;
            _kind = null;
          });
        }
        return;
      }

      final roll = _r.nextDouble();
      final size = MediaQuery.maybeOf(context)?.size ?? const Size(380, 700);

      setState(() {
        _isRealPerson = false;
        if (roll < 0.60) {
          _kind = Kind.enemy;
          final catRoll = _r.nextDouble();
          if (catRoll < 0.55) {
            _enemyCategory = EnemyCategory.normal;
          } else if (catRoll < 0.85) {
            _enemyCategory = EnemyCategory.fast;
          } else {
            _enemyCategory = EnemyCategory.tank;
          }
          _enemyHp = _enemyCategory.maxHp + (levelOf(s.xp) * 8);
          _enemyMaxHp = _enemyHp;
        } else if (roll < 0.75) {
          _kind = Kind.medkit;
        } else if (roll < 0.88) {
          _kind = Kind.bandage;
        } else {
          _kind = Kind.crate;
        }

        final w = _kind == Kind.enemy ? 100.0 : 80.0;
        final h = _kind == Kind.enemy ? 110.0 : 85.0;
        final left = 30 + _r.nextDouble() * (size.width - w - 60);
        final top = 100 + _r.nextDouble() * (size.height - h - 260);
        _targetRect = Rect.fromLTWH(left, top, w, h);
        _lastDetectionTime = DateTime.now();
      });
    });
  }

  void _startEnemyAttacks() {
    _attackTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_kind != Kind.enemy || !mounted) return;
      _takeDamage(_enemyCategory.dmg);
    });
  }

  void _takeDamage(int rawDmg) {
    final finalDmg = s.absorbDamage(rawDmg);
    setState(() {
      _hp = max(0, _hp - finalDmg);
      _showDamageBlood = true;
    });

    if (s.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }

    Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _showDamageBlood = false);
    });

    if (_hp <= 0) {
      s.addDeath();
      setState(() {
        _hp = 100;
        _kind = null;
      });
      _toast('Siz mag\'lub bo\'ldingiz! Baza sizni qayta tikladi.');
    }
  }

  void _playSound(String assetPath) {
    if (!s.soundEnabled) return;
    try {
      _audioPlayer.stop();
      _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  void _triggerHaptic({bool isKill = false, bool isHit = false}) {
    if (!s.vibrationEnabled) return;
    if (isKill) {
      HapticFeedback.vibrate();
    } else if (isHit) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _fire() {
    if (_isReloading) {
      _toast('O\'qlash jarayoni ketmoqda...');
      return;
    }
    if (_ammo <= 0) {
      _toast('O\'q tugadi! RELOAD tugmasini bosing.');
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastShotTime).inMilliseconds < s.weapon.fireRateMs) {
      return;
    }
    _lastShotTime = now;

    // Fire mechanics
    setState(() {
      _ammo--;
      // Recoil kickback (dampened when scoped)
      final recoilScale = 1.0 / max(1.0, _scopeZoom * 0.75);
      _recoilOffset = Offset(
        (_r.nextDouble() - 0.5) * s.weapon.recoil * recoilScale,
        -s.weapon.recoil * 1.5 * recoilScale,
      );
    });

    _playSound(s.weapon.soundAsset);
    _triggerHaptic();

    // Spring back recoil
    Timer(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _recoilOffset = Offset.zero);
    });

    // Crosshair Center Hit Test
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    if (_kind == Kind.enemy && _targetRect.contains(center)) {
      final isCrit = _r.nextDouble() < 0.25 || s.weapon.id == 'sniper';
      final dmg = isCrit ? (s.weapon.dmg * 1.5).round() : s.weapon.dmg;

      setState(() {
        _enemyHp -= dmg;
        _showHitmarker = true;
        _floatingDamageText = isCrit ? 'CRIT -$dmg' : '-$dmg';
      });

      _playSound('audio/hit.wav');
      _triggerHaptic(isHit: true);

      Timer(const Duration(milliseconds: 140), () {
        if (mounted) setState(() => _showHitmarker = false);
      });
      Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _floatingDamageText = null);
      });

      if (_enemyHp <= 0) {
        s.addKill();
        lan.reportKill(_enemyCategory.title);
        _triggerHaptic(isKill: true);
        setState(() => _kind = null);
        _toast('Dushman yo\'q qilindi! +15 XP, +10 Coin');
      }
    }
  }

  void _reload() {
    if (_isReloading) return;
    final needed = s.weapon.mag - _ammo;
    if (needed <= 0 || _reserve <= 0) return;

    setState(() {
      _isReloading = true;
      _reloadProgress = 0.0;
    });

    _playSound('audio/reload.wav');

    final durationMs = s.weapon.reloadMs;
    const stepMs = 50;
    final totalSteps = durationMs ~/ stepMs;
    int currentStep = 0;

    _reloadTimer?.cancel();
    _reloadTimer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      currentStep++;
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _reloadProgress = (currentStep / totalSteps).clamp(0.0, 1.0);
      });

      if (currentStep >= totalSteps) {
        t.cancel();
        final take = min(needed, _reserve);
        setState(() {
          _ammo += take;
          _reserve -= take;
          if (_reserve <= 0 && _ammo <= 0) _reserve = 60;
          _isReloading = false;
          _reloadProgress = 0.0;
        });
      }
    });
  }

  void _pickup() {
    if (_kind == Kind.medkit) {
      s.addMedkit();
      _toast('+1 Aptechka olindi');
    } else if (_kind == Kind.bandage) {
      s.addBandages(2);
      _toast('+2 Bog\'lam olindi');
    } else if (_kind == Kind.crate) {
      final res = s.openCrate();
      _toast('Sovg\'a qutisi: ${res['text']}');
    }
    setState(() => _kind = null);
  }

  void _healWithMedkit() {
    if (_hp >= 100) return;
    if (s.useMedkit()) {
      setState(() => _hp = min(100, _hp + 60));
      _toast('Aptechka ishlatildi (+60 HP)');
    } else {
      _toast('Aptechka yo\'q (Do\'kondan oling)');
    }
  }

  void _healWithBandage() {
    if (_hp >= 100) return;
    if (s.useBandage()) {
      setState(() => _hp = min(100, _hp + 25));
      _toast('Bog\'lam ishlatildi (+25 HP)');
    } else {
      _toast('Bog\'lam yo\'q');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: kCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _attackTimer?.cancel();
    _roundTickTimer?.cancel();
    _reloadTimer?.cancel();
    _cam?.stopImageStream().catchError((_) {});
    _cam?.dispose();
    _audioPlayer.dispose();
    DetectionService.i.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCenterLocked = _kind == Kind.enemy &&
        _targetRect.contains(Offset(size.width / 2, size.height / 2));

    return ListenableBuilder(
      listenable: Listenable.merge([s, lan.status, lan.killFeed, lan.matchRound]),
      builder: (_, __) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera feed or fallback tactical grid
            if (_cam != null && _cam!.value.isInitialized)
              CameraPreview(_cam!)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [Color(0xFF1A1A2E), Color(0xFF0A0A12)],
                  ),
                ),
              ),

            // Scope Overlay (1x / 2x / 4x sniper scope)
            if (_scopeZoom > 1.0) _buildScopeOverlay(size),

            // Blood vignette flash on taking damage
            if (_showDamageBlood)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kRed.withValues(alpha: 0.7), width: 14),
                  boxShadow: [
                    BoxShadow(color: kRed.withValues(alpha: 0.5), blurRadius: 40, spreadRadius: 10),
                  ],
                ),
              ),

            // Target overlay
            if (_kind != null)
              Positioned(
                left: _targetRect.left,
                top: _targetRect.top,
                width: _targetRect.width,
                height: _targetRect.height,
                child: _buildTargetWidget(),
              ),

            // Center Crosshair HUD with recoil
            Transform.translate(
              offset: _recoilOffset,
              child: Center(
                child: _buildCrosshair(isCenterLocked),
              ),
            ),

            // Floating Damage Text
            if (_floatingDamageText != null)
              Positioned(
                top: size.height / 2 - 60,
                left: size.width / 2 + 30,
                child: Text(
                  _floatingDamageText!,
                  style: GoogleFonts.robotoMono(
                    color: _floatingDamageText!.contains('CRIT') ? kOrange : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      const Shadow(color: Colors.black, blurRadius: 8),
                      Shadow(color: kRed.withValues(alpha: 0.8), blurRadius: 4),
                    ],
                  ),
                ),
              ),

            // Kill Feed (Top Right)
            Positioned(
              top: 70,
              right: 12,
              child: _buildKillFeed(),
            ),

            // Main UI Overlay
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  _buildBottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrosshair(bool isLocked) {
    final color = isLocked ? kRed : kCyan;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer Tactical Circle
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: isLocked ? 0.9 : 0.6),
              width: 1.5,
            ),
          ),
        ),
        // Center Target Dot
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color, blurRadius: isLocked ? 8 : 4),
            ],
          ),
        ),
        // Crosshair Lines
        Container(width: 1.5, height: 14, color: color),
        Container(width: 14, height: 1.5, color: color),

        // Hitmarker X
        if (_showHitmarker)
          Transform.rotate(
            angle: pi / 4,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 3.5, height: 28, color: kRed),
                  Container(width: 28, height: 3.5, color: kRed),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTargetWidget() {
    final isEnemy = _kind == Kind.enemy;
    final color = isEnemy
        ? (_isRealPerson ? kRed : _enemyCategory.color)
        : (_kind == Kind.medkit
            ? kGreen
            : (_kind == Kind.bandage ? kCyan : Colors.amber));

    final label = isEnemy
        ? (_isRealPerson
            ? 'HOSTILE DETECTED (${_targetDistance.toStringAsFixed(1)}m)'
            : _enemyCategory.title)
        : (_kind == Kind.medkit
            ? 'MEDKIT'
            : (_kind == Kind.bandage ? 'BANDAGE' : 'SUPPLY CRATE'));

    final icon = isEnemy
        ? (_isRealPerson ? Icons.person : _enemyCategory.icon)
        : (_kind == Kind.medkit
            ? Icons.medical_services
            : (_kind == Kind.bandage ? Icons.healing : Icons.inventory_2));

    return GestureDetector(
      onTap: isEnemy ? _fire : _pickup,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              label,
              style: GoogleFonts.robotoMono(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: _targetRect.width,
            height: _targetRect.height - 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          if (isEnemy) ...[
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (_enemyHp / _enemyMaxHp).clamp(0.0, 1.0),
                backgroundColor: Colors.black54,
                color: color,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    final ds = DetectionService.i;
    final isSlow = ds.isSlow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSlow ? kOrange : kCyan, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSlow ? Icons.warning_amber_rounded : Icons.speed,
            color: isSlow ? kOrange : kCyan,
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            isSlow
                ? 'Aniqlash sekin'
                : 'ML: ${ds.fps.toStringAsFixed(1)} FPS | ${ds.latencyMs}ms',
            style: GoogleFonts.robotoMono(
              color: isSlow ? kOrange : kCyan,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeOverlay(Size size) {
    if (_scopeZoom <= 1.0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        children: [
          // Dark Vignette outside circular lens
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.72,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.88),
                ],
                stops: const [0.55, 0.75, 1.0],
              ),
            ),
          ),
          // Scope Ring and Mil-dots
          Center(
            child: Container(
              width: size.width * 0.85,
              height: size.width * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kCyan.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 1, height: size.width * 0.85, color: kCyan.withValues(alpha: 0.35)),
                  Container(width: size.width * 0.85, height: 1, color: kCyan.withValues(alpha: 0.35)),
                  Positioned(
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kCyan, width: 0.8),
                      ),
                      child: Text(
                        'SCOPE ${_scopeZoom.toStringAsFixed(0)}X',
                        style: GoogleFonts.robotoMono(
                          color: kCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    Color statusDotColor;
    switch (lan.status.value) {
      case ConnectionStatus.connected:
        statusDotColor = kGreen;
        break;
      case ConnectionStatus.reconnecting:
        statusDotColor = kOrange;
        break;
      case ConnectionStatus.offline:
        statusDotColor = Colors.grey;
        break;
    }

    final round = lan.matchRound.value;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Connection status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusDotColor,
              boxShadow: [
                BoxShadow(color: statusDotColor, blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${tierOf(s.xp)} • LVL ${levelOf(s.xp)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tierColor(tierOf(s.xp)),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          if (round != null && round.active) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kOrange),
              ),
              child: Text(
                'TDM: ${round.remainingSeconds}s',
                style: GoogleFonts.robotoMono(
                  color: kOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (s.debugOverlayEnabled) ...[
            _buildDebugOverlay(),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.monetization_on, color: kOrange, size: 16),
          const SizedBox(width: 4),
          Text(
            '${s.coins}',
            style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(
            s.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildKillFeed() {
    final list = lan.killFeed.value;
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: list.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            item,
            style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 11),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // HP, Armor, Ammo Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      s.weapon.name,
                      style: TextStyle(color: s.weapon.color, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: s.weapon.rarity.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.weapon.rarity.label,
                        style: TextStyle(color: s.weapon.rarity.color, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // HP Bar
                Row(
                  children: [
                    Text('HP $_hp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    // Medkit
                    InkWell(
                      onTap: _healWithMedkit,
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services, size: 14, color: kGreen),
                          Text(' ${s.medkits} ', style: const TextStyle(fontSize: 11, color: kGreen)),
                        ],
                      ),
                    ),
                    // Bandage
                    InkWell(
                      onTap: _healWithBandage,
                      child: Row(
                        children: [
                          const Icon(Icons.healing, size: 14, color: kCyan),
                          Text(' ${s.bandages}', style: const TextStyle(fontSize: 11, color: kCyan)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_hp / 100).clamp(0.0, 1.0),
                    color: _hp < 30 ? kRed : kCyan,
                    backgroundColor: Colors.white12,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),

                // Armor Bar
                Row(
                  children: [
                    const Icon(Icons.shield, size: 12, color: Colors.purpleAccent),
                    const SizedBox(width: 4),
                    Text('Zirh ${s.armor}%', style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)),
                  ],
                ),
                const SizedBox(height: 6),

                // Ammo numbers
                Text(
                  '$_ammo / $_reserve',
                  style: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Scope Toggle Button (1X / 2X / 4X)
          OutlinedButton(
            onPressed: _toggleScope,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(54, 54),
              shape: const CircleBorder(),
              side: BorderSide(
                color: _scopeZoom > 1.0 ? kCyan : Colors.white24,
                width: _scopeZoom > 1.0 ? 2 : 1,
              ),
              backgroundColor: _scopeZoom > 1.0
                  ? kCyan.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Text(
              '${_scopeZoom.toStringAsFixed(0)}X',
              style: GoogleFonts.robotoMono(
                color: _scopeZoom > 1.0 ? kCyan : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Reload Button with Animated Circular Progress
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: _isReloading ? _reloadProgress : 0.0,
                  strokeWidth: 3,
                  backgroundColor: Colors.white10,
                  color: kPurple,
                ),
              ),
              OutlinedButton(
                onPressed: _reload,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(54, 54),
                  shape: const CircleBorder(),
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Icon(Icons.rotate_right, size: 22, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Fire Button
          FilledButton(
            onPressed: _fire,
            style: FilledButton.styleFrom(
              backgroundColor: kOrange,
              foregroundColor: Colors.black,
              minimumSize: const Size(82, 82),
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: kOrange.withValues(alpha: 0.5),
            ),
            child: Text(
              'FIRE',
              style: GoogleFonts.robotoMono(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
