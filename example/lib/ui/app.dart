import 'package:flutter/material.dart';
import 'package:testeador_example/ui/registration_screen.dart';

/// Root widget of the PokéBattle app.
class PokeBattleApp extends StatelessWidget {
  /// Creates the [PokeBattleApp].
  const PokeBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokéBattle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const RegistrationScreen(),
    );
  }
}
