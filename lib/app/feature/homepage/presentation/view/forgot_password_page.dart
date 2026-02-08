import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // ---------------- RESET PASSWORD FUNCTION ----------------
  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email")),
      );

      Navigator.pop(context);
    } on FirebaseAuthException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to send reset link")),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND IMAGE
          Image.asset(
            'lib/app/assets/welcome.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // DARK OVERLAY
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),

          // CONTENT
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BACK BUTTON
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    "Reset\nPassword",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Enter your email address to receive a reset link.",
                    style: TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 40),

                  // FORM CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // EMAIL FIELD
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Email"),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Email is required";
                              }
                              if (!value.contains("@")) {
                                return "Enter a valid email";
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // SEND RESET LINK BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _sendResetLink,
                              child: const Text(
                                "Send Reset Link",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- INPUT DECORATION ----------------
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
