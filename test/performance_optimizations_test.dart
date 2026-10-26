import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/performance_optimizations.dart';

void main() {
  test('small lists keep children alive for short interactive forms', () {
    final list = PerformanceOptimizations.optimizedListView(
      itemCount: 12,
      itemBuilder: (context, index) => Text('Item $index'),
    );

    expect(list.addAutomaticKeepAlives, isTrue);
  });

  test('large lists recycle off-screen children to reduce retained memory', () {
    final list = PerformanceOptimizations.optimizedListView(
      itemCount: 250,
      itemBuilder: (context, index) => Text('Item $index'),
    );

    expect(list.addAutomaticKeepAlives, isFalse);
    expect(list.cacheExtent, 220.0);
  });
}
