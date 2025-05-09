import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/auth/auth_work.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:inzone/screen/auth/interesting_select_screen.dart';
import 'package:inzone/root_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/screen/auth/loading_screen.dart';

class SignInLoginScreen extends StatefulWidget {
  const SignInLoginScreen({super.key});

  @override
  State<SignInLoginScreen> createState() => _SignInLoginScreenState();
}

class _SignInLoginScreenState extends State<SignInLoginScreen> {
  bool _isObscured = true;
  final IconData _iconVisible = Icons.visibility;
  final IconData _iconInvisible = Icons.visibility_off;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  // Regular expressions for validation
  final RegExp _upperCase = RegExp(r'(?=.*[A-Z])');
  final RegExp _lowerCase = RegExp(r'(?=.*[a-z])');
  final RegExp _number = RegExp(r'(?=.*\d)');
  final RegExp _specialChar = RegExp(r'(?=.*[!@#\$&*~])');

  // Validation flags
  bool hasUppercase = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;
  bool hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        FocusScope.of(context).requestFocus(_emailFocusNode);
      });
    });
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _validatePassword() {
    setState(() {
      hasUppercase = _upperCase.hasMatch(_passwordController.text);
      hasLowercase = _lowerCase.hasMatch(_passwordController.text);
      hasNumber = _number.hasMatch(_passwordController.text);
      hasSpecialChar = _specialChar.hasMatch(_passwordController.text);
      hasMinLength = _passwordController.text.length >= 8;
    });
  }

  Widget _buildValidationIcon(bool isValid) {
    return Icon(
      isValid ? FeatherIcons.checkCircle : FeatherIcons.xCircle,
      color: isValid ? AppColors.primaryBlue : Colors.grey,
      size: 20,
    );
  }

  String _getUserFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your email and password.';
      case 'email-already-in-use':
        return 'This email is already associated with an account.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  // 로그인/회원가입 처리 함수
  void _handleAuthentication() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Validate form
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Please enter both email and password.";
      });
      return;
    }

    try {
      final result = await AuthWork.loginOrSignUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // result가 null이면 로그인 성공, 'signed-up'이면 회원가입 성공, 그 외는 에러
      if (result == null) {
        // 로그인 성공
        if (mounted) {
          // 홈 화면으로 이동
          context.go(Routes.home);
        }
      } else if (result == 'signed-up') {
        // 회원가입 성공
        final user = FirebaseAuth.instance.currentUser;
        final docRef =
            FirebaseFirestore.instance.collection('humanUsers').doc(user?.uid);
        await docRef.set({
          'email': _emailController.text.trim(),
          'createdAt': null, // 프로필 설정 후 업데이트될 값
        });

        if (mounted) {
          // 프로필 설정 화면으로 이동
          context.push(Routes.profileWithEmail(_emailController.text.trim()));
        }
      } else {
        // 에러 발생
        setState(() {
          _isLoading = false;
          _errorMessage = _getUserFriendlyErrorMessage(
            FirebaseAuthException(code: result),
          );
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred. Please try again.";
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    _showLoadingDialog();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _dismissLoadingDialog();
      return;
    }

    final docRef =
        FirebaseFirestore.instance.collection('humanUsers').doc(user.uid);
    var doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'createdAt': null, // 아직 프로필 설정 안 했으면 createdAt 비워둬야 구분 가능
      });
      doc = await docRef.get();
    }

    bool isProfileCompleted = doc.data()?['createdAt'] != null;

    _dismissLoadingDialog();
    if (isProfileCompleted) {
      context.go(Routes.home);
    } else {
      context.go(Routes.profileWithEmail(user.email ?? ""));
    }
  }

  void _showLoadingDialog() {
    setState(() {
      _isLoading = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const LoadingScreen();
      },
    );
  }

  void _dismissLoadingDialog() {
    setState(() {
      _isLoading = false;
    });
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // Modularized components
  Widget _buildCustomContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(6, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    bool isPassword = false,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      cursorColor: Theme.of(context).primaryColor,
      obscureText: isPassword ? _isObscured : false,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        focusColor: Theme.of(context).cardColor,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        enabledBorder: InputBorder.none,
        hintText: hintText,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.grey[400]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isObscured ? _iconVisible : _iconInvisible),
                color: Colors.grey[400],
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _buildValidationRow(bool isValid, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        _buildValidationIcon(isValid),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: isValid ? AppColors.primaryBlue : Colors.grey,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? textColor,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(4, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Center(
          child: isLoading
              ? CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(textColor ?? Colors.white),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).canvasColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).canvasColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                context.pop();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).canvasColor,
                ),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            Text(
              "Sign In or Sign Up",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(
              width: 20,
            )
          ],
        ),
        elevation: 0,
      ),
      body: ColorfulSafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              // Email field
              _buildCustomContainer(
                child: _buildTextField(
                  controller: _emailController,
                  hintText: "Enter Email",
                  focusNode: _emailFocusNode,
                  textInputAction: TextInputAction.next,
                ),
              ),

              const SizedBox(height: 20),
              // Password field and validation
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildCustomContainer(
                    child: _buildTextField(
                      controller: _passwordController,
                      hintText: "Password",
                      isPassword: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 10),
                    child: Column(
                      children: [
                        _buildValidationRow(
                          hasUppercase,
                          "At least one uppercase letter",
                        ),
                        const SizedBox(height: 5),
                        _buildValidationRow(
                          hasLowercase,
                          "At least one lowercase letter",
                        ),
                        const SizedBox(height: 5),
                        _buildValidationRow(
                          hasNumber,
                          "At least one number",
                        ),
                        const SizedBox(height: 5),
                        _buildValidationRow(
                          hasSpecialChar,
                          "At least one special character",
                        ),
                        const SizedBox(height: 5),
                        _buildValidationRow(
                          hasMinLength,
                          "Minimum 8 characters",
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ),

              const Spacer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: _buildButton(
          text: 'Continue',
          isLoading: _isLoading,
          onTap: _handleAuthentication,
        ),
      ),
    );
  }
}
