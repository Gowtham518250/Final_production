import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_endpoints.dart';
import 'live_translated_text.dart';
import 'widgets/shop_logo_mark.dart';

class OnlineStoreQrPage extends StatelessWidget {
  const OnlineStoreQrPage({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.logoBytes,
    required this.onPrint,
    required this.onCopyLink,
  });

  final int shopId;
  final String shopName;
  final Uint8List? logoBytes;
  final VoidCallback onPrint;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    final shopUrl = AppEndpoints.customerShopUrl(shopId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      appBar: AppBar(title: const LiveTranslatedText('Shop QR code')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShopLogoMark(
                    imageBytes: logoBytes,
                    size: 72,
                    fallbackColor: const Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    shopName.trim().isEmpty ? 'Your shop' : shopName.trim(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: foreground,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LiveTranslatedText(
                    'Customers can scan this code to open your online store.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: shopUrl,
                      size: 240,
                      version: QrVersions.auto,
                      gapless: false,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    shopUrl,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: isDark
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFF166534),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCopyLink,
                          icon: const Icon(Icons.copy_rounded),
                          label: const LiveTranslatedText('Copy link'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onPrint,
                          icon: const Icon(Icons.print_rounded),
                          label: const LiveTranslatedText('Print QR'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF15803D),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
