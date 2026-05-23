import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:testeador_example/domain/models.dart';
import 'package:testeador_example/domain/repositories.dart';
import 'package:testeador_example/ui/lobby_screen.dart';
import 'package:testeador_example/ui/registration_screen.dart';

/// Entry screen for the PokéBattle app — handles register and login.
class AuthScreen extends StatefulWidget {
  /// Creates the [AuthScreen].
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio();
  late final AuthRepository _authRepo;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _authRepo = AuthRepository(_dio);
    _tabs.addListener(() => setState(() => _error = null));
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
        user = await _authRepo.register(name, email, password);
      } else {
        user = await _authRepo.login(email, password);
      }

      // Check if this user already has a registered player so returning users
      // go straight to the lobby instead of the Pokémon selection screen.
      final battleRepo = BattleRepository(_dio, token: user.token);
      final players = await battleRepo.listPlayers();
      final existing = players.where((p) => p.name == user.name).firstOrNull;

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => existing != null
              ? LobbyScreen(currentPlayer: existing, authUser: user)
              : RegistrationScreen(authUser: user),
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
        title: const Text('PokéBattle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Register'),
            Tab(text: 'Log in'),
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
