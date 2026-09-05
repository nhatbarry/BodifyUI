import 'package:flutter/material.dart';
import 'package:bodify/core/app_strings.dart';

import '../../common/app_colors.dart';
import '../../common_widget/round_button.dart';
import '../../services/auth_service.dart';
import '../main_tab/main_tab_view.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Container(
          width: media.width,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
SizedBox(
                height: media.width * 0.1,
              ),
               Image.asset(
                "assets/img/welcome.png",
                width: media.width * 0.75,
                fit: BoxFit.fitWidth,
              ),
              SizedBox(
                height: media.width * 0.1,
              ),
              Text(
                tr('title_welcome_user').replaceFirst('{name}', AuthService.instance.currentUser.value?.displayName ?? tr('label_bodify_user')),
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                tr('subtitle_welcome'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
             const Spacer(),

               RoundButton(
                  title: tr('btn_go_to_home'),
                  onPressed: () {
                    // Clear the signup flow so Back cannot return to it.
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MainTabView()),
                        (route) => false);
                  }),
               
            ],
          ),
        ),

      ),
    );
  }
}
