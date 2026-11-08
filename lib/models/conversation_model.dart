class ConversationModel {
  final int conversationId;
  final String partnerId;
  final String partnerName;
  final String? partnerPhoto;
  final String? partnerProfileFrameCode;
  final String partnerGender;
  final int partnerAge;
  final bool partnerVerified;
  final String lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  ConversationModel({
    required this.conversationId,
    required this.partnerId,
    required this.partnerName,
    this.partnerPhoto,
    this.partnerProfileFrameCode,
    required this.partnerGender,
    required this.partnerAge,
    required this.partnerVerified,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: int.parse(json['conversation_id'].toString()),
      partnerId: json['partner_id'].toString(),
      partnerName: json['partner_name'] ?? 'User',
      partnerPhoto: json['partner_photo'],
      partnerProfileFrameCode: json['partner_profile_frame_code']?.toString(),
      partnerGender: json['partner_gender'] ?? 'other',
      partnerAge: int.parse((json['partner_age'] ?? 20).toString()),
      partnerVerified:
          json['partner_verified'] == true || json['partner_verified'] == 1,
      lastMessage: json['last_message'] ?? '',
      unreadCount: int.parse((json['unread_count'] ?? 0).toString()),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
