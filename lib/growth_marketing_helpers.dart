/// Free, deterministic campaign copy for the first RetailMind Growth Agent MVP.
/// This intentionally uses local templates, not a paid AI API. It never invents
/// a discount: an offer appears only when the owner explicitly enters one.
class GrowthMarketingPricing {
  /// Returns a percentage only for a valid, strictly discounted price.
  static double? discountPercent(
    double? originalPrice,
    double? discountedPrice,
  ) {
    if (originalPrice == null ||
        discountedPrice == null ||
        !originalPrice.isFinite ||
        !discountedPrice.isFinite ||
        originalPrice <= 0 ||
        discountedPrice < 0 ||
        discountedPrice >= originalPrice) {
      return null;
    }
    return ((originalPrice - discountedPrice) / originalPrice) * 100;
  }
}

class GrowthCreativePlanner {
  static Map<String, dynamic>? nextFestival(dynamic value, {DateTime? today}) {
    dynamic rows = value;
    if (value is Map) {
      for (final key in const ['festivals', 'items', 'results', 'data']) {
        if (value[key] is List) {
          rows = value[key];
          break;
        }
      }
    }
    if (rows is! List) return null;

    final current = today ?? DateTime.now();
    final currentDate = DateTime(current.year, current.month, current.day);
    final upcoming = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final festival = Map<String, dynamic>.from(row);
      final name =
          (festival['festival_name'] ??
                  festival['name'] ??
                  festival['festival'] ??
                  festival['title'])
              ?.toString()
              .trim();
      if (name == null || name.isEmpty) continue;

      int? daysUntil = int.tryParse(
        (festival['days_until'] ?? festival['daysUntil'])?.toString() ?? '',
      );
      if (daysUntil == null) {
        final date = DateTime.tryParse(
          (festival['date'] ??
                      festival['festival_date'] ??
                      festival['date_iso'])
                  ?.toString() ??
              '',
        );
        if (date != null) {
          final festivalDate = DateTime(date.year, date.month, date.day);
          daysUntil = festivalDate.difference(currentDate).inDays;
        }
      }
      if (daysUntil == null || daysUntil < 0) continue;
      festival['_days_until'] = daysUntil;
      festival['name'] = name;
      upcoming.add(festival);
    }

    if (upcoming.isEmpty) return null;
    upcoming.sort(
      (a, b) => (a['_days_until'] as int).compareTo(b['_days_until'] as int),
    );
    return upcoming.first;
  }

  static String templateFor({String? festivalName, String? productCategory}) {
    if (festivalName?.trim().isNotEmpty ?? false) return 'festive';
    final category = (productCategory ?? '').toLowerCase();
    if (const [
      'food',
      'grocery',
      'produce',
      'fruit',
      'vegetable',
      'dairy',
    ].any(category.contains)) {
      return 'fresh';
    }
    return 'bold';
  }

  static String templateLabel(String template) {
    switch (template) {
      case 'festive':
        return 'Festival-inspired';
      case 'fresh':
        return 'Fresh & local';
      default:
        return 'Shop spotlight';
    }
  }
}

class GrowthAdCopy {
  static String festivalInvitation(String festivalName, String language) {
    final festival = festivalName.trim();
    if (language == 'te') {
      return festival + ' సందర్భంగా మా దుకాణాన్ని సందర్శించండి.';
    }
    if (language == 'hi') {
      return festival + ' के अवसर पर हमारी दुकान पर आएँ।';
    }
    return 'Celebrate ' + festival + ' with a visit to our shop.';
  }

  static String headline(String goal, String language) {
    final telugu = language == 'te';
    final hindi = language == 'hi';

    if (goal == 'new_product') {
      if (telugu) return 'మా కొత్త ఉత్పత్తులను చూడండి';
      if (hindi) return 'हमारे नए उत्पाद देखें';
      return 'Discover our latest products';
    }
    if (goal == 'regular_customers') {
      if (telugu) return 'మళ్లీ వచ్చి షాపింగ్ చేయండి';
      if (hindi) return 'फिर आइए, खरीदारी कीजिए';
      return 'We would love to see you again';
    }
    if (goal == 'clear_stock') {
      if (telugu) return 'స్టాక్‌లో ఉన్న ఉత్పత్తులు అందుబాటులో ఉన్నాయి';
      if (hindi) return 'उपलब्ध स्टॉक में से चुनें';
      return 'Available now at our shop';
    }
    if (telugu) return 'మీ దగ్గరలోని మీ నమ్మకమైన షాప్';
    if (hindi) return 'आपकी भरोसेमंद नज़दीकी दुकान';
    return 'Your neighbourhood shop';
  }

  static String caption({
    required String shopName,
    required String goal,
    required String language,
    String? productName,
    double? price,
    String? offer,
    String? festivalName,
    required String offerCode,
  }) {
    final shop = shopName.trim().isEmpty ? 'Our shop' : shopName.trim();
    final product = (productName ?? '').trim();
    final validPrice = price != null && price.isFinite && price >= 0;
    final offerText = (offer ?? '').trim();

    if (language == 'te') {
      final parts = <String>[
        shop + ' కు స్వాగతం!',
        headline(goal, language) + '.',
      ];
      if (product.isNotEmpty) {
        parts.add(
          'అందుబాటులో ఉంది: ' +
              product +
              (validPrice ? ' — ₹' + _money(price!) : ''),
        );
      }
      if (offerText.isNotEmpty) {
        parts.add('ఆఫర్: ' + offerText);
        parts.add('దుకాణాన్ని సందర్శించి ఆఫర్ కోడ్‌ను చెప్పండి: ' + offerCode);
      } else {
        parts.add('ఈరోజే మా దుకాణాన్ని సందర్శించండి.');
      }
      if (festivalName != null && festivalName.trim().isNotEmpty) {
        parts.add(festivalInvitation(festivalName, language));
      }
      return parts.join('\n');
    }

    if (language == 'hi') {
      final parts = <String>[
        shop + ' में आपका स्वागत है!',
        headline(goal, language) + '.',
      ];
      if (product.isNotEmpty) {
        parts.add(
          'उपलब्ध उत्पाद: ' +
              product +
              (validPrice ? ' — ₹' + _money(price!) : ''),
        );
      }
      if (offerText.isNotEmpty) {
        parts.add('ऑफ़र: ' + offerText);
        parts.add('दुकान पर आकर ऑफ़र कोड बताएँ: ' + offerCode);
      } else {
        parts.add('आज ही हमारी दुकान पर आएँ।');
      }
      if (festivalName != null && festivalName.trim().isNotEmpty) {
        parts.add(festivalInvitation(festivalName, language));
      }
      return parts.join('\n');
    }

    final parts = <String>[
      'Welcome to ' + shop + '!',
      headline(goal, language) + '.',
    ];
    if (product.isNotEmpty) {
      parts.add(
        'Available: ' + product + (validPrice ? ' — ₹' + _money(price!) : ''),
      );
    }
    if (offerText.isNotEmpty) {
      parts.add('Offer: ' + offerText);
      parts.add('Visit us and mention offer code: ' + offerCode + '.');
    } else {
      parts.add('Visit us today.');
    }
    if (festivalName != null && festivalName.trim().isNotEmpty) {
      parts.add(festivalInvitation(festivalName, language));
    }
    return parts.join('\n');
  }

  static String offerCode(DateTime now) {
    final suffix = now.microsecondsSinceEpoch.toString();
    final digits = suffix.length > 6
        ? suffix.substring(suffix.length - 6)
        : suffix.padLeft(6, '0');
    return 'RM' + digits;
  }

  static String _money(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
