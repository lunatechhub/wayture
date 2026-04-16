import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/core/app_routes.dart';
import 'package:wayture/services/auth_service.dart';

/// Sign up screen — matches the login screen glassmorphism style, responsive.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final error = await auth.signUp(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(_successSnack('Account created! Welcome to Wayture'));
      Navigator.pushReplacementNamed(context, AppRoutes.permissions);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (mounted) setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final error = await auth.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(_successSnack('Account created! Welcome to Wayture'));
      Navigator.pushReplacementNamed(context, AppRoutes.permissions);
    }
  }

  SnackBar _successSnack(String msg) => SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600;
    final isWide = size.width > 600;
    final horizontalPadding = isWide ? size.width * 0.15 : 20.0;
    final titleSize = isSmall ? 26.0 : (isWide ? 36.0 : 32.0);
    final topSpacing = isSmall ? 12.0 : 30.0;
    final cardMaxWidth = isWide ? 480.0 : double.infinity;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Image.asset(
            AppConstants.backgroundImage,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // Gradient overlay
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
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(height: topSpacing),
                      Text(
                        "Create\nAccount",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: topSpacing),
                      // Glassmorphism form card
                      Container(
                        padding: EdgeInsets.all(isSmall ? 16 : 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _inputField(_nameController, "Full Name"),
                              const SizedBox(height: 12),
                              _inputField(_emailController, "Email", isEmail: true),
                              const SizedBox(height: 12),
                              _passwordField(_passwordController, "Password", false),
                              const SizedBox(height: 12),
                              _passwordField(
                                  _confirmPasswordController, "Confirm Password", true),
                              SizedBox(height: isSmall ? 16 : 24),
                              // Sign up button
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
                                  onPressed: _isLoading ? null : _signup,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(Colors.black),
                                          ),
                                        )
                                      : const Text(
                                          "Sign Up",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Divider with OR
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.white38, thickness: 0.5)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('OR', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: Colors.white38, thickness: 0.5)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Google Sign-In button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.white.withAlpha(25),
                                  ),
                                  onPressed: _isLoading ? null : _signInWithGoogle,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Google "G" logo using text (no external asset needed)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'G',
                                            style: TextStyle(
                                              color: Color(0xFF4285F4),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushReplacementNamed(
                                        context, AppRoutes.login),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String hint,
      {bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      enabled: !_isLoading,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint),
      validator: (v) {
        if (v == null || v.isEmpty) return "$hint is required";
        if (isEmail && !v.contains("@")) return "Enter valid email";
        return null;
      },
    );
  }

  Widget _passwordField(
      TextEditingController controller, String hint, bool isConfirm) {
    final obscure = isConfirm ? _hideConfirm : _hidePassword;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: !_isLoading,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
          onPressed: () {
            if (mounted) {
              setState(() {
                if (isConfirm) {
                  _hideConfirm = !_hideConfirm;
                } else {
                  _hidePassword = !_hidePassword;
                }
              });
            }
          },
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "$hint is required";
        if (!isConfirm && v.length < 6) return "Min 6 characters";
        if (isConfirm && v != _passwordController.text) {
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
      fillColor: Colors.white.withAlpha(64),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
