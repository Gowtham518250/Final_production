import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration page = Duration(milliseconds: 320);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = animation.drive(
      Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: const Interval(0, 0.7, curve: Curves.easeOut))),
    );

    if (AppMotion.reduced(context)) {
      return child;
    }

    final rise = animation.drive(
      Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    final settle = secondaryAnimation.drive(
      Tween<double>(
        begin: 1,
        end: 0.97,
      ).chain(CurveTween(curve: Curves.easeInOut)),
    );

    return ScaleTransition(
      scale: settle,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(position: rise, child: child),
      ),
    );
  }
}

const PageTransitionsTheme kSmoothPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: SmoothPageTransitionsBuilder(),
    TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
    TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
    TargetPlatform.windows: SmoothPageTransitionsBuilder(),
    TargetPlatform.linux: SmoothPageTransitionsBuilder(),
    TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(),
  },
);

class AnimatedAmountText extends StatelessWidget {
  const AnimatedAmountText({
    super.key,
    required this.value,
    this.prefix = '\u20B9',
    this.fractionDigits = 2,
    this.style,
    this.duration = const Duration(milliseconds: 450),
  });

  final double value;
  final String prefix;
  final int fractionDigits;
  final TextStyle? style;
  final Duration duration;

  String _format(double amount) =>
      '$prefix${amount.toStringAsFixed(fractionDigits)}';

  @override
  Widget build(BuildContext context) {
    final finalText = _format(value);
    if (AppMotion.reduced(context)) {
      return Text(finalText, style: style, maxLines: 1, softWrap: false);
    }

    return Semantics(
      label: finalText,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, amount, _) =>
            Text(_format(amount), style: style, maxLines: 1, softWrap: false),
      ),
    );
  }
}

class AnimatedMicButton extends StatefulWidget {
  const AnimatedMicButton({
    super.key,
    required this.listening,
    required this.processing,
    this.onTap,
    this.size = 72,
  });

  final bool listening;
  final bool processing;
  final VoidCallback? onTap;
  final double size;

  @override
  State<AnimatedMicButton> createState() => _AnimatedMicButtonState();
}

class _AnimatedMicButtonState extends State<AnimatedMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool _pressed = false;
  bool _reduced = false;

  bool get _active => widget.listening || widget.processing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
    _syncLoop();
  }

  @override
  void didUpdateWidget(AnimatedMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  void _syncLoop() {
    if (_reduced) {
      _loop.stop();
    } else if (_active && !_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  IconData get _icon {
    if (widget.processing) return Icons.hourglass_empty_rounded;
    if (widget.listening) return Icons.stop_rounded;
    return Icons.mic_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final listening = widget.listening;
    final processing = widget.processing;
    final accent = listening
        ? const Color(0xFF7C3AED)
        : const Color(0xFF6366F1);
    final enabled = widget.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: processing
          ? 'Processing voice billing'
          : listening
          ? 'Stop listening'
          : 'Start voice billing',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _active ? 1 : 0),
            duration: _reduced
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            onEnd: () {
              if (!_active) _loop.stop();
            },
            builder: (context, presence, _) => AnimatedBuilder(
              animation: _loop,
              builder: (context, _) {
                final t = _loop.value;
                final breathe = listening && !_reduced
                    ? 1 + 0.045 * math.sin(2 * math.pi * t)
                    : 1.0;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _MicRingsPainter(
                            t: t,
                            presence: presence,
                            listening: listening,
                            processing: processing,
                            reduced: _reduced,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: _pressed ? 0.93 : 1,
                      duration: _reduced ? Duration.zero : AppMotion.fast,
                      curve: Curves.easeOut,
                      child: Transform.scale(
                        scale: breathe,
                        child: _buildCore(size, listening, accent),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCore(double size, bool listening, Color accent) {
    final duration = AppMotion.reduced(context)
        ? Duration.zero
        : AppMotion.medium;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: listening
              ? const [Color(0xFF7C3AED), Color(0xFF4F46E5)]
              : const [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: listening ? 0.3 : 0.18),
            blurRadius: listening ? 26 : 16,
            spreadRadius: listening ? 2 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: AppMotion.reduced(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            _icon,
            key: ValueKey<IconData>(_icon),
            color: Colors.white,
            size: size * 0.44,
          ),
        ),
      ),
    );
  }
}

class _MicRingsPainter extends CustomPainter {
  _MicRingsPainter({
    required this.t,
    required this.presence,
    required this.listening,
    required this.processing,
    required this.reduced,
    required this.color,
  });

  final double t;
  final double presence;
  final bool listening;
  final bool processing;
  final bool reduced;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (presence <= 0.001) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (listening) {
      const rings = 3;
      const reach = 26.0;
      for (var index = 0; index < rings; index++) {
        final progress = reduced ? 0.25 + index * 0.3 : (t + index / rings) % 1;
        final ringRadius = radius + Curves.easeOut.transform(progress) * reach;
        final alpha = (1 - progress) * 0.3 * presence;
        canvas.drawCircle(
          center,
          ringRadius,
          Paint()..color = color.withValues(alpha: alpha * 0.35),
        );
        canvas.drawCircle(
          center,
          ringRadius,
          Paint()
            ..color = color.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    if (processing) {
      final ringRadius = radius + 7;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..color = color.withValues(alpha: 0.14 * presence)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final start = reduced ? -math.pi / 2 : t * 4 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        start,
        1.4,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.9 * presence)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MicRingsPainter old) =>
      old.t != t ||
      old.presence != presence ||
      old.listening != listening ||
      old.processing != processing ||
      old.reduced != reduced ||
      old.color != color;
}
