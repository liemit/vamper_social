import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import '../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/feed_controller.dart';
import '../models/post_model.dart';
import '../core/utils/date_formatter.dart';
import '../screens/profile/profile_preview_screen.dart';
import '../screens/home/create_post_screen.dart';
import 'comments_sheet.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final FeedController feedController = Get.find<FeedController>();

    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.to(() => ProfilePreviewScreen(userId: post.userId)),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: post.authorPhoto != null 
                            ? Image.network(
                                authController.getFullImageUrl(post.authorPhoto)!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white),
                              )
                            : const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Get.to(() => ProfilePreviewScreen(userId: post.userId)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Row(
                            children: [
                              Text(
                                DateFormatter.formatTimeAgo(post.createdAt),
                                style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                              ),
                              if (post.status == 0) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.lock, size: 12, color: AppColors.textLight),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handlePostAction(context, value, post, feedController),
                    icon: const Icon(Icons.more_horiz, color: AppColors.textLight),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 20, color: Colors.orange), SizedBox(width: 12), Text('Report Post')])),
                      if (post.userId == authController.currentUser.value?.id) ...[
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Edit Post')])),
                        PopupMenuItem(
                          value: 'privacy', 
                          child: Row(children: [
                            Icon(post.status == 1 ? Icons.lock_outline : Icons.public, size: 20), 
                            const SizedBox(width: 12), 
                            Text(post.status == 1 ? 'Make Private' : 'Make Public')
                          ])
                        ),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 20, color: Colors.red), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.red))])),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Content
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.content, style: const TextStyle(fontSize: 15, height: 1.4)),
                    if (post.hashtags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: post.hashtags.map((tag) => Text('#$tag', style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600))).toList(),
                      ),
                    ],
                  ],
                ),
              ),

            // Multiple Images Carousel
            if (post.photos.isNotEmpty)
              _ImageCarousel(photos: post.photos, authController: authController),

            // Interaction Bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _InteractionButton(
                    icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                    label: post.likesCount.toString(),
                    color: post.isLiked ? AppColors.primary : AppColors.textSecondary,
                    onTap: () => feedController.toggleLike(post),
                  ),
                  const SizedBox(width: 16),
                  _InteractionButton(
                    icon: Icons.chat_bubble_outline,
                    label: post.commentsCount.toString(),
                    color: AppColors.textSecondary,
                    onTap: () => _showCommentsSheet(context),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      String shareText = 'Check out this moment on Vamper! 💖\n\n'
                          '${post.authorName} says: "${post.content}"\n\n'
                          'Join us on Vamper for more! #vamper #dating';
                      Share.share(shareText);
                    }, 
                    icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(post: post),
    );
  }

  void _handlePostAction(BuildContext context, String value, PostModel post, FeedController controller) {
    if (value == 'report') {
      _showReportDialog(context, post, controller);
    } else if (value == 'delete') {
      Get.dialog(
        AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this moment?'),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                controller.deletePost(post.id);
                Get.back();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else if (value == 'privacy') {
      final newStatus = post.status == 1 ? 0 : 1;
      controller.updatePostWithPhotos(postId: post.id, status: newStatus);
    } else if (value == 'edit') {
      Get.to(() => CreatePostScreen(editPost: post));
    }
  }

  void _showReportDialog(BuildContext context, PostModel post, FeedController controller) {
    final RxString selectedReason = 'Spam'.obs;
    final TextEditingController descController = TextEditingController();

    final reasons = [
      'Spam',
      'Inappropriate Content',
      'Harassment',
      'Fake Information',
      'Other',
    ];

    Get.dialog(
      AlertDialog(
        title: const Text('Report Post'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please select a reason for reporting this post:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Obx(() => Column(
                children: reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 13)),
                  value: reason,
                  groupValue: selectedReason.value,
                  onChanged: (val) => selectedReason.value = val!,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )).toList(),
              )),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Additional details (optional)...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Get.back();
              controller.reportPost(post.id, selectedReason.value, descController.text.trim());
            },
            child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<PostPhoto> photos;
  final AuthController authController;

  const _ImageCarousel({required this.photos, required this.authController});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              final url = widget.authController.getFullImageUrl(photo.url);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => url != null ? widget.authController.showImageDetail(url) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: url != null
                        ? Transform.scale(
                            scale: photo.scale,
                            alignment: photo.alignment,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              alignment: photo.alignment,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: AppColors.border.withOpacity(0.1),
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.border.withOpacity(0.1),
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          )
                        : const Icon(Icons.image),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.photos.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photos.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? AppColors.primary : AppColors.textLight.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InteractionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
