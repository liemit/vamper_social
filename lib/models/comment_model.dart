import '../core/utils/date_formatter.dart';

class CommentModel {
  final int id;
  final int postId;
  final String userId;
  final int? parentId;
  final String authorName;
  final String? authorPhoto;
  final String? replyToName;
  final String? replyToUserId;
  final String comment;
  int likesCount;
  int dislikesCount;
  String? userInteraction; // 'like', 'dislike', or null
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.authorName,
    this.authorPhoto,
    this.replyToName,
    this.replyToUserId,
    required this.comment,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.userInteraction,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: int.parse(json['id'].toString()),
      postId: int.parse(json['post_id'].toString()),
      userId: json['user_id'].toString(),
      parentId: json['parent_id'] != null ? int.parse(json['parent_id'].toString()) : null,
      authorName: json['user'] != null ? (json['user']['full_name'] ?? 'User') : (json['author_name'] ?? 'User'),
      authorPhoto: json['user'] != null ? json['user']['profile_photo'] : json['author_photo'],
      replyToName: json['reply_to_name'],
      replyToUserId: json['reply_to_user_id']?.toString(),
      comment: json['comment'] ?? '',
      likesCount: int.parse((json['likes_count'] ?? 0).toString()),
      dislikesCount: int.parse((json['dislikes_count'] ?? 0).toString()),
      userInteraction: json['user_interaction'],
      createdAt: DateFormatter.parseUtc(json['created_at'] ?? ''),
    );
  }
}
