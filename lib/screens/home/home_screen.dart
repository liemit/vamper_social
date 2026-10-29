import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../widgets/vamper_logo.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/match_hub_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../models/post_model.dart';
import '../../widgets/post_card.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/profile_preview_screen.dart';
import '../auth/login_screen.dart';
import 'create_post_screen.dart';
import 'swipe_cards_screen.dart';
import '../wallet/coin_shop_screen.dart';
import '../discovery/search_screen.dart';
import '../chat/conversations_screen.dart';
import '../../controllers/chat_controller.dart';
import '../matches/create_party_screen.dart';
import '../matches/party_room_screen.dart';
import 'party_tab.dart';
import '../wallet/store_screen.dart';
import '../../widgets/user_avatar_with_frame.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isFabVisible = true;
  final AuthController _authController = Get.find<AuthController>();
  final DiscoveryController _discoveryController = Get.put(DiscoveryController());
  final ChatController _chatController = Get.put(ChatController());

  final List<Widget> _screens = [
    const DiscoveryTab(),
    const MatchesTab(),
    const PartyTab(),
    const ConversationsScreen(),
    const ProfileTab(),
  ];

  void _showFilterSheet(BuildContext context) {
    _discoveryController.openFilters();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(controller: _discoveryController),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollUpdateNotification) {
          if (scrollNotification.scrollDelta! > 10 && _isFabVisible) {
            setState(() => _isFabVisible = false);
          } else if (scrollNotification.scrollDelta! < -10 && !_isFabVisible) {
            setState(() => _isFabVisible = true);
          }
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const VamperLogoSmall(size: 28),
          centerTitle: true,
          actions: [
            // VPC Coin Display
            Obx(() {
              final coins = _authController.currentUser.value?.coins ?? 0;
              return InkWell(
                onTap: () => Get.to(() => const CoinShopScreen()),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        coins.toString(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textPrimary),
              onPressed: () => Get.to(() => const SearchScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.tune, color: AppColors.textPrimary),
              onPressed: () => _showFilterSheet(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _screens[_currentIndex],
        floatingActionButton: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isFabVisible ? 1.0 : 0.0,
            child: FloatingActionButton(
              onPressed: () => Get.to(() => const CreatePostScreen()),
              backgroundColor: Colors.transparent,
              elevation: 4,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Discover',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavBarItem(
                  icon: Icons.favorite_border,
                  activeIcon: Icons.favorite,
                  label: 'Matches',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavBarItem(
                  icon: Icons.celebration_outlined,
                  activeIcon: Icons.celebration,
                  label: 'Party',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                Obx(() => _NavBarItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Messages',
                  isActive: _currentIndex == 3,
                  hasRedDot: _chatController.hasUnreadMessages,
                  onTap: () => setState(() => _currentIndex = 3),
                )),
                _NavBarItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isActive: _currentIndex == 4,
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool hasRedDot;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.hasRedDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? Colors.white : AppColors.textLight,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? Colors.white : AppColors.textLight,
                  ),
                ),
              ],
            ),
            if (hasRedDot && !isActive)
              Positioned(
                right: 4,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TABS IMPLEMENTATION
// ==========================================

// 1. Discovery Tab (Moments Feed)
class DiscoveryTab extends StatefulWidget {
  const DiscoveryTab({super.key});

  @override
  State<DiscoveryTab> createState() => _DiscoveryTabState();
}

class _DiscoveryTabState extends State<DiscoveryTab> {
  final ScrollController _scrollController = ScrollController();
  final FeedController feedController = Get.put(FeedController());

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      feedController.loadMorePosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => feedController.fetchPosts(isRefresh: true),
      color: AppColors.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Obx(() {
            if (feedController.isLoading.value && feedController.posts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (feedController.posts.isEmpty) {
              return SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.auto_awesome, size: 80, color: AppColors.border),
                    const SizedBox(height: 16),
                    const Text('No moments shared yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('Be the first to share a moment!', style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: feedController.posts.length + (feedController.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == feedController.posts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  );
                }
                return PostCard(post: feedController.posts[index]);
              },
            );
          }),
        ),
      ),
    );
  }
}

// 2. Matches Tab
class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final MatchHubController hubController = Get.put(MatchHubController());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: const Text(
              'Find Your Match',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Random Interactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _MatchGameButton(
                label: 'Soul Match',
                icon: Icons.chat_bubble_rounded,
                color: const Color(0xFFFF6B9D),
                onTap: () => hubController.startSoulMatch(),
              ),
              const SizedBox(width: 12),
              _MatchGameButton(
                label: 'Voice Match',
                icon: Icons.mic_rounded,
                color: const Color(0xFF74B9FF),
                onTap: () => hubController.startVoiceMatch(),
              ),
              const SizedBox(width: 12),
              _MatchGameButton(
                label: 'Lover Card',
                icon: Icons.auto_awesome_motion_rounded,
                color: const Color(0xFFFDCB6E),
                onTap: () => Get.to(() => const SwipeCardsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Daily Discovery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FadeInLeft(
            child: InkWell(
              onTap: () => Get.to(() => const SwipeCardsScreen()),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(right: -20, bottom: -20, child: Icon(Icons.favorite, size: 150, color: Colors.white.withValues(alpha: 0.2))),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Start Swiping', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Find people near you right now', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Your Matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 80,
                  decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.person, color: AppColors.textLight, size: 40)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchGameButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MatchGameButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. Messages Tab
class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text('No Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text('Match with someone to start chatting!', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Profile Tab
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return FadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Obx(() {
              final user = authController.currentUser.value;
              return UserAvatarWithFrame(
                photoUrl: user?.profilePhoto,
                frameId: user?.activeProfileFrameId,
                size: 110,
              );
            }),
            const SizedBox(height: 16),
            Obx(() => Text(authController.currentUser.value?.fullName ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
            const SizedBox(height: 8),
            Obx(() => Text(authController.currentUser.value?.email ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                final userId = authController.currentUser.value?.id;
                if (userId != null) {
                  Get.to(() => ProfilePreviewScreen(userId: userId));
                }
              },
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text('View Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
            _ProfileMenuItem(icon: Icons.storefront, title: 'Item Store 🛍️', onTap: () => Get.to(() => const StoreScreen())),
            _ProfileMenuItem(icon: Icons.edit, title: 'Edit Profile', onTap: () => Get.to(() => const EditProfileScreen())),
            _ProfileMenuItem(icon: Icons.settings, title: 'Settings', onTap: () {}),
            _ProfileMenuItem(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}),
            _ProfileMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              iconColor: AppColors.error,
              titleColor: AppColors.error,
              onTap: () {
                Get.dialog(
                  AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          authController.logout();
                          Get.offAll(() => const LoginScreen());
                        },
                        child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _ProfileMenuItem({required this.icon, required this.title, required this.onTap, this.iconColor, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary))),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  final DiscoveryController controller;

  const _FilterSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => controller.resetFilters(), child: const Text('Reset')),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Maximum Distance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Obx(() => Text('${controller.tempDistance.value.toInt()} km', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
            ],
          ),
          Obx(() => Slider(
            value: controller.tempDistance.value,
            min: 1,
            max: 100,
            activeColor: AppColors.primary,
            onChanged: (val) => controller.tempDistance.value = val,
          )),
          const SizedBox(height: 24),
          const Text('Show Me', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Obx(() => Row(
            children: [
              _FilterChip(label: 'Men', isSelected: controller.tempGender.value == 'male', onTap: () => controller.tempGender.value = 'male'),
              const SizedBox(width: 8),
              _FilterChip(label: 'Women', isSelected: controller.tempGender.value == 'female', onTap: () => controller.tempGender.value = 'female'),
              const SizedBox(width: 8),
              _FilterChip(label: 'Both', isSelected: controller.tempGender.value == 'both', onTap: () => controller.tempGender.value = 'both'),
            ],
          )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Age Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Obx(() => Text('${controller.tempAge.value.start.toInt()} - ${controller.tempAge.value.end.toInt()}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
            ],
          ),
          Obx(() => RangeSlider(
            values: controller.tempAge.value,
            min: 18,
            max: 80,
            activeColor: AppColors.primary,
            onChanged: (val) => controller.tempAge.value = val,
          )),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              controller.applyFilters();
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
