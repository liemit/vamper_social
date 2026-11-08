import 'package:flutter/material.dart';

class VpcCoinIcon extends StatelessWidget {
  final double size;

  const VpcCoinIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Text(
      '\u{1FA99}',
      style: TextStyle(fontSize: size, height: 1),
      semanticsLabel: 'VPC coin',
    );
  }
}
