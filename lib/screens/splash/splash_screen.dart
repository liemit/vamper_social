import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../widgets/vamper_logo.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Minimum wait time for splash to show logo (2.5 seconds)
    final delay = Future.delayed(const Duration(milliseconds: 2500));
    
    // Check login status (already happens in AuthController init, but we wait for it)
    await _authController.checkLoginStatus();
    
    // Wait for the minimum delay if needed
    await delay;

    if (!mounted) return;

    if (_authController.isLoggedIn.value) {
      final user = _authController.currentUser.value;
      if (user?.role == 'admin') {
        // Even if auto-logged in as admin on mobile, we should ideally redirect.
        // But for consistency with login flow:
        if (kIsWeb) {
          Get.offAllNamed('/dashboard');
        } else {
          Get.offAllNamed('/login'); // Force re-login to trigger handover
        }
      } else {
        Get.offAllNamed('/home');
      }
    } else {
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
        ),
        child: const Center(
          child: VamperLogoLarge(),
        ),
      ),
    );
  }
}