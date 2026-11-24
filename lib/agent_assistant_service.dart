import 'dart:convert';

import 'package:path/path.dart' as p;

import 'package:http/http.dart' as http;

import 'api_client.dart';

class AgentAssistantException implements Exception {
  final String message;
  final int? statusCode;

  const AgentAssistantException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AgentChatResponse {
  final String conversationId;
  final String answer;
  final List<Map<String, dynamic>> pendingActions;
  final String? transcript;

  const AgentChatResponse({
    required this.conversationId,
    required this.answer,
    required this.pendingActions,
    this.transcript,
  });
}

/// Authenticated client for the backend's owner-only Agent API.
///
/// The model never receives a client-supplied shop ID. The backend resolves
/// the tenant from the owner's access token. Financial/business writes are
/// represented as previews and can only be confirmed through this API.
class AgentAssistantService {
  static const String _base = '/api/agent';
  static const String capabilitiesPath = '$_base/capabilities';

  static Map<String, dynamic> _decodeMap(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static Never _throwResponseError(http.Response response) {
    final payload = _decodeMap(response);
    final detail = (payload['detail'] ?? payload['message'] ?? payload['error'])
        ?.toString()
        .trim();

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AgentAssistantException(
        'Your owner session may have expired. Sign in again and retry.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 503) {
      throw AgentAssistantException(
        detail?.isNotEmpty == true
            ? detail!
            : 'The Retail Mind AI agent is not enabled on this backend.',
        statusCode: 503,
      );
    }
    if (response.statusCode == 404) {
      throw const AgentAssistantException(
        'The AI agent API is not available on this backend deployment yet.',
        statusCode: 404,
      );
    }
    throw AgentAssistantException(
      detail?.isNotEmpty == true
          ? detail!
          : 'The AI assistant request failed (HTTP ' +
              response.statusCode.toString() +
              ').',
      statusCode: response.statusCode,
    );
  }

  static Future<Map<String, dynamic>> getCapabilities() async {
    final response = await ApiClient.getJson(capabilitiesPath);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    return _decodeMap(response);
  }

  static Future<AgentChatResponse> sendMessage(
    String message, {
    String? conversationId,
    String languageCode = 'auto',
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) {
      throw const AgentAssistantException('Enter a message for the assistant.');
    }

    final body = <String, dynamic>{
      'message': cleanMessage,
      'language_code': languageCode.trim().isEmpty ? 'auto' : languageCode,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversation_id': conversationId,
    };
    final response = await ApiClient.postJson('$_base/chat', body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }

    final payload = _decodeMap(response);
    final actions = payload['pending_actions'];
    return AgentChatResponse(
      conversationId: (payload['conversation_id'] ?? conversationId ?? '')
          .toString(),
      answer: (payload['answer'] ?? '').toString(),
      pendingActions: actions is List
          ? actions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const [],
    );
  }

  static Future<AgentChatResponse> sendVoice(
    String audioPath, {
    String? conversationId,
    String languageCode = 'auto',
  }) async {
    final file = await http.MultipartFile.fromPath(
      'audio',
      audioPath,
      filename: p.basename(audioPath),
    );
    final responseStream = await ApiClient.postMultipart(
      '$_base/voice',
      {
        'language_code':
            languageCode.trim().isEmpty ? 'auto' : languageCode,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
      },
      files: [file],
      timeout: const Duration(seconds: 90),
    );
    final response = http.Response(
      await responseStream.stream.bytesToString(),
      responseStream.statusCode,
      headers: responseStream.headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    final payload = _decodeMap(response);
    final actions = payload['pending_actions'];
    final transcription = payload['transcription'];
    final transcript = transcription is Map
        ? transcription['transcript']?.toString()
        : null;
    return AgentChatResponse(
      conversationId: (payload['conversation_id'] ?? conversationId ?? '')
          .toString(),
      answer: (payload['answer'] ?? '').toString(),
      transcript: transcript,
      pendingActions: actions is List
          ? actions
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const [],
    );
  }

  static Future<Map<String, dynamic>> confirmAction({
    required String actionId,
    required String previewHash,
  }) async {
    final response = await ApiClient.postJson(
      '$_base/actions/$actionId/confirm',
      {'preview_hash': previewHash},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    return _decodeMap(response);
  }

  static Future<void> cancelAction({required String actionId}) async {
    final response = await ApiClient.postJson(
      '$_base/actions/$actionId/cancel',
      const <String, dynamic>{},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
  }
}
