import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/src/capture/cdp_network_capture.dart';
import 'package:testeador/src/capture/recording_session.dart';
import 'package:testeador/src/capture/traffic_capture.dart';
import 'package:testeador/src/capture/vm_service_capture.dart';
import 'package:testeador/src/mcp/safe_write.dart';

/// `testeador record` — the manual half of the capture bracket.
///
/// Attaches to a running app (web via a Chrome debug port, native via a
/// VM-service URI), waits while you exercise it (or for `--duration` seconds),
/// then prints the gap report and writes one draft contract test per uncovered
/// endpoint under `--out` (never overwriting). Returns a process exit code.
Future<int> runRecordCli(
  List<String> args, {
  Stream<List<int>>? stdinOverride,
}) async {
  final parser = ArgParser()
    ..addOption(
      'backend',
      allowed: ['web', 'native'],
      help: 'Capture backend.',
    )
    ..addOption('debug-port', help: 'web: Chrome --remote-debugging-port.')
    ..addOption('vm-uri', help: 'native: ws:// VM-service / DDS URI.')
    ..addOption(
      'out',
      defaultsTo: 'test/contract_drafts',
      help: 'Directory for generated drafts.',
    )
    ..addOption(
      'duration',
      help: 'Seconds to record before stopping. Omit to stop on <Enter>.',
    )
    ..addFlag(
      'write',
      defaultsTo: true,
      help: 'Write drafts to --out (use --no-write to only print the report).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    return 64;
  }

  if (opts['help'] as bool) {
    stdout
      ..writeln('Usage: testeador record --backend <web|native> [options]')
      ..writeln(parser.usage);
    return 0;
  }

  final TrafficCapture capture;
  try {
    capture = _buildCapture(opts);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    return 64;
  }

  final session = RecordingSession(capture, coldStart: true);
  await session.start();
  stdout.writeln('● recording — exercise the app now.');

  await _waitToStop(opts['duration'] as String?, stdinOverride);

  final outcome = await session.stopAndGenerate();
  stdout
    ..writeln()
    ..writeln(outcome.reportText);

  if (opts['write'] as bool) {
    final outDir = opts['out'] as String;
    for (final unit in outcome.units) {
      final result = safeWrite(
        workspaceRoot: Directory.current,
        path: p.join(outDir, unit.fileName),
        content: unit.source,
        dryRun: false,
      );
      stdout.writeln(
        result.written
            ? '  wrote ${result.absolutePath}'
            : '  skipped ${result.absolutePath} (${result.error})',
      );
    }
  }
  return 0;
}

TrafficCapture _buildCapture(ArgResults opts) {
  switch (opts['backend']) {
    case 'web':
      final raw = opts['debug-port'] as String?;
      final port = raw == null ? null : int.tryParse(raw);
      if (port == null) {
        throw const FormatException('web backend requires --debug-port <int>.');
      }
      return CdpNetworkCapture(debugPort: port);
    case 'native':
      final uri = opts['vm-uri'] as String?;
      if (uri == null) {
        throw const FormatException(
          'native backend requires --vm-uri <ws://>.',
        );
      }
      return VmServiceHttpCapture(wsUri: uri);
    default:
      throw const FormatException('--backend must be web or native.');
  }
}

Future<void> _waitToStop(String? duration, Stream<List<int>>? stdinOverride) {
  if (duration != null) {
    final seconds = int.tryParse(duration) ?? 0;
    return Future<void>.delayed(Duration(seconds: seconds));
  }
  stdout.writeln('  press <Enter> to stop and generate…');
  final input = stdinOverride ?? stdin;
  return input.first.then((_) {});
}
