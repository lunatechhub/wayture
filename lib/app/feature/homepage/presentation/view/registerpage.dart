import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'loginpage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userCredential.user!.uid)
      //     .set({
      //       'name': nameController.text.trim(),
      //       'email': emailController.text.trim(),
      //       'createdAt': Timestamp.now(),
      //     });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ✅ FIXED ASSET PATH (and removed const because no need)
          Image.asset(
            'lib/app/assets/welcome.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // ✅ FIXED alpha
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(51), // 20%
                  Colors.black.withAlpha(191), // 75%
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Create\nAccount",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38), // 15%
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _inputField(controller: nameController, hint: "Name"),
                          const SizedBox(height: 12),
                          _inputField(
                            controller: emailController,
                            hint: "Email",
                            isEmail: true,
                          ),
                          const SizedBox(height: 12),
                          _passwordField(
                            controller: passwordController,
                            hint: "Password",
                            isConfirm: false,
                          ),
                          const SizedBox(height: 12),
                          _passwordField(
                            controller: confirmPasswordController,
                            hint: "Confirm Password",
                            isConfirm: true,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "By continuing, you agree to our Terms of Service\nand Privacy Policy.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                              onPressed: _registerUser,
                              child: const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Already have an account? Log in",
                              style: TextStyle(color: Colors.white70),
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

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    bool isEmail = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint),
      validator: (v) {
        if (v == null || v.isEmpty) return "$hint is required";
        if (isEmail && !v.contains("@")) return "Enter valid email";
        return null;
      },
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool isConfirm,
  }) {
    final bool obscure = isConfirm ? hideConfirmPassword : hidePassword;

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: () {
            setState(() {
              if (isConfirm) {
                hideConfirmPassword = !hideConfirmPassword;
              } else {
                hidePassword = !hidePassword;
              }
            });
          },
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "$hint is required";
        if (!isConfirm && v.length < 6) return "Min 6 characters";
        if (isConfirm && v != passwordController.text.trim()) {
          return "Passwords do not match";
        }
        return null;
      },
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withAlpha(64), // 25%
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
