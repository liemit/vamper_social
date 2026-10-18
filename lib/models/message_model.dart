class MessageModel {
  final int id;
  final int conversationId;
  final String senderId;
  final String receiverId;
  final String messageType; // 'text', 'image'
  final String? content;
  final String? mediaUrl;
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
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: int.parse(json['id'].toString()),
      conversationId: int.parse(json['conversation_id'].toString()),
      senderId: json['sender_id'].toString(),
      receiverId: json['receiver_id'].toString(),
      messageType: json['message_type'] ?? 'text',
      content: json['content'],
      mediaUrl: json['media_url'],
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
