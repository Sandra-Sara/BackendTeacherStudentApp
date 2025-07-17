import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController currentSemesterController = TextEditingController();
  final TextEditingController attachedHallController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .single();
      departmentController.text = response['department'] ?? '';
      phoneController.text = response['phone'] ?? '';
      currentSemesterController.text = response['current_semester'] ?? '';
      attachedHallController.text = response['attached_hall'] ?? '';
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('profiles').update({
        'department': departmentController.text.trim(),
        'phone': phoneController.text.trim(),
        'current_semester': currentSemesterController.text.trim(),
        'attached_hall': attachedHallController.text.trim(),
      }).eq('user_id', supabase.auth.currentUser!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    departmentController.dispose();
    phoneController.dispose();
    currentSemesterController.dispose();
    attachedHallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: departmentController,
                                decoration: InputDecoration(
                                  labelText: 'Department',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter your department' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: phoneController,
                                decoration: InputDecoration(
                                  labelText: 'Phone',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter your phone number' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: currentSemesterController,
                                decoration: InputDecoration(
                                  labelText: 'Current Semester',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter current semester' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: attachedHallController,
                                decoration: InputDecoration(
                                  labelText: 'Attached Hall',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter attached hall' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _saveProfile,
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}