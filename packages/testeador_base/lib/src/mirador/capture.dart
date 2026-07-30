import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:testeador_base/src/evidence/evidence_config.dart';
import 'package:testeador_base/src/evidence/naming.dart';
import 'package:testeador_base/src/evidence/pixel_diff.dart';
import 'package:testeador_base/src/evidence/run_manifest.dart';

/// Toma un screenshot y lo deja en el archivo indicado. Es el seam del
/// transporte: `TargetDevice.screenshot` lo cumple tal cual, y un test lo
/// sustituye sin emulador.
typedef ScreenshotTaker = Future<File> Function(File out);

/// Captura la app **corriendo** en un device y la deja lista para revisar.
///
/// Es el camino más corto del loop de supervisión: no hay test que escribir ni
/// suite que correr — se fotografía lo que está en pantalla ahora mismo y se
/// compara contra el baseline del mismo `slug`.
///
/// A diferencia de la evidencia de widget test o de patrol (que rasterizan el
/// árbol de widgets), esto es un screenshot del **device entero**: incluye la
/// barra de estado del sistema. Por eso `origin` es `live` y no se mezcla con
/// las otras fuentes: comparar entre fuentes distintas da drift espurio.
Future<IngestResultLive> captureLive({
  required ScreenshotTaker take,
  required String baseDir,
  required String scenario,
  required String actor,
  required String slug,
  String? intent,
  String source = 'device',
  EvidenceConfig config = defaultEvidenceConfig,
}) async {
  final scenarioSlug = slugify(scenario);
  final actorSlug = slugify(actor);
  final stepSlug = slugify(slug);
  final runDir = scenarioRunDir(baseDir: baseDir, scenario: scenarioSlug);
  final baselineDir = scenarioBaselineDir(
    baseDir: baseDir,
    scenario: scenarioSlug,
  );
  Directory(runDir).createSync(recursive: true);
  Directory(baselineDir).createSync(recursive: true);

  // A un temporal primero: si el screenshot falla, no se toca la evidencia
  // buena que ya estaba en el run dir.
  final tmp = File(p.join(Directory.systemTemp.path, 'mirador-live.png'));
  await take(tmp);
  final bytes = tmp.readAsBytesSync();
  final actual = img.decodePng(bytes);
  if (actual == null) {
    throw StateError(
      'el screenshot de $source no es un PNG legible (${bytes.length} B)',
    );
  }

  final manifest = RunManifest(
    actor: actorSlug,
    scenario: scenarioSlug,
    scenarioDir: runDir,
    viewportPreset: 'device',
    logicalSize: [actual.width, actual.height],
    devicePixelRatio: 1,
    capturePixelRatio: 1,
  );

  final baselineFile = File(
    p.join(baselineDir, baselineFileName(actor: actorSlug, slug: stepSlug)),
  );
  final baseline = baselineFile.existsSync()
      ? img.decodePng(baselineFile.readAsBytesSync())
      : null;

  String marker;
  ({double ratio, int marks, bool dimensionMismatch, String? image})? diff;
  if (baseline == null) {
    marker = newMarker;
  } else {
    final score = diffScore(
      actual: actual,
      baseline: baseline,
      noiseFloor: config.noiseFloor,
      maxMarks: config.maxMarks,
      channelTolerance: config.channelTolerance,
    );
    marker = marksSuffix(score.marks);
    String? diffImage;
    if (score.marks > 0 && !score.dimensionMismatch) {
      final name = diffFileName(
        actor: actorSlug,
        order: 1,
        slug: stepSlug,
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
    order: 1,
    slug: stepSlug,
    marker: marker,
  );
  File(p.join(runDir, captureName)).writeAsBytesSync(bytes);

  manifest.recordStep(
    order: 1,
    slug: stepSlug,
    description: slug,
    status: 'ok',
    intent: intent,
    capture: captureName,
    baseline: baseline == null
        ? null
        : manifestRelative(from: manifest.path, target: baselineFile.path),
    diff: diff,
    origin: 'live',
  );

  return IngestResultLive(
    scenario: scenarioSlug,
    actor: actorSlug,
    slug: stepSlug,
    manifestPath: manifest.path,
    capture: p.join(runDir, captureName),
    marks: diff?.marks ?? 0,
    ratio: diff?.ratio ?? 0,
    isNew: baseline == null,
  );
}

/// Resultado de una captura en vivo.
final class IngestResultLive {
  /// Registra el resultado de la captura.
  const IngestResultLive({
    required this.scenario,
    required this.actor,
    required this.slug,
    required this.manifestPath,
    required this.capture,
    required this.marks,
    required this.ratio,
    required this.isNew,
  });

  /// Escenario, ya slugificado.
  final String scenario;

  /// Actor, ya slugificado.
  final String actor;

  /// Paso, ya slugificado.
  final String slug;

  /// Ruta absoluta del manifest escrito.
  final String manifestPath;

  /// Ruta absoluta de la captura.
  final String capture;

  /// Marcas del drift contra el baseline (0 si no había).
  final int marks;

  /// Fracción de píxeles distintos.
  final double ratio;

  /// No había baseline: la captura es `~new`.
  final bool isNew;
}
