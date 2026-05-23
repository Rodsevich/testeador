import 'dart:io';

import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:pokebattle_serverpod_flutter/main.dart' as app;

/// Agent flow: register a brand-new trainer and land in the lobby.
///
/// Env contract:
///   TRAINER_NAME — trainer display name (e.g. 'Firesh').
///   EMAIL        — unique email per run.
///   PASSWORD     — any string.
///   TEAM         — comma-separated list of 6 lowercase Pokémon names.
///
/// On success the screen showing `ChipLive` (the lobby) is visible.
void main() {
  patrolTest(
    'Agent flow: register & land in lobby',
    ($) async {
      final env = Platform.environment;
      final name = env['TRAINER_NAME'] ?? 'AgentTrainer';
      final email = env['EMAIL'] ?? 'agent_${DateTime.now().millisecondsSinceEpoch}@testeador.dev';
      final password = env['PASSWORD'] ?? 'Pass_1234!';
      final team = (env['TEAM'] ??
              'charizard,arcanine,flareon,rapidash,magmar,ninetales')
          .split(',');

      await app.main();
      await $.pumpAndSettle();

      // Auth screen: register tab is the default. Fill credentials.
      await $(const Key('FieldTrainerName')).enterText(name);
      await $(const Key('FieldEmail')).enterText(email);
      await $(const Key('FieldPassword')).enterText(password);
      await $(const Key('ButtonSubmit')).tap();
      await $.pumpAndSettle();

      // Registration screen: select 6 Pokémon from the team list.
      for (final pokemon in team) {
        await $(Key('PokemonCard:$pokemon')).tap();
      }
      await $(const Key('ButtonEnterLobby')).tap();
      await $.pumpAndSettle(timeout: const Duration(seconds: 10));

      // Lobby visible.
      await $(const Key('ChipLive')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
    },
  );
}
