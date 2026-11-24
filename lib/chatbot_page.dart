import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as audio;

import 'agent_assistant_service.dart';
import 'ai_features_service.dart';
import 'language_provider.dart';
import 'live_translated_text.dart';
import 'retail_mind_promo_player_page.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  static const Color _ink = Color(0xFF172554);
  static const Color _muted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF4F46E5);

  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      'msg': "Hello! I'm your Retail Mind assistant. Ask me how to use the app or get help with a shop task.",
      'isMe': false,
    },
  ];

  static const List<String> _suggestions = [
    'How do I create a bill?',
    'How can I add a product?',
    'How do I reset my password?',
    'Show my sales today',
  ];

  final audio.Record _audioRecorder = audio.Record();
  Timer? _recordingLimitTimer;
  bool _isRecording = false;
  bool _isSending = false;
  bool _isLoadingAgent = true;
  bool _agentEnabled = false;
  String? _conversationId;
  String? _agentStatusMessage;
  final List<Map<String, dynamic>> _pendingActions = [];
  final Set<String> _busyActionIds = {};

  @override
  void initState() {
    super.initState();
    _loadGreeting();
    _loadAgentCapabilities();
  }

  Future<void> _loadAgentCapabilities() async {
    try {
      final capabilities = await AgentAssistantService.getCapabilities();
      if (!mounted) return;
      final enabled = capabilities['execution_enabled'] == true;
      setState(() {
        _agentEnabled = enabled;
        _isLoadingAgent = false;
        _agentStatusMessage = enabled
            ? null
            : 'The Retail Mind Agent is not enabled on this backend yet. The owner app will connect automatically after the backend deployment and agent feature flag are enabled.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _agentEnabled = false;
        _isLoadingAgent = false;
        _agentStatusMessage = error.toString();
      });
    }
  }

  Future<void> _loadGreeting() async {
    final greeting = await ChatbotContextService.getPersonalizedGreeting();
    if (!mounted) return;
    setState(() {
      _messages[0] = {'msg': greeting, 'isMe': false};
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startAgentRecording() async {
    if (!_agentEnabled || _isSending || _isRecording) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recording is currently supported in the Android app. Use text input on web.'),
        ),
      );
      return;
    }

    String? pendingPath;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw const AgentAssistantException(
          'Microphone permission is required for voice input.',
        );
      }
      final directory = await getTemporaryDirectory();
      pendingPath = p.join(
        directory.path,
        'retail_mind_agent_${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      await _audioRecorder.start(
        path: pendingPath,
        encoder: audio.AudioEncoder.aacLc,
        bitRate: 96000,
      );
      if (!mounted) {
        await _audioRecorder.stop();
        return;
      }
      setState(() {
        _isRecording = true;
        _msgController.clear();
      });
      _recordingLimitTimer?.cancel();
      _recordingLimitTimer = Timer(const Duration(seconds: 50), () {
        if (mounted && _isRecording) {
          _stopAgentRecording();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listening… tap the microphone again when you finish.'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (pendingPath != null) {
        try {
          await File(pendingPath).delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _stopAgentRecording() async {
    if (!_isRecording || _isSending) return;
    _recordingLimitTimer?.cancel();
    String? recordingPath;
    try {
      recordingPath = await _audioRecorder.stop();
    } catch (_) {
      recordingPath = null;
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isSending = true;
    });
    _scrollToLatest();

    try {
      if (recordingPath == null) {
        throw const AgentAssistantException(
          'The voice recording could not be saved. Please try again.',
        );
      }
      final file = File(recordingPath);
      if (!await file.exists() || await file.length() == 0) {
        throw const AgentAssistantException(
          'No audio was captured. Please speak and try again.',
        );
      }
      final languageCode =
          context.read<LanguageProvider>().locale.languageCode;
      final response = await AgentAssistantService.sendVoice(
        recordingPath,
        conversationId: _conversationId,
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = response.conversationId.isEmpty
            ? _conversationId
            : response.conversationId;
        final transcript = response.transcript?.trim() ?? '';
        if (transcript.isNotEmpty) {
          _messages.add({'msg': '🎙️ ' + transcript, 'isMe': true});
        }
        _messages.add({
          'msg': response.answer.isEmpty
              ? 'I could not complete that voice request. Please try again.'
              : response.answer,
          'isMe': false,
        });
        for (final action in response.pendingActions) {
          final actionId = action['action_id']?.toString();
          if (actionId != null &&
              actionId.isNotEmpty &&
              !_pendingActions.any((item) => item['action_id'] == actionId)) {
            _pendingActions.add(action);
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add({'msg': error.toString(), 'isMe': false});
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
      if (recordingPath != null) {
        try {
          await File(recordingPath).delete();
        } catch (_) {}
      }
      _scrollToLatest();
    }
  }

  Future<void> _sendMessage({String? suggestedMessage}) async {
    if (_isSending || !_agentEnabled) return;
    final text = (suggestedMessage ?? _msgController.text).trim();
    if (text.isEmpty) return;

    final languageCode = context.read<LanguageProvider>().locale.languageCode;
    setState(() {
      _messages.add({'msg': text, 'isMe': true});
      _msgController.clear();
      _isSending = true;
    });
    _scrollToLatest();

    try {
      final response = await AgentAssistantService.sendMessage(
        text,
        conversationId: _conversationId,
        languageCode: languageCode,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = response.conversationId.isEmpty
            ? _conversationId
            : response.conversationId;
        _messages.add({
          'msg': response.answer.isEmpty
              ? 'I could not complete that request. Please try again.'
              : response.answer,
          'isMe': false,
        });
        for (final action in response.pendingActions) {
          final actionId = action['action_id']?.toString();
          if (actionId != null &&
              actionId.isNotEmpty &&
              !_pendingActions.any((item) => item['action_id'] == actionId)) {
            _pendingActions.add(action);
          }
        }
        _isSending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add({'msg': error.toString(), 'isMe': false});
        _isSending = false;
      });
    }
    _scrollToLatest();
  }

  Future<void> _confirmPendingAction(Map<String, dynamic> action) async {
    final actionId = action['action_id']?.toString() ?? '';
    final previewHash = action['preview_hash']?.toString() ?? '';
    if (actionId.isEmpty || previewHash.isEmpty ||
        _busyActionIds.contains(actionId)) {
      return;
    }

    setState(() => _busyActionIds.add(actionId));
    try {
      final result = await AgentAssistantService.confirmAction(
        actionId: actionId,
        previewHash: previewHash,
      );
      if (!mounted) return;
      setState(() {
        _pendingActions.removeWhere((item) => item['action_id'] == actionId);
        final message = (result['message'] ?? '').toString().trim();
        _messages.add({
          'msg': message.isNotEmpty
              ? message
              : 'The confirmed action was processed. Refresh the relevant Retail Mind screen to verify the latest data.',
          'isMe': false,
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add({'msg': error.toString(), 'isMe': false});
      });
    } finally {
      if (mounted) {
        setState(() => _busyActionIds.remove(actionId));
      }
      _scrollToLatest();
    }
  }

  Future<void> _cancelPendingAction(Map<String, dynamic> action) async {
    final actionId = action['action_id']?.toString() ?? '';
    if (actionId.isEmpty || _busyActionIds.contains(actionId)) return;

    setState(() => _busyActionIds.add(actionId));
    try {
      await AgentAssistantService.cancelAction(actionId: actionId);
      if (!mounted) return;
      setState(() {
        _pendingActions.removeWhere((item) => item['action_id'] == actionId);
        _messages.add({
          'msg': 'The pending action was cancelled. No business data was changed.',
          'isMe': false,
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add({'msg': error.toString(), 'isMe': false});
      });
    } finally {
      if (mounted) {
        setState(() => _busyActionIds.remove(actionId));
      }
      _scrollToLatest();
    }
  }

  Widget _buildPendingActionCard(Map<String, dynamic> action) {
    final actionId = action['action_id']?.toString() ?? '';
    final rawPreview = action['preview'];
    final preview = rawPreview is Map
        ? Map<String, dynamic>.from(rawPreview)
        : <String, dynamic>{};
    final operation = (preview['operation'] ??
            action['action_type'] ??
            'PENDING ACTION')
        .toString()
        .replaceAll('_', ' ');
    final isBusy = _busyActionIds.contains(actionId);
    const visibleFields = [
      'invoice_number',
      'customer_name',
      'customer_phone_last4',
      'invoice_id',
      'order_id',
      'current_status',
      'resulting_status',
      'payment_method',
      'payment_status',
      'payment_amount',
      'total_amount',
      'amount',
      'balance_before',
      'balance_after',
      'outstanding_before',
      'outstanding_after',
    ];

    String displayValue(String key, dynamic value) {
      if (value is num &&
          (key.contains('amount') || key.startsWith('balance_') ||
              key.startsWith('outstanding_'))) {
        return '₹' + value.toStringAsFixed(2);
      }
      if (key == 'customer_phone_last4') return '•••• ' + value.toString();
      return value.toString();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(38, 0, 8, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172554).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: _primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  operation,
                  style: GoogleFonts.poppins(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'REVIEW',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9A3412),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final key in visibleFields)
            if (preview[key] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        key.replaceAll('_', ' '),
                        style: GoogleFonts.poppins(color: _muted, fontSize: 10),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(
                        displayValue(key, preview[key]),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(
                          color: _ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (preview['items'] is List)
            for (final item in (preview['items'] as List).whereType<Map>())
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  (item['product_name'] ?? 'Item').toString() +
                      ' × ' +
                      (item['quantity'] ?? '').toString() +
                      (item['line_total'] == null
                          ? ''
                          : '  •  ₹' + item['line_total'].toString()),
                  style: GoogleFonts.poppins(color: _ink, fontSize: 10),
                ),
              ),
          if (preview['warning'] != null) ...[
            const SizedBox(height: 6),
            Text(
              preview['warning'].toString(),
              style: GoogleFonts.poppins(
                color: const Color(0xFF92400E),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : () => _cancelPendingAction(action),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : () => _confirmPendingAction(action),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing is saved until you confirm this preview.',
            style: GoogleFonts.poppins(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  bool get _showSuggestions =>
      _agentEnabled &&
      !_messages.any((entry) => entry['isMe'] == true) &&
      !_isSending;

  @override
  void dispose() {
    _recordingLimitTimer?.cancel();
    unawaited(_audioRecorder.dispose());
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.support_agent_rounded, color: _primary),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveTranslatedText(
                  'Retail Mind Agent',
                  style: GoogleFonts.poppins(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Your authenticated shop operations assistant',
                  style: GoogleFonts.poppins(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LiveTranslatedText(
                        'Ask Retail Mind',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Ask questions about live shop data and prepare operations for review.',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_user_outlined,
                    color: Colors.white70, size: 19),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              children: [
                _buildPromoCard(context),
                if (!_agentEnabled) _buildAgentStatusBanner(),
                for (final message in _messages) _buildMessageBubble(message),
                for (final action in _pendingActions)
                  _buildPendingActionCard(action),
                if (_showSuggestions) _buildSuggestions(),
                if (_isSending) _buildTypingIndicator(),
              ],
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RetailMindPromoPlayerPage(),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 176,
                    child: Image.asset(
                      'assets/videos/retail_mind_promo_poster.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x22000000),
                            Color(0x00000000),
                            Color(0x66000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: _primary,
                      size: 36,
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 13,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: LiveTranslatedText(
                        'RETAIL MIND',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LiveTranslatedText(
                            'See Retail Mind in action',
                            style: GoogleFonts.poppins(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          LiveTranslatedText(
                            'A quick look at smarter shop management',
                            style: GoogleFonts.poppins(
                              color: _muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    LiveTranslatedText(
                      '0:27',
                      style: GoogleFonts.poppins(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentStatusBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF92400E)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _isLoadingAgent
                  ? 'Checking Retail Mind Agent availability…'
                  : (_agentStatusMessage ?? 'The Retail Mind Agent is currently unavailable.'),
              style: GoogleFonts.poppins(
                color: const Color(0xFF78350F),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
          if (!_isLoadingAgent)
            IconButton(
              onPressed: _loadAgentCapabilities,
              tooltip: 'Retry connection',
              icon: const Icon(Icons.refresh_rounded, size: 18),
              color: const Color(0xFF92400E),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 17, color: _primary),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? _primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(isMe ? 17 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 17),
                ),
                border: isMe
                    ? null
                    : Border.all(color: const Color(0xFFE5EAF3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF172554)
                        .withValues(alpha: isMe ? 0.08 : 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SelectableText(
                message['msg'].toString(),
                style: GoogleFonts.poppins(
                  color: isMe ? Colors.white : _ink,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(left: 38, top: 2, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveTranslatedText(
            'Try asking',
            style: GoogleFonts.poppins(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _suggestions)
                ActionChip(
                  label: Text(
                    suggestion,
                    style: GoogleFonts.poppins(
                      color: _primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFDDE3F0)),
                  onPressed: (_isSending || !_agentEnabled)
                      ? null
                      : () => _sendMessage(suggestedMessage: suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 38, bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primary,
            ),
          ),
          const SizedBox(width: 9),
          LiveTranslatedText(
            'Retail Mind is preparing an answer…',
            style: GoogleFonts.poppins(color: _muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: const Color(0xFFCBD5E1).withValues(alpha: 0.55)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                enabled: _agentEnabled && !_isSending && !_isRecording,
                controller: _msgController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _agentEnabled
                      ? 'Ask Retail Mind to check or prepare an operation…'
                      : 'Agent unavailable on this backend',
                  hintStyle: GoogleFonts.poppins(color: _muted, fontSize: 11),
                  filled: true,
                  fillColor: const Color(0xFFF4F7FC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: Color(0xFFE5EAF3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _primary, width: 1.3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 43,
              height: 47,
              child: IconButton.filledTonal(
                onPressed: (_isSending || !_agentEnabled)
                    ? null
                    : (_isRecording ? _stopAgentRecording : _startAgentRecording),
                tooltip: _isRecording ? 'Stop voice recording' : 'Record voice request',
                style: IconButton.styleFrom(
                  foregroundColor: _isRecording ? Colors.white : _primary,
                  backgroundColor: _isRecording ? Colors.redAccent : const Color(0xFFEEF2FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 19,
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 47,
              height: 47,
              child: FilledButton(
                onPressed: (_isSending || _isRecording || !_agentEnabled) ? null : _sendMessage,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Icon(Icons.send_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
