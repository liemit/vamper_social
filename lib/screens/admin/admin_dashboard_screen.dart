import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminController controller = Get.put(AdminController());
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Vamper Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () => controller.fetchAdminData(), icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () {
              authController.logout();
              Get.offAll(() => const LoginScreen());
            },
            icon: const Icon(Icons.logout, color: Colors.red),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Sidebar (Visible only on wide screens)
          if (MediaQuery.of(context).size.width > 800)
            Container(
              width: 250,
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _SidebarItem(icon: Icons.dashboard, label: 'Dashboard', isSelected: true, onTap: () {}),
                  _SidebarItem(icon: Icons.people, label: 'Users', isSelected: false, onTap: () {}),
                  _SidebarItem(icon: Icons.post_add, label: 'Moments', isSelected: false, onTap: () {}),
                  _SidebarItem(icon: Icons.report_problem, label: 'Reports', isSelected: false, onTap: () {}),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  Obx(() => Row(
                    children: [
                      _StatCard(label: 'Total Users', value: controller.stats['total_users']?.toString() ?? '0', color: Colors.blue),
                      const SizedBox(width: 16),
                      _StatCard(label: 'Total Posts', value: controller.stats['total_posts']?.toString() ?? '0', color: Colors.green),
                      const SizedBox(width: 16),
                      _StatCard(label: 'Banned', value: controller.stats['banned_users']?.toString() ?? '0', color: Colors.red),
                    ],
                  )),

                  const SizedBox(height: 32),

                  const Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // User Table
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Obx(() {
                      if (controller.isLoading.value) {
                        return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                      }

                      return DataTable(
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('User')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Coins')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: controller.users.map((user) => DataRow(cells: [
                          DataCell(Row(
                            children: [
                              CircleAvatar(radius: 14, backgroundImage: user.profilePhoto != null ? NetworkImage(authController.getFullImageUrl(user.profilePhoto)!) : null),
                              const SizedBox(width: 8),
                              Text(user.fullName),
                            ],
                          )),
                          DataCell(Text(user.email)),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: user.role == 'admin' ? Colors.purple.withOpacity(0.1) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(user.role.toUpperCase(), style: TextStyle(color: user.role == 'admin' ? Colors.purple : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          )),
                          DataCell(Text(user.coins.toString())),
                          DataCell(Switch(
                            value: user.isActive,
                            onChanged: (val) => controller.toggleUserStatus(user.id),
                            activeColor: Colors.green,
                          )),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.amber, size: 20),
                                onPressed: () => _showCoinDialog(context, user, controller),
                                tooltip: 'Give Coins',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {},
                              ),
                            ],
                          )),
                        ])).toList(),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCoinDialog(BuildContext context, UserModel user, AdminController controller) {
    final coinController = TextEditingController(text: user.coins.toString());
    Get.dialog(
      AlertDialog(
        title: Text('Manage VPC: ${user.fullName}'),
        content: TextField(controller: coinController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coin Balance')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(onPressed: () {
            controller.updateCoins(user.id, int.tryParse(coinController.text) ?? user.coins);
            Get.back();
          }, child: const Text('Update')),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _SidebarItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(label, style: TextStyle(color: isSelected ? AppColors.primary : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      onTap: onTap,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
