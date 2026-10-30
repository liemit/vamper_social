import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../models/conversation_model.dart';
import '../../models/gift_model.dart';
import '../../models/message_model.dart';
import '../../widgets/gift_celebration_overlay.dart';
import '../matches/chat_call_screen.dart';
import '../profile/profile_preview_screen.dart';
import '../wallet/coin_shop_screen.dart';

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

  MessageModel? _replyingTo;
  Timer? _incomingCallTimer;
  bool _isCheckingIncomingCall = false;
  bool _isOpeningIncomingCall = false;
  final Queue<MessageModel> _giftEffectQueue = Queue<MessageModel>();
  MessageModel? _activeGiftEffect;
  Timer? _giftEffectTimer;

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
      onNewReceivedGift: _enqueueGiftEffect,
    );
    _incomingCallTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_checkIncomingCall()),
    );
    unawaited(_checkIncomingCall());
  }

  Future<void> _startChatCall(String callType) async {
    try {
      final response = await _authController.apiService.post(
        ApiConstants.chatCall,
        data: {
          'action': 'start',
          'conversation_id': widget.conversation.conversationId,
          'call_type': callType,
        },
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ?? 'Unable to start the call.',
        );
      }
      final session = Map<String, dynamic>.from(response.data['data'] as Map);
      if (!mounted) return;
      await Get.to(() => ChatCallScreen(session: session));
    } catch (error) {
      Get.snackbar(
        'Call unavailable',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _checkIncomingCall() async {
    if (_isCheckingIncomingCall || _isOpeningIncomingCall || !mounted) return;
    _isCheckingIncomingCall = true;
    try {
      final response = await _authController.apiService.post(
        ApiConstants.chatCall,
        data: {'action': 'poll'},
      );
      if (!mounted || response.data['status'] != 'incoming') return;
      final session = Map<String, dynamic>.from(response.data['data'] as Map);
      if (session['conversation_id'].toString() !=
          widget.conversation.conversationId.toString()) {
        return;
      }
      _isOpeningIncomingCall = true;
      await Get.to(() => ChatCallScreen(session: session));
    } catch (error) {
      debugPrint('Unable to check incoming chat calls: $error');
    } finally {
      _isCheckingIncomingCall = false;
      _isOpeningIncomingCall = false;
    }
  }

  @override
  void dispose() {
    _incomingCallTimer?.cancel();
    _giftEffectTimer?.cancel();
    _chatController.onNewReceivedGift = null;
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    final replyText = _replyingTo?.content;
    _textController.clear();
    setState(() => _replyingTo = null);

    final success = await _chatController.sendTextMessage(
      conversationId: widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
      text: text,
      replyTo: replyText,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  void _pickAndSendImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (file == null) return;

    final replyText = _replyingTo?.content;
    setState(() => _replyingTo = null);

    final success = await _chatController.sendImageMessage(
      conversationId: widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
      imageFile: file,
      replyTo: replyText,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  void _pickAndSendVideo(ImageSource source) async {
    final XFile? file = await _picker.pickVideo(source: source);
    if (file == null) return;

    final replyText = _replyingTo?.content;
    setState(() => _replyingTo = null);

    final success = await _chatController.sendVideoMessage(
      conversationId: widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
      videoFile: file,
      replyTo: replyText,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  void _showMediaPickerModal() {
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
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text('Choose Photo from Gallery'),
              onTap: () {
                Get.back();
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.blue),
              title: const Text('Send Short Video (Max 15MB)'),
              onTap: () {
                Get.back();
                _pickAndSendVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPickerModal() {
    final emojis = [
      '😍',
      '❤️',
      '🔥',
      '✨',
      '😊',
      '👍',
      '💕',
      '🌹',
      '👋',
      '🎉',
      '🥰',
      '💬',
      '😘',
      '🌟',
      '🤩',
      '😎',
      '😜',
      '💖',
      '👑',
      '🚀',
      '☕',
      '🍕',
      '🐱',
      '🌹',
      '💔',
      '🙏',
      '💯',
      '💩',
      '👻',
      '🎃',
      '😁',
      '😂',
      '😜',
      '😇',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤤',
      '😴',
      '🥳',
      '😈',
      '👽',
      '🤖',
      '😺',
      '😸',
      '😹',
      '😻',
      '😼',
      '🤲',
    ];

    final vamperStickers = [
      '💖',
      '💘',
      '💍',
      '💎',
      '👑',
      '🦄',
      '🍷',
      '🥂',
      '💋',
      '💃',
      '🕺',
      '🌹',
      '🦋',
      '💫',
      '🍀',
      '🔥',
      '💌',
      '🧸',
      '🍫',
      '✨',
      '⭐',
      '🌟',
      '💥',
      '💯',
      '💢',
      '💬',
      '👁️‍🗨️',
      '💤',
      '🎉',
      '🎊',
    ];

    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        height: 380,
        child: DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Emojis (😊)'),
                  Tab(text: 'Vamper Exclusive (💎)'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: emojis.map((emoji) {
                          return InkWell(
                            onTap: () {
                              _textController.text += emoji;
                              Get.back();
                            },
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SingleChildScrollView(
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: vamperStickers.map((sticker) {
                          return InkWell(
                            onTap: () {
                              _textController.text += sticker;
                              Get.back();
                            },
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(
                                child: Text(
                                  sticker,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGiftPicker() async {
    try {
      final gifts = await _chatController.fetchGifts();
      if (!mounted) return;
      final coins = _authController.currentUser.value?.coins ?? 0;
      Get.bottomSheet(
        SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.62,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Send a gift',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text('🪙 $coins'),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a gift to send to your match.',
                  style: TextStyle(color: AppColors.textLight),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    itemCount: gifts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      final affordable = coins >= gift.priceCoins;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Get.back();
                          _confirmAndSendGift(gift);
                        },
                        child: Ink(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3F7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                gift.emoji,
                                style: const TextStyle(fontSize: 30),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                gift.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '🪙 ${gift.priceCoins}',
                                style: TextStyle(
                                  color: affordable
                                      ? AppColors.primary
                                      : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        isScrollControlled: true,
      );
    } catch (error) {
      Get.snackbar(
        'Gifts unavailable',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _confirmAndSendGift(GiftModel gift) async {
    final coins = _authController.currentUser.value?.coins ?? 0;
    if (coins < gift.priceCoins) {
      final openCoinShop = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Not enough coins'),
          content: Text(
            'You need ${gift.priceCoins} coins to send this gift. Your balance is $coins.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Get coins'),
            ),
          ],
        ),
      );
      if (openCoinShop == true) Get.to(() => const CoinShopScreen());
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirm gift'),
        content: Text(
          'Send ${gift.emoji} ${gift.name} for ${gift.priceCoins} coins?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Send gift'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sentGift = await _chatController.sendGift(
      conversationId: widget.conversation.conversationId,
      partnerId: widget.conversation.partnerId,
      gift: gift,
    );
    if (sentGift != null) {
      _enqueueGiftEffect(sentGift);
      _scrollToBottom();
    }
  }

  void _enqueueGiftEffect(MessageModel message) {
    if (message.messageType != 'gift' ||
        message.gift == null ||
        message.alreadyProcessed ||
        !mounted) {
      return;
    }
    if (_activeGiftEffect != null) {
      _giftEffectQueue.addLast(message);
      return;
    }
    _showGiftEffect(message);
  }

  void _showGiftEffect(MessageModel message) {
    if (!mounted) return;
    setState(() => _activeGiftEffect = message);
    final price =
        int.tryParse(message.gift?['price_coins']?.toString() ?? '') ?? 0;
    final duration = price >= 500
        ? const Duration(milliseconds: 4200)
        : price >= 100
        ? const Duration(milliseconds: 3400)
        : const Duration(milliseconds: 2600);
    _giftEffectTimer?.cancel();
    _giftEffectTimer = Timer(duration, _dismissGiftEffect);
  }

  void _dismissGiftEffect() {
    if (!mounted) return;
    setState(() => _activeGiftEffect = null);
    if (_giftEffectQueue.isNotEmpty) {
      final nextGift = _giftEffectQueue.removeFirst();
      _giftEffectTimer = Timer(
        const Duration(milliseconds: 180),
        () => _showGiftEffect(nextGift),
      );
    }
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'React to message',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: reactions.map((emoji) {
                return InkWell(
                  onTap: () async {
                    Get.back();
                    await _chatController.reactToMessage(
                      msg.id,
                      msg.reaction == emoji ? null : emoji,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: msg.reaction == emoji
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primary),
              title: const Text('Reply (Quote)'),
              onTap: () {
                Get.back();
                setState(() => _replyingTo = msg);
              },
            ),
            if (isMe &&
                msg.messageType != 'recalled' &&
                msg.messageType != 'gift')
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.red),
                title: const Text('Recall Message'),
                onTap: () async {
                  Get.back();
                  await _chatController.recallMessage(msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _authController.getFullImageUrl(
      widget.conversation.partnerPhoto,
    );

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
            Get.to(
              () => ProfilePreviewScreen(userId: widget.conversation.partnerId),
            );
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
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.white,
                                ),
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (widget.conversation.partnerVerified)
                          const Icon(
                            Icons.verified,
                            color: Colors.blueAccent,
                            size: 16,
                          ),
                      ],
                    ),
                    const Text(
                      'Tap to view profile',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Audio call',
            onPressed: () => _startChatCall('audio'),
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _startChatCall('video'),
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Messages List
              Expanded(
                child: Obx(() {
                  if (_chatController.isLoadingMessages.value &&
                      _chatController.messages.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
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
                              gradient: photoUrl == null
                                  ? AppColors.primaryGradient
                                  : null,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: photoUrl != null
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                decoration: const BoxDecoration(
                                                  gradient:
                                                      AppColors.primaryGradient,
                                                ),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 38,
                                                  color: Colors.white,
                                                ),
                                              ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 38,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You matched with ${widget.conversation.partnerName}! 🎉',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Say hi or send a photo to start the conversation.',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                            ),
                          ),
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
                      final isMe =
                          msg.senderId ==
                          _authController.currentUser.value?.id.toString();
                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(msg, isMe),
                        child: _buildMessageBubble(msg, isMe),
                      );
                    },
                  );
                }),
              ),

              // Quote Reply Preview Banner
              if (_replyingTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.grey.shade200,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying to: ${_replyingTo!.content}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                        onPressed: () => setState(() => _replyingTo = null),
                      ),
                    ],
                  ),
                ),

              // Input Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: Colors.white,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_photo_alternate_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                        onPressed: _showMediaPickerModal,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.sentiment_satisfied_alt_rounded,
                          color: Colors.amber,
                          size: 26,
                        ),
                        onPressed: _showEmojiPickerModal,
                      ),
                      IconButton(
                        tooltip: 'Send a gift',
                        icon: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.pinkAccent,
                          size: 25,
                        ),
                        onPressed: _showGiftPicker,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSendText(),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF0F2F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Obx(() {
                        return _chatController.isSending.value
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                                onPressed: _handleSendText,
                              );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_activeGiftEffect?.gift != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissGiftEffect,
                child: GiftCelebrationOverlay(
                  key: ValueKey(_activeGiftEffect!.id),
                  gift: _activeGiftEffect!.gift!,
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
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: msg.messageType == 'gift'
                    ? const Color(0xFFFFF0F6)
                    : msg.messageType == 'recalled'
                    ? Colors.grey.shade200
                    : (isMe ? AppColors.primary : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quoted Reply Banner if present
                  if (msg.replyTo != null && msg.replyTo!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe ? Colors.white : AppColors.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        'Replying to: ${msg.replyTo}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white70
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  if (msg.messageType == 'gift' && msg.gift != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey(msg.id),
                          tween: Tween(begin: 0.65, end: 1),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Text(
                            msg.gift!['emoji']?.toString() ?? '🎁',
                            style: const TextStyle(fontSize: 42),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? 'You sent a gift' : 'Sent you a gift',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                msg.gift!['name']?.toString() ?? 'Gift',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '🪙 ${msg.gift!['price_coins'] ?? 0}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

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
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Video Attachment if present
                  if (msg.messageType == 'video' && mediaUrl != null) ...[
                    Container(
                      height: 180,
                      width: 220,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 50,
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Video Message',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Text Content & Timestamp Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (msg.messageType != 'gift' &&
                          msg.content != null &&
                          msg.content!.isNotEmpty &&
                          msg.content != '📷 [Photo]' &&
                          msg.content != '🎬 [Video]')
                        Flexible(
                          child: Text(
                            msg.content!,
                            style: TextStyle(
                              color: msg.messageType == 'recalled'
                                  ? AppColors.textLight
                                  : (isMe
                                        ? Colors.white
                                        : AppColors.textPrimary),
                              fontSize: 14,
                              fontStyle: msg.messageType == 'recalled'
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          timeStr,
                          style: TextStyle(
                            color: isMe ? Colors.white70 : AppColors.textLight,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (msg.reaction != null && msg.reaction!.isNotEmpty)
              Positioned(
                bottom: -8,
                right: isMe ? 8 : null,
                left: isMe ? null : 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.reaction!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
