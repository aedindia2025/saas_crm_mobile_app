import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utile/app_colors.dart';
import '../intro/intro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> fadeAnimation;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeIn,
    );

    scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutBack,
      ),
    );

    animationController.forward();


    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;


      moveNextScreen();

    });
  }

  moveNextScreen() async{

    final prefs = await SharedPreferences.getInstance();
   bool isIntroDone = prefs.getBool('introDone') ?? false;


    if(!isIntroDone){

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const IntroScreen(),
      ),
    );

    }

    if(isIntroDone){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if(isIntroDone){
      Navigator.pushReplacementNamed(context, '/app_Main_Page');
      return;
    }

  }


  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -60,
              child: CircleAvatar(
                radius: 130,
                backgroundColor: Colors.white.withOpacity(0.07),
              ),
            ),
            Positioned(
              top: 100,
              right: -50,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.white.withOpacity(0.07),
              ),
            ),

            Positioned(
              bottom: 90,
              left: -80,
              child: CircleAvatar(
                radius: 120,
                backgroundColor: Colors.white.withOpacity(0.06),
              ),
            ),

            Positioned(
              bottom: 50,
              left: -70,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withOpacity(0.06),
              ),
            ),

            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                
                    FadeTransition(
                      opacity: fadeAnimation,
                      child: ScaleTransition(
                        scale: scaleAnimation,
                        child: Column(
                          children: [
                            Container(
                              width: 118,
                              height: 118,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.28),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.22),
                                    blurRadius: 34,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.business_center_rounded,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                
                            const SizedBox(height: 30),
                
                            const Text(
                              'DigitCRM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                
                            const SizedBox(height: 10),
                
                            Text(
                              'Smart Business Management',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.82),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                
                    const Spacer(),
                

                
                    const SizedBox(height: 28),
                
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}