import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:testeador_base/mirador.dart';
import 'package:testeador_base/testeador_base.dart';

/// mirador — panel de supervisión visual.
///
/// ```sh
/// dart run testeador_base:mirador ingest --from <dir> --scenario f6
/// dart run testeador_base:mirador review --once
/// dart run testeador_base:mirador promote --scenario f6 --slugs a,b
/// ```
Future<void> main(List<String> argv) async {
  final root = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Esta ayuda.')
    ..addCommand(
      'ingest',
      ArgParser()
        ..addOption(
          'from',
          help: 'Directorio que dejó pullArtifacts (busca PNG recursivamente).',
          mandatory: true,
        )
        ..addOption('base-dir', defaultsTo: 'test_evidence')
        ..addOption('scenario', help: 'Nombre del flujo.', mandatory: true)
        ..addOption(
          'actor',
          help:
              'Persona. Por defecto, lo que sigue al último "-" del scenario.',
        )
        ..addOption(
          'intents',
          help:
              'JSON {label: intent} para las capturas que aún no declaran '
              'el suyo (el steps.json del device tiene precedencia).',
        ),
    )
    ..addCommand(
      'capture',
      ArgParser()
        ..addOption('base-dir', defaultsTo: 'test_evidence')
        ..addOption('scenario', help: 'Nombre del escenario.', mandatory: true)
        ..addOption('actor', help: 'Persona / actor.', mandatory: true)
        ..addOption('slug', help: 'Paso que se fotografía.', mandatory: true)
        ..addOption('intent', help: 'Qué se espera ver en la pantalla.')
        ..addOption(
          'serial',
          defaultsTo: 'emulator-5554',
          help: 'Serial de adb del emulador.',
        )
        ..addOption('adb', defaultsTo: 'adb'),
    )
    ..addCommand(
      'review',
      ArgParser()
        ..addOption('base-dir', defaultsTo: 'test_evidence')
        ..addOption('port', defaultsTo: '4771')
        ..addFlag(
          'once',
          defaultsTo: true,
          help: 'Cerrar al recibir el veredicto (el modo del loop de trabajo).',
        )
        ..addFlag('all', help: 'Incluir también las capturas sin cambios.')
        ..addOption(
          'propose',
          help:
              'JSON {"<scenario>/<actor>/<slug>": {"verdict":…,"rationale":…}} '
              'con el pre-juicio del agente.',
        ),
    )
    ..addCommand(
      'promote',
      ArgParser()
        ..addOption('base-dir', defaultsTo: 'test_evidence')
        ..addOption('scenario', mandatory: true)
        ..addOption('actor', mandatory: true)
        ..addOption(
          'slugs',
          help: 'Lista separada por comas.',
          mandatory: true,
        ),
    );

  final ArgResults args;
  try {
    args = root.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln('mirador: ${e.message}\n');
    stdout.writeln(_usage(root));
    exitCode = 64;
    return;
  }

  final cmd = args.command;
  if (args.flag('help') || cmd == null) {
    stdout.writeln(_usage(root));
    return;
  }

  switch (cmd.name) {
    case 'ingest':
      final scenario = cmd.option('scenario')!;
      final result = ingestPatrolRun(
        sourceDir: cmd.option('from')!,
        baseDir: cmd.option('base-dir')!,
        scenario: scenario,
        actor: cmd.option('actor') ?? _actorFrom(scenario),
        intents: _intents(cmd.option('intents')),
      );
      stdout.writeln(
        'ingerido ${result.scenario} / ${result.actor}: '
        '${result.captures} captura(s), ${result.drifted} con drift, '
        '${result.brandNew} sin baseline.\n${result.manifestPath}',
      );

    case 'capture':
      final device = AndroidEmulator(
        serial: cmd.option('serial')!,
        adbPath: cmd.option('adb')!,
      );
      final result = await captureLive(
        take: device.screenshot,
        source: device.id,
        baseDir: cmd.option('base-dir')!,
        scenario: cmd.option('scenario')!,
        actor: cmd.option('actor')!,
        slug: cmd.option('slug')!,
        intent: cmd.option('intent'),
      );
      stdout.writeln(
        'capturado ${result.scenario}/${result.actor}/${result.slug}: '
        '${result.isNew ? 'sin baseline (~new)' : '${'!' * result.marks}'
                  ' ${(result.ratio * 100).toStringAsFixed(2)}% distinto'}'
        '\n${result.capture}',
      );

    case 'review':
      final baseDir = cmd.option('base-dir')!;
      final server = MiradorServer(
        baseDir: baseDir,
        port: int.parse(cmd.option('port')!),
        once: cmd.flag('once'),
      );
      final proposals = _proposals(cmd.option('propose'));
      final url = 'http://127.0.0.1:${server.boundPort}';
      stdout.writeln('mirador escuchando en $url  (base: $baseDir)');
      final outcome = await server.serve(
        proposals: proposals,
        includeUnchanged: cmd.flag('all'),
      );
      if (outcome == null) {
        stdout.writeln('cerrado sin veredicto.');
        return;
      }
      stdout.writeln('veredicto: ${outcome.decisions.length} decisión(es)');
      for (final d in outcome.decisions) {
        stdout.writeln(
          '  ${d.verdict.wire.padRight(17)} ${d.scenario}/${d.actor}/${d.slug}'
          '${d.marks.isEmpty ? '' : '  (${d.marks.length} marca/s)'}',
        );
      }
      if (outcome.roundNote != null && outcome.roundNote!.isNotEmpty) {
        stdout.writeln('nota de la ronda: ${outcome.roundNote}');
      }

    case 'promote':
      final n = promoteToBaseline(
        baseDir: cmd.option('base-dir')!,
        scenario: cmd.option('scenario')!,
        actor: cmd.option('actor')!,
        slugs: cmd.option('slugs')!.split(',').map((s) => s.trim()),
      );
      stdout.writeln('promovidas $n captura(s) a baseline.');
  }
}

String _usage(ArgParser root) =>
    '''
mirador — panel de supervisión visual.

  capture   fotografía la app corriendo en el emulador y la difea
  ingest    normaliza una corrida de patrol al layout del contrato y difea
  review    sirve el panel y espera el veredicto
  promote   copia capturas a baseline (lo que ejecuta un replace_baseline)

${root.usage}

capture:
${root.commands['capture']!.usage}

ingest:
${root.commands['ingest']!.usage}

review:
${root.commands['review']!.usage}

promote:
${root.commands['promote']!.usage}''';

/// `f2-converso` → `converso`.
String _actorFrom(String scenario) {
  final ix = scenario.lastIndexOf('-');
  return ix < 0 ? scenario : scenario.substring(ix + 1);
}

Map<String, String> _intents(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  return {
    for (final e in decoded.entries)
      if (e.value is String) e.key: e.value! as String,
  };
}

Map<String, Proposal> _proposals(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  final decoded = jsonDecode(raw) as Map<String, Object?>;
  final out = <String, Proposal>{};
  for (final e in decoded.entries) {
    final v = e.value;
    if (v is! Map<String, Object?>) continue;
    final verdict = Verdict.values.firstWhere(
      (x) => x.wire == v['verdict'],
      orElse: () => Verdict.inconclusive,
    );
    out[e.key] = Proposal(verdict, (v['rationale'] as String?) ?? '');
  }
  return out;
}
