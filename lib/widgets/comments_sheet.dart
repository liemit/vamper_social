import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/feed_controller.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/utils/date_formatter.dart';
import '../screens/profile/profile_preview_screen.dart';

class CommentsSheet extends StatefulWidget {
  final PostModel post;

  const CommentsSheet({super.key, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final FeedController _feedController = Get.find<FeedController>();
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final Rx<CommentModel?> _replyingTo = Rx<CommentModel?>(null);

  @override
  void initState() {
    super.initState();
    _feedController.fetchComments(widget.post.id);
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    final parentId = _replyingTo.value?.id;
    _replyingTo.value = null;
    _focusNode.unfocus();

    final success = await _feedController.addComment(widget.post.id, text, parentId: parentId);
    
    if (success) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _startReply(CommentModel comment) {
    _replyingTo.value = comment;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments (${widget.post.commentsCount})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close)),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: Obx(() {
              if (_feedController.isCommentsLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_feedController.activeComments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: AppColors.border),
                      const SizedBox(height: 16),
                      const Text('No comments yet.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _feedController.activeComments.length,
                itemBuilder: (context, index) {
                  final comment = _feedController.activeComments[index];
                  return _CommentTile(
                    comment: comment,
                    postAuthorId: widget.post.userId,
                    onReply: () => _startReply(comment),
                    onVote: (type) => _feedController.toggleCommentInteraction(comment.id, type),
                  );
                },
              );
            }),
          ),

          // Reply Preview Bar
          Obx(() => _replyingTo.value != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.border.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 16, color: AppColors.textLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying to ${_replyingTo.value!.authorName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _replyingTo.value = null,
                        child: const Icon(Icons.close, size: 16, color: AppColors.textLight),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink()),

          // Input Area
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 12,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final userId = _authController.currentUser.value?.id;
                    if (userId != null) Get.to(() => ProfilePreviewScreen(userId: userId));
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _authController.currentUser.value?.profilePhoto != null
                          ? Image.network(
                              _authController.getFullImageUrl(_authController.currentUser.value!.profilePhoto)!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 20, color: Colors.white),
                            )
                          : const Icon(Icons.person, size: 20, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.border.withOpacity(0.2),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitComment,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String postAuthorId;
  final VoidCallback onReply;
  final Function(String) onVote;

  const _CommentTile({required this.comment, required this.postAuthorId, required this.onReply, required this.onVote});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final bool isReply = comment.parentId != null;
    final bool isAuthor = comment.userId == postAuthorId;

    return Padding(
      padding: EdgeInsets.only(bottom: 16, left: isReply ? 40 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Get.to(() => ProfilePreviewScreen(userId: comment.userId)),
            child: Container(
              width: isReply ? 28 : 36,
              height: isReply ? 28 : 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: comment.authorPhoto != null
                    ? Image.network(
                        authController.getFullImageUrl(comment.authorPhoto)!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.person, size: isReply ? 14 : 20, color: Colors.white),
                      )
                    : Icon(Icons.person, size: isReply ? 14 : 20, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.border.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Get.to(() => ProfilePreviewScreen(userId: comment.userId)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (isAuthor) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Author',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (comment.replyToName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: GestureDetector(
                            onTap: () {
                              if (comment.replyToUserId != null) {
                                Get.to(() => ProfilePreviewScreen(userId: comment.replyToUserId!));
                              }
                            },
                            child: Text(
                              'reply to ${comment.replyToName}',
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(comment.comment, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormatter.formatTimeAgo(comment.createdAt),
                      style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: const Text('Reply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    const Spacer(),
                    _VoteButton(
                      icon: Icons.thumb_up_alt_rounded,
                      count: comment.likesCount,
                      isActive: comment.userInteraction == 'like',
                      onTap: () => onVote('like'),
                    ),
                    const SizedBox(width: 12),
                    _VoteButton(
                      icon: Icons.thumb_down_alt_rounded,
                      count: comment.dislikesCount,
                      isActive: comment.userInteraction == 'dislike',
                      onTap: () => onVote('dislike'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _VoteButton({required this.icon, required this.count, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 4),
          if (count > 0)
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primary : AppColors.textLight,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
