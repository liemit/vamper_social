import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';

class ChatCallScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const ChatCallScreen({super.key, required this.session});

  @override
  State<ChatCallScreen> createState() => _ChatCallScreenState();
}

class _ChatCallScreenState extends State<ChatCallScreen> {
  final AuthController _authController = Get.find<AuthController>();
  Timer? _pollTimer;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  late final int _callId;
  late final String _callType;
  late final bool _isCaller;
  late final Map<String, dynamic> _partner;
  String _status = 'ringing';
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraEnabled = false;
  bool _isSpeaker = true;
  bool _isPolling = false;
  bool _isFinishing = false;
  bool _isAccepting = false;
  bool _sentTerminalAction = false;
  String? _errorMessage;
  VideoTrack? _remoteVideoTrack;
  VideoTrack? _localVideoTrack;
  DateTime? _connectedAt;
  Timer? _durationTimer;
  String _duration = '00:00';

  bool get _isVideoCall => _callType == 'video';

  @override
  void initState() {
    super.initState();
    _callId = int.parse(widget.session['call_id'].toString());
    _callType = widget.session['call_type']?.toString() ?? 'audio';
    _isCaller = widget.session['is_caller'] == true;
    _partner = Map<String, dynamic>.from(widget.session['partner'] as Map);
    _status = widget.session['status']?.toString() ?? 'ringing';

    final token = widget.session['livekit_token']?.toString();
    final url = widget.session['livekit_url']?.toString();
    if (_status == 'accepted' && token != null && url != null) {
      unawaited(_connectToRoom(url, token));
    }

    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollCall()),
    );
  }

  Future<void> _pollCall() async {
    if (_isPolling || _isFinishing) return;
    _isPolling = true;
    try {
      final response = await _authController.apiService.post(
        ApiConstants.chatCall,
        data: {'action': 'poll', 'call_id': _callId},
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ??
              'Unable to check call status.',
        );
      }

      final status = response.data['status']?.toString() ?? 'ended';
      if (!mounted) return;
      if (status == 'accepted') {
        final call = Map<String, dynamic>.from(response.data['data'] as Map);
        setState(() {
          _status = status;
          _errorMessage = null;
        });
        final token = call['livekit_token']?.toString();
        final url = call['livekit_url']?.toString();
        if (!_isConnected &&
            !_isConnecting &&
            token != null &&
            token.isNotEmpty &&
            url != null &&
            url.isNotEmpty) {
          await _connectToRoom(url, token);
        }
      } else if (status == 'declined' ||
          status == 'ended' ||
          status == 'missed') {
        await _finishFromRemote(status);
      } else if (_status != status) {
        setState(() => _status = status);
      }
    } catch (error) {
      debugPrint('Unable to poll chat call: $error');
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _acceptCall() async {
    if (_isFinishing || _isAccepting || _isCaller || _status != 'ringing') {
      return;
    }
    _isAccepting = true;
    try {
      final response = await _authController.apiService.post(
        ApiConstants.chatCall,
        data: {'action': 'accept', 'call_id': _callId},
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ?? 'Unable to accept this call.',
        );
      }
      final call = Map<String, dynamic>.from(response.data['data'] as Map);
      if (mounted) setState(() => _status = 'accepted');
      final url = call['livekit_url']?.toString();
      final token = call['livekit_token']?.toString();
      if (url == null || url.isEmpty || token == null || token.isEmpty) {
        throw StateError(
          'The call service did not return valid LiveKit access.',
        );
      }
      await _connectToRoom(url, token);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      _isAccepting = false;
    }
  }

  Future<void> _connectToRoom(String url, String token) async {
    if (_isConnecting || _isConnected || _isFinishing) return;
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });
    await _disconnectRoom();
    if (!mounted || _isFinishing) return;
    final room = Room();
    _room = room;
    _roomListener = room.createListener()
      ..on<ParticipantConnectedEvent>((_) => _refreshVideoTracks())
      ..on<ParticipantDisconnectedEvent>((_) => _refreshVideoTracks())
      ..on<TrackSubscribedEvent>((_) => _refreshVideoTracks())
      ..on<TrackUnsubscribedEvent>((_) => _refreshVideoTracks())
      ..on<LocalTrackPublishedEvent>((_) => _refreshVideoTracks())
      ..on<LocalTrackUnpublishedEvent>((_) => _refreshVideoTracks())
      ..on<RoomDisconnectedEvent>((_) {
        if (mounted && !_isFinishing) {
          setState(() {
            _isConnected = false;
            _isConnecting = false;
            _errorMessage = 'The call connection was interrupted.';
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
      if (_isVideoCall) {
        await room.localParticipant?.setCameraEnabled(true);
      }
      if (!mounted || _isFinishing) return;
      _connectedAt = DateTime.now();
      _durationTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateDuration(),
      );
      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _isMuted = false;
        _isCameraEnabled = _isVideoCall;
      });
      _refreshVideoTracks();
    } catch (error) {
      debugPrint('Unable to connect chat call to LiveKit: $error');
      await _disconnectRoom();
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
          _errorMessage = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  void _refreshVideoTracks() {
    final room = _room;
    if (room == null || !mounted) return;
    VideoTrack? localTrack;
    VideoTrack? remoteTrack;
    for (final publication
        in room.localParticipant?.videoTrackPublications ?? const []) {
      if (publication.source == TrackSource.camera &&
          publication.track is VideoTrack) {
        localTrack = publication.track as VideoTrack;
      }
    }
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (publication.source == TrackSource.camera &&
            publication.track is VideoTrack) {
          remoteTrack = publication.track as VideoTrack;
        }
      }
    }
    setState(() {
      _localVideoTrack = localTrack;
      _remoteVideoTrack = remoteTrack;
    });
  }

  void _updateDuration() {
    final connectedAt = _connectedAt;
    if (!mounted || connectedAt == null) return;
    final seconds = DateTime.now().difference(connectedAt).inSeconds;
    setState(() {
      _duration =
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
          '${(seconds % 60).toString().padLeft(2, '0')}';
    });
  }

  Future<void> _toggleMicrophone() async {
    final room = _room;
    if (room == null || !_isConnected) return;
    final enable = _isMuted;
    try {
      await room.localParticipant?.setMicrophoneEnabled(enable);
      if (mounted) setState(() => _isMuted = !enable);
    } catch (error) {
      _showCallError('Microphone unavailable', error);
    }
  }

  Future<void> _toggleCamera() async {
    final room = _room;
    if (!_isVideoCall || room == null || !_isConnected) return;
    final enable = !_isCameraEnabled;
    try {
      await room.localParticipant?.setCameraEnabled(enable);
      if (mounted) setState(() => _isCameraEnabled = enable);
      _refreshVideoTracks();
    } catch (error) {
      _showCallError('Camera unavailable', error);
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
      _showCallError('Audio output unavailable', error);
    }
  }

  void _showCallError(String title, Object error) {
    Get.snackbar(
      title,
      error.toString().replaceFirst('Bad state: ', ''),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _declineCall() async {
    await _finishCall('decline');
  }

  Future<void> _hangUp() async {
    await _finishCall('end');
  }

  Future<void> _finishCall(String action) async {
    if (_isFinishing) return;
    _isFinishing = true;
    _sentTerminalAction = true;
    _pollTimer?.cancel();
    try {
      final response = await _authController.apiService.post(
        ApiConstants.chatCall,
        data: {'action': action, 'call_id': _callId},
      );
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ?? 'Unable to end this call.',
        );
      }
    } catch (error) {
      debugPrint('Unable to update call state: $error');
    }
    await _disconnectRoom();
    if (mounted) Get.back();
  }

  Future<void> _finishFromRemote(String status) async {
    if (_isFinishing) return;
    _isFinishing = true;
    _sentTerminalAction = true;
    _status = status;
    _pollTimer?.cancel();
    await _disconnectRoom();
    if (!mounted) return;
    Get.back();
    if (status == 'declined') {
      Get.snackbar(
        'Call declined',
        '${_partner['full_name'] ?? 'Your match'} declined the call.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else if (status == 'missed') {
      Get.snackbar(
        'Call ended',
        'There was no answer.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Call ended',
        'The other participant left the call.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _disconnectRoom() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _roomListener?.dispose();
    _roomListener = null;
    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (error) {
        debugPrint('Unable to disconnect chat call: $error');
      }
      try {
        await room.dispose();
      } catch (error) {
        debugPrint('Unable to dispose chat call room: $error');
      }
    }
  }

  Widget _videoStage() {
    final remoteTrack = _remoteVideoTrack;
    final photo = _authController.getFullImageUrl(
      _partner['profile_photo']?.toString(),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (remoteTrack != null)
          VideoTrackRenderer(remoteTrack, fit: VideoViewFit.cover)
        else
          Container(
            color: const Color(0xFF20232D),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundImage: photo == null ? null : NetworkImage(photo),
                  child: photo == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  _partner['full_name']?.toString() ?? 'Your match',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        if (_localVideoTrack != null && _isCameraEnabled)
          Positioned(
            top: 18,
            right: 18,
            width: 110,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: VideoTrackRenderer(
                _localVideoTrack!,
                fit: VideoViewFit.cover,
              ),
            ),
          ),
        Positioned(top: 16, left: 16, child: _callStatusPill()),
      ],
    );
  }

  Widget _callStatusPill() {
    final label = _isConnected
        ? _duration
        : _isConnecting
        ? 'Connecting...'
        : _isCaller
        ? 'Calling...'
        : 'Incoming call';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _audioStage() {
    final photo = _authController.getFullImageUrl(
      _partner['profile_photo']?.toString(),
    );
    return Container(
      width: double.infinity,
      color: const Color(0xFF20232D),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 64,
            backgroundImage: photo == null ? null : NetworkImage(photo),
            child: photo == null ? const Icon(Icons.person, size: 56) : null,
          ),
          const SizedBox(height: 20),
          Text(
            _partner['full_name']?.toString() ?? 'Your match',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _callStatusPill(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isFinishing = true;
    _pollTimer?.cancel();
    if (!_sentTerminalAction &&
        (_status == 'ringing' || _status == 'accepted')) {
      unawaited(_endCallOnDispose());
    }
    unawaited(_disconnectRoom());
    super.dispose();
  }

  Future<void> _endCallOnDispose() async {
    try {
      await _authController.apiService.post(
        ApiConstants.chatCall,
        data: {
          'action': _status == 'ringing' && !_isCaller ? 'decline' : 'end',
          'call_id': _callId,
        },
      );
    } catch (error) {
      debugPrint('Unable to close chat call during cleanup: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = !_isCaller && _status == 'ringing';
    return Scaffold(
      backgroundColor: const Color(0xFF11141B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'End call',
                    onPressed: isIncoming ? _declineCall : _hangUp,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                  Expanded(
                    child: Text(
                      _isVideoCall ? 'Video call' : 'Audio call',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Text(
                        _isConnected ? _duration : '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _isVideoCall ? _videoStage() : _audioStage()),
            if (isIncoming)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 26,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      color: Colors.red,
                      onTap: _declineCall,
                    ),
                    _actionButton(
                      icon: _isVideoCall ? Icons.videocam : Icons.call,
                      label: 'Accept',
                      color: Colors.green,
                      onTap: _acceptCall,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      color: _isMuted ? Colors.white24 : Colors.white12,
                      onTap: _toggleMicrophone,
                    ),
                    if (_isVideoCall)
                      _actionButton(
                        icon: _isCameraEnabled
                            ? Icons.videocam
                            : Icons.videocam_off,
                        label: _isCameraEnabled ? 'Camera on' : 'Camera off',
                        color: _isCameraEnabled
                            ? Colors.white12
                            : Colors.white24,
                        onTap: _toggleCamera,
                      ),
                    _actionButton(
                      icon: _isSpeaker ? Icons.volume_up : Icons.hearing,
                      label: _isSpeaker ? 'Speaker' : 'Earpiece',
                      color: Colors.white12,
                      onTap: _toggleSpeaker,
                    ),
                    _actionButton(
                      icon: Icons.call_end,
                      label: 'End',
                      color: Colors.red,
                      onTap: _hangUp,
                    ),
                  ],
                ),
              ),
            if (_isConnecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_errorMessage != null && !isIncoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'chat-call-$label',
          onPressed: onTap,
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
