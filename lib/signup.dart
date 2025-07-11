import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController regNumberController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController currentSemesterController = TextEditingController();
  final TextEditingController attachedHallController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (response.user != null) {
        await supabase.from('profiles').insert({
          'user_id': response.user!.id,
          'email': emailController.text.trim(),
          'name': nameController.text.trim(),
          'role': 'student',
          'id_number': regNumberController.text.trim(),
          'department': departmentController.text.trim(),
          'phone': phoneController.text.trim(),
          'current_semester': currentSemesterController.text.trim(),
          'attached_hall': attachedHallController.text.trim(),
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response.session!.accessToken);
        await prefs.setString('user_role', 'student');
        await prefs.setString('profile_email', emailController.text.trim());
        await prefs.setString('profile_name', nameController.text.trim());
        await prefs.setString('profile_reg', regNumberController.text.trim());
        await prefs.setString('profile_department', departmentController.text.trim());
        await prefs.setString('profile_phone', phoneController.text.trim());
        await prefs.setString('profile_semester', currentSemesterController.text.trim());
        await prefs.setString('profile_hall', attachedHallController.text.trim());

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: ${e.message}')),
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
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    regNumberController.dispose();
    departmentController.dispose();
    phoneController.dispose();
    currentSemesterController.dispose();
    attachedHallController.dispose();
    super.dispose();
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/dulogo.png',
                      width: 220,
                      height: 110,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        width: 220,
                        height: 110,
                        child: Icon(Icons.image_not_supported, color: Colors.white70),
                      ),
                    ).animate().fadeIn(duration: 800.ms).scaleXY(begin: 0.8, end: 1.0, curve: Curves.easeOut),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'University Of Dhaka',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 48),
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
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter your name' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => !value!.contains('@') || !value.contains('.') ? 'Enter a valid email' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter password' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: confirmPasswordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Confirm your password' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: regNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Registration Number',
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                                validator: (value) => value!.trim().isEmpty ? 'Enter registration number' : null,
                              ).animate().slideX(begin: -0.5, end: 0, duration: 600.ms),
                              const SizedBox(height: 16),
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
                                onPressed: _isLoading ? null : _handleSignUp,
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text('Sign Up'),
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