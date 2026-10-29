import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LiveTranslatedText(
          'Privacy Policy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              'Why we read your SMS',
              'SMS permission can expose SMS message content to Retail Mind. The app '
                  'uses SMS access to look for payment-related messages from '
                  'supported banks and payment services. While processing SMS '
                  'for this purpose, the app may encounter messages unrelated '
                  'to payments. Relevant detected transaction details may be '
                  'saved in payment history and handled by related app features. '
                  'Do not enable SMS access unless you are comfortable with it.',
            ),
            _section(
              'Why we use Notification Access',
              'Android notification access can expose notification text and metadata from '
                  'apps on this device while the permission is enabled. The listener '
                  'may receive unrelated notifications before Retail Mind filters '
                  'them for supported payment alerts, so it can encounter sensitive '
                  'content unrelated to payments. Relevant detected transaction '
                  'details may be saved in Online Payment History and handled by '
                  'related app features according to their settings. A notification '
                  'does not prove settlement; verify incoming credits before treating '
                  'them as paid. Enable this access only if you agree to this use.',
            ),
            _section(
              'Why we use Accessibility Service',
              'Accessibility access can expose text and interface information from other '
                  'apps while enabled. Retail Mind uses this service as an additional '
                  'payment-detection path. It may encounter sensitive information '
                  'outside payment alerts. Enable it only if you understand and '
                  'accept this access; manual billing remains available.',
            ),
            _section(
              'Your data rights',
              'You can export all your data anytime from '
                  'Settings → Export Data. You can delete your '
                  'account and all data from Settings → '
                  'Delete Account.',
            ),
            _section(
              'Contact',
              'For privacy questions, use the current support contact published '
                  'on the official Retail Mind app listing.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveTranslatedText(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          LiveTranslatedText(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.7,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
