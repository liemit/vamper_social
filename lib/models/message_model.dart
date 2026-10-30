import 'dart:convert';

class MessageModel {
  final int id;
  final int conversationId;
  final String senderId;
  final String receiverId;
  final String messageType; // 'text', 'image', 'video', 'gift', or 'recalled'
  final String? content;
  final String? mediaUrl;
  final String? replyTo;
  final String? reaction;
  final Map<String, dynamic>? gift;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.replyTo,
    this.reaction,
    this.gift,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? gift;
    final messageType = json['message_type']?.toString() ?? 'text';
    if (messageType == 'gift' && json['content'] != null) {
      try {
        final decoded = jsonDecode(json['content'].toString());
        if (decoded is Map<String, dynamic>) gift = decoded;
      } on FormatException {
        gift = null;
      }
    }

    return MessageModel(
      id: int.parse(json['id'].toString()),
      conversationId: int.parse(json['conversation_id'].toString()),
      senderId: json['sender_id'].toString(),
      receiverId: json['receiver_id'].toString(),
      messageType: messageType,
      content: json['content']?.toString(),
      mediaUrl: json['media_url'],
      replyTo: json['reply_to'],
      reaction: json['reaction'],
      gift: gift,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
