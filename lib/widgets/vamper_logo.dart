import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';

class VamperLogo extends StatelessWidget {
  final double size;
  final Color? textColor;
  final bool showTagline;

  const VamperLogo({
    super.key,
    this.size = 48,
    this.textColor,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = size;
    final heartSize = size * 0.9;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo: Heart + "amper"
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Heart Icon thay cho chữ "V"
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: Icon(
                Icons.favorite,
                size: heartSize,
                color: Colors.white,
              ),
            ),
            
            // Chữ "amper"
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: Text(
                'amper',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        
        // Tagline
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            'Find your perfect match',
            style: TextStyle(
              fontSize: fontSize * 0.35,
              fontWeight: FontWeight.w500,
              color: textColor ?? AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

// Logo cho Splash Screen
class VamperLogoLarge extends StatelessWidget {
  const VamperLogoLarge({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heart Icon with WHITE background for contrast
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,  // Nền trắng thay vì gradient
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite,
            color: AppColors.primary,  // Trái tim màu pink
            size: 60,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Text: ❤amper - TRẮNG để dễ nhìn trên gradient background
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Heart icon (WHITE)
            const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 48,
            ),
            
            const SizedBox(width: 4),
            
            // "amper" - TEXT TRẮNG
            const Text(
              'amper',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: Colors.white,  // Màu trắng
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Tagline - WHITE với opacity
        Text(
          'Find your perfect match',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.95),  // Trắng với opacity
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// Logo nhỏ cho AppBar
class VamperLogoSmall extends StatelessWidget {
  final double size;

  const VamperLogoSmall({
    super.key,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Heart
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Icon(
            Icons.favorite,
            size: size * 0.9,
            color: Colors.white,
          ),
        ),
        
        // "amper"
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'amper',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
