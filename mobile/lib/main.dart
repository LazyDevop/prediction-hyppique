import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: PredictionHippiqueApp()));
}

class PredictionHippiqueApp extends StatelessWidget {
  const PredictionHippiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE8B33C);
    const bg = Color(0xFF0B1120);
    const surface = Color(0xFF131C2E);

    return MaterialApp(
      title: 'Analyse Hippique',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          primary: gold,
          surface: surface,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: surface),
        cardTheme: CardThemeData(
          color: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
