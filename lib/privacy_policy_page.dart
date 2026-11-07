import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const publicUrl =
      'https://retail-mind-web.onrender.com/privacy.html';

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
              'Who we are',
              'Retail Mind is a point-of-sale app for shop owners (Android package com.retailmind.app). '
                  'This policy covers the mobile app and the Retail Mind cloud services used to sync shop data.',
            ),
            _section(
              'Why we read your SMS',
              'SMS permission can expose SMS message content to Retail Mind. The app '
                  'uses SMS access only to look for incoming payment-related messages from '
                  'supported banks and payment services. Inbox threads are not displayed. '
                  'While filtering, the app may briefly encounter messages unrelated '
                  'to payments; those are discarded and are not stored as shop records. '
                  'Relevant detected transaction details may be '
                  'saved in payment history. Do not enable SMS access unless you are comfortable with it. '
                  'Manual billing remains available without SMS access.',
            ),
            _section(
              'Why we use Notification Access',
              'Android notification access can expose notification text and metadata from '
                  'apps on this device while the permission is enabled. The listener '
                  'looks for supported payment alerts. Unrelated notifications may be seen '
                  'before they are filtered out. Relevant detected transaction '
                  'details may be saved in Online Payment History. A notification '
                  'does not prove settlement; verify incoming credits before treating '
                  'them as paid.',
            ),
            _section(
              'Why we use Accessibility Service',
              'Accessibility is limited to reading on-screen text from bank and UPI apps '
                  'so a payment confirmation can be matched to a bill. Retail Mind does not '
                  'tap, swipe, type, or control other apps. The service does not request '
                  'gesture control. Enable it only if you accept this access; manual billing remains available.',
            ),
            _section(
              'Data we process',
              'Shop catalog, sales, inventory, staff attendance, and account details you enter. '
                  'Optional payment-alert fields (amount, reference, source app or SMS sender). '
                  'Device identifiers used to keep your session signed in. '
                  'Firebase may process crash, auth, and messaging data for the Android app.',
            ),
            _section(
              'Retention',
              'Business records stay until you delete them or delete the account. '
                  'Non-payment SMS and notifications are not kept as shop records. '
                  'Session tokens expire and can be revoked by signing out.',
            ),
            _section(
              'Your data rights',
              'You can export all your data anytime from '
                  'Settings → Export Data. You can delete your '
                  'account and all data from Settings → '
                  'Delete Account. Under applicable Indian data-protection law you may also request access or erasure through the listing support contact.',
            ),
            _section(
              'Public copy',
              'A hosted copy of this policy for the Play Store listing is at $publicUrl',
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
