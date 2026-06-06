import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/src/capture/cdp_network_capture.dart';
import 'package:testeador/src/capture/recording_session.dart';
import 'package:testeador/src/capture/traffic_capture.dart';
import 'package:testeador/src/capture/vm_service_capture.dart';
import 'package:testeador/src/mcp/safe_write.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

/// Live recording sessions, keyed by the id returned from `start_recording`.
final Map<String, RecordingSession> _sessions = {};
int _sessionCounter = 0;

/// Default output directory for generated draft units.
const _defaultOutDir = 'test/contract_drafts';

/// Registers the bracket capture tools: `start_recording` +
/// `stop_and_generate`.
///
/// Gated behind `TESTEADOR_MCP_ENABLE_CAPTURE` because it attaches to a running
/// app's debug transport (Chrome CDP port or VM-service URI) which is not
/// present in plain CI.
void registerCaptureTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerStartRecording(server);
  _registerStopAndGenerate(server, workspace);
}

void _registerStartRecording(McpServer server) {
  server.registerTool(
    'start_recording',
    description:
        'Opens passive HTTP capture against a running app and returns a '
        'recording_id. Drive the app however you like (a human tapping, or an '
        'AI via marionette) — capture is passive — then call '
        '`stop_and_generate`. `web` attaches to a Chrome '
        '--remote-debugging-port (CDP Network); `native` attaches to a '
        'VM-service / DDS URI (dart:io HTTP profiler) and enables profiling '
        'before the journey.',
    inputSchema: JsonSchema.object(
      properties: {
        'backend': JsonSchema.string(enumValues: ['web', 'native']),
        'debug_port': JsonSchema.integer(
          description: 'web only: Chrome --remote-debugging-port.',
        ),
        'vm_uri': JsonSchema.string(
          description: 'native only: ws:// VM-service / DDS URI.',
        ),
      },
      required: ['backend'],
    ),
    callback: (args, extra) async {
      try {
        final backend = args['backend'] as String?;
        final TrafficCapture capture;
        switch (backend) {
          case 'web':
            final port = args['debug_port'] as int?;
            if (port == null) {
              return errResult("web backend requires 'debug_port'.");
            }
            capture = CdpNetworkCapture(debugPort: port);
          case 'native':
            final uri = args['vm_uri'] as String?;
            if (uri == null) {
              return errResult("native backend requires 'vm_uri'.");
            }
            capture = VmServiceHttpCapture(wsUri: uri);
          default:
            return errResult("backend must be 'web' or 'native'.");
        }

        // No coverage baseline is wired yet (manifest annotation is future
        // work), so every run is a cold-start: candidates, not silent gaps.
        final session = RecordingSession(capture, coldStart: true);
        await session.start();
        final id = 'rec-${++_sessionCounter}';
        _sessions[id] = session;

        return okResult({
          'recording_id': id,
          'backend': backend,
          'status': 'recording',
          'next':
              'Exercise the app, then call stop_and_generate with this '
              'recording_id.',
        });
      } on Object catch (e) {
        return errResult('start_recording failed: $e');
      }
    },
  );
}

void _registerStopAndGenerate(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'stop_and_generate',
    description:
        'Closes the capture for recording_id, diffs the exercised endpoints '
        'against coverage, and returns a gap report plus one draft contract '
        'test per uncovered endpoint. With write:true the drafts are written '
        '(never overwriting) under out_dir.',
    inputSchema: JsonSchema.object(
      properties: {
        'recording_id': JsonSchema.string(),
        'out_dir': JsonSchema.string(
          description:
              'Where drafts are written when write:true. '
              'Default: $_defaultOutDir.',
        ),
        'write': JsonSchema.boolean(defaultValue: false),
      },
      required: ['recording_id'],
    ),
    callback: (args, extra) async {
      try {
        final id = args['recording_id'] as String?;
        final session = id == null ? null : _sessions.remove(id);
        if (session == null) {
          return errResult('unknown recording_id: $id');
        }

        final outcome = await session.stopAndGenerate();
        final write = args['write'] == true;
        final outDir = (args['out_dir'] as String?) ?? _defaultOutDir;

        final units = <Map<String, dynamic>>[];
        for (final unit in outcome.units) {
          final entry = <String, dynamic>{'file_name': unit.fileName};
          if (write) {
            final result = safeWrite(
              workspaceRoot: workspace.root,
              path: p.join(outDir, unit.fileName),
              content: unit.source,
              dryRun: false,
            );
            entry['written'] = result.written;
            entry['path'] = result.absolutePath;
            if (!result.ok) entry['error'] = result.error;
          } else {
            entry['source'] = unit.source;
          }
          units.add(entry);
        }

        return okResult({
          'report': outcome.reportJson,
          'report_text': outcome.reportText,
          'wrote': write,
          'units': units,
        });
      } on Object catch (e) {
        return errResult('stop_and_generate failed: $e');
      }
    },
  );
}
