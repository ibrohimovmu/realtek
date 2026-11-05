import 'package:flutter/material.dart';
import '../services/store.dart';
import '../theme.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: kPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: kPurple, width: 2),
                      boxShadow: [
                        BoxShadow(color: kPurple.withValues(alpha: 0.35), blurRadius: 24),
                      ],
                    ),
                    child: const Icon(Icons.gps_fixed, size: 54, color: kPurple),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Xush kelibsiz, Operator',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Smartfon kamerasi orqali real hayotda do\'stlaringiz bilan AR Laser Tag o\'ynang. Nishonga oling va birinchi bo\'ling!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _c,
                    maxLength: 16,
                    decoration: const InputDecoration(
                      hintText: 'Jangovar taxallus (Callsign)',
                      prefixIcon: Icon(Icons.person, color: kPurple),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      final val = _c.text.trim();
                      if (val.isNotEmpty) {
                        Store.i.setName(val);
                      }
                    },
                    child: const Text('Jangga Kirish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
