import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../app/theme/app_colors.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_constants.dart';
import 'auth_controller.dart';
import 'package:dio/dio.dart' as dio;
import '../models/comment_model.dart';

class FeedController extends GetxController {
  final ApiService _apiService = ApiService();
  final AuthController _authController = Get.find<AuthController>();

  final RxList<PostModel> posts = <PostModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  
  int currentPage = 1;
  bool hasMore = true;
  final int pageSize = 10;

  final RxList<CommentModel> activeComments = <CommentModel>[].obs;
  final RxBool isCommentsLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPosts(isRefresh: true);
  }

  Future<void> fetchPosts({bool isRefresh = false}) async {
    if (isRefresh) {
      currentPage = 1;
      hasMore = true;
    }

    if (!hasMore || isLoadingMore.value) return;

    try {
      if (currentPage == 1) {
        isLoading.value = true;
      } else {
        isLoadingMore.value = true;
      }

      final userId = _authController.currentUser.value?.id;
      final response = await _apiService.get(
        ApiConstants.getPosts,
        params: {
          'user_id': userId,
          'page': currentPage,
          'limit': pageSize,
        },
      );

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        final newPosts = data.map((json) => PostModel.fromJson(json)).toList();

        if (newPosts.length < pageSize) {
          hasMore = false;
        }

        if (isRefresh) {
          posts.assignAll(newPosts);
        } else {
          posts.addAll(newPosts);
        }

        if (newPosts.isNotEmpty) {
          currentPage++;
        }
      }
    } catch (e) {
      print('Error fetching posts: $e');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMorePosts() async {
    await fetchPosts();
  }

  Future<List<PostModel>> fetchUserPosts(String userId) async {
    try {
      final currentUserId = _authController.currentUser.value?.id;
      final response = await _apiService.get(
        ApiConstants.getPosts,
        params: {
          'user_id': currentUserId,
          'target_user_id': userId,
        },
      );

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => PostModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching user posts: $e');
      return [];
    }
  }

  Future<bool> createPost(String content, List<XFile> images, {List<Map<String, double>>? alignments}) async {
    try {
      isLoading.value = true;
      final userId = _authController.currentUser.value?.id;
      if (userId == null) return false;

      final formData = dio.FormData.fromMap({
        'user_id': userId,
        'content': content,
        if (alignments != null) 'alignments': jsonEncode(alignments),
      });

      for (var image in images) {
        final bytes = await image.readAsBytes();
        formData.files.add(MapEntry(
          'images[]',
          dio.MultipartFile.fromBytes(bytes.toList(), filename: image.name),
        ));
      }

      final response = await _apiService.post(
        ApiConstants.createPost,
        data: formData,
      );

      if (response.data['success'] == true) {
        await fetchPosts(isRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Error creating post: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> updatePostWithPhotos({
    required int postId,
    String? content,
    int? status,
    List<XFile>? newImages,
    List<Map<String, double>>? newAlignments,
    List<String>? deleteImageUrls,
    Map<String, Map<String, double>>? updateAlignments,
  }) async {
    try {
      isLoading.value = true;
      final userId = _authController.currentUser.value?.id;
      if (userId == null) return false;

      final formData = dio.FormData.fromMap({
        'user_id': userId,
        'post_id': postId,
        if (content != null) 'content': content,
        if (status != null) 'status': status,
        if (deleteImageUrls != null) 'delete_photos': jsonEncode(deleteImageUrls),
        if (newAlignments != null) 'new_alignments': jsonEncode(newAlignments),
        if (updateAlignments != null) 'update_alignments': jsonEncode(updateAlignments),
      });

      if (newImages != null) {
        for (var image in newImages) {
          final bytes = await image.readAsBytes();
          formData.files.add(MapEntry(
            'images[]',
            dio.MultipartFile.fromBytes(bytes.toList(), filename: image.name),
          ));
        }
      }

      final response = await _apiService.post(
        '$postId/update',
        data: formData,
      );

      if (response.data['success'] == true) {
        await fetchPosts(isRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating post: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleLike(PostModel post) async {
    try {
      final userId = _authController.currentUser.value?.id;
      if (userId == null) return;

      post.isLiked = !post.isLiked;
      post.likesCount += post.isLiked ? 1 : -1;
      posts.refresh();

      final response = await _apiService.post(
        ApiConstants.likePost,
        data: {
          'user_id': userId,
          'post_id': post.id,
        },
      );

      if (response.data['success'] != true) {
        post.isLiked = !post.isLiked;
        post.likesCount += post.isLiked ? 1 : -1;
        posts.refresh();
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<bool> deletePost(int postId) async {
    try {
      final userId = _authController.currentUser.value?.id;
      if (userId == null) return false;

      final response = await _apiService.post(
        '${ApiConstants.baseUrl}/posts/$postId/delete',
        data: {'user_id': userId},
      );

      if (response.data['success'] == true) {
        posts.removeWhere((p) => p.id == postId);
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }

  Future<bool> reportPost(int postId, String reason, String description) async {
    try {
      final userId = _authController.currentUser.value?.id;
      if (userId == null) return false;

      final response = await _apiService.post(
        '${ApiConstants.baseUrl}/report-post.php',
        data: {
          'user_id': userId,
          'post_id': postId,
          'reason': reason,
          'description': description,
        },
      );

      if (response.data['success'] == true) {
        Get.snackbar(
          'Report Submitted',
          response.data['message'] ?? 'Thank you for your report.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Error reporting post: $e');
      Get.snackbar(
        'Error',
        'Failed to submit report. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<void> fetchComments(int postId) async {
    try {
      isCommentsLoading.value = true;
      activeComments.clear();
      
      final response = await _apiService.get(
        ApiConstants.getComments,
        params: {
          'post_id': postId,
          'user_id': _authController.currentUser.value?.id,
        },
      );

      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        activeComments.assignAll(data.map((json) => CommentModel.fromJson(json)).toList());
      }
    } catch (e) {
      print('Error fetching comments: $e');
    } finally {
      isCommentsLoading.value = false;
    }
  }

  Future<bool> addComment(int postId, String text, {int? parentId}) async {
    final user = _authController.currentUser.value;
    if (user == null || text.trim().isEmpty) return false;

    try {
      final response = await _apiService.post(
        ApiConstants.addComment,
        data: {
          'user_id': user.id,
          'post_id': postId,
          'comment': text.trim(),
          if (parentId != null) 'parent_id': parentId,
        },
      );

      if (response.data['success'] == true) {
        final newComment = CommentModel.fromJson(response.data['data']);
        activeComments.add(newComment);
        
        final postIndex = posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          posts[postIndex].commentsCount++;
          posts.refresh();
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  Future<void> toggleCommentInteraction(int commentId, String type) async {
    final user = _authController.currentUser.value;
    if (user == null) return;

    try {
      final response = await _apiService.post(
        ApiConstants.commentInteraction,
        data: {
          'user_id': user.id,
          'comment_id': commentId,
          'type': type,
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final index = activeComments.indexWhere((c) => c.id == commentId);
        if (index != -1) {
          activeComments[index].userInteraction = data['user_interaction'];
          activeComments[index].likesCount = data['likes_count'];
          activeComments[index].dislikesCount = data['dislikes_count'];
          activeComments.refresh();
        }
      }
    } catch (e) {
      print('Error toggling comment interaction: $e');
    }
  }
}
