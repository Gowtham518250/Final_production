/// Free, deterministic campaign copy for the first RetailMind Growth Agent MVP.
///
/// This intentionally uses local templates, not a paid AI API. It never invents
/// a discount: an offer appears only when the owner explicitly enters one.
class GrowthAdCopy {
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
        parts.add('అందుబాటులో ఉంది: ' + product +
            (validPrice ? ' — ₹' + _money(price!) : ''));
      }
      if (offerText.isNotEmpty) parts.add('ఆఫర్: ' + offerText);
      parts.add('దుకాణాన్ని సందర్శించండి. ఆఫర్ కోడ్: ' + offerCode);
      return parts.join('\n');
    }

    if (language == 'hi') {
      final parts = <String>[
        shop + ' में आपका स्वागत है!',
        headline(goal, language) + '.',
      ];
      if (product.isNotEmpty) {
        parts.add('उपलब्ध उत्पाद: ' + product +
            (validPrice ? ' — ₹' + _money(price!) : ''));
      }
      if (offerText.isNotEmpty) parts.add('ऑफ़र: ' + offerText);
      parts.add('आज दुकान पर आएँ। ऑफ़र कोड: ' + offerCode);
      return parts.join('\n');
    }

    final parts = <String>[
      'Welcome to ' + shop + '!',
      headline(goal, language) + '.',
    ];
    if (product.isNotEmpty) {
      parts.add('Available: ' + product +
          (validPrice ? ' — ₹' + _money(price!) : ''));
    }
    if (offerText.isNotEmpty) parts.add('Offer: ' + offerText);
    parts.add('Visit us today. Offer code: ' + offerCode);
    return parts.join('\n');
  }

  static String offerCode(DateTime now) {
    final suffix = now.microsecondsSinceEpoch.toString();
    final digits = suffix.length > 6
        ? suffix.substring(suffix.length - 6)
        : suffix.padLeft(6, '0');
    return 'RM' + digits;
  }

  static String _money(double value) =>
      value == value.truncateToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);
}
