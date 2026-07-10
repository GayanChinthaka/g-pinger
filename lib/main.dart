import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/pinger/pinger_screen.dart';
import 'features/pinger/pinger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const GPingerApp(),
    ),
  );
}

class GPingerApp extends StatelessWidget {
  const GPingerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G Pinger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark,
      home: const PingerScreen(),
    );
  }
}
