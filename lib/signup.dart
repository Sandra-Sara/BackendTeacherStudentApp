import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'login.dart';

enum LoginType { student, teacher }

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController regOrTeacherIdController = TextEditingController();
  LoginType _loginType = LoginType.student;
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String email = emailController.text.trim().toLowerCase();
      String password = passwordController.text.trim();
      String name = nameController.text.trim();
      String regOrTeacherId = regOrTeacherIdController.text.trim();

      print('SignUp: Attempting to create user with email: $email');

      // Create user with Supabase Authentication
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Signup failed: User not created');
      }
      print('SignUp: User created with ID: ${user.id}');

      // Update display name
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'display_name': name}),
        );
        print('SignUp: Display name updated: $name');
      } catch (e) {
        print('SignUp: Failed to update display name: $e');
        await Supabase.instance.client.auth.signOut();
        throw Exception('Failed to update display name: $e');
      }

      // Store user data in Supabase
      final data = {
        'id': user.id,
        'name': name,
        'email': email,
        'role': _loginType == LoginType.student ? 'student' : 'teacher',
        'department': '',
        'phone': '',
        'reg_no': _loginType == LoginType.student ? regOrTeacherId : '',
        'teacher_id': _loginType == LoginType.teacher ? regOrTeacherId : '',
        'semester': _loginType == LoginType.student ? '' : '',
        'hall': _loginType == LoginType.student ? '' : '',
        'profile_image': '',
      };

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await Supabase.instance.client.from('profile').insert(data);
          print('SignUp: User data inserted for role: ${_loginType == LoginType.student ? 'student' : 'teacher'}');
          break;
        } catch (e) {
          print('SignUp: Attempt $attempt failed to insert user data: $e');
          if (attempt == 3) {
            await Supabase.instance.client.auth.signOut();
            throw Exception('Failed to insert user data after retries: $e');
          }
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      // Verify profile insertion
      final verification = await Supabase.instance.client
          .from('profile')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (verification == null) {
        await Supabase.instance.client.auth.signOut();
        throw Exception('Failed to verify profile insertion for user ID: ${user.id}');
      }
      print('SignUp: Profile insertion verified for user ID: ${user.id}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_loginType == LoginType.student ? 'Student' : 'Teacher'} account created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/login');
    } on AuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email_exists':
          message = 'Email already registered.';
          break;
        case 'invalid_email':
          message = 'Invalid email format.';
          break;
        case 'weak_password':
          message = 'Password must be at least 6 characters.';
          break;
        default:
          message = 'Signup failed: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
      print('SignUp: AuthException: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      print('SignUp: General error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nameController.dispose();
    regOrTeacherIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('SignUpPage: Building UI');
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
                    'University of Dhaka',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black26,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 800.ms),
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
                            children: [
                              SegmentedButton<LoginType>(
                                segments: const [
                                  ButtonSegment(
                                    value: LoginType.student,
                                    label: Text('Student', style: TextStyle(color: Colors.black)),
                                    icon: Icon(Icons.school, color: Colors.black),
                                  ),
                                  ButtonSegment(
                                    value: LoginType.teacher,
                                    label: Text('Teacher', style: TextStyle(color: Colors.black)),
                                    icon: Icon(Icons.person_2, color: Colors.black),
                                  ),
                                ],
                                selected: {_loginType},
                                onSelectionChanged: (newSelection) {
                                  setState(() {
                                    _loginType = newSelection.first;
                                    emailController.clear();
                                    passwordController.clear();
                                    confirmPasswordController.clear();
                                    nameController.clear();
                                    regOrTeacherIdController.clear();
                                    _errorMessage = '';
                                  });
                                },
                              ).animate().fadeIn(duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  labelText: 'Full Name',
                                  hintText: 'e.g. Anisha Tabassum',
                                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: const TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) => value == null || value.trim().isEmpty
                                    ? 'Please enter your name'
                                    : null,
                              ).animate().slideX(
                                begin: -0.5,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              ).fadeIn(duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  labelText: 'Email',
                                  hintText: 'e.g. user@example.com',
                                  prefixIcon: const Icon(Icons.email, color: Colors.white70),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: const TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ).animate().slideX(
                                begin: -0.5,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              ).fadeIn(duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: const TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) => value == null || value.length < 6
                                    ? 'Password must be at least 6 characters'
                                    : null,
                              ).animate().slideX(
                                begin: 0.5,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              ).fadeIn(duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: confirmPasswordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  labelText: 'Confirm Password',
                                  hintText: 'Re-enter your password',
                                  prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: const TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) =>
                                value != passwordController.text ? 'Passwords do not match' : null,
                              ).animate().slideX(
                                begin: 0.5,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              ).fadeIn(duration: 600.ms),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: regOrTeacherIdController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white24,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  labelText: _loginType == LoginType.student
                                      ? 'Registration Number'
                                      : 'Teacher ID',
                                  hintText: _loginType == LoginType.student
                                      ? 'e.g. 2022315933'
                                      : 'e.g. T12345',
                                  prefixIcon: const Icon(Icons.badge, color: Colors.white70),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: const TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) => value == null || value.trim().isEmpty
                                    ? 'Please enter your ${_loginType == LoginType.student ? 'registration number' : 'teacher ID'}'
                                    : null,
                              ).animate().slideX(
                                begin: 0.5,
                                end: 0,
                                duration: 600.ms,
                                curve: Curves.easeOut,
                              ).fadeIn(duration: 600.ms),
                              const SizedBox(height: 16),
                              if (_errorMessage.isNotEmpty)
                                Text(
                                  _errorMessage,
                                  style: const TextStyle(color: Colors.redAccent),
                                ).animate().fadeIn(duration: 500.ms),
                              const SizedBox(height: 24),
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
                                  onPressed: _isLoading ? null : _handleSignUp,
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
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(duration: 800.ms).scaleXY(
                                begin: 0.9,
                                end: 1.0,
                                duration: 600.ms,
                                curve: Curves.bounceOut,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 1000.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}