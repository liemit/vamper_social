import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../app/theme/app_colors.dart';

class VoiceMatchCallScreen extends StatefulWidget {
  final Map<String, dynamic> partner;

  const VoiceMatchCallScreen({super.key, required this.partner});

  @override
  State<VoiceMatchCallScreen> createState() => _VoiceMatchCallScreenState();
}

class _VoiceMatchCallScreenState extends State<VoiceMatchCallScreen> with SingleTickerProviderStateMixin {
  int _secondsElapsed = 0;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isCameraOn = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _startCallTimer();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  void _startCallTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Call?'),
        content: const Text('Do you want to disconnect this voice call?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Get.back(); // close dialog
              Get.back(); // return to matches
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final photoUrl = authController.getFullImageUrl(widget.partner['profile_photo']);

    return Scaffold(
      backgroundColor: const Color(0xFF16222A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              // Top Bar / Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                    onPressed: _endCall,
                  ),
                  const Text(
                    'Voice Match Call',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDuration(_secondsElapsed),
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Partner Avatar with Pulsing Waves
              Stack(
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: _waveController, curve: Curves.easeInOut)),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withValues(alpha: 0.4),
                    ),
                  ),
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Partner Name & Age
              Text(
                '${widget.partner['full_name']}, ${widget.partner['age'] ?? 22}',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connected via Voice Match',
                style: TextStyle(color: Colors.blueAccent, fontSize: 14),
              ),
              const Spacer(),

              // Call Controls (Mute, Camera, Speaker)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute Button
                  FloatingActionButton(
                    heroTag: 'mute',
                    backgroundColor: _isMuted ? Colors.white : Colors.white24,
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Camera Toggle Button (Zalo/Messenger style)
                  FloatingActionButton(
                    heroTag: 'camera',
                    backgroundColor: _isCameraOn ? Colors.blueAccent : Colors.white24,
                    onPressed: () {
                      setState(() => _isCameraOn = !_isCameraOn);
                      Get.snackbar(
                        'Camera',
                        _isCameraOn ? 'Camera turned ON' : 'Camera turned OFF',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: _isCameraOn ? Colors.blue : Colors.grey,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 1),
                      );
                    },
                    child: Icon(
                      _isCameraOn ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Speaker Button
                  FloatingActionButton(
                    heroTag: 'speaker',
                    backgroundColor: _isSpeaker ? Colors.white : Colors.white24,
                    onPressed: () => setState(() => _isSpeaker = !_isSpeaker),
                    child: Icon(
                      _isSpeaker ? Icons.volume_up : Icons.volume_off,
                      color: _isSpeaker ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Prominent Zalo/Messenger style Red Disconnect Button in the Center/Bottom
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
