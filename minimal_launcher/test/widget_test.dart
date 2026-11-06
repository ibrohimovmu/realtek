import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_launcher/models/app_info.dart';
import 'package:minimal_launcher/widgets/app_tile.dart';

void main() {
  testWidgets('AppTile renders app label and fallback letter correctly', (WidgetTester tester) async {
    final app = AppInfo(
      label: 'YouTube',
      package: 'com.google.android.youtube',
      icon: Uint8List(0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTile(app: app),
        ),
      ),
    );

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Y'), findsOneWidget); // Fallback letter inside dark disc badge
  });
}
