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
      _showMessage(tr('error_invalid_email'));
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showMessage(tr('error_enter_password'));
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
      _showMessage(tr('error_login_failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sends a reset link, and says the same thing either way.
  ///
  /// The backend answers identically whether or not the address is
  /// registered, so that this cannot be used to discover which emails have
  /// accounts. Reporting "no such user" here would hand that back.
  Future<void> _forgotPassword() async {
    // The dialog owns its own controller. Disposing a TextEditingController
    // here, straight after `showDialog` returns, tore it out from under the
    // TextField that was still mounted for the dialog's exit animation and
    // crashed with `_dependents.isEmpty: is not true` - on Cancel as well as
    // on Send, so it was the dispose, not the request.
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(initialEmail: _emailController.text.trim()),
    );

    if (email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.requestPasswordReset(email);
    } on ApiException catch (e) {
      // Only a transport or validation failure reaches here; "unknown email"
      // never does.
      if (mounted) _showMessage(e.message);
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(tr('toast_reset_link_sent'));
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
                  tr('label_hey_there'),
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
                ),
                Text(
                  tr('title_welcome_back'),
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
                  hitText: tr('label_email'),
                  icon: "assets/img/email.png",
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(
                  height: media.width * 0.04,
                ),
                RoundTextField(
                  controller: _passwordController,
                  hitText: tr('label_password'),
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
                    TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        tr('label_forgot_password'),
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 10,
                            decoration: TextDecoration.underline),
                      ),
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
                    : RoundButton(title: tr('btn_login'), onPressed: _login),
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
                      "  ${tr('label_or')}  ",
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
                        tr('label_no_account_yet'),
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        tr('btn_register_link'),
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

/// The "reset password" prompt.
///
/// A separate widget so the text controller's lifetime is tied to the dialog
/// itself rather than to the `await showDialog` that opened it: the dialog is
/// still on screen, animating out, when that await returns.
class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(tr('title_reset_password'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('hint_reset_password'),
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: tr('label_email'),
              labelStyle:
                  TextStyle(color: colors.textSecondary, fontSize: 13),
              isDense: true,
              filled: true,
              fillColor: colors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('btn_cancel'),
              style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(tr('btn_send_reset_link'),
              style: TextStyle(color: colors.primary1)),
        ),
      ],
    );
  }
}
