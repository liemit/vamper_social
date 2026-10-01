import 'package:flutter/material.dart';
import '../core/utils/date_formatter.dart';

class PostPhoto {
  final String url;
  final double alignmentX;
  final double alignmentY;
  final double scale;

  PostPhoto({
    required this.url,
    this.alignmentX = 0.0,
    this.alignmentY = 0.0,
    this.scale = 1.0,
  });

  Alignment get alignment => Alignment(alignmentX, alignmentY);

  factory PostPhoto.fromJson(dynamic json) {
    if (json is String) {
      return PostPhoto(url: json);
    }
    return PostPhoto(
      url: json['photo_url'] ?? '',
      alignmentX: double.parse((json['alignment_x'] ?? 0.0).toString()),
      alignmentY: double.parse((json['alignment_y'] ?? 0.0).toString()),
      scale: double.parse((json['scale'] ?? 1.0).toString()),
    );
  }
}

class PostModel {
  final int id;
  final String userId;
  final String authorName;
  final String? authorPhoto;
  final String content;
  final List<PostPhoto> photos;
  final List<String> hashtags;
  int status;
  bool isLiked;
  int likesCount;
  int commentsCount;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorPhoto,
    required this.content,
    required this.photos,
    this.hashtags = const [],
    required this.status,
    required this.isLiked,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    List<PostPhoto> photos = [];
    if (json['photos'] != null) {
      photos = (json['photos'] as List).map((i) => PostPhoto.fromJson(i)).toList();
    } else if (json['images'] != null) {
      photos = (json['images'] as List).map((i) => PostPhoto.fromJson(i)).toList();
    } else if (json['image_url'] != null) {
      photos = [PostPhoto(url: json['image_url'])];
    }

    return PostModel(
      id: int.parse(json['id'].toString()),
      userId: json['user_id'].toString(),
      authorName: json['user'] != null ? (json['user']['full_name'] ?? 'User') : (json['full_name'] ?? 'User'),
      authorPhoto: json['user'] != null ? json['user']['profile_photo'] : json['profile_photo'],
      content: json['content'] ?? '',
      photos: photos,
      hashtags: List<String>.from(json['hashtags'] ?? []),
      status: int.parse((json['status'] ?? 1).toString()),
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
      likesCount: int.parse((json['likes_count'] ?? 0).toString()),
      commentsCount: int.parse((json['comments_count'] ?? 0).toString()),
      createdAt: DateFormatter.parseUtc(json['created_at'] ?? ''),
    );
  }
}
