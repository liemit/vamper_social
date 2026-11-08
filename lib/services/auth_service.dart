import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // Register
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.register,
        data: {
          'full_name': fullName,
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        await saveAuthData(
          response.data['data']['token'],
          response.data['data']['user'],
        );
        return response.data;
      } else {
        throw response.data['message'] ?? 'Registration failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.login,
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      if (response.data['success'] == true) {
        await saveAuthData(
          response.data['data']['token'],
          response.data['data']['user'],
        );
        return response.data;
      } else {
        throw response.data['message'] ?? 'Login failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Send OTP
  Future<Map<String, dynamic>> sendOtp({required String email}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.sendOtp,
        data: {'email': email.trim().toLowerCase()},
      );
      if (response.data['success'] == true) return response.data;
      throw response.data['message'] ?? 'Failed to send OTP';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) async {
    final response = await _apiService.post(
      ApiConstants.requestPasswordReset,
      data: {'email': email.trim().toLowerCase()},
    );
    if (response.data is Map && response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw response.data is Map
        ? response.data['message'] ?? 'Unable to send a reset code.'
        : 'Unable to send a reset code.';
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _apiService.post(
      ApiConstants.resetPassword,
      data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
    if (response.data is Map && response.data['success'] == true) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw response.data is Map
        ? response.data['message'] ?? 'Unable to reset the password.'
        : 'Unable to reset the password.';
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.verifyOtp,
        data: {'email': email, 'otp_code': otpCode},
      );
      if (response.data['success'] == true) {
        await saveAuthData(
          response.data['data']['token'],
          response.data['data']['user'],
        );
        return response.data;
      }
      throw response.data['message'] ?? 'Invalid OTP';
    } catch (e) {
      rethrow;
    }
  }

  // Get Any User Profile
  Future<Map<String, dynamic>> getUserProfile(
    String userId, {
    String? viewerId,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getProfile,
        params: {'user_id': userId, 'viewer_id': viewerId},
      );

      if (response.data['success'] == true) {
        return response.data;
      } else {
        throw response.data['message'] ?? 'Failed to load profile';
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update Profile
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? gender,
    String? dateOfBirth,
    String? bio,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.updateProfile,
        data: {
          'user_id': userId,
          'full_name': fullName,
          'phone': phone,
          'gender': gender,
          'date_of_birth': dateOfBirth,
          'bio': bio,
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.data['success'] == true) {
        return response.data;
      } else {
        throw response.data['message'] ?? 'Update failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.changePassword,
        data: {
          'user_id': userId,
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );

      if (response.data['success'] == true) {
        return response.data;
      }

      throw response.data['message'] ?? 'Password change failed';
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserSettings({
    required String userId,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.updateUserSettings,
        data: {
          'user_id': userId,
          'settings': settings,
        },
      );

      if (response.data['success'] == true) {
        return response.data;
      }

      throw response.data['message'] ?? 'Failed to save settings';
    } catch (e) {
      rethrow;
    }
  }

  // Upload Profile Photo
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required String userId,
    required String imagePath,
    required String fileName,
    required List<int> imageBytes,
  }) async {
    try {
      final formData = FormData.fromMap({
        'user_id': userId,
        'photo': MultipartFile.fromBytes(imageBytes, filename: fileName),
      });

      final response = await _apiService.post(
        ApiConstants.uploadProfilePhoto,
        data: formData,
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Upload User Photo (Multiple photos)
  Future<Map<String, dynamic>> uploadUserPhoto({
    required String userId,
    required List<int> imageBytes,
    required String fileName,
    bool isProfile = false,
    int sortOrder = 0,
  }) async {
    try {
      final formData = FormData.fromMap({
        'user_id': userId,
        'is_profile': isProfile ? 1 : 0,
        'sort_order': sortOrder,
        'photo': MultipartFile.fromBytes(imageBytes, filename: fileName),
      });

      final response = await _apiService.post(
        ApiConstants.uploadProfilePhoto,
        data: formData,
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Get User Photos
  Future<Map<String, dynamic>> getUserPhotos(String userId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getUserPhotos,
        params: {'user_id': userId},
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // --- Helper Methods ---

  Future<void> saveAuthData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.keyToken, token);
    await prefs.setString(ApiConstants.keyUserId, userData['id'].toString());
    await prefs.setString(ApiConstants.keyUserData, jsonEncode(userData));
    await prefs.setBool(ApiConstants.keyIsLoggedIn, true);
  }

  Future<void> updateStoredUserData(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString(ApiConstants.keyUserData);
    final userData = storedUser == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(storedUser) as Map);
    userData.addAll(user.toJson());
    await prefs.setString(ApiConstants.keyUserData, jsonEncode(userData));
  }

  Future<UserModel?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(ApiConstants.keyUserData);
    if (userData != null) return UserModel.fromJson(jsonDecode(userData));
    return null;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(ApiConstants.keyIsLoggedIn) ?? false;
  }

  Future<void> logout() async {
    try {
      await _apiService.post(ApiConstants.logout);
    } catch (error) {
      print('Unable to revoke API session during logout: $error');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.keyToken);
    await prefs.remove(ApiConstants.keyUserId);
    await prefs.remove(ApiConstants.keyUserData);
    await prefs.setBool(ApiConstants.keyIsLoggedIn, false);
  }

  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(ApiConstants.keyUserSettings);
    final decoded = current == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(current) as Map);

    decoded.addAll(settings);
    await prefs.setString(ApiConstants.keyUserSettings, jsonEncode(decoded));
  }

  Future<Map<String, dynamic>> getUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ApiConstants.keyUserSettings);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Future<void> clearUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.keyUserSettings);
  }
}
