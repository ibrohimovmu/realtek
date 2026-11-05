import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/camera_permission_screen.dart';
import 'screens/onboarding.dart';
import 'screens/safety_notice_screen.dart';
import 'screens/shell.dart';
import 'services/store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Store.i.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AR Shooter',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: ListenableBuilder(
          listenable: Store.i,
          builder: (_, __) {
            if (!Store.i.safetyAccepted) {
              return const SafetyNoticeScreen();
            }
            return CameraPermissionScreen(
              child: Store.i.name.isEmpty ? const Onboarding() : const Shell(),
            );
          },
        ),
      );
}
