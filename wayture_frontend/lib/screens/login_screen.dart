import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wayture/config/constants.dart';
import 'package:wayture/core/app_routes.dart';
import 'package:wayture/services/auth_service.dart';

/// Login screen with glassmorphism form card — responsive layout.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _isLoading = true);

    final auth = context.read<AuthService>();
    final error = await auth.signIn(
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
        ..showSnackBar(_successSnack('Welcome back! Logged in successfully'));
      Navigator.pushReplacementNamed(context, AppRoutes.home);
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
        ..showSnackBar(_successSnack('Welcome back! Logged in successfully'));
      Navigator.pushReplacementNamed(context, AppRoutes.home);
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
    final topSpacing = isSmall ? 16.0 : 40.0;
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
                        "Welcome\nBack!",
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
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_isLoading,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration("Email"),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Email is required";
                                  if (!v.contains("@")) return "Enter valid email";
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _hidePassword,
                                enabled: !_isLoading,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration("Password").copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _hidePassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () {
                                      if (mounted) setState(() => _hidePassword = !_hidePassword);
                                    },
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return "Password is required";
                                  if (v.length < 6) return "Minimum 6 characters";
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              // Remember me + Forgot password — wrap on small screens
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: !_isLoading
                                            ? (v) {
                                                if (mounted) setState(() => _rememberMe = v ?? false);
                                              }
                                            : null,
                                        checkColor: Colors.black,
                                        activeColor: Colors.white,
                                      ),
                                      const Text("Remember me",
                                          style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: !_isLoading
                                        ? () => Navigator.pushNamed(
                                              context,
                                              AppRoutes.forgotPassword,
                                              arguments:
                                                  _emailController.text.trim(),
                                            )
                                        : null,
                                    child: const Text(
                                      "Forgot Password?",
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmall ? 10 : 14),
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
                                  onPressed: _isLoading ? null : _login,
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
                                          "Log in",
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
                                onPressed: !_isLoading
                                    ? () => Navigator.pushNamed(
                                        context, AppRoutes.register)
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
