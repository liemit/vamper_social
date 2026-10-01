import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../app/theme/app_colors.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../screens/home/home_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final ApiService apiService = ApiService(); // Changed from private _apiService

  // Observable variables
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString debugOtpCode = ''.obs;
  final RxList<Map<String, dynamic>> userPhotos = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    print('🔄 AuthController onInit starting...');
    super.onInit();
    checkLoginStatus();
    print('🔄 AuthController onInit finished');
  }

  // Check if user is logged in
  Future<void> checkLoginStatus() async {
    try {
      print('🔍 Checking login status...');
      isLoggedIn.value = await _authService.isLoggedIn();
      print('🔐 Logged in: ${isLoggedIn.value}');
      if (isLoggedIn.value) {
        currentUser.value = await _authService.getUserData();
        print('👤 User: ${currentUser.value?.fullName}');
      }
    } catch (e) {
      print('🚨 Error in checkLoginStatus: $e');
    }
  }

  // Register
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _authService.register(
        fullName: fullName,
        email: email,
        password: password,
      );

      if (response['success'] == true) {
        currentUser.value = UserModel.fromJson(response['data']['user']);
        isLoggedIn.value = true;
        
        // Lưu debug OTP code (dev mode only - backend trả response.data.debug.otp_code)
        if (response['data'] != null && 
            response['data']['debug'] != null && 
            response['data']['debug']['otp_code'] != null) {
          debugOtpCode.value = response['data']['debug']['otp_code'].toString();
        }
        
        Get.snackbar(
          'Success',
          response['message'] ?? 'Registration successful!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        
        return true;
      } else {
        errorMessage.value = response['message'] ?? 'Registration failed';
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _authService.login(
        email: email,
        password: password,
      );

      if (response['success'] == true) {
        final userData = UserModel.fromJson(response['data']['user']);
        
        // 🛡️ ROLE-BASED HANDOVER LOGIC
        if (userData.role == 'admin') {
          if (kIsWeb) {
            // Business as usual on Web
            currentUser.value = userData;
            isLoggedIn.value = true;
            Get.offAllNamed('/dashboard');
          } else {
            // 📲 HANDOVER ON MOBILE: Force open system browser
            isLoading.value = false; // Stop loading spinner
            
            final Uri adminUrl = Uri.parse(ApiConstants.webAdminUrl);
            if (await canLaunchUrl(adminUrl)) {
              await launchUrl(adminUrl, mode: LaunchMode.externalApplication);
              
              Get.snackbar(
                'Admin Detected',
                'Redirecting you to the Secure Web Portal...',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.blue,
                colorText: Colors.white,
                duration: const Duration(seconds: 5),
              );
            } else {
              Get.snackbar('Error', 'Could not open browser. Please visit the portal URL manually.');
            }
            return false; // Prevent login on mobile app
          }
        } else {
          // Normal User Login
          currentUser.value = userData;
          isLoggedIn.value = true;
          Get.offAllNamed('/home');
        }

        Get.snackbar(
          'Success',
          response['message'] ?? 'Login successful!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        
        return true;
      } else {
        errorMessage.value = response['message'] ?? 'Login failed';
        Get.snackbar(
          'Error',
          errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Update Profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? bio,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    if (currentUser.value == null) return false;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _authService.updateProfile(
        userId: currentUser.value!.id,
        fullName: fullName,
        phone: phone,
        gender: gender,
        dateOfBirth: dateOfBirth,
        bio: bio,
        location: location,
        latitude: latitude,
        longitude: longitude,
      );

      if (response['success'] == true) {
        // Update local user observable
        currentUser.value = UserModel.fromJson(response['data']['user']);
        
        Get.snackbar(
          'Success',
          'Profile updated successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        return true;
      } else {
        throw response['message'] ?? 'Update failed';
      }
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Recharge Coins
  Future<bool> rechargeCoins(int coinsToAdd) async {
    final user = currentUser.value;
    if (user == null) return false;

    try {
      isLoading.value = true;
      final response = await apiService.post(
        '${ApiConstants.baseUrl}/recharge-coins.php',
        data: {
          'user_id': user.id,
          'coins': coinsToAdd,
        },
      );

      if (response.data['success'] == true) {
        currentUser.value = UserModel.fromJson(response.data['data']['user']);
        Get.snackbar(
          'Recharge Successful! 🎉',
          response.data['message'] ?? 'Coins added successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Error recharging coins: $e');
      Get.snackbar(
        'Error',
        'Failed to recharge coins. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Pick and Upload Photo
  Future<bool> pickAndUploadPhoto() async {
    if (currentUser.value == null) return false;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return false;

      isLoading.value = true;
      errorMessage.value = '';

      final bytes = await image.readAsBytes();
      
      final response = await _authService.uploadProfilePhoto(
        userId: currentUser.value!.id,
        imagePath: image.path,
        fileName: image.name,
        imageBytes: bytes.toList(),
      );

      if (response['success'] == true) {
        // Update local user observable
        currentUser.value = UserModel.fromJson(response['data']['user']);
        
        Get.snackbar(
          'Success',
          'Profile photo updated!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        return true;
      } else {
        throw response['message'] ?? 'Upload failed';
      }
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Error',
        errorMessage.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Upload Photo for Onboarding Grid
  Future<bool> uploadOnboardingPhoto(int index) async {
    if (currentUser.value == null) return false;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return false;

      isLoading.value = true;
      
      final bytes = await image.readAsBytes();
      
      final response = await _authService.uploadUserPhoto(
        userId: currentUser.value!.id,
        imageBytes: bytes.toList(),
        fileName: image.name,
        isProfile: index == 0, // First photo is profile by default
        sortOrder: index,
      );

      if (response['success'] == true) {
        // Add to local list or update if exists
        final newPhoto = response['data'];
        
        // Remove existing photo at this index if any
        userPhotos.removeWhere((p) => p['sort_order'] == index);
        userPhotos.add(newPhoto);
        userPhotos.sort((a, b) => a['sort_order'].compareTo(b['sort_order']));

        // If it was the first photo, update profile_photo in currentUser
        if (index == 0) {
          currentUser.value = UserModel.fromJson({
            ...currentUser.value!.toJson(),
            'profile_photo': newPhoto['url'],
          });
        }
        
        return true;
      } else {
        throw response['message'] ?? 'Upload failed';
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Follow/Unfollow Logic
  Future<bool> toggleFollow(String targetUserId) async {
    final currentUserId = currentUser.value?.id;
    if (currentUserId == null) return false;

    try {
      final response = await apiService.post(
        '${ApiConstants.baseUrl}/toggle-follow.php',
        data: {
          'follower_id': currentUserId,
          'followed_id': targetUserId,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      print('Error toggling follow: $e');
      return false;
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = currentUser.value?.id;
    if (currentUserId == null) return false;

    try {
      final response = await apiService.get(
        '${ApiConstants.baseUrl}/check-follow.php',
        params: {
          'follower_id': currentUserId,
          'followed_id': targetUserId,
        },
      );
      return response.data['is_following'] == true;
    } catch (e) {
      return false;
    }
  }

  // Fetch Public Profile of any user
  Future<UserModel?> fetchUserProfile(String userId) async {
    try {
      final response = await _authService.getUserProfile(userId);
      if (response['success'] == true) {
        return UserModel.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  // Fetch Photos for a specific user and return them
  Future<List<Map<String, dynamic>>> getOtherUserPhotos(String userId) async {
    try {
      final response = await _authService.getUserPhotos(userId);
      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        return data.map((p) => {
          'id': p['id'],
          'url': p['photo_url'],
          'is_profile': int.tryParse(p['is_profile'].toString()) ?? 0,
          'sort_order': int.tryParse(p['sort_order'].toString()) ?? 0,
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching other user photos: $e');
      return [];
    }
  }

  // Fetch User Photos from Server
  Future<void> fetchUserPhotos() async {
    if (currentUser.value == null) return;

    try {
      final response = await _authService.getUserPhotos(currentUser.value!.id);
      if (response['success'] == true) {
        final List<dynamic> photosData = response['data'];
        userPhotos.assignAll(photosData.map((p) => {
          'id': p['id'],
          'url': p['photo_url'],
          'is_profile': int.tryParse(p['is_profile'].toString()) ?? 0,
          'sort_order': int.tryParse(p['sort_order'].toString()) ?? 0,
        }).toList());
      }
    } catch (e) {
      // Silently fail or log for dev
    }
  }

  // Robust Image URL Helper
  String? getFullImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    
    // Normalize path
    String cleanPath = relativePath.replaceAll('\\', '/').trim();
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    
    // In Laravel, images in 'public/uploads' are served directly
    // Base URL: http://localhost/vamper_api/public/api
    // We want: http://localhost/vamper_api/public/uploads/...
    String base = ApiConstants.baseUrl.replaceAll('/api', ''); 
    if (!base.endsWith('/')) base = '$base/';
    
    final fullUrl = '$base$cleanPath';
    print('🖼️ Laravel Direct Image URL: $fullUrl');
    return fullUrl;
  }

  // Fullscreen Image Viewer
  void showImageDetail(String imageUrl) {
    Get.dialog(
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.broken_image, color: Colors.white, size: 100),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      useSafeArea: false,
    );
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    currentUser.value = null;
    isLoggedIn.value = false;
    Get.snackbar(
      'Success',
      'Logged out successfully',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success,
      colorText: Colors.white,
    );
  }
}
