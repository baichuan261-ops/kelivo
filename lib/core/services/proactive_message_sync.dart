import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import 'api/chat_api_helpers.dart';

class ProactiveMessageSync {
  ProactiveMessageSync({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static Uri? endpointFor(
    String baseUrl, {
    int sessionId = 1,
    int afterId = 0,
  }) {
    final parsed = Uri.tryParse(baseUrl.trim());
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) return null;
    return parsed.replace(
      path: '/api/proactive/messages',
      queryParameters: <String, String>{
        'session_id': '$sessionId',
        'after_id': '$afterId',
        'limit': '50',
      },
    );
  }

  Future<int> sync({
    required ProviderConfig provider,
    required Future<void> Function(String content) insertMessage,
    int sessionId = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cursorKey = 'proactive_cursor_v1:${provider.baseUrl}:$sessionId';
    final afterId = prefs.getInt(cursorKey) ?? 0;
    final endpoint = endpointFor(
      provider.baseUrl,
      sessionId: sessionId,
      afterId: afterId,
    );
    if (endpoint == null) return 0;

    final apiKey = effectiveApiKey(provider).trim();
    if (apiKey.isEmpty) return 0;

    final response = await _client
        .get(
          endpoint,
          headers: <String, String>{'Authorization': 'Bearer $apiKey'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return 0;

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final rawMessages = decoded is Map<String, dynamic>
        ? decoded['messages']
        : null;
    if (rawMessages is! List) return 0;

    var inserted = 0;
    var cursor = afterId;
    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final id = int.tryParse('${raw['id']}');
      final content = '${raw['content'] ?? ''}'.trim();
      if (id == null || id <= cursor || content.isEmpty) continue;

      await insertMessage(content);
      cursor = id;
      inserted++;
      await prefs.setInt(cursorKey, cursor);
    }
    return inserted;
  }

  void close() => _client.close();
}
