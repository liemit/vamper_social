import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';

class RepositionResult {
  final Alignment alignment;
  final double scale;
  RepositionResult(this.alignment, this.scale);
}

class RepositionImageScreen extends StatefulWidget {
  final String? imageUrl;
  final File? imageFile;
  final Alignment initialAlignment;
  final double initialScale;

  const RepositionImageScreen({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.initialAlignment = Alignment.center,
    this.initialScale = 1.0,
  });

  @override
  State<RepositionImageScreen> createState() => _RepositionImageScreenState();
}

class _RepositionImageScreenState extends State<RepositionImageScreen> {
  late double _alignmentX;
  late double _alignmentY;
  late double _scale;

  @override
  void initState() {
    super.initState();
    _alignmentX = widget.initialAlignment.x;
    _alignmentY = widget.initialAlignment.y;
    _scale = widget.initialScale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Focus & Zoom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: RepositionResult(Alignment(_alignmentX, _alignmentY), _scale)),
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Drag to pan, slider to zoom.\nThis is exactly how it will look in the feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The Viewfinder (Matches PostCard dimensions)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 40),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            // Sensitivity adjusts based on zoom level
                            double sensitivity = 0.005 / _scale;
                            _alignmentX -= details.delta.dx * sensitivity;
                            _alignmentY -= details.delta.dy * sensitivity;

                            _alignmentX = _alignmentX.clamp(-1.0, 1.0);
                            _alignmentY = _alignmentY.clamp(-1.0, 1.0);
                          });
                        },
                        child: Stack(
                          children: [
                            Transform.scale(
                              scale: _scale,
                              alignment: Alignment(_alignmentX, _alignmentY),
                              child: _buildImage(Alignment(_alignmentX, _alignmentY)),
                            ),
                            
                            // Composition Grid (Rule of Thirds)
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _GridPainter(),
                                size: Size.infinite,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Decorative Frame
                  IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls Area
          Container(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 48),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                _buildControlRow('Zoom', Icons.zoom_in, _scale, 1.0, 3.0, (val) => setState(() => _scale = val)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(label: 'Center', icon: Icons.center_focus_strong, onTap: () => setState(() { _alignmentX = 0; _alignmentY = 0; })),
                    _ActionButton(label: 'Original', icon: Icons.aspect_ratio, onTap: () => setState(() { _scale = 1.0; _alignmentX = 0; _alignmentY = 0; })),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Alignment align) {
    if (widget.imageFile != null) {
      return kIsWeb 
        ? Image.network(widget.imageFile!.path, fit: BoxFit.cover, alignment: align)
        : Image.file(widget.imageFile!, fit: BoxFit.cover, alignment: align);
    }
    return Image.network(widget.imageUrl!, fit: BoxFit.cover, alignment: align);
  }

  Widget _buildControlRow(String label, IconData icon, double value, double min, double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white30, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${value.toStringAsFixed(1)}x', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: AppColors.primary.withOpacity(0.2),
            trackHeight: 3,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white60, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;

    // Vertical lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Horizontal lines
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
