import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginTrackerTab extends StatefulWidget {
  final String token;

  const LoginTrackerTab({
    super.key,
    required this.token,
  });

  @override
  State<LoginTrackerTab> createState() => _LoginTrackerTabState();
}

class _LoginTrackerTabState extends State<LoginTrackerTab> {
  static const baseUrl = "http://103.110.236.187:3076/api/v1";

  bool loading = true;
  Map<String, dynamic>? data;
  String? tenantSlug;

  String viewMode = "dashboard";
  String reportTab = "logged_in";
  String activeChart = "hourly";

  String? dateFrom;
  String? dateTo;
  String? assignedTo;
  String? group;

  String searchQuery = "";
  final Set<int> selectedNotLoggedIn = {};
  String? mailSuccess;

  bool get isMobile => MediaQuery.of(context).size.width < 700;
  bool get isTablet => MediaQuery.of(context).size.width < 1100;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  num n(dynamic v) => v == null ? 0 : num.tryParse(v.toString()) ?? 0;

  String fmtN(dynamic v) {
    return NumberFormat.decimalPattern('en_IN').format(n(v));
  }

  String fmtDuration(dynamic minutes) {
    final m = n(minutes);

    if (m <= 0) return "—";
    if (m < 60) return "${m.round()}m";

    final h = m ~/ 60;
    final rem = (m % 60).round();

    return rem > 0 ? "${h}h ${rem}m" : "${h}h";
  }

  String fmtTime(dynamic iso) {
    final d = DateTime.tryParse("${iso ?? ""}");
    return d == null ? "—" : DateFormat("hh:mm a").format(d);
  }

  String fmtDateTime(dynamic iso) {
    final d = DateTime.tryParse("${iso ?? ""}");
    return d == null ? "—" : DateFormat("dd MMM, hh:mm a").format(d);
  }

  Map<String, String> get queryParams {
    final p = <String, String>{};

    if (dateFrom?.isNotEmpty == true) p["date_from"] = dateFrom!;
    if (dateTo?.isNotEmpty == true) p["date_to"] = dateTo!;
    if (assignedTo?.isNotEmpty == true) p["assigned_to"] = assignedTo!;
    if (group?.isNotEmpty == true) p["group"] = group!;

    return p;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    if (tenantSlug == null) {
      final prefs = await SharedPreferences.getInstance();
      tenantSlug = prefs.getString('tenant_slug') ?? '';
    }

    final uri = Uri.parse("$baseUrl/dashboard/tab/login_tracker")
        .replace(queryParameters: queryParams);

    final res = await http.get(
      uri,
      headers: {
        'X-Tenant-Slug': tenantSlug!,
        "Authorization": "Bearer ${widget.token}",
        "Accept": "application/json",
      },
    );

    data = res.statusCode == 200 ? jsonDecode(res.body) : null;

    setState(() => loading = false);
  }

  Future<void> sendReminder(List<int> userIds) async {
    if (tenantSlug == null) {
      final prefs = await SharedPreferences.getInstance();
      tenantSlug = prefs.getString('tenant_slug') ?? '';
    }

    final res = await http.post(
      Uri.parse("$baseUrl/dashboard/send-login-reminder"),
      headers: {
        'X-Tenant-Slug': tenantSlug!,
        "Authorization": "Bearer ${widget.token}",
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "user_ids": userIds,
        "subject": "Action Required: Please Log In to the CRM System Today",
        "message":
        "Dear {name},\n\nWe noticed that you have not logged in to the CRM system today. Please log in and update your activities at the earliest.\n\nRegards,\nManagement",
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      setState(() {
        selectedNotLoggedIn.clear();
        mailSuccess = "Reminder sent to ${userIds.length} user(s)";
      });

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => mailSuccess = null);
      });
    }
  }

  Map<String, dynamic> get summary {
    return Map<String, dynamic>.from(data?["summary"] ?? {});
  }

  Map<String, dynamic> get charts {
    return Map<String, dynamic>.from(data?["charts"] ?? {});
  }

  Map<String, dynamic> get topLists {
    return Map<String, dynamic>.from(data?["top_lists"] ?? {});
  }

  Map<String, dynamic> get filters {
    return Map<String, dynamic>.from(data?["filters"] ?? {});
  }

  List<Map<String, dynamic>> listOf(String key) {
    final list = data?[key];

    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  List<Map<String, dynamic>> get dailyLog => listOf("daily_log");
  List<Map<String, dynamic>> get activeSessions => listOf("active_sessions");
  List<Map<String, dynamic>> get sessionTable => listOf("session_table");
  List<Map<String, dynamic>> get alerts => listOf("alerts");
  List<Map<String, dynamic>> get notLoggedIn => listOf("not_logged_in");

  List<Map<String, dynamic>> get loggedInToday {
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
    final seen = <dynamic>{};

    return dailyLog.where((r) {
      final d = "${r["date"] ?? ""}";
      final uid = r["user_id"];

      if (!d.startsWith(today)) return false;
      if (seen.contains(uid)) return false;

      seen.add(uid);
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredLoggedIn {
    final q = searchQuery.toLowerCase().trim();

    if (q.isEmpty) return loggedInToday;

    return loggedInToday.where((r) {
      return "${r["user_name"] ?? ""}".toLowerCase().contains(q) ||
          "${r["username"] ?? ""}".toLowerCase().contains(q) ||
          "${r["role"] ?? ""}".toLowerCase().contains(q) ||
          "${r["group"] ?? ""}".toLowerCase().contains(q) ||
          "${r["region"] ?? ""}".toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredNotLoggedIn {
    final q = searchQuery.toLowerCase().trim();

    if (q.isEmpty) return notLoggedIn;

    return notLoggedIn.where((r) {
      return "${r["name"] ?? r["user_name"] ?? ""}"
          .toLowerCase()
          .contains(q) ||
          "${r["username"] ?? ""}".toLowerCase().contains(q) ||
          "${r["role"] ?? ""}".toLowerCase().contains(q) ||
          "${r["group"] ?? ""}".toLowerCase().contains(q) ||
          "${r["region"] ?? ""}".toLowerCase().contains(q) ||
          "${r["employee_code"] ?? ""}".toLowerCase().contains(q) ||
          "${r["phone"] ?? ""}".contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Scaffold(
        backgroundColor: Color(0xfff5f7fb),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 14),
              _filterBar(),
              if (mailSuccess != null) ...[
                const SizedBox(height: 12),
                _successToast(mailSuccess!),
              ],
              const SizedBox(height: 16),
              viewMode == "dashboard" ? _dashboardView() : _reportView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    if (isMobile) {
      return _card(
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _headerIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Login Tracker",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          "${fmtN(summary["total_users"])} employees in scope",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff64748b),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _viewToggle(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mobileHeadStat(
                    "Total",
                    fmtN(summary["total_users"]),
                    const Color(0xff475569),
                  ),
                  _mobileHeadStat(
                    "Logged In",
                    fmtN(summary["unique_users_today"]),
                    const Color(0xff059669),
                  ),
                  _mobileHeadStat(
                    "Not Logged",
                    fmtN(summary["not_logged_in_today"]),
                    const Color(0xffdc2626),
                  ),
                  _mobileHeadStat(
                    "Failed",
                    fmtN(summary["failed_today"]),
                    const Color(0xffd97706),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _headerIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Login Tracker",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    "${fmtN(summary["total_users"])} employees in scope",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff64748b),
                    ),
                  ),
                ],
              ),
            ),
            _headStat(
              "Total Employees",
              fmtN(summary["total_users"]),
              const Color(0xff475569),
            ),
            _headStat(
              "Logged In Today",
              fmtN(summary["unique_users_today"]),
              const Color(0xff059669),
            ),
            _headStat(
              "Not Logged In",
              fmtN(summary["not_logged_in_today"]),
              const Color(0xffdc2626),
            ),
            _headStat(
              "Failed Today",
              fmtN(summary["failed_today"]),
              const Color(0xffd97706),
            ),
            const SizedBox(width: 14),
            _viewToggle(),
          ],
        ),
      ),
    );
  }

  Widget _headerIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xffe2e8f0),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.shield,
        color: Color(0xff4f46e5),
      ),
    );
  }

  Widget _mobileHeadStat(String label, String value, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xff64748b),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToggle() {
    return Container(
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xffe2e8f0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: isMobile ? 1 : 0,
            child: _toggleButton(
              "dashboard",
              "Dashboard",
              Icons.bar_chart,
            ),
          ),
          Expanded(
            flex: isMobile ? 1 : 0,
            child: _toggleButton(
              "report",
              "Report",
              Icons.calendar_today,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String id, String label, IconData icon) {
    final active = viewMode == id;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => viewMode = id),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active ? const Color(0xff4f46e5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : const Color(0xff64748b),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xff64748b),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headStat(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xff94a3b8),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final groupOptions =
    filters["groups"] is List ? filters["groups"] as List : [];
    final owners = filters["owners"] is List ? filters["owners"] as List : [];

    if (isMobile) {
      return _card(
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      "From",
                      dateFrom,
                          (v) => dateFrom = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateField(
                      "To",
                      dateTo,
                          (v) => dateTo = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _employeeDropdown(owners),
              const SizedBox(height: 10),
              _groupDropdown(groupOptions),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loadData,
                      child: const Text("Apply"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text("Reset"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _dateField(
              "From",
              dateFrom,
                  (v) => dateFrom = v,
            ),
            const SizedBox(width: 10),
            _dateField(
              "To",
              dateTo,
                  (v) => dateTo = v,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _employeeDropdown(owners),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _groupDropdown(groupOptions),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: loadData,
              child: const Text("Apply"),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _resetFilters,
              child: const Text("Reset"),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      dateFrom = null;
      dateTo = null;
      assignedTo = null;
      group = null;
    });

    loadData();
  }

  Widget _employeeDropdown(List owners) {
    return DropdownButtonFormField<String>(
      value: assignedTo,
      decoration: _input("Employee"),
      isExpanded: true,
      items: owners.map((o) {
        if (o is Map) {
          return DropdownMenuItem(
            value: "${o["id"]}",
            child: Text(
              "${o["name"] ?? o["username"] ?? o["id"]}",
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        return DropdownMenuItem(
          value: "$o",
          child: Text(
            "$o",
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => assignedTo = v),
    );
  }

  Widget _groupDropdown(List groupOptions) {
    return DropdownButtonFormField<String>(
      value: group,
      decoration: _input("Group"),
      isExpanded: true,
      items: groupOptions.map((g) {
        return DropdownMenuItem(
          value: "$g",
          child: Text(
            "$g",
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => group = v),
    );
  }

  Widget _dateField(
      String label,
      String? value,
      Function(String?) onChanged,
      ) {
    return SizedBox(
      width: isMobile ? null : 145,
      child: TextFormField(
        key: ValueKey("$label-$value"),
        initialValue: value,
        decoration: _input(label).copyWith(
          hintText: "YYYY-MM-DD",
        ),
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xffe2e8f0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xff4f46e5),
        ),
      ),
    );
  }

  Widget _dashboardView() {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: isMobile ? 1 : (isTablet ? 2 : 4),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 3.8 : 3,
          children: [
            _miniKpi(
              Icons.groups,
              "Total Employees",
              fmtN(summary["total_users"]),
              const Color(0xff475569),
            ),
            _miniKpi(
              Icons.verified_user,
              "Logged In Today",
              fmtN(summary["unique_users_today"]),
              const Color(0xff059669),
            ),
            _miniKpi(
              Icons.person_off,
              "Not Logged In Yet",
              fmtN(summary["not_logged_in_today"]),
              const Color(0xffdc2626),
            ),
            _miniKpi(
              Icons.warning_amber,
              "Failed Today",
              fmtN(summary["failed_today"]),
              const Color(0xffd97706),
            ),
          ],
        ),
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _securityAlerts(),
        ],
        const SizedBox(height: 16),
        _responsivePair(
          left: _loginActivityChart(),
          right: _activeSessions(),
          leftFlex: 2,
        ),
        const SizedBox(height: 16),
        _responsivePair(
          left: _usersByRole(),
          right: _devicesBrowsers(),
          leftFlex: 2,
        ),
        const SizedBox(height: 16),
        _responsivePair(
          left: _mostActiveUsers(),
          right: _failedAttempts(),
        ),
        const SizedBox(height: 20),
        _section("05", "Session History"),
        const SizedBox(height: 10),
        _sessionHistoryTable(),
      ],
    );
  }

  Widget _responsivePair({
    required Widget left,
    required Widget right,
    int leftFlex = 1,
  }) {
    if (isMobile) {
      return Column(
        children: [
          left,
          const SizedBox(height: 14),
          right,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: leftFlex,
          child: left,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: right,
        ),
      ],
    );
  }

  Widget _miniKpi(
      IconData icon,
      String label,
      String value,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffe2e8f0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.1),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xff94a3b8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityAlerts() {
    return _card(
      Column(
        children: [
          _cardHead(
            "Security Alerts",
            "${alerts.length} alert(s) detected",
          ),
          ...alerts.map((a) {
            final color = "${a["severity"]}" == "high"
                ? const Color(0xffdc2626)
                : "${a["severity"]}" == "medium"
                ? const Color(0xffd97706)
                : const Color(0xff64748b);

            return ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: color,
              ),
              title: Text(
                "${a["message"] ?? ""}",
                style: const TextStyle(fontSize: 12),
              ),
              trailing: _badge(
                "${a["severity"] ?? ""}",
                color,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _loginActivityChart() {
    final list = activeChart == "hourly"
        ? List<Map<String, dynamic>>.from(
      charts["hourly_distribution"] ?? [],
    )
        : List<Map<String, dynamic>>.from(
      charts["by_weekday"] ?? [],
    );

    final max = list.isEmpty
        ? 1
        : list
        .map(
          (e) => n(
        e[activeChart == "hourly" ? "count" : "value"],
      ),
    )
        .reduce((a, b) => a > b ? a : b);

    return _card(
      Container(
        height: isMobile ? 300 : 330,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Login Activity",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        activeChart == "hourly"
                            ? "Logins by hour of day"
                            : "Logins by weekday",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff64748b),
                        ),
                      ),
                    ],
                  ),
                ),
                _smallToggle("hourly", "Hourly"),
                const SizedBox(width: 6),
                _smallToggle("weekday", "Weekday"),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                child: Text(
                  "No chart data",
                  style: TextStyle(
                    color: Color(0xff94a3b8),
                  ),
                ),
              )
                  : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: list.map((e) {
                  final value = n(
                    e[activeChart == "hourly"
                        ? "count"
                        : "value"],
                  );

                  final h = max == 0
                      ? 0.0
                      : (value / max) * (isMobile ? 180 : 220);

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: isMobile ? 12 : 18,
                          height: h,
                          decoration: BoxDecoration(
                            color: const Color(0xff4f46e5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${e[activeChart == "hourly" ? "label" : "name"] ?? ""}",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xff64748b),
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
      ),
    );
  }

  Widget _smallToggle(String id, String label) {
    final active = activeChart == id;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => activeChart = id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xff4f46e5)
              : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xff64748b),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _activeSessions() {
    return _card(
      SizedBox(
        height: isMobile ? 300 : 330,
        child: Column(
          children: [
            _cardHead(
              "Active Sessions",
              "${activeSessions.length} user(s) online now",
            ),
            Expanded(
              child: activeSessions.isEmpty
                  ? const Center(
                child: Text(
                  "No active sessions",
                  style: TextStyle(
                    color: Color(0xff94a3b8),
                  ),
                ),
              )
                  : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: activeSessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = activeSessions[i];

                  return ListTile(
                    dense: isMobile,
                    leading: const Icon(
                      Icons.circle,
                      color: Color(0xff059669),
                      size: 12,
                    ),
                    title: Text(
                      "${s["user_name"] ?? ""}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "${s["role"] ?? ""} · ${s["region"] ?? ""} · ${s["group"] ?? ""}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isMobile
                        ? null
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${s["browser"] ?? ""}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          "${s["ip_address"] ?? ""}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff94a3b8),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _usersByRole() {
    final roles = List<Map<String, dynamic>>.from(
      charts["by_role_users"] ?? [],
    );
    final max = roles.isEmpty ? 1 : n(roles.first["value"]);

    return _card(
      Container(
        height: isMobile ? null : 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Users by Role / Type",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              "Role-wise user count",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xff64748b),
              ),
            ),
            const SizedBox(height: 12),
            roles.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text("No role data"),
              ),
            )
                : Column(
              children: roles.map((d) {
                final value = n(d["value"]);

                return _progressRow(
                  "${d["name"]}",
                  value,
                  max,
                  const Color(0xff4f46e5),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _devicesBrowsers() {
    final browsers = List<Map<String, dynamic>>.from(
      charts["by_browser"] ?? [],
    );
    final os = List<Map<String, dynamic>>.from(
      charts["by_os"] ?? [],
    );

    return _card(
      Container(
        height: isMobile ? null : 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Devices & Browsers",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Browsers",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xff94a3b8),
              ),
            ),
            if (browsers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "No browser data",
                  style: TextStyle(
                    color: Color(0xff94a3b8),
                  ),
                ),
              ),
            ...browsers.take(5).map(
                  (d) => _miniRow(
                "${d["name"]}",
                n(d["value"]),
                const Color(0xff818cf8),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Operating Systems",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xff94a3b8),
              ),
            ),
            if (os.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "No OS data",
                  style: TextStyle(
                    color: Color(0xff94a3b8),
                  ),
                ),
              ),
            ...os.take(5).map(
                  (d) => _miniRow(
                "${d["name"]}",
                n(d["value"]),
                const Color(0xff7c3aed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniRow(String label, num value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            fmtN(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mostActiveUsers() {
    final list = List<Map<String, dynamic>>.from(
      topLists["most_active"] ?? [],
    );

    return _rankCard(
      "Most Active Users",
      "By login count",
      list,
          (r) => "${r["name"]}",
          (r) => fmtN(r["login_count"]),
    );
  }

  Widget _failedAttempts() {
    final list = List<Map<String, dynamic>>.from(
      topLists["most_failed"] ?? [],
    );

    return _rankCard(
      "Failed Login Attempts",
      "Users with most failures",
      list,
          (r) => "${r["username"]}",
          (r) => "${fmtN(r["attempts"])} attempts",
      danger: true,
    );
  }

  Widget _rankCard(
      String title,
      String sub,
      List<Map<String, dynamic>> items,
      String Function(Map) name,
      String Function(Map) value, {
        bool danger = false,
      }) {
    return _card(
      Column(
        children: [
          _cardHead(title, sub),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                "No data",
                style: TextStyle(
                  color: Color(0xff94a3b8),
                ),
              ),
            )
          else
            ...List.generate(items.length, (i) {
              final r = items[i];

              return ListTile(
                dense: isMobile,
                leading: CircleAvatar(
                  radius: 13,
                  backgroundColor: i < 3
                      ? danger
                      ? const Color(0xffdc2626)
                      : const Color(0xff4f46e5)
                      : const Color(0xfff1f5f9),
                  child: Text(
                    "${i + 1}",
                    style: TextStyle(
                      fontSize: 10,
                      color: i < 3 ? Colors.white : const Color(0xff64748b),
                    ),
                  ),
                ),
                title: Text(
                  name(r),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "${r["role"] ?? ""} ${r["group"] != null ? "· ${r["group"]}" : ""}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  value(r),
                  style: TextStyle(
                    color: danger
                        ? const Color(0xffdc2626)
                        : const Color(0xff4f46e5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sessionHistoryTable() {
    if (sessionTable.isEmpty) {
      return _emptyCard("No session history");
    }

    return Column(
      children: sessionTable.take(100).map((r) {
        final active = r["is_active"] == true;
        final statusColor =
        active ? const Color(0xff059669) : const Color(0xff64748b);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffe6eaf1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0d0f172a),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        active ? Icons.radio_button_checked : Icons.history,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${r["user_name"] ?? "—"}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xff0f172a),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${r["role"] ?? "—"} • ${r["region"] ?? "—"} • ${r["group"] ?? "—"}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff64748b),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _badge(active ? "Active" : "Ended", statusColor),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xffeef2f7)),
                const SizedBox(height: 14),

                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _sessionPlainInfo("Login", fmtDateTime(r["login_time"]))),
                        Expanded(child: _sessionPlainInfo("Logout", fmtDateTime(r["logout_time"]))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _sessionPlainInfo("Duration", fmtDuration(r["duration_minutes"]))),
                        Expanded(child: _sessionPlainInfo("Device", "${r["device"] ?? "—"}")),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _sessionPlainInfo("Browser", "${r["browser"] ?? "—"}")),
                        Expanded(child: _sessionPlainInfo("IP", "${r["ip_address"] ?? "—"}")),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sessionPlainInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xff94a3b8),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xff0f172a),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _reportView() {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _reportTabButton(
                  "logged_in",
                  "Logged In",
                  Icons.verified_user,
                  filteredLoggedIn.length,
                  const Color(0xff059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _reportTabButton(
                  "not_logged_in",
                  "Not Logged",
                  Icons.person_off,
                  filteredNotLoggedIn.length,
                  const Color(0xffdc2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: _input(
              reportTab == "logged_in"
                  ? "Search by name, role, group..."
                  : "Search by name, employee code, phone...",
            ),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
          if (reportTab == "not_logged_in" &&
              selectedNotLoggedIn.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => sendReminder(selectedNotLoggedIn.toList()),
                icon: const Icon(Icons.send, size: 14),
                label: Text(
                  "Send Reminder (${selectedNotLoggedIn.length})",
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          reportTab == "logged_in" ? _loggedInTable() : _notLoggedInTable(),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            _reportTabButton(
              "logged_in",
              "Logged In Today",
              Icons.verified_user,
              filteredLoggedIn.length,
              const Color(0xff059669),
            ),
            const SizedBox(width: 8),
            _reportTabButton(
              "not_logged_in",
              "Not Logged In",
              Icons.person_off,
              filteredNotLoggedIn.length,
              const Color(0xffdc2626),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                decoration: _input(
                  reportTab == "logged_in"
                      ? "Search by name, role, group..."
                      : "Search by name, employee code, phone...",
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),
            if (reportTab == "not_logged_in" &&
                selectedNotLoggedIn.isNotEmpty) ...[
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => sendReminder(selectedNotLoggedIn.toList()),
                icon: const Icon(Icons.send, size: 14),
                label: Text(
                  "Send Reminder (${selectedNotLoggedIn.length})",
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        reportTab == "logged_in" ? _loggedInTable() : _notLoggedInTable(),
      ],
    );
  }

  Widget _reportTabButton(
      String id,
      String label,
      IconData icon,
      int count,
      Color color,
      ) {
    final active = reportTab == id;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        reportTab = id;
        searchQuery = "";
        selectedNotLoggedIn.clear();
      }),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active ? color : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : color,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xff64748b),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _badge(
              fmtN(count),
              active ? Colors.white : color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _loggedInTable() {
    if (isMobile) {
      if (filteredLoggedIn.isEmpty) {
        return _emptyCard("No logged in employees found");
      }

      return Column(
        children: filteredLoggedIn.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _mobileDataCard(
              title: "${r["user_name"] ?? "—"}",
              subtitle: "${r["username"] ?? ""}",
              badge: _badge(
                "${r["role"] ?? ""}",
                const Color(0xff64748b),
              ),
              rows: [
                _infoPair("Region", "${r["region"] ?? "—"}"),
                _infoPair("Group", "${r["group"] ?? "—"}"),
                _infoPair("Branch", "${r["branch"] ?? "—"}"),
                _infoPair("First Login", fmtTime(r["first_login"])),
                _infoPair("Last Activity", fmtTime(r["last_logout"])),
                _infoPair("Duration", fmtDuration(r["duration_minutes"])),
                _infoPair("Sessions", fmtN(r["session_count"])),
                _infoPair(
                  "Device",
                  (r["devices"] is List && (r["devices"] as List).isNotEmpty)
                      ? "${r["devices"][0]}"
                      : "—",
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return _card(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xfff8fafc),
          ),
          columns: const [
            DataColumn(label: Text("Employee")),
            DataColumn(label: Text("Role")),
            DataColumn(label: Text("Region")),
            DataColumn(label: Text("Group")),
            DataColumn(label: Text("Branch")),
            DataColumn(label: Text("First Login")),
            DataColumn(label: Text("Last Activity")),
            DataColumn(label: Text("Duration")),
            DataColumn(label: Text("Sessions")),
            DataColumn(label: Text("Device")),
          ],
          rows: filteredLoggedIn.map((r) {
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${r["user_name"] ?? "—"}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "${r["username"] ?? ""}",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xff94a3b8),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  _badge(
                    "${r["role"] ?? ""}",
                    const Color(0xff64748b),
                  ),
                ),
                DataCell(Text("${r["region"] ?? "—"}")),
                DataCell(Text("${r["group"] ?? "—"}")),
                DataCell(Text("${r["branch"] ?? "—"}")),
                DataCell(Text(fmtTime(r["first_login"]))),
                DataCell(Text(fmtTime(r["last_logout"]))),
                DataCell(Text(fmtDuration(r["duration_minutes"]))),
                DataCell(Text(fmtN(r["session_count"]))),
                DataCell(
                  Text(
                    (r["devices"] is List &&
                        (r["devices"] as List).isNotEmpty)
                        ? "${r["devices"][0]}"
                        : "—",
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _notLoggedInTable() {
    final allSelected = filteredNotLoggedIn.isNotEmpty &&
        selectedNotLoggedIn.length == filteredNotLoggedIn.length;

    if (isMobile) {
      return Column(
        children: [
          _card(
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${fmtN(filteredNotLoggedIn.length)} employees haven't logged in today",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff64748b),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          selectedNotLoggedIn.clear();
                        } else {
                          selectedNotLoggedIn
                            ..clear()
                            ..addAll(
                              filteredNotLoggedIn.map(
                                    (u) => n(u["id"]).toInt(),
                              ),
                            );
                        }
                      });
                    },
                    icon: Icon(
                      allSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    label: Text(allSelected ? "Clear" : "All"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (filteredNotLoggedIn.isEmpty)
            _emptyCard("No employees found")
          else
            ...filteredNotLoggedIn.map((r) {
              final id = n(r["id"]).toInt();
              final selected = selectedNotLoggedIn.contains(id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _card(
                  Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xffeef2ff)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: (_) => setState(() {
                                  selected
                                      ? selectedNotLoggedIn.remove(id)
                                      : selectedNotLoggedIn.add(id);
                                }),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${r["name"] ?? r["user_name"] ?? "—"}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${r["username"] ?? ""}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xff94a3b8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _badge(
                                "${r["role"] ?? ""}",
                                const Color(0xff64748b),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _infoGrid([
                            _infoPair("Region", "${r["region"] ?? "—"}"),
                            _infoPair("Group", "${r["group"] ?? "—"}"),
                            _infoPair("Branch", "${r["branch"] ?? "—"}"),
                            _infoPair("Phone", "${r["phone"] ?? "—"}"),
                            _infoPair(
                              "Emp Code",
                              "${r["employee_code"] ?? "—"}",
                            ),
                            _infoPair(
                              "Last Login",
                              r["last_login"] == null
                                  ? "Never logged in"
                                  : fmtDateTime(r["last_login"]),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => sendReminder([id]),
                              icon: const Icon(Icons.mail, size: 14),
                              label: const Text("Send Mail"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      );
    }

    return _card(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  "${fmtN(filteredNotLoggedIn.length)} employees haven't logged in today",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff64748b),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        selectedNotLoggedIn.clear();
                      } else {
                        selectedNotLoggedIn
                          ..clear()
                          ..addAll(
                            filteredNotLoggedIn.map(
                                  (u) => n(u["id"]).toInt(),
                            ),
                          );
                      }
                    });
                  },
                  icon: Icon(
                    allSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                  label: Text(
                    allSelected ? "Deselect All" : "Select All",
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xfff8fafc),
              ),
              columns: const [
                DataColumn(label: Text("")),
                DataColumn(label: Text("Employee")),
                DataColumn(label: Text("Role")),
                DataColumn(label: Text("Region")),
                DataColumn(label: Text("Group")),
                DataColumn(label: Text("Branch")),
                DataColumn(label: Text("Phone")),
                DataColumn(label: Text("Emp Code")),
                DataColumn(label: Text("Last Login")),
                DataColumn(label: Text("Action")),
              ],
              rows: filteredNotLoggedIn.map((r) {
                final id = n(r["id"]).toInt();

                return DataRow(
                  color: WidgetStateProperty.all(
                    selectedNotLoggedIn.contains(id)
                        ? const Color(0xffeef2ff)
                        : Colors.white,
                  ),
                  cells: [
                    DataCell(
                      Checkbox(
                        value: selectedNotLoggedIn.contains(id),
                        onChanged: (_) => setState(() {
                          selectedNotLoggedIn.contains(id)
                              ? selectedNotLoggedIn.remove(id)
                              : selectedNotLoggedIn.add(id);
                        }),
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${r["name"] ?? r["user_name"] ?? "—"}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "${r["username"] ?? ""}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xff94a3b8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      _badge(
                        "${r["role"] ?? ""}",
                        const Color(0xff64748b),
                      ),
                    ),
                    DataCell(Text("${r["region"] ?? "—"}")),
                    DataCell(Text("${r["group"] ?? "—"}")),
                    DataCell(Text("${r["branch"] ?? "—"}")),
                    DataCell(Text("${r["phone"] ?? "—"}")),
                    DataCell(Text("${r["employee_code"] ?? "—"}")),
                    DataCell(
                      Text(
                        r["last_login"] == null
                            ? "Never logged in"
                            : fmtDateTime(r["last_login"]),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => sendReminder([id]),
                        icon: const Icon(Icons.mail, size: 12),
                        label: const Text("Send Mail"),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileDataCard({
    required String title,
    required String subtitle,
    required Widget badge,
    required List<MapEntry<String, String>> rows,
  }) {
    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff94a3b8),
                        ),
                      ),
                    ],
                  ),
                ),
                badge,
              ],
            ),
            const SizedBox(height: 12),
            _infoGrid(rows),
          ],
        ),
      ),
    );
  }

  MapEntry<String, String> _infoPair(String label, String value) {
    return MapEntry(label, value);
  }

  Widget _infoGrid(List<MapEntry<String, String>> rows) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: rows.map((e) {
        return SizedBox(
          width: isMobile
              ? (MediaQuery.of(context).size.width - 58) / 2
              : 180,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xffeef2f7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xff94a3b8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff0f172a),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyCard(String text) {
    return _card(
      Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xff94a3b8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _successToast(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffecfdf5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xffbbf7d0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_box,
            color: Color(0xff059669),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xff065f46),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
      String label,
      num value,
      num total,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 92 : 130,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0
                  ? 0
                  : (value / total).clamp(0, 1).toDouble(),
              minHeight: 9,
              backgroundColor: const Color(0xfff1f5f9),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            child: Text(
              fmtN(value),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    if (text.isEmpty) return const SizedBox();

    final white = color == Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: white
            ? Colors.white.withOpacity(.22)
            : color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: white ? Colors.white : color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xffe6eaf1),
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0d0f172a),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHead(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xffe2e8f0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff64748b),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
      String idx,
      String title, [
        String? desc,
      ]) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xffeef2ff),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            idx,
            style: const TextStyle(
              color: Color(0xff4f46e5),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (desc != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff64748b),
              ),
            ),
          ),
        ],
      ],
    );
  }
}