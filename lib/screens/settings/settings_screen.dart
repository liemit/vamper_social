import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../profile/edit_profile_screen.dart';
import 'blocked_users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthController _authController = Get.find<AuthController>();

  bool _pushNotifications = true;
  bool _matchNotifications = true;
  bool _partyNotifications = true;
  bool _privateProfile = false;
  bool _showOnlineStatus = true;
  bool _darkMode = false;
  bool _allowMessages = true;
  bool _showProfileInSearch = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Map<String, bool> _buildSettingsPayload() {
    return {
      'settings_push_notifications': _pushNotifications,
      'settings_match_notifications': _matchNotifications,
      'settings_party_notifications': _partyNotifications,
      'settings_private_profile': _privateProfile,
      'settings_show_online_status': _showOnlineStatus,
      'settings_allow_messages': _allowMessages,
      'settings_show_in_search': _showProfileInSearch,
      'settings_dark_mode': _darkMode,
    };
  }

  Future<void> _syncSettingsToBackend() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      await _authController.apiService.post(
        ApiConstants.updateUserSettings,
        data: {
          'user_id': userId,
          'settings': _buildSettingsPayload(),
        },
      );
    } catch (e) {
      print('Settings sync failed: $e');
    }
  }

  Future<void> _loadSettingsFromBackend() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final response = await _authController.apiService.get(
        ApiConstants.getUserSettings,
        params: {'user_id': userId},
      );
      final data = response.data['data'];
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        setState(() {
          _pushNotifications = map['settings_push_notifications'] == true;
          _matchNotifications = map['settings_match_notifications'] == true;
          _partyNotifications = map['settings_party_notifications'] == true;
          _privateProfile = map['settings_private_profile'] == true;
          _showOnlineStatus = map['settings_show_online_status'] == true;
          _allowMessages = map['settings_allow_messages'] == true;
          _showProfileInSearch = map['settings_show_in_search'] == true;
          _darkMode = map['settings_dark_mode'] == true;
        });
      }
    } catch (e) {
      print('Unable to load remote settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('settings_push_notifications') ?? true;
      _matchNotifications = prefs.getBool('settings_match_notifications') ?? true;
      _partyNotifications = prefs.getBool('settings_party_notifications') ?? true;
      _privateProfile = prefs.getBool('settings_private_profile') ?? false;
      _showOnlineStatus = prefs.getBool('settings_show_online_status') ?? true;
      _allowMessages = prefs.getBool('settings_allow_messages') ?? true;
      _showProfileInSearch = prefs.getBool('settings_show_in_search') ?? true;
      _darkMode = prefs.getBool('settings_dark_mode') ?? false;
    });

    if (_darkMode) {
      Get.changeThemeMode(ThemeMode.dark);
    } else {
      Get.changeThemeMode(ThemeMode.light);
    }

    await _loadSettingsFromBackend();
  }

  Future<void> _saveToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = _buildSettingsPayload();
    settings[key] = value;
    await prefs.setBool(key, value);
    await prefs.setString(ApiConstants.keyUserSettings, jsonEncode(settings));
    await _syncSettingsToBackend();
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Change password'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final cur = currentPasswordController.text.trim();
              final newPass = newPasswordController.text.trim();
              final confirm = confirmPasswordController.text.trim();

              if (newPass.isEmpty || confirm.isEmpty || cur.isEmpty) {
                Get.snackbar(
                  'Missing information',
                  'Please complete all password fields.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              if (newPass != confirm) {
                Get.snackbar(
                  'Password mismatch',
                  'New password and confirm password must match.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              try {
                final userId = _authController.currentUser.value?.id;
                if (userId == null || userId.isEmpty) {
                  throw Exception('User session is not available.');
                }

                final response = await _authController.apiService.post(
                  ApiConstants.changePassword,
                  data: {
                    'user_id': userId,
                    'current_password': cur,
                    'new_password': newPass,
                  },
                );

                if (response.data['success'] == true) {
                  Get.back();
                  Get.snackbar(
                    'Password updated',
                    response.data['message'] ?? 'Password has been changed.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                throw response.data['message'] ?? 'Password update failed';
              } catch (e) {
                Get.snackbar(
                  'Password update failed',
                  e.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Account',
            items: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Name, bio, interests, photo',
                onTap: () => Get.to(() => const EditProfileScreen()),
              ),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Change password',
                subtitle: 'Update your login password',
                onTap: _showChangePasswordDialog,
              ),
              _SettingsTile(
                icon: Icons.block_outlined,
                title: 'Blocked users',
                subtitle: 'Manage your block list',
                onTap: () => Get.to(() => const BlockedUsersScreen()),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Privacy',
            items: [
              _SettingsSwitchTile(
                icon: Icons.visibility_off_outlined,
                title: 'Private profile',
                subtitle: 'Only approved people can view your profile',
                value: _privateProfile,
                onChanged: (value) {
                  setState(() => _privateProfile = value);
                  _saveToggle('settings_private_profile', value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.online_prediction,
                title: 'Show online status',
                subtitle: 'Let others see when you are active',
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() => _showOnlineStatus = value);
                  _saveToggle('settings_show_online_status', value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.search_outlined,
                title: 'Show in search results',
                subtitle: 'Allow others to discover your profile',
                value: _showProfileInSearch,
                onChanged: (value) {
                  setState(() => _showProfileInSearch = value);
                  _saveToggle('settings_show_in_search', value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.chat_bubble_outline,
                title: 'Allow direct messages',
                subtitle: 'Let users message you without match',
                value: _allowMessages,
                onChanged: (value) {
                  setState(() => _allowMessages = value);
                  _saveToggle('settings_allow_messages', value);
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Notifications',
            items: [
              _SettingsSwitchTile(
                icon: Icons.notifications_none,
                title: 'Push notifications',
                subtitle: 'Alerts for likes, messages and party updates',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() => _pushNotifications = value);
                  _saveToggle('settings_push_notifications', value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.favorite_border,
                title: 'Match alerts',
                subtitle: 'New likes, matches and reactions',
                value: _matchNotifications,
                onChanged: (value) {
                  setState(() => _matchNotifications = value);
                  _saveToggle('settings_match_notifications', value);
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.celebration_outlined,
                title: 'Party reminders',
                subtitle: 'Upcoming party and event notifications',
                value: _partyNotifications,
                onChanged: (value) {
                  setState(() => _partyNotifications = value);
                  _saveToggle('settings_party_notifications', value);
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Security',
            items: [
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Two-factor authentication',
                subtitle: 'Add an extra layer of security',
                onTap: () => _showInfoDialog(
                  'Two-factor authentication',
                  'This feature will be enabled in the next security update.',
                ),
              ),
              _SettingsTile(
                icon: Icons.devices_other_outlined,
                title: 'Active sessions',
                subtitle: 'Review devices logged into your account',
                onTap: () => _showInfoDialog(
                  'Active sessions',
                  'You can review and disconnect devices from a future update.',
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'App',
            items: [
              _SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark mode',
                subtitle: 'Use dark theme for low-light browsing',
                value: _darkMode,
                onChanged: (value) async {
                  setState(() => _darkMode = value);
                  await _saveToggle('settings_dark_mode', value);
                  Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              _SettingsTile(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English',
                onTap: () => _showInfoDialog(
                  'Language',
                  'Language settings will be available in a later phase.',
                ),
              ),
              _SettingsTile(
                icon: Icons.delete_outline,
                title: 'Clear cache',
                subtitle: 'Remove temporary app data',
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final keysToClear = [
                    'settings_push_notifications',
                    'settings_match_notifications',
                    'settings_party_notifications',
                    'settings_private_profile',
                    'settings_show_online_status',
                    'settings_allow_messages',
                    'settings_show_in_search',
                    'settings_dark_mode',
                  ];

                  for (final key in keysToClear) {
                    await prefs.remove(key);
                  }

                  await prefs.remove(ApiConstants.keyUserSettings);
                  await _loadSettings();
                  Get.snackbar(
                    'Cache cleared',
                    'Temporary local settings have been reset without affecting your login session.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
              ),
            ],
          ),
          _SettingsSection(
            title: 'Support',
            items: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Help center',
                subtitle: 'Guides and troubleshooting',
                onTap: () => _showInfoDialog(
                  'Help center',
                  'Support articles will be added soon.',
                ),
              ),
              _SettingsTile(
                icon: Icons.feedback_outlined,
                title: 'Send feedback',
                subtitle: 'Share ideas or report issues',
                onTap: () => _showInfoDialog(
                  'Send feedback',
                  'Feedback form will be available in the next release.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SettingsSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _privateProfile = false;
  bool _showOnline = true;
  bool _allowMessages = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _privateProfile = prefs.getBool('settings_private_profile') ?? false;
      _showOnline = prefs.getBool('settings_show_online_status') ?? true;
      _allowMessages = prefs.getBool('settings_allow_messages') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSwitchTile(
            icon: Icons.visibility_off_outlined,
            title: 'Private profile',
            subtitle: 'Only approved people can view your profile',
            value: _privateProfile,
            onChanged: (value) {
              setState(() => _privateProfile = value);
              _save('settings_private_profile', value);
            },
          ),
          _SettingsSwitchTile(
            icon: Icons.online_prediction,
            title: 'Online status',
            subtitle: 'Let others see when you are active',
            value: _showOnline,
            onChanged: (value) {
              setState(() => _showOnline = value);
              _save('settings_show_online_status', value);
            },
          ),
          _SettingsSwitchTile(
            icon: Icons.chat_bubble_outline,
            title: 'Direct messages',
            subtitle: 'Allow users to message you directly',
            value: _allowMessages,
            onChanged: (value) {
              setState(() => _allowMessages = value);
              _save('settings_allow_messages', value);
            },
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.block_outlined,
            title: 'Blocked users',
            subtitle: 'Review and remove people on your block list',
            onTap: () => Get.to(() => const BlockedUsersScreen()),
          ),
        ],
      ),
    );
  }
}
