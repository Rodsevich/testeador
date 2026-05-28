import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Outcome of a `runProcess` call.
class ProcessRunResult {
  /// Creates a [ProcessRunResult] capturing the full lifecycle of a process.
  const ProcessRunResult({
    required this.command,
    required this.workingDirectory,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.durationMs,
    required this.timedOut,
  });

  /// The full command line (executable + args).
  final List<String> command;

  /// The directory the process was spawned in.
  final String workingDirectory;

  /// Exit code (`-1` when killed by timeout).
  final int exitCode;

  /// Process stdout (decoded as UTF-8, lossy).
  final String stdout;

  /// Process stderr (decoded as UTF-8, lossy).
  final String stderr;

  /// Wall-clock duration including startup.
  final int durationMs;

  /// `true` when the process was killed because the timeout elapsed.
  final bool timedOut;

  /// JSON-friendly representation for MCP tool responses.
  Map<String, dynamic> toJson() => {
        'command': command,
        'working_directory': workingDirectory,
        'exit_code': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'duration_ms': durationMs,
        'timed_out': timedOut,
      };
}

/// Spawns [executable] [arguments], captures both streams, and enforces
/// [timeout]. Returns a structured [ProcessRunResult] — never throws on
/// non-zero exit codes (callers decide how to react).
Future<ProcessRunResult> runProcess({
  required String executable,
  required List<String> arguments,
  String? workingDirectory,
  Map<String, String>? environment,
  Duration timeout = const Duration(minutes: 10),
}) async {
  final cwd = workingDirectory ?? Directory.current.path;
  final started = DateTime.now();
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: cwd,
    environment: environment,
  );

  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();
  final outSub = process.stdout
      .transform(utf8.decoder)
      .listen(stdoutBuf.write);
  final errSub = process.stderr
      .transform(utf8.decoder)
      .listen(stderrBuf.write);

  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    process.kill();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (timedOut) process.kill(ProcessSignal.sigkill);
    });
  });

  final exitCode = await process.exitCode;
  timer.cancel();
  await outSub.cancel();
  await errSub.cancel();

  return ProcessRunResult(
    command: [executable, ...arguments],
    workingDirectory: cwd,
    exitCode: timedOut ? -1 : exitCode,
    stdout: stdoutBuf.toString(),
    stderr: stderrBuf.toString(),
    durationMs: DateTime.now().difference(started).inMilliseconds,
    timedOut: timedOut,
  );
}
