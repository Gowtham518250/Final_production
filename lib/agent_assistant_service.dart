import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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
    final rawDetail = payload['detail'] ?? payload['message'] ?? payload['error'];
    final detail = rawDetail is Map
        ? (rawDetail['message'] ?? rawDetail['detail'])?.toString().trim()
        : rawDetail?.toString().trim();

    if (response.statusCode == 401) {
      throw AgentAssistantException(
        'Your owner session may have expired. Sign in again and retry.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode == 403) {
      throw AgentAssistantException(
        detail?.isNotEmpty == true
            ? detail!
            : 'This assistant feature is not available on your current plan or settings.',
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

  static Future<Map<String, dynamic>> getControlCenter() async {
    final response = await ApiClient.getJson('$_base/control-center');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> updateSettings(
    Map<String, bool> settings,
  ) async {
    if (settings.isEmpty) {
      throw const AgentAssistantException('Choose at least one setting to update.');
    }
    final response = await ApiClient.putJson('$_base/settings', settings);
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
    late final http.MultipartFile file;
    if (kIsWeb && audioPath.startsWith('blob:')) {
      // record_web returns an in-memory browser blob URL rather than a local
      // filesystem path. Fetch its bytes before building the multipart upload.
      final blobResponse = await http.get(Uri.parse(audioPath));
      if (blobResponse.statusCode < 200 || blobResponse.statusCode >= 300) {
        throw const AgentAssistantException(
          'The browser recording could not be read. Please record again.',
        );
      }
      if (blobResponse.bodyBytes.isEmpty) {
        throw const AgentAssistantException('The voice recording is empty.');
      }
      file = http.MultipartFile.fromBytes(
        'audio',
        blobResponse.bodyBytes,
        filename: 'retail-mind-owner-voice.ogg',
      );
    } else {
      file = await http.MultipartFile.fromPath(
        'audio',
        audioPath,
        filename: p.basename(audioPath),
      );
    }
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

  static Future<Map<String, dynamic>?> getLatestConversation() async {
    final response = await ApiClient.getJson('$_base/conversations?limit=1');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    final payload = _decodeMap(response);
    final conversations = payload['conversations'];
    if (conversations is! List || conversations.isEmpty) return null;
    final latest = conversations.first;
    if (latest is! Map) return null;
    final conversationId =
        latest['conversation_id']?.toString().trim() ?? '';
    if (conversationId.isEmpty) return null;

    final historyResponse = await ApiClient.getJson(
      '$_base/conversations/$conversationId/messages?limit=50',
    );
    if (historyResponse.statusCode < 200 ||
        historyResponse.statusCode >= 300) {
      _throwResponseError(historyResponse);
    }
    return _decodeMap(historyResponse);
  }

  static Future<List<Map<String, dynamic>>> getPendingActions() async {
    final response = await ApiClient.getJson('$_base/actions/pending');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    final payload = _decodeMap(response);
    final actions = payload['actions'];
    if (actions is! List) return const [];
    return actions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<Uint8List> synthesizeSpeech(
    String text, {
    String languageCode = 'en',
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw const AgentAssistantException('There is no assistant text to speak.');
    }
    final response = await ApiClient.postJson(
      '$_base/speech',
      {
        'text': cleanText,
        'language_code': languageCode.trim().isEmpty ? 'en' : languageCode,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwResponseError(response);
    }
    if (response.bodyBytes.isEmpty) {
      throw const AgentAssistantException('Sarvam returned an empty speech response.');
    }
    return response.bodyBytes;
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
