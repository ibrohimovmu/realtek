import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/ai_assistant_service.dart';
import 'services/launcher_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge to edge transparent system bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load favorites, background, settings, installed applications, and Nova AI Assistant
  await LauncherStore.i.init();
  await AiAssistantService.i.init();

  runApp(const MinimalLauncherApp());
}

class MinimalLauncherApp extends StatelessWidget {
  const MinimalLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LauncherStore.i,
      builder: (context, _) {
        final store = LauncherStore.i;
        final isDark = store.isDark;

        final systemUiOverlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemUiOverlay,
          child: MaterialApp(
            title: 'Minimal Launcher',
            debugShowCheckedModeBanner: false,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: Color(store.background),
              fontFamily: 'Roboto',
              splashFactory: InkSparkle.splashFactory,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Color(store.background),
              fontFamily: 'Roboto',
              splashFactory: InkSparkle.splashFactory,
            ),
            home: const HomeScreen(),
          ),
        );
      },
    );
  }
}
