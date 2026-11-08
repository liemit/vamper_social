import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!GetUtils.isEmail(email)) {
      Get.snackbar('Invalid email', 'Enter the email address for your account.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      Get.snackbar(
        'Check your email',
        response['message']?.toString() ??
            'If an active account uses that email, a reset code will be sent shortly.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Could not send code',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      Get.snackbar('Invalid code', 'Enter the 6-digit code from your email.');
      return;
    }
    if (password.length < 6) {
      Get.snackbar('Password too short', 'Use at least 6 characters.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      Get.snackbar('Passwords do not match', 'Check the new password fields.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: password,
      );
      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'Password changed',
        response['message']?.toString() ?? 'Sign in with your new password.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        'Could not reset password',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reset password'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _codeSent ? 'Choose a new password' : 'Forgot your password?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? 'Enter the 6-digit code sent to your email. It expires in 10 minutes.'
                          : 'Enter your account email and we will send a reset code if it is registered.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      readOnly: _codeSent,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '6-digit reset code',
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmation,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirmation =
                                  !_obscureConfirmation,
                            ),
                            icon: Icon(
                              _obscureConfirmation
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_codeSent ? _resetPassword : _requestCode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_codeSent ? 'Reset password' : 'Send reset code'),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _requestCode,
                        child: const Text('Resend code'),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _codeSent = false;
                                  _codeController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                }),
                        child: const Text('Change email address'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
