import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'resetPasswordScreen.dart'; // Import the new ResetPasswordScreen

class RequestResetPasswordScreen extends StatefulWidget {
  const RequestResetPasswordScreen({super.key});

  @override
  _RequestResetPasswordScreenState createState() => _RequestResetPasswordScreenState();
}

class _RequestResetPasswordScreenState extends State<RequestResetPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _requestResetPassword() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email";
        _isLoading = false;
      });
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() {
        _errorMessage = "Please enter a valid email address";
        _isLoading = false;
      });
      return;
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reset code sent to your email! Check your inbox."),
          backgroundColor: Colors.greenAccent,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(email: email),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
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
                      return const SizedBox(
                        width: 220,
                        height: 110,
                        child: Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.white70,
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .scaleXY(begin: 0.8, end: 1.0, curve: Curves.easeOut),
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
                          children: [
                            const Text(
                              'Forgot Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 16),
                            const Text(
                              'Enter your DU email to receive a reset code',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 16),
                            TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                labelText: 'DU Email',
                                hintText: 'e.g., student@du.ac.bd',
                                prefixIcon: const Icon(Icons.email, color: Colors.white70),
                                labelStyle: const TextStyle(color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                            )
                                .animate()
                                .slideX(
                              begin: -0.5,
                              end: 0,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            )
                                .fadeIn(duration: 600.ms),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                              ),
                            ],
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
                                onPressed: _isLoading ? null : _requestResetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  "Send Reset Code",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 800.ms)
                                .scaleXY(
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
                      "Back to ",
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Login",
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
    );
  }
}
