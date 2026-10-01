import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DiscoveryController extends GetxController {
  // Filter states
  final RxDouble maxDistance = 50.0.obs; // km
  final RxString genderPreference = 'both'.obs; // male, female, both
  final Rx<RangeValues> ageRange = const RangeValues(18, 35).obs;

  // Temporary states for the sheet (before apply)
  final RxDouble tempDistance = 50.0.obs;
  final RxString tempGender = 'both'.obs;
  final Rx<RangeValues> tempAge = const RangeValues(18, 35).obs;

  void openFilters() {
    tempDistance.value = maxDistance.value;
    tempGender.value = genderPreference.value;
    tempAge.value = ageRange.value;
  }

  void applyFilters() {
    maxDistance.value = tempDistance.value;
    genderPreference.value = tempGender.value;
    ageRange.value = tempAge.value;
    // TODO: Trigger a new discovery search based on these filters
  }

  void resetFilters() {
    tempDistance.value = 50.0;
    tempGender.value = 'both';
    tempAge.value = const RangeValues(18, 35);
  }
}
