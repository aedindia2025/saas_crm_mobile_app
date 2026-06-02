import 'package:ascent_crm/main_screens/travel_management/Travel_tada_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'EMD_BG/emd_bg.dart' hide AppColors;
import 'Leads/lead_list.dart' hide AppColors;
import 'approvals/approvals_page.dart';
import 'customers/customer_screen.dart' hide AppColors;
import 'kam_360/kam_360.dart' hide AppColors;
import 'notification/notification.dart';
import 'opportunity/opportunity_list.dart' hide AppColors;

class AppMainScreenBackup extends StatefulWidget {
  const AppMainScreenBackup({super.key});

  @override
  State<AppMainScreenBackup> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreenBackup>
    with TickerProviderStateMixin {
  String _activeDashTab = 'overview';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceAlt = Color(0xFFF0F4FB);
  static const Color _accent = Color(0xFF3060A0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textHint = Color(0xFFB0BAD0);
  static const Color _border = Color(0xFFE8EDF5);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);

  final List<_NavModule> _modules = const [
    _NavModule("Customers", Icons.groups_rounded, Color(0xFF3060A0)),
    _NavModule("Leads", Icons.person_add_alt_1_rounded, Color(0xFF10B981)),
    _NavModule("Opportunity", Icons.trending_up_rounded, Color(0xFFF59E0B)),
    _NavModule(
        "EMD/BG", Icons.account_balance_wallet_rounded, Color(0xFFEF4444)),
    _NavModule("KAM 360", Icons.manage_accounts_rounded, Color(0xFF8B5CF6)),
    _NavModule(
        "Travel Management", Icons.flight_takeoff_rounded, Color(0xFF0EA5E9)),
    _NavModule("Approvals", Icons.verified_rounded, Color(0xFFEC4899)),
  ];

  final List<_Activity> _activities = const [
    _Activity("Role 'Sales Executive' updated", "Roles", "29-05-26, 9:53 am",
        Icons.admin_panel_settings_rounded, Color(0xFF64748B)),
    _Activity("Role 'Sales Executive' updated", "Roles", "29-05-26, 9:53 am",
        Icons.admin_panel_settings_rounded, Color(0xFF64748B)),
    _Activity("Role 'GM Pre-Sales' updated", "Roles", "28-05-26, 11:10 pm",
        Icons.admin_panel_settings_rounded, Color(0xFF64748B)),
    _Activity("Role 'GM Pre-Sales' updated", "Roles", "28-05-26, 6:56 pm",
        Icons.admin_panel_settings_rounded, Color(0xFF64748B)),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _push(Widget page) => Navigator.push(context, _fadeRoute(page));

  PageRoute _fadeRoute(Widget p) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => p,
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 260),
      );

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
                  colors: [Color(0xFF112B4B), Color(0xFF397BEE)],
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
                    leading: Icon(item.icon, color: item.color),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _drawerNav(item.title);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _webCardBox({double radius = 12}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFDDE6F2)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  Widget _sectionLine(String number, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Row(
        children: [
          Text(
            number,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: const Color(0xFFDDE6F2)),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBox(String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE6F2)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Select date',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customersCharts() {
    final sectors = const [
      _SectorRow('Government', 210, Color(0xFF2563EB), .85),
      _SectorRow('Private', 186, Color(0xFF059669), .72),
      _SectorRow('Healthcare', 142, Color(0xFFF97316), .58),
      _SectorRow('Education', 96, Color(0xFF7C3AED), .42),
      _SectorRow('Others', 165, Color(0xFFEF4444), .64),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= 900;

          final statusCard = Container(
            height: 330,
            decoration: _webCardBox(radius: 14),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Status',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Active vs inactive customers',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Center(
                  child: CustomPaint(
                    size: const Size(170, 170),
                    painter: _DonutPainter(),
                  ),
                ),
                const Spacer(),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendMini('Active', Color(0xFF2563EB)),
                    SizedBox(width: 18),
                    _LegendMini('Inactive', Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          );

          final sectorCard = Container(
            height: 330,
            decoration: _webCardBox(radius: 14),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sector Distribution',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Customer count by business sector',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: Column(
                    children: sectors.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 95,
                              child: Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF334155),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: s.percent,
                                  minHeight: 9,
                                  backgroundColor: const Color(0xFFEFF3F8),
                                  valueColor:
                                  AlwaysStoppedAnimation<Color>(s.color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${s.count}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );

          return wide
              ? Row(
            children: [
              Expanded(child: statusCard),
              const SizedBox(width: 14),
              Expanded(child: sectorCard),
            ],
          )
              : Column(
            children: [
              statusCard,
              const SizedBox(height: 14),
              sectorCard,
            ],
          );
        },
      ),
    );
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
            Expanded(child: _buildWebDashboardBody()),
          ],
        ),
      ),
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
              Icons.arrow_back_ios_new_rounded,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const Spacer(),
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
                    color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {bool badge = false, VoidCallback? onTap}) {
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
            Center(child: Icon(icon, color: _textPrimary, size: 18)),
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
            child: _activeDashTab == 'customers'
                ? _buildCustomersWebTab()
                : _buildOverviewWebTab(),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    colors: [Color(0xFF123B70), Color(0xFF2F6FEA)],
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
                      color: active ? Colors.white70 : const Color(0xFF8AA0BC),
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
                        color: active ? Colors.white : const Color(0xFF1D3F66),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF263B55),
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

  Widget _buildOverviewWebTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _webHeroBanner()),
        SliverToBoxAdapter(child: _overviewKpiGrid()),
        SliverToBoxAdapter(child: _overviewFirstCharts()),
        SliverToBoxAdapter(child: _overviewSecondCharts()),
        SliverToBoxAdapter(child: _overviewThirdCharts()),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _webHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF112B4B), Color(0xFF397BEE)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good afternoon, Admin.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 7, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        'Friday, 29 May 2026',
                        style: TextStyle(
                          color: Color(0xFFB8C7DA),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _heroStat('TENDER VALUE', '₹ 2.37 Cr', const Color(0xFF60A5FA)),
            _heroDivider(),
            _heroStat('WON VALUE', '₹ 1.31 Cr', const Color(0xFF10B981)),
            _heroDivider(),
            _heroStat('WIN RATE', '39%', const Color(0xFFA5B4FC)),
            const SizedBox(width: 28),
            _heroButton(Icons.tune_rounded, 'Customize'),
            const SizedBox(width: 8),
            _heroButton(Icons.refresh_rounded, 'Refresh'),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value, Color color) {
    return SizedBox(
      width: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      height: 52,
      width: 1,
      margin: const EdgeInsets.only(right: 40),
      color: Colors.white.withOpacity(.22),
    );
  }

  Widget _heroButton(IconData icon, String label) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewKpiGrid() {
    final cards = const [
      _PipelineMetric('LEADS', '22', '₹ 2.08 Cr', Icons.track_changes_rounded,
          Color(0xFF2448C6)),
      _PipelineMetric(
          'OPPORTUNITIES', '20', '₹ 2.07 Cr', Icons.trending_up_rounded,
          Color(0xFF0D9488)),
      _PipelineMetric('TENDERS', '23', '₹ 2.37 Cr', Icons.description_rounded,
          Color(0xFF7C3AED)),
      _PipelineMetric('WORK ORDERS', '12', '₹ 5.03 Cr', Icons.grid_view_rounded,
          Color(0xFFEA580C)),
      _PipelineMetric(
          'WON', '9', '₹ 1.31 Cr', Icons.check_circle_outline_rounded,
          Color(0xFF059669)),
      _PipelineMetric('EMD / BG', '11', '₹ 13.17 L', Icons.shield_outlined,
          Color(0xFF2563EB)),
      _PipelineMetric('CUSTOMERS', '799', '₹ 2970.11 Cr', Icons.groups_rounded,
          Color(0xFFD97706)),
      _PipelineMetric(
          'APPROVALS', '0', '0 total', Icons.check_circle_outline_rounded,
          Color(0xFFEF4444)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (_, c) {
          final cross = c.maxWidth >= 1100 ? 4 : c.maxWidth >= 700 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: cross == 4 ? 3.85 : 3.2,
            ),
            itemBuilder: (_, i) => _webKpiCard(cards[i]),
          );
        },
      ),
    );
  }

  Widget _webKpiCard(_PipelineMetric m) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE6F2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [m.color.withOpacity(.06), Colors.white],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m.title,
                  style: TextStyle(
                    color: m.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  m.count,
                  style: const TextStyle(
                    color: Color(0xFF030712),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  m.amount,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: m.color,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(m.icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _overviewFirstCharts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= 900;
          return wide
              ? Row(
            children: [
              Expanded(child: _pipelineValueCard()),
              const SizedBox(width: 12),
              Expanded(child: _leadTrendCard()),
            ],
          )
              : Column(
            children: [
              _pipelineValueCard(),
              const SizedBox(height: 12),
              _leadTrendCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _pipelineValueCard() {
    return _webChartCard(
      title: 'Pipeline Value',
      subtitle: '₹ distribution by stage',
      accent: const Color(0xFF8B5CF6),
      icon: Icons.trending_up_rounded,
      height: 340,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _smallInfoBox('Total Value', '₹ 7.96 Cr')),
              const SizedBox(width: 8),
              Expanded(child: _smallInfoBox('Highest Stage', 'Tenders')),
              const SizedBox(width: 8),
              Expanded(child: _smallInfoBox('Stages', '5')),
            ],
          ),
          const SizedBox(height: 32),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: const [
                Expanded(flex: 26,
                    child: ColoredBox(
                        color: Color(0xFF2563EB), child: SizedBox(height: 26))),
                Expanded(flex: 26,
                    child: ColoredBox(
                        color: Color(0xFF7C3AED), child: SizedBox(height: 26))),
                Expanded(flex: 30,
                    child: ColoredBox(
                        color: Color(0xFFF97316), child: SizedBox(height: 26))),
                Expanded(flex: 16,
                    child: ColoredBox(
                        color: Color(0xFF059669), child: SizedBox(height: 26))),
                Expanded(flex: 2,
                    child: ColoredBox(
                        color: Color(0xFFEF4444), child: SizedBox(height: 26))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              Text('2.00 Cr',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              Text('4.00 Cr',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              Text('6.00 Cr',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              Text('8.00 Cr',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
            ],
          ),
          const Spacer(),
          Row(
            children: const [
              Expanded(child: _LegendBox(
                  'Leads', '₹ 2.08 Cr', '26%', Color(0xFF2563EB))),
              SizedBox(width: 6),
              Expanded(child: _LegendBox(
                  'Opportunities', '₹ 2.07 Cr', '26%', Color(0xFF7C3AED))),
              SizedBox(width: 6),
              Expanded(child: _LegendBox(
                  'Tenders', '₹ 2.37 Cr', '30%', Color(0xFFF97316))),
              SizedBox(width: 6),
              Expanded(child: _LegendBox(
                  'Won', '₹ 1.31 Cr', '16%', Color(0xFF059669))),
              SizedBox(width: 6),
              Expanded(child: _LegendBox(
                  'EMD / BG', '₹ 13.17 L', '2%', Color(0xFFEF4444))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leadTrendCard() {
    return _webChartCard(
      title: 'Lead Trend',
      subtitle: 'New leads per month',
      accent: const Color(0xFF2563EB),
      icon: Icons.show_chart_rounded,
      height: 340,
      child: CustomPaint(
        painter: _LineChartPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _overviewSecondCharts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= 900;

          return wide
              ? Row(
            children: [
              Expanded(child: _tenderOutcomeCard()),
              const SizedBox(width: 12),
              Expanded(child: _upcomingBidCalendarCard()),
            ],
          )
              : Column(
            children: [
              _tenderOutcomeCard(),
              const SizedBox(height: 12),
              _upcomingBidCalendarCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _overviewThirdCharts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: LayoutBuilder(
        builder: (_, c) {
          final wide = c.maxWidth >= 900;

          return wide
              ? Row(
            children: [
              Expanded(child: _leadsStatusDonutCard()),
              const SizedBox(width: 12),
              Expanded(child: _webActivityFeedCard()),
            ],
          )
              : Column(
            children: [
              _leadsStatusDonutCard(),
              const SizedBox(height: 12),
              _webActivityFeedCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _tenderOutcomeCard() {
    return _webChartCard(
      title: 'Tender Outcomes',
      subtitle: 'Win / Loss / Pending',
      accent: const Color(0xFF8B5CF6),
      icon: Icons.description_rounded,
      height: 360,
      child: CustomPaint(
        painter: _BarChartPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _upcomingBidCalendarCard() {
    return _webChartCard(
      title: 'Upcoming Bid Dates',
      subtitle: 'Tender submission calendar',
      accent: const Color(0xFF2563EB),
      icon: Icons.description_rounded,
      height: 360,
      trailing: const Text(
        'View all  ›',
        style: TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFCFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6EAF1)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF94A3B8), size: 18),
                      Expanded(
                        child: Center(
                          child: Text(
                            'May 2026',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8), size: 18),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _WeekDay('SU'),
                      _WeekDay('MO'),
                      _WeekDay('TU'),
                      _WeekDay('WE'),
                      _WeekDay('TH'),
                      _WeekDay('FR'),
                      _WeekDay('SA'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 35,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.6,
                      ),
                      itemBuilder: (_, i) {
                        final label = i < 5 ? '' : '${i - 4}';
                        final selected = label == '29';
                        final urgent = label == '31';

                        return Center(
                          child: Container(
                            width: selected || urgent ? 58 : 34,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF2563EB)
                                  : urgent
                                  ? const Color(0xFFFFF1F2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: urgent
                                  ? Border.all(color: const Color(0xFFFCA5A5))
                                  : null,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : urgent
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF334155),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 148,
            child: Column(
              children: [
                Expanded(
                  child: _calendarAlertBox(
                    title: 'URGENT',
                    value: '3',
                    sub: 'Due within 3 days',
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _calendarAlertBox(
                    title: 'UPCOMING',
                    value: '0',
                    sub: 'Next 30 days',
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarAlertBox({
    required String title,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadsStatusDonutCard() {
    return _webChartCard(
      title: 'Leads by Status',
      subtitle: 'Pipeline composition',
      accent: const Color(0xFF6366F1),
      icon: Icons.track_changes_rounded,
      height: 360,
      child: Center(
        child: CustomPaint(
          size: const Size(180, 180),
          painter: _DonutPainter(),
        ),
      ),
    );
  }

  Widget _webActivityFeedCard() {
    return _webChartCard(
      title: 'Activity Feed',
      subtitle: 'Latest system events',
      accent: const Color(0xFF0D9488),
      icon: Icons.bolt_rounded,
      height: 360,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      child: Column(
        children: _activities.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEFF3F8)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ROLE',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        e.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  e.time,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _webChartCard({
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    required double height,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE6EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersWebTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _customersHeader()),
        SliverToBoxAdapter(child: _customersFilters()),
        SliverToBoxAdapter(
          child: _sectionLine('02', 'STATUS & SECTOR DISTRIBUTION'),
        ),
        SliverToBoxAdapter(child: _customersCharts()),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _customersHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: _webCardBox(radius: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDE6F2)),
              ),
              child: const Icon(Icons.groups_rounded, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Analytics',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF020617),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '799 customers · 2970.1Cr potential',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFE6EAF1)),
              ),
              child: const Row(
                children: [
                  _HeaderMetric('TOTAL', '799', Color(0xFF020617)),
                  SizedBox(width: 54),
                  _HeaderMetric('ACTIVE', '763', Color(0xFF059669)),
                  SizedBox(width: 54),
                  _HeaderMetric('POTENTIAL', '2970.1Cr', Color(0xFF2563EB)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: Color(0xFF334155)),
                  SizedBox(width: 7),
                  Text(
                    'Arrange',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customersFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        decoration: _webCardBox(radius: 14),
        child: Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE6EAF1))),
              ),
              child: const Row(
                children: [
                  Icon(Icons.filter_alt_outlined,
                      size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text(
                    'FILTERS',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.keyboard_arrow_up_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Row(
                children: [
                  _dateBox('FROM DATE'),
                  const SizedBox(width: 14),
                  _dateBox('TO DATE'),
                  const SizedBox(width: 14),
                  Container(
                    margin: const EdgeInsets.only(top: 17),
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
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

class _Activity {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  const _Activity(this.title, this.subtitle, this.time, this.icon, this.color);
}

class _PipelineMetric {
  final String title;
  final String count;
  final String amount;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _PipelineMetric(
      this.title,
      this.count,
      this.amount,
      this.icon,
      this.color, {
        this.highlight = false,
      });
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SectorRow {
  final String name;
  final int count;
  final Color color;
  final double percent;

  const _SectorRow(this.name, this.count, this.color, this.percent);
}

class _LegendBox extends StatelessWidget {
  final String label;
  final String value;
  final String percent;
  final Color color;

  const _LegendBox(this.label, this.value, this.percent, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE6EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            percent,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  final String label;

  const _WeekDay(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _LegendMini extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendMini(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE6EAF1)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(.10)
      ..style = PaintingStyle.fill;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[
      Offset(0, size.height * .72),
      Offset(size.width * .16, size.height * .58),
      Offset(size.width * .32, size.height * .64),
      Offset(size.width * .48, size.height * .38),
      Offset(size.width * .64, size.height * .45),
      Offset(size.width * .80, size.height * .22),
      Offset(size.width, size.height * .30),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE6EAF1)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final values = [.72, .42, .58, .30, .86];
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
    ];

    final barWidth = size.width / 13;
    final gap = barWidth * 1.35;

    for (int i = 0; i < values.length; i++) {
      final x = gap + i * (barWidth + gap);
      final barHeight = size.height * values[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(7),
      );

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .14;
    final rect = Offset.zero & size;

    final data = [
      _DonutSlice(.46, const Color(0xFF2563EB)),
      _DonutSlice(.24, const Color(0xFF10B981)),
      _DonutSlice(.18, const Color(0xFFF59E0B)),
      _DonutSlice(.12, const Color(0xFFEF4444)),
    ];

    double start = -1.5708;

    for (final item in data) {
      final sweep = item.value * 6.28318;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        sweep - .08,
        false,
        paint,
      );

      start += sweep;
    }

    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * .28,
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutSlice {
  final double value;
  final Color color;

  const _DonutSlice(this.value, this.color);
}

