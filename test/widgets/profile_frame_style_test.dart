import 'package:flutter_test/flutter_test.dart';
import 'package:vamper/widgets/profile_frame_style.dart';

void main() {
  test('new shop frame codes resolve to distinct visual styles', () {
    final rose = ProfileFrameStyle.fromCode('frame_rose');
    final ice = ProfileFrameStyle.fromCode('frame_ice');
    final holo = ProfileFrameStyle.fromCode('frame_holo');
    final solar = ProfileFrameStyle.fromCode('frame_solar');

    expect(rose.badge, '🌹');
    expect(ice.badge, '❄️');
    expect(holo.colors, hasLength(4));
    expect(solar.badgeAtTop, isFalse);
    expect(rose.colors.first, isNot(ice.colors.first));
  });
}
