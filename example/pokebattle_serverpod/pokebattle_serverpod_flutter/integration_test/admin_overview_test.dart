import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pokebattle_serverpod_flutter/main_admin.dart' as admin;

/// Patrol-web e2e flow for the admin panel.
///
/// Drives the Flutter web admin panel in a real browser (Patrol 4.0+ via
/// Playwright). Run from this package with the Serverpod server up on :8080:
///
/// ```bash
/// dart run serverpod_cli  # (or: cd ../pokebattle_serverpod_server && dart bin/main.dart)
/// patrol test --device chrome \
///   --target integration_test/admin_flows/admin_overview.dart \
///   --web-headless true
/// ```
///
/// It exercises all four admin capabilities against the REAL backend:
///   1. View players / battles (lists hydrate from the server on load).
///   2. Force data — Reset, Seed players, Seed battle.
///   3. Live monitor — seeded entities arrive via the `playerAdded` /
///      `battleAdded` streams and surface as live events.
///   4. View/manage a battle — open its detail (`getBattle`) and close it.
///
/// Assertions lean on the deterministic seed names (`Seed Trainer 1..3`) and
/// the stable `Admin*` keys so they hold without mocks.
void main() {
  patrolTest(
    'Admin panel: force data + live monitor end-to-end on web',
    ($) async {
      await admin.main();
      await $.pumpAndSettle();

      // Panel is up and streaming.
      await $(const Key('AdminChipLive')).waitUntilVisible();

      // Clean slate so the counts below are deterministic.
      await $(const Key('AdminButtonReset')).tap();
      await $(const Key('AdminPlayersEmpty')).waitUntilVisible();
      await $(const Key('AdminBattlesEmpty')).waitUntilVisible();

      // Force data: seed 3 players. They round-trip through the backend and
      // come back over the playerAdded stream → live monitor + players list.
      await $(const Key('AdminButtonSeedPlayers')).tap();
      await $('Player joined · Seed Trainer 1').waitUntilVisible();
      await $('Seed Trainer 1').waitUntilVisible();
      expect($(const Key('AdminPlayersCount')).text, '(3)');

      // Force data: seed a battle between the two most recent seeds.
      await $(const Key('AdminButtonSeedBattle')).tap();
      await $('Battle created · Seed Trainer 3 vs Seed Trainer 2')
          .waitUntilVisible();
      expect($(const Key('AdminBattlesCount')).text, '(1)');

      // Manage a battle: scroll its tile into view, open the detail
      // (getBattle) and close it. The tile sits below the fold once the live
      // monitor and player list have grown, so it must be scrolled to.
      await $('Seed Trainer 3 vs Seed Trainer 2').scrollTo().tap();
      await $(const Key('AdminBattleDetail')).waitUntilVisible();
      await $(const Key('AdminBattleDetailClose')).tap();
      await $.pumpAndSettle();
    },
  );
}
