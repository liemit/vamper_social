import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import 'party_room_screen.dart';

class CreatePartyScreen extends StatefulWidget {
  const CreatePartyScreen({super.key});

  @override
  State<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends State<CreatePartyScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedTheme = 'General Chill 🎧';
  bool _isPrivate = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final themes = [
    'General Chill 🎧',
    'Late Night Talk 🌙',
    'Singing & Music 🎤',
    'Movie & Watch Party 🍿',
    'Dating & Matching 💕',
  ];

  void _createParty() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a party room title',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (_isPrivate && _passwordController.text.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a password for private room',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final AuthController authController = Get.find<AuthController>();
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await authController.apiService.post(
        '${ApiConstants.baseUrl}/create-party.php',
        data: {
          'title': title,
          'theme': _selectedTheme,
          'is_private': _isPrivate ? 1 : 0,
          'password': _passwordController.text.trim(),
        },
      );

      if (response.data['success'] == true) {
        final partyId = response.data['data']['party_id'];
        Get.back(); // close create screen
        Get.to(
          () => PartyRoomScreen(
            party: {
              'id': partyId,
              'host_id': userId,
              'title': title,
              'theme': _selectedTheme,
              'is_private': _isPrivate ? 1 : 0,
              'host_name': authController.currentUser.value?.fullName ?? 'Host',
              'host_photo': authController.currentUser.value?.profilePhoto,
            },
          ),
        );
      } else {
        Get.snackbar(
          'Error',
          response.data['message'] ?? 'Could not create party',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print('Error creating party: $e');
      Get.snackbar(
        'Error',
        'Failed to create party room',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Create Party Room 🎉',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Room Title',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Saturday Night Chill & Music 🎶',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Room Theme',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: themes.map((theme) {
                final isSelected = _selectedTheme == theme;
                return ChoiceChip(
                  label: Text(theme),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (selected) {
                    setState(() => _selectedTheme = theme);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: const Text(
                  'Private Room 🔒',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'Require a password to join this party room',
                ),
                value: _isPrivate,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
            ),
            if (_isPrivate) ...[
              const SizedBox(height: 16),
              const Text(
                'Room Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter room password...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.textLight,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _createParty,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Go Live 🎉',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
