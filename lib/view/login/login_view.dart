import 'package:bodify/common/app_colors.dart';
import 'package:bodify/common_widget/round_button.dart';
import 'package:bodify/common_widget/round_textfield.dart';
import 'package:bodify/core/api_exception.dart';
import 'package:bodify/core/app_strings.dart';
import 'package:bodify/services/auth_service.dart';
import 'package:bodify/view/main_tab/main_tab_view.dart';
import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isCheck = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(tr('invalidEmail'));
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showMessage(tr('enterPassword'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;
      // Replace the whole stack: logging in should not leave onboarding behind.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainTabView()),
        (route) => false,
      );
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage(tr('loginFailed'));
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
          child: Container(
            height: media.height * 0.9,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Hey there,",
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                ),
                Text(
                  "Welcome Back",
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  height: media.width * 0.05,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Forgot your password?",
                      style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 10,
                          decoration: TextDecoration.underline),
                    ),
                  ],
                ),
               const Spacer(),
                _isLoading
                    ? Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                            color: context.colors.primary1),
                      )
                    : RoundButton(title: "Login", onPressed: _login),
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
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Don’t have an account yet? ",
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "Register",
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
