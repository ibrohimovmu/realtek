import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

class ClockHeader extends StatefulWidget {
  final LauncherStore store;

  const ClockHeader({super.key, required this.store});

  @override
  State<ClockHeader> createState() => _ClockHeaderState();
}

class _ClockHeaderState extends State<ClockHeader>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _isEditingNote = false;
  late TextEditingController _noteController;
  late AnimationController _waveCtrl;
  bool _musicPlayingVisual = false;

  static const _shortDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _fullDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _uzMonths = [
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.store.dailyNote);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _waveCtrl.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatHour() {
    int h = _now.hour;
    if (!widget.store.use24HourFormat) {
      h = h % 12;
      if (h == 0) h = 12;
    }
    return h.toString().padLeft(2, '0');
  }

  String _formatMinute() => _now.minute.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final fg = store.foregroundColor;
    final sub = store.subtleTextColor;
    final scale = store.clockScale;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Clock Display
        switch (store.clockStyle) {
          ClockStyle.editorialRibbon => _buildEditorialRibbon(fg, sub, scale),
          ClockStyle.bauhausSplit => _buildBauhausSplit(fg, sub, scale),
          ClockStyle.neonMatrix => _buildNordicSlateMatrix(fg, sub, scale),
          ClockStyle.minimalZen => _buildMinimalZen(fg, sub, scale),
          ClockStyle.analogChrono => _buildAnalogChrono(fg, sub, scale),
        },

        // Status & Weather / Battery / Temp Pill Row
        if (store.showStatusPill || store.showDailyNoteWidget) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (store.showStatusPill) _buildTelemetryPill(store, fg, sub),
                if (store.showDailyNoteWidget) _buildDailyNotePill(store, fg, sub),
              ],
            ),
          ),
        ],

        // Minimalist Music Player Strip + Interactive Calendar Trigger
        if (store.showMusicWidget || store.showCalendarWidget) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                if (store.showMusicWidget)
                  Expanded(child: _buildMinimalMusicBar(store, fg, sub)),
                if (store.showMusicWidget && store.showCalendarWidget)
                  const SizedBox(width: 8),
                if (store.showCalendarWidget)
                  _buildCalendarQuickButton(store, fg, sub),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMinimalMusicBar(LauncherStore store, Color fg, Color sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1D21).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF677E8A).withValues(alpha: 0.28),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          // Animated Slate Soundwave Equalizer
          SizedBox(
            width: 20,
            height: 16,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(4, (i) {
                    final activeH = _musicPlayingVisual
                        ? (4.0 +
                            11.0 *
                                (0.5 +
                                    0.5 *
                                        math.sin(
                                          _waveCtrl.value * math.pi * 2 +
                                              i * 1.3,
                                        )))
                        : 5.0 + (i.isEven ? 3.0 : 0.0);
                    return Container(
                      width: 3,
                      height: activeH,
                      decoration: BoxDecoration(
                        color: _musicPlayingVisual
                            ? const Color(0xFFE0B4B2)
                            : const Color(0xFF677E8A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _musicPlayingVisual ? 'Media ijro etilmoqda' : 'Media pleyer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFABAFB5),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _mediaIconBtn(
            icon: Icons.skip_previous_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              store.mediaControl('previous');
            },
          ),
          const SizedBox(width: 4),
          _mediaIconBtn(
            icon: _musicPlayingVisual
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            highlight: true,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _musicPlayingVisual = !_musicPlayingVisual);
              store.mediaControl('play_pause');
            },
          ),
          const SizedBox(width: 4),
          _mediaIconBtn(
            icon: Icons.skip_next_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              store.mediaControl('next');
            },
          ),
        ],
      ),
    );
  }

  Widget _mediaIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFF677E8A).withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFFABAFB5),
        ),
      ),
    );
  }

  Widget _buildCalendarQuickButton(LauncherStore store, Color fg, Color sub) {
    final monthName = _uzMonths[_now.month - 1];
    return GestureDetector(
      onTap: () => _openFullCalendarModal(context, store),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1D21).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF677E8A).withValues(alpha: 0.28),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: Color(0xFF677E8A),
            ),
            const SizedBox(width: 6),
            Text(
              '${_now.day} $monthName',
              style: const TextStyle(
                color: Color(0xFFABAFB5),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullCalendarModal(BuildContext context, LauncherStore store) {
    HapticFeedback.lightImpact();
    final firstDayOfMonth = DateTime(_now.year, _now.month, 1);
    final daysInMonth = DateTime(_now.year, _now.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Mon .. 7 = Sun

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1D21),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.30),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF677E8A).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_uzMonths[_now.month - 1].toUpperCase()} ${_now.year}',
                      style: const TextStyle(
                        color: Color(0xFFABAFB5),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF122E34),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bugun: ${_now.day}-${_uzMonths[_now.month - 1]}',
                        style: const TextStyle(
                          color: Color(0xFF677E8A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const ['DU', 'SE', 'CH', 'PA', 'JU', 'SH', 'YA']
                      .map(
                        (d) => SizedBox(
                          width: 36,
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                color: Color(0xFF677E8A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: (startWeekday - 1) + daysInMonth,
                  itemBuilder: (context, idx) {
                    if (idx < startWeekday - 1) {
                      return const SizedBox.shrink();
                    }
                    final dayNum = idx - (startWeekday - 1) + 1;
                    final isToday = dayNum == _now.day;
                    return Container(
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFF677E8A)
                            : const Color(0xFF122E34).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFF0E1D21)
                                : const Color(0xFFABAFB5),
                            fontSize: 12.5,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryPill(LauncherStore store, Color fg, Color sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1D21).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF677E8A).withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            store.isCharging
                ? Icons.bolt_rounded
                : Icons.battery_std_rounded,
            size: 13,
            color: const Color(0xFFABAFB5),
          ),
          const SizedBox(width: 4),
          Text(
            '${store.batteryLevel}%',
            style: const TextStyle(
              color: Color(0xFFABAFB5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: Color(0xFF677E8A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${store.deviceTempC.toStringAsFixed(0)}°C • RAM ${store.ramUsedPercent}%',
            style: const TextStyle(
              color: Color(0xFF677E8A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyNotePill(LauncherStore store, Color fg, Color sub) {
    if (_isEditingNote) {
      return Container(
        width: 210,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1D21).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFABAFB5).withValues(alpha: 0.4),
          ),
        ),
        child: TextField(
          controller: _noteController,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFABAFB5), fontSize: 11.5),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 6),
          ),
          onSubmitted: (v) {
            final clean = v.trim().isEmpty ? 'Kunlik maqsad' : v.trim();
            store.updateSetting(() => store.dailyNote = clean);
            setState(() => _isEditingNote = false);
          },
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _noteController.text = store.dailyNote;
        setState(() => _isEditingNote = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1D21).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF677E8A).withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.edit_note_rounded,
              size: 13,
              color: Color(0xFF677E8A),
            ),
            const SizedBox(width: 4),
            Text(
              store.dailyNote,
              style: const TextStyle(
                color: Color(0xFFABAFB5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Style 1: Exact Editorial Ribbon from the user's screenshot (20:43 + wed thu fri Saturday sun mon tue + 09 badge)
  Widget _buildEditorialRibbon(Color fg, Color sub, double scale) {
    final currentIdx = _now.weekday - 1;
    final dayNumber = _now.day.toString().padLeft(2, '0');

    final List<Widget> dayItems = [];
    for (int offset = -3; offset <= 3; offset++) {
      final idx = (currentIdx + offset + 7) % 7;
      if (offset == 0) {
        dayItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _fullDays[idx],
              style: TextStyle(
                fontSize: 15 * scale,
                fontWeight: FontWeight.w500,
                color: fg.withValues(alpha: 0.88),
                letterSpacing: 0.3,
              ),
            ),
          ),
        );
      } else {
        dayItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              _shortDays[idx],
              style: TextStyle(
                fontSize: 11.5 * scale,
                fontWeight: FontWeight.w500,
                color: sub,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatHour()}:${_formatMinute()}',
          style: TextStyle(
            fontSize: 48 * scale,
            fontWeight: FontWeight.w400,
            color: fg,
            letterSpacing: -0.5,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: dayItems,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 0.9,
                  color: fg.withValues(alpha: 0.28),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 25 * scale,
                  height: 25 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1D21),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fg.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    dayNumber,
                    style: TextStyle(
                      fontSize: 10.5 * scale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFABAFB5),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 0.9,
                  color: fg.withValues(alpha: 0.28),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Style 2: Bauhaus Split Typography
  Widget _buildBauhausSplit(Color fg, Color sub, double scale) {
    final dayName = _fullDays[_now.weekday - 1].toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _formatHour(),
            style: TextStyle(
              fontSize: 56 * scale,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 0.95,
              letterSpacing: -2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 3,
              height: 44 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFF677E8A),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMinute(),
                style: TextStyle(
                  fontSize: 28 * scale,
                  fontWeight: FontWeight.w300,
                  color: fg.withValues(alpha: 0.9),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$dayName • ${_now.day}',
                style: TextStyle(
                  fontSize: 10.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: sub,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Style 3: Nordic Slate Matrix Card (#0E1D21 & #122E34 & #677E8A)
  Widget _buildNordicSlateMatrix(Color fg, Color sub, double scale) {
    final dayName = _fullDays[_now.weekday - 1].toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1D21).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF677E8A).withValues(alpha: 0.35),
          width: 1.1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatHour()} : ${_formatMinute()}',
            style: TextStyle(
              fontSize: 38 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFABAFB5),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$dayName  //  ${_now.day}.${_now.month.toString().padLeft(2, '0')}.${_now.year}',
            style: TextStyle(
              fontSize: 10 * scale,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF677E8A),
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Style 4: Minimal Zen
  Widget _buildMinimalZen(Color fg, Color sub, double scale) {
    final dayName = _fullDays[_now.weekday - 1];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatHour()}:${_formatMinute()}',
          style: TextStyle(
            fontSize: 52 * scale,
            fontWeight: FontWeight.w200,
            color: fg,
            letterSpacing: 2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$dayName, ${_now.day}',
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w400,
            color: sub,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  /// Style 5: Analog Chrono Dial
  Widget _buildAnalogChrono(Color fg, Color sub, double scale) {
    final size = 96.0 * scale;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _AnalogClockPainter(now: _now, color: fg, subtle: sub),
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_formatHour()}:${_formatMinute()}',
              style: TextStyle(
                fontSize: 32 * scale,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            Text(
              '${_fullDays[_now.weekday - 1]} • ${_now.day}',
              style: TextStyle(
                fontSize: 12 * scale,
                color: sub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime now;
  final Color color;
  final Color subtle;

  _AnalogClockPainter({
    required this.now,
    required this.color,
    required this.subtle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = subtle.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius - 2, ringPaint);

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final outer = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - (i % 3 == 0 ? 11 : 8)) * math.cos(angle),
        center.dy + (radius - (i % 3 == 0 ? 11 : 8)) * math.sin(angle),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = i % 3 == 0 ? color : subtle
          ..strokeWidth = i % 3 == 0 ? 2.0 : 1.0,
      );
    }

    final hourAngle =
        ((now.hour % 12 + now.minute / 60.0) * 30 - 90) * math.pi / 180;
    final minAngle = ((now.minute + now.second / 60.0) * 6 - 90) * math.pi / 180;
    final secAngle = (now.second * 6 - 90) * math.pi / 180;

    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.46 * math.cos(hourAngle),
        center.dy + radius * 0.46 * math.sin(hourAngle),
      ),
      Paint()
        ..color = color
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.68 * math.cos(minAngle),
        center.dy + radius * 0.68 * math.sin(minAngle),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * 0.74 * math.cos(secAngle),
        center.dy + radius * 0.74 * math.sin(secAngle),
      ),
      Paint()
        ..color = const Color(0xFFE0B4B2)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 3.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) =>
      oldDelegate.now.second != now.second || oldDelegate.color != color;
}
