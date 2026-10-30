import 'package:flutter/material.dart';

class ProfileFrameStyle {
  final List<Color> colors;
  final String? badge;
  final bool badgeAtTop;

  const ProfileFrameStyle({
    required this.colors,
    this.badge,
    this.badgeAtTop = true,
  });

  static ProfileFrameStyle fromCode(String code) {
    return switch (code) {
      'frame_blue' => ProfileFrameStyle(
        colors: [Colors.blue.shade400, Colors.cyanAccent],
      ),
      'frame_emerald' => const ProfileFrameStyle(
        colors: [Colors.teal, Colors.greenAccent],
      ),
      'frame_neon' => const ProfileFrameStyle(
        colors: [Colors.purple, Colors.pink, Colors.cyan],
      ),
      'frame_gold' => ProfileFrameStyle(
        colors: [Colors.amber.shade700, Colors.yellow, Colors.amber.shade300],
        badge: '👑',
        badgeAtTop: true,
      ),
      'frame_flame' => const ProfileFrameStyle(
        colors: [Colors.deepOrange, Colors.orange, Colors.red],
        badge: '🔥',
        badgeAtTop: false,
      ),
      'frame_galaxy' => const ProfileFrameStyle(
        colors: [Colors.indigo, Colors.purple, Colors.pinkAccent],
        badge: '✨',
        badgeAtTop: true,
      ),
      'frame_dragon' => const ProfileFrameStyle(
        colors: [Color(0xFF8E1018), Color(0xFF6A1B9A), Colors.black],
        badge: '🐉',
        badgeAtTop: false,
      ),
      'frame_rose' => const ProfileFrameStyle(
        colors: [Color(0xFFFF4D8D), Color(0xFFFFB6C8), Color(0xFFB5175B)],
        badge: '🌹',
      ),
      'frame_ice' => const ProfileFrameStyle(
        colors: [Color(0xFF8BE9FD), Color(0xFFFFFFFF), Color(0xFF5B8DEF)],
        badge: '❄️',
        badgeAtTop: false,
      ),
      'frame_sakura' => const ProfileFrameStyle(
        colors: [Color(0xFFFFC1D9), Color(0xFFE84393), Color(0xFFFFE6EF)],
        badge: '🌸',
      ),
      'frame_ocean' => const ProfileFrameStyle(
        colors: [Color(0xFF00B4D8), Color(0xFF0077B6), Color(0xFF90E0EF)],
        badge: '🌊',
        badgeAtTop: false,
      ),
      'frame_sunset' => const ProfileFrameStyle(
        colors: [Color(0xFFFF6B35), Color(0xFFFFC857), Color(0xFFE84393)],
        badge: '🌅',
      ),
      'frame_mint' => const ProfileFrameStyle(
        colors: [Color(0xFF80ED99), Color(0xFF38A3A5), Color(0xFFB7E4C7)],
        badge: '🍃',
        badgeAtTop: false,
      ),
      'frame_obsidian' => const ProfileFrameStyle(
        colors: [Color(0xFF111827), Color(0xFF4B5563), Color(0xFF111827)],
        badge: '💠',
      ),
      'frame_holo' => const ProfileFrameStyle(
        colors: [
          Color(0xFFFF8FAB),
          Color(0xFFB8F2E6),
          Color(0xFFA0C4FF),
          Color(0xFFFFD6A5),
        ],
        badge: '💫',
        badgeAtTop: false,
      ),
      'frame_rainbow' => const ProfileFrameStyle(
        colors: [
          Color(0xFFFF595E),
          Color(0xFFFFCA3A),
          Color(0xFF8AC926),
          Color(0xFF1982C4),
          Color(0xFF6A4C93),
        ],
        badge: '🌈',
      ),
      'frame_solar' => const ProfileFrameStyle(
        colors: [Color(0xFFFFD166), Color(0xFFF77F00), Color(0xFFFFE29A)],
        badge: '☀️',
        badgeAtTop: false,
      ),
      _ => ProfileFrameStyle(
        colors: [Colors.grey.shade400, Colors.grey.shade200],
      ),
    };
  }
}
