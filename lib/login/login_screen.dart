import 'dart:async';
import 'dart:math' as math;

import 'package:ascent_crm/utile/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_helpers/api_method.dart';
import '../api_helpers/api_urls.dart';
import '../main_screens/dashboard/main_dashboard.dart';


class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color secondaryBlue = Color(0xFF1E88E5);
  static const Color lightBlue = Color(0xFFEAF3FF);
  static const Color veryLightBlue = Color(0xFFF6FAFF);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  static const Color textDark = Color(0xFF1F2937);
  static const Color textMedium = Color(0xFF4B5563);
  static const Color textLight = Color(0xFF6B7280);

  static const Color borderColor = Color(0xFFE5EAF2);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    primaryColor: primaryBlue,
    scaffoldBackgroundColor: background,

    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: secondaryBlue,
      surface: surface,
      error: Color(0xFFD32F2F),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textDark,
    ),

    fontFamily: 'Roboto',

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textDark,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: textDark,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(
        color: primaryBlue,
        size: 19,
      ),
      actionsIconTheme: IconThemeData(
        color: primaryBlue,
        size: 19,
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
      displayMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textDark,
      ),
      displaySmall: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      headlineLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      titleLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textDark,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textMedium,
      ),
      bodyLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMedium,
      ),
      bodySmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: textLight,
      ),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textMedium,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textLight,
      ),
    ),

    iconTheme: const IconThemeData(
      color: primaryBlue,
      size: 18,
    ),

    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(
          color: borderColor,
          width: 1,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: veryLightBlue,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      hintStyle: const TextStyle(
        fontSize: 12,
        color: textLight,
      ),
      labelStyle: const TextStyle(
        fontSize: 12,
        color: textMedium,
      ),
      prefixIconColor: primaryBlue,
      suffixIconColor: primaryBlue,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: primaryBlue,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFD32F2F),
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 42),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        side: const BorderSide(
          color: primaryBlue,
          width: 1,
        ),
        minimumSize: const Size(double.infinity, 40),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 2,
      iconSize: 18,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryBlue,
      unselectedItemColor: textLight,
      selectedIconTheme: IconThemeData(size: 19),
      unselectedIconTheme: IconThemeData(size: 18),
      selectedLabelStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 4,
      height: 58,
      indicatorColor: lightBlue,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: primaryBlue,
            size: 19,
          );
        }
        return const IconThemeData(
          color: textLight,
          size: 18,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: primaryBlue,
          );
        }
        return const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textLight,
        );
      }),
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: primaryBlue,
      textColor: textDark,
      selectedColor: primaryBlue,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 0,
      ),
      minLeadingWidth: 22,
      horizontalTitleGap: 8,
      dense: true,
    ),

    dividerTheme: const DividerThemeData(
      color: borderColor,
      thickness: 1,
      space: 1,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: lightBlue,
      selectedColor: primaryBlue,
      disabledColor: const Color(0xFFE5E7EB),
      labelStyle: const TextStyle(
        fontSize: 11,
        color: textDark,
        fontWeight: FontWeight.w500,
      ),
      secondaryLabelStyle: const TextStyle(
        fontSize: 11,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      side: BorderSide.none,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      elevation: 4,
      textStyle: const TextStyle(
        fontSize: 12,
        color: textDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 12,
        color: textMedium,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: textDark,
      contentTextStyle: const TextStyle(
        fontSize: 12,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryBlue,
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue;
        }
        return Colors.white;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(
        color: borderColor,
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),

    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue;
        }
        return textLight;
      }),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryBlue;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return lightBlue;
        }
        return const Color(0xFFE5E7EB);
      }),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: primaryBlue,
      unselectedLabelColor: textLight,
      indicatorColor: primaryBlue,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}


// ═══════════════════════════════════════════════════════════════
//  DESIGN TOKENS — white based blue theme
// ═══════════════════════════════════════════════════════════════
class _T {
  // palette
  static const ink       = Color(0xFF0D47A1); // deep blue
  static const surface   = Color(0xFFFFFFFF);
  static const card      = Color(0xFFFFFFFF);

  static const purple    = Color(0xFF1565C0); // primary blue
  static const pink      = Color(0xFF1E88E5); // secondary blue
  static const violet    = Color(0xFF42A5F5); // soft blue
  static const roseLight = Color(0xFFEAF3FF); // light blue

  static const fieldBg   = Color(0xFFF6FAFF);
  static const fieldBdr  = Color(0xFFD6E6F8);
  static const textMain  = Color(0xFF102A43);
  static const textMid   = Color(0xFF486581);
  static const textHint  = Color(0xFF7B8794);

  // gradients
  static const heroGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1565C0),
      Color(0xFF1E88E5),
    ],
  );

  static const logoGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1565C0),
      Color(0xFF42A5F5),
    ],
  );

  static const titleGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D47A1),
      Color(0xFF1E88E5),
    ],
  );

  // shadows
  static List<BoxShadow> get logoShadow => [
    BoxShadow(
      color: Color(0xFF1565C0).withOpacity(0.18),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Color(0xFF1565C0).withOpacity(0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  String? companyLogoUrl;

  // ── Quick PIN setup flow tokens ─────────────────────────────
  String? quickPinChallengeId;   // from verify-account
  String? quickPinSetupToken;    // from verify-otp
  String? quickPinMaskedEmail;   // otp_delivery_target

  // ── controllers ─────────────────────────────────────────────
  final organizationController    = TextEditingController();
  final usernameController        = TextEditingController();
  final passwordController        = TextEditingController();
  final companyCodeController     = TextEditingController(); // quick pin login company code
  final quickPinController        = TextEditingController(); // quick pin login 4-digit pin
  final setupCompanyCodeController= TextEditingController();
  final setupUsernameController   = TextEditingController();
  final createPinController       = TextEditingController();
  final confirmPinController      = TextEditingController();
  final emailForgotPassController = TextEditingController();
  final quickPinEmailController   = TextEditingController(); // setup email
  final quickPinOtpController     = TextEditingController(); // setup otp

  // ── Quick PIN endpoints ─────────────────────────────────────
  static const String quickPinBaseUrl =
      "https://ascent.crm.azcentrix.com:4447/api/v1";

  static const String quickPinVerifyAccountUrl =
      "$quickPinBaseUrl/auth/quick-pin/verify-account";

  static const String quickPinVerifyOtpUrl =
      "$quickPinBaseUrl/auth/quick-pin/verify-otp";

  static const String quickPinSetUrl =
      "$quickPinBaseUrl/auth/quick-pin/set";

  static const String quickPinLoginUrl =
      "$quickPinBaseUrl/auth/quick-pin/login";

  static const String resetPassword =
      "https://ascent.crm.azcentrix.com:4447/api/v1/auth/reset-password";

  bool obscurePassword      = true;
  bool isQuickPinTab        = false;

  // setup steps
  bool isQuickPinOtpMode    = false; // OTP step
  bool isCreatePinMode      = false; // create pin step

  bool rememberMe           = false;

  late AnimationController _bgAnimCtrl;

  bool hasSavedCompanyCode = false;
  String savedCompanyCode = "";

  bool hasSavedUsername = false;
  String savedUsername = "";

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    checkRememberMe();
    loadCompanyLogo();
  }


  Future<void> loadCompanyLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final logo = prefs.getString('company_logo');
    if (mounted) {
      setState(() {
        companyLogoUrl = logo;
      });
    }
  }

  // ── unchanged logic helpers ────────────────────────────────

  Future<String> getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("device_uuid");
    if (id == null || id.isEmpty) {
      id = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString("device_uuid", id);
    }
    return id;
  }


  Future<void> saveCompanyLogoUrlToPrefs(dynamic companyLogo) async {
    if (companyLogo == null) return;

    final path = companyLogo.toString().trim();
    if (path.isEmpty) return;

    // company_logo comes as a relative path like "/uploads/.../theme_logo.png"
    // Prefix it with baseUrl. If it's already a full URL, leave it as-is.
    final String fullUrl = path.startsWith('http')
        ? path
        : "${ApiUrls.baseUrl}${path.startsWith('/') ? '' : '/'}$path";

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_logo', fullUrl);

    if (mounted) {
      setState(() {
        companyLogoUrl = fullUrl;
      });
    }
  }

  checkRememberMe() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCode = prefs.getString('company_code') ??
        prefs.getString('organizationName') ??
        prefs.getString('tenant_slug') ??
        "";

    final savedUser = prefs.getString('userName') ??
        prefs.getString('quick_pin_username') ??
        "";

    if (savedCode.trim().isNotEmpty) {
      savedCompanyCode = savedCode.trim();
      hasSavedCompanyCode = true;

      organizationController.text = savedCompanyCode;
      companyCodeController.text = savedCompanyCode;
      setupCompanyCodeController.text = savedCompanyCode;
    }

    if (savedUser.trim().isNotEmpty) {
      savedUsername = savedUser.trim();
      hasSavedUsername = true;

      usernameController.text = savedUsername;
      setupUsernameController.text = savedUsername;
    }

    rememberMe = prefs.getBool('rememberMe') ?? false;

    if (mounted) setState(() {});
  }

  /*checkRememberMe() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCode = prefs.getString('company_code') ??
        prefs.getString('organizationName') ??
        prefs.getString('tenant_slug') ??
        "";

    if (savedCode.trim().isNotEmpty) {
      savedCompanyCode = savedCode.trim();
      hasSavedCompanyCode = true;

      organizationController.text = savedCompanyCode;
      companyCodeController.text = savedCompanyCode;
      setupCompanyCodeController.text = savedCompanyCode;
    }

    rememberMe = prefs.getBool('rememberMe') ?? false;

    if (rememberMe) {
      usernameController.text = prefs.getString('userName') ?? "";
    }

    if (mounted) setState(() {});
  }*/

  Future<void> saveCompanyCodeToPrefs(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('company_code', cleanCode);
    await prefs.setString('organizationName', cleanCode);
    await prefs.setString('tenant_slug', cleanCode);

    savedCompanyCode = cleanCode;
    hasSavedCompanyCode = true;

    organizationController.text = cleanCode;
    companyCodeController.text = cleanCode;
    setupCompanyCodeController.text = cleanCode;
  }

  /// store the employee_code / username used for quick pin login
  Future<void> saveQuickPinUsernameToPrefs(String username) async {
    final clean = username.trim();
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quick_pin_username', clean);
    await prefs.setString('userName', clean);
  }

  @override
  void dispose() {
    _bgAnimCtrl.dispose();
    for (final c in [
      organizationController, usernameController, passwordController,
      companyCodeController, quickPinController, setupCompanyCodeController,
      setupUsernameController, createPinController,
      confirmPinController, emailForgotPassController,
      quickPinEmailController, quickPinOtpController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── snack ───────────────────────────────────────────────────
  void showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      backgroundColor: _T.purple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(gradient: _T.heroGrad, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.info_outline_rounded, color: AppColors.card, size: 16),
        ),
        const SizedBox(width: 10),
        Flexible(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    ));
  }

  // ── loading ─────────────────────────────────────────────────
  void showLoadingDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      barrierColor: AppColors.primaryDeep.withOpacity(0.5),
      builder: (_) => Center(
        child: Lottie.asset('assets/animation/loading.json', fit: BoxFit.cover),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  USER LOGIN LOGIC — UNCHANGED
  // ════════════════════════════════════════════════════════════

  void userLogin() async => loginWithoutPin();

  loginWithoutPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);
    var fcmToken = prefs.getString('FCM_tokel');

    await saveCompanyCodeToPrefs(organizationController.text);
    await prefs.setString('userName', usernameController.text);

    showLoadingDialog(context);

    Map<String, String> headers = {
      "X-Tenant-Slug": organizationController.text.trim(),
      "Content-Type": "application/json",
    };

    Map<String, dynamic> body = {
      "username": usernameController.text.trim(),
      "password": passwordController.text.trim(),
      "remember_me": rememberMe,
      "login_from":"mobile",
      "fcm_token": fcmToken,
    };

    try {
      final response = await ApiMethod.postRequest(
          url: ApiUrls.loginUrl, headers: headers, body: body);

      if (response["statusCode"] == 200) {
        Navigator.pop(context);

        var challengeId = response['data']['otp_challenge_id'];
        if (challengeId != null) {
          _showPinDialog(challengeId);
        } else {
          var auth = response['data'];

          if (auth['must_change_password'] == true) {
            final resetToken = auth['password_reset_token'];

            if (resetToken == null || resetToken
                .toString()
                .isEmpty) {
              showSnack("Password reset token missing");
              return;
            }

            _showMustChangePasswordDialog(resetToken.toString());
            return;
          }

          final challengeId = auth['otp_challenge_id'];

          if (challengeId != null) {
            _showPinDialog(challengeId);
          } else {
            final p = await SharedPreferences.getInstance();
            await p.setString('auth_token', auth['access_token']);
            await saveCompanyCodeToPrefs(organizationController.text);
            await p.setString('full_name', auth['full_name']);

            await p.setString('role', auth['role']);

            await saveCompanyLogoUrlToPrefs(auth['company_logo']);

            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) =>
                    DashboardShell(token: auth['access_token'])));
          }
        }
      }
      if (response["statusCode"] != 200) {
        showSnack("${response["data"]['detail']}");
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
    }
  }

  void _showMustChangePasswordDialog(String resetToken) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isSubmitting = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Change Password",
      barrierColor: AppColors.primaryDeep.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, anim, _, __) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Transform.scale(
              scale: curve.value,
              child: Opacity(
                opacity: anim.value,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.90,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDeep.withOpacity(0.22),
                            blurRadius: 55,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                _gradBox(Icons.lock_reset_rounded),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Change Password",
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: _T.textMain,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Your password must be changed before continuing.",
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: AppColors.textSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            _dlgField(
                              ctrl: newPasswordController,
                              hint: "New Password",
                              icon: Icons.lock_rounded,
                              obscure: obscureNewPassword,
                              suffix: IconButton(
                                icon: Icon(
                                  obscureNewPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _T.textHint,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    obscureNewPassword = !obscureNewPassword;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 14),

                            _dlgField(
                              ctrl: confirmPasswordController,
                              hint: "Confirm Password",
                              icon: Icons.lock_reset_rounded,
                              obscure: obscureConfirmPassword,
                              suffix: IconButton(
                                icon: Icon(
                                  obscureConfirmPassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: _T.textHint,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    obscureConfirmPassword =
                                    !obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                  final newPassword =
                                  newPasswordController.text.trim();
                                  final confirmPassword =
                                  confirmPasswordController.text.trim();

                                  if (newPassword.isEmpty ||
                                      confirmPassword.isEmpty) {
                                    showSnack(
                                      "Please enter both password fields",
                                    );
                                    return;
                                  }

                                  if (newPassword.length < 8) {
                                    showSnack(
                                      "Password must be at least 8 characters",
                                    );
                                    return;
                                  }

                                  if (newPassword != confirmPassword) {
                                    showSnack("Passwords do not match");
                                    return;
                                  }

                                  setDialogState(() {
                                    isSubmitting = true;
                                  });

                                  await _submitForcedPasswordChange(
                                    dialogCtx: dialogCtx,
                                    resetToken: resetToken,
                                    newPassword: newPassword,
                                    confirmPassword: confirmPassword,
                                  );

                                  if (ctx.mounted && Navigator.of(dialogCtx).canPop()) {
                                    setDialogState(() {
                                      isSubmitting = false;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.purple,
                                  foregroundColor: AppColors.card,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  "Submit",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            Text(
                              "You cannot continue until your password is changed.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSoft.withOpacity(0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitForcedPasswordChange({
    required BuildContext dialogCtx,
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await ApiMethod.postRequest(
        url: resetPassword,
        headers: {
          "X-Tenant-Slug": organizationController.text.trim(),
          "Content-Type": "application/json",
        },
        body: {
          "token": resetToken,
          "new_password": newPassword,
          "confirm_password": confirmPassword,
        },
      );

      if (response["statusCode"] == 200) {
        final data = response["data"];

        if (Navigator.of(dialogCtx).canPop()) {
          Navigator.of(dialogCtx).pop();
        }

        passwordController.clear();

        showSnack(
          data?["message"] ??
              "Password changed successfully. Please login again.",
        );
        return;
      } else {
        final detail = response["data"]?["detail"] ??
            response["data"]?["message"] ??
            "Password reset failed";

        showSnack(detail.toString());
      }
    } catch (e) {
      showSnack("Something went wrong. Please try again.");
    }
  }

  void _showPinDialog(String challengeId) {
    int sec = 60;
    bool canResend = false;
    bool active = true;
    final pinCtrl = TextEditingController();
    Timer? timer;

    void stopTimer() { active = false; timer?.cancel(); }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "OTP",
      barrierColor: AppColors.primaryDeep.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dCtx, anim, _, __) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return StatefulBuilder(builder: (_, setD) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (!active || !dCtx.mounted) { t.cancel(); return; }
            if (sec > 0) { setD(() => sec--); }
            else { t.cancel(); if (!active || !dCtx.mounted) return; setD(() => canResend = true); }
          });

          return Transform.scale(
            scale: c.value,
            child: Opacity(
              opacity: anim.value,
              child: Center(
                child: Material(
                  color: AppColors.card.withOpacity(0),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: AppColors.primaryDeep.withOpacity(0.2), blurRadius: 50, offset: const Offset(0, 20))],
                    ),
                    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        _gradBox(Icons.verified_user_rounded),
                        const Spacer(),
                        _xBtn(() { stopTimer(); Navigator.pop(dCtx); }),
                      ]),
                      const SizedBox(height: 22),
                      const Align(alignment: Alignment.centerLeft,
                          child: Text("OTP Verification",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _T.textMain))),
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft,
                          child: Text("Enter the 6-digit OTP sent to your registered email.",
                              style: TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.textSoft, fontWeight: FontWeight.w500))),
                      const SizedBox(height: 28),
                      Pinput(
                        controller: pinCtrl,
                        length: 6,
                        keyboardType: TextInputType.number,
                        defaultPinTheme: PinTheme(
                          width: 44, height: 52,
                          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _T.textMain),
                          decoration: BoxDecoration(
                            color: _T.fieldBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _T.fieldBdr, width: 1.5),
                          ),
                        ),
                        focusedPinTheme: PinTheme(
                          width: 44, height: 52,
                          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _T.purple),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _T.purple, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("Didn't receive OTP?",
                            style: TextStyle(color: AppColors.textSoft, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: canResend ? () async {
                            showLoadingDialog(context);
                            pinCtrl.clear();
                            await resendOTP(challengeId);
                            if (!active || !dCtx.mounted) return;
                            setD(() { sec = 20; canResend = false; });
                            timer?.cancel();
                            timer = Timer.periodic(const Duration(seconds: 1), (t) {
                              if (!active || !dCtx.mounted) { t.cancel(); return; }
                              if (sec > 0) { setD(() => sec--); }
                              else { t.cancel(); if (!active || !dCtx.mounted) return; setD(() => canResend = true); }
                            });
                          } : null,
                          style: TextButton.styleFrom(foregroundColor: _T.purple,
                              textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                          child: Text(canResend ? "Resend" : "00:${sec.toString().padLeft(2, '0')}"),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      _mainBtn(label: "Verify OTP", onPressed: () async {
                        if (pinCtrl.text.length != 6) { showSnack("Please enter 6-digit OTP"); return; }
                        stopTimer();
                        showLoadingDialog(context);
                        verifyOtpWithServer(challengeId, pinCtrl.text);
                      }),
                    ])),
                  ),
                ),
              ),
            ),
          );
        });
      },
    ).then((_) => stopTimer());
  }

  resendOTP(String challengeId) async {
    try {
      final r = await ApiMethod.postRequest(
        url: ApiUrls.resendOTP,
        headers: {"X-Tenant-Slug": organizationController.text.trim(), "Content-Type": "application/json"},
        body: {"challenge_id": challengeId},
      );
      if (r["statusCode"] == 200) Navigator.pop(context);
    } catch (_) { Navigator.pop(context); }
  }

  verifyOtpWithServer(String challengeId, otp) async {
    try {
      final r = await ApiMethod.postRequest(
        url: ApiUrls.otpVerify,
        headers: {"X-Tenant-Slug": organizationController.text.trim(), "Content-Type": "application/json"},
        body: {"challenge_id": challengeId, "otp": otp},
      );
      if (r["statusCode"] == 200) {
        var auth = r['data'];
        final p = await SharedPreferences.getInstance();
        await p.setString('auth_token', auth['access_token']);
        await saveCompanyCodeToPrefs(organizationController.text);
        await p.setString('userName', usernameController.text.trim());

        await saveCompanyLogoUrlToPrefs(auth['company_logo']);

        Navigator.pop(context);
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => DashboardShell(token: auth['access_token'])));
      }
    } catch (_) { Navigator.pop(context); Navigator.pop(context); }
  }

  // ════════════════════════════════════════════════════════════
  //  NEW QUICK PIN FLOW
  // ════════════════════════════════════════════════════════════

  /// STEP 1 — verify account & send OTP to registered email.
  /// POST /auth/quick-pin/verify-account  body {username, email}
  /// On success: store company code + username, keep challenge_id.
  Future<void> quickPinVerifyAccount() async {
    FocusScope.of(context).unfocus();

    final companyCode = setupCompanyCodeController.text.trim();
    final username = setupUsernameController.text.trim();
    final email = quickPinEmailController.text.trim();

    if (companyCode.isEmpty) {
      showSnack("Please enter company code");
      return;
    }
    if (username.isEmpty) {
      showSnack("Please enter username / employee code");
      return;
    }
    if (email.isEmpty) {
      showSnack("Please enter email ID");
      return;
    }
    if (!email.contains("@")) {
      showSnack("Please enter a valid email ID");
      return;
    }

    showLoadingDialog(context);

    try {
      final r = await ApiMethod.postRequest(
        url: quickPinVerifyAccountUrl,
        headers: {
          "X-Tenant-Slug": companyCode,
          "Content-Type": "application/json",
        },
        body: {
          "username": username,
          "email": email,
        },
      );

      Navigator.pop(context); // close loading

      final data = r["data"];

      if (r["statusCode"] == 200) {
        quickPinChallengeId = data?["challenge_id"]?.toString();
        quickPinMaskedEmail = data?["otp_delivery_target"]?.toString();

        if (quickPinChallengeId == null || quickPinChallengeId!.isEmpty) {
          showSnack("Challenge ID missing. Please try again");
          return;
        }

        // store company code + username for later quick pin login
        await saveCompanyCodeToPrefs(companyCode);
        await saveQuickPinUsernameToPrefs(
          (data?["username"]?.toString().isNotEmpty ?? false)
              ? data!["username"].toString()
              : username,
        );

        quickPinOtpController.clear();

        setState(() {
          isQuickPinOtpMode = true;
          isCreatePinMode = false;
        });

        showSnack(
          "OTP sent to ${quickPinMaskedEmail ?? 'your registered email'}",
        );
      } else {
        // show whatever the server responded with
        showSnack(
          data?["detail"]?.toString() ??
              data?["message"]?.toString() ??
              "Failed to send OTP",
        );
      }
    } catch (e) {
      Navigator.pop(context);
      showSnack("Something went wrong");
    }
  }

  /// STEP 2 — verify OTP.
  /// POST /auth/quick-pin/verify-otp  body {challenge_id, otp}
  /// On success: keep setup_token.
  Future<void> quickPinVerifyOtp() async {
    FocusScope.of(context).unfocus();

    final companyCode = setupCompanyCodeController.text.trim();
    final otp = quickPinOtpController.text.trim();

    if (companyCode.isEmpty) {
      showSnack("Company code missing");
      return;
    }
    if (otp.length != 6) {
      showSnack("Please enter 6-digit OTP");
      return;
    }
    if (quickPinChallengeId == null || quickPinChallengeId!.isEmpty) {
      showSnack("Challenge expired. Please send OTP again");
      return;
    }

    showLoadingDialog(context);

    try {
      final r = await ApiMethod.postRequest(
        url: quickPinVerifyOtpUrl,
        headers: {
          "X-Tenant-Slug": companyCode,
          "Content-Type": "application/json",
        },
        body: {
          "challenge_id": quickPinChallengeId,
          "otp": otp,
        },
      );

      Navigator.pop(context); // close loading

      final data = r["data"];

      if (r["statusCode"] == 200) {
        quickPinSetupToken = data?["setup_token"]?.toString();

        if (quickPinSetupToken == null || quickPinSetupToken!.isEmpty) {
          showSnack("Setup token missing. Please try again");
          return;
        }

        // make sure stored username matches verified account
        if ((data?["username"]?.toString().isNotEmpty ?? false)) {
          await saveQuickPinUsernameToPrefs(data!["username"].toString());
        }
        if ((data?["company_code"]?.toString().isNotEmpty ?? false)) {
          await saveCompanyCodeToPrefs(data!["company_code"].toString());
        }

        setState(() {
          isQuickPinOtpMode = false;
          isCreatePinMode = true;
        });

        showSnack("OTP verified successfully");
      } else {
        showSnack(
          data?["detail"]?.toString() ??
              data?["message"]?.toString() ??
              "Invalid OTP",
        );
      }
    } catch (e) {
      Navigator.pop(context);
      showSnack("Something went wrong");
    }
  }

  /// STEP 3 — set 4 digit PIN.
  /// POST /auth/quick-pin/set  body {setup_token, pin, confirm_pin}
  /// Close bottom sheet only when ok == true.
  void saveQuickPin() async {
    FocusScope.of(context).unfocus();

    final companyCode = setupCompanyCodeController.text.trim();
    final pin = createPinController.text.trim();
    final confirmPin = confirmPinController.text.trim();

    if (pin.length != 4 || confirmPin.length != 4) {
      showSnack("PIN must be 4 digits");
      return;
    }
    if (pin != confirmPin) {
      showSnack("PINs do not match");
      return;
    }
    if (quickPinSetupToken == null || quickPinSetupToken!.isEmpty) {
      showSnack("Setup token expired. Please send OTP again");
      return;
    }

    showLoadingDialog(context);

    try {
      final r = await ApiMethod.postRequest(
        url: quickPinSetUrl,
        headers: {
          "X-Tenant-Slug": companyCode,
          "Content-Type": "application/json",
        },
        body: {
          "setup_token": quickPinSetupToken,
          "pin": pin,
          "confirm_pin": confirmPin,
        },
      );

      Navigator.pop(context); // close loading

      final data = r["data"];

      if (r["statusCode"] == 200 && data?["ok"] == true) {
        await saveCompanyCodeToPrefs(companyCode);

        showSnack(
          data?["message"]?.toString() ?? "Quick PIN saved successfully.",
        );

        setState(() {
          isCreatePinMode = false;
          isQuickPinOtpMode = false;
          isQuickPinTab = true;

          quickPinController.clear();
          createPinController.clear();
          confirmPinController.clear();
          quickPinEmailController.clear();
          quickPinOtpController.clear();
          setupUsernameController.clear();

          quickPinSetupToken = null;
          quickPinChallengeId = null;
          quickPinMaskedEmail = null;
        });

        // close bottom sheet (only happens when ok == true)
        Navigator.pop(context);
      } else {
        showSnack(
          data?["detail"]?.toString() ??
              data?["message"]?.toString() ??
              "Failed to create Quick PIN",
        );
      }
    } catch (e) {
      Navigator.pop(context);
      showSnack("Something went wrong");
    }
  }

  /// QUICK PIN LOGIN.
  /// employee_code + X-Tenant-Slug read from SharedPreferences.
  /// POST /auth/quick-pin/login  body {employee_code, pin}
  void quickPinLogin() async {
    FocusScope.of(context).unfocus();

    final prefs = await SharedPreferences.getInstance();

    final companyCode = (prefs.getString('company_code') ??
        prefs.getString('tenant_slug') ??
        companyCodeController.text.trim())
        .trim();

    final employeeCode = (prefs.getString('quick_pin_username') ??
        prefs.getString('userName') ??
        "")
        .trim();

    if (companyCode.isEmpty) {
      showSnack("Company code missing. Please set Quick PIN first");
      return;
    }
    if (employeeCode.isEmpty) {
      showSnack("Employee code missing. Please set Quick PIN first");
      return;
    }
    if (quickPinController.text.length != 4) {
      showSnack("PIN must be exactly 4 digits");
      return;
    }

    showLoadingDialog(context);

    try {
      final r = await ApiMethod.postRequest(
        url: quickPinLoginUrl,
        headers: {
          "X-Tenant-Slug": companyCode,
          "Content-Type": "application/json",
        },
        body: {
          "employee_code": employeeCode,
          "pin": quickPinController.text.trim(),
        },
      );

      Navigator.pop(context); // close loading

      if (r["statusCode"] == 200) {
        final d = r["data"];
        final p = await SharedPreferences.getInstance();

        await p.setString("auth_token", d["access_token"]);
        await saveCompanyCodeToPrefs(companyCode);
        await p.setString('userName', employeeCode);

        if (d['full_name'] != null) {
          await p.setString('full_name', d['full_name'].toString());
        }
        if (d['role'] != null) {
          await p.setString('role', d['role'].toString());
        }
        if (d['company_logo'] != null) {
          await saveCompanyLogoUrlToPrefs(d['company_logo']);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardShell(token: d["access_token"]),
          ),
        );
      } else {
        showSnack(
          r["data"]?["detail"]?.toString() ??
              r["data"]?["message"]?.toString() ??
              "Quick PIN login failed",
        );
      }
    } catch (_) {
      Navigator.pop(context);
      showSnack("Something went wrong");
    }
  }

  void sendRequistForgotPassword() async {
    try {
      final r = await ApiMethod.postRequest(
        url: ApiUrls.resendOTP,
        headers: {"X-Tenant-Slug": organizationController.text.trim(), "Content-Type": "application/json"},
        body: {"username": "", "email": ""},
      );
      if (r["statusCode"] == 200) Navigator.pop(context);
    } catch (_) { Navigator.pop(context); }
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED SMALL WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _gradBox(IconData icon) => Container(
    width: 54,
    height: 54,
    decoration: BoxDecoration(
      gradient: _T.heroGrad,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        ..._T.logoShadow,
        BoxShadow(
          color: _T.purple.withOpacity(0.16),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Icon(icon, color: AppColors.card, size: 24),
  );

  Widget _xBtn(VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.7)),
      ),
      child: const Icon(Icons.close_rounded, color: AppColors.primaryDark, size: 18),
    ),
  );

  Widget _mainBtn({
    required String label,
    required VoidCallback onPressed,
    IconData icon = Icons.arrow_forward_rounded,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _T.purple,
          foregroundColor: AppColors.card,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _simpleField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool showDivider = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    IconData icon;
    if (hint.toLowerCase().contains("organization")) {
      icon = Icons.apartment_rounded;
    } else if (hint.toLowerCase().contains("email") ||
        hint.toLowerCase().contains("username")) {
      icon = Icons.person_rounded;
    } else if (hint.toLowerCase().contains("password")) {
      icon = Icons.lock_rounded;
    } else if (hint.toLowerCase().contains("company")) {
      icon = Icons.business_rounded;
    } else if (hint.toLowerCase().contains("pin")) {
      icon = Icons.pin_rounded;
    } else {
      icon = Icons.text_fields_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withOpacity(0.75),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _T.textMain,
        ),
        decoration: InputDecoration(
          counterText: "",
          hintText: hint,
          hintStyle: const TextStyle(
            color: _T.textHint,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _T.purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: _T.purple,
              size: 19,
            ),
          ),
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(
            minHeight: 24,
            minWidth: 48,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  InputDecoration _field({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _T.textHint, fontSize: 13.5, fontWeight: FontWeight.w600),
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _T.purple,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _T.purple.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, color: AppColors.card, size: 19),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: _T.fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _T.fieldBdr, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _T.purple, width: 2),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active
                  ? const Color(0xFF1565C0)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            color: active
                ? const Color(0xFF1F2937)
                : const Color(0xFFC7D0DD),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );

  Widget _dlgField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.fieldBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _T.fieldBdr, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _T.textMain, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _T.textHint, fontWeight: FontWeight.w600, fontSize: 13.5),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _T.ink, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.card, size: 18),
          ),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 19, horizontal: 14),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════
  Widget _headerSection() {
    return Column(
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: companyLogoUrl != null && companyLogoUrl!.trim().isNotEmpty
                ? Image.network(
              companyLogoUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                "assets/images/app_logo.png",
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.eco_rounded,
                  color: _T.purple,
                  size: 34,
                ),
              ),
            )
                : Image.asset(
              "assets/images/app_logo.png",
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.eco_rounded,
                color: _T.purple,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isQuickPinTab ? "Quick PIN Login" : "Azcentrix Connect",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: _T.purple,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  USER LOGIN FORM
  // ════════════════════════════════════════════════════════════
  Widget _userForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Column(
        children: [
          if (!hasSavedCompanyCode)
            _simpleField(
              controller: organizationController,
              hint: "Company Code",
            ),

          _simpleField(
            controller: usernameController,
            hint: "Username",
          ),
          _simpleField(
            controller: passwordController,
            hint: "Password",
            obscure: obscurePassword,
            showDivider: false,
            suffix: TextButton(
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
              child: Icon(obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded ),
            ),
          ),
        ],
      ),

      const SizedBox(height: 1),
      Row(
        children: [
          Transform.scale(
            scale: 0.90,
            child: Checkbox(
              value: rememberMe,
              activeColor: _T.purple,
              side: BorderSide(color: AppColors.border.withOpacity(0.9)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => setState(() => rememberMe = v ?? false),
            ),
          ),
          const Text(
            "Remember me",
            style: TextStyle(
              fontSize: 12.5,
              color: _T.textMid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _mainBtn(label: "Log In", onPressed: userLogin),
      const SizedBox(height: 14),
      Center(
        child: TextButton(
          onPressed: showForgotPasswordDialog,
          child: const Text(
            "Forgot Password?",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              color: _T.textMain,
            ),
          ),
        ),
      ),
    ],
  );

  // ════════════════════════════════════════════════════════════
  //  QUICK PIN LOGIN FORM
  // ════════════════════════════════════════════════════════════
  Widget _pinForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Column(
        children: [

          if (!hasSavedCompanyCode)
            _simpleField(
              controller: companyCodeController,
              hint: "Company Code",
              textCapitalization: TextCapitalization.characters,
            ),

          _simpleField(
            controller: quickPinController,
            hint: "4-Digit PIN",
            obscure: true,
            keyboardType: const TextInputType.numberWithOptions(),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            maxLength: 4,
            showDivider: false,
          ),
        ],
      ),

      const SizedBox(height: 16),
      _mainBtn(
        label: "Login with Quick PIN",
        icon: Icons.login_rounded,
        onPressed: quickPinLogin,
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();

            setState(() {
              // reset to first setup step
              isCreatePinMode = false;
              isQuickPinOtpMode = false;

              quickPinSetupToken = null;
              quickPinChallengeId = null;
              quickPinMaskedEmail = null;

              quickPinEmailController.clear();
              quickPinOtpController.clear();
              createPinController.clear();
              confirmPinController.clear();
              setupUsernameController.clear();

              if (hasSavedCompanyCode && savedCompanyCode.trim().isNotEmpty) {
                setupCompanyCodeController.text = savedCompanyCode.trim();
              }
            });

            showQuickPinSetupSheet();
          },
          child: Text(
            "Set Quick PIN",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _T.purple,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ],
  );


  // ════════════════════════════════════════════════════════════
  //  AUTH CARD
  // ════════════════════════════════════════════════════════════
  Widget _authCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Row(
              children: [
                _tab(
                  "USER LOGIN",
                  !isQuickPinTab,
                      () => setState(() => isQuickPinTab = false),
                ),
                _tab(
                  "QUICK PIN",
                  isQuickPinTab,
                      () => setState(() => isQuickPinTab = true),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(isQuickPinTab),
              child: isQuickPinTab ? _pinForm() : _userForm(),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FORGOT PASSWORD DIALOG
  // ════════════════════════════════════════════════════════════
  void showForgotPasswordDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "FP",
      barrierColor: AppColors.primaryDeep.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: c.value,
          child: Opacity(
            opacity: anim.value,
            child: Center(
              child: Material(
                color: AppColors.card.withOpacity(0),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.90,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: AppColors.border.withOpacity(0.55)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDeep.withOpacity(0.22),
                        blurRadius: 55,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [_gradBox(Icons.lock_reset_rounded), const Spacer(), _xBtn(() => Navigator.pop(ctx))]),
                    const SizedBox(height: 22),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: _T.textMain,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Enter your organization code and username to receive reset instructions.",
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (!hasSavedCompanyCode) ...[
                      _dlgField(
                        ctrl: organizationController,
                        hint: "Organization Code",
                        icon: Icons.apartment_rounded,
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (!hasSavedUsername) ...[
                      _dlgField(
                        ctrl: usernameController,
                        hint: "Username",
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 12),
                    ],


                    const SizedBox(height: 12),
                    _dlgField(ctrl: emailForgotPassController, hint: "Email Address", icon: Icons.email_rounded),
                    const SizedBox(height: 24),
                    _mainBtn(
                      label: "Send Reset Request",
                      icon: Icons.send_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        sendRequistForgotPassword();
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border.withOpacity(0.8)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.security_rounded, size: 14, color: AppColors.textSoft.withOpacity(0.70)),
                        const SizedBox(width: 6),
                        Text(
                          "Your information is securely protected",
                          style: TextStyle(
                            color: AppColors.textSoft.withOpacity(0.70),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  QUICK PIN SETUP SHEET
  // ════════════════════════════════════════════════════════════
  void showQuickPinSetupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card.withOpacity(0),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              border: Border.all(color: AppColors.border.withOpacity(0.7)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withOpacity(0.16),
                  blurRadius: 35,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: _T.heroGrad,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _T.logoShadow,
                  ),
                  child: const Icon(Icons.pin_rounded, color: AppColors.card, size: 17),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Set Quick PIN",
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _T.textMain, letterSpacing: -0.2),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Verify your account then create a 4-digit PIN",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: _T.textHint, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      "${isQuickPinOtpMode}_$isCreatePinMode",
                    ),
                    child: _quickPinSetupStep(setS),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickPinSetupStep(StateSetter setS) {
    // STEP 3 — create 4-digit PIN
    if (isCreatePinMode) {
      return Column(
        children: [
          TextField(
            controller: createPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: _field(
              hint: "Create 4-Digit PIN",
              icon: Icons.pin_rounded,
            ).copyWith(counterText: ""),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: confirmPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: _field(
              hint: "Confirm PIN",
              icon: Icons.lock_reset_rounded,
            ).copyWith(counterText: ""),
          ),
          const SizedBox(height: 24),
          _mainBtn(
            label: "Save Quick PIN",
            icon: Icons.check_circle_rounded,
            onPressed: () {
              // saveQuickPin pops the loading + the sheet itself on success
              saveQuickPin();
            },
          ),
        ],
      );
    }

    // STEP 2 — verify OTP
    if (isQuickPinOtpMode) {
      return Column(
        children: [
          Text(
            quickPinMaskedEmail == null
                ? "Enter the OTP sent to your email."
                : "Enter the OTP sent to $quickPinMaskedEmail",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: _T.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),

          Pinput(
            controller: quickPinOtpController,
            length: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            defaultPinTheme: PinTheme(
              width: 44,
              height: 52,
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _T.textMain,
              ),
              decoration: BoxDecoration(
                color: _T.fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _T.fieldBdr,
                  width: 1.5,
                ),
              ),
            ),
            focusedPinTheme: PinTheme(
              width: 44,
              height: 52,
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _T.purple,
              ),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _T.purple,
                  width: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          TextButton(
            onPressed: () {
              setState(() {
                isQuickPinOtpMode = false;
                isCreatePinMode = false;

                quickPinOtpController.clear();
                quickPinChallengeId = null;
                quickPinMaskedEmail = null;
              });
              setS(() {});
            },
            child: const Text("Change Details"),
          ),

          const SizedBox(height: 12),

          _mainBtn(
            label: "Verify OTP",
            icon: Icons.verified_rounded,
            onPressed: () async {
              await quickPinVerifyOtp();
              setS(() {});
            },
          ),
        ],
      );
    }

    // STEP 1 — verify account (company code + username + email) → Send OTP
    return Column(
      children: [
        
        if (!hasSavedCompanyCode) ...[
          TextField(
            controller: setupCompanyCodeController,
            textCapitalization: TextCapitalization.none,
            decoration: _field(
              hint: "Company Code",
              icon: Icons.business_rounded,
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (!hasSavedUsername) ...[
          TextField(
            controller: setupUsernameController,
            decoration: _field(
              hint: "Username / Employee Code",
              icon: Icons.person_rounded,
            ),
          ),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 14),
        TextField(
          controller: quickPinEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _field(
            hint: "Email ID",
            icon: Icons.email_rounded,
          ),
        ),
        const SizedBox(height: 24),

        _mainBtn(
          label: "Send OTP",
          icon: Icons.send_rounded,
          onPressed: () async {
            await quickPinVerifyAccount();
            setS(() {});
          },
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _headerSection(),
                      const SizedBox(height: 24),
                      _authCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}