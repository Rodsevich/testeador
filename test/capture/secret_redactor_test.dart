import 'dart:convert';

import 'package:test/test.dart';
import 'package:testeador/src/capture/secret_redactor.dart';

void main() {
  group('SecretRedactor headers', () {
    final r = SecretRedactor();

    test('redacts default sensitive headers, case-insensitively', () {
      final out = r.redactHeaders({
        'Authorization': 'Bearer abc',
        'Cookie': 'sid=1',
        'X-Api-Key': 'k',
        'Accept': 'application/json',
      });
      expect(out['Authorization'], SecretRedactor.placeholder);
      expect(out['Cookie'], SecretRedactor.placeholder);
      expect(out['X-Api-Key'], SecretRedactor.placeholder);
      expect(out['Accept'], 'application/json');
    });

    test('honors extra header keys', () {
      final out = SecretRedactor(
        extraHeaderKeys: {'x-trace'},
      ).redactHeaders({'X-Trace': 't', 'Accept': 'x'});
      expect(out['X-Trace'], SecretRedactor.placeholder);
      expect(out['Accept'], 'x');
    });

    test('isSensitiveHeader is case-insensitive', () {
      expect(r.isSensitiveHeader('AUTHORIZATION'), isTrue);
      expect(r.isSensitiveHeader('accept'), isFalse);
    });
  });

  group('SecretRedactor body', () {
    final r = SecretRedactor();

    test('redacts secret-looking keys, recursively, keeping the rest', () {
      final out = r.redactJsonBody(
        jsonEncode({
          'name': 'ash',
          'password': 'pw',
          'accessToken': 'a.b.c',
          'profile': {'refresh_token': 'r', 'age': 10},
          'sessions': [
            {'secret': 's', 'id': '1'},
          ],
        }),
      );
      final decoded = jsonDecode(out!) as Map<String, dynamic>;
      expect(decoded['name'], 'ash');
      expect(decoded['password'], SecretRedactor.placeholder);
      expect(decoded['accessToken'], SecretRedactor.placeholder);
      expect(
        (decoded['profile'] as Map)['refresh_token'],
        SecretRedactor.placeholder,
      );
      expect((decoded['profile'] as Map)['age'], 10);
      final session = (decoded['sessions'] as List).first as Map;
      expect(session['secret'], SecretRedactor.placeholder);
      expect(session['id'], '1');
    });

    test('passes null and empty through', () {
      expect(r.redactJsonBody(null), isNull);
      expect(r.redactJsonBody(''), '');
    });

    test('drops non-JSON bodies wholesale', () {
      expect(
        r.redactJsonBody('user=ash&password=pw'),
        SecretRedactor.nonJsonBody,
      );
    });

    test('isSensitiveBodyKey matches token/secret/password patterns', () {
      expect(r.isSensitiveBodyKey('apiKey'), isTrue);
      expect(r.isSensitiveBodyKey('user_password'), isTrue);
      expect(r.isSensitiveBodyKey('name'), isFalse);
    });
  });
}
