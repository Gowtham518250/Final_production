import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpCodeInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final int length;
  final bool enabled;
  final Color textColor;
  final Color fillColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color placeholderColor;
  final String placeholder;
  final double boxHeight;

  const OtpCodeInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.length = 6,
    this.enabled = true,
    this.textColor = const Color(0xFF111827),
    this.fillColor = const Color(0xFFF9FAFB),
    this.borderColor = const Color(0xFFD1D5DB),
    this.focusedBorderColor = const Color(0xFF6366F1),
    this.placeholderColor = const Color(0xFF9CA3AF),
    this.placeholder = '•',
    this.boxHeight = 58,
  }) : assert(length > 0);

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _bindFocusNode();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_refresh);
      if (_ownsFocusNode) _focusNode.dispose();
      _bindFocusNode();
    }
  }

  void _bindFocusNode() {
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode.removeListener(_refresh);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.controller.text;
    return Semantics(
      textField: true,
      label: '${widget.length}-digit verification code',
      value: digits,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          final boxWidth =
              (constraints.maxWidth - spacing * (widget.length - 1)) /
              widget.length;
          return SizedBox(
            height: widget.boxHeight,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(widget.length, (index) {
                      final hasDigit = index < digits.length;
                      final isCurrent =
                          _focusNode.hasFocus &&
                          index == digits.length &&
                          digits.length < widget.length;
                      return Container(
                        width: boxWidth,
                        height: widget.boxHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.enabled
                              ? widget.fillColor
                              : widget.fillColor.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? widget.focusedBorderColor
                                : widget.borderColor,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          hasDigit ? digits[index] : widget.placeholder,
                          style: TextStyle(
                            color: hasDigit
                                ? widget.textColor
                                : widget.placeholderColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned.fill(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: widget.length,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    showCursor: false,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      widget.controller.selection = TextSelection.collapsed(
                        offset: widget.controller.text.length,
                      );
                    },
                    onChanged: widget.onChanged,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
