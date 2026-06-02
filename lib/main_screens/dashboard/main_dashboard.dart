import 'package:ascent_crm/main_screens/dashboard/tender.dart';
import 'package:ascent_crm/main_screens/dashboard/travel.dart';
import 'package:ascent_crm/main_screens/travel_management/Travel_tada_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login/login_screen.dart';
import '../EMD_BG/emd_bg.dart' hide AppColors;
import '../Leads/lead_list.dart' hide AppColors;
import '../approvals/approvals_page.dart';
import '../customers/customer_screen.dart' hide AppColors;
import '../kam_360/kam_360.dart' hide AppColors;
import '../notification/notification.dart';
import '../opportunity/opportunity_list.dart' hide AppColors;

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

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _surfaceAlt = Color(0xFFF0F4FB);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _red = Color(0xFFEF4444);

  final List<_NavModule> _modules = const [
    _NavModule("Customers", Icons.groups_rounded, Color(0xFF3060A0)),
    _NavModule("Leads", Icons.person_add_alt_1_rounded, Color(0xFF10B981)),
    _NavModule("Opportunity", Icons.trending_up_rounded, Color(0xFFF59E0B)),
    _NavModule("EMD/BG", Icons.account_balance_wallet_rounded, Color(0xFFEF4444)),
    _NavModule("KAM 360", Icons.manage_accounts_rounded, Color(0xFF8B5CF6)),
    _NavModule("Travel Management", Icons.flight_takeoff_rounded, Color(0xFF0EA5E9)),
    _NavModule("Approvals", Icons.verified_rounded, Color(0xFFEC4899)),
  ];

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
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
        _push(const OpportunityList());
        break;
      case "EMD/BG":
        _push(const EmdBg());
        break;
      case "KAM 360":
        _push(const Kam360Page());
        break;
      case "Travel Management":
        _push(const TravelTadaPage());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF112B4B),
                    Color(0xFF397BEE),
                  ],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ascent CRM',
                    style: TextStyle(
                      color: Color(0xFFDCEBFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = _modules[i];

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: item.color.withOpacity(.08),
                    leading: Icon(
                      item.icon,
                      color: item.color,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    onTap: () {
                      Navigator.pop(context);
                      _drawerNav(item.title);
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.red.withOpacity(0.08),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await logoutUser();
                },
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
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 62,
        color: _bg,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            _iconBtn(
              Icons.menu,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Text(
                _selectedTabName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _iconBtn(
              Icons.notifications_outlined,
              badge: true,
              onTap: () => _push(const NotificationPage()),
            ),
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF3B82F6),
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Admin',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                icon,
                color: _textPrimary,
                size: 18,
              ),
            ),
            if (badge)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDashboardBody() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          _buildWebTabsBar(),
          Expanded(
            child: _buildDashboardTabBody(),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        boxShadow: [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final tab = tabs[i];
            final active = _activeDashTab == tab.id;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _activeDashTab = tab.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                    colors: [
                      Color(0xFF123B70),
                      Color(0xFF2F6FEA),
                    ],
                  )
                      : null,
                  color: active ? null : const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFD7E4F7),
                  ),
                  boxShadow: active
                      ? const [
                    BoxShadow(
                      color: Color(0x332F6FEA),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 15,
                      color: active
                          ? Colors.white70
                          : const Color(0xFF8AA0BC),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(.15)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        tab.icon,
                        size: 15,
                        color: active
                            ? Colors.white
                            : const Color(0xFF1D3F66),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : const Color(0xFF263B55),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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