import '../../live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_endpoints.dart';

class PrinterMonetizationBanner extends StatelessWidget {
  const PrinterMonetizationBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final orderPhone = AppEndpoints.printerOrderWhatsapp;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.print_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveTranslatedText(
                  '🖨️ Bluetooth Printer — ₹1,999',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                LiveTranslatedText(
                  orderPhone == null
                      ? 'Print bills instantly with a Bluetooth printer.'
                      : 'Print bills instantly. WhatsApp us to order!',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          if (orderPhone != null)
            GestureDetector(
              onTap: () async {
                const msg =
                    'Hi! I want to order the Bluetooth Printer for ₹1,999 from Retail Mind.';
                final uri = Uri.https('wa.me', '/$orderPhone', {'text': msg});
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LiveTranslatedText(
                  'Order',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
