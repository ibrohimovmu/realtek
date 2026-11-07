import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_launcher/models/app_info.dart';
import 'package:minimal_launcher/services/ai_assistant_service.dart';
import 'package:minimal_launcher/services/launcher_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nova AI Autonomous Local Command Parser (v4.0)', () {
    test('parses Instagram Direct messaging command in Uzbek', () {
      final res = AiAssistantService.parseLocalCommand(
        'Instagramga kirib Sardorga bugun soat 7 da ko\'rishamiz deb yoz',
      );
      expect(res, isNotNull);
      expect(res!['action'], equals('send_instagram'));
      expect(res['recipient'], equals('Sardor'));
      expect(res['message'], equals('bugun soat 7 da ko\'rishamiz'));
    });

    test('parses Telegram messaging command in Uzbek', () {
      final res = AiAssistantService.parseLocalCommand(
        'Telegramdan Akmalga 10 daqiqada boraman deb yoz',
      );
      expect(res, isNotNull);
      expect(res!['action'], equals('send_telegram'));
      expect(res['recipient'], equals('Akmal'));
      expect(res['message'], equals('10 daqiqada boraman'));
    });

    test('parses WhatsApp messaging command in Uzbek', () {
      final res = AiAssistantService.parseLocalCommand(
        'WhatsAppdan Jasurga hujjatlar tayyor deb yozib yubor',
      );
      expect(res, isNotNull);
      expect(res!['action'], equals('send_whatsapp'));
      expect(res['recipient'], equals('Jasur'));
      expect(res['message'], equals('hujjatlar tayyor'));
    });

    test('parses Lock-Screen unlock and Game Hub RAM boost commands', () {
      final unlock = AiAssistantService.parseLocalCommand(
        'Telefon qulfini och',
      );
      expect(unlock?['action'], equals('unlock_screen'));

      final boost = AiAssistantService.parseLocalCommand(
        'RAM xotirani tozalab tezlashtir',
      );
      expect(boost?['action'], equals('boost_ram'));
    });

    test('parses flashlight, volume, and alarm commands', () {
      final flash = AiAssistantService.parseLocalCommand('Fonarikni yoq');
      expect(flash?['action'], equals('set_flashlight'));
      expect(flash?['enabled'], isTrue);

      final vol = AiAssistantService.parseLocalCommand('Ovozni 80 foiz qil');
      expect(vol?['action'], equals('set_volume'));
      expect(vol?['percent'], equals(80));

      final alarm = AiAssistantService.parseLocalCommand(
        'Soat 07:30 ga budilnik qo\'y',
      );
      expect(alarm?['action'], equals('set_alarm'));
      expect(alarm?['hour'], equals(7));
      expect(alarm?['minute'], equals(30));
    });
  });

  group('Nordic Slate Store, Palette, Game Hub & Vault Security', () {
    test('verifies Nordic Slate palette, vertical stack & Game Hub state', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LauncherStore();
      await store.init();

      // Verify exact Nordic Slate hex swatches (#0E1D21, #122E34, #677E8A, #ABAFB5, #622347, #E0B4B2)
      expect(NordicPalette.obsidianTealHex, equals(0xFF0E1D21));
      expect(NordicPalette.abyssalTealHex, equals(0xFF122E34));
      expect(NordicPalette.steelSlateHex, equals(0xFF677E8A));
      expect(NordicPalette.silverMistHex, equals(0xFFABAFB5));
      expect(NordicPalette.mutedPlumHex, equals(0xFF622347));
      expect(NordicPalette.roseSilverHex, equals(0xFFE0B4B2));

      // Verify default straight vertical stack (0.0 curvature, no forced half-moon)
      expect(store.wheelCurvature, equals(0.0));
      expect(store.iconStyle, equals(IconPackStyle.monochromeDisc));
      expect(store.visibleApps, isNotEmpty);

      // Verify Game Hub & App Vault lock toggling
      final firstPkg = store.visibleApps.first.package;
      store.toggleGameApp(firstPkg);
      expect(store.gameApps.any((a) => a.package == firstPkg), isTrue);

      store.toggleLockApp(firstPkg);
      expect(store.isLocked(firstPkg), isTrue);
    });
  });
}
