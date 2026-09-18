import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../core/api_exception.dart';
import '../core/app_strings.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart';

/// The "Or ——" divider and the Google / Facebook buttons under it.
///
/// Shared by the login and signup screens, which offered exactly the same two
/// buttons and did nothing with them.
///
/// **Buttons appear only for providers the server can actually complete.**
/// Setting up Google and Facebook happens in two consoles and the Supabase
/// dashboard, not in this app, so whether either works is a server fact that
/// GET /auth/oauth/config answers. The whole block - divider included -
/// disappears when neither is set up, rather than offering a tap that can only
/// ever fail.
class SocialSignInRow extends StatefulWidget {
  /// Called once a provider sign-in has produced a session and the user has
  /// been loaded. The screen decides where to go next.
  final ValueChanged<CurrentUser> onSignedIn;

  /// Lets the parent grey out its own form while a provider sheet is open.
  final ValueChanged<bool>? onBusyChanged;

  const SocialSignInRow({
    super.key,
    required this.onSignedIn,
    this.onBusyChanged,
  });

  @override
  State<SocialSignInRow> createState() => _SocialSignInRowState();
}

class _SocialSignInRowState extends State<SocialSignInRow> {
  late final Future<SocialAuthConfig> _config =
      SocialAuthService.instance.config();

  bool _busy = false;

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _busy = value);
    widget.onBusyChanged?.call(value);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Runs one provider's flow and turns its session into a signed-in user.
  ///
  /// A null session means the user backed out of the account picker or closed
  /// the browser tab. That is not a failure and says nothing on screen.
  Future<void> _signIn(Future<AuthSession?> Function() flow) async {
    if (_busy) return;
    _setBusy(true);
    try {
      final session = await flow();
      if (session == null) return;

      final user = await AuthService.instance.adoptSession(session);
      if (!mounted) return;
      widget.onSignedIn(user);
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage(tr('error_login_failed'));
    } finally {
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;

    return FutureBuilder<SocialAuthConfig>(
      future: _config,
      builder: (context, snapshot) {
        // Nothing is drawn until the answer arrives, and nothing is drawn if
        // it says no provider is available. Both cases render as empty rather
        // than as a spinner: this sits below the real login form, and a
        // placeholder there would push the layout around for no reason.
        final config = snapshot.data;
        if (config == null || !config.any) return const SizedBox.shrink();

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Container(
                  height: 1,
                  color: context.colors.textSecondary.withValues(alpha: 0.5),
                )),
                Text(
                  "  ${tr('label_or')}  ",
                  style: TextStyle(
                      color: context.colors.textPrimary, fontSize: 12),
                ),
                Expanded(
                    child: Container(
                  height: 1,
                  color: context.colors.textSecondary.withValues(alpha: 0.5),
                )),
              ],
            ),
            SizedBox(height: media.width * 0.04),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (config.google)
                  _ProviderButton(
                    asset: "assets/img/google.png",
                    busy: _busy,
                    onTap: () =>
                        _signIn(SocialAuthService.instance.signInWithGoogle),
                  ),
                if (config.google && config.facebook)
                  SizedBox(width: media.width * 0.04),
                if (config.facebook)
                  _ProviderButton(
                    asset: "assets/img/facebook.png",
                    busy: _busy,
                    onTap: () =>
                        _signIn(SocialAuthService.instance.signInWithFacebook),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One square provider button, which becomes a spinner while any provider's
/// sign-in is running - two sheets at once is not a state worth supporting.
class _ProviderButton extends StatelessWidget {
  final String asset;
  final bool busy;
  final VoidCallback onTap;

  const _ProviderButton({
    required this.asset,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(
            width: 1,
            color: context.colors.textSecondary.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.primary1,
                ),
              )
            : Image.asset(asset, width: 20, height: 20),
      ),
    );
  }
}
