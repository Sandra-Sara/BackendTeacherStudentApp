import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  String? _profileImageUrl;
  Map<String, String> _profileData = {
    'Name': 'unknown',
    'ID Number': '2022315933',
    'Department': 'enter your dept name',
    'Email': 'your profile',
    'Phone': 'your phone number',
    'Current Semester': 'your year and semester',
    'Attached Hall': 'enter hall name',
    'Role': 'student',
  };
  late Map<String, TextEditingController> _controllers;
  final String userId = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _controllers = {
      'Name': TextEditingController(text: _profileData['Name']),
      'ID Number': TextEditingController(text: _profileData['ID Number']),
      'Department': TextEditingController(text: _profileData['Department']),
      'Email': TextEditingController(text: _profileData['Email']),
      'Phone': TextEditingController(text: _profileData['Phone']),
      'Current Semester': TextEditingController(text: _profileData['Current Semester']),
      'Attached Hall': TextEditingController(text: _profileData['Attached Hall']),
      'Role': TextEditingController(text: _profileData['Role']),
    };
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (userId.isNotEmpty) {
      print('User ID: $userId');
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response != null) {
        setState(() {
          _profileData = {
            'Name': response['name'] ?? _profileData['Name']!,
            'ID Number': response['id_number'] ?? _profileData['ID Number']!,
            'Department': response['department'] ?? _profileData['Department']!,
            'Email': response['email'] ?? _profileData['Email']!,
            'Phone': response['phone'] ?? _profileData['Phone']!,
            'Current Semester': response['current_semester'] ?? _profileData['Current Semester']!,
            'Attached Hall': response['attached_hall'] ?? _profileData['Attached Hall']!,
            'Role': response['role'] ?? _profileData['Role']!,
          };
          _profileImageUrl = response['profile_image_url'];
          _controllers.forEach((key, controller) {
            controller.text = _profileData[key]!;
          });
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (userId.isNotEmpty) {
      final updatedData = {
        'user_id': userId,
        'name': _controllers['Name']!.text,
        'id_number': _controllers['ID Number']!.text,
        'department': _controllers['Department']!.text,
        'email': _controllers['Email']!.text,
        'phone': _controllers['Phone']!.text,
        'current_semester': _controllers['Current Semester']!.text,
        'attached_hall': _controllers['Attached Hall']!.text,
        'role': _controllers['Role']!.text,
        'profile_image_url': _profileImageUrl,
      };
      print('Saving profile data: $updatedData');
      await Supabase.instance.client.from('profiles').upsert(updatedData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to save the profile!')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select the image source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
        ],
      ),
    );

    if (source != null) {
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        try {
          final file = File(pickedFile.path);
          final fileName = 'profile_images/$userId.png';
          print('Uploading file: $fileName');
          await Supabase.instance.client.storage.from('profile-pics').upload(fileName, file);
          final url = Supabase.instance.client.storage.from('profile-pics').getPublicUrl(fileName);
          print('Download URL: $url');
          setState(() {
            _profileImageUrl = url;
          });
          await _saveProfile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully updated profile picture!')),
          );
        } catch (e) {
          print('Error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error in uploading: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image has selected.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        _controllers.forEach((key, controller) {
          _profileData[key] = controller.text.isNotEmpty ? controller.text : _profileData[key]!;
        });
        _saveProfile();
      }
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Student Profile'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipOval(
                    child: _profileImageUrl != null
                        ? Image.network(
                      _profileImageUrl!,
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          width: 150,
                          color: Colors.grey,
                          child: const Icon(Icons.person, size: 50, color: Colors.white),
                        );
                      },
                    )
                        : Container(
                      height: 150,
                      width: 150,
                      color: Colors.grey,
                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: _pickAndUploadImage,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'University Of Dhaka',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Student Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey),
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
                      ),
                      ProfileInfoRow(
                        label: 'ID Number',
                        value: _profileData['ID Number']!,
                        isEditing: _isEditing,
                        controller: _controllers['ID Number']!,
                      ),
                      ProfileInfoRow(
                        label: 'Department',
                        value: _profileData['Department']!,
                        isEditing: _isEditing,
                        controller: _controllers['Department']!,
                      ),
                      ProfileInfoRow(
                        label: 'Email',
                        value: _profileData['Email']!,
                        isEditing: _isEditing,
                        controller: _controllers['Email']!,
                      ),
                      ProfileInfoRow(
                        label: 'Phone',
                        value: _profileData['Phone']!,
                        isEditing: _isEditing,
                        controller: _controllers['Phone']!,
                      ),
                      ProfileInfoRow(
                        label: 'Current Semester',
                        value: _profileData['Current Semester']!,
                        isEditing: _isEditing,
                        controller: _controllers['Current Semester']!,
                      ),
                      ProfileInfoRow(
                        label: 'Attached Hall',
                        value: _profileData['Attached Hall']!,
                        isEditing: _isEditing,
                        controller: _controllers['Attached Hall']!,
                      ),
                      ProfileInfoRow(
                        label: 'Role',
                        value: _profileData['Role']!,
                        isEditing: _isEditing,
                        controller: _controllers['Role']!,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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
                ),
              ),
            ],
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

  const ProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.isEditing,
    required this.controller,
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
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: isEditing
                ? TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              ),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
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