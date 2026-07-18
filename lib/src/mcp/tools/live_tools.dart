import 'package:mcp_dart/mcp_dart.dart';
import 'package:testeador/src/live/live_persona.dart';
import 'package:testeador/src/live/questline_live_client.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

/// Registra las tools de **siembra en vivo** (`boot_persona`,
/// `list_personas`, `configure_questline`).
///
/// Gated tras `TESTEADOR_MCP_ENABLE_LIVE` porque se conectan al VM service de
/// una app Flutter corriendo (que no existe en CI plano), igual que las tools
/// de captura. Invocan las service extensions `ext.stabilitas.*` /
/// `ext.questline.*` que el app registra en su flavor dev.
void registerLiveTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerBootPersona(server);
  _registerListPersonas(server);
  _registerConfigureQuestline(server);
}

void _registerBootPersona(McpServer server) {
  server.registerTool(
    'boot_persona',
    description:
        'Boots the running dev Flutter app already SEEDED into a testeador '
        'persona, by invoking its `ext.stabilitas.setPersona` service '
        'extension over the VM service. The app opens (or re-runs) in that '
        'isolated fixture state; explore it by hand or drive it with '
        'flutter_driver/DTD. Requires the app running in its dev flavor. Omit '
        '`persona` (or pass empty) to EXIT fixture mode back to the real dev '
        'database.',
    inputSchema: JsonSchema.object(
      properties: {
        'vm_uri': JsonSchema.string(
          description:
              'ws:// VM-service / DDS URI of the running dev app '
              '(e.g. ws://127.0.0.1:PORT/ws). NOT the DTD URI.',
        ),
        'persona': JsonSchema.string(
          description:
              'Persona to seed: novicio | converso | monje | peregrino. '
              'Omit or pass empty to exit fixture mode.',
        ),
        'timeout_s': JsonSchema.integer(
          description:
              'Seconds to wait for the app to register the extension. '
              'Default 15.',
        ),
      },
      required: ['vm_uri'],
    ),
    callback: (args, extra) async {
      try {
        final uri = args['vm_uri'] as String?;
        if (uri == null || uri.isEmpty) {
          return errResult("boot_persona requires 'vm_uri'.");
        }
        final persona = args['persona'] as String?;
        final timeoutS = args['timeout_s'] as int? ?? 15;
        final client = LivePersonaClient(wsUri: uri);
        final result = await client.setPersona(
          persona,
          timeout: Duration(seconds: timeoutS),
        );
        return okResult({
          'status': 'ok',
          'requested': (persona == null || persona.isEmpty)
              ? '<exit fixture mode>'
              : persona,
          'result': result,
        });
      } on Object catch (e) {
        return errResult('boot_persona failed: $e');
      }
    },
  );
}

void _registerListPersonas(McpServer server) {
  server.registerTool(
    'list_personas',
    description:
        'Lists the testeador personas the running dev app exposes (via its '
        '`ext.stabilitas.listPersonas` service extension), and the currently '
        'active one. Use before boot_persona to see the choices.',
    inputSchema: JsonSchema.object(
      properties: {
        'vm_uri': JsonSchema.string(
          description: 'ws:// VM-service / DDS URI of the running dev app.',
        ),
        'timeout_s': JsonSchema.integer(
          description: 'Seconds to wait for the extension. Default 15.',
        ),
      },
      required: ['vm_uri'],
    ),
    callback: (args, extra) async {
      try {
        final uri = args['vm_uri'] as String?;
        if (uri == null || uri.isEmpty) {
          return errResult("list_personas requires 'vm_uri'.");
        }
        final timeoutS = args['timeout_s'] as int? ?? 15;
        final client = LivePersonaClient(wsUri: uri);
        // `listPersonas` ya incluye la persona activa: una sola conexión.
        final result = await client.listPersonas(
          timeout: Duration(seconds: timeoutS),
        );
        return okResult({
          'personas': result['personas'],
          'active': result['active'],
        });
      } on Object catch (e) {
        return errResult('list_personas failed: $e');
      }
    },
  );
}

void _registerConfigureQuestline(McpServer server) {
  server.registerTool(
    'configure_questline',
    description:
        'Live-configures the questline runtime (signals, liturgical clock, '
        'mission/unlock state) of a running dev Flutter app, by invoking its '
        '`ext.questline.*` service extensions over the VM service. Returns the '
        'extension JSON body. Requires the app running with QuestlineDevtools '
        '(dev flavor).\n'
        'Actions:\n'
        '- dumpState: no extra args; returns {targets, signals, clock}.\n'
        '- setSignal: key + value (+ optional type '
        'bool|int|double|string|null).\n'
        '- forceHour: hour (liturgical name e.g. sexta) OR minutes '
        '(0..1439).\n'
        '- clearClock: no extra args.',
    inputSchema: JsonSchema.object(
      properties: {
        'vm_uri': JsonSchema.string(
          description:
              'ws:// VM-service / DDS URI of the running dev app '
              '(e.g. ws://127.0.0.1:PORT/ws). NOT the DTD URI.',
        ),
        'action': JsonSchema.string(
          description: 'dumpState | setSignal | forceHour | clearClock.',
        ),
        'key': JsonSchema.string(
          description: 'setSignal: signal name (e.g. feria, unlockedOpusVita).',
        ),
        'value': JsonSchema.string(
          description: 'setSignal: value (serialized as string).',
        ),
        'type': JsonSchema.string(
          description:
              'setSignal: bool|int|double|string|null. Defaults to string.',
        ),
        'hour': JsonSchema.string(
          description:
              'forceHour: liturgical hour name '
              '(vigiliae|laudes|tercia|sexta|nona|visperas|completas).',
        ),
        'minutes': JsonSchema.integer(
          description:
              'forceHour: minute of day 0..1439 (alternative to hour).',
        ),
        'timeout_s': JsonSchema.integer(
          description: 'Seconds to wait for the extension. Default 15.',
        ),
      },
      required: ['vm_uri', 'action'],
    ),
    callback: (args, extra) async {
      try {
        final uri = args['vm_uri'] as String?;
        if (uri == null || uri.isEmpty) {
          return errResult("configure_questline requires 'vm_uri'.");
        }
        final action = args['action'] as String?;
        if (action == null || action.isEmpty) {
          return errResult("configure_questline requires 'action'.");
        }
        final timeout = Duration(seconds: args['timeout_s'] as int? ?? 15);
        final client = QuestlineLiveClient(wsUri: uri);

        final Map<String, dynamic> result;
        switch (action) {
          case 'dumpState':
            result = await client.dumpState(timeout: timeout);
          case 'setSignal':
            final key = args['key'] as String?;
            if (key == null || key.isEmpty) {
              return errResult("setSignal requires 'key'.");
            }
            result = await client.setSignal(
              key,
              args['value'],
              type: args['type'] as String?,
              timeout: timeout,
            );
          case 'forceHour':
            final hour = args['hour'] as String?;
            final minutes = args['minutes'] as int?;
            if (hour != null && hour.isNotEmpty) {
              result = await client.forceLiturgicalHour(hour, timeout: timeout);
            } else if (minutes != null) {
              result = await client.forceHour(minutes, timeout: timeout);
            } else {
              return errResult("forceHour requires 'hour' or 'minutes'.");
            }
          case 'clearClock':
            result = await client.clearClock(timeout: timeout);
          default:
            return errResult(
              "Unknown action '$action'. Use dumpState | setSignal | "
              'forceHour | clearClock.',
            );
        }
        return okResult({'action': action, 'result': result});
      } on Object catch (e) {
        return errResult('configure_questline failed: $e');
      }
    },
  );
}
