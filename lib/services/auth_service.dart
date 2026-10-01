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
        await _saveAuthData(
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
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        await _saveAuthData(
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

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp({required String email, required String otpCode}) async {
    try {
      final response = await _apiService.post(
        ApiConstants.verifyOtp,
        data: {'email': email, 'otp_code': otpCode},
      );
      if (response.data['success'] == true) {
        await _saveAuthData(response.data['data']['token'], response.data['data']['user']);
        return response.data;
      }
      throw response.data['message'] ?? 'Invalid OTP';
    } catch (e) {
      rethrow;
    }
  }

  // Get Any User Profile
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _apiService.get(
        ApiConstants.getProfile,
        params: {'user_id': userId},
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
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
          if (gender != null) 'gender': gender,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
          if (bio != null) 'bio': bio,
          if (location != null) 'location': location,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
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

  Future<void> _saveAuthData(String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConstants.keyToken, token);
    await prefs.setString(ApiConstants.keyUserId, userData['id'].toString());
    await prefs.setString(ApiConstants.keyUserData, jsonEncode(userData));
    await prefs.setBool(ApiConstants.keyIsLoggedIn, true);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConstants.keyToken);
    await prefs.remove(ApiConstants.keyUserId);
    await prefs.remove(ApiConstants.keyUserData);
    await prefs.setBool(ApiConstants.keyIsLoggedIn, false);
  }
}
