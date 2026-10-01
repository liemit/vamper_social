import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import '../home/home_screen.dart';

class ProfilePreviewScreen extends StatefulWidget {
  final String userId;

  const ProfilePreviewScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ProfilePreviewScreen> createState() => _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends State<ProfilePreviewScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final FeedController _feedController = Get.find<FeedController>();
  
  final Rx<UserModel?> _viewedUser = Rx<UserModel?>(null);
  final RxList<PostModel> _userPosts = <PostModel>[].obs;
  final RxBool _isLocalLoading = true.obs;
  final RxBool _isFollowing = false.obs;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    _isLocalLoading.value = true;
    
    // 1. Fetch basic profile info
    final profile = await _authController.fetchUserProfile(widget.userId);
    _viewedUser.value = profile;
    
    // 2. Fetch user's moments (posts)
    final posts = await _feedController.fetchUserPosts(widget.userId);
    _userPosts.assignAll(posts);

    // 3. Check follow status (if not self)
    if (widget.userId != _authController.currentUser.value?.id) {
      _isFollowing.value = await _authController.isFollowing(widget.userId);
    }
    
    _isLocalLoading.value = false;
  }

  void _handleFollowToggle() async {
    final success = await _authController.toggleFollow(widget.userId);
    if (success) {
      _isFollowing.value = !_isFollowing.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Obx(() {
      if (_isLocalLoading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final user = _viewedUser.value;
      if (user == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('User not found')),
        );
      }

      final bool isSelf = user.id == _authController.currentUser.value?.id;
      
      return Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),
          actions: [
            if (!isSelf)
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {},
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Photo
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final photoUrl = _authController.getFullImageUrl(user.profilePhoto);
                          if (photoUrl != null) _authController.showImageDetail(photoUrl);
                        },
                        child: Hero(
                          tag: 'profile_photo_${user.id}',
                          child: Container(
                            height: size.height * 0.6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.border.withOpacity(0.1),
                            ),
                            child: Builder(builder: (context) {
                              final photoUrl = _authController.getFullImageUrl(user.profilePhoto);
                              if (photoUrl != null) {
                                return Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
                                );
                              }
                              return _buildPlaceholderIcon();
                            }),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.1),
                                Colors.black.withOpacity(0.8),
                              ],
                              stops: const [0.6, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        left: 20,
                        right: 20,
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.fullName,
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                  ),
                                  if (user.age != null) ...[
                                    const SizedBox(width: 8),
                                    Text('${user.age}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w400)),
                                  ],
                                  const SizedBox(width: 8),
                                  if (user.isVerified)
                                    const Icon(Icons.verified, color: AppColors.info, size: 24),
                                ],
                              ),
                              if (user.location != null && user.location!.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                    const SizedBox(width: 4),
                                    Text(user.location!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2. About
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('About Me', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        Text(
                          (user.bio != null && user.bio!.isNotEmpty) ? user.bio! : "This user hasn't added a bio yet.",
                          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 3. Basics
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Basics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.person_outline, 'Gender', user.gender?.capitalizeFirst ?? 'Not specified'),
                        _buildInfoRow(Icons.cake_outlined, 'Birthday', user.dateOfBirth ?? 'Not specified'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 4. Moments (Posts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Moments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        if (_userPosts.isEmpty)
                          _buildEmptyPlaceholder('No moments shared yet.')
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _userPosts.length,
                            itemBuilder: (context, index) => PostCard(post: _userPosts[index]),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120), // Padding for sticky buttons
                ],
              ),
            ),

            // Sticky Interaction Buttons (If not self)
            if (!isSelf)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleFollowToggle,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: _isFollowing.value ? Colors.white : AppColors.primary,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.primary, width: 2),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
                          ),
                          child: Center(
                            child: Text(
                              _isFollowing.value ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: _isFollowing.value ? AppColors.primary : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        onPressed: () {
                          // TODO: Open direct chat
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyPlaceholder(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.border.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.layers_clear_outlined, color: AppColors.textLight, size: 40),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(child: Icon(Icons.person, size: 100, color: AppColors.textLight.withOpacity(0.5)));
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
              Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
