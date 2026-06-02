

class ApiUrls {


  static String baseUrl = "http://103.110.236.187:3076";

  static String loginUrl = "${baseUrl}/api/v1/auth/login";

  static String otpVerify = "${baseUrl}/api/v1/auth/login/verify-otp";

  static String resendOTP = "${baseUrl}/api/v1/auth/login/resend-otp";

  static String forgotPass = "${baseUrl}/api/v1/auth/forgot-password";

  // DASHBOARD
  static  String dashboard =
      "$baseUrl/api/v1/dashboard";

  // LEADS
  static  String leads =
      "$baseUrl/api/v1/leads";

  // CUSTOMERS
  static  String customers =
      "$baseUrl/api/v1/customers";

  // OPPORTUNITIES
  static  String opportunities =
      "$baseUrl/api/v1/opportunities";

  // TENDERS
  static  String tenders =
      "$baseUrl/api/v1/tenders";

  // EMD / BG
  static  String emdBg =
      "$baseUrl/api/v1/emdbg";

  // APPROVALS
  static  String approvals =
      "$baseUrl/api/v1/approvals";

  // KAM 360
  static  String kam360 =
      "$baseUrl/api/v1/kam360";

  // TRAVEL
  static  String travel =
      "$baseUrl/api/v1/travel";

  // NOTIFICATIONS
  static  String notifications =
      "$baseUrl/api/v1/notifications";

}