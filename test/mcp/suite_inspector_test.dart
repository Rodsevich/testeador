import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador/src/mcp/suite_inspector.dart';

void main() {
  final repoRoot = Directory.current.path;
  final restRunner = File(
    p.join(repoRoot, 'example', 'pokebattle_rest', 'bin', 'run_tests.dart'),
  );
  final serverpodTest = File(
    p.join(
      repoRoot,
      'example',
      'pokebattle_serverpod',
      'pokebattle_serverpod_flutter',
      'test',
      'contract_test.dart',
    ),
  );

  group('inspectSuite — pokebattle_rest CLI runner', () {
    test('detects CLI mode, actors, and flows from imports', () async {
      // Guard: only run when the example is present (it ships with the repo).
      if (!restRunner.existsSync()) {
        markTestSkipped('example runner not found');
        return;
      }
      final result = await inspectSuite(restRunner);

      expect(result.mode, SuiteMode.cli);
      expect(
        result.actors.map((a) => a.name),
        containsAll(<String>['fireshActor', 'watershActor']),
      );
      // The smoke journey flow is declared in an imported *_flow.dart file and
      // must be resolved via neighbour-file parsing.
      final smoke = result.flows.firstWhere(
        (f) => f.name.contains('full smoke journey'),
        orElse: () => throw StateError(
          'smoke journey flow not resolved; flows: '
          '${result.flows.map((f) => f.name).toList()}',
        ),
      );
      expect(smoke.kind, FlowKind.lasting);
      expect(smoke.tags, containsAll(<String>['smoke', 'e2e']));
      expect(smoke.stepNames, isNotEmpty);
      expect(
        smoke.stepNames.first,
        contains('Firesh registers'),
      );
    });

    test('aggregated tags include smoke and regression', () async {
      if (!restRunner.existsSync()) {
        markTestSkipped('example runner not found');
        return;
      }
      final result = await inspectSuite(restRunner);
      expect(result.allTags, contains('smoke'));
    });
  });

  group('inspectSuite — serverpod dart_test', () {
    test('detects dart_test mode', () async {
      if (!serverpodTest.existsSync()) {
        markTestSkipped('serverpod example not found');
        return;
      }
      final result = await inspectSuite(serverpodTest);
      expect(result.mode, SuiteMode.dartTest);
    });
  });

  group('inspectSuite — error paths', () {
    test('non-existent file yields unknown mode + warning', () async {
      final result = await inspectSuite(File('/no/such/suite.dart'));
      expect(result.mode, SuiteMode.unknown);
      expect(result.warnings, isNotEmpty);
      expect(result.flows, isEmpty);
    });
  });

  group('findSuites', () {
    test('discovers the rest runner under example/', () {
      final found = findSuites(Directory(repoRoot)).map((f) => f.path);
      if (!restRunner.existsSync()) {
        markTestSkipped('example runner not found');
        return;
      }
      expect(found, contains(restRunner.absolute.path));
    });
  });
}
