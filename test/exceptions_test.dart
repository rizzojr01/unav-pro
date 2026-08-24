import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sense/core/error/exceptions.dart';

void main() {
  test('friendlyServerMessage hides HTML bodies, keeps real messages', () {
    expect(
      friendlyServerMessage('<!DOCTYPE html><html>...502 page...</html>', 502),
      'The server is temporarily unavailable.\nPlease try again in a moment.',
    );
    expect(
      friendlyServerMessage('<html>oops</html>', 500),
      contains('error 500'),
    );
    expect(friendlyServerMessage('Route not found', 404), 'Route not found');
  });
}
