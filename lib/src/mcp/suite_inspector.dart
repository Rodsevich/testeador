import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

/// How a suite is wired: a standalone CLI (`Testeador.run`) or a
/// `dart test`-registered file (`registerWithDartTest`).
enum SuiteMode {
  /// `bin/*.dart` calling `Testeador(...).run(args)`.
  cli,

  /// `test/*.dart` calling `Testeador(...).registerWithDartTest()`.
  dartTest,

  /// File contains `Testeador(...)` but neither call form. Rare.
  unknown,
}

/// `lasting` vs `transient` flavor of a flow.
enum FlowKind {
  /// `TestFlowLasting`.
  lasting,

  /// `TestFlowTransient`.
  transient,
}

/// Actor reference discovered in a suite.
class InspectedActor {
  /// Creates an [InspectedActor].
  const InspectedActor({required this.name, this.file});

  /// Actor identifier as it appears in the source (variable name, class name,
  /// or factory function name).
  final String name;

  /// File where the actor was defined, if resolvable from the suite's
  /// neighbour files. May be `null`.
  final String? file;

  /// JSON-friendly representation.
  Map<String, dynamic> toJson() =>
      {'name': name, if (file != null) 'file': file};
}

/// One flow discovered in a suite (or in an imported `*_flow.dart` file).
class InspectedFlow {
  /// Creates an [InspectedFlow].
  const InspectedFlow({
    required this.name,
    required this.kind,
    required this.tags,
    required this.stepNames,
    this.description,
    this.file,
  });

  /// `name:` argument of the `TestFlowLasting`/`TestFlowTransient` ctor.
  final String name;

  /// Whether the flow is lasting or transient.
  final FlowKind kind;

  /// `tags:` set (string literals only; non-literal entries are dropped).
  final List<String> tags;

  /// `name:` of every `TestStep` declared in the `steps:` list.
  final List<String> stepNames;

  /// `description:` argument, if present.
  final String? description;

  /// File where the flow was declared.
  final String? file;

  /// JSON-friendly representation.
  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'tags': tags,
        'step_names': stepNames,
        if (description != null) 'description': description,
        if (file != null) 'file': file,
      };
}

/// Result of [inspectSuite].
class InspectedSuite {
  /// Creates an [InspectedSuite].
  const InspectedSuite({
    required this.path,
    required this.mode,
    required this.actors,
    required this.flows,
    required this.warnings,
  });

  /// Absolute path of the suite file.
  final String path;

  /// CLI vs dart_test mode.
  final SuiteMode mode;

  /// Actors passed in the `actors:` arg of `Testeador(...)`.
  final List<InspectedActor> actors;

  /// All flows reachable via the `flows:` arg (recurses into imported files).
  final List<InspectedFlow> flows;

  /// Non-fatal warnings (e.g. flow function not found in imports).
  final List<String> warnings;

  /// Aggregated tag set across [flows].
  Set<String> get allTags => {for (final f in flows) ...f.tags};

  /// JSON-friendly representation.
  Map<String, dynamic> toJson() => {
        'path': path,
        'mode': mode.name,
        'actors': actors.map((a) => a.toJson()).toList(),
        'flows': flows.map((f) => f.toJson()).toList(),
        'tags': allTags.toList()..sort(),
        'warnings': warnings,
      };
}

/// Parses [suite] and returns its structure.
///
/// Strategy:
///   1. Parse the suite file with `parseString` (no resolution — fast).
///   2. Locate the `Testeador(...)` invocation. Detect mode by sibling call
///      `.run(args)` vs `.registerWithDartTest()`.
///   3. Walk the `actors:` and `flows:` arguments. For each flow expression
///      (a function call like `buildSmokeJourneyFlow()`), find the matching
///      function/method declaration by name in the suite file and the files
///      imported with relative URIs (typical pattern: `../test/flows/x.dart`).
///   4. In each declaration, look for a `TestFlowLasting(...)` /
///      `TestFlowTransient(...)` ctor and extract `name`, `tags`, `steps`,
///      `description`.
Future<InspectedSuite> inspectSuite(File suite) async {
  final warnings = <String>[];
  final absolutePath = suite.absolute.path;
  if (!suite.existsSync()) {
    return InspectedSuite(
      path: absolutePath,
      mode: SuiteMode.unknown,
      actors: const [],
      flows: const [],
      warnings: ['Suite file does not exist.'],
    );
  }

  final unit = _parseFile(suite);
  final visitor = _TesteadorCallVisitor();
  unit.accept(visitor);

  if (visitor.testeadorArgs == null) {
    return InspectedSuite(
      path: absolutePath,
      mode: SuiteMode.unknown,
      actors: const [],
      flows: const [],
      warnings: ['No `Testeador(...)` invocation found in suite.'],
    );
  }

  final mode = visitor.usesRun
      ? SuiteMode.cli
      : (visitor.usesRegister ? SuiteMode.dartTest : SuiteMode.unknown);

  final actors = _extractActors(visitor.testeadorArgs!);
  final flowExprs = _extractFlowExpressions(visitor.testeadorArgs!);

  final neighbours = _resolveNeighbourFiles(suite, unit);
  final flowsByName = <String, _FlowDeclarationMatch>{};
  _collectFlowDeclarations(unit, suite.path, flowsByName);
  for (final n in neighbours) {
    try {
      final nUnit = _parseFile(n);
      _collectFlowDeclarations(nUnit, n.path, flowsByName);
    } on Exception catch (e) {
      warnings.add('Failed to parse neighbour file ${n.path}: $e');
    }
  }

  final flows = <InspectedFlow>[];
  for (final expr in flowExprs) {
    final hit = flowsByName[expr];
    if (hit == null) {
      warnings.add('Could not resolve flow expression: $expr');
      continue;
    }
    flows.add(hit.flow);
  }

  return InspectedSuite(
    path: absolutePath,
    mode: mode,
    actors: actors,
    flows: flows,
    warnings: warnings,
  );
}

/// Scans [projectRoot] for files that construct a `Testeador(...)`.
///
/// Looks under `bin/` and `test/`, plus the equivalent dirs nested under
/// `example/*/` so the testeador repo's own examples are discovered.
List<File> findSuites(Directory projectRoot) {
  final results = <File>[];
  final candidateRoots = <Directory>[
    Directory(p.join(projectRoot.path, 'bin')),
    Directory(p.join(projectRoot.path, 'test')),
  ];
  final exampleRoot = Directory(p.join(projectRoot.path, 'example'));
  if (exampleRoot.existsSync()) {
    for (final child in exampleRoot.listSync().whereType<Directory>()) {
      candidateRoots
        ..add(Directory(p.join(child.path, 'bin')))
        ..add(Directory(p.join(child.path, 'test')));
      // Flutter sub-project shape (e.g. pokebattle_serverpod_flutter).
      for (final grand in child.listSync().whereType<Directory>()) {
        candidateRoots
          ..add(Directory(p.join(grand.path, 'bin')))
          ..add(Directory(p.join(grand.path, 'test')));
      }
    }
  }

  for (final root in candidateRoots) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      // Quick string-grep before paying the AST cost.
      final body = entity.readAsStringSync();
      if (!body.contains('Testeador(')) continue;
      results.add(entity);
    }
  }
  return results;
}

CompilationUnit _parseFile(File f) {
  final result = parseString(
    content: f.readAsStringSync(),
    featureSet: FeatureSet.latestLanguageVersion(),
    path: f.path,
    throwIfDiagnostics: false,
  );
  return result.unit;
}

/// In an *unresolved* AST, a constructor call without `new`/`const`
/// (`Testeador(...)`, `TestFlowLasting(...)`, `TestStep(...)`) is parsed as a
/// [MethodInvocation], not an [InstanceCreationExpression]. This helper
/// normalizes both forms to `(name, args)` so the inspector works without
/// type resolution.
({String name, ArgumentList args})? _callInfo(Expression expr) {
  if (expr is InstanceCreationExpression) {
    return (
      name: expr.constructorName.type.name.lexeme,
      args: expr.argumentList,
    );
  }
  if (expr is MethodInvocation && expr.target == null) {
    return (name: expr.methodName.name, args: expr.argumentList);
  }
  return null;
}

class _TesteadorCallVisitor extends RecursiveAstVisitor<void> {
  ArgumentList? testeadorArgs;
  bool usesRun = false;
  bool usesRegister = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'Testeador') {
      testeadorArgs ??= node.argumentList;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'run') usesRun = true;
    if (name == 'registerWithDartTest') usesRegister = true;
    if (name == 'Testeador' && node.target == null) {
      testeadorArgs ??= node.argumentList;
    }
    super.visitMethodInvocation(node);
  }
}

List<InspectedActor> _extractActors(ArgumentList callArgs) {
  final arg = _namedArg(callArgs, 'actors');
  if (arg is! ListLiteral) return const [];
  final out = <InspectedActor>[];
  for (final el in arg.elements) {
    if (el is Expression) {
      final info = _callInfo(el);
      if (info != null) {
        out.add(InspectedActor(name: info.name));
        continue;
      }
    }
    if (el is SimpleIdentifier) {
      out.add(InspectedActor(name: el.name));
    }
  }
  return out;
}

List<String> _extractFlowExpressions(ArgumentList callArgs) {
  final arg = _namedArg(callArgs, 'flows');
  if (arg is! ListLiteral) return const [];
  final out = <String>[];
  for (final el in arg.elements) {
    if (el is Expression) {
      final info = _callInfo(el);
      if (info != null) {
        out.add(info.name);
        continue;
      }
    }
    if (el is SimpleIdentifier) {
      out.add(el.name);
    }
  }
  return out;
}

Expression? _namedArg(ArgumentList args, String name) {
  for (final a in args.arguments) {
    if (a is NamedExpression && a.name.label.name == name) {
      return a.expression;
    }
  }
  return null;
}

class _FlowDeclarationMatch {
  _FlowDeclarationMatch(this.flow);
  final InspectedFlow flow;
}

void _collectFlowDeclarations(
  CompilationUnit unit,
  String filePath,
  Map<String, _FlowDeclarationMatch> out,
) {
  for (final decl in unit.declarations) {
    if (decl is FunctionDeclaration) {
      final flow = _extractFlowFromBody(decl.functionExpression.body);
      if (flow != null) {
        out[decl.name.lexeme] = _FlowDeclarationMatch(
          flow.copyWithFile(filePath),
        );
      }
    } else if (decl is TopLevelVariableDeclaration) {
      for (final v in decl.variables.variables) {
        final init = v.initializer;
        if (init == null) continue;
        final flow = _extractFlowFromExpression(init);
        if (flow != null) {
          out[v.name.lexeme] = _FlowDeclarationMatch(
            flow.copyWithFile(filePath),
          );
        }
      }
    }
  }
}

extension on InspectedFlow {
  InspectedFlow copyWithFile(String f) => InspectedFlow(
        name: name,
        kind: kind,
        tags: tags,
        stepNames: stepNames,
        description: description,
        file: f,
      );
}

InspectedFlow? _extractFlowFromBody(FunctionBody body) {
  Expression? returned;
  if (body is ExpressionFunctionBody) {
    returned = body.expression;
  } else if (body is BlockFunctionBody) {
    for (final stmt in body.block.statements.reversed) {
      if (stmt is ReturnStatement) {
        returned = stmt.expression;
        break;
      }
    }
  }
  if (returned == null) return null;
  return _extractFlowFromExpression(returned);
}

InspectedFlow? _extractFlowFromExpression(Expression expr) {
  final info = _callInfo(expr);
  if (info == null) return null;
  FlowKind? kind;
  if (info.name == 'TestFlowLasting') kind = FlowKind.lasting;
  if (info.name == 'TestFlowTransient') kind = FlowKind.transient;
  if (kind == null) return null;

  final args = info.args;
  final nameArg = _namedArg(args, 'name');
  final tagsArg = _namedArg(args, 'tags');
  final stepsArg = _namedArg(args, 'steps');
  final descArg = _namedArg(args, 'description');

  return InspectedFlow(
    name: _stringLiteral(nameArg) ?? '<unresolved>',
    kind: kind,
    tags: _extractStringSet(tagsArg),
    stepNames: _extractStepNames(stepsArg),
    description: _stringLiteral(descArg),
  );
}

String? _stringLiteral(Expression? expr) {
  if (expr is SimpleStringLiteral) return expr.value;
  if (expr is AdjacentStrings) {
    final buf = StringBuffer();
    for (final s in expr.strings) {
      if (s is SimpleStringLiteral) {
        buf.write(s.value);
      } else {
        return null;
      }
    }
    return buf.toString();
  }
  return null;
}

List<String> _extractStringSet(Expression? expr) {
  if (expr is! SetOrMapLiteral) return const [];
  final out = <String>[];
  for (final el in expr.elements) {
    if (el is SimpleStringLiteral) out.add(el.value);
  }
  return out;
}

List<String> _extractStepNames(Expression? expr) {
  if (expr is! ListLiteral) return const [];
  final out = <String>[];
  for (final el in expr.elements) {
    if (el is! Expression) continue;
    final info = _callInfo(el);
    if (info == null || info.name != 'TestStep') continue;
    final s = _stringLiteral(_namedArg(info.args, 'name'));
    if (s != null) out.add(s);
  }
  return out;
}

List<File> _resolveNeighbourFiles(File suite, CompilationUnit unit) {
  final out = <File>[];
  final dir = suite.parent;
  for (final d in unit.directives) {
    if (d is ImportDirective) {
      final uri = d.uri.stringValue;
      if (uri == null) continue;
      if (uri.startsWith('package:') || uri.startsWith('dart:')) continue;
      final f = File(p.normalize(p.join(dir.path, uri)));
      if (f.existsSync()) out.add(f);
    }
  }
  return out;
}
