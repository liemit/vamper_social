import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../screens/matches/soul_match_waiting_screen.dart';
import '../screens/matches/voice_match_waiting_screen.dart';

class MatchHubController extends GetxController {
  // States for random matching animations/logic
  final RxBool isSearching = false.obs;
  final RxString activeGame = ''.obs; // 'soul', 'voice', etc.

  void startSoulMatch() {
    Get.to(() => const SoulMatchWaitingScreen());
  }

  void startVoiceMatch() {
    Get.to(() => const VoiceMatchWaitingScreen());
  }

  void stopSearching() {
    isSearching.value = false;
    activeGame.value = '';
  }
}
