import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/api_constants.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../app/theme/app_colors.dart';
import 'soul_match_chat_screen.dart';

class SoulMatchWaitingScreen extends StatefulWidget {
  const SoulMatchWaitingScreen({super.key});

  @override
  State<SoulMatchWaitingScreen> createState() => _SoulMatchWaitingScreenState();
}

class _SoulMatchWaitingScreenState extends State<SoulMatchWaitingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _pingTimer;
  bool _isSearching = true;
  String _statusText = 'Finding your soul match...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startQueuePing('soul');
    _findMatch();
  }

  void _startQueuePing(String mode) {
    _sendPing(mode, 'ping');
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _sendPing(mode, 'ping');
    });
  }

  void _sendPing(String mode, String action) {
    final AuthController authController = Get.find<AuthController>();
    final userId = authController.currentUser.value?.id;
    if (userId == null) return;

    authController.apiService.post(
      '${ApiConstants.baseUrl}/match-queue-ping.php',
      data: {
        'user_id': userId,
        'mode': mode,
        'action': action,
      },
    ).catchError((e) => print('Queue ping error: $e'));
  }

  Future<void> _findMatch() async {
    final AuthController authController = Get.find<AuthController>();
    final userId = authController.currentUser.value?.id;
    final DiscoveryController discoveryController = Get.put(DiscoveryController());
    final genderPref = discoveryController.genderPreference.value; // 'male', 'female', 'both'

    if (userId == null) {
      Get.back();
      return;
    }

    try {
      // Simulate searching delay for immersive UX
      await Future.delayed(const Duration(seconds: 3));

      final response = await authController.apiService.get(
        '${ApiConstants.baseUrl}/soul-match-find.php',
        params: {
          'user_id': userId,
          'gender_pref': genderPref,
        },
      );

      if (response.data['success'] == true) {
        final partnerData = response.data['data'];
        if (mounted) {
          setState(() {
            _statusText = 'Match Found! Connecting...';
          });
        }
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Get.off(() => SoulMatchChatScreen(partner: partnerData));
        }
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _statusText = response.data['message'] ?? 'No match found.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _statusText = 'No online users found right now. Try again later!';
        });
      }
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _sendPing('soul', 'leave');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Radar Animation
                Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _controller,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 2),
                          gradient: SweepGradient(
                            colors: [
                              Colors.pink.withValues(alpha: 0.0),
                              Colors.pink.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.pink.shade500.withValues(alpha: 0.2),
                      ),
                    ),
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.pink,
                      child: Icon(Icons.favorite, color: Colors.white, size: 40),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                Text(
                  _statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Searching across your discovery preferences...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (!_isSearching)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Get.back(),
                    child: const Text('Back to Matches'),
                  )
                else
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
