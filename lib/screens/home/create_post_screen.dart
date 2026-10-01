import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/post_model.dart';
import 'reposition_image_screen.dart';

class CreatePostScreen extends StatefulWidget {
  final PostModel? editPost;

  const CreatePostScreen({super.key, this.editPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final FeedController _feedController = Get.find<FeedController>();
  final AuthController _authController = Get.find<AuthController>();
  
  final List<XFile> _selectedNewImages = [];
  final List<Alignment> _newImageAlignments = [];
  final List<double> _newImageScales = []; // New list for scales
  
  final List<PostPhoto> _existingPhotos = [];
  final List<String> _deletedImageUrls = [];

  bool get isEditMode => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _contentController.text = widget.editPost!.content;
      _existingPhotos.addAll(widget.editPost!.photos);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedNewImages.addAll(images);
        for (var _ in images) {
          _newImageAlignments.add(Alignment.center);
          _newImageScales.add(1.0); // Default scale
        }
      });
    }
  }

  void _handlePost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedNewImages.isEmpty && _existingPhotos.isEmpty) {
      Get.snackbar('Error', 'Please enter some text or add a photo');
      return;
    }

    // Convert alignments and scales to JSON-friendly format
    final List<Map<String, double>> newAligns = [];
    for (int i = 0; i < _selectedNewImages.length; i++) {
      newAligns.add({
        'x': _newImageAlignments[i].x,
        'y': _newImageAlignments[i].y,
        'scale': _newImageScales[i],
      });
    }

    bool success = false;
    if (isEditMode) {
      // Map current alignments for all existing photos
      final Map<String, Map<String, double>> updatedExistingAligns = {};
      for (var photo in _existingPhotos) {
        updatedExistingAligns[photo.url] = {
          'x': photo.alignmentX, 
          'y': photo.alignmentY,
          'scale': photo.scale
        };
      }

      success = await _feedController.updatePostWithPhotos(
        postId: widget.editPost!.id,
        content: content,
        newImages: _selectedNewImages,
        newAlignments: newAligns,
        deleteImageUrls: _deletedImageUrls,
        updateAlignments: updatedExistingAligns,
      );
    } else {
      success = await _feedController.createPost(content, _selectedNewImages, alignments: newAligns);
    }

    if (success) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Moment' : 'Create Moment'),
        actions: [
          TextButton(
            onPressed: _handlePost,
            child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Obx(() {
                  final photo = _authController.currentUser.value?.profilePhoto;
                  return CircleAvatar(
                    backgroundImage: photo != null ? NetworkImage(_authController.getFullImageUrl(photo)!) : null,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: photo == null ? const Icon(Icons.person, color: Colors.white) : null,
                  );
                }),
                const SizedBox(width: 12),
                const Text('What\'s on your mind?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share a moment... use #hashtags to trend!',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_selectedNewImages.isNotEmpty || _existingPhotos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
                ),
                itemCount: _existingPhotos.length + _selectedNewImages.length,
                itemBuilder: (context, index) {
                  if (index < _existingPhotos.length) {
                    final photo = _existingPhotos[index];
                    return _ImagePreviewCard(
                      url: _authController.getFullImageUrl(photo.url),
                      alignment: photo.alignment,
                      onTap: () async {
                        final result = await Get.to(() => RepositionImageScreen(
                          imageUrl: _authController.getFullImageUrl(photo.url),
                          initialAlignment: photo.alignment,
                          initialScale: photo.scale,
                        ));
                        if (result is RepositionResult) {
                          setState(() {
                            _existingPhotos[index] = PostPhoto(
                              url: photo.url,
                              alignmentX: result.alignment.x,
                              alignmentY: result.alignment.y,
                              scale: result.scale,
                            );
                          });
                        }
                      },
                      onRemove: () {
                        setState(() {
                          _deletedImageUrls.add(photo.url);
                          _existingPhotos.removeAt(index);
                        });
                      },
                    );
                  } else {
                    final localIndex = index - _existingPhotos.length;
                    final xfile = _selectedNewImages[localIndex];
                    return _ImagePreviewCard(
                      file: File(xfile.path),
                      alignment: _newImageAlignments[localIndex],
                      onTap: () async {
                        final result = await Get.to(() => RepositionImageScreen(
                          imageFile: File(xfile.path),
                          initialAlignment: _newImageAlignments[localIndex],
                          initialScale: _newImageScales[localIndex],
                        ));
                        if (result is RepositionResult) {
                          setState(() {
                            _newImageAlignments[localIndex] = result.alignment;
                            _newImageScales[localIndex] = result.scale;
                          });
                        }
                      },
                      onRemove: () {
                        setState(() {
                          _selectedNewImages.removeAt(localIndex);
                          _newImageAlignments.removeAt(localIndex);
                          _newImageScales.removeAt(localIndex);
                        });
                      },
                    );
                  }
                },
              ),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add Photos'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Tip: Tap a photo to adjust its focus area.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  final String? url;
  final File? file;
  final Alignment alignment;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _ImagePreviewCard({this.url, this.file, required this.alignment, required this.onRemove, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppColors.border.withOpacity(0.2),
              child: url != null
                  ? Image.network(url!, fit: BoxFit.cover, alignment: alignment)
                  : (kIsWeb ? Image.network(file!.path, fit: BoxFit.cover, alignment: alignment) : Image.file(file!, fit: BoxFit.cover, alignment: alignment)),
            ),
          ),
        ),
        Positioned(
          top: 5,
          right: 5,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
