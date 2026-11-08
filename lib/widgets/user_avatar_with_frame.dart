import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import 'profile_frame_style.dart';

class UserAvatarWithFrame extends StatelessWidget {
  final String? photoUrl;
  final String? frameCode;
  final double size;
  final VoidCallback? onTap;

  const UserAvatarWithFrame({
    super.key,
    this.photoUrl,
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

    final code = frameCode != null && frameCode!.isNotEmpty ? frameCode : null;

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
                    errorBuilder: (_, _, _) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
        ),
      );
    }

    final style = ProfileFrameStyle.fromCode(code);
    final gradientColors = style.colors;
    final badgeIcon = style.badge == null
        ? null
        : Positioned(
            top: style.badgeAtTop ? -size * 0.05 : null,
            bottom: style.badgeAtTop ? null : -size * 0.05,
            child: Text(style.badge!, style: TextStyle(fontSize: size * 0.22)),
          );

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
                    color: gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: size * 0.12,
                    spreadRadius: 1,
                  ),
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
                          errorBuilder: (_, _, _) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            ?badgeIcon,
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Icon(Icons.person, size: size * 0.45, color: AppColors.primary),
    );
  }
}
