import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../models/conversation_model.dart';
import '../../models/message_model.dart';
import '../profile/profile_preview_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatController _chatController = Get.put(ChatController());
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _chatController.messages.clear(); // Clear stale messages from memory
    _chatController.fetchMessages(
      widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
    );
    _chatController.startPollingMessages(
      widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final success = await _chatController.sendTextMessage(
      conversationId: widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
      text: text,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  void _pickAndSendImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 70);
    if (file == null) return;

    final success = await _chatController.sendImageMessage(
      conversationId: widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
      imageFile: file,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  void _showImagePickerModal() {
    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () {
                Get.back();
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Get.back();
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPickerModal() {
    final emojis = ['😍', '❤️', '🔥', '✨', '😊', '👍', '💕', '🌹', '👋', '🎉', '🥰', '💬', '😘', '🌟'];

    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Emojis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              itemCount: emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    _textController.text += emojis[index];
                    Get.back();
                  },
                  child: Center(
                    child: Text(emojis[index], style: const TextStyle(fontSize: 26)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _authController.getFullImageUrl(widget.conversation.partnerPhoto);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: InkWell(
          onTap: () {
            Get.to(() => ProfilePreviewScreen(userId: widget.conversation.partnerId));
          },
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: photoUrl == null ? AppColors.primaryGradient : null,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                            child: const Icon(Icons.person, size: 20, color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.person, size: 20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${widget.conversation.partnerName}, ${widget.conversation.partnerAge}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        if (widget.conversation.partnerVerified)
                          const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                      ],
                    ),
                    const Text('Tap to view profile', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Obx(() {
              if (_chatController.isLoadingMessages.value && _chatController.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (_chatController.messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: photoUrl == null ? AppColors.primaryGradient : null,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                                    child: const Icon(Icons.person, size: 38, color: Colors.white),
                                  ),
                                )
                              : const Icon(Icons.person, size: 38, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('You matched with ${widget.conversation.partnerName}! 🎉', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Say hi or send a photo to start the conversation.', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _chatController.messages.length,
                itemBuilder: (context, index) {
                  final msg = _chatController.messages[index];
                  final isMe = msg.senderId == _authController.currentUser.value?.id.toString();
                  return _buildMessageBubble(msg, isMe);
                },
              );
            }),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  // Photo Attachment Button
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 26),
                    onPressed: _showImagePickerModal,
                  ),
                  // Emoji Picker Button
                  IconButton(
                    icon: const Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.amber, size: 26),
                    onPressed: _showEmojiPickerModal,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendText(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textLight),
                        filled: true,
                        fillColor: const Color(0xFFF0F2F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(() {
                    return _chatController.isSending.value
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 28),
                            onPressed: _handleSendText,
                          );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final mediaUrl = _authController.getFullImageUrl(msg.mediaUrl);
    final timeStr = DateFormat('jm').format(msg.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image Attachment if present
            if (msg.messageType == 'image' && mediaUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Text Content if present
            if (msg.content != null && msg.content!.isNotEmpty && msg.content != '📷 [Photo]')
              Text(
                msg.content!,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textLight,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
