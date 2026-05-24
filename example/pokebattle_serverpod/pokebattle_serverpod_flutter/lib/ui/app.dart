import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/ui/auth_screen.dart';

/// Root widget of the streaming PokéBattle app.
///
/// The theme seed colour can be overridden at compile time via
/// `--dart-define=SEED_COLOR=<red|cyan|indigo|...>` so the same APK/IPA can
/// be reused on multiple devices in the multi-device E2E run with a visually
/// distinct identity per actor (e.g. Firesh on red, Watersh on cyan).
class PokeBattleApp extends StatelessWidget {
  /// Creates the [PokeBattleApp].
  const PokeBattleApp({required this.client, super.key});

  /// Default seed when no `--dart-define=SEED_COLOR=...` was set.
  static const _defaultSeed = 'indigo';

  static const _seedByName = <String, Color>{
    'red': Colors.red,
    'cyan': Color(0xFF40C4FF),
    'celeste': Color(0xFF40C4FF),
    'blue': Colors.blue,
    'indigo': Colors.indigo,
    'green': Colors.green,
    'purple': Colors.purple,
    'orange': Colors.deepOrange,
  };

  /// The Serverpod client this app talks to.
  final Client client;

  @override
  Widget build(BuildContext context) {
    const requested = String.fromEnvironment(
      'SEED_COLOR',
      defaultValue: _defaultSeed,
    );
    final seed = _seedByName[requested.toLowerCase()] ?? Colors.indigo;
    return MaterialApp(
      title: 'PokéBattle (Serverpod)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      home: AuthScreen(client: client),
    );
  }
}
