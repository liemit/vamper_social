import 'dart:async';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:image_picker/image_picker.dart';
import '../core/constants/api_constants.dart';
import '../models/conversation_model.dart';
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
  int? _activeConversationId;

  @override
  void onInit() {
    super.onInit();
    fetchConversations();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
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
        },
      );

      if (response.data['success'] == true) {
        final newMsg = MessageModel.fromJson(response.data['data']);
        messages.add(newMsg);
        fetchConversations(); // refresh inbox snippet
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> sendImageMessage({
    required int conversationId,
    required String partnerId,
    required XFile imageFile,
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
}
