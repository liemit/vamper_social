import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/chat_controller.dart';
import '../../models/conversation_model.dart';
import '../../widgets/user_avatar_with_frame.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController chatController = Get.put(ChatController());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => chatController.fetchConversations(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => chatController.fetchConversations(),
        color: AppColors.primary,
        child: Obx(() {
          if (chatController.isLoadingConversations.value &&
              chatController.conversations.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (chatController.conversations.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.mark_chat_unread_rounded,
                        size: 80,
                        color: AppColors.border,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Matches or Messages Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Match with someone on Soul Match, Voice Match, or Lover Card to start chatting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chatController.conversations.length,
            itemBuilder: (context, index) {
              final conversation = chatController.conversations[index];
              return _buildConversationItem(context, conversation);
            },
          );
        }),
      ),
    );
  }

  Widget _buildConversationItem(
    BuildContext context,
    ConversationModel conversation,
  ) {
    final timeStr = DateFormat('jm').format(conversation.updatedAt);

    return InkWell(
      onTap: () {
        Get.to(() => ChatScreen(conversation: conversation));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Partner Avatar
            Stack(
              children: [
                UserAvatarWithFrame(
                  photoUrl: conversation.partnerPhoto,
                  frameCode: conversation.partnerProfileFrameCode,
                  size: 56,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Partner Details & Snippet
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${conversation.partnerName}, ${conversation.partnerAge}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (conversation.partnerVerified)
                        const Icon(
                          Icons.verified,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        conversation.partnerGender == 'male'
                            ? Icons.male
                            : (conversation.partnerGender == 'female'
                                  ? Icons.female
                                  : Icons.transgender),
                        color: conversation.partnerGender == 'male'
                            ? Colors.blue
                            : Colors.pink,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: conversation.unreadCount > 0
                          ? AppColors.textPrimary
                          : AppColors.textLight,
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Time & Unread Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 6),
                if (conversation.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      conversation.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
