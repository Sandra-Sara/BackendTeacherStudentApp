import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'signup.dart';
import 'forgot_password_page.dart';
import 'about_us_page.dart';

enum LoginType { student, teacher }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  LoginType _loginType = LoginType.student;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      String email = emailController.text.trim().toLowerCase();
      String password = passwordController.text.trim();

      print('Login: Attempting to sign in with email: $email');

      // Sign in with Supabase Authentication
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Login failed: No user found');
      }
      print('Login: User signed in with ID: ${user.id}');

      // Fetch profile with retries
      var userDoc;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          print('Login: Attempt $attempt to fetch profile for user ID: ${user.id}');
          userDoc = await Supabase.instance.client
              .from('profile')
              .select()
              .eq('id', user.id)
              .maybeSingle();
          break;
        } catch (e) {
          print('Login: Attempt $attempt failed to fetch user data: $e');
          if (attempt == 3) {
            throw Exception('Failed to fetch user data after retries: $e');
          }
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      if (userDoc == null) {
        print('Login: No profile found, creating default profile for user ID: ${user.id}');
        userDoc = {
          'id': user.id,
          'email': email,
          'role': _loginType == LoginType.student ? 'student' : 'teacher',
          'name': '',
          'department': '',
          'phone': '',
          'reg_no': '',
          'teacher_id': '',
          'semester': '',
          'hall': '',
          'profile_image': '',
        };
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            await Supabase.instance.client.from('profile').insert(userDoc);
            print('Login: Default profile created for user ID: ${user.id}');
            break;
          } catch (e) {
            print('Login: Attempt $attempt failed to create default profile: $e');
            if (attempt == 3) {
              throw Exception('Failed to create default profile: $e');
            }
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
        // Verify profile creation
        userDoc = await Supabase.instance.client
            .from('profile')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (userDoc == null) {
          throw Exception('Failed to verify default profile creation');
        }
      }

      String? role = userDoc['role'] as String?;
      print('Login: User role fetched: $role');

      if (role == null || (role != 'student' && role != 'teacher')) {
        throw Exception('Invalid user role: $role');
      }

      // Verify role matches selected login type
      if ((role == 'student' && _loginType != LoginType.student) ||
          (role == 'teacher' && _loginType != LoginType.teacher)) {
        throw Exception('Selected login type does not match user role: $role');
      }

      // Navigate based on role
      String route = role == 'student' ? '/student_dashboard' : '/teacher_dashboard';
      print('Login: Navigating to $route');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login successful'),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid_credentials':
          message = 'Invalid email or password.';
          break;
        case 'user_not_found':
          message = 'No user found for this email.';
          break;
        default:
          message = 'Login failed: ${e.message}';
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
      print('Login: AuthException: $e');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      print('Login: General error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  void _handleSignUp() {
    Navigator.pushNamed(context, '/signup');
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('LoginPage: Building UI');
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
                                    _errorMessage = '';
                                  });
                                },
                              ).animate().fadeIn(duration: 600.ms),
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
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
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
                                  onPressed: _isLoading ? null : _handleLogin,
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
                                    'Log In',
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
                        'Forgot your password? ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: _handleForgotPassword,
                        child: const Text(
                          'Get help',
                          style: TextStyle(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 1000.ms),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text(
                    'Don’t have an account? ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: _handleSignUp,
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().fadeIn(duration: 1200.ms),
                  const SizedBox(height: 32),
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
                      onPressed: () {
                        Navigator.pushNamed(context, '/about_us');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'About Us',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 1400.ms).scaleXY(
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
    );
  }
}