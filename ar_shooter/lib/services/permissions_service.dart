import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

class PermissionsService {
  PermissionsService._();
  static final PermissionsService i = PermissionsService._();

  /// Requests location permission with an Uzbek explanation dialog.
  /// Location is only requested when GPS aiming or bomb mode is activated.
  Future<bool> requestLocationPermission(BuildContext context) async {
    final currentStatus = await Permission.location.status;
    if (currentStatus.isGranted) {
      return true;
    }

    if (!context.mounted) return false;

    // Show friendly explanation modal
    final shouldRequest = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: kOrange, width: 2),
              ),
              child: const Icon(Icons.location_on, color: kOrange, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'GPS Joylashuv Ruxsati',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'GPS nishonlash va Bomba rejimida raqiblar masofasi hamda yo\'nalishini hisoblash uchun joylashuv ruxsati kerak bo\'ladi.\n\n'
              '🔒 Maxfiylik: Geopozitsiyangiz faqat o\'yin xonasidagi ishtirokchilar bilan ulashiladi va xonadan chiqqach uzatish darhol to\'xtatiladi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Bekor qilish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Ruxsat berish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (shouldRequest != true) return false;

    final result = await Permission.location.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sozlamalarni Ochish Talab Qilinadi'),
          content: const Text(
            'GPS ruxsati rad etilgan. Funksiyadan foydalanish uchun sozlamalardan ruxsatni yoqing.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Yopish'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Sozlamalarni Ochish'),
            ),
          ],
        ),
      );
    }

    return false;
  }
}
