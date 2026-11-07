import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Types the shopkeeper's language into a placeholder, like live translation.
class SpokenLanguageTypewriter extends StatefulWidget {
  const SpokenLanguageTypewriter({
    super.key,
    required this.text,
    this.style,
    this.loop = false,
    this.msPerGlyph = 42,
    this.showCaret = true,
    this.maxLines = 3,
  });

  final String text;
  final TextStyle? style;
  final bool loop;
  final int msPerGlyph;
  final bool showCaret;
  final int maxLines;

  @override
  State<SpokenLanguageTypewriter> createState() =>
      _SpokenLanguageTypewriterState();
}

class _SpokenLanguageTypewriterState extends State<SpokenLanguageTypewriter>
    with SingleTickerProviderStateMixin {
  Timer? _typeTimer;
  late final AnimationController _caret;
  String _visible = '';

  @override
  void initState() {
    super.initState();
    _caret = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(SpokenLanguageTypewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.loop != widget.loop ||
        oldWidget.msPerGlyph != widget.msPerGlyph) {
      _sync();
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _caret.dispose();
    super.dispose();
  }

  bool get _reduced {
    if (!mounted) return true;
    return AppMotion.reduced(context);
  }

  void _sync() {
    _typeTimer?.cancel();
    if (!mounted) return;
    if (_reduced || widget.text.isEmpty) {
      setState(() => _visible = widget.text);
      return;
    }

    final target = widget.text.characters;
    if (widget.text.startsWith(_visible) && _visible.isNotEmpty) {
      _tickToward(target.length);
      return;
    }
    setState(() => _visible = '');
    _tickToward(target.length);
  }

  void _tickToward(int targetLength) {
    _typeTimer?.cancel();
    final delay = Duration(milliseconds: widget.msPerGlyph.clamp(16, 120));
    _typeTimer = Timer.periodic(delay, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final glyphs = widget.text.characters.toList();
      if (_visible.characters.length >= glyphs.length) {
        if (!widget.loop) {
          timer.cancel();
          return;
        }
        timer.cancel();
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (!mounted || !widget.loop) return;
          setState(() => _visible = '');
          _tickToward(widget.text.characters.length);
        });
        return;
      }
      setState(() {
        _visible = glyphs.take(_visible.characters.length + 1).join();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          height: 1.4,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
        );
    return AnimatedBuilder(
      animation: _caret,
      builder: (context, _) {
        final caretOn = widget.showCaret && !_reduced && _caret.value > 0.45;
        return Text(
          caretOn ? '$_visible|' : _visible,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
