import 'dart:math';

class GiftModel {
  final int id;
  final String key;
  final String name;
  final String emoji;
  final int priceCoins;

  const GiftModel({
    required this.id,
    required this.key,
    required this.name,
    required this.emoji,
    required this.priceCoins,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      id: int.parse(json['id'].toString()),
      key: json['gift_key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎁',
      priceCoins: int.parse(json['price_coins'].toString()),
    );
  }

  static String createRequestId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
