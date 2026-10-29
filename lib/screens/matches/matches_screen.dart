import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import 'soul_match_waiting_screen.dart';
import 'voice_match_waiting_screen.dart';
import '../home/swipe_cards_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Find Your Match',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Random Interactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            
            // Match Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildMatchFeatureCard(
                    title: 'Soul Match',
                    icon: Icons.chat_bubble_rounded,
                    color: Colors.pink.shade50,
                    iconColor: Colors.pink,
                    onTap: () => Get.to(() => const SoulMatchWaitingScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMatchFeatureCard(
                    title: 'Voice Match',
                    icon: Icons.mic_rounded,
                    color: Colors.blue.shade50,
                    iconColor: Colors.blue,
                    onTap: () => Get.to(() => const VoiceMatchWaitingScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMatchFeatureCard(
                    title: 'Lover Card',
                    icon: Icons.style_rounded,
                    color: Colors.amber.shade50,
                    iconColor: Colors.amber.shade800,
                    onTap: () => Get.to(() => const SwipeCardsScreen()),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Daily Discovery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Banner card
            GestureDetector(
              onTap: () => Get.to(() => const SwipeCardsScreen()),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Start Swiping',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Find people near you right now and discover your soulmate.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.favorite, color: Colors.white, size: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: iconColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
