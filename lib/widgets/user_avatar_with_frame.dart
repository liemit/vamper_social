import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class UserAvatarWithFrame extends StatelessWidget {
  final String? photoUrl;
  final int? frameId;
  final String? frameCode;
  final double size;
  final VoidCallback? onTap;

  const UserAvatarWithFrame({
    super.key,
    this.photoUrl,
    this.frameId,
    this.frameCode,
    this.size = 80.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final fullPhotoUrl = photoUrl != null && photoUrl!.isNotEmpty
        ? authController.getFullImageUrl(photoUrl)
        : null;

    final code = _resolveFrameCode(frameId, frameCode);

    if (code == null) {
      // Standard Avatar without frame
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: fullPhotoUrl != null
                ? Image.network(
                    fullPhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
        ),
      );
    }

    List<Color> gradientColors;
    Widget? badgeIcon;

    switch (code) {
      case 'frame_blue':
        gradientColors = [Colors.blue.shade400, Colors.cyanAccent];
        break;
      case 'frame_emerald':
        gradientColors = [Colors.teal, Colors.greenAccent];
        break;
      case 'frame_neon':
        gradientColors = [Colors.purple, Colors.pink, Colors.cyan];
        break;
      case 'frame_gold':
        gradientColors = [Colors.amber.shade700, Colors.yellow, Colors.amber.shade300];
        badgeIcon = Positioned(top: -size * 0.05, child: Text('👑', style: TextStyle(fontSize: size * 0.22)));
        break;
      case 'frame_flame':
        gradientColors = [Colors.deepOrange, Colors.orange, Colors.red];
        badgeIcon = Positioned(bottom: -size * 0.05, child: Text('🔥', style: TextStyle(fontSize: size * 0.22)));
        break;
      case 'frame_galaxy':
        gradientColors = [Colors.indigo, Colors.purple, Colors.pinkAccent];
        badgeIcon = Positioned(top: -size * 0.05, child: Text('✨', style: TextStyle(fontSize: size * 0.22)));
        break;
      case 'frame_dragon':
        gradientColors = [Colors.red.shade900, Colors.purple.shade800, Colors.black];
        badgeIcon = Positioned(bottom: -size * 0.05, child: Text('🐉', style: TextStyle(fontSize: size * 0.22)));
        break;
      case 'frame_white':
      default:
        gradientColors = [Colors.grey.shade400, Colors.grey.shade200];
        break;
    }

    final frameThickness = size * 0.06;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Frame Ring Outer
            Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(frameThickness),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.4),
                    blurRadius: size * 0.12,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: fullPhotoUrl != null
                      ? Image.network(
                          fullPhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            if (badgeIcon != null) badgeIcon,
          ],
        ),
      ),
    );
  }

  String? _resolveFrameCode(int? id, String? code) {
    if (code != null && code.isNotEmpty) return code;
    if (id == null || id <= 0) return null;
    switch (id) {
      case 1:
        return 'frame_white';
      case 2:
        return 'frame_blue';
      case 3:
        return 'frame_emerald';
      case 4:
        return 'frame_neon';
      case 5:
        return 'frame_gold';
      case 6:
        return 'frame_flame';
      case 7:
        return 'frame_galaxy';
      case 8:
        return 'frame_dragon';
      default:
        return 'frame_gold';
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Icon(
        Icons.person,
        size: size * 0.45,
        color: AppColors.primary,
      ),
    );
  }
}
