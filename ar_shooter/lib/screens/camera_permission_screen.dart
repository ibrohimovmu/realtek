import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

class CameraPermissionScreen extends StatefulWidget {
  final Widget child;
  const CameraPermissionScreen({super.key, required this.child});

  @override
  State<CameraPermissionScreen> createState() => _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen> with WidgetsBindingObserver {
  bool _granted = false;
  bool _permanentlyDenied = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _granted = status.isGranted;
        _permanentlyDenied = status.isPermanentlyDenied;
        _checking = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _granted = status.isGranted;
        _permanentlyDenied = status.isPermanentlyDenied;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(
          child: CircularProgressIndicator(color: kPurple),
        ),
      );
    }

    if (_granted) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: kPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: kPurple, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: kPurple, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                'Kamera Ruxsati Talab Qilinadi',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _permanentlyDenied
                    ? 'Kameraga ruxsat berilmadi. AR nishonlarni ko\'rish va jang qilish uchun ilova sozlamalaridan kamera ruxsatini yoqing.'
                    : 'Real hayotda do\'stlaringiz va nishonlar bilan AR Laser Tag jangini boshlash uchun telefon kamerasi kerak bo\'ladi. Hech qanday video saqlanmaydi.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              if (_permanentlyDenied) ...[
                FilledButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Sozlamalarni Ochish'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _checkPermission,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Qayta Tekshirish'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Kameraga Ruxsat Berish'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
