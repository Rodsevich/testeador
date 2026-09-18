import 'package:dev_mate/dev_mate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Federa el dominio `reporter` de dev_mate: ruta activa, último error no
/// controlado, estado de cada Bloc y el widget tree, en vivo. Pensado para
/// que una IA (o `mirador capture --paint`, ver `testeador_base`) reciba
/// contexto completo de la app sin que el humano lo escriba a mano.
///
/// No-op en release (doble cinturón junto al guard interno de dev_mate). Solo
/// wire quien tenga acceso a la ruta activa (el widget dueño del Navigator):
/// llamalo desde donde ya federás otros dominios (p.ej. junto al de
/// `appearance`), y des-registralo en `dispose`.
void registerReporterDomain({required String Function() currentRoute}) {
  if (kReleaseMode) {
    return;
  }
  _installHooksOnce();
  DevMate.instance.register(
    DevMateDomain(
      name: 'reporter',
      description:
          'Captura ruta activa, último error no controlado, estado de cada '
          'Bloc y el widget tree — de solo lectura, nada persiste.',
      actions: <DevMateAction>[
        DevMateAction(
          name: 'capture',
          description: 'Toma una foto del estado actual de la app.',
          params: const <DevMateParam>[
            DevMateParam(
              name: 'message',
              description: 'Instrucción libre para quien lea la captura.',
            ),
          ],
          handler: (Map<String, String> params) async {
            final Map<String, Object?> snapshot = _snapshot(
              route: currentRoute(),
              message: params['message'] ?? '',
            );
            _latest = snapshot;
            return snapshot;
          },
        ),
      ],
      state: () => _latest ?? const <String, Object?>{'status': 'sin capturas aún'},
    ),
  );
}

/// Des-registra el dominio `reporter`. Llamalo en `dispose`, simétrico a
/// [registerReporterDomain].
void unregisterReporterDomain() {
  if (kReleaseMode) {
    return;
  }
  DevMate.instance.unregister('reporter');
}

const int _widgetTreeMaxChars = 8000;

Map<String, Object?>? _latest;

Map<String, Object?> _snapshot({required String route, required String message}) {
  final String? tree = WidgetsBinding.instance.rootElement?.toStringDeep(
    minLevel: DiagnosticLevel.info,
  );
  return <String, Object?>{
    'route': route,
    'lastError': _lastError,
    'blocStates': Map<String, String>.from(_blocStates),
    'widgetTree': tree == null
        ? null
        : (tree.length > _widgetTreeMaxChars
              ? tree.substring(0, _widgetTreeMaxChars)
              : tree),
    'message': message,
  };
}

// --- Hooks: instalados una sola vez, delegan a lo que ya había -------------

bool _hooksInstalled = false;
Map<String, Object?>? _lastError;
final Map<String, String> _blocStates = <String, String>{};

void _installHooksOnce() {
  if (_hooksInstalled) {
    return;
  }
  _hooksInstalled = true;

  final FlutterExceptionHandler? previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _lastError = <String, Object?>{
      'message': details.exceptionAsString(),
      'stack': details.stack?.toString(),
    };
    previousOnError?.call(details);
  };

  final BlocObserver? previous = Bloc.observer;
  Bloc.observer = _ReporterBlocObserver(previous);
}

/// Encadena el [BlocObserver] que ya hubiera puesto la app — testeador no
/// pisa un observer ajeno, solo agrega su propia captura de estado.
final class _ReporterBlocObserver extends BlocObserver {
  _ReporterBlocObserver(this._previous);

  final BlocObserver? _previous;

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    _previous?.onCreate(bloc);
    super.onCreate(bloc);
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    _previous?.onEvent(bloc, event);
    super.onEvent(bloc, event);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    _blocStates[bloc.runtimeType.toString()] = change.nextState.toString();
    _previous?.onChange(bloc, change);
    super.onChange(bloc, change);
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    _previous?.onTransition(bloc, transition);
    super.onTransition(bloc, transition);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _previous?.onError(bloc, error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    _previous?.onClose(bloc);
    super.onClose(bloc);
  }
}
