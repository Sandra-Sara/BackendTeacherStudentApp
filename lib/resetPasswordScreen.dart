import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleResetPassword() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final code = codeController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Validate inputs
    if (code.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = "Please fill all fields";
        _isLoading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = "Passwords do not match";
        _isLoading = false;
      });
      return;
    }

    if (newPassword.length < 8) {
      setState(() {
        _errorMessage = "Password must be at least 8 characters";
        _isLoading = false;
      });
      return;
    }

    try {
      // Verify the reset code
      await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.recovery,
      );

      // Update the password
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset successful! Redirecting to login..."),
          backgroundColor: Colors.greenAccent,
        ),
      );

      // Navigate to login page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false, // Remove all previous routes
      );
    } catch (e) {
      // Handle specific Supabase errors
      String errorMsg = "An error occurred. Please try again.";
      if (e.toString().contains("Invalid")) {
        errorMsg = "Invalid or expired reset code. Please request a new code.";
      } else if (e.toString().contains("Auth")) {
        errorMsg = "Authentication error. Please try again or contact support.";
      } else {
        errorMsg = "Error: ${e.toString()}";
      }
      setState(() {
        _errorMessage = errorMsg;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
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
                              'Set New Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 16),
                            const Text(
                              'Enter the reset code from your email and your new password',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(duration: 600.ms),
                            const SizedBox(height: 16),
                            TextField(
                              controller: codeController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                labelText: 'Reset Code',
                                hintText: 'Enter the code from email',
                                prefixIcon: const Icon(Icons.vpn_key, color: Colors.white70),
                                labelStyle: const TextStyle(color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.text,
                            )
                                .animate()
                                .slideX(
                              begin: -0.5,
                              end: 0,
                              duration: 600.ms,
                              curve: Curves.easeOut,
                            )
                                .fadeIn(duration: 600.ms),
                            const SizedBox(height: 16),
                            TextField(
                              controller: newPasswordController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                labelText: 'New Password',
                                hintText: 'Enter new password',
                                prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                                labelStyle: const TextStyle(color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
                            )
                                .animate()
                                .slideX(
                              begin: -0.5,
                              end: 0,
                              duration: 700.ms,
                              curve: Curves.easeOut,
                            )
                                .fadeIn(duration: 700.ms),
                            const SizedBox(height: 16),
                            TextField(
                              controller: confirmPasswordController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white24,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                labelText: 'Confirm Password',
                                hintText: 'Re-enter new password',
                                prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                                labelStyle: const TextStyle(color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
                            )
                                .animate()
                                .slideX(
                              begin: -0.5,
                              end: 0,
                              duration: 800.ms,
                              curve: Curves.easeOut,
                            )
                                .fadeIn(duration: 800.ms),
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
                                onPressed: _isLoading ? null : _handleResetPassword,
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
                                  "Reset Password",
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
                        "Forgot Password",
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