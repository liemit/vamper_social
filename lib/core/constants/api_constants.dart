import 'package:flutter/foundation.dart';

class ApiConstants {
  // Base URL cho Server PHP trên ổ D (Laragon) qua tên miền riêng vamper.xyz
  static String get baseUrl {
    if (kIsWeb) {
      final String origin = Uri.base.origin;
      // Nếu đang debug web (localhost:port), ta vẫn gọi API về server Laragon (localhost/vamper_api)
      if (origin.contains('localhost')) {
        return 'http://localhost/vamper_api/api';
      }
      // Khi đã deploy lên cùng server
      return '/vamper_api/api';
    }
    // Cho máy thật / Emulator qua Cloudflare Tunnel (vamper.xyz)
    return 'https://vamper.xyz/vamper_api/api';
  }
  
  // Public URL cho Web Portal (Admin)
  static String get webAdminUrl => 'https://vamper.xyz/vamper_api/admin.php'; 
  
  // Endpoints - Sử dụng đuôi .php cho backend PHP thuần
  static String get test => '$baseUrl/test.php';
  static String get register => '$baseUrl/register.php';
  static String get login => '$baseUrl/login.php';
  static String get sendOtp => '$baseUrl/send-otp.php';
  static String get verifyOtp => '$baseUrl/verify-otp.php';
  static String get getProfile => '$baseUrl/get-profile.php';
  static String get updateProfile => '$baseUrl/update-profile.php';
  static String get uploadProfileFolder => '$baseUrl/upload-photo.php';
  static String get uploadProfilePhoto => '$baseUrl/upload-photo.php';
  static String get getUserPhotos => '$baseUrl/get-user-photos.php';
  
  // Posts
  static String get getPosts => '$baseUrl/get-posts.php';
  static String get createPost => '$baseUrl/create-post.php';
  static String get likePost => '$baseUrl/like-post.php';
  
  // Comments
  static String get getComments => '$baseUrl/get-comments.php';
  static String get addComment => '$baseUrl/add-comment.php';
  static String get commentInteraction => '$baseUrl/toggle-comment-interaction.php';

  // Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Storage keys
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserData = 'user_data';
  static const String keyIsLoggedIn = 'is_logged_in';
}
