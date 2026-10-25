import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../core/constants/api_constants.dart';

class SwipeCardsScreen extends StatefulWidget {
  const SwipeCardsScreen({super.key});

  @override
  State<SwipeCardsScreen> createState() => _SwipeCardsScreenState();
}

class _SwipeCardsScreenState extends State<SwipeCardsScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final DiscoveryController _discoveryController = Get.put(DiscoveryController());

  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;
  Offset _cardOffset = Offset.zero;
  double _cardAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCandidates();
  }

  Future<void> _fetchCandidates() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authController.apiService.get(
        '${ApiConstants.baseUrl}/lover-cards-get.php',
        params: {
          'user_id': userId,
          'gender_pref': _discoveryController.genderPreference.value,
        },
      );

      if (response.data['success'] == true) {
        final List data = response.data['data'] ?? [];
        setState(() {
          _candidates = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _swipeCard(String action) async {
    if (_candidates.isEmpty) return;

    final target = _candidates.first;
    final targetId = target['id'].toString();
    final userId = _authController.currentUser.value?.id;

    setState(() {
      _candidates.removeAt(0);
      _cardOffset = Offset.zero;
      _cardAngle = 0.0;
    });

    if (userId == null) return;

    try {
      final response = await _authController.apiService.post(
        '${ApiConstants.baseUrl}/lover-card-swipe.php',
        data: {
          'user_id': userId,
          'target_id': targetId,
          'action': action,
        },
      );

      if (response.data['is_match'] == true) {
        _showMatchModal(target);
      }
    } catch (e) {
      print('Error recording swipe: $e');
    }
  }

  void _showMatchModal(Map<String, dynamic> partner) {
    final photoUrl = _authController.getFullImageUrl(partner['profile_photo']);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.pink, size: 64),
            const SizedBox(height: 12),
            const Text(
              'It\'s a Match! 🎉',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'You and ${partner['full_name']} liked each other.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 45,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Get.back(); // close modal
              },
              child: const Text('Keep Swiping'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Lover Card',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _candidates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.style_rounded, size: 70, color: AppColors.textLight),
                      const SizedBox(height: 16),
                      const Text(
                        'No more cards right now!',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try refreshing or changing filters.',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _fetchCandidates,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Cards'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_candidates.length > 1)
                              _buildCard(_candidates[1], isTop: false),
                            _buildTopCard(_candidates[0]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionButton(
                            icon: Icons.close_rounded,
                            color: Colors.red,
                            onTap: () => _swipeCard('pass'),
                          ),
                          const SizedBox(width: 24),
                          _ActionButton(
                            icon: Icons.star_rounded,
                            color: Colors.blue,
                            onTap: () => _swipeCard('superlike'),
                          ),
                          const SizedBox(width: 24),
                          _ActionButton(
                            icon: Icons.favorite_rounded,
                            color: Colors.green,
                            onTap: () => _swipeCard('like'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTopCard(Map<String, dynamic> user) {
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _cardOffset += details.delta;
          _cardAngle = _cardOffset.dx / screenSize.width * 0.4;
        });
      },
      onPanEnd: (details) {
        if (_cardOffset.dx > 100) {
          _swipeCard('like');
        } else if (_cardOffset.dx < -100) {
          _swipeCard('pass');
        } else if (_cardOffset.dy < -100) {
          _swipeCard('superlike');
        } else {
          setState(() {
            _cardOffset = Offset.zero;
            _cardAngle = 0.0;
          });
        }
      },
      child: Transform.translate(
        offset: _cardOffset,
        child: Transform.rotate(
          angle: _cardAngle,
          child: _buildCard(user, isTop: true),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> user, {required bool isTop}) {
    final screenSize = MediaQuery.of(context).size;
    final photoUrl = _authController.getFullImageUrl(user['profile_photo']);

    return Container(
      width: screenSize.width * 0.88,
      height: screenSize.height * 0.62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // User Image
            photoUrl != null
                ? Image.network(photoUrl, fit: BoxFit.cover)
                : Container(
                    color: Colors.pink.shade50,
                    child: const Icon(Icons.person, size: 80, color: Colors.pinkAccent),
                  ),

            // Gradient Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.5, 1.0],
                ),
              ),
            ),

            // User Info
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${user['full_name']}, ${user['age'] ?? 20}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (user['is_verified'] == 1)
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        user['location'] ?? 'Vietnam',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  if (!empty(user['bio'])) ...[
                    const SizedBox(height: 8),
                    Text(
                      user['bio'],
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool empty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
