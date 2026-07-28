import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador_base/evidence.dart';

/// Filesystem stub that fails every write — simulates a full disk.
final class _BrokenFileSystem extends EvidenceFileSystem {
  const _BrokenFileSystem();

  @override
  void writeStringAtomic(String path, String content) =>
      throw const FileSystemException('disk full');
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('testeador_manifest');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  RunManifest buildManifest({EvidenceFileSystem? fs}) => RunManifest(
    scenario: 'checkout',
    actor: 'comprador',
    scenarioDir: tmp.path,
    viewportPreset: 'phone',
    logicalSize: const [410, 890],
    devicePixelRatio: 2,
    capturePixelRatio: 2.5,
    fileSystem: fs ?? const EvidenceFileSystem(),
  );

  Map<String, Object?> readManifest(RunManifest manifest) =>
      jsonDecode(File(manifest.path).readAsStringSync())
          as Map<String, Object?>;

  group('RunManifest', () {
    test('writes a parseable manifest with header fields on creation', () {
      final manifest = buildManifest();
      final json = readManifest(manifest);
      expect(json['schemaVersion'], RunManifest.schemaVersion);
      expect(json['scenario'], 'checkout');
      expect(json['actor'], 'comprador');
      expect(json['viewport'], containsPair('preset', 'phone'));
      expect(json['capturePixelRatio'], 2.5);
      expect(json['environment'], containsPair('platform', isA<String>()));
      expect(json['steps'], isEmpty);
    });

    test('is valid JSON after every recorded step (incremental write)', () {
      final manifest = buildManifest()
        ..recordStep(
          order: 1,
          slug: 'home',
          description: 'home',
          status: 'ok',
          intent: 'shows the categories',
          capture: 'comprador-01_home~new.png',
        );
      var json = readManifest(manifest);
      expect(json['steps'], hasLength(1));

      manifest.recordStep(
        order: 2,
        slug: 'carrito',
        description: 'carrito',
        status: 'failed',
        exception: 'TestFailure: boom',
      );
      json = readManifest(manifest);
      final steps = json['steps']! as List<Object?>;
      expect(steps, hasLength(2));
      expect(
        steps.last,
        allOf(
          containsPair('status', 'failed'),
          containsPair('exception', 'TestFailure: boom'),
        ),
      );
    });

    test('survives a mid-flow crash: manifest written so far stays complete '
        'and parseable even if no further steps arrive', () {
      final manifest = buildManifest()
        ..recordStep(
          order: 1,
          slug: 'home',
          description: 'home',
          status: 'ok',
        );
      // Simulated crash: the test simply stops recording. The file on disk
      // must already be complete.
      final json = readManifest(manifest);
      expect(json['steps'], hasLength(1));
    });

    test('records origin for device-produced evidence', () {
      final manifest = buildManifest()
        ..recordStep(
          order: 1,
          slug: 'home',
          description: 'home',
          status: 'ok',
          capture: 'comprador-01_home~device.png',
          origin: 'device',
        );
      final steps = readManifest(manifest)['steps']! as List<Object?>;
      expect(steps.single, containsPair('origin', 'device'));
    });

    test('records diff block with marks and optional triptych image', () {
      final manifest = buildManifest()
        ..recordStep(
          order: 1,
          slug: 'carrito',
          description: 'carrito',
          status: 'ok',
          diff: (
            ratio: 0.004,
            marks: 2,
            dimensionMismatch: false,
            image: 'comprador-01_carrito!!.diff.png',
          ),
        );
      final steps = readManifest(manifest)['steps']! as List<Object?>;
      final diff =
          (steps.single! as Map<String, Object?>)['diff']!
              as Map<String, Object?>;
      expect(diff['ratio'], 0.004);
      expect(diff['marks'], 2);
      expect(diff['dimensionMismatch'], isFalse);
      expect(diff['image'], 'comprador-01_carrito!!.diff.png');
    });

    test("cleans only this actor's previous artifacts on creation", () {
      File(p.join(tmp.path, 'comprador-01_stale!!!.png')).createSync();
      File(p.join(tmp.path, 'comprador.manifest.json')).createSync();
      File(p.join(tmp.path, 'visitante-01_keep.png')).createSync();
      File(p.join(tmp.path, 'visitante.manifest.json')).createSync();

      buildManifest();

      expect(
        File(p.join(tmp.path, 'comprador-01_stale!!!.png')).existsSync(),
        isFalse,
      );
      expect(
        File(p.join(tmp.path, 'visitante-01_keep.png')).existsSync(),
        isTrue,
        reason: "another actor's artifacts must not be touched",
      );
      expect(
        File(p.join(tmp.path, 'visitante.manifest.json')).existsSync(),
        isTrue,
      );
    });

    test('reconcileOrphans lists baselines no step references', () {
      // Baselines live OUTSIDE the scenario run dir in the real layout
      // (<base>/baseline/<scenario> vs <base>/runs/current/<scenario>), so
      // they are never touched by the run-dir cleanup sweep.
      final baselineDir = Directory.systemTemp.createTempSync(
        'testeador_baselines',
      );
      addTearDown(() => baselineDir.deleteSync(recursive: true));
      File(p.join(baselineDir.path, 'comprador-home.png')).createSync();
      File(p.join(baselineDir.path, 'comprador-paso_viejo.png')).createSync();
      File(p.join(baselineDir.path, 'visitante-home.png')).createSync();

      final manifest = buildManifest()
        ..recordStep(
          order: 1,
          slug: 'home',
          description: 'home',
          status: 'ok',
        )
        ..reconcileOrphans(baselineDir.path);

      final json = readManifest(manifest);
      expect(
        json['orphanedBaselines'],
        equals(['comprador-paso_viejo.png']),
        reason: "other actors' baselines are out of scope",
      );
    });

    test('environment records the Flutter version from FLUTTER_ROOT', () {
      final fakeRoot = Directory.systemTemp.createTempSync('fake_flutter');
      addTearDown(() => fakeRoot.deleteSync(recursive: true));
      File(p.join(fakeRoot.path, 'version')).writeAsStringSync('9.9.9\n');

      final manifest = RunManifest(
        scenario: 'checkout',
        actor: 'comprador',
        scenarioDir: tmp.path,
        viewportPreset: 'phone',
        logicalSize: const [410, 890],
        devicePixelRatio: 2,
        capturePixelRatio: 2.5,
        environment: {
          'FLUTTER_ROOT': fakeRoot.path,
          'GITHUB_SHA': 'abc123',
        },
      );
      final env =
          readManifest(manifest)['environment']! as Map<String, Object?>;
      expect(env['flutter'], '9.9.9');
      expect(env['commit'], 'abc123');
    });

    test('write failure surfaces as an exception (harness failure)', () {
      expect(
        () => buildManifest(fs: const _BrokenFileSystem()),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('path helpers', () {
    test('scenario directories are keyed by scenario slug', () {
      expect(
        scenarioRunDir(baseDir: '/base', scenario: 'Checkout Feliz'),
        p.join('/base', 'runs', 'current', 'checkout_feliz'),
      );
      expect(
        scenarioBaselineDir(baseDir: '/base', scenario: 'Checkout Feliz'),
        p.join('/base', 'baseline', 'checkout_feliz'),
      );
    });

    test('manifestRelative produces paths relative to the manifest dir', () {
      expect(
        manifestRelative(
          from: '/base/runs/current/checkout',
          target: '/base/baseline/checkout/comprador-home.png',
        ),
        p.join('..', '..', '..', 'baseline', 'checkout', 'comprador-home.png'),
      );
    });
  });
}
