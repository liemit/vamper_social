import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';

class VoiceMatchCallScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const VoiceMatchCallScreen({super.key, required this.session});

  @override
  State<VoiceMatchCallScreen> createState() => _VoiceMatchCallScreenState();
}

class _VoiceMatchCallScreenState extends State<VoiceMatchCallScreen>
    with SingleTickerProviderStateMixin {
  final AuthController _authController = Get.find<AuthController>();
  int _secondsElapsed = 0;
  Timer? _timer;
  Timer? _heartbeatTimer;
  bool _isMuted = false;
  bool _isSpeaker = true;
  bool _isConnecting = true;
  bool _isLeaving = false;
  bool _leftSession = false;
  String? _liveKitUrl;
  String? _liveKitToken;
  String? _callError;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  late final AnimationController _waveController;

  Map<String, dynamic> get _partner =>
      Map<String, dynamic>.from(widget.session['partner'] as Map);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _liveKitUrl = widget.session['livekit_url']?.toString();
    _liveKitToken = widget.session['livekit_token']?.toString();
    unawaited(_connectToCall());
  }

  Future<void> _connectToCall() async {
    final url = _liveKitUrl;
    final token = _liveKitToken;
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _callError = 'The voice service did not provide a valid call token.';
        });
      }
      return;
    }

    await _disconnectRoom();
    final room = Room();
    _room = room;
    _roomListener = room.createListener()
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted && !_isLeaving) {
          setState(() {
            _isConnecting = false;
            _callError = 'The voice connection was interrupted.';
          });
        }
      });

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        await AudioManager.instance.setSpeakerOutputPreferred(_isSpeaker);
      }
      await room.connect(
        url,
        token,
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (!mounted || _isLeaving) return;
      setState(() {
        _isConnecting = false;
        _isMuted = false;
        _callError = null;
      });
      _startCallTimer();
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_heartbeat()),
      );
    } catch (error) {
      debugPrint('Unable to connect Voice Match call: $error');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _callError = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  void _startCallTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  Future<void> _heartbeat() async {
    if (_isLeaving || _leftSession) return;
    try {
      final response = await _authController.apiService.post(
        ApiConstants.voiceMatchSession,
        data: {'action': 'poll'},
      );
      if (response.data['status'] == 'matched' &&
          response.data['data'] is Map) {
        final session = Map<String, dynamic>.from(response.data['data'] as Map);
        _liveKitUrl = session['livekit_url']?.toString() ?? _liveKitUrl;
        _liveKitToken = session['livekit_token']?.toString() ?? _liveKitToken;
      }
      if (response.data['status'] == 'ended' ||
          response.data['status'] == 'left') {
        await _handleRemoteHangup();
      }
    } catch (error) {
      debugPrint('Voice Match heartbeat failed: $error');
    }
  }

  Future<void> _handleRemoteHangup() async {
    if (_isLeaving || !mounted) return;
    _isLeaving = true;
    await _disconnectRoom();
    if (!mounted) return;
    Get.back();
    Get.snackbar(
      'Call ended',
      'The other participant left the voice call.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _toggleMicrophone() async {
    final room = _room;
    if (room == null || _isConnecting || _callError != null) return;
    final enable = _isMuted;
    try {
      await room.localParticipant?.setMicrophoneEnabled(enable);
      if (mounted) setState(() => _isMuted = !enable);
    } catch (error) {
      Get.snackbar(
        'Microphone unavailable',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _toggleSpeaker() async {
    final useSpeaker = !_isSpeaker;
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        await AudioManager.instance.setSpeakerOutputPreferred(useSpeaker);
      }
      if (mounted) setState(() => _isSpeaker = useSpeaker);
    } catch (error) {
      Get.snackbar(
        'Audio output unavailable',
        error.toString().replaceFirst('Bad state: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _endCall() async {
    if (_isLeaving) return;
    final shouldEnd = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('End call?'),
        content: const Text('Do you want to disconnect this voice call?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Continue call'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Get.back(result: true),
            child: const Text('End call'),
          ),
        ],
      ),
    );
    if (shouldEnd != true || !mounted) return;
    _isLeaving = true;
    await _leaveSession();
    await _disconnectRoom();
    if (mounted) Get.back();
  }

  Future<void> _leaveSession() async {
    if (_leftSession) return;
    _leftSession = true;
    try {
      await _authController.apiService.post(
        ApiConstants.voiceMatchSession,
        data: {'action': 'leave'},
      );
    } catch (error) {
      debugPrint('Unable to end Voice Match session: $error');
    }
  }

  Future<void> _disconnectRoom() async {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _timer = null;
    _heartbeatTimer = null;
    _roomListener?.dispose();
    _roomListener = null;
    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (error) {
        debugPrint('Unable to disconnect Voice Match room: $error');
      }
      try {
        await room.dispose();
      } catch (error) {
        debugPrint('Unable to dispose Voice Match room: $error');
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _isLeaving = true;
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    if (!_leftSession) unawaited(_leaveSession());
    unawaited(_disconnectRoom());
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _authController.getFullImageUrl(
      _partner['profile_photo']?.toString(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF16222A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white70,
                    ),
                    onPressed: _endCall,
                  ),
                  const Text(
                    'Voice Match',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDuration(_secondsElapsed),
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Stack(
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.25).animate(
                      CurvedAnimation(
                        parent: _waveController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withValues(alpha: 0.4),
                    ),
                  ),
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                '${_partner['full_name']}, ${_partner['age'] ?? 22}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isConnecting
                    ? 'Connecting to secure voice...'
                    : _callError ?? 'Connected via LiveKit voice',
                style: TextStyle(
                  color: _callError == null ? Colors.blueAccent : Colors.orange,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isConnecting) ...[
                const SizedBox(height: 18),
                const CircularProgressIndicator(color: Colors.blueAccent),
              ],
              if (_callError != null) ...[
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConnecting = true;
                      _callError = null;
                    });
                    unawaited(_connectToCall());
                  },
                  child: const Text('Reconnect'),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'voice-match-mute',
                    backgroundColor: _isMuted ? Colors.white : Colors.white24,
                    onPressed: _toggleMicrophone,
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 28),
                  FloatingActionButton(
                    heroTag: 'voice-match-speaker',
                    backgroundColor: _isSpeaker ? Colors.white : Colors.white24,
                    onPressed: _toggleSpeaker,
                    child: Icon(
                      _isSpeaker ? Icons.volume_up : Icons.hearing,
                      color: _isSpeaker ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
