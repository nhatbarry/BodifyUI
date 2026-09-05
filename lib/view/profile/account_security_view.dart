import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../on_boarding/started_view.dart';

/// Changing the email address or the password.
///
/// Both ask for the current password, and the backend re-checks it rather than
/// trusting the access token: a phone left unlocked already carries a token,
/// and these are exactly the two moves that lock the real owner out.
class AccountSecurityView extends StatefulWidget {
  const AccountSecurityView({super.key});

  @override
  State<AccountSecurityView> createState() => _AccountSecurityViewState();
}

class _AccountSecurityViewState extends State<AccountSecurityView> {
  final _emailPassword = TextEditingController();
  final _newEmail = TextEditingController();

  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _emailPassword.dispose();
    _newEmail.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  Future<void> _submitEmail() async {
    final password = _emailPassword.text;
    final email = _newEmail.text.trim();

    if (password.isEmpty) return _show(tr('error_enter_current_password'));
    if (!_looksLikeEmail(email)) return _show(tr('error_invalid_email'));

    setState(() => _busy = true);
    try {
      await AuthService.instance
          .changeEmail(currentPassword: password, newEmail: email);
      if (!mounted) return;
      setState(() => _busy = false);
      _emailPassword.clear();
      _newEmail.clear();
      _show(tr('toast_email_changed'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _show(e is ApiException ? e.message : tr('error_save_failed'));
    }
  }

  Future<void> _submitPassword() async {
    final current = _currentPassword.text;
    final next = _newPassword.text;

    if (current.isEmpty) return _show(tr('error_enter_current_password'));
    if (next.length < 6) return _show(tr('error_password_too_short'));
    if (next != _confirmPassword.text) {
      return _show(tr('error_password_mismatch'));
    }

    setState(() => _busy = true);
    try {
      await AuthService.instance
          .changePassword(currentPassword: current, newPassword: next);
    } catch (e) {
      if (!mounted) return;
      // Every exit path clears `_busy`. The screen is wrapped in an
      // AbsorbPointer while it is true, so a path that forgets to reset it
      // does not show an error - it freezes the screen.
      setState(() => _busy = false);
      _show(e is ApiException ? e.message : tr('error_save_failed'));
      return;
    }

    if (!mounted) return;
    // The backend revoked every session, this one included, so there is
    // nothing left to come back to. Saying so and sending them to the login
    // screen beats letting the next request fail with a bare 401.
    _show(tr('toast_password_changed'));
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StartedView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text(
          tr('title_account_security'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            ValueListenableBuilder<CurrentUser?>(
              valueListenable: AuthService.instance.currentUser,
              builder: (context, user, _) => Text(
                user?.user.email ?? tr('error_not_signed_in'),
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 22),
            _section(
              colors,
              title: tr('title_change_email'),
              children: [
                _field(colors, tr('label_new_email'), _newEmail,
                    keyboard: TextInputType.emailAddress),
                _field(colors, tr('label_current_password'), _emailPassword,
                    obscure: true),
                _submit(colors, tr('btn_change_email'), _submitEmail),
              ],
            ),
            const SizedBox(height: 24),
            _section(
              colors,
              title: tr('title_change_password'),
              note: tr('msg_password_change_signs_out'),
              children: [
                _field(colors, tr('label_current_password'), _currentPassword,
                    obscure: true),
                _field(colors, tr('label_new_password'), _newPassword,
                    obscure: true),
                _field(colors, tr('label_confirm_password'), _confirmPassword,
                    obscure: true),
                _submit(colors, tr('btn_change_password'), _submitPassword),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BodifyColors colors, {
    required String title,
    required List<Widget> children,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note,
                style: TextStyle(color: colors.textSecondary, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    BodifyColors colors,
    String label,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
          isDense: true,
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _submit(BodifyColors colors, String label, VoidCallback onPressed) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _busy ? null : onPressed,
        child: _busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.primary1),
              )
            : Text(label,
                style: TextStyle(
                    color: colors.primary1, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
