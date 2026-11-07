import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../live_translated_text.dart';

class FirstSaleGuide extends StatefulWidget {
  const FirstSaleGuide({super.key, required this.onStartSale});

  final VoidCallback onStartSale;

  @override
  State<FirstSaleGuide> createState() => _FirstSaleGuideState();
}

class _FirstSaleGuideState extends State<FirstSaleGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _steps = [
    (Icons.point_of_sale_rounded, 'Open sales'),
    (Icons.add_shopping_cart_rounded, 'Add products'),
    (Icons.mic_rounded, 'Try voice billing'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value * _steps.length;
        final activeStep = progress.floor().clamp(0, _steps.length - 1);
        final pulse = math.sin((progress % 1) * math.pi);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiveTranslatedText(
                'Your first sale, step by step',
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              LiveTranslatedText(
                'Follow the animation, then try speaking your items.',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var index = 0; index < _steps.length; index++) ...[
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: index <= activeStep
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    Expanded(child: _buildStep(index, activeStep, pulse)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              LiveTranslatedText(
                'In Sales, tap the microphone, say product names and quantities, then review before adding them to the bill.',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: widget.onStartSale,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const LiveTranslatedText('Start first sale'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(int index, int activeStep, double pulse) {
    final isActive = index == activeStep;
    final (icon, label) = _steps[index];

    return Transform.scale(
      scale: isActive ? 1 + pulse * 0.035 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6366F1).withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF6366F1).withValues(alpha: 0.55)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(
                      0xFF6366F1,
                    ).withValues(alpha: 0.12 + pulse * 0.12),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: isActive
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            LiveTranslatedText(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF3730A3)
                    : const Color(0xFF475569),
                fontSize: 10,
                height: 1.2,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
