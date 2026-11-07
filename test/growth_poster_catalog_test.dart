import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/growth_poster_catalog.dart';

void main() {
  test('Grow My Shop has at least 20 distinct card colours', () {
    expect(GrowthPosterCatalog.all.length, greaterThanOrEqualTo(20));
    expect(
      GrowthPosterCatalog.all.map((style) => style.id).toSet().length,
      GrowthPosterCatalog.all.length,
    );
  });

  test('legacy templates keep shop and product poster colours', () {
    expect(GrowthPosterCatalog.of('fresh').id, 'emerald');
    expect(GrowthPosterCatalog.of('bold').id, 'indigo');
    expect(GrowthPosterCatalog.of('festive').id, 'ruby');
    expect(GrowthPosterCatalog.of('minimal').light, isTrue);
  });

  test('god image blessing cards are available', () {
    expect(GrowthPosterCatalog.blessings.length, greaterThanOrEqualTo(12));
    expect(GrowthPosterCatalog.of('ganesha').blessing, isTrue);
    expect(GrowthPosterCatalog.of('lakshmi').blessingName, 'Lakshmi');
    expect(GrowthPosterCatalog.accepts('god_user_123'), isTrue);
    expect(GrowthPosterCatalog.of('god_user_123').blessing, isTrue);
  });
}
