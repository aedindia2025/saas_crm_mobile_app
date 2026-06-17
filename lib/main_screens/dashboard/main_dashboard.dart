import 'dart:async';
import 'dart:convert';

import 'package:ascent_crm/main_screens/dashboard/tender.dart';
import 'package:ascent_crm/main_screens/dashboard/travel.dart';
import 'package:ascent_crm/main_screens/travel_management/Travel_tada_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../login/login_screen.dart';
import '../EMD_BG/emd_bg.dart' hide AppColors;
import '../Leads/lead_list.dart' hide AppColors;
import '../approvals/approvals_page.dart';
import '../customers/customer_screen.dart' hide AppColors;
import '../kam_360/kam_360.dart' hide AppColors;
import '../notification/notification.dart';
import '../opportunity/opportunity_list.dart' hide AppColors;

import '../quotations/quotations.dart';
import 'customer.dart';
import 'emd_bg.dart';
import 'kam_360.dart';
import 'lead.dart';
import 'login_track.dart';
import 'overview.dart';

class DashboardShell extends StatefulWidget {
  final String token;

  const DashboardShell({
    super.key,
    required this.token,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with TickerProviderStateMixin {
  String _activeDashTab = 'overview';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  Timer? _locationTimer;
  bool _isSendingLocation = false;


  static const String _locationUrl =
      "https://ascent.crm.azcentrix.com:4447/api/v1/user-locations/store";

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _surfaceAlt = Color(0xFFF0F4FB);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _red = Color(0xFFEF4444);

  final List<_NavModule> _modules = const [
    _NavModule("Customers", Icons.groups_rounded, Color(0xFF3060A0)),
    _NavModule("Leads", Icons.person_add_alt_1_rounded, Color(0xFF10B981)),
    _NavModule("Opportunity", Icons.trending_up_rounded, Color(0xFFF59E0B)),

    _NavModule("Quotations", Icons.request_quote, Color(0xFFF59E0B)),

    _NavModule("EMD/BG", Icons.account_balance_wallet_rounded, Color(0xFFEF4444)),
    _NavModule("KAM 360", Icons.manage_accounts_rounded, Color(0xFF8B5CF6)),
    _NavModule("Travel Management", Icons.flight_takeoff_rounded, Color(0xFF0EA5E9)),
    _NavModule("Approvals", Icons.verified_rounded, Color(0xFFEC4899)),
  ];

  String _tenantSlug = '';
  String auth_token = '';
  String fullName = '';

  @override
  void initState() {
    super.initState();
    _loadTenantSlug();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationTracking();
    });

  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    Future<bool?> showLocationDialog({
      required IconData icon,
      required String title,
      required String message,
      required String primaryText,
      required String secondaryText,
      required Color color,
    }) {
      return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.95),
                          color.withOpacity(0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF5F6B7A),
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5F6B7A),
                              side: const BorderSide(
                                color: Color(0xFFE3E9F2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              secondaryText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              primaryText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (!serviceEnabled) {
      if (!mounted) return false;

      final openSettings = await showLocationDialog(
        icon: Icons.location_off_rounded,
        title: "Turn on Location",
        message:
        "Location service is currently turned off. Please enable location to continue live tracking.",
        primaryText: "Turn On",
        secondaryText: "Cancel",
        color: const Color(0xFF2563EB),
      );

      if (openSettings == true) {
        await Geolocator.openLocationSettings();

        await Future.delayed(const Duration(seconds: 2));

        serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (!serviceEnabled) {
          debugPrint("Location service still disabled");
          return false;
        }
      } else {
        return false;
      }
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        debugPrint("Location permission denied");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;

      final openAppSettings = await showLocationDialog(
        icon: Icons.gpp_maybe_rounded,
        title: "Permission Required",
        message:
        "Location permission is permanently denied. Please allow location permission from app settings to continue tracking.",
        primaryText: "Open Settings",
        secondaryText: "Cancel",
        color: const Color(0xFFE67E22),
      );

      if (openAppSettings == true) {
        await Geolocator.openAppSettings();
      }

      return false;
    }

    return true;
  }

  void _startLocationTracking() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;

    // Send immediately when page opens
    await _sendCurrentLocation();

    // Send every 30 seconds
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _sendCurrentLocation(),
    );
  }

  Future<void> _sendCurrentLocation() async {
    if (_isSendingLocation) return;

    _isSendingLocation = true;

    try {
      if (_tenantSlug.isEmpty || auth_token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _tenantSlug = prefs.getString('tenant_slug') ?? '';
        auth_token = prefs.getString("auth_token") ?? "";
        setState(() {});
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.post(
        Uri.parse(_locationUrl),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer ${auth_token}",
          "X-Tenant-Slug": _tenantSlug,
        },
        body: jsonEncode({
          "latitude": position.latitude,
          "longitude": position.longitude,
        }),
      );

      debugPrint("Location status: ${response.statusCode}");
      debugPrint("Location response: ${response.body}");
    } catch (e) {
      debugPrint("Location send error: $e");
    } finally {
      _isSendingLocation = false;
    }
  }

  Future<void> _loadTenantSlug() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tenantSlug = prefs.getString('tenant_slug') ?? '';
      auth_token = prefs.getString('auth_token') ?? '';
      fullName = prefs.getString('full_name') ?? '';

    });
  }

  void _push(Widget page) {
    Navigator.push(context, _fadeRoute(page));
  }

  PageRoute _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 260),
    );
  }

  void _drawerNav(String title) {
    switch (title) {
      case "Customers":
        _push(const Customer());
        break;
      case "Leads":
        _push(const LeadList());
        break;
      case "Opportunity":
        _push(OpportunityList(tenantSlug: _tenantSlug));
        break;
      case "EMD/BG":
        _push(EmdBg(tenantSlug: _tenantSlug));
        break;
      case "KAM 360":
        _push(const Kam360Page());
        break;
      case "Travel Management":
        _push(const TravelTadaPage());
        break;

      case "Quotations":
        _push(const Quotation());
        break;

      case "Approvals":
        _push(const ApprovalsPage());
        break;
    }
  }

  Widget _buildDashboardTabBody() {
    final token = widget.token;

    switch (_activeDashTab) {
      case 'overview':
        return OverviewTab(token: token);
      case 'customers':
        return CustomersTab(token: token);
      case 'leads':
        return LeadsTab(token: token);
      case 'tenders':
        return TendersTab(token: token);
      case 'emdbg':
        return EMDBGTab(token: token);
      case 'kam360':
        return KAM360Tab(token: token);
      case 'travel':
        return TravelTab(token: token);
      case 'login_tracker':
        return LoginTrackerTab(token: token);
      default:
        return OverviewTab(token: token);
    }
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xff2563eb), Color(0xff3b82f6)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332563eb),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Exit Application",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff0f172a),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Do you want to exit from this app?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          side: const BorderSide(color: Color(0xffcbd5e1)),
                        ),
                        child: const Text(
                          "No",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xff475569),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Color(0xff2563eb),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          "Yes",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldExit = await _showExitDialog();

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        drawer: _buildDrawer(),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _buildWebDashboardBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 315,
      backgroundColor: const Color(0xfff8fafc),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff020617),
                    Color(0xff1e3a8a),
                    Color(0xff38bdf8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff2563eb).withOpacity(0.26),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -28,
                    top: -28,
                    child: Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: -42,
                    child: Container(
                      height: 95,
                      width: 95,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(.24),
                          ),
                        ),
                        child: const Icon(
                          Icons.dashboard_customize_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        fullName.isEmpty ? "Admin" : fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(.22),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: Color(0xffe0f2fe),
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Azcentrix Connect",
                              style: TextStyle(
                                color: Color(0xffe0f2fe),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                itemCount: _modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = _modules[i];

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(context);
                        _drawerNav(item.title);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xffe2e8f0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff0f172a).withOpacity(0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    item.color.withOpacity(.18),
                                    item.color.withOpacity(.07),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff0f172a),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xfff1f5f9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xff64748b),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    Navigator.pop(context);
                    await logoutUser();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff1f2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xffffcdd2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffef4444).withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Color(0xffdc2626),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Logout",
                            style: TextStyle(
                              color: Color(0xffdc2626),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xffdc2626),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _selectedTabName {
    switch (_activeDashTab) {
      case 'overview':
        return 'Overview';
      case 'customers':
        return 'Customers';
      case 'leads':
        return 'Leads';
      case 'tenders':
        return 'Tenders';
      case 'emdbg':
        return 'EMD / BG';
      case 'kam360':
        return 'KAM 360';
      case 'travel':
        return 'Travel';
      case 'login_tracker':
        return 'Login Tracker';
      default:
        return 'Dashboard';
    }
  }

  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('auth_token');
    await prefs.remove('full_name');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

 /* Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('auth_token');
    await prefs.remove('rememberMe');
    await prefs.remove('organizationName');
    await prefs.remove('userName');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }*/

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xff0f172a).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _iconBtn(
              Icons.menu_rounded,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTabName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff0f172a),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Dashboard workspace",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xff64748b),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Container(
              constraints: const BoxConstraints(maxWidth: 120),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xfff1f5f9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xffe2e8f0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 23,
                    height: 23,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xff2563eb),
                          Color(0xff38bdf8),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      fullName.isEmpty ? "Admin" : fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff0f172a),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            _iconBtn(
              Icons.notifications_rounded,
              badge: true,
              onTap: () => _push(const NotificationPage()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, {
        bool badge = false,
        VoidCallback? onTap,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xfff1f5f9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xffe2e8f0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0f172a).withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  color: const Color(0xff0f172a),
                  size: 20,
                ),
              ),
              if (badge)
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xffef4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebDashboardBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xfff8fafc),
            Color(0xffeef4ff),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          _buildWebTabsBar(),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: _buildDashboardTabBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebTabsBar() {
    final tabs = const [
      _DashTab('overview', 'Overview', Icons.dashboard_rounded),
      _DashTab('customers', 'Customers', Icons.groups_rounded),
      _DashTab('leads', 'Leads', Icons.track_changes_rounded),
      _DashTab('tenders', 'Tenders', Icons.description_rounded),
      _DashTab('emdbg', 'EMD / BG', Icons.shield_rounded),
      _DashTab('kam360', 'KAM 360', Icons.explore_rounded),
      _DashTab('travel', 'Travel', Icons.send_rounded),
      _DashTab('login_tracker', 'Login Tracker', Icons.fingerprint_rounded),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xffdbeafe),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff1e3a8a).withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final tab = tabs[i];
            final active = _activeDashTab == tab.id;

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _activeDashTab = tab.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                    colors: [
                      Color(0xff0f172a),
                      Color(0xff2563eb),
                      Color(0xff38bdf8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: active ? null : const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? Colors.white.withOpacity(0.12)
                        : const Color(0xffe2e8f0),
                  ),
                  boxShadow: active
                      ? [
                    BoxShadow(
                      color: const Color(0xff2563eb).withOpacity(0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(.17)
                            : const Color(0xffeff6ff),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        tab.icon,
                        size: 16,
                        color: active
                            ? Colors.white
                            : const Color(0xff1e3a8a),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : const Color(0xff334155),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashTab {
  final String id;
  final String label;
  final IconData icon;

  const _DashTab(this.id, this.label, this.icon);
}

class _NavModule {
  final String title;
  final IconData icon;
  final Color color;

  const _NavModule(this.title, this.icon, this.color);
}