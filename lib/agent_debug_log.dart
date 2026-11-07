import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Debug-only ingest for this session. Remove after the false token-expiry banner is verified.
class AgentDebugLog {
  static const _ingests = <String>[
    'http://127.0.0.1:7711/ingest/9a5d3e2d-5b91-4efc-9299-74941b85ada4',
    'http://10.0.2.2:7711/ingest/9a5d3e2d-5b91-4efc-9299-74941b85ada4',
  ];

  static void log({
    required String location,
    required String message,
    String? hypothesisId,
    Map<String, Object?> data = const {},
  }) {
    if (!kDebugMode) return;
    final payload = jsonEncode({
      'sessionId': 'b45dc3',
      'runId': 'post-fix',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'message': message,
      'hypothesisId': hypothesisId,
      'data': data,
    });
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Debug-Session-Id': 'b45dc3',
    };
    for (final url in _ingests) {
      http
          .post(Uri.parse(url), headers: headers, body: payload)
          .catchError((_) => http.Response('', 599));
    }
  }

  static int? accessExpDeltaSec(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      final pad = payload.length % 4;
      if (pad > 0) payload += '=' * (4 - pad);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (decoded is! Map) return null;
      final exp = int.tryParse('${decoded['exp']}');
      if (exp == null) return null;
      return exp - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return null;
    }
  }
}
