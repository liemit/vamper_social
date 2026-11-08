import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: ApiConstants.headers,
      ),
    );

    // Add interceptors for logging & ngrok header enforcement
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.uri.host.endsWith('ngrok-free.app') ||
              options.uri.host.endsWith('ngrok.io')) {
            options.headers['ngrok-skip-browser-warning'] = 'true';
          }
          final preferences = await SharedPreferences.getInstance();
          final token = preferences.getString(ApiConstants.keyToken);
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          return handler.next(options);
        },
      ),
    );

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
        requestHeader: false,
        responseHeader: false,
      ),
    );
  }

  Dio get dio => _dio;

  // Test API connection
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await _dio.get(ApiConstants.test);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // POST request
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // GET request
  Future<Response> get(String endpoint, {Map<String, dynamic>? params}) async {
    try {
      return await _dio.get(endpoint, queryParameters: params);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(endpoint);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error handler
  String _handleError(DioException error) {
    print('🚨 API Error [${error.type}]: ${error.message}');
    if (error.response != null) {
      print('🚨 Status: ${error.response?.statusCode}');
      print('🚨 Data: ${error.response?.data}');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';

      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data != null && data is Map) {
          return data['message'] ??
              'Server error: ${error.response?.statusCode}';
        }
        return 'Server error: ${error.response?.statusCode}';

      case DioExceptionType.cancel:
        return 'Request cancelled';

      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') ?? false) {
          return 'No internet connection or API server unreachable.';
        }
        return 'Network error: ${error.message}';

      default:
        return 'Something went wrong: ${error.message}';
    }
  }
}
