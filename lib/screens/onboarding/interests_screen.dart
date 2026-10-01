import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../home/home_screen.dart';

class InterestsScreen extends StatelessWidget {
  final String userId;

  const InterestsScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Interests'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_outline,
                size: 100,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Your Interests',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose what you love to do',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              GradientButton(
                text: 'Complete Setup',
                onPressed: () {
                  Get.snackbar(
                    'Success',
                    'Profile setup complete!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.success,
                    colorText: Colors.white,
                  );
                  
                  // Navigate to Home Screen
                  // Use offAllNamed to clear the navigation stack
                  Get.offAll(() => const HomeScreen());
                },
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
