import 'package:test/test.dart';
import 'package:testeador/src/mcp/process_runner.dart';

void main() {
  group('runProcess', () {
    test('captures stdout and a zero exit code', () async {
      final result = await runProcess(
        executable: 'echo',
        arguments: ['hello-testeador'],
      );
      expect(result.exitCode, 0);
      expect(result.stdout.trim(), 'hello-testeador');
      expect(result.timedOut, isFalse);
      expect(result.command, ['echo', 'hello-testeador']);
    });

    test('reports a non-zero exit code without throwing', () async {
      final result = await runProcess(
        executable: 'sh',
        arguments: ['-c', 'exit 3'],
      );
      expect(result.exitCode, 3);
      expect(result.timedOut, isFalse);
    });

    test('kills the process and flags timedOut on timeout', () async {
      final result = await runProcess(
        executable: 'sh',
        arguments: ['-c', 'sleep 5'],
        timeout: const Duration(milliseconds: 200),
      );
      expect(result.timedOut, isTrue);
      expect(result.exitCode, -1);
    });

    test('toJson exposes the expected keys', () async {
      final result = await runProcess(
        executable: 'echo',
        arguments: ['x'],
      );
      final json = result.toJson();
      expect(
        json.keys,
        containsAll([
          'command',
          'working_directory',
          'exit_code',
          'stdout',
          'stderr',
          'duration_ms',
          'timed_out',
        ]),
      );
    });
  });
}
