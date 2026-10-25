import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';

class PartyRoomScreen extends StatefulWidget {
  final Map<String, dynamic> party;

  const PartyRoomScreen({super.key, required this.party});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  // 10 Seats State (Seat 0 = Host, Seats 1-9 = Participants)
  late List<Map<String, dynamic>?> _seats;
  late int _viewerCount;
  bool _isMuted = false;
  bool _isScreenSharing = false;
  String? _currentMusic;
  String? _playingEffect;

  @override
  void initState() {
    super.initState();
    _viewerCount = widget.party['participants_count'] ?? 1;

    // Initialize 10 seats
    _seats = List.filled(10, null);
    // Seat 0 is always Host
    _seats[0] = {
      'id': widget.party['host_id'],
      'name': widget.party['host_name'] ?? 'Host',
      'photo': widget.party['host_photo'],
      'isHost': true,
      'isMuted': false,
    };

    _joinParty();
    _messages.add({
      'user': 'System',
      'text': 'Welcome to ${widget.party['title']}! Tap any empty seat (+) to join the conversation 🎉',
      'isSystem': true,
    });
  }

  bool get isHost {
    final userId = _authController.currentUser.value?.id.toString();
    final hostId = widget.party['host_id']?.toString();
    return userId != null && hostId != null && userId == hostId;
  }

  int? get userSeatIndex {
    final userId = _authController.currentUser.value?.id.toString();
    if (userId == null) return null;
    for (int i = 0; i < _seats.length; i++) {
      if (_seats[i] != null && _seats[i]!['id'].toString() == userId) {
        return i;
      }
    }
    return null;
  }

  bool get isUserSeated => userSeatIndex != null;

  void _joinParty() {
    _authController.apiService.post(
      '${ApiConstants.baseUrl}/join-party.php',
      data: {'party_id': widget.party['id'], 'action': 'join'},
    ).catchError((e) => print('Join party error: $e'));
  }

  void _leaveParty() {
    _authController.apiService.post(
      '${ApiConstants.baseUrl}/join-party.php',
      data: {'party_id': widget.party['id'], 'action': 'leave'},
    ).catchError((e) => print('Leave party error: $e'));
    Get.back();
  }

  void _deleteParty() async {
    final userId = _authController.currentUser.value?.id;
    if (userId == null) return;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End & Delete Party?'),
        content: const Text('This will close the party room for all participants.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Get.back(); // close dialog
              try {
                await _authController.apiService.post(
                  '${ApiConstants.baseUrl}/delete-party.php',
                  data: {
                    'party_id': widget.party['id'],
                    'host_id': userId,
                  },
                );
                Get.back(); // return to party list
                Get.snackbar('Party Ended', 'Room has been closed and deleted', snackPosition: SnackPosition.BOTTOM);
              } catch (e) {
                print('Error deleting party: $e');
              }
            },
            child: const Text('End & Delete'),
          ),
        ],
      ),
    );
  }

  void _takeSeat(int seatIndex) {
    final user = _authController.currentUser.value;
    if (user == null) return;

    final currentIndex = userSeatIndex;

    setState(() {
      if (currentIndex != null) {
        // Leave previous seat
        _seats[currentIndex] = null;
      }
      // Take new seat
      _seats[seatIndex] = {
        'id': user.id,
        'name': user.fullName ?? 'Participant',
        'photo': user.profilePhoto,
        'isHost': false,
        'isMuted': false,
      };

      _messages.add({
        'user': 'System',
        'text': '${user.fullName ?? 'Participant'} sat on Chair ${seatIndex + 1} 🪑',
        'isSystem': true,
      });
    });

    Get.snackbar('Seat Taken 🎉', 'You are now on Chair ${seatIndex + 1}. Mic activated!', snackPosition: SnackPosition.BOTTOM);
  }

  void _leaveSeat() {
    final currentIndex = userSeatIndex;
    if (currentIndex == null || currentIndex == 0) return; // Host cannot leave host seat

    final user = _authController.currentUser.value;
    setState(() {
      _seats[currentIndex] = null;
      _messages.add({
        'user': 'System',
        'text': '${user?.fullName ?? 'Participant'} left Chair ${currentIndex + 1}',
        'isSystem': true,
      });
    });

    Get.snackbar('Left Chair', 'You returned to the audience.', snackPosition: SnackPosition.BOTTOM);
  }

  void _blockUserInParty(String targetId, String targetName) async {
    final myId = _authController.currentUser.value?.id;
    if (myId == null) return;

    try {
      final response = await _authController.apiService.post(
        '${ApiConstants.baseUrl}/block-user.php',
        data: {
          'blocker_id': myId,
          'blocked_id': targetId,
          'action': 'block',
        },
      );

      if (response.data['success'] == true) {
        Get.snackbar('Blocked', '$targetName has been permanently blocked', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      print('Error blocking user in party: $e');
    }
  }

  void _handleSeatTap(int index) {
    final seatData = _seats[index];

    if (seatData == null) {
      // Empty seat -> Take seat
      _takeSeat(index);
    } else {
      final isMe = seatData['id'].toString() == _authController.currentUser.value?.id.toString();

      Get.bottomSheet(
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${seatData['name']} (Chair ${index + 1})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (isMe && index != 0) ...[
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                  title: const Text('Leave Chair'),
                  onTap: () {
                    Get.back();
                    _leaveSeat();
                  },
                ),
                ListTile(
                  leading: Icon(_isMuted ? Icons.mic : Icons.mic_off, color: Colors.blue),
                  title: Text(_isMuted ? 'Unmute Mic' : 'Mute Mic'),
                  onTap: () {
                    Get.back();
                    setState(() => _isMuted = !_isMuted);
                  },
                ),
              ],
              if (!isMe) ...[
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.redAccent),
                  title: const Text('Block User 🚫'),
                  onTap: () {
                    Get.back();
                    _blockUserInParty(seatData['id'].toString(), seatData['name'].toString());
                  },
                ),
              ],
              if (!isMe && isHost) ...[
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.red),
                  title: const Text('Remove from Chair'),
                  onTap: () {
                    Get.back();
                    setState(() => _seats[index] = null);
                    Get.snackbar('Removed', '${seatData['name']} was removed from Chair ${index + 1}', snackPosition: SnackPosition.BOTTOM);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({
        'user': _authController.currentUser.value?.fullName ?? 'Me',
        'text': text,
        'isSystem': false,
      });
    });
    _msgController.clear();
  }

  void _playSoundEffect(String effectName, String emoji) {
    setState(() => _playingEffect = '$effectName $emoji');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _playingEffect = null);
    });
  }

  void _showMusicModal() {
    final songs = [
      {'title': 'Chill Lofi Beats ☕', 'genre': 'Relaxing'},
      {'title': 'Deep House Vibe 🎧', 'genre': 'Electronic'},
      {'title': 'Romantic Acoustic 🎸', 'genre': 'Pop'},
      {'title': 'Party EDM Anthem 🔥', 'genre': 'Dance'},
    ];

    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Party Music Player 🎶', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...songs.map((song) => ListTile(
              leading: const Icon(Icons.music_note, color: Colors.pink),
              title: Text(song['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(song['genre']!),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentMusic == song['title'] ? Colors.green : Colors.pink,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() => _currentMusic = song['title']);
                  Get.back();
                  Get.snackbar('Now Playing', song['title']!, snackPosition: SnackPosition.BOTTOM);
                },
                child: Text(_currentMusic == song['title'] ? 'Playing' : 'Play'),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _toggleScreenShare() {
    setState(() {
      _isScreenSharing = !_isScreenSharing;
    });
    Get.snackbar(
      _isScreenSharing ? 'Screen Sharing Started 🖥️' : 'Screen Sharing Stopped',
      _isScreenSharing ? 'You are now broadcasting your screen to the party!' : 'Screen sharing ended.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16162B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: _leaveParty,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party['title'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Host: ${widget.party['host_name']} • Theme: ${widget.party['theme']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        actions: [
          if (isHost)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'End & Delete Party',
              onPressed: _deleteParty,
            ),
          // Real-time Eye Viewer Count Badge
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text('$_viewerCount', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.pink.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: const [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Screen Share Active Bar if sharing
          if (_isScreenSharing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.purple.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.monitor_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('🖥️ Screen Sharing Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),

          if (_currentMusic != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: Colors.pink.shade900.withOpacity(0.5),
              child: Text('🎶 Now Playing: $_currentMusic', textAlign: TextAlign.center, style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ),

          // 10-SEAT GRID LAYOUT (2 rows of 5 seats)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            color: const Color(0xFF16162B),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final seat = _seats[index];
                final isOccupied = seat != null;
                final isHostSeat = index == 0;
                final photoUrl = isOccupied ? _authController.getFullImageUrl(seat['photo']) : null;

                return InkWell(
                  onTap: () => _handleSeatTap(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOccupied ? Colors.pink.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: isHostSeat ? Colors.amber : (isOccupied ? Colors.pink : Colors.white30),
                                width: isHostSeat ? 2 : 1,
                              ),
                            ),
                            child: ClipOval(
                              child: isOccupied
                                  ? (photoUrl != null
                                      ? Image.network(photoUrl, fit: BoxFit.cover)
                                      : const Icon(Icons.person, color: Colors.white, size: 28))
                                  : const Icon(Icons.add, color: Colors.white54, size: 22),
                            ),
                          ),
                          if (isHostSeat)
                            const Positioned(
                              top: -2,
                              child: Text('👑', style: TextStyle(fontSize: 12)),
                            ),
                          if (isOccupied)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                child: Icon(
                                  seat['isMuted'] == true ? Icons.mic_off : Icons.mic,
                                  size: 10,
                                  color: seat['isMuted'] == true ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isOccupied ? seat['name'] : 'Seat ${index + 1}',
                        style: TextStyle(
                          color: isOccupied ? Colors.white : Colors.white38,
                          fontSize: 10,
                          fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Effect Pop banner if triggered
          if (_playingEffect != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
              child: Text(_playingEffect!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
            ),

          // Quick Action Toolbar (Music, Screen Share, Sound Effects)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: const Color(0xFF1A1A36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolButton(Icons.music_note, 'Music', Colors.pink, _showMusicModal),
                _buildToolButton(_isScreenSharing ? Icons.stop_screen_share : Icons.screen_share, 'Screen Share', Colors.blue, _toggleScreenShare),
                _buildToolButton(Icons.celebration, 'Applause', Colors.amber, () => _playSoundEffect('Applause!', '👏')),
                _buildToolButton(Icons.sentiment_very_satisfied, 'Laugh', Colors.orange, () => _playSoundEffect('Laughter!', '😂')),
                _buildToolButton(Icons.local_fire_department, 'Cheer', Colors.red, () => _playSoundEffect('Cheers!', '🎉')),
              ],
            ),
          ),

          // Chat & Participant Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isSystem = msg['isSystem'] == true;
                if (isSystem) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Text(msg['text'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  );
                }
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${msg['user']}: ', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(child: Text(msg['text'], style: const TextStyle(color: Colors.white, fontSize: 13))),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Input & Mic Controls
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF16162B),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isUserSeated ? (_isMuted ? Icons.mic_off : Icons.mic) : Icons.mic_none,
                      color: isUserSeated ? (_isMuted ? Colors.red : Colors.green) : Colors.white38,
                    ),
                    onPressed: () {
                      if (!isUserSeated) {
                        Get.snackbar('Take a seat', 'Tap any empty seat (+) to activate your mic and speak!', snackPosition: SnackPosition.BOTTOM);
                      } else {
                        setState(() => _isMuted = !_isMuted);
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Say something in party...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.pink),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
