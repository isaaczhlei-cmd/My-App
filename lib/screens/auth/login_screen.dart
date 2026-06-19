import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import 'forgot_password_screen.dart';
import 'widgets/signup_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthServiceLike? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  void _handleSuccessfulAuth() {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.error != null) {
          _errorMessage = result.error;
        }
      });

      if (result.error == null) {
        _handleSuccessfulAuth();
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.error != null) {
          _errorMessage = result.error;
        }
      });

      if (result.error == null) {
        _handleSuccessfulAuth();
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signInWithApple();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.error != null) {
          _errorMessage = result.error;
        }
      });

      if (result.error == null) {
        _handleSuccessfulAuth();
      }
    }
  }

  Future<void> _signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.registerWithEmail(
      email: email,
      password: password,
      displayName: name,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.error != null) {
          _errorMessage = result.error;
        }
      });

      if (result.error == null) {
        _handleSuccessfulAuth();
      }
    }
  }

  void _handleForgotPasswordTap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordScreen(
          authService: _authService,
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo and title
                _buildHeader(),
                const SizedBox(height: 40),

                // Login/Sign Up toggle
                _buildAuthToggle(),
                const SizedBox(height: 32),

                // Auth form content with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: Offset(_isLoginMode ? -0.3 : 0.3, 0.0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                  child: _isLoginMode
                      ? KeyedSubtree(
                          key: const ValueKey('login'),
                          child: _buildLoginForm(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('signup'),
                          child: _buildSignUpForm(),
                        ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final themeColors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeColors.card,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.flight, size: 60, color: primary),
        ),
        const SizedBox(height: 16),
        Text(
          'flightprint',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: themeColors.onCard,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your flight emissions',
          style: TextStyle(fontSize: 16, color: themeColors.onCardMuted),
        ),
      ],
    );
  }

  Widget _buildAuthToggle() {
    final themeColors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: themeColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: themeColors.outlineSoft),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final toggleWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Animated sliding indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: _isLoginMode ? 0 : toggleWidth,
                top: 0,
                bottom: 0,
                width: toggleWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Toggle buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_isLoginMode) {
                          setState(() {
                            _isLoginMode = true;
                            _errorMessage = null;
                          });
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isLoginMode
                                ? Colors.white
                                : themeColors.onCardMuted,
                          ),
                          child: const Text('Login'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_isLoginMode) {
                          setState(() {
                            _isLoginMode = false;
                            _errorMessage = null;
                          });
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: !_isLoginMode
                                ? Colors.white
                                : themeColors.onCardMuted,
                          ),
                          child: const Text('Sign Up'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginForm() {
    final themeColors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: AppColors.errorRed, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: themeColors.onCard),
            decoration: _buildInputDecoration(
              label: 'Email',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: themeColors.onCard),
            decoration: _buildInputDecoration(
              label: 'Password',
              icon: Icons.lock_outlined,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: themeColors.onCardMuted,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Forgot password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPasswordTap,
              child: Text(
                'Forgot Password?',
                style: TextStyle(color: primary, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signInWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: primary.withValues(alpha: 0.5),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // OR divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: themeColors.onCardMuted.withValues(alpha: 0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: themeColors.onCardMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: themeColors.onCardMuted.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Google Sign-In button
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                foregroundColor: themeColors.onCard,
                side: BorderSide(color: themeColors.outlineSoft),
                backgroundColor: themeColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Image.network(
                'https://www.google.com/favicon.ico',
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.g_mobiledata,
                  size: 24,
                  color: themeColors.onCard,
                ),
              ),
              label: const Text(
                'Continue with Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          if (Platform.isIOS) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeColors.outlineSoft),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SignInWithAppleButton(
                    onPressed: _isLoading ? () {} : _signInWithApple,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      children: [
        // Error message for signup
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.errorRed.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.errorRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppColors.errorRed, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SignupForm(
          isLoading: _isLoading,
          onSignup: _signUpWithEmail,
          onSwitchToLogin: () {
            setState(() {
              _isLoginMode = true;
              _errorMessage = null;
            });
          },
          onGoogleSignIn: _signInWithGoogle,
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final themeColors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: themeColors.onCardMuted),
      prefixIcon: Icon(icon, color: themeColors.onCardMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: themeColors.cardMuted,
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
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.errorRed, width: 2),
      ),
      errorStyle: TextStyle(color: AppColors.errorRed),
    );
  }

  AuthServiceLike get _authService => widget.authService ?? AuthService();
}
