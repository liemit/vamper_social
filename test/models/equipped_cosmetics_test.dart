import 'package:flutter_test/flutter_test.dart';
import 'package:vamper/models/conversation_model.dart';
import 'package:vamper/models/post_model.dart';
import 'package:vamper/models/user_model.dart';

void main() {
  test('UserModel reads and serializes equipped frame codes', () {
    final user = UserModel.fromJson({
      'id': 42,
      'full_name': 'Test User',
      'email': 'test@example.com',
      'is_verified': 1,
      'is_active': 1,
      'created_at': '2025-01-01 00:00:00',
      'active_profile_frame_id': 9,
      'active_party_frame_id': 12,
      'active_profile_frame_code': 'frame_gold',
      'active_party_frame_code': 'party_royal',
    });

    expect(user.activeProfileFrameCode, 'frame_gold');
    expect(user.activePartyFrameCode, 'party_royal');
    expect(user.toJson()['active_profile_frame_code'], 'frame_gold');
    expect(user.toJson()['active_party_frame_code'], 'party_royal');
  });

  test('PostModel reads the author profile frame code', () {
    final post = PostModel.fromJson({
      'id': 1,
      'user_id': 42,
      'full_name': 'Test User',
      'profile_photo': 'uploads/avatar.jpg',
      'active_profile_frame_code': 'frame_neon',
      'created_at': '2025-01-01T00:00:00Z',
    });

    expect(post.authorProfileFrameCode, 'frame_neon');
  });

  test('ConversationModel reads the partner profile frame code', () {
    final conversation = ConversationModel.fromJson({
      'conversation_id': 3,
      'partner_id': 42,
      'partner_name': 'Test User',
      'partner_profile_frame_code': 'frame_blue',
      'updated_at': '2025-01-01T00:00:00Z',
    });

    expect(conversation.partnerProfileFrameCode, 'frame_blue');
  });
}
