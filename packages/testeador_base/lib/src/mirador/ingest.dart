import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:testeador_base/src/evidence/evidence_config.dart';
import 'package:testeador_base/src/evidence/naming.dart';
import 'package:testeador_base/src/evidence/pixel_diff.dart';
import 'package:testeador_base/src/evidence/run_manifest.dart';

/// Resultado de ingerir una corrida.
final class IngestResult {
  /// Registra el resultado de una ingesta.
  const IngestResult({
    required this.scenario,
    required this.actor,
    required this.manifestPath,
    required this.captures,
    required this.drifted,
    required this.brandNew,
  });

  /// Escenario ingerido, ya slugificado.
  final String scenario;

  /// Actor (la persona), ya slugificado.
  final String actor;

  /// Ruta absoluta del manifest escrito.
  final String manifestPath;

  /// Capturas ingeridas.
  final int captures;

  /// Cuántas tienen marcas (> 0).
  final int drifted;

  /// Cuántas no tenían baseline.
  final int brandNew;
}

/// Normaliza una corrida de patrol al layout del contrato y calcula los diffs.
///
/// Entrada: el árbol que deja `DeviceFleet.pullArtifacts`, es decir
/// `<evidenceDir>/<label-del-flujo>/<platform>-<id>/NN-<label>.png`.
/// Salida: `<baseDir>/runs/current/<scenario>/<actor>.manifest.json` con sus
/// capturas y trípticos, listo para `mirador review`.
///
/// **Se parea por label, nunca por el prefijo `NN-`**: ese número es el
/// contador de capturas efectivamente escritas, no el índice del paso, así que
/// se corre solo con que un shot condicional no dispare. El orden se toma del
/// número para mostrar, pero la identidad del paso es el slug.
IngestResult ingestPatrolRun({
  required String sourceDir,
  required String baseDir,
  required String scenario,
  required String actor,
  Map<String, String> intents = const {},
  EvidenceConfig config = defaultEvidenceConfig,
}) {
  final src = Directory(sourceDir);
  if (!src.existsSync()) {
    throw ArgumentError('no existe el directorio de evidencia: $sourceDir');
  }

  // Los intents que el flujo declaró en el device pesan más que los que venga
  // a inventar quien ingesta: el paso es el dueño de su contrato.
  final declarados = _declaredIntents(src);
  final efectivos = <String, String>{...intents, ...declarados};

  final pngs =
      src
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  final scenarioSlug = slugify(scenario);
  final actorSlug = slugify(actor);
  final runDir = scenarioRunDir(baseDir: baseDir, scenario: scenarioSlug);
  final baselineDir = scenarioBaselineDir(
    baseDir: baseDir,
    scenario: scenarioSlug,
  );
  Directory(runDir).createSync(recursive: true);
  Directory(baselineDir).createSync(recursive: true);

  // El constructor limpia los artefactos previos DE ESTE actor.
  final manifest = RunManifest(
    actor: actorSlug,
    scenario: scenarioSlug,
    scenarioDir: runDir,
    viewportPreset: 'device',
    logicalSize: const [0, 0],
    devicePixelRatio: 1,
    capturePixelRatio: 1,
  );

  var order = 0;
  var drifted = 0;
  var brandNew = 0;

  for (final file in pngs) {
    final label = _labelOf(p.basename(file.path));
    if (label == null) continue;
    final slug = slugify(label);
    order++;

    final actualBytes = file.readAsBytesSync();
    final actual = img.decodePng(actualBytes);
    if (actual == null) continue;

    final baselineFile = File(
      p.join(baselineDir, baselineFileName(actor: actorSlug, slug: slug)),
    );
    final baseline = baselineFile.existsSync()
        ? img.decodePng(baselineFile.readAsBytesSync())
        : null;

    String marker;
    ({double ratio, int marks, bool dimensionMismatch, String? image})? diff;

    if (baseline == null) {
      marker = newMarker;
      brandNew++;
    } else {
      final score = diffScore(
        actual: actual,
        baseline: baseline,
        noiseFloor: config.noiseFloor,
        maxMarks: config.maxMarks,
        channelTolerance: config.channelTolerance,
      );
      marker = marksSuffix(score.marks);
      if (score.marks > 0) drifted++;

      String? diffImage;
      if (score.marks > 0 && !score.dimensionMismatch) {
        final name = diffFileName(
          actor: actorSlug,
          order: order,
          slug: slug,
          marker: marker,
        );
        File(p.join(runDir, name)).writeAsBytesSync(
          img.encodePng(
            composeDiffImage(
              baseline: baseline,
              actual: actual,
              channelTolerance: config.channelTolerance,
            ),
          ),
        );
        diffImage = name;
      }
      diff = (
        ratio: score.ratio,
        marks: score.marks,
        dimensionMismatch: score.dimensionMismatch,
        image: diffImage,
      );
    }

    final captureName = captureFileName(
      actor: actorSlug,
      order: order,
      slug: slug,
      marker: marker,
    );
    File(p.join(runDir, captureName)).writeAsBytesSync(actualBytes);

    manifest.recordStep(
      order: order,
      slug: slug,
      description: label,
      status: 'ok',
      intent: efectivos[label] ?? efectivos[slug],
      capture: captureName,
      baseline: baseline == null
          ? null
          : manifestRelative(from: manifest.path, target: baselineFile.path),
      diff: diff,
      origin: 'patrol',
    );
  }

  manifest.reconcileOrphans(baselineDir);

  return IngestResult(
    scenario: scenarioSlug,
    actor: actorSlug,
    manifestPath: manifest.path,
    captures: order,
    drifted: drifted,
    brandNew: brandNew,
  );
}

/// Levanta los intents del `steps.json` que `shots.dart` deja junto a los PNG
/// en el device. Sin ese archivo (corridas viejas), devuelve vacío.
Map<String, String> _declaredIntents(Directory src) {
  final out = <String, String>{};
  for (final f in src.listSync(recursive: true).whereType<File>()) {
    if (p.basename(f.path) != 'steps.json') continue;
    try {
      final doc = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      for (final raw in (doc['steps'] as List<Object?>? ?? const [])) {
        if (raw is! Map<String, Object?>) continue;
        final label = raw['label'];
        final intent = raw['intent'];
        if (label is String && intent is String && intent.isNotEmpty) {
          out[label] = intent;
        }
      }
    } on Object {
      // Un índice ilegible no debe impedir ingerir las capturas.
      continue;
    }
  }
  return out;
}

/// `03-opus-dies.png` → `opus-dies`. Devuelve `null` si no matchea el patrón.
String? _labelOf(String basename) {
  final m = RegExp(
    r'^(\d+)-(.+)\.png$',
    caseSensitive: false,
  ).firstMatch(basename);
  if (m != null) return m.group(2);
  // Sin prefijo numérico: el nombre entero es el label.
  final bare = basename.replaceAll(RegExp(r'\.png$', caseSensitive: false), '');
  return bare.isEmpty ? null : bare;
}

/// Promueve las capturas de una corrida a baseline. Es lo que ejecuta un
/// veredicto `replace_baseline`, y por eso vive acá y no en el panel: el panel
/// solo registra la decisión.
int promoteToBaseline({
  required String baseDir,
  required String scenario,
  required String actor,
  required Iterable<String> slugs,
}) {
  final scenarioSlug = slugify(scenario);
  final actorSlug = slugify(actor);
  final runDir = scenarioRunDir(baseDir: baseDir, scenario: scenarioSlug);
  final baselineDir = scenarioBaselineDir(
    baseDir: baseDir,
    scenario: scenarioSlug,
  );
  Directory(baselineDir).createSync(recursive: true);

  var promoted = 0;
  final entries = Directory(runDir).existsSync()
      ? Directory(runDir).listSync().whereType<File>().toList()
      : <File>[];

  for (final slug in slugs) {
    final wanted = slugify(slug);
    // La captura trae orden y marcas en el nombre; se la busca por slug.
    final match = entries.where((f) {
      final b = p.basename(f.path);
      return b.startsWith('$actorSlug-') &&
          !b.endsWith('.diff.png') &&
          RegExp('_${RegExp.escape(wanted)}(!*|~\\w+)\\.png\$').hasMatch(b);
    }).firstOrNull;
    if (match == null) continue;
    match.copySync(
      p.join(baselineDir, baselineFileName(actor: actorSlug, slug: wanted)),
    );
    promoted++;
  }
  return promoted;
}
