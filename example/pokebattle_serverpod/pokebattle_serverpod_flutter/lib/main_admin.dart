import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/admin/admin_app.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Global Serverpod client for the admin panel.
///
/// Separate entrypoint from [main] (the player app): run with
/// `flutter run -d chrome -t lib/main_admin.dart`. Reuses the same client and
/// streaming endpoints — the admin panel is just a different view onto the
/// same backend, built to be driven by Patrol-web e2e tests.
late final Client client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Same resolution as the player app: `--dart-define=SERVER_URL=...` first,
  // then `assets/config.json` (default `http://localhost:8080/`).
  final serverUrl = await getServerUrl();

  client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor();

  runApp(AdminApp(client: client));
}
