import 'dart:async';

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

/// DevTools extension de testeador: siembra en vivo de personas.
void main() => runApp(const TesteadorExtension());

/// Raíz de la extension. `DevToolsExtension` inicializa los globals
/// `serviceManager` (VM service de la app inspeccionada), `extensionManager` y
/// `dtdManager`.
class TesteadorExtension extends StatelessWidget {
  /// Crea la extension.
  const TesteadorExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: PersonaPanel());
  }
}

/// Panel que lista las personas disponibles y permite sembrarlas en vivo.
class PersonaPanel extends StatefulWidget {
  /// Crea el panel.
  const PersonaPanel({super.key});

  @override
  State<PersonaPanel> createState() => _PersonaPanelState();
}

class _PersonaPanelState extends State<PersonaPanel> {
  List<Map<String, dynamic>> _personas = <Map<String, dynamic>>[];
  String? _active;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final personas = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.stabilitas.listPersonas',
      );
      final active = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.stabilitas.getActivePersona',
      );
      final raw = (personas.json?['personas'] as List<Object?>?) ?? const [];
      setState(() {
        _personas = raw
            .whereType<Map<String, Object?>>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _active = active.json?['persona'] as String?;
      });
    } on Object catch (e) {
      setState(() => _error = _hint(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _setPersona(String? id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.stabilitas.setPersona',
        args: <String, dynamic>{if (id != null) 'persona': id},
      );
      await _load();
    } on Object catch (e) {
      setState(() {
        _error = _hint(e);
        _busy = false;
      });
    }
  }

  /// Mensaje accionable: la extension solo existe en la app dev (flavor dev).
  String _hint(Object e) =>
      'No se pudo hablar con ext.stabilitas.* ($e).\n¿La app está corriendo en '
      'el flavor dev y conectada a este DevTools?';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Personas testeador',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refrescar',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_active != null)
              Chip(label: Text('Activa: $_active'))
            else
              const Chip(label: Text('Modo normal (DB de desarrollo real)')),
            const SizedBox(height: 12),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final persona in _personas)
                    Card(
                      child: ListTile(
                        title: Text(persona['label']?.toString() ?? '?'),
                        subtitle: Text(
                          persona['description']?.toString() ?? '',
                        ),
                        trailing: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _setPersona(persona['id'] as String?),
                          child: const Text('Sembrar'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _setPersona(null),
                    icon: const Icon(Icons.logout),
                    label: const Text('Salir del modo fixture'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
