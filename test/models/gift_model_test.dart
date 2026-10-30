import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vamper/models/gift_model.dart';
import 'package:vamper/models/message_model.dart';

void main() {
  test('GiftModel reads catalog entries and creates unique request IDs', () {
    final gift = GiftModel.fromJson({
      'id': 7,
      'gift_key': 'rose',
      'name': 'Rose',
      'emoji': '🌹',
      'price_coins': 10,
    });

    expect(gift.id, 7);
    expect(gift.name, 'Rose');
    expect(gift.priceCoins, 10);

    final requestId = GiftModel.createRequestId();
    expect(requestId, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(GiftModel.createRequestId(), isNot(requestId));
  });

  test('MessageModel decodes gift message details', () {
    final message = MessageModel.fromJson({
      'id': 12,
      'conversation_id': 3,
      'sender_id': 5,
      'receiver_id': 8,
      'message_type': 'gift',
      'content': jsonEncode({
        'transaction_id': 41,
        'gift_id': 7,
        'name': 'Rose',
        'emoji': '🌹',
        'price_coins': 10,
      }),
      'is_read': 0,
      'already_processed': 1,
      'created_at': '2026-10-30 01:00:00',
    });

    expect(message.messageType, 'gift');
    expect(message.gift?['transaction_id'], 41);
    expect(message.gift?['emoji'], '🌹');
    expect(message.gift?['price_coins'], 10);
    expect(message.alreadyProcessed, isTrue);
  });
}
