import 'dart:io';

import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:pokebattle_serverpod_flutter/main.dart' as app;

/// Agent flow: register a player team for a NEW trainer (auth + team picker).
///
/// Same shape as [register_and_land_in_lobby] but kept as a separate file so a
/// testeador step can spin up a fresh actor in a single device without
/// dragging unrelated UI work into the same Patrol test.
void main() {
  patrolTest(
    'Agent flow: register player',
    ($) async {
      final env = Platform.environment;
      final name = env['TRAINER_NAME'] ?? 'AgentTrainer';
      final email = env['EMAIL'] ?? 'agent_${DateTime.now().millisecondsSinceEpoch}@testeador.dev';
      final password = env['PASSWORD'] ?? 'Pass_1234!';
      final team = (env['TEAM'] ??
              'blastoise,gyarados,vaporeon,lapras,starmie,cloyster')
          .split(',');

      await app.main();
      await $.pumpAndSettle();

      await $(const Key('FieldTrainerName')).enterText(name);
      await $(const Key('FieldEmail')).enterText(email);
      await $(const Key('FieldPassword')).enterText(password);
      await $(const Key('ButtonSubmit')).tap();
      await $.pumpAndSettle();

      for (final pokemon in team) {
        await $(Key('PokemonCard:$pokemon')).tap();
      }
      await $(const Key('ButtonEnterLobby')).tap();
      await $(const Key('ChipLive')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );
    },
  );
}
