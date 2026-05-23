import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pokebattle_serverpod_flutter/main.dart' as app;

/// Agent flow: from a lobby state, wait for a battle to arrive via the
/// `battleAdded` stream and tap its `Join` button.
///
/// Env contract:
///   EMAIL    — credentials of the opponent (already registered).
///   PASSWORD — same.
///
/// The flow does not specify which battle — it takes the first card whose
/// opponent is the logged-in trainer. The whole point is exercising the
/// streaming push: there is no refresh button, the battle just appears.
void main() {
  patrolTest(
    'Agent flow: accept battle',
    ($) async {
      final env = Platform.environment;
      final email = env['EMAIL'] ?? 'watersh@testeador.dev';
      final password = env['PASSWORD'] ?? 'Pass_1234!';

      await app.main();
      await $.pumpAndSettle();

      await $(const Key('TabLogin')).tap();
      await $(const Key('FieldEmail')).enterText(email);
      await $(const Key('FieldPassword')).enterText(password);
      await $(const Key('ButtonSubmit')).tap();
      await $(const Key('ChipLive')).waitUntilVisible(
        timeout: const Duration(seconds: 10),
      );

      // Wait for any battle card to appear in the lobby — these are pushed
      // from the server's `battleAdded` stream, no refresh needed.
      final battleCard = $(find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('BattleCard:'),
      ));
      await battleCard.waitUntilVisible(
        timeout: const Duration(seconds: 15),
      );
      await battleCard.tap();
      await $.pumpAndSettle();

      // BattleScreen reached.
      await $(const Key('TextBattleTitle')).waitUntilVisible();
    },
  );
}
