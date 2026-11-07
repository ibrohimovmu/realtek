import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/ai_assistant_service.dart';
import 'services/launcher_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  final store = LauncherStore();
  final ai = AiAssistantService();
  await store.init();

  runApp(MinimalLauncherApp(store: store, ai: ai));
}

class MinimalLauncherApp extends StatelessWidget {
  final LauncherStore store;
  final AiAssistantService ai;

  const MinimalLauncherApp({
    super.key,
    required this.store,
    required this.ai,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minimal Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0E1D21),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF677E8A),
          brightness: Brightness.dark,
          surface: const Color(0xFF0E1D21),
        ),
      ),
      home: HomeScreen(store: store, ai: ai),
    );
  }
}
