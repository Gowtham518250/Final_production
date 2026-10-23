import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'guided_dictation_button.dart';
import 'language_provider.dart';

class GuidedFieldControls extends StatelessWidget {
  const GuidedFieldControls({
    super.key,
    required this.controller,
    required this.step,
    required this.languageCode,
    this.color,
    this.trailing,
  });

  final TextEditingController controller;
  final String step;
  final String languageCode;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final guidedModeEnabled =
        Provider.of<LanguageProvider?>(context)?.isGuidedModeEnabled ?? false;
    if (!guidedModeEnabled) {
      return trailing ?? const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GuidedDictationButton(
          controller: controller,
          languageCode: languageCode,
          color: color,
        ),
        ?trailing,
      ],
    );
  }
}
