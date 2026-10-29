import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../widgets/user_avatar_with_frame.dart';
import '../matches/create_party_screen.dart';
import '../matches/party_room_screen.dart';

class PartyTab extends StatefulWidget {
  const PartyTab({super.key});

  @override
  State<PartyTab> createState() => _PartyTabState();
}

class _PartyTabState extends State<PartyTab> {
  final AuthController _authController = Get.find<AuthController>();
  final RxList<Map<String, dynamic>> parties = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingParties = false.obs;
  String _selectedCategory = '🔥 Trending';
  String _searchQuery = '';

  final categories = ['🔥 Trending', '🎵 Music', '☕ Chill', '💕 Dating'];

  Color _partyFrameAccent(String? code) {
    switch (code) {
      case 'party_pink':
        return const Color(0xFFE94E9B);
      case 'party_royal':
        return const Color(0xFFFFC857);
      case 'party_disco':
        return const Color(0xFF31D6E8);
      case 'party_club':
        return const Color(0xFF8A6CFF);
      case 'party_palace':
        return const Color(0xFF50D6B2);
      default:
        return AppColors.primary.withValues(alpha: 0.2);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchParties();
  }

  Future<void> fetchParties() async {
    try {
      isLoadingParties.value = true;
      final response = await _authController.apiService.get(
        '${ApiConstants.baseUrl}/get-parties.php',
      );
      if (response.data['success'] == true) {
        final List data = response.data['data'] ?? [];
        final list = data.map((e) => Map<String, dynamic>.from(e)).toList();
        // Sort by participants_count descending so top popular rooms appear first
        list.sort(
          (a, b) => (b['participants_count'] ?? 0).compareTo(
            a['participants_count'] ?? 0,
          ),
        );
        parties.value = list;
      }
    } catch (e) {
      print('Error fetching parties: $e');
    } finally {
      isLoadingParties.value = false;
    }
  }

  void _handleJoinParty(Map<String, dynamic> party) {
    final userId = _authController.currentUser.value?.id.toString();
    final hostId = party['host_id']?.toString();
    final isPrivate =
        party['is_private'] == 1 ||
        party['is_private'] == '1' ||
        party['is_private'] == true;

    if (isPrivate && userId != hostId) {
      final TextEditingController passInputController = TextEditingController();
      bool obscureDialogPass = true;

      Get.dialog(
        StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.lock, color: Colors.pink),
                  SizedBox(width: 8),
                  Text('Private Party Room'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Room "${party['title']}" is protected by a password.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passInputController,
                    obscureText: obscureDialogPass,
                    decoration: InputDecoration(
                      hintText: 'Enter room password...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureDialogPass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textLight,
                        ),
                        onPressed: () {
                          setDialogState(
                            () => obscureDialogPass = !obscureDialogPass,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final password = passInputController.text.trim();
                    Get.back();
                    Get.to(
                      () => PartyRoomScreen(
                        party: party,
                        accessPassword: password,
                      ),
                    )?.then((_) => fetchParties());
                  },
                  child: const Text('Join Room'),
                ),
              ],
            );
          },
        ),
      );
    } else {
      Get.to(() => PartyRoomScreen(party: party))?.then((_) => fetchParties());
    }
  }

  List<Map<String, dynamic>> get filteredParties {
    List<Map<String, dynamic>> list = parties;
    if (_selectedCategory == '🎵 Music') {
      list = parties
          .where(
            (p) =>
                p['theme'].toString().toLowerCase().contains('music') ||
                p['theme'].toString().toLowerCase().contains('singing'),
          )
          .toList();
    } else if (_selectedCategory == '☕ Chill') {
      list = parties
          .where(
            (p) =>
                p['theme'].toString().toLowerCase().contains('chill') ||
                p['theme'].toString().toLowerCase().contains('talk'),
          )
          .toList();
    } else if (_selectedCategory == '💕 Dating') {
      list = parties
          .where(
            (p) =>
                p['theme'].toString().toLowerCase().contains('dating') ||
                p['theme'].toString().toLowerCase().contains('match'),
          )
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where(
            (p) =>
                p['title'].toString().toLowerCase().contains(q) ||
                p['host_name'].toString().toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: fetchParties,
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Create Button Banner
            FadeInDown(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Live Parties 🎉',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Join audio rooms, share screen & listen to music!',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => Get.to(
                      () => const CreatePartyScreen(),
                    )?.then((_) => fetchParties()),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text(
                      'Host Party',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Banner Promo Card
            FadeInLeft(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Broadcast Live 🎤',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Screen share, play music & chat with people in real-time!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.headset_mic_rounded,
                      color: Colors.white,
                      size: 54,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search party rooms or hosts...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textLight,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Party List
            Obx(() {
              if (isLoadingParties.value && parties.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final displayList = filteredParties;

              if (displayList.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.celebration_outlined,
                        size: 60,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No live party rooms here yet!',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Start your own party room and invite friends!',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Get.to(
                          () => const CreatePartyScreen(),
                        )?.then((_) => fetchParties()),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Party Room'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final party = displayList[index];
                  final frameAccent = _partyFrameAccent(
                    party['host_party_frame_code']?.toString(),
                  );
                  final count = party['participants_count'] ?? 1;

                  return FadeInUp(
                    duration: Duration(milliseconds: 200 + (index * 50)),
                    child: InkWell(
                      onTap: () => _handleJoinParty(party),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: frameAccent,
                            width: party['host_party_frame_code'] == null
                                ? 1
                                : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                UserAvatarWithFrame(
                                  photoUrl: party['host_photo']?.toString(),
                                  frameCode: party['host_profile_frame_code']
                                      ?.toString(),
                                  size: 56,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.mic,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (party['is_private'] == 1 ||
                                          party['is_private'] == '1' ||
                                          party['is_private'] == true) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.lock,
                                                color: Colors.amber,
                                                size: 10,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Private',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          party['title'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Host: ${party['host_name']} • ${party['theme']}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.pink,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$count',
                                        style: const TextStyle(
                                          color: Colors.pink,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Join',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
