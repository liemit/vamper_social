import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_constants.dart';
import 'auth_controller.dart';

class AdminController extends GetxController {
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();

  final RxList<UserModel> users = <UserModel>[].obs;
  final RxMap<String, dynamic> stats = <String, dynamic>{}.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAdminData();
  }

  Future<void> fetchAdminData() async {
    try {
      isLoading.value = true;
      final response = await _apiService.get(
        '${ApiConstants.baseUrl}/admin/users',
      );

      if (response.data['success'] == true) {
        final List<dynamic> userData = response.data['data']['users'];
        users.assignAll(userData.map((json) => UserModel.fromJson(json)).toList());
        stats.assignAll(response.data['data']['stats']);
      }
    } catch (e) {
      print('Error fetching admin data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleUserStatus(String userId) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.baseUrl}/admin/toggle-status',
        data: {'target_user_id': userId},
      );

      if (response.data['success'] == true) {
        await fetchAdminData();
      }
    } catch (e) {
      print('Error toggling user status: $e');
    }
  }

  Future<void> updateCoins(String userId, int newAmount) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.baseUrl}/admin/update-coins',
        data: {
          'target_user_id': userId,
          'coins': newAmount,
        },
      );

      if (response.data['success'] == true) {
        await fetchAdminData();
      }
    } catch (e) {
      print('Error updating coins: $e');
    }
  }
}
