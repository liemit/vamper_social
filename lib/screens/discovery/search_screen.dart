import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import '../../widgets/user_avatar_with_frame.dart';
import '../profile/profile_preview_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>> _userResults = [];
  List<PostModel> _postResults = [];
  bool _isLoading = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _activeQuery = '';
        _userResults.clear();
        _postResults.clear();
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _activeQuery = trimmed;
      _isLoading = true;
    });

    final currentUserId = _authController.currentUser.value?.id;

    try {
      final response = await _authController.apiService.get(
        ApiConstants.searchGlobal,
        params: {'q': trimmed, 'user_id': currentUserId},
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final List rawUsers = data['users'] ?? [];
        final List rawPosts = data['posts'] ?? [];

        setState(() {
          _userResults = List<Map<String, dynamic>>.from(rawUsers);
          _postResults = rawPosts.map((p) => PostModel.fromJson(p)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _performSearch,
            onChanged: (val) {
              if (val.trim().isEmpty) _performSearch('');
            },
            decoration: InputDecoration(
              hintText: 'Search people, posts, email...',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppColors.textLight,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'People'),
            Tab(text: 'Posts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _activeQuery.isEmpty
          ? _buildInitialState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllResultsTab(),
                _buildUsersTab(),
                _buildPostsTab(),
              ],
            ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.manage_search_rounded, size: 80, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            'Smart Search',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search for people by name/email or explore post moments.',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAllResultsTab() {
    if (_userResults.isEmpty && _postResults.isEmpty) {
      return _buildNoResults();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_userResults.isNotEmpty) ...[
            const Text(
              'People',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._userResults.take(3).map((u) => _buildUserCard(u)),
            const SizedBox(height: 16),
          ],
          if (_postResults.isNotEmpty) ...[
            const Text(
              'Moments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._postResults.map((p) => PostCard(post: p)),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_userResults.isEmpty) return _buildNoResults();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userResults.length,
      itemBuilder: (context, index) => _buildUserCard(_userResults[index]),
    );
  }

  Widget _buildPostsTab() {
    if (_postResults.isEmpty) return _buildNoResults();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _postResults.length,
      itemBuilder: (context, index) => PostCard(post: _postResults[index]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatarWithFrame(
          photoUrl: user['profile_photo']?.toString(),
          frameCode: user['active_profile_frame_code']?.toString(),
          size: 48,
        ),
        title: Row(
          children: [
            Text(
              user['full_name'] ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 4),
            if (user['is_verified'] == 1)
              const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
          ],
        ),
        subtitle: Text(
          user['email'] ?? '',
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
        onTap: () {
          Get.to(() => ProfilePreviewScreen(userId: user['id'].toString()));
        },
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 12),
          Text(
            'No results for "$_activeQuery"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try searching with a different keyword or email.',
            style: TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
