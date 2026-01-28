import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _hidepassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isLogin) {
      final result = await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (result.error != null && mounted) {
        setState(() {
          _errorMessage = result.error;
          _isLoading = false;
        });
      }
    } else {
      final result = await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (result.error != null && mounted) {
        setState(() {
          _errorMessage = result.error;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInAsGuest();
    if (result.error != null && mounted) {
      setState(() {
        _errorMessage = result.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithGoogle();
    if (result.error != null && mounted) {
      setState(() {
        _errorMessage = result.error;
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Enter your email to reset password';
      });
      return;
    }

    final result = await _authService.sendPasswordResetEmail(email);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } else {
        setState(() {
          _errorMessage = result.error;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration(
                      label: "email",
                      icon: Icons.email,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: _inputDecoration(
                      label: "password",
                      icon: Icons.password,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidepassword = !_hidepassword; // ! = NOT --> hidepassword = 
                          });
                        },
                        icon: Icon(
                          _hidepassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ), obscureText: _hidepassword,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
