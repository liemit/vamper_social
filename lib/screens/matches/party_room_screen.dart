import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';
import '../../models/gift_model.dart';
import '../../widgets/user_avatar_with_frame.dart';
import '../wallet/coin_shop_screen.dart';

class PartyRoomScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  final String? accessPassword;

  const PartyRoomScreen({super.key, required this.party, this.accessPassword});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _participants = [];

  // 10 Seats State (Seat 0 = Host, Seats 1-9 = Participants)
  late List<Map<String, dynamic>?> _seats;
  int get _viewerCount => _participants.isEmpty ? 1 : _participants.length;

  bool _isMuted = true;
  bool _isScreenSharing = false;
  bool _canShareScreen = false;
  bool _isMicLocked = false;
  String? _playingEffect;
  final Map<String, String> _seatEffects = {};
  final Map<String, int> _seatEffectVersions = {};
  bool _isCohost = false;
  bool _isJoining = true;
  bool _roomConnected = false;
  bool _hasJoinedParty = false;
  bool _isHandRaised = false;
  bool _isLeaving = false;
  bool _isSyncing = false;
  bool _isSendingGift = false;
  final Map<String, String> _pendingGiftRequestIds = {};
  String? _roomStatus;
  int _lastMessageId = 0;
  int _lastEventId = 0;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();

    // Initialize 10 seats
    _seats = List.filled(10, null);

    final currentUserId = _authController.currentUser.value?.id.toString();
    final hostId = widget.party['host_id']?.toString();
    final hostPhoto =
        (currentUserId != null && hostId != null && currentUserId == hostId)
        ? _authController.currentUser.value?.profilePhoto
        : widget.party['host_photo'];

    // Seat 0 is always Host
    _seats[0] = {
      'id': widget.party['host_id'],
      'name': widget.party['host_name'] ?? 'Host',
      'photo': hostPhoto,
      'frameCode': currentUserId == hostId
          ? _authController.currentUser.value?.activeProfileFrameCode
          : widget.party['host_profile_frame_code'],
      'isHost': true,
      'isMuted': false,
    };

    unawaited(_joinParty());
    _messages.add({
      'user': 'System',
      'text':
          'Welcome to ${widget.party['title']}! Tap any empty seat (+) to join the conversation 🎉',
      'isSystem': true,
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    unawaited(_disconnectParty());
    super.dispose();
  }

  bool get isHost {
    final userId = _authController.currentUser.value?.id.toString();
    final hostId = widget.party['host_id']?.toString();
    return userId != null && hostId != null && userId == hostId;
  }

  bool get _canModerate => isHost || _isCohost;

  List<Color> get _partyBackgroundColors {
    return [const Color(0xFF0F0F1A), const Color(0xFF16162B)];
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

  Future<Map<String, dynamic>> _partyAction(
    String action, {
    Map<String, dynamic> payload = const {},
  }) async {
    final response = await _authController.apiService.post(
      '${ApiConstants.baseUrl}/party-room.php',
      data: {'party_id': widget.party['id'], 'action': action, ...payload},
    );
    if (response.data is! Map) {
      throw StateError('The party service returned an invalid response.');
    }
    final body = Map<String, dynamic>.from(response.data as Map);
    if (body['success'] != true) {
      throw StateError(body['message']?.toString() ?? 'Party request failed.');
    }
    return body;
  }

  Future<void> _joinParty() async {
    try {
      final response = await _partyAction(
        'join',
        payload: {'password': widget.accessPassword},
      );
      _hasJoinedParty = true;
      _canShareScreen = response['can_share_screen'] == true;
      _isMicLocked = response['is_mic_locked'] == true;
      if (!mounted || _isLeaving) {
        await _partyAction('leave');
        _hasJoinedParty = false;
        return;
      }
      final liveKitUrl = response['livekit_url']?.toString();
      final liveKitToken = response['livekit_token']?.toString();

      if (liveKitUrl != null &&
          liveKitUrl.isNotEmpty &&
          liveKitToken != null &&
          liveKitToken.isNotEmpty) {
        await _connectLiveKit(liveKitUrl, liveKitToken);
      } else {
        _roomStatus =
            response['message']?.toString() ??
            'Voice and screen sharing need LiveKit credentials on the server.';
        if (mounted) {
          Get.snackbar(
            'Voice and screen share unavailable',
            _roomStatus!,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 6),
          );
        }
      }

      _syncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_syncParty()),
      );
      await _syncParty();
    } catch (error) {
      debugPrint('Unable to join party: $error');
      if (mounted) {
        final errorMessage = error.toString().replaceFirst('Bad state: ', '');
        final details = errorMessage.toLowerCase().contains('network error')
            ? '$errorMessage. Check the API connection and deploy party-room.php to the configured server.'
            : errorMessage;
        Get.snackbar(
          'Unable to join party',
          details,
          snackPosition: SnackPosition.BOTTOM,
        );
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (mounted) Get.back();
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _refreshRoomView() {
    if (mounted) setState(() {});
  }

  Future<void> _connectLiveKit(String url, String token) async {
    final oldRoom = _room;
    _room = null;
    _roomConnected = false;
    _roomListener?.dispose();
    _roomListener = null;
    if (oldRoom != null) {
      try {
        await oldRoom.disconnect();
      } finally {
        await oldRoom.dispose();
      }
    }

    final room = Room();
    _room = room;
    _roomListener = room.createListener()
      ..on<ParticipantConnectedEvent>((_) => _refreshRoomView())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshRoomView())
      ..on<TrackSubscribedEvent>((_) => _refreshRoomView())
      ..on<TrackUnsubscribedEvent>((_) => _refreshRoomView())
      ..on<LocalTrackPublishedEvent>((_) => _refreshRoomView())
      ..on<LocalTrackUnpublishedEvent>((_) => _refreshRoomView())
      ..on<TrackMutedEvent>((_) => _refreshRoomView())
      ..on<TrackUnmutedEvent>((_) => _refreshRoomView())
      ..on<RoomReconnectedEvent>((_) {
        _roomConnected = true;
        _roomStatus = null;
        _refreshRoomView();
      })
      ..on<RoomDisconnectedEvent>((_) {
        _roomConnected = false;
        _roomStatus = 'Disconnected from party voice and screen sharing.';
        _refreshRoomView();
      });
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await AudioManager.instance.setSpeakerOutputPreferred(true);
    }
    await room.connect(url, token);
    _roomConnected = true;
    _roomStatus = null;
    if (!_isMuted && !_isMicLocked) {
      await room.localParticipant?.setMicrophoneEnabled(true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshMediaToken() async {
    try {
      final response = await _partyAction('refresh_token');
      final url = response['livekit_url']?.toString();
      final token = response['livekit_token']?.toString();
      if (url == null || url.isEmpty || token == null || token.isEmpty) {
        throw StateError('The party service did not return a LiveKit token.');
      }
      _canShareScreen = response['can_share_screen'] == true;
      _isMicLocked = response['is_mic_locked'] == true;
      if (response['can_publish'] != true || _isMicLocked) {
        _isMuted = true;
      }
      await _connectLiveKit(url, token);
    } catch (error) {
      debugPrint('Unable to refresh LiveKit token: $error');
      Get.snackbar(
        'Unable to update voice access',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _syncParty() async {
    if (!_hasJoinedParty || _isLeaving || _isSyncing) return;
    _isSyncing = true;
    try {
      final response = await _partyAction(
        'sync',
        payload: {
          'after_message_id': _lastMessageId,
          'after_event_id': _lastEventId,
        },
      );
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final participants = (data['participants'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final updatedSeats = List<Map<String, dynamic>?>.filled(10, null);
      for (final participant in participants) {
        final seatIndex = int.tryParse(
          participant['seat_index']?.toString() ?? '',
        );
        if (seatIndex == null ||
            seatIndex < 0 ||
            seatIndex >= updatedSeats.length) {
          continue;
        }
        final identity = participant['user_id'].toString();
        final liveParticipant = _room?.remoteParticipants[identity];
        updatedSeats[seatIndex] = {
          'id': participant['user_id'],
          'name': participant['full_name'] ?? 'Participant',
          'photo': participant['profile_photo'],
          'frameCode': participant['active_profile_frame_code'],
          'isHost':
              int.tryParse(participant['user_id'].toString()) ==
              int.tryParse(widget.party['host_id'].toString()),
          'isMuted':
              identity == _authController.currentUser.value?.id.toString()
              ? _isMuted
              : (liveParticipant?.isMuted ?? true),
          'isHandRaised':
              participant['is_hand_raised'] == 1 ||
              participant['is_hand_raised'] == '1',
          'isCohost':
              participant['is_cohost'] == 1 || participant['is_cohost'] == '1',
          'canShareScreen':
              participant['can_share_screen'] == true ||
              participant['can_share_screen'] == 1 ||
              participant['can_share_screen'] == '1',
          'isMicLocked':
              participant['is_mic_locked'] == true ||
              participant['is_mic_locked'] == 1 ||
              participant['is_mic_locked'] == '1',
        };
      }

      final self = Map<String, dynamic>.from(data['self'] as Map);
      final isRaised =
          self['is_hand_raised'] == true ||
          self['is_hand_raised'] == 1 ||
          self['is_hand_raised'] == '1';
      final isCohost =
          self['is_cohost'] == true ||
          self['is_cohost'] == 1 ||
          self['is_cohost'] == '1';
      final canShareScreen =
          self['can_share_screen'] == true ||
          self['can_share_screen'] == 1 ||
          self['can_share_screen'] == '1';
      final isMicLocked =
          self['is_mic_locked'] == true ||
          self['is_mic_locked'] == 1 ||
          self['is_mic_locked'] == '1';
      final permissionsChanged =
          canShareScreen != _canShareScreen || isMicLocked != _isMicLocked;
      final newMessages = (data['messages'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final newEvents = (data['events'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _participants
          ..clear()
          ..addAll(participants);
        _seats = updatedSeats;
        _isCohost = isCohost;
        _isHandRaised = isRaised;
        _canShareScreen = canShareScreen;
        _isMicLocked = isMicLocked;
        for (final message in newMessages) {
          final id = int.tryParse(message['id'].toString()) ?? 0;
          if (id > _lastMessageId) {
            _lastMessageId = id;
            _messages.add({
              'user': message['full_name'] ?? 'Participant',
              'text': message['message'] ?? '',
              'isSystem': false,
            });
          }
        }
        if (_messages.length > 100) {
          _messages.removeRange(0, _messages.length - 100);
        }
        for (final event in newEvents) {
          final id = int.tryParse(event['id'].toString()) ?? 0;
          if (id > _lastEventId) {
            _lastEventId = id;
            if (event['event_type'] == 'reaction') {
              _playingEffect = '${event['payload']} ${event['full_name'] ?? ''}'
                  .trim();
              Future<void>.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _playingEffect = null);
              });
            } else if (event['event_type'] == 'effect' &&
                event['target_user_id'] != null) {
              final targetId = event['target_user_id'].toString();
              final version = (_seatEffectVersions[targetId] ?? 0) + 1;
              _seatEffectVersions[targetId] = version;
              _seatEffects[targetId] = event['payload'].toString();
              Future<void>.delayed(const Duration(seconds: 2), () {
                if (mounted && _seatEffectVersions[targetId] == version) {
                  setState(() => _seatEffects.remove(targetId));
                }
              });
            } else if (event['event_type'] == 'gift') {
              try {
                final payload = Map<String, dynamic>.from(
                  jsonDecode(event['payload'].toString()) as Map,
                );
                final senderName = event['full_name']?.toString() ?? 'Someone';
                final receiverName =
                    event['target_name']?.toString() ?? 'a participant';
                final giftName = payload['name']?.toString() ?? 'a gift';
                final emoji = payload['emoji']?.toString() ?? '🎁';
                _messages.add({
                  'user': senderName,
                  'text': '$senderName sent $emoji $giftName to $receiverName',
                  'isGift': true,
                  'emoji': emoji,
                  'giftName': giftName,
                  'targetName': receiverName,
                });
                _playingEffect =
                    '$emoji $senderName sent a gift to $receiverName';
                Future<void>.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _playingEffect = null);
                });
              } on FormatException catch (error) {
                debugPrint('Invalid Party gift event payload: $error');
              } on TypeError catch (error) {
                debugPrint('Invalid Party gift event shape: $error');
              }
            }
          }
        }
      });
      if (permissionsChanged) {
        if (isMicLocked && !_isMuted) {
          try {
            await _room?.localParticipant?.setMicrophoneEnabled(false);
          } catch (error) {
            debugPrint('Unable to apply microphone lock immediately: $error');
          }
          _isMuted = true;
        }
        if (_isScreenSharing) {
          try {
            await _room?.localParticipant?.setScreenShareEnabled(false);
          } catch (error) {
            debugPrint(
              'Unable to stop screen sharing after access change: $error',
            );
          }
          _isScreenSharing = false;
          if (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android &&
              FlutterBackground.isBackgroundExecutionEnabled) {
            try {
              await FlutterBackground.disableBackgroundExecution();
            } catch (error) {
              debugPrint(
                'Unable to stop screen-share background service: $error',
              );
            }
          }
        }
        unawaited(_refreshMediaToken());
        if (mounted) setState(() {});
      }
    } catch (error) {
      if (error is DioException &&
          (error.response?.statusCode == 403 ||
              error.response?.statusCode == 404) &&
          mounted) {
        await _disconnectParty();
        if (mounted) {
          Get.back();
          Get.snackbar(
            'Party ended',
            'You are no longer a member of this party.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        debugPrint('Party sync failed: $error');
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _disconnectParty() async {
    if (_isLeaving) return;
    _isLeaving = true;
    _syncTimer?.cancel();
    _syncTimer = null;
    final room = _room;
    _room = null;
    _roomListener?.dispose();
    _roomListener = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (error) {
        debugPrint('Unable to disconnect from LiveKit: $error');
      }
      try {
        await room.dispose();
      } catch (error) {
        debugPrint('Unable to dispose LiveKit room: $error');
      }
    }
    if (_isScreenSharing &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        FlutterBackground.isBackgroundExecutionEnabled) {
      try {
        await FlutterBackground.disableBackgroundExecution();
      } catch (error) {
        debugPrint('Unable to stop the screen-share service: $error');
      }
    }
    _isScreenSharing = false;
    _roomConnected = false;
    if (_hasJoinedParty) {
      try {
        await _partyAction('leave');
      } catch (error) {
        debugPrint('Unable to leave party membership: $error');
      }
      _hasJoinedParty = false;
    }
  }

  Future<void> _leaveParty() async {
    await _disconnectParty();
    if (mounted) Get.back();
  }

  void _deleteParty() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End & Delete Party?'),
        content: const Text(
          'This will close the party room for all participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Get.back(); // close dialog
              try {
                await _authController.apiService.post(
                  '${ApiConstants.baseUrl}/delete-party.php',
                  data: {'party_id': widget.party['id']},
                );
                await _disconnectParty();
                Get.back(); // return to party list
                Get.snackbar(
                  'Party Ended',
                  'Room has been closed for all participants.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              } catch (error) {
                debugPrint('Error ending party: $error');
                Get.snackbar(
                  'Unable to end party',
                  error.toString(),
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('End & Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _takeSeat(int seatIndex) async {
    try {
      if (_isScreenSharing) {
        await _room?.localParticipant?.setScreenShareEnabled(false);
        _isScreenSharing = false;
        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.disableBackgroundExecution();
        }
      }
      await _partyAction('take_seat', payload: {'seat_index': seatIndex});
      await _refreshMediaToken();
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Seat unavailable',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
      await _syncParty();
    }
  }

  Future<void> _leaveSeat() async {
    final currentIndex = userSeatIndex;
    if (currentIndex == null || currentIndex == 0) return;
    try {
      if (_isScreenSharing) {
        await _toggleScreenShare();
      }
      if (!_isMuted) {
        await _room?.localParticipant?.setMicrophoneEnabled(false);
        _isMuted = true;
      }
      await _partyAction('leave_seat');
      await _refreshMediaToken();
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to leave seat',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_isMicLocked) {
      Get.snackbar(
        'Microphone locked',
        'The host has locked your microphone.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!isUserSeated) {
      Get.snackbar(
        'Take a seat first',
        'Choose an empty seat to speak in the party.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!_roomConnected) {
      Get.snackbar(
        'Voice unavailable',
        _roomStatus ?? 'Connect to LiveKit before enabling your microphone.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      final enable = _isMuted;
      await _room?.localParticipant?.setMicrophoneEnabled(enable);
      if (mounted) setState(() => _isMuted = !enable);
    } catch (error) {
      debugPrint('Unable to change microphone state: $error');
      Get.snackbar(
        'Microphone error',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _muteParticipant(String targetId) async {
    try {
      await _partyAction(
        'set_mic_lock',
        payload: {'target_user_id': int.tryParse(targetId), 'locked': true},
      );
      Get.snackbar(
        'Microphone locked',
        'The participant microphone was locked.',
      );
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to mute participant',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _setMicrophoneLock(String targetId, bool locked) async {
    try {
      await _partyAction(
        'set_mic_lock',
        payload: {'target_user_id': int.tryParse(targetId), 'locked': locked},
      );
      Get.snackbar(
        locked ? 'Microphone locked' : 'Microphone unlocked',
        locked
            ? 'The participant cannot turn their microphone on.'
            : 'The participant can turn their microphone on again.',
      );
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to change microphone access',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _setScreenSharePermission(String targetId, bool allowed) async {
    try {
      await _partyAction(
        'set_screen_share_permission',
        payload: {'target_user_id': int.tryParse(targetId), 'allowed': allowed},
      );
      Get.snackbar(
        allowed ? 'Screen sharing allowed' : 'Screen sharing disabled',
        allowed
            ? 'The participant can share their screen while seated.'
            : 'The participant can no longer share their screen.',
      );
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to update screen-share access',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _removeParticipant(String targetId) async {
    try {
      await _partyAction(
        'remove_participant',
        payload: {'target_user_id': int.tryParse(targetId)},
      );
      Get.snackbar(
        'Participant removed',
        'The participant was removed from the room.',
      );
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to remove participant',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _setCohost(String targetId, bool isCohost) async {
    try {
      await _partyAction(
        'set_cohost',
        payload: {
          'target_user_id': int.tryParse(targetId),
          'is_cohost': isCohost,
        },
      );
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to update co-host',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _blockUserInParty(String targetId, String targetName) async {
    final myId = _authController.currentUser.value?.id;
    if (myId == null) return;

    try {
      final response = await _authController.apiService.post(
        '${ApiConstants.baseUrl}/block-user.php',
        data: {'blocker_id': myId, 'blocked_id': targetId, 'action': 'block'},
      );

      if (response.data['success'] == true) {
        Get.snackbar(
          'Blocked',
          '$targetName has been permanently blocked',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print('Error blocking user in party: $e');
    }
  }

  void _handleSeatTap(int index) {
    if (index == 0 && !isHost && _seats[index] == null) {
      Get.snackbar(
        'Host seat',
        'The first seat is reserved for the party host.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final seatData = _seats[index];

    if (seatData == null) {
      // Empty seat -> Take seat
      _takeSeat(index);
    } else {
      final isMe =
          seatData['id'].toString() ==
          _authController.currentUser.value?.id.toString();

      Get.bottomSheet(
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${seatData['name']} (Chair ${index + 1})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (isMe && !isHost && index != 0)
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                  title: const Text('Leave Chair'),
                  onTap: () {
                    Get.back();
                    unawaited(_leaveSeat());
                  },
                ),
              if (isMe)
                ListTile(
                  leading: Icon(
                    _isMicLocked
                        ? Icons.mic_off
                        : (_isMuted ? Icons.mic : Icons.mic_off),
                    color: _isMicLocked ? Colors.red : Colors.blue,
                  ),
                  title: Text(
                    _isMicLocked
                        ? 'Microphone locked by host'
                        : (_isMuted ? 'Unmute Mic' : 'Mute Mic'),
                  ),
                  onTap: () {
                    Get.back();
                    unawaited(_toggleMicrophone());
                  },
                ),
              if (!isMe) ...[
                ListTile(
                  leading: const Icon(Icons.card_giftcard, color: Colors.pink),
                  title: const Text('Send a gift'),
                  onTap: () {
                    Get.back();
                    unawaited(
                      _showPartyGiftPicker(
                        seatData['id'].toString(),
                        seatData['name'].toString(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.redAccent),
                  title: const Text('Block User 🚫'),
                  onTap: () {
                    Get.back();
                    _blockUserInParty(
                      seatData['id'].toString(),
                      seatData['name'].toString(),
                    );
                  },
                ),
                ..._targetEffectActions(seatData['id'].toString()),
              ],
              if (!isMe && _canModerate) ...[
                if (seatData['isMicLocked'] == true)
                  ListTile(
                    leading: const Icon(Icons.mic, color: Colors.green),
                    title: const Text('Unlock microphone'),
                    onTap: () {
                      Get.back();
                      unawaited(
                        _setMicrophoneLock(seatData['id'].toString(), false),
                      );
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(
                      Icons.mic_off,
                      color: Colors.deepOrange,
                    ),
                    title: const Text('Lock microphone'),
                    onTap: () {
                      Get.back();
                      unawaited(_muteParticipant(seatData['id'].toString()));
                    },
                  ),
                if (isHost)
                  ListTile(
                    leading: Icon(
                      seatData['canShareScreen'] == true
                          ? Icons.screen_share
                          : Icons.screen_share_outlined,
                      color: Colors.blue,
                    ),
                    title: Text(
                      seatData['canShareScreen'] == true
                          ? 'Revoke screen-share permission'
                          : 'Allow screen sharing',
                    ),
                    onTap: () {
                      Get.back();
                      unawaited(
                        _setScreenSharePermission(
                          seatData['id'].toString(),
                          seatData['canShareScreen'] != true,
                        ),
                      );
                    },
                  ),
                if (isHost)
                  ListTile(
                    leading: Icon(
                      seatData['isCohost'] == true
                          ? Icons.remove_moderator
                          : Icons.shield,
                      color: Colors.blue,
                    ),
                    title: Text(
                      seatData['isCohost'] == true
                          ? 'Remove co-host'
                          : 'Make co-host',
                    ),
                    onTap: () {
                      Get.back();
                      unawaited(
                        _setCohost(
                          seatData['id'].toString(),
                          seatData['isCohost'] != true,
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.person_remove, color: Colors.red),
                  title: const Text('Remove from Party'),
                  onTap: () {
                    Get.back();
                    unawaited(_removeParticipant(seatData['id'].toString()));
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  List<Widget> _targetEffectActions(String targetId) {
    const effects = [
      ('❤️', 'Send a heart'),
      ('💩', 'Throw a poop'),
      ('🔫', 'Water-gun splash'),
      ('🐶', 'Playful dog effect'),
      ('🦁', 'Lion roar'),
      ('🥁', 'Drum sound effect'),
    ];
    return effects
        .map(
          (effect) => ListTile(
            leading: Text(effect.$1, style: const TextStyle(fontSize: 20)),
            title: Text(effect.$2),
            onTap: () {
              Get.back();
              unawaited(_sendTargetedEffect(effect.$1, targetId));
            },
          ),
        )
        .toList();
  }

  void _showParticipantActions(Map<String, dynamic> participant) {
    final targetId = participant['user_id'].toString();
    final canShareScreen =
        participant['can_share_screen'] == true ||
        participant['can_share_screen'] == 1 ||
        participant['can_share_screen'] == '1';
    final isMicLocked =
        participant['is_mic_locked'] == true ||
        participant['is_mic_locked'] == 1 ||
        participant['is_mic_locked'] == '1';

    Get.bottomSheet(
      SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                participant['full_name']?.toString() ?? 'Participant',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: Colors.pink),
                title: const Text('Send a gift'),
                onTap: () {
                  Get.back();
                  unawaited(
                    _showPartyGiftPicker(
                      targetId,
                      participant['full_name']?.toString() ?? 'Participant',
                    ),
                  );
                },
              ),
              if (this.isHost)
                ListTile(
                  leading: Icon(
                    canShareScreen
                        ? Icons.screen_share
                        : Icons.screen_share_outlined,
                    color: Colors.blue,
                  ),
                  title: Text(
                    canShareScreen
                        ? 'Revoke screen-share permission'
                        : 'Allow screen sharing',
                  ),
                  onTap: () {
                    Get.back();
                    unawaited(
                      _setScreenSharePermission(targetId, !canShareScreen),
                    );
                  },
                ),
              if (this.isHost)
                ListTile(
                  leading: Icon(
                    isMicLocked ? Icons.mic : Icons.mic_off,
                    color: isMicLocked ? Colors.green : Colors.deepOrange,
                  ),
                  title: Text(
                    isMicLocked ? 'Unlock microphone' : 'Lock microphone',
                  ),
                  onTap: () {
                    Get.back();
                    unawaited(_setMicrophoneLock(targetId, !isMicLocked));
                  },
                ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _showPartyGiftPicker(String targetId, String targetName) async {
    try {
      final response = await _authController.apiService.get(
        ApiConstants.getGifts,
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ?? 'Unable to load gifts.',
        );
      }
      final gifts = (response.data['data'] as List? ?? const [])
          .map(
            (item) =>
                GiftModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      if (!mounted) return;
      final coins = _authController.currentUser.value?.coins ?? 0;
      Get.bottomSheet(
        SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.58,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Text(
                  'Send a gift to $targetName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Your balance: 🪙 $coins'),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    itemCount: gifts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.7,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Get.back();
                          unawaited(
                            _confirmAndSendPartyGift(
                              gift,
                              targetId,
                              targetName,
                              coins,
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                gift.emoji,
                                style: const TextStyle(fontSize: 30),
                              ),
                              Text(
                                gift.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('🪙 ${gift.priceCoins}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        isScrollControlled: true,
      );
    } catch (error) {
      Get.snackbar(
        'Gifts unavailable',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _confirmAndSendPartyGift(
    GiftModel gift,
    String targetId,
    String targetName,
    int currentCoins,
  ) async {
    if (currentCoins < gift.priceCoins) {
      final openCoinShop = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Not enough coins'),
          content: Text(
            'You need ${gift.priceCoins} coins to send this gift. Your balance is $currentCoins.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Get coins'),
            ),
          ],
        ),
      );
      if (openCoinShop == true) Get.to(() => const CoinShopScreen());
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirm gift'),
        content: Text(
          'Send ${gift.emoji} ${gift.name} to $targetName for ${gift.priceCoins} coins?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Send gift'),
          ),
        ],
      ),
    );
    if (confirmed != true || _isSendingGift) return;

    final requestKey = '${widget.party['id']}:$targetId:${gift.id}';
    final requestId = _pendingGiftRequestIds.putIfAbsent(
      requestKey,
      GiftModel.createRequestId,
    );
    setState(() => _isSendingGift = true);
    try {
      final response = await _partyAction(
        'send_gift',
        payload: {
          'target_user_id': int.tryParse(targetId),
          'gift_id': gift.id,
          'request_id': requestId,
        },
      );
      final data = Map<String, dynamic>.from(response['data'] as Map);
      final remainingCoins = int.tryParse(data['remaining_coins'].toString());
      final currentUser = _authController.currentUser.value;
      if (remainingCoins != null && currentUser != null) {
        await _authController.updateCachedUser(
          currentUser.copyWith(coins: remainingCoins),
        );
      }
      _pendingGiftRequestIds.remove(requestKey);
      Get.snackbar(
        'Gift sent',
        '${gift.emoji} ${gift.name} sent to $targetName!',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to send gift',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isSendingGift = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || text.length > 500) return;
    try {
      await _partyAction('send_message', payload: {'message': text});
      _msgController.clear();
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to send message',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _sendReaction(String reaction) async {
    try {
      await _partyAction('react', payload: {'reaction': reaction});
    } catch (error) {
      Get.snackbar(
        'Unable to send reaction',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _sendTargetedEffect(String effect, String targetId) async {
    try {
      await _partyAction(
        'send_effect',
        payload: {'effect': effect, 'target_user_id': int.tryParse(targetId)},
      );
    } catch (error) {
      Get.snackbar(
        'Unable to send effect',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _toggleRaisedHand() async {
    final raised = !_isHandRaised;
    try {
      await _partyAction('raise_hand', payload: {'raised': raised});
      if (mounted) setState(() => _isHandRaised = raised);
      await _syncParty();
    } catch (error) {
      Get.snackbar(
        'Unable to raise hand',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _inviteParticipants() async {
    await Share.share(
      'Join "${widget.party['title']}" in Vamper. Party ID: ${widget.party['id']}',
      subject: 'Vamper Party invitation',
    );
  }

  Future<void> _toggleScreenShare() async {
    if (!_canShareScreen) {
      Get.snackbar(
        'Host approval required',
        'The host must allow screen sharing before this control is available.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!isUserSeated) {
      Get.snackbar(
        'Take a speaker seat',
        'Only speakers can share their screen in this party.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!_roomConnected) {
      Get.snackbar(
        'Screen share unavailable',
        _roomStatus ?? 'Connect to LiveKit before sharing your screen.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      final shareEnabled = !_isScreenSharing;
      if (shareEnabled &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final hasCapturePermission = await Helper.requestCapturePermission();
        if (!hasCapturePermission) {
          throw StateError('Screen capture permission was not granted.');
        }

        var hasBackgroundPermissions = await FlutterBackground.hasPermissions;
        if (!hasBackgroundPermissions) {
          hasBackgroundPermissions = await FlutterBackground.initialize(
            androidConfig: const FlutterBackgroundAndroidConfig(
              notificationTitle: 'Vamper Party',
              notificationText: 'Your screen is being shared.',
              notificationImportance: AndroidNotificationImportance.normal,
              notificationIcon: AndroidResource(
                name: 'ic_launcher',
                defType: 'mipmap',
              ),
            ),
          );
        }
        if (!hasBackgroundPermissions) {
          throw StateError(
            'Background screen-share permission was not granted.',
          );
        }
        if (!FlutterBackground.isBackgroundExecutionEnabled) {
          final enabled = await FlutterBackground.enableBackgroundExecution();
          if (!enabled) {
            throw StateError('Unable to start the screen-share service.');
          }
        }
      }

      await _room?.localParticipant?.setScreenShareEnabled(
        shareEnabled,
        captureScreenAudio: shareEnabled,
      );
      if (mounted) setState(() => _isScreenSharing = shareEnabled);
      if (!shareEnabled &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (error) {
      debugPrint('Unable to change screen sharing state: $error');
      Get.snackbar(
        'Unable to share screen',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  VideoTrack? get _sharedScreenTrack {
    final room = _room;
    if (room == null) return null;
    final local = room.localParticipant;
    for (final publication in local?.videoTrackPublications ?? const []) {
      if (publication.source == TrackSource.screenShareVideo &&
          publication.track != null) {
        return publication.track;
      }
    }
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (publication.source == TrackSource.screenShareVideo &&
            publication.track != null) {
          return publication.track;
        }
      }
    }
    return null;
  }

  void _showOnlineParticipants() {
    Get.bottomSheet(
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Online in Room (${_participants.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final participant = _participants[index];
                  final seatIndex = int.tryParse(
                    participant['seat_index']?.toString() ?? '',
                  );
                  final isHost =
                      participant['user_id'].toString() ==
                      widget.party['host_id'].toString();
                  final isCohost =
                      participant['is_cohost'] == 1 ||
                      participant['is_cohost'] == '1';
                  final isHandRaised =
                      participant['is_hand_raised'] == 1 ||
                      participant['is_hand_raised'] == '1';
                  return ListTile(
                    leading: UserAvatarWithFrame(
                      photoUrl: participant['profile_photo']?.toString(),
                      frameCode: participant['active_profile_frame_code']
                          ?.toString(),
                      size: 44,
                    ),
                    title: Text(
                      participant['full_name']?.toString() ?? 'Participant',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${isHandRaised ? '✋ Hand raised · ' : ''}${isHost
                          ? 'Host'
                          : isCohost
                          ? 'Co-host'
                          : seatIndex == null
                          ? 'Listener'
                          : 'Speaker seat ${seatIndex + 1}'}',
                    ),
                    trailing: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap:
                        participant['user_id'].toString() ==
                            _authController.currentUser.value?.id.toString()
                        ? null
                        : () => _showParticipantActions(participant),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partyColors = _partyBackgroundColors;
    final screenTrack = _sharedScreenTrack;

    return Scaffold(
      backgroundColor: partyColors.first,
      appBar: AppBar(
        backgroundColor: partyColors.first.withValues(alpha: 0.95),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: _leaveParty,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.party['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Host: ${widget.party['host_name']} • Theme: ${widget.party['theme']}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white70),
            tooltip: 'Invite to party',
            onPressed: _inviteParticipants,
          ),
          if (isHost)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'End & Delete Party',
              onPressed: _deleteParty,
            ),
          // Real-time Eye Viewer Count Badge
          Center(
            child: InkWell(
              onTap: _showOnlineParticipants,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye_rounded,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_viewerCount',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.pink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: partyColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            if (_isJoining)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Colors.pinkAccent,
                backgroundColor: Colors.transparent,
              ),
            if (_roomStatus != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: Colors.deepOrange.shade900,
                child: Text(
                  _roomStatus!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            if (_isScreenSharing || _sharedScreenTrack != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: Colors.purple.shade900,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.monitor_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Screen sharing is live',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            if (screenTrack != null)
              Container(
                width: double.infinity,
                height: 190,
                color: Colors.black,
                child: VideoTrackRenderer(
                  screenTrack,
                  fit: VideoViewFit.contain,
                ),
              ),
            if (!_roomConnected && !_isJoining && _roomStatus == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.deepOrange.shade900,
                child: const Text(
                  'Connecting to party media…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),

            // 10-SEAT GRID LAYOUT (2 rows of 5 seats)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              color: partyColors.first.withValues(alpha: 0.72),
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
                  final isReservedHostSeat = index == 0 && !isHost;
                  return InkWell(
                    onTap: () => _handleSeatTap(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            isOccupied
                                ? UserAvatarWithFrame(
                                    photoUrl: seat['photo'],
                                    frameCode: seat['frameCode']?.toString(),
                                    size: 50,
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      border: Border.all(
                                        color: Colors.white30,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      isReservedHostSeat
                                          ? Icons.lock_outline
                                          : Icons.add,
                                      color: Colors.white54,
                                      size: 22,
                                    ),
                                  ),
                            if (isOccupied)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    seat['isMuted'] == true
                                        ? Icons.mic_off
                                        : Icons.mic,
                                    size: 10,
                                    color: seat['isMuted'] == true
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ),
                            if (seat?['isHandRaised'] == true)
                              const Positioned(
                                top: 0,
                                right: 0,
                                child: Icon(
                                  Icons.pan_tool,
                                  color: Colors.amber,
                                  size: 15,
                                ),
                              ),
                            if (isOccupied &&
                                _seatEffects.containsKey(seat['id'].toString()))
                              Positioned(
                                top: -10,
                                child: Text(
                                  _seatEffects[seat['id'].toString()]!,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOccupied
                              ? seat['name']
                              : (isReservedHostSeat
                                    ? 'Host seat'
                                    : 'Seat ${index + 1}'),
                          style: TextStyle(
                            color: isOccupied ? Colors.white : Colors.white38,
                            fontSize: 10,
                            fontWeight: isOccupied
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _playingEffect!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),

            // Music playback stays hidden until a licensed shared audio source is available.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: partyColors.last.withValues(alpha: 0.68),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUserSeated && _canShareScreen)
                      _buildToolButton(
                        _isScreenSharing
                            ? Icons.stop_screen_share
                            : Icons.screen_share,
                        'Screen Share',
                        Colors.blue,
                        _toggleScreenShare,
                      ),
                    _buildToolButton(
                      Icons.celebration,
                      'Applause',
                      Colors.amber,
                      () => _sendReaction('👏'),
                    ),
                    _buildToolButton(
                      Icons.sentiment_very_satisfied,
                      'Laugh',
                      Colors.orange,
                      () => _sendReaction('😂'),
                    ),
                    _buildToolButton(
                      Icons.local_fire_department,
                      'Cheer',
                      Colors.red,
                      () => _sendReaction('🎉'),
                    ),
                    _buildToolButton(
                      _isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                      _isHandRaised ? 'Lower hand' : 'Raise hand',
                      Colors.amber,
                      _toggleRaisedHand,
                    ),
                  ],
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  if (msg['isGift'] == true) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.pinkAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(msg['text']),
                            tween: Tween(begin: 0.6, end: 1),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: Text(
                              msg['emoji']?.toString() ?? '🎁',
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              msg['text']?.toString() ?? 'A gift was sent!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${msg['user']}: ',
                          style: const TextStyle(
                            color: Colors.pinkAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            msg['text'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Input & Mic Controls
            Container(
              padding: const EdgeInsets.all(12),
              color: partyColors.first.withValues(alpha: 0.72),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isUserSeated
                            ? (_isMuted ? Icons.mic_off : Icons.mic)
                            : Icons.mic_none,
                        color: isUserSeated
                            ? (_isMuted ? Colors.red : Colors.green)
                            : Colors.white38,
                      ),
                      onPressed: () {
                        unawaited(_toggleMicrophone());
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        maxLength: 500,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Say something in party...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
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
      ),
    );
  }

  Widget _buildToolButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
