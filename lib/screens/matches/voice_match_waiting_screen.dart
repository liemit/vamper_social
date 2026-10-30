import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discovery_controller.dart';
import '../../core/constants/api_constants.dart';
import 'voice_match_call_screen.dart';

class VoiceMatchWaitingScreen extends StatefulWidget {
  const VoiceMatchWaitingScreen({super.key});

  @override
  State<VoiceMatchWaitingScreen> createState() =>
      _VoiceMatchWaitingScreenState();
}

class _VoiceMatchWaitingScreenState extends State<VoiceMatchWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _pollTimer;
  bool _isSearching = true;
  bool _isPolling = false;
  bool _hasMatched = false;
  String _statusText = 'Finding voice partner...';
  String? _errorMessage;

  AuthController get _authController => Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    unawaited(_startSearch());
  }

  Future<void> _startSearch() async {
    if (_isPolling || _hasMatched) return;
    _isPolling = true;
    try {
      final preference = Get.find<DiscoveryController>().genderPreference.value;
      final response = await _authController.apiService.post(
        ApiConstants.voiceMatchSession,
        data: {'action': 'search', 'gender_preference': preference},
      );
      if (!mounted) return;
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ??
              'Unable to start Voice Match.',
        );
      }
      await _handleMatchResponse(Map<String, dynamic>.from(response.data));
      if (mounted && !_hasMatched && _isSearching) {
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => unawaited(_pollMatch()),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = error.toString().replaceFirst('Bad state: ', '');
          _statusText = 'Voice Match is unavailable';
        });
      }
      unawaited(_leaveQueue());
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _pollMatch() async {
    if (_isPolling || _hasMatched || !_isSearching) return;
    _isPolling = true;
    try {
      final response = await _authController.apiService.post(
        ApiConstants.voiceMatchSession,
        data: {'action': 'poll'},
      );
      if (!mounted) return;
      if (response.data['success'] != true) {
        throw StateError(
          response.data['message']?.toString() ?? 'Voice Match polling failed.',
        );
      }
      await _handleMatchResponse(Map<String, dynamic>.from(response.data));
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusText = 'Reconnecting to matchmaking...';
          _errorMessage = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _handleMatchResponse(Map<String, dynamic> response) async {
    if (response['status'] != 'matched') {
      if (mounted) {
        setState(() {
          _statusText = 'Finding voice partner...';
          _errorMessage = null;
        });
      }
      return;
    }

    final session = Map<String, dynamic>.from(response['data'] as Map);
    _hasMatched = true;
    _pollTimer?.cancel();
    if (mounted) {
      setState(() => _statusText = 'Voice Match found! Connecting...');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Get.off(() => VoiceMatchCallScreen(session: session));
  }

  Future<void> _leaveQueue() async {
    try {
      await _authController.apiService.post(
        ApiConstants.voiceMatchSession,
        data: {'action': 'leave'},
      );
    } catch (error) {
      debugPrint('Unable to leave Voice Match queue: $error');
    }
  }

  void _cancelSearch() {
    _pollTimer?.cancel();
    unawaited(_leaveQueue());
    Get.back();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (!_hasMatched) unawaited(_leaveQueue());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16222A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isSearching)
                      RotationTransition(
                        turns: _controller,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            gradient: SweepGradient(
                              colors: [
                                Colors.blue.withValues(alpha: 0),
                                Colors.blue.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade500.withValues(alpha: 0.2),
                      ),
                    ),
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.mic, color: Colors.white, size: 40),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ??
                      'We will connect you as soon as someone compatible is ready.',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (!_isSearching && _errorMessage != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                        _errorMessage = null;
                        _statusText = 'Finding voice partner...';
                      });
                      unawaited(_startSearch());
                    },
                    child: const Text('Try again'),
                  )
                else
                  TextButton(
                    onPressed: _cancelSearch,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
