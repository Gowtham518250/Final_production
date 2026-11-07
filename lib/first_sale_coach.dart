import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_motion.dart';
import 'live_translated_text.dart';
import 'low_memory_performance.dart';
import 'tutorial_service.dart';

class FirstSaleCoachStep {
  const FirstSaleCoachStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
}

/// Dims the screen, cuts a hole over a real control, and points a hand at it.
class FirstSaleCoachOverlay extends StatefulWidget {
  const FirstSaleCoachOverlay({
    super.key,
    required this.steps,
    required this.onFinished,
  });

  final List<FirstSaleCoachStep> steps;
  final VoidCallback onFinished;

  @override
  State<FirstSaleCoachOverlay> createState() => _FirstSaleCoachOverlayState();
}

class _FirstSaleCoachOverlayState extends State<FirstSaleCoachOverlay>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  int _measureTries = 0;
  Rect? _hole;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce =
        AppMotion.reduced(context) || LowMemoryPerformance.useReducedMotion;
    if (reduce) {
      _pulse.stop();
      _pulse.value = 0.35;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  FirstSaleCoachStep? get _step {
    if (_index < 0 || _index >= widget.steps.length) return null;
    return widget.steps[_index];
  }

  Future<void> _measure() async {
    if (!mounted) return;
    final step = _step;
    if (step == null) {
      widget.onFinished();
      return;
    }
    final ctx = step.targetKey.currentContext;
    if (ctx == null) {
      _retryMeasureOrAdvance();
      return;
    }
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: AppMotion.reduced(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final box = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      _retryMeasureOrAdvance();
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    _measureTries = 0;
    setState(() {
      _hole = Rect.fromLTWH(
        origin.dx - 8,
        origin.dy - 8,
        box.size.width + 16,
        box.size.height + 16,
      ).inflate(4);
    });
  }

  void _retryMeasureOrAdvance() {
    if (_measureTries < 8) {
      _measureTries += 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      return;
    }
    _advance();
  }

  void _advance() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() {
      _index += 1;
      _measureTries = 0;
      _hole = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  Future<void> _skip() async {
    await TutorialService.completeFirstSaleCoach();
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final hole = _hole;
    final size = MediaQuery.sizeOf(context);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _CoachHoleClipper(hole: hole),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const ColoredBox(color: Color(0xCC0F172A)),
                ),
              ),
            ),
            if (hole != null)
              Positioned.fromRect(
                rect: hole.inflate(2),
                child: IgnorePointer(
                  ignoring: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
              ),
            if (hole != null)
              Positioned(
                left: (hole.center.dx - 18).clamp(
                  8.0,
                  math.max(8.0, size.width - 56),
                ),
                top: (hole.bottom - 10).clamp(
                  8.0,
                  math.max(8.0, size.height - 90),
                ),
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final lift = 10 * math.sin(_pulse.value * math.pi);
                      return Transform.translate(
                        offset: Offset(0, -lift),
                        child: child,
                      );
                    },
                    child: const _CoachHand(),
                  ),
                ),
              ),
            if (step != null)
              Positioned(
                left: 16,
                right: 16,
                top: hole != null && hole.center.dy < size.height * 0.45
                    ? hole.bottom + 56
                    : null,
                bottom: hole == null || hole.center.dy >= size.height * 0.45
                    ? (hole == null ? 24 : size.height - hole.top + 12)
                    : null,
                child: _CoachCard(
                  title: step.title,
                  body: step.body,
                  stepLabel: '${_index + 1} / ${widget.steps.length}',
                  onSkip: _skip,
                  onNext: _advance,
                  isLast: _index >= widget.steps.length - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoachHoleClipper extends CustomClipper<Path> {
  _CoachHoleClipper({required this.hole});

  final Rect? hole;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      path.addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(16)));
      path.fillType = PathFillType.evenOdd;
    }
    return path;
  }

  @override
  bool shouldReclip(_CoachHoleClipper oldClipper) => oldClipper.hole != hole;
}

class _CoachHand extends StatelessWidget {
  const _CoachHand();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.45,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.touch_app_rounded,
          size: 30,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.onSkip,
    required this.onNext,
    required this.isLast,
  });

  final String title;
  final String body;
  final String stepLabel;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: LiveTranslatedText(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                LiveTranslatedText(
                  stepLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LiveTranslatedText(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const LiveTranslatedText('Skip'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                  ),
                  child: LiveTranslatedText(isLast ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
