import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final RxList<Map<String, dynamic>> _blockedUsers = <Map<String, dynamic>>[].obs;
  final RxBool _isLoading = false.obs;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      _isLoading.value = true;
      final response = await _authController.apiService.get(
        '${ApiConstants.baseUrl}/block-user.php',
        params: {
          'action': 'list',
          'blocker_id': userId,
        },
      );

      if (response.data['success'] == true) {
        final List data = response.data['data'] ?? [];
        _blockedUsers.value = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print('Error fetching blocked users: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  void _unblockUser(String blockedId, String name) async {
    final myId = _authController.currentUser.value?.id;
    if (myId == null) return;

    try {
      final response = await _authController.apiService.post(
        '${ApiConstants.baseUrl}/block-user.php',
        data: {
          'blocker_id': myId,
          'blocked_id': blockedId,
          'action': 'unblock',
        },
      );

      if (response.data['success'] == true) {
        _blockedUsers.removeWhere((u) => u['id'].toString() == blockedId);
        Get.snackbar('Unblocked', '$name has been unblocked', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      print('Error unblocking user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Blocked Users 🚫', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (_isLoading.value && _blockedUsers.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (_blockedUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shield_outlined, size: 70, color: AppColors.textLight),
                SizedBox(height: 16),
                Text('No Blocked Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('Users you block will appear here.', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _blockedUsers.length,
          itemBuilder: (context, index) {
            final user = _blockedUsers[index];
            final photoUrl = _authController.getFullImageUrl(user['profile_photo']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null ? const Icon(Icons.person, size: 24) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['full_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        if (user['email'] != null)
                          Text(user['email'], style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _unblockUser(user['id'].toString(), user['full_name'] ?? 'User'),
                    child: const Text('Unblock'),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
