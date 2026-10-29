import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'live_translation_service.dart';
import 'shared_page_translations.dart';
import 'translation_text_policy.dart';

/// A replacement Text widget that localizes dictionary-backed labels and
/// translates other visible strings for display.
///
/// The original model/database value is never changed. Unsupported locales or
/// failed/offline translation keep the source visible rather than hiding data.
class LiveTranslatedText extends StatefulWidget {
  const LiveTranslatedText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  State<LiveTranslatedText> createState() => _LiveTranslatedTextState();
}

class _LiveTranslatedTextState extends State<LiveTranslatedText> {
  String _displayText = '';
  late final VoidCallback _capacityListener;

  bool _isListeningForCapacity = false;

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _capacityListener = _retryDeferredTranslation;
  }

  void _listenForCapacityChanges() {
    if (_isListeningForCapacity) return;
    LiveTranslationService.instance.capacityChanges.addListener(_capacityListener);
    _isListeningForCapacity = true;
  }

  void _stopListeningForCapacityChanges() {
    if (!_isListeningForCapacity) return;
    LiveTranslationService.instance.capacityChanges.removeListener(_capacityListener);
    _isListeningForCapacity = false;
  }

  void _retryDeferredTranslation() {
    if (!mounted || _displayText != widget.text) {
      _stopListeningForCapacityChanges();
      return;
    }
    final targetCode =
        (widget.locale ?? Localizations.localeOf(context)).languageCode;
    if (targetCode == 'en') {
      _stopListeningForCapacityChanges();
      return;
    }

    final service = LiveTranslationService.instance;
    if (!service.hasDeferredTranslation(
      widget.text,
      targetLanguageCode: targetCode,
    )) {
      _stopListeningForCapacityChanges();
      return;
    }
    if (!service.isDeferredAndRetryable(
      widget.text,
      targetLanguageCode: targetCode,
    )) {
      return;
    }

    // Only widgets with work actually deferred by the bounded queue subscribe
    // here. Ordinary translated labels no longer receive every capacity pulse.
    _requestKey = null;
    _stopListeningForCapacityChanges();
    _queueTranslation(targetCode);
  }
  String? _requestKey;
  int _requestVersion = 0;

  // Building this reverse index once avoids scanning the entire English
  // localization dictionary for every dynamic product/status label on a page.
  static Map<String, String>? _englishTextToKey;

  // Reuse matchers across dynamic labels instead of constructing regex objects
  // repeatedly while hundreds of text widgets initialize on low-memory phones.
  static final RegExp _urlPattern =
      RegExp(r'^https?://', caseSensitive: false);
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9][0-9 ()-]{6,}$');
  static final RegExp _machineIdentifierPattern =
      RegExp(r'^[#A-Z0-9][A-Z0-9_./:#-]{4,}$');
  static final RegExp _machineIdentifierCharacterPattern =
      RegExp(r'[0-9_./:#-]');
  static final RegExp _shortUppercaseTokenPattern =
      RegExp(r'^[A-Z0-9 _./:#-]{2,}$');

  static Map<String, String> _getEnglishTextToKey() {
    final cached = _englishTextToKey;
    if (cached != null) return cached;

    final english = AppLocalizations.translations['en'];
    if (english == null) return _englishTextToKey = <String, String>{};

    final reverse = <String, String>{};
    for (final entry in english.entries) {
      final normalized = entry.value.trim();
      if (normalized.isNotEmpty) {
        // Preserve the old linear scan's first-match behavior for duplicates.
        reverse.putIfAbsent(normalized, () => entry.key);
      }
    }
    _englishTextToKey = reverse;
    return reverse;
  }

  String? _curatedTranslation(String input, String targetCode) {
    final normalized = input.trim();
    final sharedPageCopy = SharedPageTranslations.lookup(
      normalized,
      targetCode,
    );
    if (sharedPageCopy != null) return sharedPageCopy;

    final screenText =
        AppLocalizations.screenTextTranslations[targetCode]?[normalized];
    if (screenText != null) return screenText;

    final target = AppLocalizations.translations[targetCode];
    if (target == null) return null;

    final englishKey = _getEnglishTextToKey()[normalized];
    if (englishKey == null) return null;
    return target[englishKey] ?? normalized;
  }

  bool _shouldPreserve(String input) {
    final value = input.trim();
    if (TranslationTextPolicy.isStandaloneNumberOrCurrency(value)) {
      return true;
    }
    if (value.isEmpty ||
        value.contains('@') ||
        _urlPattern.hasMatch(value) ||
        _phonePattern.hasMatch(value)) {
      return true;
    }

    // Preserve values such as ORD-20261017-13, invoice IDs and SKU codes.
    if (_machineIdentifierPattern.hasMatch(value) &&
        _machineIdentifierCharacterPattern.hasMatch(value)) {
      return true;
    }

    // Keep short all-capital tokens (UPI, GST, COD), but let statuses such as
    // PENDING and CANCELLED translate as ordinary labels.
    return value.length <= 4 &&
        value == value.toUpperCase() &&
        _shortUppercaseTokenPattern.hasMatch(value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations.localeOf subscribes this widget to MaterialApp locale
    // changes without requiring the page to know about a particular provider.
    _queueTranslation(
      (widget.locale ?? Localizations.localeOf(context)).languageCode,
    );
  }

  @override
  void didUpdateWidget(covariant LiveTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.locale != widget.locale) {
      _requestKey = null;
      _displayText = widget.text;
      _queueTranslation(
        (widget.locale ?? Localizations.localeOf(context)).languageCode,
      );
    }
  }

  void _queueTranslation(String targetCode) {
    final requestKey = '$targetCode\u0000${widget.text}';
    if (_requestKey == requestKey) return;
    _stopListeningForCapacityChanges();
    _requestKey = requestKey;
    final requestVersion = ++_requestVersion;

    if (targetCode == 'en' || widget.text.trim().isEmpty) {
      _displayText = widget.text;
      _stopListeningForCapacityChanges();
      return;
    }

    // Curated dictionary strings are instant and work offline.
    final curated = _curatedTranslation(widget.text, targetCode);
    if (curated != null) {
      _displayText = curated;
      _stopListeningForCapacityChanges();
      return;
    }

    // Don't send URLs, emails, phone numbers or machine identifiers for
    // translation. Those values must remain exact on screen.
    if (_shouldPreserve(widget.text)) {
      _displayText = widget.text;
      _stopListeningForCapacityChanges();
      return;
    }

    _displayText = widget.text;
    LiveTranslationService.instance
        .translateForDisplay(widget.text, targetLanguageCode: targetCode)
        .then((translated) {
          if (!mounted || requestVersion != _requestVersion) return;
          if (_displayText != translated) {
            _stopListeningForCapacityChanges();
            setState(() => _displayText = translated);
            return;
          }

          // Register only when the translation service confirms that this
          // widget's request is deferred due to backpressure. This avoids
          // waking every LiveTranslatedText on a large dashboard after batches.
          final service = LiveTranslationService.instance;
          if (service.hasDeferredTranslation(
            widget.text,
            targetLanguageCode: targetCode,
          )) {
            _listenForCapacityChanges();
          } else {
            _stopListeningForCapacityChanges();
          }
        });
  }

  @override
  void dispose() {
    _stopListeningForCapacityChanges();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText.isEmpty ? widget.text : _displayText,
      style: widget.style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      locale: widget.locale,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      textScaler: widget.textScaler,
      maxLines: widget.maxLines,
      semanticsLabel: widget.semanticsLabel,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectionColor: widget.selectionColor,
    );
  }
}
