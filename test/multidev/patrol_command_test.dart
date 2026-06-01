import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

void main() {
  group('patrolCommandFor', () {
    const target = 'integration_test/agent_flows/register_player.dart';

    test('Android uses the serial as the patrol device', () {
      const device = AndroidEmulator(serial: 'emulator-5554');
      expect(
        patrolCommandFor(device, target),
        ['test', '--target', target, '--device', 'emulator-5554'],
      );
    });

    test('iOS uses the UDID as the patrol device', () {
      const udid = 'F7B5C0DE-0000-0000-0000-000000000000';
      const device = IosSimulator(udid: udid);
      expect(
        patrolCommandFor(device, target),
        ['test', '--target', target, '--device', udid],
      );
    });

    test('Web targets `chrome` and appends headless + viewport flags', () {
      // `id` is only an evidence label; the patrol device must still be chrome.
      final device = WebDevice(
        baseUrl: 'http://localhost:8080',
        id: 'admin-panel',
        chromePath: '/bin/true',
      );
      expect(
        patrolCommandFor(device, target),
        [
          'test',
          '--target',
          target,
          '--device',
          'chrome',
          '--web-headless',
          'true',
          '--web-viewport',
          '{"width": 1280, "height": 900}',
        ],
      );
    });

    test('Web honours webHeadless=false and a custom viewport', () {
      final device = WebDevice(
        baseUrl: 'http://localhost:8080',
        webHeadless: false,
        width: 1440,
        height: 1024,
        chromePath: '/bin/true',
      );
      expect(
        patrolCommandFor(device, target),
        [
          'test',
          '--target',
          target,
          '--device',
          'chrome',
          '--web-headless',
          'false',
          '--web-viewport',
          '{"width": 1440, "height": 1024}',
        ],
      );
    });
  });

  group('TargetDevice patrol selectors', () {
    test('Android/iOS expose no extra patrol args', () {
      expect(const AndroidEmulator(serial: 'emulator-5554').patrolExtraArgs(),
          isEmpty);
      expect(const IosSimulator(udid: 'udid').patrolExtraArgs(), isEmpty);
    });

    test('Web patrolDeviceId is always chrome regardless of id', () {
      final device = WebDevice(
        baseUrl: 'http://localhost:8080',
        id: 'gwsm-web',
        chromePath: '/bin/true',
      );
      expect(device.patrolDeviceId, 'chrome');
      expect(device.platform, 'web');
    });
  });
}
