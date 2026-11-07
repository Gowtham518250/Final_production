class AppEndpoints {
  AppEndpoints._();

  static const String _defaultApiBaseUrl =
      'https://retail-mind-hpx3.onrender.com';
  static const String _defaultCustomerApiBaseUrl =
      'https://retail-mind-vkbp.onrender.com/api';
  static const String _defaultCustomerWebSocketBaseUrl =
      'wss://retail-mind-vkbp.onrender.com/ws';
  static const String _defaultCustomerStoreBaseUrl =
      'https://retail-mind-1.onrender.com';
  static const String _defaultShopWebBaseUrl =
      'https://retail-mind-web.onrender.com';

  static String get apiBaseUrl => normalizeBaseUrl(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultApiBaseUrl,
    ),
  );

  static String get customerApiBaseUrl => normalizeBaseUrl(
    const String.fromEnvironment(
      'CUSTOMER_API_BASE_URL',
      defaultValue: _defaultCustomerApiBaseUrl,
    ),
  );

  static String get customerWebSocketBaseUrl => normalizeBaseUrl(
    const String.fromEnvironment(
      'CUSTOMER_WS_BASE_URL',
      defaultValue: _defaultCustomerWebSocketBaseUrl,
    ),
  );

  static String get customerStoreBaseUrl => normalizeBaseUrl(
    const String.fromEnvironment(
      'CUSTOMER_STORE_BASE_URL',
      defaultValue: _defaultCustomerStoreBaseUrl,
    ),
  );

  static String customerShopUrl(int shopId) {
    if (shopId <= 0) {
      throw ArgumentError.value(shopId, 'shopId', 'Must be a positive ID.');
    }
    return '$customerStoreBaseUrl/shop/$shopId';
  }

  static String get shopWebBaseUrl => normalizeBaseUrl(
    const String.fromEnvironment(
      'SHOP_WEB_BASE_URL',
      defaultValue: _defaultShopWebBaseUrl,
    ),
  );

  static String? get printerOrderWhatsapp {
    const configured = String.fromEnvironment('PRINTER_ORDER_WHATSAPP');
    final digits = configured.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits.length <= 15 ? digits : null;
  }

  static String get deliveryTrackingWebSocketUrl =>
      '$customerWebSocketBaseUrl/delivery/track';

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://') &&
        !normalized.startsWith('ws://') &&
        !normalized.startsWith('wss://')) {
      normalized = 'https://$normalized';
    }
    return normalized;
  }
}
