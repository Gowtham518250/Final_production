import 'live_translated_text.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_client.dart';
import 'app_localizations.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'otp_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 1; // 1: Email, 2: OTP, 3: New Password
  String _errorMessage = '';
  bool _otpVerified = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorMessage = AppLocalizations.of(context).enterEmail);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _otpVerified = false;
    });

    try {
      final result = await OTPService.sendPasswordResetOTP(email);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _currentStep = 2;
          _errorMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LiveTranslatedText('OTP sent to $email. Check your inbox and spam folder.'),
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              result['message']?.toString() ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await OTPService.verifyPasswordResetOTP(email, otp);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _otpVerified = result['success'] == true;
          _currentStep = _otpVerified ? 3 : 2;
          _errorMessage = _otpVerified ? '' : (result['message']?.toString() ?? 'OTP verification failed.');
        });
      } else {
        setState(() {
          _otpVerified = false;
          _errorMessage =
              result['message']?.toString() ?? 'OTP verification failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'OTP verification failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (!_otpVerified) {
      setState(() => _errorMessage =
          'Verify the OTP before resetting your password.');
      return;
    }

    if (pass.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(pass) ||
        !RegExp(r'[a-z]').hasMatch(pass) ||
        !RegExp(r'\d').hasMatch(pass)) {
      setState(() => _errorMessage =
          'Password must be at least 8 characters and contain uppercase, lowercase, and a number.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiClient.postJson(
        '/auth/verify-reset-otp',
        {
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
          'password': pass,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await OTPService.clearResetState();
        setState(() => _currentStep = 4);
      } else {
        Map<String, dynamic> data = {};
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {}
        setState(() => _errorMessage =
            data['detail']?.toString() ?? 'Reset failed. Please request a new code.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            AppLocalizations.of(context).connectionError);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBackToPreviousPage() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    // Also support opening this screen directly, without a login route below it.
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          onTap: _goBackToPreviousPage,
                          borderRadius: BorderRadius.circular(13),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.arrow_back_rounded,
                                color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ResetLanguageButton(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFE5EAF3)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF172554).withValues(alpha: 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_currentStep <= 3) ...[
                          _buildStepProgress(),
                          const SizedBox(height: 22),
                          const Divider(height: 1, color: Color(0xFFEFF2F7)),
                          const SizedBox(height: 22),
                        ],
                        _buildStageContent(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Never share your password or verification code.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 10,
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

  Widget _buildStageContent() {
    switch (_currentStep) {
      case 2:
        return _buildOtpState();
      case 3:
        return _buildNewPasswordState();
      case 4:
        return _buildSuccessState();
      case 1:
      default:
        return _buildEmailState();
    }
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF16A34A), size: 42),
        ),
        const SizedBox(height: 20),
        LiveTranslatedText(
          'Password reset complete',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF172554),
          ),
        ),
        const SizedBox(height: 10),
        LiveTranslatedText(
          'Your password has been updated. You can now sign in using your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _goBackToPreviousPage,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: LiveTranslatedText(
              AppLocalizations.of(context).login,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepProgress() {
    const labels = ['Email', 'Verify', 'New password'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: index + 1 <= _currentStep
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFFE2E8F0),
                  child: Text(
                    (index + 1).toString(),
                    style: GoogleFonts.poppins(
                      color: index + 1 <= _currentStep
                          ? Colors.white
                          : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  style: GoogleFonts.poppins(
                    color: index + 1 <= _currentStep
                        ? const Color(0xFF334155)
                        : const Color(0xFF94A3B8),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle, IconData icon) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, color: const Color(0xFF4F46E5), size: 32),
        ),
        const SizedBox(height: 18),
        LiveTranslatedText(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF172554),
          ),
        ),
        const SizedBox(height: 8),
        LiveTranslatedText(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF64748B),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildError() {
    if (_errorMessage.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: LiveTranslatedText(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: const Color(0xFFB91C1C),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailState() {
    return Column(
      children: [
        _buildHeader(
          AppLocalizations.of(context).forgotPassword,
          AppLocalizations.of(context).enterCredentials,
          Icons.lock_reset_rounded,
        ),
        _buildError(),
        _buildInputField(
          controller: _emailController,
          hint: AppLocalizations.of(context).enterEmail,
          icon: Icons.email_outlined,
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 28),
        _buildSubmitButton(
          label: 'SEND CODE',
          onTap: _sendResetEmail,
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: _goBackToPreviousPage,
          child: LiveTranslatedText(
            AppLocalizations.of(context).signIn,
            style: GoogleFonts.poppins(
              color: const Color(0xFF818CF8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpState() {
    return Column(
      children: [
        _buildHeader(
          'Verify Email',
          'Enter the 6-digit code sent to\n${_emailController.text}',
          Icons.mark_email_unread_rounded,
        ),

        _buildError(),
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LiveTranslatedText(
                  'Open the secure confirmation link in the same email first. Then enter the 6-digit OTP here. Both checks are required before a password-reset token is issued.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF475569),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildInputField(
          controller: _otpController,
          hint: 'Enter 6-digit OTP',
          icon: Icons.pin_rounded,
          type: TextInputType.number,
        ),
        const SizedBox(height: 28),
        _buildSubmitButton(
          label: 'VERIFY CODE',
          onTap: _verifyOtp,
        ),
        const SizedBox(height: 22),
        TextButton(
          onPressed: () => setState(() => _currentStep = 1),
          child: LiveTranslatedText(
            'Change Email',
            style: GoogleFonts.poppins(
              color: const Color(0xFF818CF8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordState() {
    return Column(
      children: [
        _buildHeader(
          'New Password',
          'Use 8+ characters with uppercase, lowercase, and a number',
          Icons.vpn_key_rounded,
        ),
        _buildError(),
        _buildInputField(
          controller: _passwordController,
          hint: 'New Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          icon: Icons.lock_clock_outlined,
          isPassword: true,
        ),
        const SizedBox(height: 28),
        _buildSubmitButton(
          label: 'RESET PASSWORD',
          onTap: _resetPassword,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: isPassword,
      style: GoogleFonts.poppins(
        color: const Color(0xFF172554),
        fontSize: 13,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF94A3B8),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isLoading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          disabledBackgroundColor: const Color(0xFFA5B4FC),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : LiveTranslatedText(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
      ),
    );
  }
}

class _ResetLanguageButton extends StatelessWidget {
  const _ResetLanguageButton();

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentCode = languageProvider.locale.languageCode;

    return PopupMenuButton<String>(
      tooltip: 'Choose language',
      color: Colors.white,
      elevation: 8,
      onSelected: (code) => languageProvider.setLanguage(code),
      itemBuilder: (context) => LanguageProvider.languages
          .map(
            (lang) => PopupMenuItem<String>(
              value: lang['code']!,
              child: Row(
                children: [
                  Text(lang['nativeName']!,
                      style: const TextStyle(color: Color(0xFF172554))),
                  const SizedBox(width: 8),
                  Text(lang['name']!,
                      style: const TextStyle(color: Color(0xFF64748B))),
                  const Spacer(),
                  if (lang['code'] == currentCode)
                    const Icon(Icons.check, size: 16, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded,
                size: 17, color: Color(0xFF4F46E5)),
            const SizedBox(width: 6),
            LiveTranslatedText(
              AppLocalizations.of(context).language,
              style: GoogleFonts.poppins(
                color: const Color(0xFF334155),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
