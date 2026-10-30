import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'ai_features_service.dart';
import 'language_provider.dart';
import 'live_translated_text.dart';

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

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadGreeting();
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

  Future<void> _sendMessage({String? suggestedMessage}) async {
    if (_isSending) return;
    final text = (suggestedMessage ?? _msgController.text).trim();
    if (text.isEmpty) return;

    final history = _messages
        .map((entry) => <String, String>{
              'role': entry['isMe'] == true ? 'user' : 'assistant',
              'content': entry['msg'].toString(),
            })
        .toList(growable: false);

    final languageCode = context.read<LanguageProvider>().locale.languageCode;
    setState(() {
      _messages.add({'msg': text, 'isMe': true});
      _msgController.clear();
      _isSending = true;
    });
    _scrollToLatest();

    final response = await ChatbotContextService.sendMessageWithContext(
      text,
      languageCode: languageCode,
      conversationHistory: history,
    );

    if (!mounted) return;
    setState(() {
      _messages.add({'msg': response, 'isMe': false});
      _isSending = false;
    });
    _scrollToLatest();
  }

  bool get _showSuggestions =>
      !_messages.any((entry) => entry['isMe'] == true) && !_isSending;

  @override
  void dispose() {
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
                  'Help & Support',
                  style: GoogleFonts.poppins(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Retail Mind AI assistant',
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
                        'Get app guidance or ask about your shop data.',
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
                for (final message in _messages) _buildMessageBubble(message),
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
                  onPressed: _isSending
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
                controller: _msgController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask a question about Retail Mind…',
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
            const SizedBox(width: 9),
            SizedBox(
              width: 47,
              height: 47,
              child: FilledButton(
                onPressed: _isSending ? null : _sendMessage,
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
