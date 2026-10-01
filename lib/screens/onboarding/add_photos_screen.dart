import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../widgets/gradient_button.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import 'interests_screen.dart';

class AddPhotosScreen extends StatefulWidget {
  final String userId;

  const AddPhotosScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AddPhotosScreen> createState() => _AddPhotosScreenState();
}

class _AddPhotosScreenState extends State<AddPhotosScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Fetch existing photos when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController.fetchUserPhotos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress indicator
              Row(
                children: [
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 32),

              FadeInDown(child: const Text('Add your photos', style: AppTextStyles.h2)),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 100),
                child: Text('Add at least 2 photos to stand out from the crowd!', style: AppTextStyles.body2),
              ),
              const SizedBox(height: 32),

              // Photos Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return _PhotoSlot(index: index);
                },
              ),

              const SizedBox(height: 48),

              // Continue Button
              Obx(() {
                final photoCount = _authController.userPhotos.length;
                return FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: GradientButton(
                    text: 'Continue',
                    onPressed: photoCount >= 2 
                        ? () => Get.to(() => InterestsScreen(userId: widget.userId))
                        : null,
                    isLoading: _authController.isLoading.value,
                    width: double.infinity,
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Skip Button
              Center(
                child: TextButton(
                  onPressed: () => Get.to(() => InterestsScreen(userId: widget.userId)),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final int index;

  const _PhotoSlot({required this.index});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Obx(() {
      // Find photo matching this slot index
      final photo = authController.userPhotos.firstWhereOrNull(
        (p) => p['sort_order'].toString() == index.toString()
      );
      final isUploading = authController.isLoading.value;

      return GestureDetector(
        onTap: isUploading ? null : () => authController.uploadOnboardingPhoto(index),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.border.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            image: photo != null
                ? DecorationImage(
                    image: NetworkImage('${ApiConstants.baseUrl.replaceAll('/api', '')}/${photo['url']}'),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photo == null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                )
              : null,
        ),
      );
    });
  }
}
