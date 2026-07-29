import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:testeador_base/src/evidence/naming.dart';
import 'package:testeador_base/src/evidence/run_manifest.dart';
import 'package:testeador_base/src/mirador/brushes.dart';

/// Una captura esperando revisión, con todo lo que el panel necesita para
/// mostrarla y lo que el agente necesita para actuar.
final class ReviewItem {
  /// Arma un ítem de la cola.
  const ReviewItem({
    required this.scenario,
    required this.actor,
    required this.slug,
    required this.description,
    required this.status,
    required this.marks,
    required this.ratio,
    required this.dimensionMismatch,
    required this.isNew,
    this.intent,
    this.capture,
    this.baseline,
    this.diff,
    this.attachments = const [],
    this.exception,
    this.origin,
    this.proposedVerdict,
    this.rationale,
    this.variants = const [],
  });

  /// Escenario al que pertenece la captura.
  final String scenario;

  /// Persona que la produjo.
  final String actor;

  /// Identidad del paso dentro del escenario.
  final String slug;

  /// Descripción legible del paso.
  final String description;

  /// `ok` | `failed` | `skipped`.
  final String status;

  /// 0–5. Prioriza la mirada; **no** juzga.
  final int marks;

  /// Fracción de píxeles distintos, 0–1.
  final double ratio;

  /// La captura y su baseline no miden lo mismo.
  final bool dimensionMismatch;

  /// Primera corrida: no hay baseline contra el que comparar.
  final bool isNew;

  /// Contrato declarado del paso: contra esto se juzga.
  final String? intent;

  /// Ruta absoluta de la captura nueva.
  final String? capture;

  /// Ruta absoluta del baseline contra el que se comparó.
  final String? baseline;

  /// Ruta absoluta del tríptico `baseline | actual | cambios`.
  final String? diff;

  /// Curls y logs adjuntos (rutas absolutas).
  final List<String> attachments;

  /// Excepción que abortó el paso, si hubo.
  final String? exception;

  /// Procedencia de la captura (`patrol`, `live`, …).
  final String? origin;

  /// Alternativas ya implementadas y capturadas, para elegir una viéndolas.
  /// Cuando no está vacía, el panel muestra la tira en vez de una sola imagen.
  final List<String> variants;

  /// Lo que el agente propone, para que el humano confirme en bloque.
  final Verdict? proposedVerdict;

  /// Por qué lo propone.
  final String? rationale;

  /// Clave estable de la captura en el veredicto.
  String get id => '$scenario/$actor/$slug';

  /// Serializa el ítem tal como lo consume el panel.
  Map<String, Object?> toJson() => {
    'scenario': scenario,
    'actor': actor,
    'slug': slug,
    'description': description,
    'status': status,
    'marks': marks,
    'ratio': ratio,
    'dimensionMismatch': dimensionMismatch,
    'isNew': isNew,
    if (intent != null) 'intent': intent,
    if (capture != null) 'capture': capture,
    if (baseline != null) 'baseline': baseline,
    if (diff != null) 'diff': diff,
    if (attachments.isNotEmpty) 'attachments': attachments,
    if (variants.isNotEmpty) 'variants': variants,
    if (exception != null) 'exception': exception,
    if (origin != null) 'origin': origin,
    if (proposedVerdict != null) 'proposedVerdict': proposedVerdict!.wire,
    if (rationale != null) 'rationale': rationale,
  };
}

/// Propuesta del agente para una captura, inyectada al armar la cola.
final class Proposal {
  /// Declara el pre-juicio del agente para una captura.
  const Proposal(this.verdict, this.rationale);

  /// Veredicto propuesto.
  final Verdict verdict;

  /// Por qué, en términos del intent y la evidencia.
  final String rationale;
}

/// Lee los manifests de `<baseDir>/runs/current/` y arma la cola de revisión,
/// **ordenada por marcas descendente**: lo que más cambió se mira primero.
///
/// Nunca parsea nombres de archivo para deducir estado — el manifest es la
/// fuente de verdad (`docs/verdict-agent.md`). Los nombres solo se usan tal
/// como el manifest los referencia.
///
/// [proposals] son los pre-juicios del agente, por `scenario/actor/slug`. Lo
/// que no venga propuesto cae en la heurística de [proposeFor], que es
/// deliberadamente conservadora: ante duda, `inconclusive`.
List<ReviewItem> loadQueue({
  required String baseDir,
  Map<String, Proposal> proposals = const {},
  bool includeUnchanged = false,
}) {
  final runsDir = Directory(p.join(baseDir, 'runs', 'current'));
  if (!runsDir.existsSync()) return const [];

  final items = <ReviewItem>[];
  for (final scenarioDir in runsDir.listSync().whereType<Directory>()) {
    for (final f in scenarioDir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.manifest.json')) continue;
      items.addAll(
        _itemsFromManifest(
          f,
          proposals: proposals,
          includeUnchanged: includeUnchanged,
        ),
      );
    }
  }

  items.sort((a, b) {
    final byMarks = b.marks.compareTo(a.marks);
    if (byMarks != 0) return byMarks;
    final byRatio = b.ratio.compareTo(a.ratio);
    if (byRatio != 0) return byRatio;
    return a.id.compareTo(b.id);
  });
  return items;
}

List<ReviewItem> _itemsFromManifest(
  File manifest, {
  required Map<String, Proposal> proposals,
  required bool includeUnchanged,
}) {
  final Map<String, Object?> json;
  try {
    json = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
  } on Object {
    // Un manifest ilegible no debe tumbar la revisión del resto.
    return const [];
  }

  final scenario = (json['scenario'] as String?) ?? '?';
  final actor = (json['actor'] as String?) ?? '?';
  // ABSOLUTO a propósito: si `baseDir` vino relativo, `manifest.parent.path`
  // también lo es, y una ruta relativa al cwd no la puede resolver el server
  // (que resuelve contra su raíz de sandbox). Absolutizar acá deja una sola
  // interpretación posible para todo consumidor.
  final dir = manifest.parent.absolute.path;
  String? resolve(Object? rel) {
    if (rel is! String || rel.isEmpty) return null;
    return p.normalize(p.isAbsolute(rel) ? rel : p.join(dir, rel));
  }

  final out = <ReviewItem>[];
  for (final raw in (json['steps'] as List<Object?>? ?? const [])) {
    if (raw is! Map<String, Object?>) continue;
    final diff = raw['diff'] as Map<String, Object?>?;
    final marks = (diff?['marks'] as num?)?.toInt() ?? 0;
    final ratio = (diff?['ratio'] as num?)?.toDouble() ?? 0.0;
    final mismatch = (diff?['dimensionMismatch'] as bool?) ?? false;
    final status = (raw['status'] as String?) ?? 'ok';
    final baseline = resolve(raw['baseline']);
    final isNew = diff == null && status == 'ok' && baseline == null;

    final unchanged = status == 'ok' && marks == 0 && !isNew && !mismatch;
    if (unchanged && !includeUnchanged) continue;

    final slug = (raw['slug'] as String?) ?? '?';
    final key = '$scenario/$actor/$slug';
    final proposal =
        proposals[key] ??
        proposeFor(
          status: status,
          marks: marks,
          isNew: isNew,
          dimensionMismatch: mismatch,
          exception: raw['exception'] as String?,
        );

    final attachments = <String>[];
    final att = raw['attachments'] as Map<String, Object?>?;
    if (att != null) {
      for (final entry in att.entries) {
        if (entry.key == 'missing') continue;
        for (final v in (entry.value as List<Object?>? ?? const [])) {
          final resolved = resolve(v);
          if (resolved != null) attachments.add(resolved);
        }
      }
    }

    out.add(
      ReviewItem(
        variants: _variantsFor(dir: dir, actor: actor, slug: slug),
        scenario: scenario,
        actor: actor,
        slug: slug,
        description: (raw['description'] as String?) ?? slug,
        status: status,
        marks: marks,
        ratio: ratio,
        dimensionMismatch: mismatch,
        isNew: isNew,
        intent: raw['intent'] as String?,
        capture: resolve(raw['capture']),
        baseline: baseline,
        diff: resolve(diff?['image']),
        attachments: attachments,
        exception: raw['exception'] as String?,
        origin: raw['origin'] as String?,
        proposedVerdict: proposal.verdict,
        rationale: proposal.rationale,
      ),
    );
  }
  return out;
}

/// Alternativas de un paso, por convención de directorio:
/// `<runDir>/variants/<actor>-<slug>/*.png`, en orden alfabético — así el
/// agente las deja ahí y el panel las encuentra sin que nadie las declare.
List<String> _variantsFor({
  required String dir,
  required String actor,
  required String slug,
}) {
  final d = Directory(p.join(dir, 'variants', '$actor-$slug'));
  if (!d.existsSync()) return const [];
  final files =
      d
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .map((f) => f.absolute.path)
          .toList()
        ..sort();
  return files;
}

/// Heurística de pre-juicio para cuando el agente no propuso nada.
///
/// Conservadora a propósito: las marcas priorizan, no juzgan, así que un drift
/// visual del que no sabemos la causa NO se auto-aprueba. Lo único que se
/// afirma con seguridad es lo que el manifest dice sin ambigüedad: un paso que
/// falló es `fix_code`.
Proposal proposeFor({
  required String status,
  required int marks,
  required bool isNew,
  required bool dimensionMismatch,
  String? exception,
}) {
  if (status == 'failed') {
    return Proposal(
      Verdict.fixCode,
      'El paso falló${exception == null ? '' : ': $exception'}. La captura '
      'muestra el estado de la pantalla en ese momento.',
    );
  }
  if (status == 'skipped') {
    return const Proposal(
      Verdict.inconclusive,
      'El paso no llegó a correr porque uno anterior falló: sin evidencia '
      'propia que juzgar.',
    );
  }
  if (isNew) {
    return const Proposal(
      Verdict.inconclusive,
      'Primera corrida ($newMarker): no hay baseline. Adoptarlo requiere '
      'confirmar que la captura cumple el intent — adoptar una pantalla rota '
      'envenena toda comparación futura.',
    );
  }
  if (dimensionMismatch) {
    return const Proposal(
      Verdict.inconclusive,
      'Cambió el tamaño de la captura: puede ser un viewport distinto o un '
      'cambio real de layout. No se comparó píxel a píxel.',
    );
  }
  return Proposal(
    Verdict.inconclusive,
    'Drift de ${marksSuffix(marks)} sin causa declarada: hace falta comparar '
    'contra el intent para decidir.',
  );
}

/// Una marca que el humano pintó sobre una captura.
final class Mark {
  /// Declara una marca pintada.
  const Mark({
    required this.brushId,
    required this.rect,
    this.note,
    this.points = const [],
  });

  /// Reconstruye desde el JSON que manda el panel.
  factory Mark.fromJson(Map<String, Object?> json) => Mark(
    brushId: (json['brush'] as String?) ?? '',
    rect: (json['rect'] as List<Object?>? ?? const [])
        .map((e) => (e as num).toDouble())
        .toList(growable: false),
    note: json['note'] as String?,
    points: (json['points'] as List<Object?>? ?? const [])
        .whereType<List<Object?>>()
        .map(
          (pt) => pt.map((e) => (e as num).toDouble()).toList(growable: false),
        )
        .toList(growable: false),
  );

  /// [Brush.id] del pincel usado.
  final String brushId;

  /// `[x, y, w, h]` en píxeles **de la imagen**, no de pantalla.
  final List<double> rect;

  /// Aclaración que el humano escribió sobre este trazo.
  final String? note;

  /// El trazo completo, para pinceles direccionales como `mover`.
  final List<List<double>> points;

  /// Serializa la marca para el veredicto.
  Map<String, Object?> toJson() => {
    'brush': brushId,
    'rect': rect,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (points.isNotEmpty) 'points': points,
  };
}

/// La decisión del humano sobre una captura.
final class Decision {
  /// Declara la decisión sobre una captura.
  const Decision({
    required this.scenario,
    required this.actor,
    required this.slug,
    required this.verdict,
    required this.rationale,
    required this.judgedBy,
    this.capture,
    this.marks = const [],
    this.note,
    this.chosenVariant,
  });

  /// Reconstruye desde el JSON que manda el panel.
  factory Decision.fromJson(Map<String, Object?> json) => Decision(
    scenario: (json['scenario'] as String?) ?? '?',
    actor: (json['actor'] as String?) ?? '?',
    slug: (json['slug'] as String?) ?? '?',
    verdict: Verdict.values.firstWhere(
      (v) => v.wire == json['verdict'],
      orElse: () => Verdict.inconclusive,
    ),
    rationale: (json['rationale'] as String?) ?? '',
    judgedBy: (json['judgedBy'] as String?) ?? 'human',
    capture: json['capture'] as String?,
    marks: ((json['marks'] as List<Object?>?) ?? const [])
        .whereType<Map<String, Object?>>()
        .map(Mark.fromJson)
        .toList(growable: false),
    note: json['note'] as String?,
    chosenVariant: json['chosenVariant'] as String?,
  );

  /// Escenario de la captura.
  final String scenario;

  /// Persona que la produjo.
  final String actor;

  /// Paso al que corresponde.
  final String slug;

  /// Veredicto elegido.
  final Verdict verdict;

  /// Por qué, en términos del intent y la evidencia.
  final String rationale;

  /// `human` cuando lo pintó o lo confirmó a mano; `agent` cuando el humano
  /// aceptó en bloque lo propuesto.
  final String judgedBy;

  /// Nombre del archivo de captura que el veredicto referencia.
  final String? capture;

  /// Marcas pintadas sobre esta captura.
  final List<Mark> marks;

  /// Texto libre de la captura: instrucciones que no pertenecen a una marca.
  final String? note;

  /// Nombre del archivo de la variante elegida, cuando el veredicto fue
  /// `variants` y el humano eligió una de la tira.
  final String? chosenVariant;

  /// Fila de `verdicts.json`, con los campos del schema más los aditivos.
  Map<String, Object?> toVerdictJson(String judgedAt) => {
    if (capture != null) 'capture': capture,
    'actor': actor,
    'slug': slug,
    'verdict': verdict.wire,
    'rationale': rationale,
    'judgedAt': judgedAt,
    'judgedBy': judgedBy,
    if (marks.isNotEmpty) 'marks': [for (final m in marks) m.toJson()],
    if (note != null && note!.isNotEmpty) 'note': note,
    if (chosenVariant != null) 'chosenVariant': chosenVariant,
  };
}

/// Lo que el panel devuelve al apretar Enter.
final class ReviewOutcome {
  /// Agrupa lo que el panel devolvió.
  const ReviewOutcome({
    required this.decisions,
    this.roundNote,
  });

  /// Reconstruye desde el JSON que manda el panel.
  factory ReviewOutcome.fromJson(Map<String, Object?> json) => ReviewOutcome(
    decisions: ((json['decisions'] as List<Object?>?) ?? const [])
        .whereType<Map<String, Object?>>()
        .map(Decision.fromJson)
        .toList(growable: false),
    roundNote: json['roundNote'] as String?,
  );

  /// Una decisión por captura decidida.
  final List<Decision> decisions;

  /// Texto libre de la ronda entera.
  final String? roundNote;
}

/// Appendea las decisiones a `<baseDir>/baseline/<scenario>/verdicts.json`,
/// creando el archivo con el esqueleto del schema si falta.
///
/// **No** copia baselines: promover una captura es una acción del agente, que
/// pasa por su propia verificación. Acá solo queda el rastro auditable.
void appendVerdicts({
  required String baseDir,
  required List<Decision> decisions,
  required String judgedAt,
}) {
  final byScenario = <String, List<Decision>>{};
  for (final d in decisions) {
    byScenario.putIfAbsent(d.scenario, () => []).add(d);
  }

  for (final entry in byScenario.entries) {
    final dir = scenarioBaselineDir(baseDir: baseDir, scenario: entry.key);
    final file = File(p.join(dir, 'verdicts.json'));
    var doc = <String, Object?>{'schemaVersion': 1, 'verdicts': <Object?>[]};
    if (file.existsSync()) {
      try {
        doc = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      } on Object {
        // Archivo corrupto: se preserva bajo `.bak` antes de reescribir, para
        // no perder el rastro de auditoría de corridas anteriores.
        file.copySync('${file.path}.bak');
      }
    }
    final list = (doc['verdicts'] as List<Object?>? ?? <Object?>[]).toList();
    for (final d in entry.value) {
      list.add(d.toVerdictJson(judgedAt));
    }
    doc['schemaVersion'] = 1;
    doc['verdicts'] = list;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(doc)}\n',
    );
  }
}
