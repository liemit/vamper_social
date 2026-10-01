import 'package:get/get.dart';
import 'package:flutter/material.dart';

class MatchHubController extends GetxController {
  // States for random matching animations/logic
  final RxBool isSearching = false.obs;
  final RxString activeGame = ''.obs; // 'soul', 'voice', etc.

  void startSoulMatch() {
    activeGame.value = 'soul';
    isSearching.value = true;
    // Future logic: call API to find stranger
  }

  void startVoiceMatch() {
    activeGame.value = 'voice';
    isSearching.value = true;
    // Future logic: call API to find stranger
  }

  void stopSearching() {
    isSearching.value = false;
    activeGame.value = '';
  }
}
