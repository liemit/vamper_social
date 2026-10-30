import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/profile_frame_style.dart';
import 'coin_shop_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final RxList<Map<String, dynamic>> _items = <Map<String, dynamic>>[].obs;
  final RxList<int> _ownedItemIds = <int>[].obs;
  final RxnInt _activeFrameId = RxnInt();
  final RxnInt _activeAvatarId = RxnInt();
  final RxBool _isLoading = false.obs;

  @override
  void initState() {
    super.initState();
    _fetchShopItems();
  }

  Future<void> _fetchShopItems() async {
    try {
      _isLoading.value = true;
      final response = await _authController.apiService.get(
        '${ApiConstants.baseUrl}/get-shop-items.php',
      );

      if (response.data['success'] == true) {
        final List data = response.data['items'] ?? [];
        _items.value = data.map((e) => Map<String, dynamic>.from(e)).toList();

        final List owned = response.data['owned_item_ids'] ?? [];
        _ownedItemIds.value = owned
            .map((e) => int.parse(e.toString()))
            .toList();

        _activeFrameId.value = int.tryParse(
          response.data['active_profile_frame_id']?.toString() ?? '',
        );
        _activeAvatarId.value = int.tryParse(
          response.data['active_avatar_item_id']?.toString() ?? '',
        );

        final currentUser = _authController.currentUser.value;
        if (currentUser != null) {
          await _authController.updateCachedUser(
            currentUser.copyWith(
              activeProfileFrameId: _activeFrameId.value,
              activeProfileFrameCode: response.data['active_profile_frame_code']
                  ?.toString(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching shop items: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  void _purchaseItem(Map<String, dynamic> item) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    final price = int.tryParse(item['price_coins']?.toString() ?? '') ?? 0;
    final currentCoins = _authController.currentUser.value?.coins ?? 0;
    final itemId = int.parse(item['id'].toString());

    if (currentCoins < price) {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Insufficient Coins 🪙'),
          content: Text(
            'You need $price VPC coins to buy "${item['name']}". Your current balance is $currentCoins coins.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Get.back();
                Get.to(() => const CoinShopScreen());
              },
              child: const Text('Recharge Coins'),
            ),
          ],
        ),
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(price == 0 ? 'Get Free Item 🎁' : 'Purchase Item 🛍️'),
        content: Text(
          price == 0
              ? 'Claim "${item['name']}" for FREE?'
              : 'Buy "${item['name']}" for $price VPC coins?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: price == 0 ? Colors.teal : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back();
              try {
                final response = await _authController.apiService.post(
                  '${ApiConstants.baseUrl}/purchase-item.php',
                  data: {'item_id': itemId},
                );

                if (response.data['success'] == true) {
                  if (!_ownedItemIds.contains(itemId)) {
                    _ownedItemIds.add(itemId);
                  }
                  // Update current user coins in AuthController
                  if (response.data['remaining_coins'] != null) {
                    final updatedUser = _authController.currentUser.value;
                    if (updatedUser != null) {
                      await _authController.updateCachedUser(
                        updatedUser.copyWith(
                          coins: int.parse(
                            response.data['remaining_coins'].toString(),
                          ),
                        ),
                      );
                    }
                  }
                  Get.snackbar(
                    'Acquired! 🎉',
                    'You got ${item['name']}. Equipping now...',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  await _equipItem(itemId, item['type']);
                } else {
                  Get.snackbar(
                    'Error',
                    response.data['message'] ?? 'Purchase failed',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              } catch (e) {
                print('Error purchasing item: $e');
                Get.snackbar(
                  'Purchase failed',
                  e.toString().replaceFirst('Exception: ', ''),
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: Text(price == 0 ? 'Claim Now' : 'Confirm Purchase'),
          ),
        ],
      ),
    );
  }

  Future<void> _equipItem(int itemId, String type) async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    try {
      final response = await _authController.apiService.post(
        '${ApiConstants.baseUrl}/equip-item.php',
        data: {'item_id': itemId, 'type': type},
      );

      if (response.data['success'] == true) {
        final currentUser = _authController.currentUser.value;
        if (currentUser != null) {
          if (type == 'profile_frame') {
            _activeFrameId.value = itemId;
            await _authController.updateCachedUser(
              currentUser.copyWith(
                activeProfileFrameId: itemId,
                activeProfileFrameCode: response.data['frame_code']?.toString(),
              ),
            );
          } else if (type == 'avatar') {
            final photo = response.data['profile_photo'];
            if (photo != null) {
              _activeAvatarId.value = itemId;
              await _authController.updateCachedUser(
                currentUser.copyWith(profilePhoto: photo),
              );
            }
          }
        }
        Get.snackbar(
          'Equipped! ⚡',
          'Item equipped successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Error',
          response.data['message'] ?? 'Could not equip this item',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print('Error equipping item: $e');
      Get.snackbar(
        'Could not equip item',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Item Store 🛍️',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Get.back(),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Frames 🖼️'),
              Tab(text: 'Avatars 👤'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Balance Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Obx(
                        () => Text(
                          '${_authController.currentUser.value?.coins ?? 0} VPC Coins',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => Get.to(() => const CoinShopScreen()),
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Top Up'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Store Item Grid
            Expanded(
              child: Obx(() {
                if (_isLoading.value && _items.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                return TabBarView(
                  children: [
                    _buildItemCategoryGrid('profile_frame'),
                    _buildItemCategoryGrid('avatar'),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCategoryGrid(String categoryType) {
    final filtered = _items.where((i) => i['type'] == categoryType).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.storefront_outlined,
              size: 60,
              color: AppColors.textLight,
            ),
            SizedBox(height: 12),
            Text(
              'No items in this category yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final itemId = int.parse(item['id'].toString());
        return Obx(() {
          final isOwned = _ownedItemIds.contains(itemId);
          final isEquipped = switch (categoryType) {
            'profile_frame' => _activeFrameId.value == itemId,
            'avatar' => _activeAvatarId.value == itemId,
            _ => false,
          };
          final price =
              int.tryParse(item['price_coins']?.toString() ?? '') ?? 0;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEquipped
                    ? AppColors.primary
                    : (isOwned ? Colors.green.shade300 : AppColors.border),
                width: isEquipped ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                // Item Preview
                _buildItemPreview(item),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    item['name'] ?? 'Item',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Price / Free Tag
                if (price == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      'FREE 🎉',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$price VPC',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Equipped ⚡',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (isOwned)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _equipItem(itemId, item['type']),
                    child: const Text('Equip ⚡'),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: price == 0
                          ? Colors.teal
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _purchaseItem(item),
                    child: Text(price == 0 ? 'Get Free' : 'Buy'),
                  ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildItemPreview(Map<String, dynamic> item) {
    final type = item['type'] ?? '';
    final imageUrl = item['image_url'] ?? '';
    final userPhoto = _authController.currentUser.value?.profilePhoto;

    if (type == 'avatar') {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: imageUrl.startsWith('http')
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.purple.shade100,
                    child: const Icon(
                      Icons.person,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : Container(
                  color: Colors.purple.shade100,
                  child: const Icon(
                    Icons.person,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
        ),
      );
    } else if (type == 'profile_frame') {
      final style = ProfileFrameStyle.fromCode(imageUrl);
      final gradientColors = style.colors;
      final badgeIcon = style.badge == null
          ? null
          : Positioned(
              top: style.badgeAtTop ? -4 : null,
              bottom: style.badgeAtTop ? null : -2,
              child: Text(style.badge!, style: const TextStyle(fontSize: 14)),
            );

      return SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: (userPhoto != null && userPhoto.isNotEmpty)
                      ? Image.network(
                          userPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 32,
                          color: AppColors.primary,
                        ),
                ),
              ),
            ),
            ?badgeIcon,
          ],
        ),
      );
    } else {
      // party_frame
      List<Color> frameGradient;
      String partyIcon = '🎉';

      switch (imageUrl) {
        case 'party_pink':
          frameGradient = [Colors.pinkAccent, Colors.purpleAccent];
          partyIcon = '🌸';
          break;
        case 'party_royal':
          frameGradient = [Colors.amber, Colors.yellow.shade700];
          partyIcon = '👑';
          break;
        case 'party_disco':
          frameGradient = [Colors.cyan, Colors.pinkAccent, Colors.yellow];
          partyIcon = '🪩';
          break;
        case 'party_club':
          frameGradient = [Colors.deepPurple, Colors.indigo, Colors.blue];
          partyIcon = '🎧';
          break;
        case 'party_palace':
          frameGradient = [Colors.cyan, Colors.teal, Colors.amber];
          partyIcon = '🏰';
          break;
        case 'party_simple':
        default:
          frameGradient = [Colors.grey.shade400, Colors.grey.shade200];
          partyIcon = '🎙️';
          break;
      }

      return Container(
        width: 76,
        height: 60,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: frameGradient),
          boxShadow: [
            BoxShadow(
              color: frameGradient.first.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(partyIcon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                'PARTY ROOM',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: frameGradient.first,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
