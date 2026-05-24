import 'package:flutter/material.dart';
import 'package:pokebattle_serverpod_client/pokebattle_serverpod_client.dart';
import 'package:pokebattle_serverpod_flutter/ui/lobby_screen.dart';
import 'package:pokebattle_serverpod_flutter/ui/registration_screen.dart';

/// Entry screen — register / log in tabs.
class AuthScreen extends StatefulWidget {
  /// Creates the [AuthScreen].
  const AuthScreen({required this.client, super.key});

  /// The Serverpod client.
  final Client client;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  /// When set via `--dart-define=AUTO_LOGIN_EMAIL=...`, the screen
  /// auto-registers the trainer at boot and jumps straight to
  /// [RegistrationScreen] / [LobbyScreen]. Used by the multi-device E2E run
  /// so each emulator/simulator starts already inside the lobby — that way
  /// the stream-driven UI is what the side-by-side composites capture.
  static const _autoLoginEmail =
      String.fromEnvironment('AUTO_LOGIN_EMAIL');
  static const _autoLoginPassword =
      String.fromEnvironment('AUTO_LOGIN_PASSWORD');
  static const _autoLoginName =
      String.fromEnvironment('AUTO_LOGIN_NAME');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _error = null));
    if (_autoLoginEmail.isNotEmpty &&
        _autoLoginPassword.isNotEmpty &&
        _autoLoginName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoLogin());
    }
  }

  Future<void> _autoLogin() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      AuthUser user;
      try {
        user = await widget.client.auth.register(
          _autoLoginName, _autoLoginEmail, _autoLoginPassword,
        );
      } on Exception {
        // Already registered (subsequent hot-restart). Fall back to login.
        user = await widget.client.auth.login(
          _autoLoginEmail, _autoLoginPassword,
        );
      }
      final players = await widget.client.players.listPlayers();
      final existing = players.where((p) => p.name == user.name).firstOrNull;
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => existing != null
              ? LobbyScreen(
                  client: widget.client,
                  currentPlayer: existing,
                  authUser: user,
                )
              : RegistrationScreen(client: widget.client, authUser: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Auto-login failed: $e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final isRegister = _tabs.index == 0;
    if (email.isEmpty || password.isEmpty) return;
    if (isRegister && name.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AuthUser user;
      if (isRegister) {
        user = await widget.client.auth.register(name, email, password);
      } else {
        user = await widget.client.auth.login(email, password);
      }

      // Returning users with an existing player skip the team picker.
      final players = await widget.client.players.listPlayers();
      final existing = players.where((p) => p.name == user.name).firstOrNull;

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => existing != null
              ? LobbyScreen(
                  client: widget.client,
                  currentPlayer: existing,
                  authUser: user,
                )
              : RegistrationScreen(client: widget.client, authUser: user),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _tabs.index == 0;
    final canSubmit = !_loading &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        (!isRegister || _nameController.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PokéBattle · Live'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(key: Key('TabRegister'), text: 'Register'),
            Tab(key: Key('TabLogin'), text: 'Log in'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isRegister) ...[
              TextField(
                key: const Key('FieldTrainerName'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Trainer name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              key: const Key('FieldEmail'),
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('FieldPassword'),
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            FilledButton(
              key: const Key('ButtonSubmit'),
              onPressed: canSubmit ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isRegister ? 'Register' : 'Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
