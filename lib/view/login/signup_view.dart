import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/round_button.dart';
import 'package:bodify/common_widget/round_textfield.dart';
import 'package:bodify/core/api_exception.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/services/auth_service.dart';
import 'package:bodify/view/login/complete_profile_view.dart';
import 'package:bodify/view/login/login_view.dart';
import 'package:flutter/material.dart';

class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isCheck = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// The backend stores one `name`; the form collects it in two fields.
  String get _fullName => [
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
      ].where((part) => part.isNotEmpty).join(' ');

  String? _validate() {
    if (_fullName.isEmpty) return tr('enterName');
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return tr('invalidEmail');
    if (_passwordController.text.length < 6) {
      return tr('passwordTooShort');
    }
    if (!isCheck) return tr('acceptTerms');
    return null;
  }

  Future<void> _register() async {
    final error = _validate();
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.instance.register(
        email: _emailController.text,
        password: _passwordController.text,
        name: _fullName,
      );

      if (!mounted) return;

      if (result.needsEmailConfirmation) {
        _showMessage(tr('confirmEmailThenLogin'));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginView()),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CompleteProfileView()),
      );
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage(tr('registerFailed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Hey there,",
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                ),
                Text(
                  "Create an Account",
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  height: media.width * 0.05,
                ),
                RoundTextField(
                  controller: _firstNameController,
                  hitText: "First Name",
                  icon: "assets/img/user_text.png",
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
                RoundTextField(
                  controller: _lastNameController,
                  hitText: "Last Name",
                  icon: "assets/img/user_text.png",
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
                RoundTextField(
                  controller: _emailController,
                  hitText: "Email",
                  icon: "assets/img/email.png",
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
                RoundTextField(
                  controller: _passwordController,
                  hitText: "Password",
                  icon: "assets/img/lock.png",
                  obscureText: _obscurePassword,
                  rigtIcon: TextButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      child: Container(
                          alignment: Alignment.center,
                          width: 20,
                          height: 20,
                          child: Image.asset(
                            "assets/img/show_password.png",
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            color: _obscurePassword
                                ? context.colors.textSecondary
                                : context.colors.primary1,
                          ))),
                ),
                Row(
                  // crossAxisAlignment: CrossAxisAlignment.,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          isCheck = !isCheck;
                        });
                      },
                      icon: Icon(
                        isCheck
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank_outlined,
                        color: context.colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child:  Text(
                          "By continuing you accept our Privacy Policy and\nTerm of Use",
                          style: TextStyle(color: context.colors.textSecondary, fontSize: 10),
                        ),

                    )
                  ],
                ),
                SizedBox(
                  height: media.width * 0.4,
                ),
                _isLoading
                    ? Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                            color: context.colors.primary1),
                      )
                    : RoundButton(title: "Register", onPressed: _register),
                SizedBox(
                  height: media.width * 0.04,
                ),
                Row(
                  // crossAxisAlignment: CrossAxisAlignment.,
                  children: [
                    Expanded(
                        child: Container(
                      height: 1,
                      color: context.colors.textSecondary.withOpacity(0.5),
                    )),
                    Text(
                      "  Or  ",
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 12),
                    ),
                    Expanded(
                        child: Container(
                      height: 1,
                      color: context.colors.textSecondary.withOpacity(0.5),
                    )),
                  ],
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          border: Border.all(
                            width: 1,
                            color: context.colors.textSecondary.withOpacity(0.4),
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Image.asset(
                          "assets/img/google.png",
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),

                     SizedBox(
                      width: media.width * 0.04,
                    ),

                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          border: Border.all(
                            width: 1,
                            color: context.colors.textSecondary.withOpacity(0.4),
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Image.asset(
                          "assets/img/facebook.png",
                          width: 20,
                          height: 20,
                        ),
                      ),
                    )
                  ],
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
                TextButton(
                  onPressed: () {
                     Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginView()));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "Login",
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      )
                    ],
                  ),
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
