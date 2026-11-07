import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_motion.dart';
import 'live_translated_text.dart';

class GrowthStudioMotion {
  static const Color ink = Color(0xFF182230);
  static const Color muted = Color(0xFF64748B);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color violet = Color(0xFF7C3AED);
  static const Color night = Color(0xFF11183F);
}

class GrowthAmbientBackdrop extends StatelessWidget {
  const GrowthAmbientBackdrop({
    super.key,
    required this.animation,
    required this.child,
    this.height = 188,
  });

  final Animation<double> animation;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF312E81),
                    Color(0xFF4F46E5),
                    Color(0xFF7C3AED),
                  ],
                ),
              ),
            ),
            if (!reduced)
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) =>
                    CustomPaint(painter: _GrowthOrbPainter(animation.value)),
              ),
            if (!reduced)
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.55,
                  child: Transform.translate(
                    offset: Offset(animation.value * 140 - 40, 0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Align(alignment: Alignment.topCenter, child: child),
          ],
        ),
      ),
    );
  }
}

class _GrowthOrbPainter extends CustomPainter {
  _GrowthOrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
      );
    }

    final wave = math.sin(t * math.pi * 2);
    orb(
      Offset(size.width * (0.18 + wave * 0.04), size.height * 0.28),
      58,
      const Color(0xFF22D3EE).withValues(alpha: 0.28),
    );
    orb(
      Offset(size.width * (0.86 - wave * 0.05), size.height * 0.72),
      72,
      const Color(0xFFF59E0B).withValues(alpha: 0.22),
    );
    orb(
      Offset(size.width * 0.62, size.height * (0.18 + wave * 0.08)),
      46,
      Colors.white.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_GrowthOrbPainter oldDelegate) => oldDelegate.t != t;
}

class GrowthStagger extends StatelessWidget {
  const GrowthStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index * 70).clamp(0, 420)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 18),
          child: child,
        ),
      ),
    );
  }
}

class GrowthWizardRail extends StatelessWidget {
  const GrowthWizardRail({
    super.key,
    required this.step,
    required this.onStepTap,
    this.canOpenReview = false,
  });

  final int step;
  final ValueChanged<int> onStepTap;
  final bool canOpenReview;

  @override
  Widget build(BuildContext context) {
    const labels = ['Goal', 'Design', 'Review'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E2F7)),
        boxShadow: [
          BoxShadow(
            color: GrowthStudioMotion.indigo.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(labels.length, (index) {
              final current = index == step;
              final complete = index < step;
              final open = index <= step || (index == 2 && canOpenReview);
              return Expanded(
                child: InkWell(
                  onTap: open ? () => onStepTap(index) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedScale(
                    scale: current ? 1.04 : 1,
                    duration: AppMotion.medium,
                    curve: Curves.easeOutBack,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.medium,
                          width: current ? 36 : 30,
                          height: current ? 36 : 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: complete || current
                                ? const LinearGradient(
                                    colors: [
                                      GrowthStudioMotion.indigo,
                                      GrowthStudioMotion.violet,
                                    ],
                                  )
                                : null,
                            color: complete || current
                                ? null
                                : const Color(0xFFF1F5F9),
                          ),
                          child: Center(
                            child: complete
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: current
                                          ? Colors.white
                                          : GrowthStudioMotion.muted,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        LiveTranslatedText(
                          labels[index],
                          style: TextStyle(
                            color: current
                                ? GrowthStudioMotion.indigo
                                : GrowthStudioMotion.muted,
                            fontSize: 11,
                            fontWeight: current
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (step + 1) / 3),
              duration: AppMotion.page,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEF2FF),
                color: GrowthStudioMotion.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GrowMyShopEntryCard extends StatefulWidget {
  const GrowMyShopEntryCard({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<GrowMyShopEntryCard> createState() => _GrowMyShopEntryCardState();
}

class _GrowMyShopEntryCardState extends State<GrowMyShopEntryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(22),
        child: GrowthAmbientBackdrop(
          animation: _loop,
          height: 118,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _loop,
                  builder: (context, child) => Transform.rotate(
                    angle: AppMotion.reduced(context)
                        ? 0
                        : math.sin(_loop.value * math.pi * 2) * 0.08,
                    child: child,
                  ),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: LiveTranslatedText(
                              'Grow My Shop',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'FREE',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LiveTranslatedText(
                        'Create a shop poster and share your offers.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? const Color(0xFFC4B5FD) : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GrowthLoadingStage extends StatelessWidget {
  const GrowthLoadingStage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseMark(),
          SizedBox(height: 14),
          LiveTranslatedText(
            'Preparing your promotion studio…',
            style: TextStyle(
              color: GrowthStudioMotion.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseMark extends StatefulWidget {
  const _PulseMark();

  @override
  State<_PulseMark> createState() => _PulseMarkState();
}

class _PulseMarkState extends State<_PulseMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 0.92,
        end: 1.08,
      ).animate(CurvedAnimation(parent: _loop, curve: Curves.easeInOut)),
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [GrowthStudioMotion.indigo, GrowthStudioMotion.violet],
          ),
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
      ),
    );
  }
}

class GrowthStepSwitch extends StatelessWidget {
  const GrowthStepSwitch({super.key, required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.page,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final rise = Tween<Offset>(
          begin: const Offset(0.03, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: rise, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(step), child: child),
    );
  }
}
