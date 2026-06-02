
import 'package:flutter/material.dart';

import '../before_login_screen/splash_screen/splash_screen.dart';
import '../login/login_screen.dart';

class AppRoute {

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
    );

      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

     /* case '/app_Main_Page':
        return MaterialPageRoute(
          builder: (_) => const AppMainScreen(),
        );*/


      default:
    return MaterialPageRoute(
    builder: (_) => const LoginScreen(),
    );

    }
  }
}