/// Motor de evidencia visual: nombres con marcas de severidad, scoring de
/// drift contra baselines y el manifest por corrida que consume el juez.
///
/// Es Dart puro a propósito. La captura desde un árbol de widgets vive en el
/// paquete `testeador` (Flutter), que depende de este.
library;

export 'src/evidence/evidence_config.dart';
export 'src/evidence/evidence_file_system.dart';
export 'src/evidence/naming.dart';
export 'src/evidence/pixel_diff.dart';
export 'src/evidence/run_manifest.dart';
