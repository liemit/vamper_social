import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:image_picker/image_picker.dart';
import '../core/constants/api_constants.dart';
import '../models/conversation_model.dart';
import '../models/gift_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import 'auth_controller.dart';

class ChatController extends GetxController {
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();

  final RxList<ConversationModel> conversations = <ConversationModel>[].obs;
  final RxList<MessageModel> messages = <MessageModel>[].obs;
  final RxBool isLoadingConversations = false.obs;
  final RxBool isLoadingMessages = false.obs;
  final RxBool isSending = false.obs;

  Timer? _pollingTimer;
  Timer? _notificationTimer;
  int? _activeConversationId;
  final Map<String, String> _pendingGiftRequestIds = {};
  bool _isSendingGift = false;

  bool get hasUnreadMessages => conversations.any((c) => c.unreadCount > 0);

  Future<List<GiftModel>> fetchGifts() async {
    final response = await _apiService.get(ApiConstants.getGifts);
    if (response.data['success'] != true) {
      throw StateError(response.data['message']?.toString() ?? 'Unable to load gifts.');
    }
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((gift) => GiftModel.fromJson(Map<String, dynamic>.from(gift as Map)))
        .toList();
  }

  Future<bool> sendGift({
    required int conversationId,
    required String partnerId,
    required GiftModel gift,
  }) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null || _isSendingGift) return false;

    final requestKey = '$conversationId:$partnerId:${gift.id}';
    final requestId = _pendingGiftRequestIds.putIfAbsent(
      requestKey,
      GiftModel.createRequestId,
    );
    try {
      _isSendingGift = true;
      isSending.value = true;
      final response = await _apiService.post(
        ApiConstants.sendGift,
        data: {
          'context_type': 'chat',
          'context_id': conversationId,
          'receiver_id': int.tryParse(partnerId),
          'gift_id': gift.id,
          'request_id': requestId,
        },
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ?? 'Unable to send this gift.',
        );
      }
      _pendingGiftRequestIds.remove(requestKey);

      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      messages.add(
        MessageModel.fromJson(Map<String, dynamic>.from(data)),
      );
      final remainingCoins = int.tryParse(data['remaining_coins'].toString());
      final currentUser = _authController.currentUser.value;
      if (remainingCoins != null && currentUser != null) {
        await _authController.updateCachedUser(
          currentUser.copyWith(coins: remainingCoins),
        );
      }
      fetchConversations();
      return true;
    } catch (error) {
      Get.snackbar(
        'Unable to send gift',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      _isSendingGift = false;
      isSending.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchConversations();
    startNotificationPolling();
  }

  @override
  void onClose() {
    _stopPolling();
    _notificationTimer?.cancel();
    super.onClose();
  }

  void startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      checkNotifications();
    });
  }

  Future<void> checkNotifications() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      final response = await _apiService.get(
        '${ApiConstants.baseUrl}/get-notifications.php',
        params: {'user_id': userId},
      );

      if (response.data['success'] == true) {
        final List data = response.data['data'] ?? [];
        for (var notif in data) {
          if (notif['type'] == 'follow' || notif['type'] == 'gift') {
            Get.snackbar(
              notif['title'] ?? 'Notification',
              notif['body'] ?? 'You have a new update!',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.pink,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          }
        }
        if (data.isNotEmpty) {
          fetchConversations();
        }
      }
    } catch (e) {
      print('Error checking notifications: $e');
    }
  }

  Future<void> fetchConversations() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      isLoadingConversations.value = true;
      final response = await _apiService.get(
        ApiConstants.getConversations,
        params: {'user_id': userId},
      );

      if (response.data['success'] == true) {
        final List data = response.data['data'] ?? [];
        conversations.value = data.map((c) => ConversationModel.fromJson(c)).toList();
      }
    } catch (e) {
      print('Error fetching conversations: $e');
    } finally {
      isLoadingConversations.value = false;
    }
  }

  Future<void> fetchMessages(int conversationId, {String? partnerId, bool isSilent = false}) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      if (!isSilent) isLoadingMessages.value = true;

      final Map<String, dynamic> params = {'user_id': userId};
      if (conversationId > 0) {
        params['conversation_id'] = conversationId;
      }
      if (partnerId != null) {
        params['partner_id'] = partnerId;
      }

      final response = await _apiService.get(
        ApiConstants.getMessages,
        params: params,
      );

      if (response.data['success'] == true) {
        if (response.data['conversation_id'] != null) {
          final realCid = int.parse(response.data['conversation_id'].toString());
          _activeConversationId = realCid;
        }
        final List data = response.data['data'] ?? [];
        messages.value = data.map((m) => MessageModel.fromJson(m)).toList();
      }
    } catch (e) {
      print('Error fetching messages: $e');
      if (!isSilent) messages.clear();
    } finally {
      if (!isSilent) isLoadingMessages.value = false;
    }
  }

  void startPollingMessages(int conversationId, {String? partnerId}) {
    _stopPolling();
    _activeConversationId = conversationId > 0 ? conversationId : null;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchMessages(_activeConversationId ?? 0, partnerId: partnerId, isSilent: true);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activeConversationId = null;
  }

  Future<bool> sendTextMessage({
    required int conversationId,
    required String partnerId,
    required String text,
    String? replyTo,
  }) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null || text.trim().isEmpty) return false;

    try {
      isSending.value = true;
      final response = await _apiService.post(
        ApiConstants.sendMessage,
        data: {
          'conversation_id': conversationId,
          'sender_id': userId,
          'receiver_id': partnerId,
          'content': text.trim(),
          'reply_to': ?replyTo,
        },
      );

      if (response.data['success'] == true) {
        final newMsg = MessageModel.fromJson(response.data['data']);
        messages.add(newMsg);
        fetchConversations(); // refresh inbox snippet
        return true;
      }
      Get.snackbar('Error', response.data['message'] ?? 'Failed to send message', snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (e) {
      print('Error sending message: $e');
      Get.snackbar('Error', 'Network or server error while sending message', snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> sendImageMessage({
    required int conversationId,
    required String partnerId,
    required XFile imageFile,
    String? replyTo,
  }) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return false;

    try {
      isSending.value = true;
      final bytes = await imageFile.readAsBytes();

      final formData = dio.FormData.fromMap({
        'conversation_id': conversationId,
        'sender_id': userId,
        'receiver_id': partnerId,
        'content': '📷 [Photo]',
        'reply_to': ?replyTo,
        'image': dio.MultipartFile.fromBytes(bytes.toList(), filename: imageFile.name),
      });

      final response = await _apiService.post(
        ApiConstants.sendMessage,
        data: formData,
      );

      if (response.data['success'] == true) {
        final newMsg = MessageModel.fromJson(response.data['data']);
        messages.add(newMsg);
        fetchConversations(); // refresh inbox snippet
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending image message: $e');
      return false;
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> sendVideoMessage({
    required int conversationId,
    required String partnerId,
    required XFile videoFile,
    String? replyTo,
  }) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return false;

    try {
      isSending.value = true;
      final bytes = await videoFile.readAsBytes();

      if (bytes.length > 15 * 1024 * 1024) {
        Get.snackbar('Video too large', 'Max video size is 15MB', snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      final formData = dio.FormData.fromMap({
        'conversation_id': conversationId,
        'sender_id': userId,
        'receiver_id': partnerId,
        'content': '🎬 [Video]',
        'reply_to': ?replyTo,
        'video': dio.MultipartFile.fromBytes(bytes.toList(), filename: videoFile.name),
      });

      final response = await _apiService.post(
        ApiConstants.sendMessage,
        data: formData,
      );

      if (response.data['success'] == true) {
        final newMsg = MessageModel.fromJson(response.data['data']);
        messages.add(newMsg);
        fetchConversations();
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending video message: $e');
      return false;
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> recallMessage(int messageId) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return false;

    try {
      final response = await _apiService.post(
        '${ApiConstants.baseUrl}/recall-message.php',
        data: {
          'message_id': messageId,
          'user_id': userId,
        },
      );

      if (response.data['success'] == true) {
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          final old = messages[index];
          messages[index] = MessageModel(
            id: old.id,
            conversationId: old.conversationId,
            senderId: old.senderId,
            receiverId: old.receiverId,
            messageType: 'recalled',
            content: '[Message recalled]',
            mediaUrl: null,
            replyTo: old.replyTo,
            isRead: old.isRead,
            createdAt: old.createdAt,
          );
        }
        fetchConversations();
        return true;
      }
      return false;
    } catch (e) {
      print('Error recalling message: $e');
      return false;
    }
  }

  Future<bool> reactToMessage(int messageId, String? reaction) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return false;

    try {
      final response = await _apiService.post(
        '${ApiConstants.baseUrl}/react-message.php',
        data: {
          'message_id': messageId,
          'user_id': userId,
          'reaction': reaction,
        },
      );

      if (response.data['success'] == true) {
        final index = messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          final old = messages[index];
          messages[index] = MessageModel(
            id: old.id,
            conversationId: old.conversationId,
            senderId: old.senderId,
            receiverId: old.receiverId,
            messageType: old.messageType,
            content: old.content,
            mediaUrl: old.mediaUrl,
            replyTo: old.replyTo,
            reaction: reaction,
            isRead: old.isRead,
            createdAt: old.createdAt,
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error reacting to message: $e');
      return false;
    }
  }

}
