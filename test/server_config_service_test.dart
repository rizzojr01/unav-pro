import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sense/core/services/server_config_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: '''
BASE_URL=http://3.234.213.229:8080
KOYEB_URL=https://territorial-mavis-taggedweb-nyu-3d762b6d.koyeb.app
''');
  });

  group('ServerConfigService', () {
    test('defaults to the local server with no stored preference', () async {
      final svc = ServerConfigService(await SharedPreferences.getInstance());

      expect(svc.currentKey, ServerConfigService.localKey);
      expect(svc.currentUrl, 'http://3.234.213.229:8080');
      expect(svc.isKoyeb, isFalse);
    });

    test('setUseKoyeb(true) switches to Koyeb and persists the choice',
        () async {
      final svc = ServerConfigService(await SharedPreferences.getInstance());

      await svc.setUseKoyeb(true);

      expect(svc.currentKey, ServerConfigService.koyebKey);
      expect(
        svc.currentUrl,
        'https://territorial-mavis-taggedweb-nyu-3d762b6d.koyeb.app',
      );
      expect(svc.isKoyeb, isTrue);

      // A fresh instance should read the persisted choice.
      final reloaded = ServerConfigService(await SharedPreferences.getInstance());
      expect(reloaded.currentKey, ServerConfigService.koyebKey);
    });

    test('setUseKoyeb(false) switches back to local', () async {
      final svc = ServerConfigService(await SharedPreferences.getInstance());

      await svc.setUseKoyeb(true);
      await svc.setUseKoyeb(false);

      expect(svc.currentKey, ServerConfigService.localKey);
      expect(svc.currentUrl, 'http://3.234.213.229:8080');
    });

    test('unknown key falls back to local', () async {
      final svc = ServerConfigService(await SharedPreferences.getInstance());

      await svc.setServer('something-else');

      expect(svc.currentKey, ServerConfigService.localKey);
    });

    test('notifier fires when the server changes', () async {
      final svc = ServerConfigService(await SharedPreferences.getInstance());
      var calls = 0;
      svc.serverKeyNotifier.addListener(() => calls++);

      await svc.setUseKoyeb(true);

      expect(calls, 1);
    });
  });

  group('truncateUrl', () {
    test('returns short URLs unchanged', () {
      expect(
        truncateUrl('http://3.234.213.229:8080'),
        'http://3.234.213.229:8080',
      );
    });

    test('middle-truncates long URLs', () {
      const long = 'https://territorial-mavis-taggedweb-nyu-3d762b6d.koyeb.app';
      final result = truncateUrl(long);
      expect(result.startsWith('https://territorial-mav'), isTrue);
      expect(result.endsWith('koyeb.app'), isTrue);
      expect(result.contains('…'), isTrue);
      expect(result.length, lessThan(long.length));
    });
  });
}
