import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_info.dart';

/// Big clock + week strip + date badge, as in the reference screenshot.
class ClockHeader extends StatefulWidget {
  final Color ink;
  final Color muted;
  const ClockHeader({super.key, required this.ink, required this.muted});

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
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      if (n.minute != _now.minute || n.day != _now.day) {
        setState(() => _now = n);
        _pulse.forward(from: 0);
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
    final time = '${LauncherLogic.two(_now.hour)}:${LauncherLogic.two(_now.minute)}';
    final strip = LauncherLogic.weekStrip(_now);
    final today = LauncherLogic.weekdayFull[_now.weekday - 1];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Time with per-digit rolling animation
        FadeTransition(
          opacity: _interval(0.0, 0.5),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(_interval(0.0, 0.5)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < time.length; i++)
                  _RollingChar(char: time[i], color: widget.ink, key: ValueKey('c$i')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Week strip
        FadeTransition(
          opacity: _interval(0.25, 0.75),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final d in strip.before) _day(d),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: c),
                ),
                child: Text(
                  today,
                  key: ValueKey(today),
                  style: TextStyle(
                    color: widget.muted,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              for (final d in strip.after) _day(d),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Lines growing from the centre + date badge
        SizedBox(
          width: 320,
          height: 24,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _pulse]),
            builder: (context, _) {
              final grow = _interval(0.4, 1.0).value;
              final pulse = Curves.easeOut.transform(_pulse.value);
              final badgeScale = 1.0 + 0.18 * (1 - (2 * pulse - 1).abs());
              return Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: grow,
                        child: Container(height: 1, color: widget.muted.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: grow * badgeScale,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: widget.ink, shape: BoxShape.circle),
                      child: Text(
                        LauncherLogic.two(_now.day),
                        style: TextStyle(
                          color: widget.ink.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
                        child: Container(height: 1, color: widget.muted.withValues(alpha: 0.6)),
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

  Widget _day(String d) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Text(d, style: TextStyle(color: widget.ink.withValues(alpha: 0.75), fontSize: 11)),
      );
}

/// A single clock character that rolls up when it changes.
class _RollingChar extends StatelessWidget {
  final String char;
  final Color color;
  const _RollingChar({super.key, required this.char, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: 46,
      fontWeight: FontWeight.w400,
      height: 1.1,
      letterSpacing: -0.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 550),
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
