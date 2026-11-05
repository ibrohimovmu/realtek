import 'package:flutter/material.dart';
import '../theme.dart';
import 'hud_screen.dart';
import 'leaderboard_screen.dart';
import 'missions_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HudScreen(),
            ShopScreen(),
            LeaderboardScreen(),
            MissionsScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: kCard,
            indicatorColor: kPurple.withValues(alpha: 0.25),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 11);
              }
              return const TextStyle(color: Colors.white60, fontSize: 11);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: kPurple);
              }
              return const IconThemeData(color: Colors.white60);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            height: 64,
            elevation: 0,
            onDestinationSelected: (v) => setState(() => _currentIndex = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.gps_fixed), label: 'O\'yin'),
              NavigationDestination(icon: Icon(Icons.storefront), label: 'Do\'kon'),
              NavigationDestination(icon: Icon(Icons.leaderboard), label: 'Reyting'),
              NavigationDestination(icon: Icon(Icons.flag), label: 'Vazifa'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        ),
      );
}
