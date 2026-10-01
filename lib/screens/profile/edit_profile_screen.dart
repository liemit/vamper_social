import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/api_constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthController _authController = Get.find<AuthController>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  
  double? _latitude;
  double? _longitude;
  bool _isDetectingLocation = false;
  
  String? _selectedGender;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final user = _authController.currentUser.value;
    _nameController = TextEditingController(text: user?.fullName);
    _phoneController = TextEditingController(text: user?.phone);
    _bioController = TextEditingController(text: user?.bio);
    _locationController = TextEditingController(text: user?.location);
    _latitude = double.tryParse(user?.latitude ?? '');
    _longitude = double.tryParse(user?.longitude ?? '');
    _selectedGender = user?.gender;
    
    if (user?.dateOfBirth != null) {
      try {
        _selectedDate = DateTime.parse(user!.dateOfBirth!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _selectedDate != null 
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!) 
            : null,
        latitude: _latitude,
        longitude: _longitude,
      );

      if (success) {
        Get.back();
      }
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar('Permission Denied', 'Location permissions are denied');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar('Permission Error', 'Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      _latitude = position.latitude;
      _longitude = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.locality}, ${place.country}";
        setState(() {
          _locationController.text = address;
        });
      }
    } catch (e) {
      print('❌ GPS Error: $e');
      Get.snackbar('Error', 'Failed to get location: $e');
    } finally {
      setState(() => _isDetectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => LoadingOverlay(
      isLoading: _authController.isLoading.value,
      message: 'Updating profile...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      Obx(() {
                        final user = _authController.currentUser.value;
                        final photoUrl = _authController.getFullImageUrl(user?.profilePhoto);
                        
                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: ClipOval(
                            child: photoUrl != null
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                    },
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50, color: Colors.white),
                                  )
                                : const Icon(Icons.person, size: 50, color: Colors.white),
                          ),
                        );
                      }),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _authController.pickAndUploadPhoto(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              CustomTextField(
                label: 'Full Name',
                hint: 'Enter your name',
                controller: _nameController,
                prefixIcon: Icons.person_outline,
                validator: (value) => (value == null || value.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              CustomTextField(
                label: 'Phone Number',
                hint: 'Enter your phone',
                controller: _phoneController,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              const Text('Gender', style: AppTextStyles.body2),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GenderChip(label: 'Male', isSelected: _selectedGender == 'male', onTap: () => setState(() => _selectedGender = 'male')),
                  const SizedBox(width: 12),
                  _GenderChip(label: 'Female', isSelected: _selectedGender == 'female', onTap: () => setState(() => _selectedGender = 'female')),
                  const SizedBox(width: 12),
                  _GenderChip(label: 'Other', isSelected: _selectedGender == 'other', onTap: () => setState(() => _selectedGender = 'other')),
                ],
              ),
              const SizedBox(height: 20),

              const Text('Date of Birth', style: AppTextStyles.body2),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(_selectedDate == null ? 'Select your birthday' : DateFormat('MMM dd, yyyy').format(_selectedDate!), style: TextStyle(color: _selectedDate == null ? AppColors.textLight : AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              CustomTextField(label: 'Bio', hint: 'Write something about yourself...', controller: _bioController, prefixIcon: Icons.info_outline, maxLines: 3),
              const SizedBox(height: 20),

              // Location with GPS Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Location',
                      hint: 'City, Country',
                      controller: _locationController,
                      prefixIcon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isDetectingLocation ? null : _detectLocation,
                    child: Container(
                      height: 54, width: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: _isDetectingLocation
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              Obx(() => GradientButton(
                text: 'Save Changes',
                onPressed: _handleSave,
                isLoading: _authController.isLoading.value,
                width: double.infinity,
              )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    )));
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
