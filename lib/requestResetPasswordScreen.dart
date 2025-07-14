import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class RequestResetPasswordScreen extends StatefulWidget {
  const RequestResetPasswordScreen({super.key});

  @override
  _RequestResetPasswordScreenState createState() =>
      _RequestResetPasswordScreenState();
}

class _RequestResetPasswordScreenState
    extends State<RequestResetPasswordScreen> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();

  Future<void> _handleResetPassword() async {
    String newPassword = newPasswordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Simulate password reset confirmation
    await Future.delayed(const Duration(seconds: 1)); // Mock network delay
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Password reset successful!"),
        backgroundColor: Colors.greenAccent,
      ),
    );

    // Optionally navigate back to login page
    Navigator.pop(context);
  }

  @override
  void dispose() {
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
                              'Enter your new password to reset your account',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(duration: 600.ms),
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
                                prefixIcon:
                                const Icon(Icons.lock, color: Colors.white70),
                                labelStyle:
                                const TextStyle(color: Colors.white70),
                                hintStyle: const TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
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
                                prefixIcon:
                                const Icon(Icons.lock, color: Colors.white70),
                                labelStyle:
                                const TextStyle(color: Colors.white70),
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
                                onPressed: _handleResetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
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