import 'dart:async';

import 'package:flutter/material.dart';

import 'common/app_colors.dart';
import 'core/app_locale.dart';
import 'core/theme_controller.dart';
import 'services/auth_service.dart';
import 'view/main_tab/main_tab_view.dart';
import 'core/media_cache.dart';
import 'view/on_boarding/started_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the saved language and theme before the first frame so the app never
  // flashes the wrong one.
  await LocaleController.instance.load();
  await ThemeController.instance.load();
  // Not awaited: the first frame must not wait on a cache warm-up, it only
  // needs the database to be opening already by the time a screen asks.
  unawaited(MediaCache.warmUp());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole tree when the language or theme changes, so every
    // screen picks it up without being individually subscribed.
    return AnimatedBuilder(
      animation: Listenable.merge(
        [LocaleController.instance, ThemeController.instance],
      ),
      builder: (context, _) {
        return MaterialApp(
          title: 'Bodify',
          debugShowCheckedModeBanner: false,
          locale: LocaleController.instance.locale,
          theme: buildBodifyTheme(Brightness.light),
          darkTheme: buildBodifyTheme(Brightness.dark),
          themeMode: ThemeController.instance.mode,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Decides where the app opens: straight into the app for a user whose stored
/// session still works, otherwise onboarding.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<bool> _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _restore();
  }

  Future<bool> _restore() async {
    try {
      final user = await AuthService.instance.restoreSession();
      return user != null;
    } catch (_) {
      // Offline or backend down: fall back to onboarding rather than hanging
      // on the splash screen.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: context.colors.surface,
            body: Center(
              child: CircularProgressIndicator(color: context.colors.primary1),
            ),
          );
        }

        return snapshot.data == true ? const MainTabView() : const StartedView();
      },
    );
  }
}
