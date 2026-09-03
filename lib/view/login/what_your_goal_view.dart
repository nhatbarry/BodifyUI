import 'package:carousel_slider/carousel_slider.dart';
import 'package:bodify/view/login/welcome_view.dart';
import 'package:flutter/material.dart';

import '../../common/app_colors.dart';
import '../../common_widget/round_button.dart';

class WhatYourGoalView extends StatefulWidget {
  const WhatYourGoalView({super.key});

  @override
  State<WhatYourGoalView> createState() => _WhatYourGoalViewState();
}

class _WhatYourGoalViewState extends State<WhatYourGoalView> {
  CarouselSliderController buttonCarouselController = CarouselSliderController();

  List goalArr = [
    {
      "image": "assets/img/goal_1.png",
      "title": "Improve Shape",
      "subtitle":
          "I have a low amount of body fat\nand need / want to build more\nmuscle"
    },
    {
      "image": "assets/img/goal_2.png",
      "title": "Lean & Tone",
      "subtitle":
          "I’m “skinny fat”. look thin but have\nno shape. I want to add learn\nmuscle in the right way"
    },
    {
      "image": "assets/img/goal_3.png",
      "title": "Lose a Fat",
      "subtitle":
          "I have over 20 lbs to lose. I want to\ndrop all this fat and gain muscle\nmass"
    },
  ];

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
          child: Stack(
        children: [
          Center(
            child: CarouselSlider(
              items: goalArr
                  .map(
                    (gObj) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: context.colors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.symmetric(
                          vertical: media.width * 0.1, horizontal: 25),
                      alignment: Alignment.center,
                      child: FittedBox(
                        child: Column(
                          children: [
                            Image.asset(
                              gObj["image"].toString(),
                              width: media.width * 0.5,
                              fit: BoxFit.fitWidth,
                            ),
                            SizedBox(
                              height: media.width * 0.1,
                            ),
                            Text(
                              gObj["title"].toString(),
                              style: TextStyle(
                                  color: context.colors.surface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                            Container(
                              width: media.width * 0.1,
                              height: 1,
                              color: context.colors.surface,
                            ),
                            SizedBox(
                              height: media.width * 0.02,
                            ),
                            Text(
                              gObj["subtitle"].toString(),
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: context.colors.surface, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
              carouselController: buttonCarouselController,
              options: CarouselOptions(
                autoPlay: false,
                enlargeCenterPage: true,
                viewportFraction: 0.7,
                aspectRatio: 0.74,
                initialPage: 0,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            width: media.width,
            child: Column(
              children: [
                SizedBox(
                  height: media.width * 0.05,
                ),
                Text(
                  "What is your goal ?",
                  style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  "It will help us to choose a best\nprogram for you",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                SizedBox(
                  height: media.width * 0.05,
                ),
                RoundButton(
                    title: "Confirm",
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const WelcomeView()));
                    }),
              ],
            ),
          )
        ],
      )),
    );
  }
}
