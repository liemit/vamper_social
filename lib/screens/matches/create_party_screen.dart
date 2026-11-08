import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import 'party_room_screen.dart';

class CreatePartyScreen extends StatefulWidget {
  final Map<String, dynamic>? editParty;

  const CreatePartyScreen({super.key, this.editParty});

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

  bool get isEditMode => widget.editParty != null;

  @override
  void initState() {
    super.initState();
    final party = widget.editParty;
    if (party != null) {
      _titleController.text = party['title']?.toString() ?? '';
      _selectedTheme = party['theme']?.toString() ?? _selectedTheme;
      if (!themes.contains(_selectedTheme)) themes.insert(0, _selectedTheme);
      _isPrivate = party['is_private'] == 1 ||
          party['is_private'] == '1' ||
          party['is_private'] == true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

    final password = _passwordController.text.trim();
    final wasPrivate = widget.editParty?['is_private'] == 1 ||
      widget.editParty?['is_private'] == '1' ||
      widget.editParty?['is_private'] == true;
    if (_isPrivate && password.isEmpty && !(isEditMode && wasPrivate)) {
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
        '${ApiConstants.baseUrl}/${isEditMode ? 'update-party.php' : 'create-party.php'}',
        data: {
          if (isEditMode) 'party_id': widget.editParty!['id'],
          'title': title,
          'theme': _selectedTheme,
          'is_private': _isPrivate ? 1 : 0,
          'password': password,
        },
      );

      if (response.data['success'] == true) {
        final responseData = Map<String, dynamic>.from(response.data['data'] ?? {});
        if (responseData['coins'] != null && authController.currentUser.value != null) {
          await authController.updateCachedUser(
            authController.currentUser.value!.copyWith(
              coins: int.tryParse(responseData['coins'].toString()) ??
                  authController.currentUser.value!.coins,
            ),
          );
        }

        if (isEditMode) {
          Get.back(result: responseData);
          Get.snackbar(
            'Party updated',
            'Your party room changes have been saved.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

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
        e.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Party Room' : 'Create Party Room 🎉',
          style: const TextStyle(
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
            if (!isEditMode)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Your first 3 party rooms are free. Each room after that costs 200 VPC.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            Text(
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
              Text(
                'Room Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: isEditMode && _isPrivate
                    ? 'Leave blank to keep current password'
                    : 'Enter room password...',
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
                  : Text(
                    isEditMode ? 'Save Changes' : 'Go Live 🎉',
                    style: const TextStyle(
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
