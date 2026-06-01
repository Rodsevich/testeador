import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/admin/admin_dashboard_screen.dart';

/// Root widget of the web admin panel.
///
/// A deliberately DOM-light Material app (no sprite network fetches) so
/// Patrol-web e2e runs are fast and deterministic.
class AdminApp extends StatelessWidget {
  /// Creates the [AdminApp].
  const AdminApp({required this.client, super.key});

  /// The Serverpod client this panel talks to.
  final Client client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const Key('AdminAppRoot'),
      title: 'PokéBattle Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AdminDashboardScreen(client: client),
    );
  }
}
