import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  bool _isEditing = false;
  Map<String, String> _profileData = {
    'Name': 'Unknown',
    'Teacher ID': 'T12345',
    'Department': 'Enter your department',
    'Email': 'your.email@example.com',
    'Phone': 'Your phone number',
    'Profile Image': '',
  };
  late Map<String, TextEditingController> _controllers;
  String _errorMessage = '';
  String? _profileImageUrl;
  bool _isUploadingImage = false;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controllers = {
      'Name': TextEditingController(text: _profileData['Name']),
      'Teacher ID': TextEditingController(text: _profileData['Teacher ID']),
      'Department': TextEditingController(text: _profileData['Department']),
      'Email': TextEditingController(text: _profileData['Email']),
      'Phone': TextEditingController(text: _profileData['Phone']),
    };
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to view your profile';
        _errorMessageColor = Colors.red;
      });
      return;
    }
    try {
      print('TeacherProfile: Loading profile for user ID: ${user.id}');
      final doc = await Supabase.instance.client
          .from('profile')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (doc == null) {
        setState(() {
          _errorMessage = 'Profile data not found';
          _errorMessageColor = Colors.red;
        });
        print('TeacherProfile: Profile data not found for user ID: ${user.id}');
        return;
      }
      if (doc['role'] != 'teacher') {
        setState(() {
          _errorMessage = 'Invalid profile: Not a teacher account';
          _errorMessageColor = Colors.red;
        });
        print('TeacherProfile: Invalid role: ${doc['role']}');
        return;
      }
      setState(() {
        _profileData = {
          'Name': doc['name'] ?? _profileData['Name']!,
          'Teacher ID': doc['teacher_id'] ?? _profileData['Teacher ID']!,
          'Department': doc['department'] ?? _profileData['Department']!,
          'Email': doc['email'] ?? _profileData['Email']!,
          'Phone': doc['phone'] ?? _profileData['Phone']!,
          'Profile Image': doc['profile_image'] ?? '',
        };
        _profileImageUrl = doc['profile_image']?.isNotEmpty == true
            ? Supabase.instance.client.storage.from('profileimages').getPublicUrl(doc['profile_image'])
            : null;
        _controllers.forEach((key, controller) {
          controller.text = _profileData[key]!;
        });
        _errorMessage = 'Profile loaded successfully';
        _errorMessageColor = Colors.green;
        print('TeacherProfile: Profile loaded successfully');
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _errorMessageColor = Colors.red;
      });
      print('TeacherProfile: Load profile error: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to save your profile';
        _errorMessageColor = Colors.red;
      });
      return;
    }
    try {
      print('TeacherProfile: Saving profile for user ID: ${user.id}');
      await Supabase.instance.client.from('profile').upsert({
        'id': user.id,
        'name': _controllers['Name']!.text.trim(),
        'teacher_id': _controllers['Teacher ID']!.text.trim(),
        'department': _controllers['Department']!.text.trim(),
        'email': _controllers['Email']!.text.trim(),
        'phone': _controllers['Phone']!.text.trim(),
        'role': 'teacher',
        'profile_image': _profileData['Profile Image'],
      });
      setState(() {
        _errorMessage = 'Profile saved successfully';
        _errorMessageColor = Colors.green;
      });
      print('TeacherProfile: Profile saved successfully');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving profile: $e';
        _errorMessageColor = Colors.red;
      });
      print('TeacherProfile: Save profile error: $e');
    }
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to upload an image';
        _errorMessageColor = Colors.red;
      });
      return;
    }
    try {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    await _uploadImage(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    await _uploadImage(image);
                  }
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting image: $e';
        _errorMessageColor = Colors.red;
      });
      print('TeacherProfile: Image selection error: $e');
    }
  }

  Future<bool> _isValidImage(File file, String extension) async {
    try {
      final bytes = await file.readAsBytes();
      if (extension == '.png') {
        // PNG signature: 89 50 4E 47 0D 0A 1A 0A
        if (bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) {
          return true;
        }
      } else if (extension == '.jpg' || extension == '.jpeg') {
        // JPEG signature: FF D8
        if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('TeacherProfile: Error checking image signature: $e');
      return false;
    }
  }

  Future<void> _uploadImage(XFile image) async {
    setState(() {
      _isUploadingImage = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      // Get file extension
      final String extension = path.extension(image.path).toLowerCase();
      print('TeacherProfile: Image path: ${image.path}, Extension: $extension');

      // Validate file extension
      if (!['.jpg', '.jpeg', '.png'].contains(extension)) {
        throw Exception('Unsupported file extension. Please use JPG or PNG.');
      }

      // Validate file content
      final file = File(image.path);
      if (!await _isValidImage(file, extension)) {
        throw Exception('Invalid image format. Please use a valid JPG or PNG image.');
      }

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
      print('TeacherProfile: Uploading image: $fileName');

      // Validate file size (max 5MB)
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image size exceeds 5MB limit.');
      }

      // Delete existing image if present
      if (_profileData['Profile Image']?.isNotEmpty == true) {
        try {
          await Supabase.instance.client.storage.from('profileimages').remove([_profileData['Profile Image']!]);
          print('TeacherProfile: Removed existing image: ${_profileData['Profile Image']}');
        } catch (e) {
          print('TeacherProfile: Error removing existing image: $e');
          // Continue with upload even if deletion fails
        }
      }

      // Upload new image
      await Supabase.instance.client.storage.from('profileimages').upload(fileName, file);
      final imageUrl = Supabase.instance.client.storage.from('profileimages').getPublicUrl(fileName);
      setState(() {
        _profileData['Profile Image'] = fileName;
        _profileImageUrl = imageUrl;
        _errorMessage = 'Image uploaded successfully';
        _errorMessageColor = Colors.green;
      });
      print('TeacherProfile: Image uploaded, URL: $imageUrl');
      await _saveProfile(); // Save profile with new image URL
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading image: $e';
        _errorMessageColor = Colors.red;
      });
      print('TeacherProfile: Image upload error: $e');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Color _errorMessageColor = Colors.red; // Track color for success/error messages

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        if (_formKey.currentState!.validate()) {
          _controllers.forEach((key, controller) {
            _profileData[key] = controller.text.isNotEmpty ? controller.text : _profileData[key]!;
          });
          _saveProfile();
        } else {
          return; // Don't exit editing mode if validation fails
        }
      }
      _isEditing = !_isEditing;
      _errorMessage = ''; // Clear message when toggling edit mode
      _errorMessageColor = Colors.red;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Teacher Profile'),
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _isEditing ? _pickImage : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 75,
                              backgroundImage: _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : const AssetImage('assets/profile.png') as ImageProvider,
                              child: _profileImageUrl == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                            if (_isEditing)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                              ),
                            if (_isUploadingImage)
                              const CircularProgressIndicator(),
                          ],
                        ),
                      ).animate().fadeIn(duration: 800.ms),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'University Of Dhaka',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Teacher Profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white70),
                    ),
                    const SizedBox(height: 30),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileInfoRow(
                              label: 'Name',
                              value: _profileData['Name']!,
                              isEditing: _isEditing,
                              controller: _controllers['Name']!,
                              validator: (value) =>
                              value!.trim().isEmpty ? 'Please enter your name' : null,
                            ).animate().fadeIn(duration: 600.ms),
                            ProfileInfoRow(
                              label: 'Teacher ID',
                              value: _profileData['Teacher ID']!,
                              isEditing: _isEditing,
                              controller: _controllers['Teacher ID']!,
                              validator: (value) =>
                              value!.trim().isEmpty ? 'Please enter your teacher ID' : null,
                            ).animate().fadeIn(duration: 650.ms),
                            ProfileInfoRow(
                              label: 'Department',
                              value: _profileData['Department']!,
                              isEditing: _isEditing,
                              controller: _controllers['Department']!,
                              validator: (value) =>
                              value!.trim().isEmpty ? 'Please enter your department' : null,
                            ).animate().fadeIn(duration: 700.ms),
                            ProfileInfoRow(
                              label: 'Email',
                              value: _profileData['Email']!,
                              isEditing: _isEditing,
                              controller: _controllers['Email']!,
                              validator: (value) {
                                if (value!.trim().isEmpty) return 'Please enter your email';
                                if (!value.contains('@') || !value.contains('.'))
                                  return 'Please enter a valid email';
                                return null;
                              },
                            ).animate().fadeIn(duration: 750.ms),
                            ProfileInfoRow(
                              label: 'Phone',
                              value: _profileData['Phone']!,
                              isEditing: _isEditing,
                              controller: _controllers['Phone']!,
                              validator: (value) {
                                if (value!.trim().isEmpty) return 'Please enter your phone number';
                                if (!RegExp(r'^\d+$').hasMatch(value))
                                  return 'Please enter a valid phone number';
                                return null;
                              },
                            ).animate().fadeIn(duration: 800.ms),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.5, end: 0),
                    const SizedBox(height: 20),
                    if (_errorMessage.isNotEmpty)
                      Text(
                        _errorMessage,
                        style: TextStyle(color: _errorMessageColor),
                      ).animate().fadeIn(duration: 500.ms),
                    Center(
                      child: ElevatedButton(
                        onPressed: _toggleEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          _isEditing ? 'Save' : 'Edit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ).animate().fadeIn(duration: 600.ms),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/teacher_dashboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ).animate().fadeIn(duration: 600.ms),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const ProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isEditing,
    required this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: isEditing
                ? TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              ),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              validator: validator,
            )
                : Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}