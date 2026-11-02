import 'package:flutter/material.dart';

import '../live_translated_text.dart';
import '../voice_billing_display.dart';

/// What kind of dynamic text is being shown, so the right offline dictionary
/// is consulted.
enum DisplayKind { productName, warning }

/// Shows dynamic text in the user's language, trying the instant offline
/// dictionary first and only falling back to the network translator
/// ([LiveTranslatedText]) when the text is not covered.
///
/// DISPLAY ONLY. The [text] passed in is the canonical value (for a product,
/// the English/catalogue name that stock is deducted by). This widget never
/// changes it and nothing it renders is ever written back to the bill.
class OfflineFirstText extends StatelessWidget {
  const OfflineFirstText(
    this.text, {
    super.key,
    required this.kind,
    required this.locale,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final DisplayKind kind;
  final Locale locale;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final lang = locale.languageCode;
    final offline = switch (kind) {
      DisplayKind.productName => VoiceBillingDisplay.productName(text, lang),
      DisplayKind.warning => VoiceBillingDisplay.warning(text, lang),
    };
    if (offline != null) {
      return Text(
        offline,
        locale: locale,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }
    return LiveTranslatedText(
      text,
      locale: locale,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
