import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/ui/auth_screen.dart';

/// Root widget of the streaming PokéBattle app.
class PokeBattleApp extends StatelessWidget {
  /// Creates the [PokeBattleApp].
  const PokeBattleApp({required this.client, super.key});

  /// The Serverpod client this app talks to.
  final Client client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokéBattle (Serverpod)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AuthScreen(client: client),
    );
  }
}
