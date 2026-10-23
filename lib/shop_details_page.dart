import 'package:flutter/material.dart';

import 'shop_profile_page.dart';

/// Compatibility entry point for callers that still refer to shop setup.
///
/// Setup and profile editing share one screen so their fields and save behavior
/// cannot drift apart.
class ShopDetailsPage extends StatelessWidget {
  const ShopDetailsPage({super.key});

  @override
  Widget build(BuildContext context) => const ShopProfilePage();
}
