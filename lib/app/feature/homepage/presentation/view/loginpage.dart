import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'forgot_password_page.dart';
import 'registerpage.dart';
import 'analytics_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AnalyticsPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = _getErrorMessage(e.code);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      print("Firebase Auth Error: ${e.code} - ${e.message}");
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );

      print("Unexpected error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      case 'operation-not-allowed':
        return 'Email/Password login is not enabled';
      default:
        return 'Login failed: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'lib/app/assets/welcome.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(51),
                  Colors.black.withAlpha(191),
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
                  const SizedBox(height: 40),
                  const Text(
                    "Welcome\nBack!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Email"),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Email is required";
                              }
                              if (!value.contains("@")) {
                                return "Enter valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            enabled: !isLoading,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration("Password").copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() => hidePassword = !hidePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Password is required";
                              }
                              if (value.length < 6) {
                                return "Minimum 6 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: rememberMe,
                                onChanged: !isLoading
                                    ? (v) {
                                        setState(() => rememberMe = v ?? false);
                                      }
                                    : null,
                                checkColor: Colors.black,
                                activeColor: Colors.white,
                              ),
                              const Text(
                                "Remember me",
                                style: TextStyle(color: Colors.white),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: !isLoading
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordPage(),
                                          ),
                                        );
                                      }
                                    : null,
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                              onPressed: isLoading ? null : _loginUser,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      "Log in",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: !isLoading
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterPage(),
                                      ),
                                    );
                                  }
                                : null,
                            child: const Text(
                              "Don't have an account? Sign up",
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withAlpha(64),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
