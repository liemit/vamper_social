import 'dart:math' as math;

import 'package:flutter/material.dart';

class GiftCelebrationOverlay extends StatefulWidget {
  final Map<String, dynamic> gift;

  const GiftCelebrationOverlay({super.key, required this.gift});

  @override
  State<GiftCelebrationOverlay> createState() => _GiftCelebrationOverlayState();
}

class _GiftCelebrationOverlayState extends State<GiftCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int get _price =>
      int.tryParse(widget.gift['price_coins']?.toString() ?? '') ?? 0;

  int get _tier => _price >= 500
      ? 2
      : _price >= 100
      ? 1
      : 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = switch (_tier) {
      2 => const [Color(0xFFFFC857), Color(0xFFFF4F81), Color(0xFF9B5DE5)],
      1 => const [Color(0xFFFF79A8), Color(0xFFB36BFF), Color(0xFF5D8DFF)],
      _ => const [Color(0xFFFF91B8), Color(0xFFFF5B8A), Color(0xFFB65CFF)],
    };
    final particleCount = _tier == 2
        ? 16
        : _tier == 1
        ? 10
        : 6;

    return Material(
      color: Colors.black.withValues(alpha: _tier == 2 ? 0.62 : 0.48),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = Curves.easeOutBack.transform(_controller.value);
          final opacity = Curves.easeOut.transform(_controller.value);
          return Center(
            child: SizedBox(
              width: 300,
              height: 330,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var index = 0; index < particleCount; index++)
                    _buildParticle(index, particleCount, colors, progress),
                  Transform.scale(
                    scale: 0.55 + (0.45 * progress),
                    child: Opacity(
                      opacity: opacity.clamp(0, 1),
                      child: Container(
                        width: _tier == 2 ? 224 : 204,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors
                                .map(
                                  (color) => color.withValues(
                                    alpha: _tier == 2 ? 0.95 : 0.88,
                                  ),
                                )
                                .toList(),
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: _tier == 2 ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withValues(alpha: 0.5),
                              blurRadius: _tier == 2 ? 44 : 28,
                              spreadRadius: _tier == 2 ? 5 : 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tier == 2
                                  ? 'MEGA GIFT!'
                                  : _tier == 1
                                  ? 'SPECIAL GIFT!'
                                  : 'A GIFT FOR YOU',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 1.1,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Transform.rotate(
                              angle: (1 - progress) * -0.22,
                              child: Text(
                                widget.gift['emoji']?.toString() ?? '🎁',
                                style: TextStyle(
                                  fontSize: _tier == 2 ? 82 : 70,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black26,
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.gift['name']?.toString() ?? 'Gift',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$_price VPC',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    child: Opacity(
                      opacity: opacity.clamp(0, 1),
                      child: const Text(
                        'Tap to continue',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParticle(
    int index,
    int count,
    List<Color> colors,
    double progress,
  ) {
    final angle = (2 * math.pi * index) / count;
    final distance = 55 + (125 * progress);
    final icon = index % 3 == 0 ? Icons.star_rounded : Icons.auto_awesome;
    return Transform.translate(
      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
      child: Opacity(
        opacity: (1 - progress).clamp(0, 1),
        child: Transform.rotate(
          angle: progress * (index.isEven ? 2 : -2),
          child: Icon(
            icon,
            size: index % 3 == 0 ? 20 : 14,
            color: colors[index % colors.length],
            shadows: const [Shadow(color: Colors.white, blurRadius: 10)],
          ),
        ),
      ),
    );
  }
}
