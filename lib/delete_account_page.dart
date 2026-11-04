import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_localizations.dart';
import 'api_client.dart';
import 'session_logout_service.dart';

/// Account Deletion Page - Complies with Play Store and GDPR requirements
/// Users can request permanent account deletion from within the app
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isDeleting = false;
  bool _acceptedTerms = false;
  late TextEditingController _confirmController;

  @override
  void initState() {
    super.initState();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  String _normalizeConfirmation(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _matchesConfirmation(String expectedPhrase) =>
      _normalizeConfirmation(_confirmController.text) ==
      _normalizeConfirmation(expectedPhrase);

  Future<void> _deleteAccount() async {
    final localizations = AppLocalizations.of(context);
    final confirmationPhrase = localizations.translate('PERMANENT DELETE');
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LiveTranslatedText(
            'Please confirm that you understand the consequences',
          ),
        ),
      );
      return;
    }

    if (!_matchesConfirmation(confirmationPhrase)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LiveTranslatedText('Confirmation phrase does not match'),
        ),
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      // Do not wipe local data unless the server confirms the account deletion.
      final response = await ApiClient.deleteJson('/api/auth/account');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Account deletion failed with HTTP ${response.statusCode}.',
        );
      }

      // Full local wipe (tokens, prefs, queues)
      await SessionLogoutService.performFullLogout(notifyServer: false);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText(
              'Account deleted successfully. All data has been cleared.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LiveTranslatedText(
              'Could not delete the account. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmationPhrase = AppLocalizations.of(
      context,
    ).translate('PERMANENT DELETE');
    final confirmationMatches = _matchesConfirmation(confirmationPhrase);
    return Scaffold(
      appBar: AppBar(
        title: const LiveTranslatedText('Delete Account'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning heading
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: Colors.red.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiveTranslatedText(
                      'This action cannot be undone',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Explanation
            LiveTranslatedText(
              'When you delete your account:',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(
              'Your account and all associated data will be permanently deleted from our servers',
            ),
            _buildBulletPoint(
              'All sales records, customer data, and inventory information will be removed',
            ),
            _buildBulletPoint(
              'Your authentication credentials will be revoked',
            ),
            _buildBulletPoint('This cannot be reversed or recovered'),

            const SizedBox(height: 24),

            // Confirmation checkbox
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              title: LiveTranslatedText(
                'I understand and accept the permanent deletion of all my data',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 20),

            // Text confirmation
            LiveTranslatedText(
              'Type this phrase exactly to confirm:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            LiveTranslatedText(
              confirmationPhrase,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hint: const LiveTranslatedText('Type the confirmation phrase'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isDeleting || !_acceptedTerms || !confirmationMatches
                    ? null
                    : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : LiveTranslatedText(
                        'Delete Account Permanently',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: LiveTranslatedText(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiveTranslatedText(
            '• ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: LiveTranslatedText(
              text,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
