import 'package:flutter/material.dart';
import '/controllers/auth_controller.dart';
import '/controllers/user_controller.dart';
import '/models/user_model.dart';
import '/widgets/custom_button.dart';
import '/widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authController = AuthController();
  final _userController = UserController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Inline error (no SnackBar)
  String? _errorMessage;

  // --- Validators ---
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your full name';
    if (v.trim().length < 2) return 'Name looks too short';
    return null;
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email required';
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Password required';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text.trim()) {
      return "Passwords don't match";
    }
    return null;
  }

  // --- Actions ---
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null); // clear previous error

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // AuthController.register should return:
      //  - true   => success
      //  - false  => generic failure
      //  - String => specific error message (e.g. "Email already registered")
      final ok = await _authController.register(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );

      if (!mounted) return;

      if (ok == true) {
        Navigator.pushReplacementNamed(context, '/home');

        final userId = _authController.getCurrentUser()?.id;
        if (userId != null) {
          await _userController.createUserProfile(
            UserModel(
              id: userId,
              fullName: _nameController.text.trim(),
              email: _emailController.text.trim(),
            ),
          );
        }
      } else {
        final msg = (ok is String && ok.isNotEmpty)
            ? ok
            : 'Registration failed. Please try again.';
        setState(() => _errorMessage = msg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToLogin() => Navigator.pushReplacementNamed(context, '/login');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add, color: Colors.purple, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // Full name
                      CustomTextField(
                        controller: _nameController,
                        hint: 'Full Name',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        validator: _validateName,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      CustomTextField(
                        controller: _emailController,
                        hint: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      // Password
                      CustomTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        validator: _validatePassword,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      CustomTextField(
                        controller: _confirmPasswordController,
                        hint: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_person_outlined),
                        validator: _validateConfirm,
                        obscure: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          tooltip: _obscureConfirm
                              ? 'Show password'
                              : 'Hide password',
                        ),
                        onSubmitted: (_) {
                          if (!_isLoading) _register();
                        },
                      ),
                      const SizedBox(height: 24),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          label: _isLoading ? 'Registering...' : 'Register',
                          onPressed: _isLoading ? null : _register,
                          color: Colors.purple,
                          loading: _isLoading,
                        ),
                      ),

                      // Inline error message (no SnackBar)
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _isLoading ? null : _goToLogin,
                        child: const Text('Already have an account? Login'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'By creating an account you agree to our Terms and Privacy Policy.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color.fromARGB(229, 0, 0, 0),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
