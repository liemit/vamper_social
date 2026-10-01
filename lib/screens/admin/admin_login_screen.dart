import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.find<AuthController>();

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.login(
        email: _adminIdController.text.trim(),
        password: _passwordController.text,
      );
      // AuthController handles the redirection to /dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E), // Professional Dark Mode
      body: Center(
        child: SingleChildScrollView(
          child: FadeIn(
            duration: const Duration(milliseconds: 800),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    const Icon(Icons.admin_panel_settings, size: 64, color: AppColors.primary),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Admin Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Secure management system access',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 40),

                    CustomTextField(
                      label: 'Admin ID or Email',
                      hint: 'Enter credentials',
                      prefixIcon: Icons.badge_outlined,
                      controller: _adminIdController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    CustomTextField(
                      label: 'Password',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_open_rounded,
                      isPassword: true,
                      controller: _passwordController,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 32),

                    Obx(() => GradientButton(
                      text: 'Authorize Access',
                      onPressed: _handleLogin,
                      isLoading: _authController.isLoading.value,
                      width: double.infinity,
                    )),
                    
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Get.offAllNamed('/login'),
                      child: const Text('Back to Member Login', style: TextStyle(color: AppColors.textLight)),
                    ),
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
