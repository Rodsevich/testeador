import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/testeador.dart';

/// Fails capture/baseline writes but lets the manifest work — isolates the
/// harness-failure path of `photo()`.
final class _BrokenBytesFileSystem extends EvidenceFileSystem {
  const _BrokenBytesFileSystem();

  @override
  void writeBytes(String path, List<int> bytes) =>
      throw const FileSystemException('disk full');
}

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('testeador_recorder');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  EvidenceConfig config() => (
    baseDir: tmp.path,
    capturePixelRatio: 1.0,
    noiseFloor: 0.0001,
    maxMarks: 5,
    channelTolerance: 8,
  );

  EvidenceRecorder recorder({
    String scenario = 'grupo_a',
    String actor = 'tester',
    EvidenceFileSystem? fs,
  }) => EvidenceRecorder(
    scenario: scenario,
    actor: actor,
    config: config(),
    fileSystem: fs ?? const EvidenceFileSystem(),
  );

  Widget screen(Color color, String label) => ColoredBox(
    color: color,
    child: Center(child: Text(label)),
  );

  void expectValidPng(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'missing $path');
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(_pngSignature.length));
    expect(bytes.sublist(0, 8), equals(_pngSignature), reason: 'PNG magic');
  }

  group('EvidenceRecorder.photo', () {
    testWidgets('two captures land in the scenario folder as valid ~new PNGs', (
      tester,
    ) async {
      final rec = recorder();
      await rec.pump(tester, screen(Colors.white, 'uno'));
      await rec.photo(tester, name: 'primera', intent: 'shows uno');
      await rec.pump(tester, screen(Colors.white, 'dos'));
      await rec.photo(tester, name: 'segunda', intent: 'shows dos');

      expectValidPng(p.join(rec.runDir, 'tester-01_primera~new.png'));
      expectValidPng(p.join(rec.runDir, 'tester-02_segunda~new.png'));
    });

    /// Runs [body] with `--update-goldens` semantics, restoring the global
    /// before the test body ends (the binding verifies it was not leaked).
    Future<void> withUpdateGoldens(Future<void> Function() body) async {
      autoUpdateGoldenFiles = true;
      try {
        await body();
      } finally {
        autoUpdateGoldenFiles = false;
      }
    }

    testWidgets('--update-goldens writes the baseline and reports no drift', (
      tester,
    ) async {
      final rec = recorder();
      await withUpdateGoldens(() async {
        await rec.pump(tester, screen(Colors.white, 'estable'));
        final diff = await rec.photo(tester, name: 'home');
        expect(diff, isNotNull);
        expect(diff!.marks, 0, reason: 'compared against itself');
      });
      expectValidPng(p.join(rec.baselineDir, 'tester-home.png'));
      expectValidPng(p.join(rec.runDir, 'tester-01_home.png'));
    });

    testWidgets('re-running an unchanged UI against its baseline → 0 marks', (
      tester,
    ) async {
      await withUpdateGoldens(() async {
        final first = recorder();
        await first.pump(tester, screen(Colors.white, 'estable'));
        await first.photo(tester, name: 'home');
      });

      final second = recorder();
      await second.pump(tester, screen(Colors.white, 'estable'));
      final diff = await second.photo(tester, name: 'home');

      expect(diff!.marks, 0, reason: 'determinism: identical run, no drift');
      expectValidPng(p.join(second.runDir, 'tester-01_home.png'));
    });

    testWidgets('drift produces ! marks and a baseline|actual|diff triptych', (
      tester,
    ) async {
      await withUpdateGoldens(() async {
        final first = recorder();
        await first.pump(tester, screen(Colors.white, 'antes'));
        await first.photo(tester, name: 'pantalla');
      });

      final second = recorder();
      await second.pump(tester, screen(Colors.deepPurple, 'después'));
      final diff = await second.photo(tester, name: 'pantalla');

      expect(diff!.marks, greaterThan(0));
      final marker = '!' * diff.marks;
      expectValidPng(
        p.join(second.runDir, 'tester-01_pantalla$marker.png'),
      );
      expectValidPng(
        p.join(second.runDir, 'tester-01_pantalla$marker.diff.png'),
      );
    });

    testWidgets('a run with 100% drift does NOT fail the test', (tester) async {
      await withUpdateGoldens(() async {
        final first = recorder();
        await first.pump(tester, screen(Colors.white, 'a'));
        await first.photo(tester, name: 'p');
      });

      final second = recorder();
      await second.pump(tester, screen(Colors.black, 'b'));
      final diff = await second.photo(tester, name: 'p');
      // Reaching this line IS the assertion: photo() scored max drift and
      // did not throw.
      expect(diff!.marks, second.config.maxMarks);
    });

    testWidgets('duplicate step name throws at once (no silent overwrite)', (
      tester,
    ) async {
      final rec = recorder();
      await rec.pump(tester, screen(Colors.white, 'x'));
      await rec.photo(tester, name: 'repetida');
      await expectLater(
        () => rec.photo(tester, name: 'repetida'),
        throwsArgumentError,
      );
    });

    testWidgets('a corrupted baseline PNG is a harness failure', (
      tester,
    ) async {
      final rec = recorder();
      File(p.join(rec.baselineDir, 'tester-rota.png'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('esto no es un PNG');
      await rec.pump(tester, screen(Colors.white, 'x'));
      await expectLater(
        () => rec.photo(tester, name: 'rota'),
        throwsA(isA<EvidenceCaptureException>()),
      );
    });

    testWidgets('actor names are slugified: no prefix collisions, no marker '
        'spoofing', (tester) async {
      final rec = recorder(actor: 'Comprador VIP!');
      expect(rec.actor, 'comprador_vip');
      await rec.pump(tester, screen(Colors.white, 'x'));
      await rec.photo(tester, name: 'home');
      expectValidPng(
        p.join(rec.runDir, 'comprador_vip-01_home~new.png'),
      );
      // A sibling actor whose name is a prefix of another must not clobber
      // it: `comprador` cleanup only matches `comprador-*`, never
      // `comprador_vip-*` (slugs cannot contain the `-` separator).
      final sibling = recorder(actor: 'comprador');
      expect(
        File(
          p.join(sibling.runDir, 'comprador_vip-01_home~new.png'),
        ).existsSync(),
        isTrue,
        reason:
            'creating actor `comprador` must not delete '
            '`comprador_vip` artifacts',
      );
    });

    testWidgets('a rasterization error is wrapped as a harness failure', (
      tester,
    ) async {
      // An invalid capture pixel ratio makes the engine-side rasterization
      // blow up with a non-harness error, which photo() must wrap.
      final rec = EvidenceRecorder(
        scenario: 'grupo_a',
        actor: 'tester',
        config: (
          baseDir: tmp.path,
          capturePixelRatio: -1.0,
          noiseFloor: 0.0001,
          maxMarks: 5,
          channelTolerance: 8,
        ),
      );
      await rec.pump(tester, screen(Colors.white, 'x'));
      await expectLater(
        () => rec.photo(tester, name: 'invalida'),
        throwsA(isA<EvidenceCaptureException>()),
      );
    });

    testWidgets('photo before pump is a harness failure', (tester) async {
      final rec = recorder();
      await expectLater(
        () => rec.photo(tester, name: 'sin_pump'),
        throwsA(isA<EvidenceCaptureException>()),
      );
    });

    testWidgets('capture write failure is a harness failure, not an app one', (
      tester,
    ) async {
      final rec = recorder(fs: const _BrokenBytesFileSystem());
      await rec.pump(tester, screen(Colors.white, 'x'));
      await expectLater(
        () => rec.photo(tester, name: 'foto'),
        throwsA(isA<EvidenceCaptureException>()),
      );
    });
  });

  group('crash and skip bookkeeping', () {
    testWidgets('photoCrash stores a ~crash capture with failed status', (
      tester,
    ) async {
      final rec = recorder();
      await rec.pump(tester, screen(Colors.red, 'boom'));
      await rec.photoCrash(
        tester,
        name: 'explota',
        exception: StateError('boom'),
      );
      expectValidPng(p.join(rec.runDir, 'tester-01_explota~crash.png'));
      final manifest = File(rec.manifest.path).readAsStringSync();
      expect(manifest, contains('"status": "failed"'));
      expect(manifest, contains('Bad state: boom'));
    });

    testWidgets(
      'photoCrash without a mounted boundary still records the failed step '
      '(rasterization fallback)',
      (tester) async {
        final rec = recorder();
        // No pump: rasterizing the crash state is impossible — the step must
        // still land in the manifest, without a capture.
        await rec.photoCrash(
          tester,
          name: 'sin_arbol',
          exception: StateError('boom'),
        );
        final manifest = File(rec.manifest.path).readAsStringSync();
        expect(manifest, contains('"status": "failed"'));
        expect(manifest, contains('Bad state: boom'));
        expect(manifest, isNot(contains('~crash.png')));
      },
    );

    testWidgets('markSkipped records steps that never ran', (tester) async {
      recorder().markSkipped(
        name: 'nunca_corrio',
        intent: 'would check something',
      );
      // No capture file — only the manifest entry.
      final manifestFile = File(
        p.join(
          scenarioRunDir(baseDir: tmp.path, scenario: 'grupo_a'),
          'tester.manifest.json',
        ),
      );
      expect(manifestFile.readAsStringSync(), contains('"skipped"'));
    });

    testWidgets('reconcileOrphans flags stale baselines of this actor', (
      tester,
    ) async {
      final rec = recorder();
      File(p.join(rec.baselineDir, 'tester-viejo.png'))
        ..parent.createSync(recursive: true)
        ..createSync();
      await rec.pump(tester, screen(Colors.white, 'x'));
      await rec.photo(tester, name: 'actual');
      rec.reconcileOrphans();
      expect(
        File(rec.manifest.path).readAsStringSync(),
        contains('tester-viejo.png'),
      );
    });
  });

  group('EvidenceCaptureException', () {
    test('toString includes the message and the optional cause', () {
      expect(
        EvidenceCaptureException('write failed').toString(),
        'EvidenceCaptureException: write failed',
      );
      expect(
        EvidenceCaptureException('write failed', 'disk full').toString(),
        'EvidenceCaptureException: write failed (disk full)',
      );
    });
  });

  group('baseDir resolution', () {
    testWidgets('relative baseDir resolves against Directory.current', (
      tester,
    ) async {
      final previous = Directory.current;
      Directory.current = tmp;
      addTearDown(() => Directory.current = previous);

      final rec = EvidenceRecorder(
        scenario: 'relativo',
        actor: 'tester',
        config: (
          baseDir: 'evidencia_relativa',
          capturePixelRatio: 1.0,
          noiseFloor: 0.0001,
          maxMarks: 5,
          channelTolerance: 8,
        ),
      );
      expect(
        p.isWithin(tmp.resolveSymbolicLinksSync(), rec.runDir) ||
            p.isWithin(tmp.path, rec.runDir),
        isTrue,
        reason: 'run dir must live under the (temporary) cwd',
      );
    });
  });

  group('pump options', () {
    testWidgets('tablet preset and explicit theme drive the mounted tree', (
      tester,
    ) async {
      final rec = EvidenceRecorder(
        scenario: 'tablet',
        actor: 'tester',
        config: config(),
        viewport: ViewportPreset.tablet,
      );
      await rec.pump(
        tester,
        screen(Colors.white, 'tema'),
        theme: ThemeData.dark(),
      );
      expect(tester.view.physicalSize, ViewportPreset.tablet.physicalSize);
      expect(
        Theme.of(tester.element(find.text('tema'))).brightness,
        Brightness.dark,
      );
      final diff = await rec.photo(tester, name: 'oscuro');
      expect(diff, isNull, reason: 'first capture: ~new, no baseline');
    });
  });

  group('attachments', () {
    testWidgets(
      'existing files are referenced relative to the run dir; promised '
      'files that never arrived land in attachments.missing',
      (tester) async {
        final rec = recorder();
        File(p.join(rec.runDir, 'http', 'tester-foto.curl'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('curl https://example.com');

        rec
          ..attach(step: 'foto', type: 'http', file: 'http/tester-foto.curl')
          ..attach(step: 'foto', type: 'http', file: 'http/nunca_llego.curl');
        await rec.pump(tester, screen(Colors.white, 'x'));
        await rec.photo(tester, name: 'foto');

        final manifest = File(rec.manifest.path).readAsStringSync();
        expect(manifest, contains('http/tester-foto.curl'));
        expect(manifest, contains('"missing"'));
        expect(manifest, contains('http/nunca_llego.curl'));
      },
    );

    testWidgets(
      'attachments registered for a never-photographed step surface as '
      'unclaimed instead of vanishing',
      (tester) async {
        final rec = recorder();
        await rec.pump(tester, screen(Colors.white, 'x'));
        // One attachment whose file exists, one that never arrived — both for
        // a step name that is never photographed.
        File(p.join(rec.runDir, 'http', 'tester-existe.curl'))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('curl x');
        rec
          ..attach(
            step: 'typo_en_nombre',
            type: 'http',
            file: 'http/tester-existe.curl',
          )
          ..attach(step: 'typo_en_nombre', type: 'http', file: 'http/x.curl');
        await rec.photo(tester, name: 'real');
        rec.reconcileOrphans();
        final manifest = File(rec.manifest.path).readAsStringSync();
        expect(manifest, contains('unclaimedAttachments'));
        expect(manifest, contains('typo_en_nombre'));
        expect(manifest, contains('tester-existe.curl'));
      },
    );

    testWidgets('stale attachments in subdirs are cleaned on a new run', (
      tester,
    ) async {
      final first = recorder();
      File(p.join(first.runDir, 'http', 'tester-viejo.curl'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('curl viejo');
      // A new run for the same actor must sweep the attachment subdir too.
      final second = recorder();
      expect(
        File(p.join(second.runDir, 'http', 'tester-viejo.curl')).existsSync(),
        isFalse,
        reason: 'stale evidence must never be re-attachable as current',
      );
    });
  });

  group('parallel actors on the same scenario', () {
    testWidgets('two actors write side by side without clobbering each other', (
      tester,
    ) async {
      final comprador = recorder(actor: 'comprador');
      await comprador.pump(tester, screen(Colors.white, 'c'));
      await comprador.photo(tester, name: 'home');

      final visitante = recorder(actor: 'visitante');
      await visitante.pump(tester, screen(Colors.white, 'v'));
      await visitante.photo(tester, name: 'home');

      expectValidPng(
        p.join(comprador.runDir, 'comprador-01_home~new.png'),
      );
      expectValidPng(
        p.join(visitante.runDir, 'visitante-01_home~new.png'),
      );
      expect(File(comprador.manifest.path).existsSync(), isTrue);
      expect(File(visitante.manifest.path).existsSync(), isTrue);
      expect(
        comprador.manifest.path,
        isNot(equals(visitante.manifest.path)),
      );
    });
  });
}
