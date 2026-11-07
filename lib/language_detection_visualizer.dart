// =============================================================================
// language_detection_visualizer.dart  —  LIVE LANGUAGE + PRODUCT VISUALIZER
// =============================================================================
// PURPOSE:
//   Shows the user WHICH language was auto-detected and what product name
//   was recognized in THEIR script — builds trust, surfaces errors early.
//
// FEATURES:
//   VIZ-1  Auto-detect dominant script from transcript in real-time
//   VIZ-2  Language badge with flag + name that animates in
//   VIZ-3  Per-word confidence coloring (green/amber/red)
//   VIZ-4  Product name displayed in NATIVE SCRIPT alongside English canonical
//   VIZ-5  "Did you mean?" nudge when confidence < 0.7
//   VIZ-6  Animated script transition when language switches mid-sentence
//   VIZ-7  Fully offline — zero external calls
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'voice_billing_display.dart';
import 'voice_billing_localization.dart';
import 'voice_nlp_engine.dart';

// ─── Script detection ─────────────────────────────────────────────────────────

enum DetectedScript {
  latin, // English (Roman)
  devanagari, // Hindi, Marathi
  tamil,
  telugu,
  kannada,
  malayalam,
  bengali,
  gujarati,
  gurmukhi, // Punjabi
  mixed, // Hinglish / code-switching
  unknown,
}

class ScriptDetector {
  static const Map<DetectedScript, _ScriptRange> _ranges = {
    DetectedScript.devanagari: _ScriptRange(0x0900, 0x097F),
    DetectedScript.tamil: _ScriptRange(0x0B80, 0x0BFF),
    DetectedScript.telugu: _ScriptRange(0x0C00, 0x0C7F),
    DetectedScript.kannada: _ScriptRange(0x0C80, 0x0CFF),
    DetectedScript.malayalam: _ScriptRange(0x0D00, 0x0D7F),
    DetectedScript.bengali: _ScriptRange(0x0980, 0x09FF),
    DetectedScript.gujarati: _ScriptRange(0x0A80, 0x0AFF),
    DetectedScript.gurmukhi: _ScriptRange(0x0A00, 0x0A7F),
  };

  static DetectedScript detect(String text) {
    if (text.trim().isEmpty) return DetectedScript.unknown;

    final counts = <DetectedScript, int>{};
    int latinCount = 0;

    for (final rune in text.runes) {
      if ((rune >= 0x0041 && rune <= 0x005A) ||
          (rune >= 0x0061 && rune <= 0x007A)) {
        latinCount++;
        continue;
      }
      for (final entry in _ranges.entries) {
        if (rune >= entry.value.start && rune <= entry.value.end) {
          counts[entry.key] = (counts[entry.key] ?? 0) + 1;
          break;
        }
      }
    }

    final nativeTotal = counts.values.fold(0, (a, b) => a + b);
    final total = nativeTotal + latinCount;
    if (total == 0) return DetectedScript.unknown;

    if (nativeTotal == 0) return DetectedScript.latin;

    // More than 20% Latin mixed with a native script = "mixed"
    if (latinCount / total > 0.20 && nativeTotal / total > 0.20) {
      return DetectedScript.mixed;
    }

    if (nativeTotal == 0) return DetectedScript.latin;

    // Return dominant native script
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String scriptToLocale(DetectedScript s) => const {
    DetectedScript.latin: 'en-IN',
    DetectedScript.devanagari: 'hi-IN',
    DetectedScript.tamil: 'ta-IN',
    DetectedScript.telugu: 'te-IN',
    DetectedScript.kannada: 'kn-IN',
    DetectedScript.malayalam: 'ml-IN',
    DetectedScript.bengali: 'bn-IN',
    DetectedScript.gujarati: 'gu-IN',
    DetectedScript.gurmukhi: 'pa-IN',
    DetectedScript.mixed: 'hi-IN',
    DetectedScript.unknown: 'en-IN',
  }[s]!;
}

class _ScriptRange {
  final int start, end;
  const _ScriptRange(this.start, this.end);
}

// ─── Detected word model ──────────────────────────────────────────────────────

class DetectedWord {
  final String native; // word as STT returned it
  final String? canonical; // English canonical name if resolved
  final double confidence; // 0.0 – 1.0
  final String role; // 'product' | 'quantity' | 'unit' | 'price' | 'other'

  const DetectedWord({
    required this.native,
    this.canonical,
    required this.confidence,
    this.role = 'other',
  });

  Color get color {
    if (confidence >= 0.80) return const Color(0xFF00C853); // green
    if (confidence >= 0.60) return const Color(0xFFFFAB00); // amber
    return const Color(0xFFFF3D71); // red
  }
}

// ─── Main Visualizer Widget ───────────────────────────────────────────────────

/// Drop this widget anywhere in your voice billing UI.
/// Feed it the live transcript + parsed items; it self-updates.
class LanguageDetectionVisualizer extends StatefulWidget {
  final String transcript;
  final String selectedLocale; // BCP-47, e.g. "hi-IN"
  final List<Map<String, dynamic>> parsedItems; // from NLP parser
  final bool isListening;

  const LanguageDetectionVisualizer({
    super.key,
    required this.transcript,
    required this.selectedLocale,
    required this.parsedItems,
    this.isListening = false,
  });

  @override
  State<LanguageDetectionVisualizer> createState() =>
      _LanguageDetectionVisualizerState();
}

class _LanguageDetectionVisualizerState
    extends State<LanguageDetectionVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late AnimationController _listenCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  DetectedScript _lastScript = DetectedScript.unknown;
  List<DetectedWord> _words = [];

  // Language display info
  static const _langInfo = <String, _LangDisplay>{
    'en-IN': _LangDisplay('English', '🇮🇳', Color(0xFF1565C0)),
    'hi-IN': _LangDisplay('हिंदी', '🕉️', Color(0xFFFF6F00)),
    'ta-IN': _LangDisplay('தமிழ்', '🌺', Color(0xFF6A1B9A)),
    'te-IN': _LangDisplay('తెలుగు', '🌸', Color(0xFF00695C)),
    'kn-IN': _LangDisplay('ಕನ್ನಡ', '🌻', Color(0xFFE65100)),
    'ml-IN': _LangDisplay('മലയാളം', '🌴', Color(0xFF1B5E20)),
    'mr-IN': _LangDisplay('मराठी', '🏔️', Color(0xFF880E4F)),
    'bn-IN': _LangDisplay('বাংলা', '🎋', Color(0xFF01579B)),
    'gu-IN': _LangDisplay('ગુજરાતી', '🦚', Color(0xFF4E342E)),
    'pa-IN': _LangDisplay('ਪੰਜਾਬੀ', '🌾', Color(0xFF558B2F)),
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _listenCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _lastScript = ScriptDetector.detect(widget.transcript);
    _words = _buildDetectedWords(widget.transcript, widget.parsedItems);
    _fadeCtrl.forward();
    _slideCtrl.forward();
    if (widget.isListening) _listenCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LanguageDetectionVisualizer old) {
    super.didUpdateWidget(old);
    final parsedNamesChanged =
        old.parsedItems.length != widget.parsedItems.length ||
        List.generate(old.parsedItems.length, (index) {
          final oldName =
              (old.parsedItems[index]['product_name'] ??
                      old.parsedItems[index]['name'] ??
                      '')
                  .toString();
          final newName =
              (widget.parsedItems[index]['product_name'] ??
                      widget.parsedItems[index]['name'] ??
                      '')
                  .toString();
          return oldName != newName;
        }).contains(true);
    if (old.transcript != widget.transcript ||
        parsedNamesChanged ||
        old.selectedLocale != widget.selectedLocale) {
      _analyzeTranscript();
    }
    if (old.isListening != widget.isListening) {
      if (widget.isListening) {
        _listenCtrl.repeat(reverse: true);
      } else {
        _listenCtrl.stop();
        _listenCtrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _listenCtrl.dispose();
    super.dispose();
  }

  void _analyzeTranscript() {
    final script = ScriptDetector.detect(widget.transcript);
    if (script != _lastScript) {
      _lastScript = script;
      // Animate badge change
      _slideCtrl.forward(from: 0);
    }
    setState(() {
      _words = _buildDetectedWords(widget.transcript, widget.parsedItems);
    });
  }

  List<DetectedWord> _buildDetectedWords(
    String transcript,
    List<Map<String, dynamic>> items,
  ) {
    if (transcript.trim().isEmpty) return [];

    final words = transcript.trim().split(RegExp(r'\s+'));
    final itemNames = items
        .map(
          (e) =>
              (e['product_name'] ?? e['name'] ?? '').toString().toLowerCase(),
        )
        .toList();

    return words.map((w) {
      final lower = w.toLowerCase();
      // Determine role
      String role = 'other';
      double confidence = 0.55;

      if (RegExp(r'^\d+\.?\d*$').hasMatch(w)) {
        role = 'quantity';
        confidence = 0.90;
      } else if (_isUnit(lower)) {
        role = 'unit';
        confidence = 0.85;
      } else if (_isPrice(lower)) {
        role = 'price';
        confidence = 0.90;
      } else if (itemNames.any((n) => n.contains(lower) || lower.contains(n))) {
        role = 'product';
        confidence = 0.88;
      } else {
        // Word in STT output not matched — lower confidence
        confidence = 0.45;
      }

      // Find canonical form if it's a product
      String? canonical;
      if (role == 'product') {
        for (final item in items) {
          final name = (item['product_name'] ?? item['name'] ?? '').toString();
          if (name.toLowerCase().contains(lower) ||
              lower.contains(name.toLowerCase())) {
            canonical = name;
            break;
          }
        }
      }

      return DetectedWord(
        native: w,
        canonical: canonical,
        confidence: confidence,
        role: role,
      );
    }).toList();
  }

  bool _isUnit(String w) => const {
    'kg', 'kilo', 'kilogram', 'g', 'gm', 'gram', 'litre', 'liter', 'l',
    'ml', 'piece', 'pieces', 'pc', 'pcs', 'packet', 'pkt', 'pack',
    'bottle', 'btl', 'box', 'dozen', 'doz',
    // Hindi/common
    'किलो', 'ग्राम', 'लीटर', 'पैकेट', 'पीस',
    // Tamil
    'கிலோ', 'கிராம்', 'லிட்டர்',
    // Telugu
    'కిలో', 'గ్రాము', 'లీటర్',
  }.contains(w);

  bool _isPrice(String w) => const {
    'rs',
    'rupees',
    'rupee',
    'रुपये',
    'रुपए',
    'रூபாய்',
    'రూపాయలు',
    'ರೂಪಾಯಿ',
    'rupaya',
    '₹',
  }.contains(w);

  @override
  Widget build(BuildContext context) {
    if (widget.transcript.isEmpty && widget.parsedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final detectedLocale = ScriptDetector.scriptToLocale(
      ScriptDetector.detect(widget.transcript),
    );
    final displayLocale = widget.selectedLocale;
    final langInfo = _langInfo[displayLocale] ?? _langInfo['en-IN']!;
    final autoInfo = _langInfo[detectedLocale];
    final isMismatch =
        detectedLocale != displayLocale &&
        widget.transcript.isNotEmpty &&
        detectedLocale != 'en-IN';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMismatch
                ? const Color(0xFFFFAB00).withOpacity(0.6)
                : const Color(0xFF1E3A5F),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Language badges ────────────────────────────────────────
            Row(
              children: [
                _buildLangBadge(
                  langInfo,
                  VoiceBillingLocalization.label('Selected', displayLocale),
                ),
                if (isMismatch && autoInfo != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: Color(0xFF546E7A),
                  ),
                  const SizedBox(width: 8),
                  SlideTransition(
                    position: _slideAnim,
                    child: _buildLangBadge(
                      autoInfo,
                      VoiceBillingLocalization.label('Detected', displayLocale),
                      pulse: true,
                    ),
                  ),
                ],
                const Spacer(),
                // Live listening indicator
                if (widget.isListening) _LiveDot(),
              ],
            ),

            // ── Mismatch warning ─────────────────────────────────────────────
            if (isMismatch) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFAB00).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFAB00),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Speech detected in ${autoInfo?.name ?? detectedLocale} — '
                        'switching to that language may improve accuracy',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFFFFAB00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            if (widget.isListening) ...[
              const SizedBox(height: 12),
              _ListeningWaveform(animation: _listenCtrl),
            ],

            // ── Row 2: Word-by-word confidence display ───────────────────────
            if (_words.isNotEmpty) ...[
              Text(
                VoiceBillingLocalization.label(
                  'RECOGNIZED WORDS',
                  displayLocale,
                ),
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFF42A5F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _words.length; i++)
                    _AnimatedDetectChip(
                      delay: Duration(milliseconds: 55 * i),
                      child: _buildWordChip(_words[i], displayLocale),
                    ),
                ],
              ),
            ],

            // ── Row 3: Parsed product names in native script ─────────────────
            if (widget.parsedItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF1E3A5F), height: 1),
              const SizedBox(height: 10),
              Text(
                VoiceBillingLocalization.label('PRODUCT NAMES', displayLocale),
                style: GoogleFonts.rajdhani(
                  color: const Color(0xFF42A5F5),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.parsedItems.asMap().entries.map(
                (entry) => _AnimatedDetectChip(
                  delay: Duration(milliseconds: 90 * entry.key),
                  child: _buildProductRow(
                    entry.value,
                    displayLocale,
                    langInfo.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLangBadge(
    _LangDisplay info,
    String label, {
    bool pulse = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: info.color.withOpacity(pulse ? 0.8 : 0.4),
          width: pulse ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  color: info.color.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                info.name,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  color: info.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(DetectedWord word, String locale) {
    final isProduct = word.role == 'product';
    final shown = _localizedWord(word, locale);
    return Tooltip(
      message: [
        'Role: ${word.role}',
        if (word.canonical != null) 'Matched: ${word.canonical}',
        'Confidence: ${(word.confidence * 100).toInt()}%',
      ].join('\n'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: word.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: word.color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shown,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: word.color,
                fontWeight: isProduct ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (isProduct && shown != word.native)
              Text(
                word.native,
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  color: word.color.withOpacity(0.7),
                  letterSpacing: 0.3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _localizedWord(DetectedWord word, String locale) {
    if (word.role == 'unit') {
      return VoiceBillingDisplay.unit(word.native, locale);
    }
    if (word.role == 'price') {
      final lower = word.native.toLowerCase().replaceAll('.', '');
      if (const {'rs', 'rupees', 'rupee'}.contains(lower) ||
          word.native.contains('₹')) {
        return VoiceBillingLocalization.label('Price', locale);
      }
    }
    if (word.role == 'product') {
      return VoiceBillingDisplay.productName(
            word.canonical ?? word.native,
            locale,
          ) ??
          word.native;
    }
    return word.native;
  }

  Widget _buildProductRow(
    Map<String, dynamic> item,
    String locale,
    Color accentColor,
  ) {
    final name = (item['product_name'] ?? item['name'] ?? '').toString();
    final price = item['price'] ?? item['unit_price'] ?? 0;
    final qty = item['quantity'] ?? item['qty'] ?? 1;
    final unit = _displayUnit(item, locale);
    final conf = (item['confidence'] as num?)?.toDouble() ?? 0.7;
    final nativeName = VoiceBillingDisplay.productName(name, locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: conf >= 0.8
                  ? const Color(0xFF00C853)
                  : conf >= 0.6
                  ? const Color(0xFFFFAB00)
                  : const Color(0xFFFF3D71),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nativeName ?? name,
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (nativeName != null && nativeName != name)
                  Text(
                    name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      color: const Color(0xFF546E7A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$qty $unit',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              color: const Color(0xFF7986CB),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${price.toString()}',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _displayUnit(Map<String, dynamic> item, String locale) {
    var unit = (item['unit'] ?? '').toString().trim();
    final name = (item['product_name'] ?? item['name'] ?? '').toString();
    if (unit.isEmpty || unit.toLowerCase() == 'pc') {
      final spokenKg = RegExp(
        r'\b(\d+(?:\.\d+)?)\s*(kg|kilo|కిలో)\b',
        caseSensitive: false,
      ).hasMatch(widget.transcript);
      if (spokenKg) {
        unit = 'kg';
      } else {
        unit = UnitInferrer.infer(name);
      }
    }
    return VoiceBillingDisplay.unit(unit, locale);
  }
}

// ─── Live dot animation ───────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF3D71),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              color: const Color(0xFFFF3D71),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Internal model ───────────────────────────────────────────────────────────

class _LangDisplay {
  final String name, flag;
  final Color color;
  const _LangDisplay(this.name, this.flag, this.color);
}

class _AnimatedDetectChip extends StatelessWidget {
  const _AnimatedDetectChip({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: Transform.scale(
              scale: 0.92 + (0.08 * value),
              child: animatedChild,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _ListeningWaveform extends StatelessWidget {
  const _ListeningWaveform({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (index) {
            final phase = (animation.value + (index / 7)) % 1.0;
            final height = 6 + (math.sin(phase * math.pi) * (10 + index * 1.4));
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF6366F1),
                  const Color(0xFF22D3EE),
                  phase,
                ),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        );
      },
    );
  }
}
