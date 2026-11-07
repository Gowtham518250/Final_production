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
          const horizontalPadding = 8.0;
          const spacing = 6.0;
          const minItemWidth = 76.0;
          const maxItemWidth = 120.0;
          final availableWidth = constraints.maxWidth;
          final contentWidth = availableWidth - horizontalPadding * 2;
          final fitWidth = items.isEmpty
              ? maxItemWidth
              : (contentWidth - spacing * (items.length - 1)) / items.length;
          final itemWidth = fitWidth.clamp(minItemWidth, maxItemWidth);
          final rowWidth =
              itemWidth * items.length + spacing * (items.length - 1);

          return Container(
            height: 72,
            padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 6,
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
                        height: 58,
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
    final foreground = item.primary ? Colors.white : item.color;
    return Tooltip(
      message: item.label,
      child: Material(
        color: item.primary ? item.color : item.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.primary
                    ? item.color
                    : item.color.withValues(alpha: 0.24),
              ),
              boxShadow: item.primary
                  ? [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.22),
                        blurRadius: 7,
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
                      Icon(
                        item.icon,
                        color: foreground,
                        size: item.primary ? 21 : 20,
                      ),
                      const SizedBox(height: 3),
                      LiveTranslatedText(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 10,
                          fontWeight: item.primary
                              ? FontWeight.w700
                              : FontWeight.w600,
                          height: 1.1,
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
