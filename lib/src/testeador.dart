import 'dart:io';

import 'package:args/args.dart';
import 'package:test/test.dart' as dart_test;
import 'package:testeador/src/actor.dart';
import 'package:testeador/src/test_flow.dart';
import 'package:testeador/src/testeador_options.dart';

/// {@template testeador}
/// Orchestrates the execution of [TestFlow]s.
///
/// Use [registerWithDartTest] to integrate with `dart test`.
/// Use [run] to execute as a standalone CLI binary.
/// {@endtemplate}
class Testeador {
  /// {@macro testeador}
  const Testeador({
    required this.flows,
    this.actors = const [],
  });

  /// The flows to orchestrate.
  final List<TestFlow> flows;

  /// Actors whose cURL logs are cleared before each flow and printed on
  /// failure.
  final List<Actor> actors;

  // ---------------------------------------------------------------------------
  // dart test integration
  // ---------------------------------------------------------------------------

  /// Registers all flows as `group()`/`test()` blocks with `package:test`.
  ///
  /// Call this inside `main()` in a file run by `dart test`.
  void registerWithDartTest([
    TesteadorOptions options = const TesteadorOptions(),
  ]) {
    _injectInterceptors();
    final filtered = _filter(flows, options);
    for (final flow in filtered) {
      dart_test.group(flow.name, () {
        dynamic context;

        dart_test.setUpAll(() async {
          _clearActorLogs();
          if (flow.fixture != null) {
            context = await flow.fixture!.load();
          }
        });

        dart_test.tearDownAll(() async {
          if (flow.fixture != null && context != null) {
            await flow.fixture!.dispose(context);
          }
        });

        for (final step in flow.steps) {
          dart_test.test(step.name, () async {
            await step.execute();
          });
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Standalone CLI runner
  // ---------------------------------------------------------------------------

  /// Parses [args] and runs flows sequentially, then calls [exit].
  ///
  /// Supported flags:
  ///
  /// ```text
  /// --include-tags          Comma-separated tags to include
  /// --exclude-tags          Comma-separated tags to exclude
  /// --include-flows         Comma-separated flow names to include
  /// --exclude-flows         Comma-separated flow names to exclude
  /// --[no-]fail-fast        Stop on first failure (default: true)
  /// --[no-]verbose          Print step names as they run (default: false)
  /// --[no-]exit-on-failure  Exit with code 1 on failure (default: true)
  /// --[no-]show-curls       Print cURL log on failure (default: true)
  /// --[no-]show-stack-traces Print stack traces on failure (default: false)
  /// --help                  Show usage
  /// ```
  Future<void> run(List<String> args) async {
    _injectInterceptors();
    final parser = _buildArgParser();
    ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (e) {
      stderr
        ..writeln('Error parsing arguments: $e')
        ..writeln(parser.usage);
      exit(1);
    }

    if (results['help'] as bool) {
      stdout.writeln(parser.usage);
      exit(0);
    }

    final options = _optionsFromArgs(results);
    final filtered = _filter(flows, options);

    stdout.writeln('testeador — running ${filtered.length} flow(s)');

    var failureCount = 0;

    for (final flow in filtered) {
      stdout.writeln('\n▶ ${flow.name}');
      if (options.verbose && flow.description != null) {
        stdout.writeln('  ${flow.description}');
      }

      _clearActorLogs();
      dynamic context;

      try {
        if (flow.fixture != null) {
          if (options.verbose) stdout.writeln('  [fixture] loading...');
          context = await flow.fixture!.load();
        }

        for (final step in flow.steps) {
          if (options.verbose) stdout.writeln('  • ${step.name}');
          await step.execute();
        }

        stdout.writeln('  ✓ passed');
      } catch (e, st) {
        failureCount++;
        stderr.writeln('  ✗ FAILED: $e');

        if (options.showCurls) {
          _printCurlLogs();
        }

        if (options.showStackTraces) {
          stderr.writeln(st);
        }

        if (options.failFast) {
          break;
        }
      } finally {
        if (flow.fixture != null && context != null) {
          try {
            await flow.fixture!.dispose(context);
          } on Exception catch (e) {
            stderr.writeln('  [fixture] dispose error: $e');
          }
        }
      }
    }

    stdout.writeln(
      '\n${filtered.length - failureCount}/${filtered.length} flows passed.',
    );

    if (failureCount > 0 && options.exitOnFailure) {
      exit(1);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<TestFlow> _filter(List<TestFlow> all, TesteadorOptions opts) {
    return all.where((flow) {
      if (opts.includeFlows.isNotEmpty &&
          !opts.includeFlows.contains(flow.name)) {
        return false;
      }
      if (opts.excludeFlows.contains(flow.name)) return false;
      if (opts.includeTags.isNotEmpty &&
          !flow.tags.any(opts.includeTags.contains)) {
        return false;
      }
      if (flow.tags.any(opts.excludeTags.contains)) return false;
      return true;
    }).toList();
  }

  void _injectInterceptors() {
    for (final actor in actors) {
      if (!actor.dio.interceptors.contains(actor.curlInterceptor)) {
        actor.dio.interceptors.add(actor.curlInterceptor);
      }
    }
  }

  void _clearActorLogs() {
    for (final actor in actors) {
      actor.curlInterceptor.clear();
    }
  }

  void _printCurlLogs() {
    for (final actor in actors) {
      final log = actor.curlInterceptor.log;
      if (log.isEmpty) continue;
      stderr.writeln('\n  cURL log for actor "${actor.name}":');
      for (final curl in log) {
        stderr.writeln('    $curl');
      }
    }
  }

  static ArgParser _buildArgParser() {
    return ArgParser()
      ..addOption('include-tags', help: 'Comma-separated tags to include')
      ..addOption('exclude-tags', help: 'Comma-separated tags to exclude')
      ..addOption(
        'include-flows',
        help: 'Comma-separated flow names to include',
      )
      ..addOption(
        'exclude-flows',
        help: 'Comma-separated flow names to exclude',
      )
      ..addFlag('fail-fast', defaultsTo: true, help: 'Stop on first failure')
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Print step names',
      )
      ..addFlag(
        'exit-on-failure',
        defaultsTo: true,
        help: 'Exit with code 1 on failure',
      )
      ..addFlag(
        'show-curls',
        defaultsTo: true,
        help: 'Print cURL log on failure',
      )
      ..addFlag(
        'show-stack-traces',
        help: 'Print stack traces on failure',
      )
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');
  }

  static TesteadorOptions _optionsFromArgs(ArgResults r) {
    Set<String> splitOption(String key) {
      final val = r[key] as String?;
      if (val == null || val.isEmpty) return {};
      return val.split(',').map((s) => s.trim()).toSet();
    }

    return TesteadorOptions(
      includeTags: splitOption('include-tags'),
      excludeTags: splitOption('exclude-tags'),
      includeFlows: splitOption('include-flows'),
      excludeFlows: splitOption('exclude-flows'),
      failFast: r['fail-fast'] as bool,
      verbose: r['verbose'] as bool,
      exitOnFailure: r['exit-on-failure'] as bool,
      showCurls: r['show-curls'] as bool,
      showStackTraces: r['show-stack-traces'] as bool,
    );
  }
}
