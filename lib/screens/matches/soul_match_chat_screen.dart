import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../app/theme/app_colors.dart';

class SoulMatchChatScreen extends StatefulWidget {
  final Map<String, dynamic> partner;

  const SoulMatchChatScreen({super.key, required this.partner});

  @override
  State<SoulMatchChatScreen> createState() => _SoulMatchChatScreenState();
}

class _SoulMatchChatScreenState extends State<SoulMatchChatScreen> {
  int _remainingSeconds = 30;
  Timer? _timer;
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isActionTaken = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        if (!_isActionTaken) {
          _isActionTaken = true;
          _sendPassInBackground();
          Get.back(); // Instant exit
        }
      }
    });
  }

  void _sendPassInBackground() {
    final AuthController authController = Get.find<AuthController>();
    final userId = authController.currentUser.value?.id;
    final partnerId = widget.partner['id'].toString();

    authController.apiService.post(
      '${ApiConstants.baseUrl}/soul-match-action.php',
      data: {
        'user_id': userId,
        'partner_id': partnerId,
        'action': 'pass',
      },
    ).catchError((e) => print('Error sending pass: $e'));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final AuthController authController = Get.find<AuthController>();
    final userId = authController.currentUser.value?.id;
    final partnerId = widget.partner['id'].toString();
    if (userId == null) return;

    _msgController.clear();

    try {
      final response = await authController.apiService.post(
        ApiConstants.sendMessage,
        data: {
          'sender_id': userId,
          'receiver_id': partnerId,
          'content': text,
        },
      );

      if (response.data['success'] == true) {
        setState(() {
          _messages.add({
            'sender': 'me',
            'text': text,
            'time': DateTime.now(),
          });
        });
      } else {
        Get.snackbar('Error', response.data['message'] ?? 'Could not send message', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      print('Error sending soul match message: $e');
      Get.snackbar('Error', 'Failed to send message', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _sendAction(String action) async {
    if (_isActionTaken) return;
    setState(() {
      _isActionTaken = true;
    });
    _timer?.cancel();

    final AuthController authController = Get.find<AuthController>();
    final userId = authController.currentUser.value?.id;
    final partnerId = widget.partner['id'].toString();

    try {
      final response = await authController.apiService.post(
        '${ApiConstants.baseUrl}/soul-match-action.php',
        data: {
          'user_id': userId,
          'partner_id': partnerId,
          'action': action,
        },
      );

      if (response.data['success'] == true) {
        final bool isMutual = response.data['is_mutual'] == true;
        if (isMutual) {
          Get.dialog(
            AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.pink, size: 60),
                  const SizedBox(height: 16),
                  const Text('It\'s a Mutual Match! 🎉', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('You and ${widget.partner['full_name']} liked each other. Added to Messages!'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
                    onPressed: () {
                      Get.back(); // close dialog
                      Get.back(); // return to matches
                    },
                    child: const Text('Go to Inbox'),
                  ),
                ],
              ),
            ),
            barrierDismissible: false,
          );
        } else {
          Get.snackbar('Soul Match Ended', action == 'like' ? 'Liked! Waiting for their response.' : 'Passed.', snackPosition: SnackPosition.BOTTOM);
          Get.back();
        }
      }
    } catch (e) {
      Get.back();
    }
  }

  void _showActionDialog({bool expired = false}) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(expired ? 'Time\'s Up! ⏰' : 'Soul Match Action'),
        content: Text(expired ? 'The 30-second timer has ended. Do you want to like this person?' : 'Would you like to connect with this person?'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _sendAction('pass');
            },
            child: const Text('Pass', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink, foregroundColor: Colors.white),
            onPressed: () {
              Get.back();
              _sendAction('like');
            },
            child: const Text('Like ❤️'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _confirmLeaveChat() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Chat?'),
        content: const Text('If you leave, this chat conversation will disappear!'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Get.back(); // close dialog
              Get.back(); // exit chat
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final photoUrl = authController.getFullImageUrl(widget.partner['profile_photo']);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _confirmLeaveChat,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.partner['full_name']}, ${widget.partner['age'] ?? 20}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.partner['gender'] ?? 'Other',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 10 ? Colors.red : Colors.pink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _remainingSeconds <= 10 ? Colors.red : Colors.pink),
              ),
              child: Text(
                '0:${_remainingSeconds.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.pink : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['text'],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF161625),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Say something nice...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.pink),
                  onPressed: _sendMessage,
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _showActionDialog(expired: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
