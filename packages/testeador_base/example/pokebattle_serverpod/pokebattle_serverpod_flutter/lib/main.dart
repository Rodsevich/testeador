import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/ui/app.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

/// Global Serverpod client. Initialised in [main] before runApp.
///
/// Hosts the WebSocket used by every streaming endpoint, so a single instance
/// per app process is correct (no per-screen clients).
late final Client client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reads `SERVER_URL` from `--dart-define`, falling back to
  // `assets/config.json` (default `http://localhost:8080/`).
  //
  // For Android emulators pass `--dart-define=SERVER_URL=http://10.0.2.2:8080/`
  // since `localhost` inside the AVD points to the AVD itself.
  final serverUrl = await getServerUrl();

  client = Client(serverUrl)
    ..connectivityMonitor = FlutterConnectivityMonitor();

  runApp(PokeBattleApp(client: client));
}
