/// Los pinceles del panel de supervisión: cada color ES la acción a tomar.
///
/// El humano no escribe un veredicto, lo pinta. Cada trazo aterriza en uno de
/// los cuatro veredictos del contrato (`docs/verdict-agent.md`) más dos
/// extensiones — `variants` y `explain` — que el schema admite porque no
/// declara `additionalProperties: false`.
library;

/// Veredictos del contrato, más las dos extensiones del panel humano.
enum Verdict {
  /// La evidencia contradice el `intent`: la app debe cambiar.
  fixCode('fix_code'),

  /// La UI está bien; el `intent` o las interacciones del paso quedaron viejos.
  fixTest('fix_test'),

  /// El drift es intencional: la captura pasa a ser el baseline.
  replaceBaseline('replace_baseline'),

  /// No se puede decidir con esta evidencia.
  inconclusive('inconclusive'),

  /// Extensión: pedir N implementaciones alternativas y elegir viéndolas.
  variants('variants'),

  /// Extensión: una pregunta, no un cambio.
  explain('explain');

  const Verdict(this.wire);

  /// El valor tal como viaja en `verdicts.json`.
  final String wire;
}

/// Un pincel: una tecla, un color y la acción que codifica.
final class Brush {
  /// Declara un pincel del catálogo.
  const Brush({
    required this.key,
    required this.id,
    required this.label,
    required this.color,
    required this.verdict,
    required this.instruction,
  });

  /// Tecla que lo selecciona.
  final String key;

  /// Identificador estable que viaja en el veredicto.
  final String id;

  /// Nombre corto para la leyenda.
  final String label;

  /// Color CSS del trazo.
  final String color;

  /// Veredicto del contrato en el que aterriza.
  final Verdict verdict;

  /// Qué se espera que haga el agente con una marca de este pincel. Viaja al
  /// veredicto para que la instrucción sea explícita y no una convención
  /// tácita entre el panel y quien lo lee.
  final String instruction;
}

/// El catálogo, en orden de tecla. `0` es la última porque cae a la derecha
/// del `9` en el teclado.
const List<Brush> kBrushes = [
  Brush(
    key: '1',
    id: 'quitar',
    label: 'quitar',
    color: '#d92d20',
    verdict: Verdict.fixCode,
    instruction: 'Sacar el elemento marcado.',
  ),
  Brush(
    key: '2',
    id: 'modificar',
    label: 'modificar',
    color: '#e79c2a',
    verdict: Verdict.fixCode,
    instruction: 'Corregir lo marcado según la nota.',
  ),
  Brush(
    key: '3',
    id: 'aprobar',
    label: 'aprobar',
    color: '#2e9e5b',
    verdict: Verdict.replaceBaseline,
    instruction:
        'Está bien: promover esta captura a baseline y no tocar el código.',
  ),
  Brush(
    key: '4',
    id: 'agregar',
    label: 'agregar',
    color: '#2d6fd9',
    verdict: Verdict.fixCode,
    instruction: 'Falta algo en la zona marcada: agregarlo.',
  ),
  Brush(
    key: '5',
    id: 'variantes',
    label: 'variantes',
    color: '#8b5cf6',
    verdict: Verdict.variants,
    instruction:
        'Implementar 3 alternativas de lo marcado, capturarlas y mostrarlas '
        'lado a lado para elegir.',
  ),
  Brush(
    key: '6',
    id: 'mover',
    label: 'mover',
    color: '#0eaec4',
    verdict: Verdict.fixCode,
    instruction:
        'Posición u orden equivocado: el trazo va de origen a destino.',
  ),
  Brush(
    key: '7',
    id: 'texto',
    label: 'texto',
    color: '#d926a9',
    verdict: Verdict.fixCode,
    instruction: 'Cambiar el texto o su traducción.',
  ),
  Brush(
    key: '8',
    id: 'espaciado',
    label: 'espaciado',
    color: '#c9b21a',
    verdict: Verdict.fixCode,
    instruction: 'Ajuste fino de layout, alineación o espaciado.',
  ),
  Brush(
    key: '9',
    id: 'test_miente',
    label: 'el test miente',
    color: '#4f46e5',
    verdict: Verdict.fixTest,
    instruction:
        'La pantalla está bien: actualizar el intent o las interacciones '
        'del paso.',
  ),
  Brush(
    key: '0',
    id: 'explicar',
    label: 'explicá',
    color: '#8a8578',
    verdict: Verdict.explain,
    instruction: 'Responder qué es esto. No tocar código.',
  ),
];

/// Busca un pincel por su [Brush.id]; `null` si no existe.
Brush? brushById(String id) {
  for (final b in kBrushes) {
    if (b.id == id) return b;
  }
  return null;
}
