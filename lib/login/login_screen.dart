import 'dart:async';

import 'package:ascent_crm/utile/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_helpers/api_method.dart';
import '../api_helpers/api_urls.dart';
import '../main_screens/dashboard/main_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final organizationController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  final companyCodeController = TextEditingController();
  final quickPinController = TextEditingController();

  final setupCompanyCodeController = TextEditingController();
  final setupUsernameController = TextEditingController();
  final setupPasswordController = TextEditingController();
  final createPinController = TextEditingController();
  final confirmPinController = TextEditingController();
  final emailForgotPassController = TextEditingController();

  String? quickPinSetupToken;
  static const String quickPinBaseUrl = "http://103.110.236.187:3076/api/v1";


  bool obscurePassword = true;
  bool obscureSetupPassword = true;
  bool isQuickPinTab = false;
  bool isCreatePinMode = false;

  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    checkRememberMe();
  }

  Future<String> getDeviceUUID() async {
    final prefs = await SharedPreferences.getInstance();

    String? deviceUuid = prefs.getString("device_uuid");

    if (deviceUuid == null || deviceUuid.isEmpty) {
      deviceUuid = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString("device_uuid", deviceUuid);
    }

    return deviceUuid;
  }

  checkRememberMe() async {
    final prefs = await SharedPreferences.getInstance();

    var isRemenberMe = prefs.getBool('rememberMe') ?? false;
    setState(() {});

    if(isRemenberMe) {
      organizationController.text = prefs.getString('organizationName') ?? "";
      usernameController.text = prefs.getString('userName') ?? "";

      setState(() {});
    }
  }

  @override
  void dispose() {
    organizationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    companyCodeController.dispose();
    quickPinController.dispose();
    setupCompanyCodeController.dispose();
    setupUsernameController.dispose();
    setupPasswordController.dispose();
    createPinController.dispose();
    confirmPinController.dispose();
    emailForgotPassController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xff9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 21),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xffF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xffE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide:  BorderSide(
          color: AppColors.primaryLight,
          width: 1.7,
        ),
      ),
    );
  }

  void userLogin() async{
    loginWithoutPin();
  }



  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(

              child: Lottie.asset(
                'assets/animation/loading.json',
                fit: BoxFit.cover,

              ),
            ),
          ],
        );
      },
    );
  }

  loginWithoutPin() async{

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', rememberMe);
    var fcmToken = prefs.getString('FCM_tokel');
    setState(() {});
    await prefs.setString('organizationName', organizationController.text);
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
      "fcm_token":fcmToken,
    };

    try {
      final response = await ApiMethod.postRequest(
        url: ApiUrls.loginUrl,
        headers: headers,
        body: body,
      );

      print("Response: $response['status']");
      print("Response data: $response");

      if (response["statusCode"] == 200) {
        Navigator.pop(context);

        var challenge_id =  response['data']['otp_challenge_id'];

        if(challenge_id != null){
          _showPinDialog(challenge_id);
        }
        else{
          var auth_token = response['data'];
          print("auth_token=== ${auth_token['access_token']}");

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', auth_token['access_token']);
          await prefs.setString('tenant_slug', organizationController.text.trim());
          await prefs.setString('full_name', auth_token['full_name']);

          Navigator.pushReplacement(context,
            MaterialPageRoute(
              builder: (context) => DashboardShell(token: auth_token['access_token']),
            ),
          );
        }

      }if (response["statusCode"] != 200) {

        ScaffoldMessenger.of(
            this.context)
            .showSnackBar(
          SnackBar(
            behavior:
            SnackBarBehavior
                .floating,
            backgroundColor:
            AppColors
                .primaryDark,
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius
                  .circular(
                  14),
            ),
            content:
            Text(
              "${response["data"]['detail']}",
            ),
          ),
        );
        Navigator.pop(context);

      }

    } catch (e) {
      Navigator.pop(context);
      print("Error==${e}");
    }

  }

  void _showPinDialog(String challengeId) {
    int secondsRemaining = 60;
    bool canResend = false;
    bool dialogActive = true;

    final pinController = TextEditingController();
    Timer? resendTimer;

    void stopTimer() {
      dialogActive = false;
      resendTimer?.cancel();
      resendTimer = null;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "OTP",
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            resendTimer ??= Timer.periodic(
              const Duration(seconds: 1),
                  (timer) {
                if (!dialogActive || !dialogContext.mounted) {
                  timer.cancel();
                  return;
                }

                if (secondsRemaining > 0) {
                  setStateDialog(() {
                    secondsRemaining--;
                  });
                } else {
                  timer.cancel();

                  if (!dialogActive || !dialogContext.mounted) return;

                  setStateDialog(() {
                    canResend = true;
                  });
                }
              },
            );

            return Transform.scale(
              scale: curved.value,
              child: Opacity(
                opacity: curved.value,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.88,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 30,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: AppColors.headerGradient,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    stopTimer();
                                    Navigator.pop(dialogContext);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "OTP Verification",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDeep,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Enter the 6-digit OTP sent to your registered email.",
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.5,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            Pinput(
                              controller: pinController,
                              length: 6,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Didn't receive OTP?",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: canResend
                                      ? () async {
                                    showLoadingDialog(context);
                                    pinController.clear();

                                    await resendOTP(challengeId);

                                    if (!dialogActive || !dialogContext.mounted) return;

                                    setStateDialog(() {
                                      secondsRemaining = 20;
                                      canResend = false;
                                    });

                                    resendTimer?.cancel();
                                    resendTimer = Timer.periodic(
                                      const Duration(seconds: 1),
                                          (timer) {
                                        if (!dialogActive || !dialogContext.mounted) {
                                          timer.cancel();
                                          return;
                                        }

                                        if (secondsRemaining > 0) {
                                          setStateDialog(() {
                                            secondsRemaining--;
                                          });
                                        } else {
                                          timer.cancel();

                                          if (!dialogActive || !dialogContext.mounted) return;

                                          setStateDialog(() {
                                            canResend = true;
                                          });
                                        }
                                      },
                                    );
                                  }
                                      : null,
                                  child: Text(
                                    canResend
                                        ? "Resend"
                                        : "00:${secondsRemaining.toString().padLeft(2, '0')}",
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () async {
                                  if (pinController.text.length != 6) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppColors.primaryDark,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        content: const Text("Please enter 6 digit PIN"),
                                      ),
                                    );
                                    return;
                                  }

                                  stopTimer();
                                  showLoadingDialog(context);

                                  verifyOtpWithServer(
                                    challengeId,
                                    pinController.text,
                                  );
                                },
                                child: const Text(
                                  "Verify OTP",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
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
    ).then((_) {
      stopTimer();
    });
  }

  resendOTP(String challenge_id) async {

    Map<String, String> headers = {
      "X-Tenant-Slug":
      organizationController.text
          .trim(),
      "Content-Type":
      "application/json",
    };

    Map<String, dynamic> body = {
      "challenge_id": challenge_id,

    };

    try {

      final response =
      await ApiMethod.postRequest(
        url: ApiUrls.resendOTP,
        headers: headers,
        body: body,
      );



      if (response["statusCode"] == 200) {
        Navigator.pop(context);

      }

    } catch (e) {
      Navigator.pop(context);
      print(e);
    }

  }

  verifyOtpWithServer(String challenge_id,otp) async {

    Map<String, String> headers = {
      "X-Tenant-Slug":
      organizationController.text
          .trim(),
      "Content-Type":
      "application/json",
    };

    Map<String, dynamic> body = {
      "challenge_id": challenge_id,
      "otp": otp,
    };

    try {

      final response =
      await ApiMethod.postRequest(
        url: ApiUrls.otpVerify,
        headers: headers,
        body: body,
      );

      print("response===ajih= ${response}");


      if (response["statusCode"] == 200) {
        var auth_token = response['data'];
        print("auth_token=== ${auth_token['access_token']}");

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', auth_token['access_token']);
        await prefs.setString('tenant_slug', organizationController.text.trim());
        await prefs.setString('organizationName', organizationController.text.trim());
        await prefs.setString('userName', usernameController.text.trim());

        Navigator.pop(context);

        Navigator.pushReplacement(context,
          MaterialPageRoute(
            builder: (context) => DashboardShell(token: auth_token['access_token']),
          ),
        );
      }

    } catch (e) {
      Navigator.pop(context);
      Navigator.pop(context);
      print(e);
    }

  }

  void quickPinLogin() async {
    FocusScope.of(context).unfocus();

    if (companyCodeController.text.trim().isEmpty) {
      showSnack("Please enter company code");
      return;
    }

    if (quickPinController.text.length != 4) {
      showSnack("PIN must be exactly 4 digits");
      return;
    }

    showLoadingDialog(context);

    final deviceUuid = await getDeviceUUID();

    Map<String, String> headers = {
      "X-Tenant-Slug": companyCodeController.text.trim(),
      "X-Device-UUID": deviceUuid,
      "Content-Type": "application/json",
    };

    Map<String, dynamic> body = {
      "pin": quickPinController.text.trim(),
      "remember_me": rememberMe,
    };

    try {
      final response = await ApiMethod.postRequest(
        url: "$quickPinBaseUrl/auth/quick-pin/login",
        headers: headers,
        body: body,
      );

      Navigator.pop(context);

      if (response["statusCode"] == 200) {
        final data = response["data"];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("auth_token", data["access_token"]);
        await prefs.setString("tenant_slug", companyCodeController.text.trim());
        await prefs.setString("organizationName", companyCodeController.text.trim());

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardShell(token: data["access_token"]),
          ),
        );
      } else {
        showSnack(response["data"]?["detail"] ?? "Quick PIN login failed");
      }
    } catch (e) {
      Navigator.pop(context);
      showSnack("Something went wrong");
      print(e);
    }
  }

  Future<void> verifyUserAndAllowPinSetup() async {
    if (setupCompanyCodeController.text.trim().isEmpty ||
        setupUsernameController.text.trim().isEmpty ||
        setupPasswordController.text.trim().isEmpty) {
      showSnack("Please fill all fields");
      return;
    }

    showLoadingDialog(context);

    final deviceUuid = await getDeviceUUID();

    Map<String, String> headers = {
      "X-Tenant-Slug": setupCompanyCodeController.text.trim(),
      "X-Device-UUID": deviceUuid,
      "Content-Type": "application/json",
    };

    Map<String, dynamic> body = {
      "username": setupUsernameController.text.trim(),
      "password": setupPasswordController.text.trim(),
    };

    try {
      final response = await ApiMethod.postRequest(
        url: "$quickPinBaseUrl/auth/quick-pin/verify-account",
        headers: headers,
        body: body,
      );

      Navigator.pop(context);

      if (response["statusCode"] == 200) {
        quickPinSetupToken = response["data"]["setup_token"];

        setState(() {
          isCreatePinMode = true;
        });
      } else {
        showSnack(response["data"]?["detail"] ?? "Account verification failed");
      }
    } catch (e) {
      Navigator.pop(context);
      showSnack("Something went wrong");
      print(e);
    }
  }

  void saveQuickPin() async {
    if (createPinController.text.length != 4 ||
        confirmPinController.text.length != 4) {
      showSnack("PIN must be exactly 4 digits");
      return;
    }

    if (createPinController.text != confirmPinController.text) {
      showSnack("PIN and confirm PIN do not match");
      return;
    }

    if (quickPinSetupToken == null) {
      showSnack("Setup token expired. Please verify again");
      return;
    }

    showLoadingDialog(context);

    final deviceUuid = await getDeviceUUID();

    Map<String, String> headers = {
      "X-Tenant-Slug": setupCompanyCodeController.text.trim(),
      "X-Device-UUID": deviceUuid,
      "Content-Type": "application/json",
    };

    Map<String, dynamic> body = {
      "setup_token": quickPinSetupToken,
      "pin": createPinController.text.trim(),
      "confirm_pin": confirmPinController.text.trim(),
    };

    try {
      final response = await ApiMethod.postRequest(
        url: "$quickPinBaseUrl/auth/quick-pin/set",
        headers: headers,
        body: body,
      );

      Navigator.pop(context);

      if (response["statusCode"] == 200) {
        showSnack("Quick PIN created successfully");

        setState(() {
          isCreatePinMode = false;
          isQuickPinTab = true;
          companyCodeController.text = setupCompanyCodeController.text.trim();
          quickPinController.clear();
          createPinController.clear();
          confirmPinController.clear();
          quickPinSetupToken = null;
        });

        Navigator.pop(context);
      } else {
        showSnack(response["data"]?["detail"] ?? "Failed to create Quick PIN");
      }
    } catch (e) {
      Navigator.pop(context);
      showSnack("Something went wrong");
      print(e);
    }
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(message),
      ),
    );
  }

  void showForgotPasswordDialog() {

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Forgot Password",
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {

        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return Transform.scale(
          scale: curved.value,
          child: Opacity(
            opacity: curved.value,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.90,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 35,
                        spreadRadius: 3,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      /// TOP SECTION
                      Row(
                        children: [

                          /// ICON
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: AppColors.headerGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLight
                                      .withOpacity(0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),

                          const Spacer(),

                          /// CLOSE BUTTON
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      /// TITLE
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDeep,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      /// SUBTITLE
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Enter your organization code and username to receive password reset instructions.",
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.6,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      ///company code
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: organizationController,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDeep,
                          ),
                          decoration: InputDecoration(
                            hintText: "User Name",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: AppColors.headerGradient,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),

                      /// USERNAME FIELD
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: usernameController,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDeep,
                          ),
                          decoration: InputDecoration(
                            hintText: "User Name",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: AppColors.headerGradient,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),

                      /// EMAIL
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: TextField(
                          controller: emailForgotPassController,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDeep,
                          ),
                          decoration: InputDecoration(
                            hintText: "User Name",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: AppColors.headerGradient,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),




                      const SizedBox(height: 32),

                      /// SEND BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: AppColors.headerGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLight
                                    .withOpacity(0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {

                              Navigator.pop(context);


                              sendRequistForgotPassword();
                            },
                            child: const Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [

                                Text(
                                  "Send Reset Request",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),

                                SizedBox(width: 10),

                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// FOOTER
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [

                          Icon(
                            Icons.security_rounded,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),

                          const SizedBox(width: 6),

                          Text(
                            "Your information is securely protected",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  sendRequistForgotPassword() async {

    Map<String, String> headers = {
      "X-Tenant-Slug":
      organizationController.text
          .trim(),
      "Content-Type":
      "application/json",
    };

    Map<String, dynamic> body = {
      "username": "",
      "email" : "",

    };

    try {

      final response =
      await ApiMethod.postRequest(
        url: ApiUrls.resendOTP,
        headers: headers,
        body: body,
      );

      if (response["statusCode"] == 200) {
        Navigator.pop(context);

      }

    } catch (e) {
      Navigator.pop(context);
      print(e);
    }

  }

  Widget tabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primarySlate,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget userLoginForm() {
    return Column(
      children: [
        TextField(
          controller: organizationController,
          decoration: inputDecoration(
            hint: "Organization",
            icon: Icons.apartment_rounded,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: usernameController,
          decoration: inputDecoration(
            hint: "UserName",
            icon: Icons.person_rounded,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: inputDecoration(
            hint: "Password",
            icon: Icons.lock_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppColors.primarySlate,
              ),
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  activeColor: AppColors.primaryLight,
                  onChanged: (value) {
                    setState(() {
                      rememberMe = value ?? false;
                    });
                  },
                ),
                const Text(
                  "Remember Me",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primarySlate,
                  ),
                ),
              ],
            ),

            SizedBox(width: 10,),

            TextButton(
              onPressed: showForgotPasswordDialog,
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        mainButton(
          title: "Sign In",
          icon: Icons.arrow_forward_rounded,
          onPressed: userLogin,
        ),
      ],
    );
  }

  Widget quickPinLoginForm() {
    return Column(
      children: [
        TextField(
          controller: companyCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: inputDecoration(
            hint: "Company Code",
            icon: Icons.business_rounded,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: quickPinController,
          obscureText: true,
          keyboardType: TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          textInputAction: TextInputAction.done,
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],

          decoration: inputDecoration(
            hint: "Enter 4 Digit PIN",
            icon: Icons.pin_rounded,
          ).copyWith(counterText: ""),
        ),
        const SizedBox(height: 22),
        mainButton(
          title: "Login with Quick PIN",
          icon: Icons.login_rounded,
          onPressed: quickPinLogin,
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () {
            setState(() {
              FocusScope.of(context).unfocus();
              isCreatePinMode = false;
            });
            showQuickPinSetupSheet();
          },
          child: const Text(
            "Set Quick PIN",
            style: TextStyle(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget mainButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 21),
          ],
        ),
      ),
    );
  }

  void showQuickPinSetupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xffD1D5DB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        "Set Quick PIN",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Verify your account and create a 4 digit PIN",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xff9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 26),

                      if (!isCreatePinMode) ...[
                        TextField(
                          controller: setupCompanyCodeController,
                          decoration: inputDecoration(
                            hint: "Company Code",
                            icon: Icons.business_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: setupUsernameController,
                          decoration: inputDecoration(
                            hint: "User Name",
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: setupPasswordController,
                          obscureText: obscureSetupPassword,
                          decoration: inputDecoration(
                            hint: "Password",
                            icon: Icons.lock_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureSetupPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: AppColors.primarySlate,
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  obscureSetupPassword = !obscureSetupPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        mainButton(
                          title: "Verify Account",
                          icon: Icons.verified_user_rounded,
                          onPressed: () async {
                            await verifyUserAndAllowPinSetup();
                            setSheetState(() {});
                          },
                        ),
                      ] else ...[
                        TextField(
                          controller: createPinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: inputDecoration(
                            hint: "Create 4 Digit PIN",
                            icon: Icons.pin_rounded,
                          ).copyWith(counterText: ""),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: confirmPinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: inputDecoration(
                            hint: "Confirm 4 Digit PIN",
                            icon: Icons.lock_reset_rounded,
                          ).copyWith(counterText: ""),
                        ),
                        const SizedBox(height: 24),
                        mainButton(
                          title: "Save Quick PIN",
                          icon: Icons.check_circle_rounded,
                          onPressed: () {
                            saveQuickPin();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topSectionHeight = size.height * 0.28; // responsive header

    return Scaffold(
      backgroundColor: const Color(0xffEEF1F5),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // HEADER BACKGROUND (responsive)
            Container(
              height: topSectionHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(42),
                  bottomRight: Radius.circular(42),
                ),
              ),
            ),

            Positioned(
              top: -70,
              right: -55,
              child: CircleAvatar(
                radius: 120,
                backgroundColor: Colors.white.withOpacity(0.07),
              ),
            ),

            Positioned(
              top: 135,
              left: -65,
              child: CircleAvatar(
                radius: 95,
                backgroundColor: Colors.white.withOpacity(0.06),
              ),
            ),

            // MAIN CONTENT (flexible + scroll safe)
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(height: size.height * 0.05),

                          // LOGO
                          Container(
                            height: 92,
                            width: 92,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.16),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.business_center_rounded,
                                color: AppColors.primaryLight,
                                size: 46,
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          const Text(
                            "DigitCRM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "Smart Business Management",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),

                          SizedBox(height: size.height * 0.03),

                          // LOGIN CARD
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryDark.withOpacity(0.12),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffEEF1F5),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      tabButton(
                                        title: "USER LOGIN",
                                        selected: !isQuickPinTab,
                                        onTap: () {
                                          setState(() {
                                            isQuickPinTab = false;
                                          });
                                        },
                                      ),
                                      tabButton(
                                        title: "QUICK PIN",
                                        selected: isQuickPinTab,
                                        onTap: () {
                                          setState(() {
                                            isQuickPinTab = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Text(
                                  isQuickPinTab
                                      ? "Quick PIN Login"
                                      : "Welcome Back",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryDeep,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  isQuickPinTab
                                      ? "Login faster using company code and PIN"
                                      : "Login to access your CRM dashboard",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff9CA3AF),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: isQuickPinTab
                                      ? quickPinLoginForm()
                                      : userLoginForm(),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          Text(
                            "Crafted by AZCENTRIX",
                            style: TextStyle(
                              color: AppColors.primarySlate.withOpacity(0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
