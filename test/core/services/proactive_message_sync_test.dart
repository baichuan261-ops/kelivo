import 'package:Kelivo/core/services/proactive_message_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds proactive endpoint from provider base URL', () {
    final uri = ProactiveMessageSync.endpointFor(
      'https://kelivo.example.com/v1',
      sessionId: 1,
      afterId: 42,
    );

    expect(uri?.path, '/api/proactive/messages');
    expect(uri?.queryParameters['session_id'], '1');
    expect(uri?.queryParameters['after_id'], '42');
  });

  test('rejects invalid provider URL', () {
    expect(ProactiveMessageSync.endpointFor('not a URL'), isNull);
  });
}
