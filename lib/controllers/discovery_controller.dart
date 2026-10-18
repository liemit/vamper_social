import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiscoveryController extends GetxController {
  // Filter states
  final RxDouble maxDistance = 50.0.obs; // km
  final RxString genderPreference = 'both'.obs; // male, female, both
  final Rx<RangeValues> ageRange = const RangeValues(18, 35).obs;

  // Temporary states for the sheet (before apply)
  final RxDouble tempDistance = 50.0.obs;
  final RxString tempGender = 'both'.obs;
  final Rx<RangeValues> tempAge = const RangeValues(18, 35).obs;

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      maxDistance.value = prefs.getDouble('discovery_max_distance') ?? 50.0;
      genderPreference.value = prefs.getString('discovery_gender_pref') ?? 'both';
      final double ageMin = prefs.getDouble('discovery_age_min') ?? 18.0;
      final double ageMax = prefs.getDouble('discovery_age_max') ?? 35.0;
      ageRange.value = RangeValues(ageMin, ageMax);
    } catch (e) {
      print('Error loading discovery preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('discovery_max_distance', maxDistance.value);
      await prefs.setString('discovery_gender_pref', genderPreference.value);
      await prefs.setDouble('discovery_age_min', ageRange.value.start);
      await prefs.setDouble('discovery_age_max', ageRange.value.end);
    } catch (e) {
      print('Error saving discovery preferences: $e');
    }
  }

  void openFilters() {
    tempDistance.value = maxDistance.value;
    tempGender.value = genderPreference.value;
    tempAge.value = ageRange.value;
  }

  void applyFilters() {
    maxDistance.value = tempDistance.value;
    genderPreference.value = tempGender.value;
    ageRange.value = tempAge.value;
    _savePreferences();
  }

  void resetFilters() {
    tempDistance.value = 50.0;
    tempGender.value = 'both';
    tempAge.value = const RangeValues(18, 35);
  }
}
