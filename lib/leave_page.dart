import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'login.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _nameController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  Color _errorMessageColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _toController.text = 'registrar@du.ac.bd';
    _subjectController.text = 'Application for Leave of Absence';
    _initializeFromField();
  }

  Future<void> _initializeFromField() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'User not authenticated';
        _errorMessageColor = Colors.redAccent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: _errorMessageColor,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profile')
          .select('name, email')
          .eq('id', user.id)
          .maybeSingle();
      setState(() {
        _fromController.text = user.email ?? '';
        _nameController.text = profile?['name'] ?? '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching user profile: $e';
        _errorMessageColor = Colors.redAccent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: _errorMessageColor,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submitLeaveApplication() async {
    if (_nameController.text.isEmpty ||
        _fromController.text.isEmpty ||
        _toController.text.isEmpty ||
        _subjectController.text.isEmpty ||
        _bodyController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
        _errorMessageColor = Colors.redAccent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: _errorMessageColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await Supabase.instance.client.from('leave_applications').insert({
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'from_email': _fromController.text.trim(),
        'to_email': _toController.text.trim(),
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _errorMessage = 'Leave application submitted successfully!';
        _errorMessageColor = Colors.green;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: _errorMessageColor,
        ),
      );
      setState(() {
        _nameController.clear();
        _bodyController.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting application: $e';
        _errorMessageColor = Colors.redAccent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: _errorMessageColor,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/dulogo.png',
                    width: 220,
                    height: 110,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 220,
                        height: 110,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.white70,
                        ),
                      );
                    },
                  ).animate().fadeIn(duration: 800.ms).scaleXY(
                    begin: 0.8,
                    end: 1.0,
                    curve: Curves.easeOut,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'University Of Dhaka',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Name:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'e.g. John Doe',
                                prefixIcon: const Icon(Icons.person, color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ).animate().fadeIn(duration: 600.ms).slideX(
                              begin: -0.5,
                              end: 0,
                              curve: Curves.easeOut,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'From:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _fromController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'e.g. user@example.com',
                                prefixIcon: const Icon(Icons.email, color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                              enabled: false, // Disable editing as it's pre-filled
                            ).animate().fadeIn(duration: 600.ms).slideX(
                              begin: -0.5,
                              end: 0,
                              curve: Curves.easeOut,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'To:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _toController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Enter recipient email',
                                prefixIcon: const Icon(Icons.email, color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                            ).animate().fadeIn(duration: 600.ms).slideX(
                              begin: -0.5,
                              end: 0,
                              curve: Curves.easeOut,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Subject:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _subjectController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Enter subject',
                                prefixIcon: const Icon(Icons.subject, color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ).animate().fadeIn(duration: 600.ms).slideX(
                              begin: -0.5,
                              end: 0,
                              curve: Curves.easeOut,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Body:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _bodyController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Enter email body',
                                prefixIcon: const Icon(Icons.description, color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              maxLines: 15,
                            ).animate().fadeIn(duration: 600.ms).slideX(
                              begin: -0.5,
                              end: 0,
                              curve: Curves.easeOut,
                            ),
                            if (_errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                style: TextStyle(color: _errorMessageColor, fontSize: 16),
                              ).animate().fadeIn(duration: 500.ms),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.deepPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitLeaveApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 800.ms).scaleXY(
                      begin: 0.9,
                      end: 1.0,
                      curve: Curves.bounceOut,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.deepPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                    ).animate().fadeIn(duration: 800.ms).scaleXY(
                      begin: 0.9,
                      end: 1.0,
                      curve: Curves.bounceOut,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}