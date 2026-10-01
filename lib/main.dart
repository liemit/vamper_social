import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app.dart';
import 'controllers/auth_controller.dart';

void main() async {
  print('🚀 App is starting...');
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ Flutter Binding Initialized');
  
  try {
    Get.put(AuthController());
    print('✅ AuthController Injected');
  } catch (e) {
    print('🚨 Controller Injection Error: $e');
  }
  
  runApp(const VamperApp());
  print('🎬 runApp() called');
}
