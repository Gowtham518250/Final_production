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
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

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
    final topInset = MediaQuery.of(context).padding.top;
    const headerHeight = 235.0;
    const overlap = 36.0;

    return Scaffold(
      backgroundColor: const Color(0xFFE9EFFA),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + headerHeight + overlap,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2447),
                    Color(0xFF1B3A6B),
                    Color(0xFF0A1628),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: _goBackToPreviousPage,
                              borderRadius: BorderRadius.circular(999),
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const _ResetLanguageButton(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBrandHeader(),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F2447).withValues(alpha: 0.14),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_currentStep <= 3) ...[
                              _buildStepProgress(),
                              const SizedBox(height: 18),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE6EAF5),
                              ),
                              const SizedBox(height: 20),
                            ],
                            _buildStageContent(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 78,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Image.asset(
                              'assets/shop_bottom_left.png',
                              width: 124,
                              height: 74,
                              cacheWidth: 380,
                              cacheHeight: 230,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomLeft,
                              excludeFromSemantics: true,
                            ),
                            Image.asset(
                              'assets/bag_bottom_right.png',
                              width: 76,
                              height: 78,
                              cacheWidth: 230,
                              cacheHeight: 240,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomRight,
                              excludeFromSemantics: true,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 15,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Your account recovery is protected and secure.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    final localizations = AppLocalizations.of(context);
    return SizedBox(
      height: 185,
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 8,
            right: 118,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      'assets/shop_logo.png',
                      cacheWidth: 160,
                      cacheHeight: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.35,
                    ),
                    children: const [
                      TextSpan(
                        text: 'RETAIL ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'MIND',
                        style: TextStyle(color: Color(0xFF2DD4BF)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                LiveTranslatedText(
                  'Smart Analytics & Billing Platform',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: Colors.white.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 11),
                LiveTranslatedText(
                  'Recover your account securely',
                  style: GoogleFonts.dancingScript(
                    fontSize: 18,
                    height: 1.12,
                    color: Colors.white.withValues(alpha: 0.94),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 86,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: 122,
              height: 158,
              child: Image.asset(
                'assets/shop_keeper.png',
                cacheWidth: 340,
                cacheHeight: 440,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                errorBuilder: (_, __, ___) => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: Colors.white70,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F2447),
          ),
        ),
        const SizedBox(height: 10),
        LiveTranslatedText(
          'Your password has been updated. You can now sign in using your new password.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
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
              backgroundColor: const Color(0xFF1E3A6E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: LiveTranslatedText(
              AppLocalizations.of(context).login,
              style: GoogleFonts.inter(
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
                      ? const Color(0xFF1E3A6E)
                      : const Color(0xFFE6EAF5),
                  child: Text(
                    (index + 1).toString(),
                    style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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
          style: GoogleFonts.inter(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F2447),
          ),
        ),
        const SizedBox(height: 8),
        LiveTranslatedText(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
              color: const Color(0xFF4F46E5),
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
                  style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
              color: const Color(0xFF4F46E5),
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
          passwordVisible: _passwordVisible,
          onTogglePasswordVisibility: () => setState(
            () => _passwordVisible = !_passwordVisible,
          ),
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _confirmPasswordController,
          hint: 'Confirm Password',
          icon: Icons.lock_clock_outlined,
          isPassword: true,
          passwordVisible: _confirmPasswordVisible,
          onTogglePasswordVisibility: () => setState(
            () => _confirmPasswordVisible = !_confirmPasswordVisible,
          ),
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
    bool passwordVisible = false,
    VoidCallback? onTogglePasswordVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF5)),
      ),
      child: TextField(
        controller: controller,
        enabled: !_isLoading,
        keyboardType: type,
        obscureText: isPassword && !passwordVisible,
        style: GoogleFonts.inter(
          color: const Color(0xFF0F172A),
          fontSize: 14.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFF94A3B8),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF64748B),
            size: 21,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  tooltip: passwordVisible ? 'Hide password' : 'Show password',
                  onPressed: _isLoading ? null : onTogglePasswordVisibility,
                  icon: Icon(
                    passwordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                )
              : null,
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
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A6E),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF7890B8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LiveTranslatedText(
                    label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 19),
                ],
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
    final current = LanguageProvider.languages.firstWhere(
      (language) => language['code'] == currentCode,
      orElse: () => LanguageProvider.languages.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EAF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2447).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Choose language',
        color: Colors.white,
        elevation: 8,
        onSelected: (code) => languageProvider.setLanguage(code),
        itemBuilder: (context) => LanguageProvider.languages
            .map(
              (language) => PopupMenuItem<String>(
                value: language['code']!,
                child: Row(
                  children: [
                    LiveTranslatedText(
                      language['nativeName']!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      language['name']!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (language['code'] == currentCode)
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                size: 19,
                color: Color(0xFF0F2447),
              ),
              const SizedBox(width: 7),
              LiveTranslatedText(
                AppLocalizations.of(context).language,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0F2447),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              LiveTranslatedText(
                current['nativeName']!,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 19,
                color: Color(0xFF0F2447),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
