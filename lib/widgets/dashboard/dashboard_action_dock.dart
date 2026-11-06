import 'package:flutter/material.dart';
import '../../live_translated_text.dart';

class DashboardActionItem {
  const DashboardActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
  final bool primary;
}

class DashboardActionDock extends StatelessWidget {
  const DashboardActionDock({
    super.key,
    required this.items,
    required this.backgroundColor,
    required this.borderColor,
  });

  final List<DashboardActionItem> items;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 5;
          const horizontalPadding = 12.0;
          const spacing = 6.0;
          final itemWidth =
              (constraints.maxWidth -
                  horizontalPadding * 2 -
                  spacing * (columns - 1)) /
              columns;

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: _DashboardActionButton(item: item),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  const _DashboardActionButton({required this.item});

  final DashboardActionItem item;

  @override
  Widget build(BuildContext context) {
    final foreground = item.primary ? Colors.white : item.color;
    return Tooltip(
      message: item.label,
      child: Material(
        color: item.primary ? item.color : item.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: item.primary
                  ? null
                  : Border.all(color: item.color.withValues(alpha: 0.3)),
              boxShadow: item.primary
                  ? [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: foreground, size: 21),
                      const SizedBox(height: 3),
                      LiveTranslatedText(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.badgeCount > 99
                            ? '99+'
                            : item.badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
