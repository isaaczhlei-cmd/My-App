import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// A reusable signup form widget with comprehensive validation.
///
/// Features:
/// - Name, email, password, and confirm password fields
/// - Real-time validation with error messages
/// - Password strength indicator
/// - Password visibility toggle
/// - Google Sign-In option
/// - Loading state support
class SignupForm extends StatefulWidget {
  /// Callback when signup is submitted with valid credentials
  final void Function(String name, String email, String password) onSignup;

  /// Callback to switch to login screen
  final VoidCallback onSwitchToLogin;

  /// Callback for Google Sign-In
  final VoidCallback onGoogleSignIn;

  /// Whether the form is in a loading state
  final bool isLoading;

  const SignupForm({
    super.key,
    required this.onSignup,
    required this.onSwitchToLogin,
    required this.onGoogleSignIn,
    this.isLoading = false,
  });

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Track field interaction for real-time validation
  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;

  // Theme colors
  static const Color _cardBackground = AppColors.cardBackground;
  static const Color _primaryGreen = AppColors.primaryGreen;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  static const Color _errorColor = AppColors.errorRed;

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time validation
    _nameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  /// Validates name field (required, min 2 characters)
  String? _validateName(String? value) {
    if (!_nameTouched) return null;
    return SignupFormValidator.validateName(value);
  }

  /// Validates email using regex pattern
  String? _validateEmail(String? value) {
    if (!_emailTouched) return null;
    return SignupFormValidator.validateEmail(value);
  }

  /// Validates password (min 8 characters)
  String? _validatePassword(String? value) {
    if (!_passwordTouched) return null;
    return SignupFormValidator.validatePassword(value);
  }

  /// Validates confirm password matches password
  String? _validateConfirmPassword(String? value) {
    if (!_confirmPasswordTouched) return null;
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Calculates password strength: weak, medium, or strong
  _PasswordStrength _getPasswordStrength(String password) {
    if (password.isEmpty) return _PasswordStrength.none;

    int score = 0;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Contains lowercase
    if (password.contains(RegExp(r'[a-z]'))) score++;

    // Contains uppercase
    if (password.contains(RegExp(r'[A-Z]'))) score++;

    // Contains numbers
    if (password.contains(RegExp(r'[0-9]'))) score++;

    // Contains special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 2) return _PasswordStrength.weak;
    if (score <= 4) return _PasswordStrength.medium;
    return _PasswordStrength.strong;
  }

  /// Checks if all fields are valid for enabling the submit button
  bool get _isFormValid {
    return SignupFormValidator.isFormValid(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
  }

  void _handleSubmit() {
    if (_isFormValid && !widget.isLoading) {
      widget.onSignup(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name field
          _buildNameField(),
          const SizedBox(height: 16),

          // Email field
          _buildEmailField(),
          const SizedBox(height: 16),

          // Password field with strength indicator
          _buildPasswordField(),
          const SizedBox(height: 8),
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 16),

          // Confirm password field
          _buildConfirmPasswordField(),
          const SizedBox(height: 24),

          // Create Account button
          _buildCreateAccountButton(),
          const SizedBox(height: 24),

          // OR divider
          _buildOrDivider(),
          const SizedBox(height: 24),

          // Google Sign-In button
          _buildGoogleSignInButton(),
          const SizedBox(height: 24),

          // Switch to login link
          _buildSwitchToLoginLink(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    final error = _validateName(_nameController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          enabled: !widget.isLoading,
          style: const TextStyle(color: _textPrimary),
          decoration: _inputDecoration(
            label: 'Name',
            icon: Icons.person_outline,
            hasError: error != null,
          ),
          textInputAction: TextInputAction.next,
          onTap: () {
            if (!_nameTouched) {
              setState(() => _nameTouched = true);
            }
          },
          onChanged: (_) {
            if (!_nameTouched) {
              setState(() => _nameTouched = true);
            }
          },
        ),
        if (error != null) _buildErrorText(error),
      ],
    );
  }

  Widget _buildEmailField() {
    final error = _validateEmail(_emailController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _emailController,
          enabled: !widget.isLoading,
          style: const TextStyle(color: _textPrimary),
          decoration: _inputDecoration(
            label: 'Email',
            icon: Icons.email_outlined,
            hasError: error != null,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          onTap: () {
            if (!_emailTouched) {
              setState(() => _emailTouched = true);
            }
          },
          onChanged: (_) {
            if (!_emailTouched) {
              setState(() => _emailTouched = true);
            }
          },
        ),
        if (error != null) _buildErrorText(error),
      ],
    );
  }

  Widget _buildPasswordField() {
    final error = _validatePassword(_passwordController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          enabled: !widget.isLoading,
          style: const TextStyle(color: _textPrimary),
          decoration: _inputDecoration(
            label: 'Password',
            icon: Icons.lock_outline,
            hasError: error != null,
            suffixIcon: IconButton(
              onPressed: widget.isLoading
                  ? null
                  : () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: _textSecondary,
              ),
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          onTap: () {
            if (!_passwordTouched) {
              setState(() => _passwordTouched = true);
            }
          },
          onChanged: (_) {
            if (!_passwordTouched) {
              setState(() => _passwordTouched = true);
            }
          },
        ),
        if (error != null) _buildErrorText(error),
      ],
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    final strength = _getPasswordStrength(password);

    if (strength == _PasswordStrength.none) {
      return const SizedBox.shrink();
    }

    Color strengthColor;
    String strengthText;
    double strengthValue;

    switch (strength) {
      case _PasswordStrength.weak:
        strengthColor = _errorColor;
        strengthText = 'Weak';
        strengthValue = 0.33;
        break;
      case _PasswordStrength.medium:
        strengthColor = AppColors.warningOrange;
        strengthText = 'Medium';
        strengthValue = 0.66;
        break;
      case _PasswordStrength.strong:
        strengthColor = _primaryGreen;
        strengthText = 'Strong';
        strengthValue = 1.0;
        break;
      case _PasswordStrength.none:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strengthValue,
                    backgroundColor: _cardBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strengthText,
                style: TextStyle(
                  color: strengthColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    final error = _validateConfirmPassword(_confirmPasswordController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _confirmPasswordController,
          enabled: !widget.isLoading,
          style: const TextStyle(color: _textPrimary),
          decoration: _inputDecoration(
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            hasError: error != null,
            suffixIcon: IconButton(
              onPressed: widget.isLoading
                  ? null
                  : () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: _textSecondary,
              ),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleSubmit(),
          onTap: () {
            if (!_confirmPasswordTouched) {
              setState(() => _confirmPasswordTouched = true);
            }
          },
          onChanged: (_) {
            if (!_confirmPasswordTouched) {
              setState(() => _confirmPasswordTouched = true);
            }
          },
        ),
        if (error != null) _buildErrorText(error),
      ],
    );
  }

  Widget _buildCreateAccountButton() {
    final isEnabled = _isFormValid && !widget.isLoading;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? _primaryGreen
              : _primaryGreen.withValues(alpha: 0.5),
          foregroundColor: _textPrimary,
          disabledBackgroundColor: _primaryGreen.withValues(alpha: 0.3),
          disabledForegroundColor: _textPrimary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: widget.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_textPrimary),
                ),
              )
            : const Text(
                'Create Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _textSecondary.withValues(alpha: 0.3),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: _textSecondary.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: widget.isLoading ? null : widget.onGoogleSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: BorderSide(
            color: widget.isLoading
                ? _textSecondary.withValues(alpha: 0.3)
                : _textSecondary.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Image.network(
          'https://www.google.com/favicon.ico',
          height: 20,
          width: 20,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.g_mobiledata, size: 24, color: _textPrimary),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildSwitchToLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        GestureDetector(
          onTap: widget.isLoading ? null : widget.onSwitchToLogin,
          child: Text(
            'Login',
            style: TextStyle(
              color: widget.isLoading
                  ? _primaryGreen.withValues(alpha: 0.5)
                  : _primaryGreen,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        error,
        style: const TextStyle(color: _errorColor, fontSize: 12),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    bool hasError = false,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary),
      prefixIcon: Icon(icon, color: _textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: hasError
            ? const BorderSide(color: _errorColor, width: 1)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? _errorColor : _primaryGreen,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

/// Enum representing password strength levels
enum _PasswordStrength { none, weak, medium, strong }

class SignupFormValidator {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static bool isFormValid({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    return validateName(name) == null &&
        validateEmail(email) == null &&
        validatePassword(password) == null &&
        confirmPassword.isNotEmpty &&
        confirmPassword == password;
  }
}
