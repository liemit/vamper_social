import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vamper/widgets/gift_celebration_overlay.dart';

void main() {
  testWidgets('gift celebration scales its presentation by gift value', (
    tester,
  ) async {
    Future<void> pumpGift(int price) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GiftCelebrationOverlay(
              gift: {
                'name': 'Gift',
                'emoji': '🎁',
                'price_coins': price,
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }

    await pumpGift(50);
    expect(find.text('A GIFT FOR YOU'), findsOneWidget);

    await pumpGift(100);
    expect(find.text('SPECIAL GIFT!'), findsOneWidget);

    await pumpGift(500);
    expect(find.text('MEGA GIFT!'), findsOneWidget);
    expect(find.text('500 VPC'), findsOneWidget);
  });
}
