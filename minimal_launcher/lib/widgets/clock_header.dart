import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Multi-style Clock & Home Widget Header supporting 6 distinct clock aesthetics
/// plus optional System Pulse (Battery/RAM) and Daily Focus Note widgets.
class ClockHeader extends StatefulWidget {
  final Color ink;
  final Color muted;
  final VoidCallback? onTapClock;

  const ClockHeader({
    super.key,
    required this.ink,
    required this.muted,
    this.onTapClock,
  });

  @override
  State<ClockHeader> createState() => _ClockHeaderState();
}

class _ClockHeaderState extends State<ClockHeader> with TickerProviderStateMixin {
  late DateTime _now;
  Timer? _timer;
  late final AnimationController _intro;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      final minChanged = n.minute != _now.minute;
      if (mounted) {
        setState(() => _now = n);
        if (minChanged) _pulse.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b) =>
      CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    final store = LauncherStore.i;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            if (widget.onTapClock != null) {
              widget.onTapClock!();
            } else {
              // Cycle to next clock style on double/quick tap if desired
              final nextIdx = (store.clockStyle.index + 1) % ClockStyle.values.length;
              store.setClockStyle(ClockStyle.values[nextIdx]);
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            child: _buildSelectedClock(store.clockStyle, store),
          ),
        ),

        // Optional System Telemetry Pulse Pill (Battery + RAM)
        if (store.showSystemPulse && store.clockStyle != ClockStyle.cyber) ...[
          const SizedBox(height: 8),
          _buildSystemPulsePill(store),
        ],

        // Optional Daily Focus / Quick Note Widget
        if (store.showQuickNote) ...[
          const SizedBox(height: 6),
          _buildQuickNotePill(context, store),
        ],
      ],
    );
  }

  Widget _buildSelectedClock(ClockStyle style, LauncherStore store) {
    switch (style) {
      case ClockStyle.reference:
        return _buildReferenceClock();
      case ClockStyle.flip:
        return _buildFlipClock();
      case ClockStyle.analog:
        return _buildAnalogClock();
      case ClockStyle.editorial:
        return _buildEditorialClock();
      case ClockStyle.cyber:
        return _buildCyberClock(store);
      case ClockStyle.glassPill:
        return _buildGlassPillClock(store);
    }
  }

  // 1. Reference Screenshot Clock (20:43 + wed thu fri Saturday + line & circle badge)
  Widget _buildReferenceClock() {
    final time = '${LauncherLogic.two(_now.hour)}:${LauncherLogic.two(_now.minute)}';
    final strip = LauncherLogic.weekStrip(_now);
    final today = LauncherLogic.weekdayFull[_now.weekday - 1];

    return Column(
      key: const ValueKey('clock_ref'),
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _interval(0.0, 0.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < time.length; i++)
                _RollingChar(char: time[i], color: widget.ink, key: ValueKey('c$i')),
            ],
          ),
        ),
        const SizedBox(height: 5),
        FadeTransition(
          opacity: _interval(0.25, 0.75),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in strip.before) _day(d),
              const SizedBox(width: 10),
              Text(
                today,
                style: TextStyle(
                  color: widget.muted,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              for (final d in strip.after) _day(d),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 310,
          height: 22,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _pulse]),
            builder: (context, _) {
              final grow = _interval(0.4, 1.0).value;
              final pulse = Curves.easeOut.transform(_pulse.value);
              final badgeScale = 1.0 + 0.16 * (1 - (2 * pulse - 1).abs());
              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: grow,
                        child: Container(height: 1, color: widget.muted.withValues(alpha: 0.55)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: grow * badgeScale,
                    child: Container(
                      width: 21,
                      height: 21,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: widget.ink, shape: BoxShape.circle),
                      child: Text(
                        LauncherLogic.two(_now.day),
                        style: TextStyle(
                          color: widget.ink.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: grow,
                        child: Container(height: 1, color: widget.muted.withValues(alpha: 0.55)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. 3D Retro Mechanical Flip Clock
  Widget _buildFlipClock() {
    final hh = LauncherLogic.two(_now.hour);
    final mm = LauncherLogic.two(_now.minute);
    final ss = LauncherLogic.two(_now.second);
    final today = LauncherLogic.weekdayFull[_now.weekday - 1];

    return Column(
      key: const ValueKey('clock_flip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _flipCard(hh),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
              child: Text(
                ':',
                style: TextStyle(color: widget.ink, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            _flipCard(mm),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                ss,
                style: TextStyle(
                  color: widget.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${today.toUpperCase()}  •  ${LauncherLogic.two(_now.day)}.${LauncherLogic.two(_now.month)}.${_now.year}',
          style: TextStyle(
            color: widget.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _flipCard(String digits) {
    return Container(
      width: 68,
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2327),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            digits,
            style: const TextStyle(
              color: Color(0xFFF3F4F6),
              fontSize: 34,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          // Split-flap horizontal crease line
          Container(
            height: 1.2,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }

  // 3. Bauhaus Minimalist Analog Watch
  Widget _buildAnalogClock() {
    final today = LauncherLogic.weekdayShort[_now.weekday - 1].toUpperCase();
    return Row(
      key: const ValueKey('clock_analog'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: CustomPaint(
            painter: _BauhausAnalogPainter(now: _now, ink: widget.ink, muted: widget.muted),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${LauncherLogic.two(_now.hour)}:${LauncherLogic.two(_now.minute)}',
              style: TextStyle(
                color: widget.ink,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '$today, ${LauncherLogic.two(_now.day)}-${LauncherLogic.two(_now.month)}',
              style: TextStyle(
                color: widget.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Giant Editorial Stacked Clock
  Widget _buildEditorialClock() {
    final hh = LauncherLogic.two(_now.hour);
    final mm = LauncherLogic.two(_now.minute);
    final today = LauncherLogic.weekdayFull[_now.weekday - 1];

    return Row(
      key: const ValueKey('clock_editorial'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hh,
              style: TextStyle(
                color: widget.ink,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                height: 0.92,
                letterSpacing: -1,
              ),
            ),
            Text(
              mm,
              style: TextStyle(
                color: widget.ink.withValues(alpha: 0.55),
                fontSize: 38,
                fontWeight: FontWeight.w300,
                height: 0.95,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Container(width: 1.5, height: 54, color: widget.ink.withValues(alpha: 0.25)),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              today.toUpperCase(),
              style: TextStyle(
                color: widget.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${LauncherLogic.two(_now.day)} / ${LauncherLogic.two(_now.month)} / ${_now.year}',
              style: TextStyle(color: widget.muted, fontSize: 11.5),
            ),
          ],
        ),
      ],
    );
  }

  // 5. Cyber HUD Clock
  Widget _buildCyberClock(LauncherStore store) {
    final time = '${LauncherLogic.two(_now.hour)}:${LauncherLogic.two(_now.minute)}:${LauncherLogic.two(_now.second)}';
    final secFrac = _now.second / 60.0;

    return Container(
      key: const ValueKey('clock_cyber'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.ink.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SYS//TIME ',
                style: TextStyle(
                  color: widget.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  color: widget.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 190,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: secFrac,
                minHeight: 2.5,
                backgroundColor: widget.ink.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(widget.ink.withValues(alpha: 0.8)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'BAT ${store.batteryLevel}%${store.isCharging ? "⚡" : ""}  |  RAM ${store.ramPercent}%  |  ${LauncherLogic.two(_now.day)}.${LauncherLogic.two(_now.month)}',
            style: TextStyle(
              color: widget.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // 6. Frosted Glass Pill Clock
  Widget _buildGlassPillClock(LauncherStore store) {
    final time = '${LauncherLogic.two(_now.hour)}:${LauncherLogic.two(_now.minute)}';
    final today = LauncherLogic.weekdayFull[_now.weekday - 1];

    return ClipRRect(
      key: const ValueKey('clock_glass'),
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: widget.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: widget.ink.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: widget.ink,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 28, color: widget.ink.withValues(alpha: 0.22)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    today,
                    style: TextStyle(
                      color: widget.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${LauncherLogic.two(_now.day)}-kun • ${store.batteryLevel}% 🔋',
                    style: TextStyle(color: widget.muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemPulsePill(LauncherStore store) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: widget.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            store.isCharging ? Icons.bolt_rounded : Icons.battery_std_rounded,
            size: 13,
            color: widget.ink.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 3),
          Text(
            '${store.batteryLevel}%',
            style: TextStyle(
              color: widget.ink.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.memory_rounded, size: 13, color: widget.ink.withValues(alpha: 0.75)),
          const SizedBox(width: 3),
          Text(
            'RAM ${store.ramPercent}%',
            style: TextStyle(
              color: widget.ink.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (store.incognitoMode) ...[
            const SizedBox(width: 10),
            Icon(Icons.visibility_off_rounded, size: 12, color: widget.ink.withValues(alpha: 0.85)),
            const SizedBox(width: 3),
            Text(
              'Maxfiy',
              style: TextStyle(
                color: widget.ink.withValues(alpha: 0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickNotePill(BuildContext context, LauncherStore store) {
    return GestureDetector(
      onTap: () => _editNoteDialog(context, store),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: widget.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.ink.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded, size: 14, color: widget.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                store.quickNoteText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.ink.withValues(alpha: 0.82),
                  fontSize: 11.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editNoteDialog(BuildContext context, LauncherStore store) {
    final ctrl = TextEditingController(text: store.quickNoteText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202429),
        title: const Text('Eslatma vidjeti', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Eslatma yozing...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              store.setQuickNoteText(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  Widget _day(String d) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(d, style: TextStyle(color: widget.ink.withValues(alpha: 0.75), fontSize: 11)),
      );
}

class _BauhausAnalogPainter extends CustomPainter {
  final DateTime now;
  final Color ink;
  final Color muted;

  _BauhausAnalogPainter({required this.now, required this.ink, required this.muted});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    // Dial ring
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = ink.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 12 hour markers
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final inner = i % 3 == 0 ? r - 7 : r - 4;
      canvas.drawLine(
        c + Offset(cos(a) * inner, sin(a) * inner),
        c + Offset(cos(a) * (r - 1.5), sin(a) * (r - 1.5)),
        Paint()
          ..color = ink.withValues(alpha: i % 3 == 0 ? 0.85 : 0.38)
          ..strokeWidth = i % 3 == 0 ? 1.8 : 1.0,
      );
    }

    final hourAngle = ((now.hour % 12) + now.minute / 60.0) * pi / 6 - pi / 2;
    final minAngle = (now.minute + now.second / 60.0) * pi / 30 - pi / 2;
    final secAngle = now.second * pi / 30 - pi / 2;

    // Hour hand
    canvas.drawLine(
      c,
      c + Offset(cos(hourAngle) * r * 0.50, sin(hourAngle) * r * 0.50),
      Paint()
        ..color = ink
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    // Minute hand
    canvas.drawLine(
      c,
      c + Offset(cos(minAngle) * r * 0.74, sin(minAngle) * r * 0.74),
      Paint()
        ..color = ink
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // Bauhaus orange-red second hand
    canvas.drawLine(
      c - Offset(cos(secAngle) * 5, sin(secAngle) * 5),
      c + Offset(cos(secAngle) * r * 0.82, sin(secAngle) * r * 0.82),
      Paint()
        ..color = const Color(0xFFE0533C)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFE0533C));
  }

  @override
  bool shouldRepaint(covariant _BauhausAnalogPainter old) =>
      old.now.second != now.second || old.ink != ink;
}

class _RollingChar extends StatelessWidget {
  final String char;
  final Color color;
  const _RollingChar({super.key, required this.char, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: 44,
      fontWeight: FontWeight.w400,
      height: 1.08,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) {
          final incoming = child.key == ValueKey(char);
          final offset = Tween<Offset>(
            begin: incoming ? const Offset(0, 1) : const Offset(0, -1),
            end: Offset.zero,
          ).animate(anim);
          return SlideTransition(position: offset, child: FadeTransition(opacity: anim, child: child));
        },
        child: Text(char, key: ValueKey(char), style: style),
      ),
    );
  }
}
