/// mirador — el panel de supervisión visual: mostrar evidencia previa y nueva
/// con el overlay de los cambios, dejar que un humano PINTE la acción a tomar
/// (cada color es un veredicto) y devolver eso como `verdicts.json`.
///
/// Corre en el host, sobre `dart:io`: el CLI es `bin/mirador.dart`.
library;

export 'src/mirador/brushes.dart';
export 'src/mirador/ingest.dart';
export 'src/mirador/review.dart';
export 'src/mirador/server.dart';
export 'src/mirador/ui.dart' show brushCatalogJson, miradorHtml;
