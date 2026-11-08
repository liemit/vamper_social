import 'package:flutter_test/flutter_test.dart';
import 'package:vamper/models/conversation_model.dart';
import 'package:vamper/models/message_model.dart';

void main() {
  test('ConversationModel reads online status from PHP JSON values', () {
    final online = ConversationModel.fromJson({
      'conversation_id': 3,
      'partner_id': 8,
      'partner_name': 'Alex',
      'partner_gender': 'other',
      'partner_age': 24,
      'partner_verified': 0,
      'partner_is_online': '1',
      'last_message': 'Hello',
      'unread_count': 0,
      'updated_at': '2026-11-08 18:00:00',
    });
    final offline = ConversationModel.fromJson({
      'conversation_id': 4,
      'partner_id': 9,
      'partner_name': 'Sam',
      'partner_gender': 'other',
      'partner_age': 25,
      'partner_verified': 0,
      'partner_is_online': '0',
      'last_message': 'Hi',
      'unread_count': 0,
      'updated_at': '2026-11-08 18:00:00',
    });

    expect(online.partnerIsOnline, isTrue);
    expect(offline.partnerIsOnline, isFalse);
  });

  test('MessageModel parses read status returned as a numeric string', () {
    final message = MessageModel.fromJson({
      'id': 12,
      'conversation_id': 3,
      'sender_id': 5,
      'receiver_id': 8,
      'message_type': 'text',
      'content': 'Hello',
      'is_read': '1',
      'created_at': '2026-11-08 18:00:00',
    });

    expect(message.isRead, isTrue);
  });
}
