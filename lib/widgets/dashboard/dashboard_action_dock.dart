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
    this.targetKey,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
  final bool primary;
  final Key? targetKey;
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
          const horizontalPadding = 12.0;
          const spacing = 8.0;
          const minItemWidth = 76.0;
          const maxItemWidth = 136.0;
          final availableWidth = constraints.maxWidth;
          final contentWidth = availableWidth - horizontalPadding * 2;
          final fitWidth = items.isEmpty
              ? maxItemWidth
              : (contentWidth - spacing * (items.length - 1)) / items.length;
          final itemWidth = fitWidth.clamp(minItemWidth, maxItemWidth);
          final rowWidth =
              itemWidth * items.length + spacing * (items.length - 1);

          return Container(
            height: 84,
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: rowWidth < contentWidth ? contentWidth : rowWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const SizedBox(width: spacing),
                      SizedBox(
                        key:
                            items[index].targetKey ??
                            ValueKey('dashboard-action-$index'),
                        width: itemWidth,
                        height: 70,
                        child: _DashboardActionButton(item: items[index]),
                      ),
                    ],
                  ],
                ),
              ),
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
    const foreground = Color(0xFF1F2937);
    return Tooltip(
      message: item.label,
      child: Material(
        color: item.primary ? item.color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.primary ? item.color : const Color(0xFFE5E7EB),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 30,
                        decoration: BoxDecoration(
                          color: item.primary
                              ? Colors.white.withValues(alpha: 0.16)
                              : item.color.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          item.icon,
                          color: item.primary ? Colors.white : item.color,
                          size: 21,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LiveTranslatedText(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.primary
                              ? Colors.white
                              : foreground.withValues(alpha: 0.92),
                          fontSize: 11,
                          fontWeight: item.primary
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.badgeCount > 0)
                  Positioned(
                    right: -3,
                    top: -2,
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
