import 'dart:convert';
import 'dart:math' as math;
import 'package:ascent_crm/main_screens/kam_360/plan_your_day.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF3060A0);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF3060A0),
      Color(0xFF3060A0),
      Color(0xFF3060A0),
      Color(0xFF204070),
      Color(0xFF103050),
      Color(0xFF102040),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class Kam360Page extends StatefulWidget {
  const Kam360Page({super.key});

  @override
  State<Kam360Page> createState() => _Kam360PageState();
}

class _TableHead extends StatelessWidget {
  final String text;
  final bool center;

  const _TableHead(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
        color: Color(0xff64748B),
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    );
  }
}

class _Kam360PageState extends State<Kam360Page>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final String baseUrl = "http://103.110.236.187:3076/api/v1";
  String? token;


  String advancedSection = "tree";
  int? expandedGroupId;
  int? expandedAdvancedMemberId;

  bool pageLoading = true;
  bool activitiesLoading = true;
  bool kamLoading = true;
  bool saving = false;
  bool panelLoading = false;

  String tabName = "activities";

  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> ownCustomers = [];
  List<Map<String, dynamic>> popupCustomers = [];
  List<Map<String, dynamic>> teamMembers = [];
  List<Map<String, dynamic>> teamRows = [];
  List<Map<String, dynamic>> customerActivities = [];
  List<Map<String, dynamic>> masterGroups = [];

  List<Map<String, dynamic>> panelLeads = [];
  List<Map<String, dynamic>> panelTenders = [];
  List<Map<String, dynamic>> panelCustomers = [];

  Map<String, dynamic> summary = {};
  Map<String, dynamic> performance = {};

  String panelTitle = "";
  double panelSalesTarget = 0;
  double panelWonValue = 0;

  bool isYearly = false;
  int selectedYear = DateTime.now().year;
  String period = "";

  String viewMode = "normal"; // normal / advanced

  int? selectedKamUserId;
  int? selectedKamCustomerId;
  int? expandedMemberId;
  int? expandedCustomerId;

  String kamCustomerSearch = "";
  String advancedMemberSearch = "";

  String activitySearch = "";
  String dateView = "today"; // today / all / custom
  String? selectedActivityType;
  String? selectedActivityStatus;
  int? selectedActivityCustomerId;
  int? selectedActivityUserId;
  DateTime? activityFromDate;
  DateTime? activityToDate;

  final List<String> activityTypes = const [
    "Phone Call",
    "Video Call",
    "In Person Meet",
    "Demo",
    "Site Visit",
    "Follow Up",
    "Email",
  ];

  final List<String> activityStatuses = const [
    "Planned",
    "In Progress",
    "Completed",
    "Cancelled",
    "Postponed",
  ];

  final List<String> travelModes = const [
    "Own Vehicle",
    "Company Vehicle",
    "Train",
    "Bus",
    "Auto/Cab",
  ];

  final List<String> visitTypes = const [
    "Customer Visit",
    "Site Visit",
    "Training",
    "Conference",
    "Meeting",
    "Demo / Presentation",
    "Audit",
    "Follow-up",
    "Other",
  ];

  final List<String> accommodationTypes = const [
    "Company Guest House",
    "Hotel (Self-Book)",
    "Hotel (Company Arranged)",
    "Customer Arranged",
    "Home Stay",
    "Not Required",
  ];

  final Map<String, String> transportModes = const {
    "own_vehicle": "Own Vehicle",
    "company_car": "Company Car",
    "train": "Train",
    "bus": "Bus",
    "taxi_cab": "Taxi / Cab",
    "bike": "Bike",
    "flight": "Flight",
    "other": "Other",
  };

  final Map<String, List<String>> followupCategories = const {
    "Technical": [
      "Product Demo",
      "PoC Support",
      "Spec Clarification",
      "Installation Support",
    ],
    "Commercial": [
      "Price Negotiation",
      "Payment Follow-up",
      "Order Confirmation",
      "Quotation Review",
    ],
    "Tender": [
      "Tender Submission",
      "Bid Clarification",
      "Rate Revision",
      "L1 Negotiation",
    ],
    "Support": [
      "AMC Renewal",
      "Complaint Resolution",
      "Escalation",
      "SLA Review",
    ],
    "Relationship": [
      "Executive Visit",
      "Review Meeting",
      "Reference Request",
      "Event Invite",
    ],
  };

  final List<String> cancellationReasons = const [
    "Customer unavailable",
    "Customer rescheduled",
    "Internal priority change",
    "Travel issue",
    "Technical issue",
    "Customer cancelled",
    "Weather / force majeure",
    "Other",
  ];

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging && mounted) {
        setState(() {
          tabName = tabController.index == 0 ? "activities" : "360";
        });
      }
    });

    final now = DateTime.now();
    period = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    loadAll();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Map<String, String> get headers => {
    "Authorization": "Bearer $token",
    "X-Tenant-Slug": "ascent",
    "Accept": "application/json",
    "Content-Type": "application/json",
  };

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("auth_token");

    if (token == null || token!.isEmpty) {
      setState(() {
        pageLoading = false;
        activitiesLoading = false;
        kamLoading = false;
      });
      showError("Login token not found");
      return;
    }

    setState(() => pageLoading = true);

    await Future.wait([
      fetchTeamMembers(),
      fetchCustomers(),
    ]);

    await Future.wait([
      fetchActivities(),
      fetchKam360(),
      fetchKamSharedData(),
    ]);

    if (mounted) setState(() => pageLoading = false);
  }

  Future<dynamic> getApi(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse("$baseUrl$path").replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);

    debugPrint("GET => $uri");
    debugPrint("STATUS => ${response.statusCode}");

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(response.body);
  }

  Future<dynamic> postApi(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: headers,
      body: jsonEncode(body),
    );

    debugPrint("POST => $baseUrl$path");
    debugPrint("BODY => ${jsonEncode(body)}");
    debugPrint("STATUS => ${response.statusCode}");

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(response.body);
  }

  Future<dynamic> putApi(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse("$baseUrl$path"),
      headers: headers,
      body: jsonEncode(body),
    );

    debugPrint("PUT => $baseUrl$path");
    debugPrint("BODY => ${jsonEncode(body)}");
    debugPrint("STATUS => ${response.statusCode}");

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return {};
      return jsonDecode(response.body);
    }

    throw Exception(response.body);
  }

  Future<void> fetchTeamMembers() async {
    try {
      final data = await getApi("/kam/team-members");
      setState(() {
        teamMembers = toMapList(data);
      });
    } catch (e) {
      debugPrint("fetchTeamMembers failed: $e");
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final data = await getApi("/kam/plan-customers", params: {
        "per_page": "5000",
      });
      setState(() {
        customers = toMapList(data);
        popupCustomers = toMapList(data);
      });
    } catch (e) {
      debugPrint("fetchCustomers failed: $e");
    }
  }

  Future<void> fetchKamSharedData() async {
    try {
      final requestPeriod = isYearly ? selectedYear.toString() : period;

      final results = await Future.wait([
        getApi("/kam/plan-customers", params: {
          "own_only": "true",
          "per_page": "5000",
          "period": requestPeriod,
          "view_type": isYearly ? "yearly" : "monthly",
          "year": selectedYear.toString(),
        }).catchError((_) => []),
        getApi("/kam/team-360", params: {
          "period": requestPeriod,
          "view_type": isYearly ? "yearly" : "monthly",
          "year": selectedYear.toString(),
        }).catchError((_) => {}),
        getApi("/masters/groups").catchError((_) => []),
      ]);

      setState(() {
        ownCustomers = toMapList(results[0]);

        final teamData = Map<String, dynamic>.from(results[1] as Map? ?? {});
        teamRows = toMapList(teamData["members"] ?? []);

        masterGroups = toMapList(results[2]);
      });
    } catch (e) {
      debugPrint("fetchKamSharedData failed: $e");
    }
  }

  Future<void> fetchActivities() async {
    try {
      setState(() => activitiesLoading = true);

      final params = <String, String>{};

      if (selectedActivityUserId != null) {
        params["user_id"] = selectedActivityUserId.toString();
      }

      if (selectedActivityType != null && selectedActivityType!.isNotEmpty) {
        params["activity_type"] = selectedActivityType!;
      }

      if (selectedActivityStatus != null && selectedActivityStatus!.isNotEmpty) {
        params["status"] = selectedActivityStatus!;
      }

      if (selectedActivityCustomerId != null) {
        params["customer_id"] = selectedActivityCustomerId.toString();
      }

      if (activityFromDate != null) {
        params["date_from"] = dateText(activityFromDate!);
      }

      if (activityToDate != null) {
        params["date_to"] = dateText(activityToDate!);
      }

      if (params.isEmpty && dateView == "today") {
        params["activity_date"] = dateText(DateTime.now());
      }

      final data = await getApi("/kam/activities", params: params);

      setState(() {
        activities = toMapList(data);
        activitiesLoading = false;
      });
    } catch (e) {
      setState(() => activitiesLoading = false);
      showError(e.toString());
    }
  }

  Future<void> fetchKam360() async {
    try {
      setState(() => kamLoading = true);

      final requestPeriod = isYearly ? selectedYear.toString() : period;

      final params = <String, String>{
        "period": requestPeriod,
        "view_type": isYearly ? "yearly" : "monthly",
        "year": selectedYear.toString(),
      };

      if (selectedKamUserId != null) {
        params["user_id"] = selectedKamUserId.toString();
      }

      final results = await Future.wait([
        getApi("/kam/360-summary", params: params),
        getApi("/kam/customer-activities", params: params),
        getApi("/kam/performance", params: params),
      ]);

      setState(() {
        summary = Map<String, dynamic>.from(results[0] as Map);
        customerActivities = toMapList(results[1]);
        performance = Map<String, dynamic>.from(results[2] as Map);
        kamLoading = false;
      });
    } catch (e) {
      setState(() => kamLoading = false);
      showError(e.toString());
    }
  }

  Future<void> reloadKamAll() async {
    await Future.wait([
      fetchKam360(),
      fetchKamSharedData(),
    ]);
  }

  Future<void> refreshCurrentTab() async {
    if (tabController.index == 0) {
      await fetchActivities();
    } else {
      await reloadKamAll();
    }
  }

  Future<void> openLeadPanel({int? userId, int? customerId, String? title}) async {
    setState(() {
      panelTitle = title ?? "Leads";
      panelLeads = [];
      panelLoading = true;
    });

    try {
      final params = <String, String>{};

      if (userId != null) params["assigned_to"] = userId.toString();
      if (customerId != null) params["customer_id"] = customerId.toString();

      final data = await getApi("/leads", params: params);

      setState(() {
        panelLeads = normalizeItems(data);
        panelLoading = false;
      });

      showLeadPanel();
    } catch (e) {
      setState(() => panelLoading = false);
      showError(e.toString());
    }
  }

  Future<void> openTenderPanel({
    int? userId,
    int? customerId,
    String? title,
  }) async {
    setState(() {
      panelTitle = title ?? "Tenders";
      panelTenders = [];
      panelLoading = true;
    });

    try {
      final params = <String, String>{};

      if (userId != null) params["assigned_to"] = userId.toString();
      if (customerId != null) params["customer_id"] = customerId.toString();

      final data = await getApi("/tenders", params: params);

      setState(() {
        panelTenders = normalizeItems(data);
        panelLoading = false;
      });

      showTenderPanel();
    } catch (e) {
      setState(() => panelLoading = false);
      showError(e.toString());
    }
  }

  Future<void> openCustomerPanel({
    int? userId,
    String? title,
    bool ownOnly = false,
  }) async {
    setState(() {
      panelTitle = title ?? "Customers";
      panelCustomers = [];
      panelLoading = true;
    });

    try {
      final requestPeriod = isYearly ? selectedYear.toString() : period;

      final params = <String, String>{
        "per_page": "5000",
        "period": requestPeriod,
        "view_type": isYearly ? "yearly" : "monthly",
        "year": selectedYear.toString(),
      };

      if (userId != null) params["user_id"] = userId.toString();
      if (ownOnly) params["own_only"] = "true";

      final data = await getApi("/kam/plan-customers", params: params);

      setState(() {
        panelCustomers = toMapList(data);
        panelLoading = false;
      });

      showCustomerPanel();
    } catch (e) {
      setState(() => panelLoading = false);
      showError(e.toString());
    }
  }

  Future<double> fetchCurrentSalesTarget({
    required int userId,
    required String targetPeriod,
  }) async {
    try {
      final data = await getApi("/kam/targets/summary", params: {
        "user_id": userId.toString(),
        "period": targetPeriod,
      });
      return asDouble(data["sales_target"]);
    } catch (_) {
      return 0;
    }
  }

  List<Map<String, dynamic>> toMapList(dynamic data) {
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    if (data is Map && data["items"] is List) {
      return (data["items"] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (data is Map && data["data"] is List) {
      return (data["data"] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  List<Map<String, dynamic>> normalizeItems(dynamic data) {
    return toMapList(data);
  }

  double asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String safeText(dynamic value, [String fallback = "-"]) {
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? fallback : text;
  }

  String dateText(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String money(dynamic value) {
    final amount = asDouble(value);

    if (amount >= 10000000) {
      return "₹${(amount / 10000000).toStringAsFixed(1)}Cr";
    }
    if (amount >= 100000) {
      return "₹${(amount / 100000).toStringAsFixed(1)}L";
    }
    if (amount >= 1000) {
      return "₹${(amount / 1000).toStringAsFixed(0)}K";
    }
    return "₹${amount.toStringAsFixed(0)}";
  }

  int pct(dynamic value, dynamic target) {
    final v = asDouble(value);
    final t = asDouble(target);
    if (t <= 0) return v > 0 ? 100 : 0;
    return ((v / t) * 100).clamp(0, 100).round();
  }

  bool isSalesKAMUser(dynamic role) {
    final r = role?.toString().toLowerCase() ?? "";
    return !["ceo", "admin", "super_admin", "accounts"].contains(r);
  }

  bool get canViewTeam {
    return teamMembers.where((u) => isSalesKAMUser(u["role"])).length > 1 ||
        teamRows.isNotEmpty;
  }

  bool get canSetTarget {
    return teamMembers.where((u) => isSalesKAMUser(u["role"])).isNotEmpty;
  }

  String roleLabel(dynamic role) {
    final r = role?.toString().toLowerCase() ?? "";
    switch (r) {
      case "manager":
      case "sales_head":
        return "Sales Head";
      case "vp":
        return "VP";
      case "sales":
      case "sales_executive":
        return "Sales";
      case "admin":
        return "Admin";
      case "ceo":
        return "CEO";
      case "support":
        return "Support";
      case "accounts":
        return "Accounts";
      default:
        return role?.toString() ?? "User";
    }
  }

  String activityTypeName(Map<String, dynamic> item) {
    final raw = item["task_type_name"]?.toString() ??
        item["activity_type"]?.toString() ??
        "Task";

    final mode = item["mode"]?.toString() ?? "";

    if (raw == "Daily Call") {
      return mode == "Video Call" ? "Video Call" : "Phone Call";
    }
    if (raw == "Meeting") return "In Person Meet";
    if (raw == "Follow-up") return "Follow Up";
    if (raw == "Phone") return "Phone Call";
    if (raw == "In-Person") return "In Person Meet";

    return raw;
  }

  bool isTravelActivityType(String type) {
    return ["In Person Meet", "Meeting", "Site Visit"].contains(type);
  }

  String modeForActivityType(String type) {
    switch (type) {
      case "Phone Call":
        return "Phone";
      case "Video Call":
        return "Video Call";
      case "In Person Meet":
      case "Meeting":
      case "Site Visit":
      case "Demo":
        return "In-Person";
      case "Email":
        return "Email";
      default:
        return "Phone";
    }
  }

  Color typeColor(String type) {
    switch (type) {
      case "Phone Call":
        return const Color(0xff2563EB);
      case "Video Call":
        return const Color(0xff0891B2);
      case "In Person Meet":
        return const Color(0xff7C3AED);
      case "Demo":
        return const Color(0xff059669);
      case "Site Visit":
        return const Color(0xffEA580C);
      case "Follow Up":
        return const Color(0xffD97706);
      case "Email":
        return const Color(0xff64748B);
      default:
        return const Color(0xff475569);
    }
  }

  IconData typeIcon(String type) {
    switch (type) {
      case "Phone Call":
        return Icons.phone_outlined;
      case "Video Call":
        return Icons.videocam_outlined;
      case "In Person Meet":
        return Icons.handshake_outlined;
      case "Demo":
        return Icons.desktop_windows_outlined;
      case "Site Visit":
        return Icons.near_me_outlined;
      case "Follow Up":
        return Icons.repeat_rounded;
      case "Email":
        return Icons.email_outlined;
      default:
        return Icons.task_alt_rounded;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "Completed":
        return const Color(0xff059669);
      case "Cancelled":
        return const Color(0xffDC2626);
      case "Postponed":
        return const Color(0xff64748B);
      case "In Progress":
        return const Color(0xffD97706);
      default:
        return const Color(0xff2563EB);
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FB),
      body: Column(
        children: [
          header(),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                activitiesTab(),
                kam360Tab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget header() {
    final isActivities = tabController.index == 0;
    final count = isActivities ? activities.length : customerActivities.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.18)),
                  ),
                  child: Icon(
                    isActivities ? Icons.task_alt_rounded : Icons.pie_chart_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActivities ? "Activities" : "KAM 360",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        isActivities
                            ? "$count activity records"
                            : "$count customer records",
                        style: TextStyle(
                          color: Colors.white.withOpacity(.72),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: (){
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) =>  PlanYourDayPage(
                      customers: customers,
                      teamMembers: teamMembers,
                      baseUrl: baseUrl,
                      token: token!,
                    ),));
                  },
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text("Plan Day"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  Colors.white,
                    foregroundColor: AppColors.primaryLight,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8,horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                SizedBox(width: 6,),
                _headerIconBtn(Icons.refresh_rounded, refreshCurrentTab),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 46,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.14)),
              ),
              child: TabBar(
                controller: tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: Colors.white.withOpacity(.78),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: "Activities"),
                  Tab(text: "KAM 360"),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget activitiesTab() {
    final filtered = activities.where((a) {
      final q = activitySearch.toLowerCase().trim();
      if (q.isEmpty) return true;

      return safeText(a["subject"], "").toLowerCase().contains(q) ||
          safeText(a["customer_name"], "").toLowerCase().contains(q) ||
          safeText(a["user_name"], "").toLowerCase().contains(q) ||
          safeText(a["activity_type"], "").toLowerCase().contains(q) ||
          safeText(a["task_type_name"], "").toLowerCase().contains(q);
    }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final a in filtered) {
      final user = safeText(a["user_name"], "My Activities");
      grouped.putIfAbsent(user, () => []).add(a);
    }

    return RefreshIndicator(
      onRefresh: fetchActivities,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _activitySummaryStrip(),
          const SizedBox(height: 14),
          _activityFilters(),
          const SizedBox(height: 16),
          if (activitiesLoading)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            _emptyCard(
              icon: Icons.event_available_rounded,
              title: "No activities found",
              subtitle: "Change filters to view activity records.",
            )
          else
            ...grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (canViewTeam) _activityGroupHeader(entry.key, entry.value.length),
                  ...entry.value.map(activityCard),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _activitySummaryStrip() {
    final total = activities.length;
    final completed =
        activities.where((e) => safeText(e["status"]) == "Completed").length;
    final cancelled =
        activities.where((e) => safeText(e["status"]) == "Cancelled").length;
    final pending = activities
        .where((e) =>
    safeText(e["status"]) == "Planned" ||
        safeText(e["status"]) == "In Progress")
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _activityMetric("Total", total, Icons.list_alt_rounded),
          _activityMetric("Completed", completed, Icons.check_circle_rounded),
          _activityMetric("Pending", pending, Icons.pending_actions_rounded),
          _activityMetric("Cancelled", cancelled, Icons.cancel_rounded),
        ],
      ),
    );
  }

  Widget _activityMetric(String label, int value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            "$value",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(.72),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityGroupHeader(String name, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppColors.primaryLight, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xff0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          _miniBadge("$count activities", AppColors.primaryLight),
        ],
      ),
    );
  }

  Widget _activityFilters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _segmentedButton(
                  label: "Today",
                  active: dateView == "today",
                  icon: Icons.today_rounded,
                  onTap: () {
                    setState(() {
                      dateView = "today";
                      activityFromDate = null;
                      activityToDate = null;
                    });
                    fetchActivities();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _segmentedButton(
                  label: "All",
                  active: dateView == "all",
                  icon: Icons.list_rounded,
                  onTap: () {
                    setState(() {
                      dateView = "all";
                      activityFromDate = null;
                      activityToDate = null;
                    });
                    fetchActivities();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _segmentedButton(
                  label: "Custom",
                  active: dateView == "custom",
                  icon: Icons.date_range_rounded,
                  onTap: () {
                    setState(() => dateView = "custom");
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => activitySearch = v),
            decoration: inputDecoration(
              hint: "Search activity, customer or user...",
              icon: Icons.search_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _filterDropdown<String>(
                  value: selectedActivityType,
                  hint: "All Types",
                  items: activityTypes,
                  onChanged: (v) {
                    setState(() => selectedActivityType = v);
                    fetchActivities();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterDropdown<String>(
                  value: selectedActivityStatus,
                  hint: "All Status",
                  items: activityStatuses,
                  onChanged: (v) {
                    setState(() => selectedActivityStatus = v);
                    fetchActivities();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _activityCustomerDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _activityUserDropdown()),
            ],
          ),
          if (dateView == "custom") ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dateFilterBox(
                    label: activityFromDate == null
                        ? "From Date"
                        : dateText(activityFromDate!),
                    onTap: () => pickFilterDate(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateFilterBox(
                    label: activityToDate == null
                        ? "To Date"
                        : dateText(activityToDate!),
                    onTap: () => pickFilterDate(false),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: clearActivityFilters,
                  icon: const Icon(Icons.clear_rounded, size: 17),
                  label: const Text("Clear"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff64748B),
                    side: const BorderSide(color: Color(0xffCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: fetchActivities,
                  icon: const Icon(Icons.filter_alt_rounded, size: 17),
                  label: const Text("Apply"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget activityCard(Map<String, dynamic> item) {
    final type = activityTypeName(item);
    final status = safeText(item["status"]);
    final color = typeColor(type);
    final isDone = status == "Completed";
    final isCancelled = status == "Cancelled";
    final isOpen = !isDone && !isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(radius: 22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => openActivityDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  typeBox(type, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      safeText(item["subject"]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCancelled
                            ? const Color(0xff94A3B8)
                            : const Color(0xff0F172A),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  _statusPill(status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _softInfoChip(type, color, typeIcon(type)),
                  if (safeText(item["customer_name"], "").isNotEmpty)
                    _softInfoChip(
                      safeText(item["customer_name"]),
                      AppColors.primaryLight,
                      Icons.business_outlined,
                    ),
                  if (canViewTeam && safeText(item["user_name"], "").isNotEmpty)
                    _softInfoChip(
                      safeText(item["user_name"]),
                      const Color(0xff7C3AED),
                      Icons.person_outline_rounded,
                    ),
                  _softInfoChip(
                    safeText(item["activity_date"]),
                    const Color(0xff64748B),
                    Icons.calendar_today_outlined,
                  ),
                  if (asInt(item["duration_minutes"]) > 0)
                    _softInfoChip(
                      "${asInt(item["duration_minutes"])}m",
                      const Color(0xff64748B),
                      Icons.access_time,
                    ),
                  if (item["has_travel"] == true)
                    _softInfoChip(
                      item["is_outside_district"] == true
                          ? "Outside district"
                          : "Local travel",
                      const Color(0xffEA580C),
                      item["is_outside_district"] == true
                          ? Icons.flight_takeoff_rounded
                          : Icons.directions_car_rounded,
                    ),
                ],
              ),
              if (safeText(item["outcome"], "").isNotEmpty ||
                  safeText(item["next_action"], "").isNotEmpty ||
                  item["has_travel"] == true) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (safeText(item["outcome"], "").isNotEmpty)
                      _compactInfo(
                        icon: isCancelled
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline_rounded,
                        text: "${isCancelled ? "Cancelled" : "Outcome"}: ${safeText(item["outcome"])}",
                        color: isCancelled
                            ? const Color(0xffDC2626)
                            : const Color(0xff059669),
                      ),
                    if (safeText(item["next_action"], "").isNotEmpty)
                      _compactInfo(
                        icon: Icons.arrow_forward_rounded,
                        text:
                        "Follow-up: ${safeText(item["next_action"])}${safeText(item["next_action_date"], "").isNotEmpty ? " (${safeText(item["next_action_date"])})" : ""}",
                        color: AppColors.primaryLight,
                      ),
                    if (item["has_travel"] == true)
                      _compactInfo(
                        icon: item["is_outside_district"] == true
                            ? Icons.flight_takeoff_rounded
                            : Icons.directions_car_rounded,
                        text:
                        "${safeText(item["travel_from"], "—")} → ${safeText(item["travel_to"], "—")}${safeText(item["travel_mode"], "").isNotEmpty ? " (${safeText(item["travel_mode"])})" : ""}",
                        color: const Color(0xffEA580C),
                      ),
                  ],
                ),
              ],
              if (isOpen) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openActivityForm(item, isEdit: true),
                        icon: const Icon(Icons.edit_rounded, size: 17),
                        label: const Text("Edit"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => openUpdateActivityLogDialog(item),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text("Log"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void openActivityDetail(Map<String, dynamic> activity) {
    final type = activityTypeName(activity);
    final status = safeText(activity["status"]);
    final isDone = status == "Completed";
    final isCancelled = status == "Cancelled";
    final isOpen = !isDone && !isCancelled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xffCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      typeBox(type, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          safeText(activity["subject"]),
                          style: const TextStyle(
                            color: Color(0xff0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _statusPill(status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _softInfoChip(type, typeColor(type), typeIcon(type)),
                      if (safeText(activity["customer_name"], "").isNotEmpty)
                        _softInfoChip(
                          safeText(activity["customer_name"]),
                          AppColors.primaryLight,
                          Icons.business_outlined,
                        ),
                      if (safeText(activity["user_name"], "").isNotEmpty)
                        _softInfoChip(
                          safeText(activity["user_name"]),
                          const Color(0xff7C3AED),
                          Icons.person_outline_rounded,
                        ),
                      _softInfoChip(
                        safeText(activity["activity_date"]),
                        const Color(0xff64748B),
                        Icons.calendar_today_outlined,
                      ),
                      if (asInt(activity["duration_minutes"]) > 0)
                        _softInfoChip(
                          "${asInt(activity["duration_minutes"])} min",
                          const Color(0xff64748B),
                          Icons.access_time,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (safeText(activity["location"], "").isNotEmpty)
                    _infoPanel(
                      icon: Icons.location_on_outlined,
                      title: "Location",
                      text: safeText(activity["location"]),
                      color: const Color(0xff64748B),
                    ),
                  if (safeText(activity["description"], "").isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoPanel(
                      icon: Icons.notes_rounded,
                      title: "Notes",
                      text: safeText(activity["description"]),
                      color: const Color(0xff64748B),
                    ),
                  ],
                  if (safeText(activity["outcome"], "").isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoPanel(
                      icon: isCancelled
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline_rounded,
                      title: isCancelled ? "Cancellation" : "Outcome",
                      text: safeText(activity["outcome"]),
                      color: isCancelled
                          ? const Color(0xffDC2626)
                          : const Color(0xff059669),
                    ),
                  ],
                  if (safeText(activity["next_action"], "").isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoPanel(
                      icon: Icons.arrow_forward_rounded,
                      title: "Next Action",
                      text:
                      "${safeText(activity["next_action"])}${safeText(activity["next_action_date"], "").isNotEmpty ? " (${safeText(activity["next_action_date"])})" : ""}",
                      color: AppColors.primaryLight,
                    ),
                  ],
                  if (activity["has_travel"] == true) ...[
                    const SizedBox(height: 12),
                    _infoPanel(
                      icon: activity["is_outside_district"] == true
                          ? Icons.flight_takeoff_rounded
                          : Icons.directions_car_rounded,
                      title: "Travel",
                      text:
                      "${safeText(activity["travel_from"], "—")} → ${safeText(activity["travel_to"], "—")}"
                          "${safeText(activity["travel_mode"], "").isNotEmpty ? " · ${safeText(activity["travel_mode"])}" : ""}"
                          "${safeText(activity["travel_request_number"], "").isNotEmpty ? " · ${safeText(activity["travel_request_number"])}" : ""}",
                      color: const Color(0xffEA580C),
                    ),
                  ],
                  if (isOpen) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              openActivityForm(activity, isEdit: true);
                            },
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text("Edit"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              openUpdateActivityLogDialog(activity);
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text("Update Log"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> pickFilterDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
      isFrom ? activityFromDate ?? DateTime.now() : activityToDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      dateView = "custom";
      if (isFrom) {
        activityFromDate = picked;
      } else {
        activityToDate = picked;
      }
    });

    fetchActivities();
  }

  void clearActivityFilters() {
    setState(() {
      activitySearch = "";
      dateView = "today";
      selectedActivityType = null;
      selectedActivityStatus = null;
      selectedActivityCustomerId = null;
      selectedActivityUserId = null;
      activityFromDate = null;
      activityToDate = null;
    });
    fetchActivities();
  }

  Widget _activityCustomerDropdown() {
    return DropdownButtonFormField<int?>(
      value: selectedActivityCustomerId,
      isExpanded: true,
      decoration: _inputDecoration(hint: "All Customers"),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text("All Customers")),
        ...customers.map((c) => DropdownMenuItem<int?>(
          value: c["id"],
          child: Text(
            safeText(c["customer_name"] ?? c["name"]),
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (v) {
        setState(() => selectedActivityCustomerId = v);
        fetchActivities();
      },
    );
  }

  Widget _activityUserDropdown() {
    return DropdownButtonFormField<int?>(
      value: selectedActivityUserId,
      isExpanded: true,
      decoration: _inputDecoration(hint: "All Sales Members"),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text("All Sales Members")),
        ...teamMembers.map((u) => DropdownMenuItem<int?>(
          value: u["id"],
          child: Text(
            safeText(u["full_name"] ?? u["user_name"]),
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (v) {
        setState(() => selectedActivityUserId = v);
        fetchActivities();
      },
    );
  }

  Widget kam360Tab() {
    final filteredCustomers = customerActivities.where((c) {
      final q = kamCustomerSearch.toLowerCase().trim();

      final searchMatch = q.isEmpty ||
          safeText(c["customer_name"], "").toLowerCase().contains(q) ||
          safeText(c["city"], "").toLowerCase().contains(q) ||
          safeText(c["vertical"], "").toLowerCase().contains(q);

      final customerMatch =
          selectedKamCustomerId == null || c["customer_id"] == selectedKamCustomerId;

      return searchMatch && customerMatch;
    }).toList();

    final filteredTeam = teamRows.where((m) {
      final q = advancedMemberSearch.toLowerCase().trim();
      if (q.isEmpty) return true;

      return safeText(m["full_name"] ?? m["user_name"], "")
          .toLowerCase()
          .contains(q) ||
          safeText(m["role"], "").toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: reloadKamAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _kamToolbar(),
          const SizedBox(height: 14),
          if (kamLoading)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (viewMode == "normal") ...[
              _normalSummaryCards(),
              const SizedBox(height: 14),
              _performanceCard(),
              const SizedBox(height: 14),
              _customerActivitySection(filteredCustomers),
            ] else ...[
              _advancedDashboardTop(),
              const SizedBox(height: 14),
              _advancedSectionTabs(),
              const SizedBox(height: 14),

              if (advancedSection == "tree") ...[
                _advancedTeamHierarchy(),
              ] else if (advancedSection == "groupTree") ...[
                _advancedGroupTreeView(),
              ] else if (advancedSection == "comparison") ...[
                _advancedComparisonView(),
              ] else ...[
                _advancedAchievementTable(),
              ],

              const SizedBox(height: 14),
              _customerActivitySection(filteredCustomers),
            ],
          ],
        ],
      ),
    );
  }

  Widget _advancedDashboardTop() {
    final salesTarget = asDouble(summary["sales_target"] ?? performance["sales_target"]);
    final salesDone = asDouble(
      summary["wo_value"] ??
          performance["sales_done"] ??
          performance["won_tender_value"],
    );
    final salesPct = pct(salesDone, salesTarget);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(radius: 24),
          child: Row(
            children: [
              const Icon(Icons.track_changes_rounded, color: Color(0xffEA580C)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sales Revenue Target",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xff0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (salesTarget <= 0) ...[
                      const Text(
                        "No sales target set for this period",
                        style: TextStyle(
                          color: Color(0xff64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      InkWell(
                        onTap: openSetTargetModal,
                        child: const Text(
                          "Set target now →",
                          style: TextStyle(
                            color: Color(0xff4F46E5),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${money(salesDone)} / ${money(salesTarget)}",
                              style: const TextStyle(
                                color: Color(0xff0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _ringPercent(salesPct),
                        ],
                      ),
                      const SizedBox(height: 10),
                      progressBar(salesPct),
                    ],
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: openSetTargetModal,
                icon: const Icon(Icons.settings_rounded, size: 15),
                label: const Text("Manage"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _advancedBigCard(
                title: "Customers",
                value: "${summary["customers"] ?? summary["customer_count"] ?? 0}",
                sub: money(summary["potential_value"]),
                icon: Icons.business_rounded,
                color: const Color(0xff334155),
                onTap: () => openCustomerPanel(title: "Customers"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _advancedBigCard(
                title: "Activities",
                value: "${summary["total_activities"] ?? summary["activity_count"] ?? 0}",
                sub: "${summary["completed_activities"] ?? 0} completed",
                icon: Icons.monitor_heart_rounded,
                color: const Color(0xff2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _advancedBigCard(
                title: "Leads",
                value: "${summary["lead_count"] ?? 0}",
                sub: money(summary["lead_value"]),
                icon: Icons.trending_up_rounded,
                color: const Color(0xff7C3AED),
                onTap: () => openLeadPanel(title: "Leads"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _advancedBigCard(
                title: "Tenders",
                value: "${summary["tender_count"] ?? 0}",
                sub: money(summary["tender_value"]),
                icon: Icons.description_rounded,
                color: const Color(0xffEA580C),
                onTap: () => openTenderPanel(title: "Tenders"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _advancedBigCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(.90), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedSectionTabs() {
    final tabs = [
      ["tree", "Team Hierarchy", Icons.account_tree_rounded],
      ["groupTree", "Group Tree", Icons.device_hub_rounded],
      ["comparison", "Comparison", Icons.bar_chart_rounded],
      ["table", "Achievement Table", Icons.track_changes_rounded],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xffEEF2F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: tabs.map((t) {
            final id = t[0] as String;
            final label = t[1] as String;
            final icon = t[2] as IconData;
            final active = advancedSection == id;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => setState(() => advancedSection = id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: active
                        ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: active ? const Color(0xff0F172A) : const Color(0xff64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: active ? const Color(0xff0F172A) : const Color(0xff64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get syntheticGroups {
    if (masterGroups.isNotEmpty) {
      return masterGroups.map((g) {
        final gid = asInt(g["id"]);
        final members = teamRows.where((m) {
          final raw = safeText(m["group_id"], "");
          final ids = raw.split(",").map((e) => e.trim()).toList();
          return ids.contains("$gid") ||
              asInt(m["group_id"]) == gid ||
              safeText(m["group_name"]) == safeText(g["name"]);
        }).toList();

        return {
          "id": gid,
          "name": safeText(g["name"], "Group $gid"),
          "region": safeText(g["region"], ""),
          "members": members,
        };
      }).where((g) => (g["members"] as List).isNotEmpty).toList();
    }

    final map = <String, List<Map<String, dynamic>>>{};
    for (final m in teamRows) {
      final key = safeText(m["group_name"], "Team");
      map.putIfAbsent(key, () => []).add(m);
    }

    return map.entries.map((e) {
      return {
        "id": e.key.hashCode,
        "name": e.key,
        "region": "",
        "members": e.value,
      };
    }).toList();
  }

  Widget _advancedTeamHierarchy() {
    final groups = syntheticGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_tree_rounded, color: Color(0xff059669), size: 18),
            const SizedBox(width: 8),
            const Text(
              "Team Hierarchy",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xff0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${groups.length} groups",
              style: const TextStyle(
                color: Color(0xff94A3B8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          _emptyCard(
            icon: Icons.groups_rounded,
            title: "No team hierarchy found",
            subtitle: "No group-wise team data available.",
          )
        else
          ...groups.map(_advancedGroupCard),
      ],
    );
  }

  Widget _advancedGroupCard(Map<String, dynamic> group) {
    final members = List<Map<String, dynamic>>.from(group["members"] ?? []);
    final gid = asInt(group["id"]);
    final expanded = expandedGroupId == gid;

    final totalCustomers = members.fold<int>(
      0,
          (s, m) => s + asInt(m["own_customers"] ?? m["customers"] ?? m["customer_count"]),
    );

    final totalActivities = members.fold<int>(
      0,
          (s, m) => s + asInt(m["total_activities"] ?? m["activity_count"]),
    );

    final doneActivities = members.fold<int>(
      0,
          (s, m) => s + asInt(m["completed"] ?? m["completed_activities"]),
    );

    final totalLeads = members.fold<int>(
      0,
          (s, m) => s + asInt(m["lead_count"]),
    );

    final totalTenders = members.fold<int>(
      0,
          (s, m) => s + asInt(m["tender_count"]),
    );

    final color = _groupColor(gid);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(radius: 22),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expandedGroupId = expanded ? null : gid),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: expanded
                    ? const BorderRadius.vertical(top: Radius.circular(22))
                    : BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.device_hub_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                safeText(group["name"]),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _whiteBadge("${members.length} members"),
                            if (safeText(group["region"], "").isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _whiteBadge(safeText(group["region"])),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 9,
                          runSpacing: 4,
                          children: [
                            _groupMiniText("$totalCustomers customers total"),
                            _groupMiniText("$doneActivities/$totalActivities activities"),
                            _groupMiniText("$totalLeads leads"),
                            _groupMiniText("$totalTenders tenders"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _ringPercent(totalActivities == 0
                      ? 0
                      : ((doneActivities / totalActivities) * 100).round()),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Container(
              color:  Color(0xffF8FAFC),
              padding:  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child:  Row(
                children: [
                  Expanded(flex: 3, child: _TableHead("Member")),
                  Expanded(flex: 2, child: _TableHead("Role")),
                  Expanded(flex: 2, child: _TableHead("Customers", center: true)),
                  Expanded(flex: 2, child: _TableHead("Activities", center: true)),
                  Expanded(flex: 2, child: _TableHead("Leads", center: true)),
                  Expanded(flex: 2, child: _TableHead("Tenders", center: true)),
                ],
              ),
            ),
            ...members.map(_advancedHierarchyMemberRow),
          ],
        ],
      ),
    );
  }

  Widget _advancedHierarchyMemberRow(Map<String, dynamic> m) {
    final uid = asInt(m["user_id"] ?? m["id"]);
    final name = safeText(m["full_name"] ?? m["user_name"]);
    final isHead = safeText(m["role"]).toLowerCase().contains("manager");
    final activities = asInt(m["total_activities"] ?? m["activity_count"]);
    final done = asInt(m["completed"] ?? m["completed_activities"]);

    return InkWell(
      onTap: () => setState(() {
        expandedAdvancedMemberId = expandedAdvancedMemberId == uid ? null : uid;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xffEEF2F7))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _avatarBox(name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xff1E293B),
                            ),
                          ),
                        ),
                        if (isHead) ...[
                          const SizedBox(width: 5),
                          _miniBadge("HEAD", const Color(0xff4F46E5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _miniBadge(roleLabel(m["role"]), _roleColor(m["role"])),
              ),
            ),
            Expanded(
              flex: 2,
              child: _tableValue(
                "${m["own_customers"] ?? m["customers"] ?? m["customer_count"] ?? 0} ↗",
                const Color(0xff059669),
              ),
            ),
            Expanded(
              flex: 2,
              child: _tableValue(
                "$done/$activities · ${activities == 0 ? 0 : ((done / activities) * 100).round()}%",
                const Color(0xffEA580C),
              ),
            ),
            Expanded(
              flex: 2,
              child: _tableValue("${m["lead_count"] ?? 0} ↗", const Color(0xff7C3AED)),
            ),
            Expanded(
              flex: 2,
              child: _tableValue("${m["tender_count"] ?? 0} ↗", const Color(0xffEA580C)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advancedGroupTreeView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Organization Chart", Icons.account_tree_rounded),
          const SizedBox(height: 6),
          const Text(
            "Every group is shown as one branch. Members inside the same group stay at the same level.",
            style: TextStyle(
              color: Color(0xff64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...syntheticGroups.map((g) {
            final members = List<Map<String, dynamic>>.from(g["members"] ?? []);
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xffE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeText(g["name"]),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xff0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: members.map((m) {
                      final name = safeText(m["full_name"] ?? m["user_name"]);
                      return Container(
                        width: 155,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xffE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _avatarBox(name),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            _miniBadge(roleLabel(m["role"]), _roleColor(m["role"])),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _advancedComparisonView() {
    final rows = [...teamRows];
    rows.sort((a, b) => asDouble(b["wo_value"] ?? b["won_tender_value"])
        .compareTo(asDouble(a["wo_value"] ?? a["won_tender_value"])));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Member Performance Comparison", Icons.bar_chart_rounded),
          const SizedBox(height: 14),
          ...rows.map((m) {
            final name = safeText(m["full_name"] ?? m["user_name"]);
            final value = asDouble(m["wo_value"] ?? m["won_tender_value"]);
            final maxValue = rows.isEmpty
                ? 1
                : rows.map((e) => asDouble(e["wo_value"] ?? e["won_tender_value"])).reduce(math.max);
            final p = maxValue <= 0 ? 0 : ((value / maxValue) * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  _avatarBox(name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        progressBar(p),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    money(value),
                    style: const TextStyle(
                      color: Color(0xff059669),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _advancedAchievementTable() {
    return Container(
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            child: sectionTitle("Achievement Table", Icons.track_changes_rounded),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xffF8FAFC),
            child:  Row(
              children: [
                Expanded(flex: 3, child: _TableHead("Member")),
                Expanded(flex: 2, child: _TableHead("Activities", center: true)),
                Expanded(flex: 2, child: _TableHead("Leads", center: true)),
                Expanded(flex: 2, child: _TableHead("Tenders", center: true)),
                Expanded(flex: 2, child: _TableHead("Revenue", center: true)),
              ],
            ),
          ),
          ...teamRows.map((m) {
            final name = safeText(m["full_name"] ?? m["user_name"]);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xffEEF2F7))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        _avatarBox(name),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _tableValue(
                      "${m["completed"] ?? m["completed_activities"] ?? 0}/${m["total_activities"] ?? m["activity_count"] ?? 0}",
                      const Color(0xffEA580C),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _tableValue("${m["lead_count"] ?? 0}", const Color(0xff7C3AED)),
                  ),
                  Expanded(
                    flex: 2,
                    child: _tableValue("${m["tender_count"] ?? 0}", const Color(0xffEA580C)),
                  ),
                  Expanded(
                    flex: 2,
                    child: _tableValue(
                      money(m["wo_value"] ?? m["won_tender_value"]),
                      const Color(0xff059669),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _whiteBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _groupMiniText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(.78),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _tableValue(String value, Color color) {
    return Center(
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _groupColor(int id) {
    final colors = [
      const Color(0xff7C3AED),
      const Color(0xff059669),
      const Color(0xffEA580C),
      const Color(0xffDB2777),
      const Color(0xff2563EB),
    ];
    return colors[id.abs() % colors.length];
  }

  Color _roleColor(dynamic role) {
    final r = safeText(role, "").toLowerCase();
    if (r.contains("manager")) return const Color(0xff7C3AED);
    if (r.contains("sales")) return const Color(0xff059669);
    if (r.contains("vp")) return const Color(0xff4F46E5);
    return const Color(0xff64748B);
  }

  Widget _kamToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(radius: 22),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (canSetTarget)
              _topActionChip(
                title: "Set Target",
                icon: Icons.track_changes_rounded,
                selected: false,
                onTap: openSetTargetModal,
              ),
            if (canSetTarget) const SizedBox(width: 8),
            _topActionChip(
              title: "Normal",
              icon: Icons.grid_view_rounded,
              selected: viewMode == "normal",
              onTap: () => setState(() => viewMode = "normal"),
            ),
            const SizedBox(width: 8),
            _topActionChip(
              title: "Advanced",
              icon: Icons.auto_awesome_rounded,
              selected: viewMode == "advanced",
              onTap: () => setState(() => viewMode = "advanced"),
            ),
            const SizedBox(width: 12),
            _smallToggle("Monthly", !isYearly, () {
              setState(() => isYearly = false);
              reloadKamAll();
            }),
            _smallToggle("Yearly", isYearly, () {
              setState(() => isYearly = true);
              reloadKamAll();
            }),
            const SizedBox(width: 8),
            SizedBox(
              width: isYearly ? 84 : 130,
              child: TextFormField(
                key: ValueKey(isYearly ? "year-$selectedYear" : "period-$period"),
                initialValue: isYearly ? selectedYear.toString() : period,
                keyboardType:
                isYearly ? TextInputType.number : TextInputType.datetime,
                decoration: compactInput(isYearly ? "Year" : "YYYY-MM"),
                onFieldSubmitted: (v) {
                  setState(() {
                    if (isYearly) {
                      selectedYear = int.tryParse(v) ?? DateTime.now().year;
                    } else {
                      period = v.trim();
                    }
                  });
                  reloadKamAll();
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<int?>(
                value: selectedKamCustomerId,
                isExpanded: true,
                decoration: compactInput("All Customers"),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text("All Customers"),
                  ),
                  ...customers.map((c) {
                    return DropdownMenuItem<int?>(
                      value: c["id"],
                      child: Text(
                        safeText(c["customer_name"] ?? c["name"]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => selectedKamCustomerId = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<int?>(
                value: selectedKamUserId,
                isExpanded: true,
                decoration: compactInput("All Sales Members"),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text("All Sales Members"),
                  ),
                  ...teamMembers.where((u) => isSalesKAMUser(u["role"])).map((u) {
                    return DropdownMenuItem<int?>(
                      value: u["id"],
                      child: Text(
                        safeText(u["full_name"] ?? u["user_name"]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (v) {
                  setState(() => selectedKamUserId = v);
                  reloadKamAll();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _normalSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.42,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _statCard(
          title: "Customers",
          value: "${summary["customer_count"] ?? summary["customers"] ?? 0}",
          sub: "Assigned / visible",
          icon: Icons.business_rounded,
          color: AppColors.primaryLight,
          onTap: () => openCustomerPanel(title: "Customers"),
        ),
        _statCard(
          title: "Activities",
          value: "${summary["activity_count"] ?? summary["activities"] ?? 0}",
          sub: "KAM activity count",
          icon: Icons.task_alt_rounded,
          color: const Color(0xff7C3AED),
        ),
        _statCard(
          title: "Leads",
          value: "${summary["lead_count"] ?? 0}",
          sub: money(summary["lead_value"]),
          icon: Icons.trending_up_rounded,
          color: const Color(0xff059669),
          onTap: () => openLeadPanel(title: "Leads"),
        ),
        _statCard(
          title: "Tenders / WOs",
          value: "${summary["tender_count"] ?? 0} / ${summary["wo_count"] ?? 0}",
          sub: money(summary["wo_value"]),
          icon: Icons.file_copy_rounded,
          color: const Color(0xffEA580C),
          onTap: () => openTenderPanel(title: "Tenders"),
        ),
      ],
    );
  }

  Widget _performanceCard() {
    final salesTarget = asDouble(performance["sales_target"]);
    final salesDone = asDouble(performance["sales_done"] ??
        performance["won_tender_value"] ??
        summary["wo_value"]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Performance vs Target", Icons.speed_rounded),
          const SizedBox(height: 14),
          progressRow("Calls", performance["calls_done"], performance["calls_target"]),
          progressRow(
              "Meetings", performance["meetings_done"], performance["meetings_target"]),
          progressRow("Demos", performance["demos_done"], performance["demos_target"]),
          progressRow("Site Visits", performance["site_visits_done"],
              performance["site_visits_target"]),
          progressRow("Sales", salesDone, salesTarget, moneyMode: true),
        ],
      ),
    );
  }

  Widget _customerActivitySection(List<Map<String, dynamic>> rows) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: sectionTitle(
                "Customer Activity Breakdown",
                Icons.business_rounded,
              ),
            ),
            _miniBadge("${rows.length}", AppColors.primaryLight),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => kamCustomerSearch = v),
          decoration: inputDecoration(
            hint: "Search customers...",
            icon: Icons.search_rounded,
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _emptyCard(
            icon: Icons.business_rounded,
            title: "No customer activity found",
            subtitle: "Try another period, user or customer filter.",
          )
        else
          ...rows.map(customerActivityCard),
      ],
    );
  }

  Widget customerActivityCard(Map<String, dynamic> c) {
    final customerId = c["customer_id"] ?? c["id"];
    final total = asInt(c["total_activities"] ?? c["activity_count"]);
    final completed = asInt(c["completed"] ?? c["completed_activity_count"]);
    final completion = total > 0 ? ((completed / total) * 100).round() : 0;
    final expanded = expandedCustomerId == customerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardDecoration(radius: 22),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                expandedCustomerId = expanded ? null : asInt(customerId);
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _avatarBox(safeText(c["customer_name"], "?")),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              safeText(c["customer_name"]),
                              style: const TextStyle(
                                color: Color(0xff0F172A),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (safeText(c["city"], "").isNotEmpty ||
                                safeText(c["vertical"], "").isNotEmpty)
                              Text(
                                [
                                  safeText(c["city"], ""),
                                  safeText(c["vertical"], "")
                                ].where((e) => e.isNotEmpty).join(" · "),
                                style: const TextStyle(
                                  color: Color(0xff64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _ringPercent(completion),
                    ],
                  ),
                  const SizedBox(height: 12),
                  progressBar(completion),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniBadge("Activities $total", AppColors.primaryLight),
                      _miniBadge("Done $completed", const Color(0xff059669)),
                      _miniBadge("Calls ${c["calls_done"] ?? c["calls"] ?? 0}",
                          const Color(0xff2563EB)),
                      _miniBadge(
                          "Meetings ${c["meetings_done"] ?? c["meetings"] ?? 0}",
                          const Color(0xff7C3AED)),
                      InkWell(
                        onTap: asInt(c["lead_count"]) > 0
                            ? () => openLeadPanel(
                          customerId: asInt(customerId),
                          title: "Leads - ${safeText(c["customer_name"])}",
                        )
                            : null,
                        child: _miniBadge(
                          "Leads ${c["lead_count"] ?? 0}",
                          const Color(0xff9333EA),
                        ),
                      ),
                      InkWell(
                        onTap: asInt(c["tender_count"]) > 0
                            ? () => openTenderPanel(
                          customerId: asInt(customerId),
                          title: "Tenders - ${safeText(c["customer_name"])}",
                        )
                            : null,
                        child: _miniBadge(
                          "Tenders ${c["tender_count"] ?? 0}",
                          const Color(0xffEA580C),
                        ),
                      ),
                      _miniBadge("WO ${money(c["wo_value"])}",
                          const Color(0xff059669)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(),
                  _detailMetricGrid([
                    _MiniMetric("Lead Pipeline", money(c["lead_value"]),
                        "${c["lead_count"] ?? 0} leads", const Color(0xff9333EA)),
                    _MiniMetric("Tender Value", money(c["tender_value"]),
                        "${c["tender_count"] ?? 0} tenders", const Color(0xffEA580C)),
                    _MiniMetric("Revenue Booked", money(c["wo_value"]),
                        "${c["wo_count"] ?? 0} WOs", const Color(0xff059669)),
                    _MiniMetric("Received", money(c["payment_received"]),
                        "Payment", const Color(0xffD97706)),
                  ]),
                  if (safeText(c["last_activity_date"], "").isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _infoPanel(
                      icon: Icons.history_rounded,
                      title: "Last Activity",
                      text:
                      "${safeText(c["last_activity_date"])}${safeText(c["last_activity_type"], "").isNotEmpty ? " · ${safeText(c["last_activity_type"])}" : ""}",
                      color: const Color(0xff64748B),
                    ),
                  ],
                  if (safeText(c["last_outcome"], "").isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _infoPanel(
                      icon: Icons.check_circle_outline_rounded,
                      title: "Last Outcome",
                      text: safeText(c["last_outcome"]),
                      color: const Color(0xff059669),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedActivityCustomerId = asInt(customerId);
                        tabController.index = 0;
                      });
                      fetchActivities();
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text("View activities for ${safeText(c["customer_name"])}"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _advancedHero() {
    final salesDone = asDouble(performance["sales_done"] ??
        performance["won_tender_value"] ??
        summary["wo_value"]);
    final salesTarget = asDouble(performance["sales_target"]);
    final salesPct = pct(salesDone, salesTarget);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                "Advanced KAM Intelligence",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _advancedHeroMetric(
                  "Sales Achievement",
                  "$salesPct%",
                  "${money(salesDone)} / ${money(salesTarget)}",
                  Icons.track_changes_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _advancedHeroMetric(
                  "Pipeline",
                  money(summary["lead_value"]),
                  "${summary["lead_count"] ?? 0} leads",
                  Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _advancedHeroMetric(
                  "Tenders",
                  "${summary["tender_count"] ?? 0}",
                  money(summary["tender_value"]),
                  Icons.description_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _advancedHeroMetric(
                  "Work Orders",
                  "${summary["wo_count"] ?? 0}",
                  money(summary["wo_value"]),
                  Icons.inventory_2_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _advancedHeroMetric(
      String title,
      String value,
      String sub,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(.82),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withOpacity(.62),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _advancedTeamSearch() {
    return TextField(
      onChanged: (v) => setState(() => advancedMemberSearch = v),
      decoration: inputDecoration(
        hint: "Search team member...",
        icon: Icons.search_rounded,
      ),
    );
  }

  Widget _advancedTeam360(List<Map<String, dynamic>> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Hierarchy Performance", Icons.account_tree_rounded),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _emptyInline("No team performance found")
          else
            ...rows.map(_advancedMemberCard),
        ],
      ),
    );
  }

  Widget _advancedMemberCard(Map<String, dynamic> m) {
    final uid = asInt(m["user_id"] ?? m["id"]);
    final expanded = expandedMemberId == uid;

    final name = safeText(m["full_name"] ?? m["user_name"]);
    final salesDone = asDouble(m["sales_done"] ?? m["won_value"] ?? m["wo_value"]);
    final salesTarget = asDouble(m["sales_target"]);
    final salesPct = pct(salesDone, salesTarget);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                expandedMemberId = expanded ? null : uid;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  _avatarBox(name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xff0F172A))),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          children: [
                            _miniBadge(roleLabel(m["role"]), const Color(0xff7C3AED)),
                            _miniBadge(
                                "${m["activity_count"] ?? m["total_activities"] ?? 0} acts",
                                AppColors.primaryLight),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _ringPercent(salesPct),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Column(
                children: [
                  const Divider(),
                  _detailMetricGrid([
                    _MiniMetric("Sales", money(salesDone),
                        "Target ${money(salesTarget)}", const Color(0xff059669)),
                    _MiniMetric("Leads", "${m["lead_count"] ?? 0}",
                        money(m["lead_value"]), const Color(0xff9333EA)),
                    _MiniMetric("Tenders", "${m["tender_count"] ?? 0}",
                        money(m["tender_value"]), const Color(0xffEA580C)),
                    _MiniMetric("Customers", "${m["customer_count"] ?? 0}",
                        "Assigned", AppColors.primaryLight),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => openLeadPanel(
                            userId: uid,
                            title: "Leads - $name",
                          ),
                          icon: const Icon(Icons.trending_up_rounded, size: 16),
                          label: const Text("Leads"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => openTenderPanel(
                            userId: uid,
                            title: "Tenders - $name",
                          ),
                          icon: const Icon(Icons.description_rounded, size: 16),
                          label: const Text("Tenders"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => openCustomerPanel(
                      userId: uid,
                      title: "Customers - $name",
                    ),
                    icon: const Icon(Icons.business_rounded, size: 16),
                    label: const Text("Customers"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _advancedCustomerSignals(List<Map<String, dynamic>> rows) {
    final hotCustomers = [...rows]
      ..sort((a, b) =>
          asDouble(b["lead_value"] ?? b["tender_value"] ?? b["wo_value"])
              .compareTo(asDouble(a["lead_value"] ?? a["tender_value"] ?? a["wo_value"])));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Customer Signals", Icons.radar_rounded),
          const SizedBox(height: 12),
          if (hotCustomers.isEmpty)
            _emptyInline("No customer signals")
          else
            ...hotCustomers.take(8).map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: Row(
                  children: [
                    _avatarBox(safeText(c["customer_name"])),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            safeText(c["customer_name"]),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xff0F172A),
                            ),
                          ),
                          Text(
                            "Leads ${c["lead_count"] ?? 0} · Tenders ${c["tender_count"] ?? 0} · Acts ${c["total_activities"] ?? c["activity_count"] ?? 0}",
                            style: const TextStyle(
                              color: Color(0xff64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(asDouble(c["lead_value"]) +
                          asDouble(c["tender_value"]) +
                          asDouble(c["wo_value"])),
                      style: const TextStyle(
                        color: Color(0xff059669),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
  void openUpdateActivityLogDialog(Map<String, dynamic> activity) {
    openActivityForm(activity, isEdit: false, isLogUpdate: true);
  }

  void openActivityForm(
      Map<String, dynamic> activity, {
        required bool isEdit,
        bool isLogUpdate = false,
      }) {
    final formKey = GlobalKey<FormState>();

    String activityType = activityTypeName(activity);
    String status =
    isLogUpdate ? "Completed" : safeText(activity["status"], "Planned");

    int? customerId = activity["customer_id"];
    String? travelMode = activity["travel_mode"]?.toString();
    String? followCategory = activity["followup_category"]?.toString();
    String? followSubType = activity["followup_sub_type"]?.toString();
    String? cancellationReason = activity["cancellation_reason"]?.toString();

    bool hasTravel = activity["has_travel"] == true;
    bool outsideDistrict = activity["is_outside_district"] == true;

    final subject = TextEditingController(text: safeText(activity["subject"], ""));
    final date = TextEditingController(
      text: safeText(activity["activity_date"], dateText(DateTime.now())),
    );
    final startTime = TextEditingController(text: safeText(activity["start_time"], ""));
    final duration = TextEditingController(
      text: activity["duration_minutes"] == null ? "" : "${activity["duration_minutes"]}",
    );
    final location = TextEditingController(text: safeText(activity["location"], ""));
    final outcome = TextEditingController(text: safeText(activity["outcome"], ""));
    final nextAction = TextEditingController(text: safeText(activity["next_action"], ""));
    final nextActionDate =
    TextEditingController(text: safeText(activity["next_action_date"], ""));
    final notes = TextEditingController(text: safeText(activity["description"], ""));
    final travelFrom = TextEditingController(text: safeText(activity["travel_from"], ""));
    final travelTo = TextEditingController(text: safeText(activity["travel_to"], ""));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        bool localSaving = false;

        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> pickDate(TextEditingController c) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(c.text) ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                c.text = dateText(picked);
                setSheet(() {});
              }
            }

            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;

              if (status == "Completed" && outcome.text.trim().isEmpty) {
                showError("Outcome required");
                return;
              }

              if (status == "Cancelled" &&
                  (cancellationReason == null || cancellationReason!.isEmpty) &&
                  outcome.text.trim().isEmpty) {
                showError("Cancellation reason required");
                return;
              }

              setSheet(() => localSaving = true);

              final body = {
                "activity_type": activityType,
                "mode": modeForActivityType(activityType),
                "customer_id": customerId,
                "subject": subject.text.trim(),
                "description": notes.text.trim(),
                "activity_date": date.text.trim(),
                "start_time": startTime.text.trim().isEmpty ? null : startTime.text.trim(),
                "duration_minutes": int.tryParse(duration.text.trim()),
                "location": location.text.trim(),
                "status": status,
                "outcome": outcome.text.trim(),
                "next_action": nextAction.text.trim(),
                "next_action_date":
                nextActionDate.text.trim().isEmpty ? null : nextActionDate.text.trim(),
                "followup_category": followCategory,
                "followup_sub_type": followSubType,
                "cancellation_reason": cancellationReason,
                "has_travel": hasTravel,
                "travel_mode": travelMode,
                "travel_from": travelFrom.text.trim(),
                "travel_to": travelTo.text.trim(),
                "is_outside_district": outsideDistrict,
              };

              try {
                await putApi("/kam/activities/${activity["id"]}", body);
                if (!mounted) return;
                Navigator.pop(context);
                showSuccess("Activity saved");
                await Future.wait([fetchActivities(), reloadKamAll()]);
              } catch (e) {
                setSheet(() => localSaving = false);
                showError(e.toString());
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: .92,
              minChildSize: .55,
              maxChildSize: .96,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xffF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      _sheetHeader(
                        title: isLogUpdate ? "Update Activity Log" : "Edit Activity",
                        subtitle: subject.text.isEmpty ? "KAM activity details" : subject.text,
                        icon: isLogUpdate ? Icons.edit_note_rounded : Icons.edit_rounded,
                        onClose: localSaving ? null : () => Navigator.pop(context),
                      ),
                      if (isLogUpdate)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          color: Colors.white,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 9),
                                child: Text(
                                  "Mark as:",
                                  style: TextStyle(
                                    color: Color(0xff64748B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              ...["Completed", "In Progress", "Postponed", "Cancelled"].map((s) {
                                final active = status == s;
                                final c = statusColor(s);
                                return ChoiceChip(
                                  selected: active,
                                  label: Text(s),
                                  selectedColor: c,
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    color: active ? Colors.white : c,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  side: BorderSide(
                                    color: active ? c : const Color(0xffCBD5E1),
                                  ),
                                  onSelected: (_) => setSheet(() => status = s),
                                );
                              }),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Form(
                          key: formKey,
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              _formSection(
                                title: "Activity Type",
                                child: isLogUpdate
                                    ? Row(
                                  children: [
                                    typeBox(activityType),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "$activityType  •  Activity type locked",
                                        style: const TextStyle(
                                          color: Color(0xff64748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                    : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: activityTypes.map((t) {
                                    final active = activityType == t;
                                    final c = typeColor(t);
                                    return ChoiceChip(
                                      selected: active,
                                      avatar: Icon(
                                        typeIcon(t),
                                        size: 15,
                                        color: active ? Colors.white : c,
                                      ),
                                      label: Text(t),
                                      selectedColor: c,
                                      backgroundColor: c.withOpacity(.08),
                                      labelStyle: TextStyle(
                                        color: active ? Colors.white : c,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                      onSelected: (_) =>
                                          setSheet(() => activityType = t),
                                    );
                                  }).toList(),
                                ),
                              ),
                              _formSection(
                                title: "Details",
                                child: Column(
                                  children: [
                                    _dialogTextField(
                                      label: "Subject / Purpose",
                                      controller: subject,
                                      requiredField: true,
                                    ),
                                    const SizedBox(height: 12),
                                    _customerDropdown(
                                      customerId,
                                          (v) => setSheet(() => customerId = v),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _dialogTextField(
                                            label: "Activity Date",
                                            controller: date,
                                            readOnly: true,
                                            suffixIcon: Icons.calendar_today_outlined,
                                            onTap: () => pickDate(date),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _dialogTextField(
                                            label: "Start Time",
                                            controller: startTime,
                                            suffixIcon: Icons.access_time,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _dialogTextField(
                                            label: "Duration (min)",
                                            controller: duration,
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                        if (!isLogUpdate) ...[
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _statusDropdown(
                                              status,
                                                  (v) => setSheet(() => status = v ?? status),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (isTravelActivityType(activityType)) ...[
                                      const SizedBox(height: 12),
                                      _dialogTextField(
                                        label: "Location",
                                        controller: location,
                                        suffixIcon: Icons.location_on_outlined,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (activityType == "Follow Up")
                                _formSection(
                                  title: "Follow-up Classification",
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: followupCategories.keys.map((cat) {
                                          final active = followCategory == cat;
                                          return ChoiceChip(
                                            selected: active,
                                            label: Text(cat),
                                            selectedColor: const Color(0xffD97706),
                                            backgroundColor: const Color(0xffFFFBEB),
                                            labelStyle: TextStyle(
                                              color: active
                                                  ? Colors.white
                                                  : const Color(0xffD97706),
                                              fontWeight: FontWeight.w800,
                                            ),
                                            onSelected: (_) => setSheet(() {
                                              followCategory = cat;
                                              followSubType = null;
                                            }),
                                          );
                                        }).toList(),
                                      ),
                                      if (followCategory != null) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children:
                                          (followupCategories[followCategory] ?? []).map((sub) {
                                            final active = followSubType == sub;
                                            return ChoiceChip(
                                              selected: active,
                                              label: Text(sub),
                                              selectedColor: AppColors.primaryLight,
                                              backgroundColor: const Color(0xffEFF6FF),
                                              labelStyle: TextStyle(
                                                color:
                                                active ? Colors.white : AppColors.primaryLight,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              onSelected: (_) =>
                                                  setSheet(() => followSubType = sub),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              _formSection(
                                title: "Travel & TA/DA",
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      value: hasTravel,
                                      activeColor: AppColors.primaryLight,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        "This activity involves travel",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xff0F172A),
                                        ),
                                      ),
                                      subtitle: const Text("Enable to update travel details"),
                                      onChanged: (v) => setSheet(() => hasTravel = v),
                                    ),
                                    if (hasTravel) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _dialogTextField(
                                              label: "From City",
                                              controller: travelFrom,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _dialogTextField(
                                              label: "To City",
                                              controller: travelTo,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _travelModeDropdown(
                                        travelMode,
                                            (v) => setSheet(() => travelMode = v),
                                      ),
                                      CheckboxListTile(
                                        value: outsideDistrict,
                                        activeColor: const Color(0xffEA580C),
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text(
                                          "Outside district / city",
                                          style: TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        subtitle: const Text("Travel approval may be applicable"),
                                        onChanged: (v) =>
                                            setSheet(() => outsideDistrict = v ?? false),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              _formSection(
                                title: "Outcome & Next Action",
                                child: Column(
                                  children: [
                                    if (status == "Cancelled") ...[
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: cancellationReasons.map((r) {
                                            final active = cancellationReason == r;
                                            return ChoiceChip(
                                              selected: active,
                                              label: Text(r),
                                              selectedColor: const Color(0xffDC2626),
                                              backgroundColor: const Color(0xffFEF2F2),
                                              labelStyle: TextStyle(
                                                color: active
                                                    ? Colors.white
                                                    : const Color(0xffDC2626),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 11,
                                              ),
                                              onSelected: (_) =>
                                                  setSheet(() => cancellationReason = r),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    _dialogTextArea(
                                      label: status == "Cancelled"
                                          ? "Cancellation Notes / Outcome"
                                          : "Outcome",
                                      controller: outcome,
                                      requiredField: status == "Completed",
                                    ),
                                    const SizedBox(height: 12),
                                    _dialogTextField(
                                      label: "Next Action",
                                      controller: nextAction,
                                      suffixIcon: Icons.arrow_forward_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    _dialogTextField(
                                      label: "Next Action Date",
                                      controller: nextActionDate,
                                      readOnly: true,
                                      suffixIcon: Icons.calendar_month_rounded,
                                      onTap: () => pickDate(nextActionDate),
                                    ),
                                    const SizedBox(height: 12),
                                    _dialogTextArea(
                                      label: "Internal Notes",
                                      controller: notes,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _sheetFooter(
                        loading: localSaving,
                        positiveText: isLogUpdate ? "Save Log" : "Save",
                        color: statusColor(status),
                        onCancel: () => Navigator.pop(context),
                        onSave: save,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void openSetTargetModal() {
    final assignable = teamMembers.where((u) => isSalesKAMUser(u["role"])).toList();

    int? userId;
    String year = selectedYear.toString();
    String mode = "add";
    double currentTarget = 0;
    bool loadingCurrent = false;
    bool localSaving = false;
    final amount = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            Future<void> loadCurrent() async {
              if (userId == null || year.length != 4) return;
              setDialog(() {
                loadingCurrent = true;
                currentTarget = 0;
              });
              final value = await fetchCurrentSalesTarget(
                userId: userId!,
                targetPeriod: year,
              );
              setDialog(() {
                currentTarget = value;
                loadingCurrent = false;
              });
            }

            Future<void> saveTarget() async {
              if (userId == null) {
                showError("Select team member");
                return;
              }

              final entered = asDouble(amount.text.replaceAll(",", ""));
              if (entered <= 0) {
                showError("Enter valid target amount");
                return;
              }

              final finalTarget = mode == "add" ? currentTarget + entered : entered;

              setDialog(() => localSaving = true);

              try {
                await postApi("/kam/targets", {
                  "user_id": userId,
                  "period": year,
                  "calls_target": 0,
                  "meetings_target": 0,
                  "leads_target": 0,
                  "revenue_target": 0,
                  "demos_target": 0,
                  "site_visits_target": 0,
                  "sales_target": finalTarget,
                });

                if (!mounted) return;
                Navigator.pop(context);

                setState(() {
                  isYearly = true;
                  selectedYear = int.tryParse(year) ?? selectedYear;
                });

                showSuccess("Target set successfully");
                reloadKamAll();
              } catch (e) {
                setDialog(() => localSaving = false);
                showError(e.toString());
              }
            }

            final entered = asDouble(amount.text.replaceAll(",", ""));
            final finalTarget = mode == "add" ? currentTarget + entered : entered;

            return Dialog(
              insetPadding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 430),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xffEEF2FF),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xffC7D2FE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.track_changes_rounded,
                              color: Color(0xff4F46E5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Set Sales Target",
                                  style: TextStyle(
                                    color: Color(0xff0F172A),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Assign yearly sales target",
                                  style: TextStyle(
                                    color: Color(0xff64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: localSaving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          DropdownButtonFormField<int>(
                            value: userId,
                            isExpanded: true,
                            decoration: _inputDecoration(hint: "Team Member *"),
                            items: assignable.map((u) {
                              return DropdownMenuItem<int>(
                                value: u["id"],
                                child: Text(
                                  "${safeText(u["full_name"] ?? u["user_name"])}${u["is_self"] == true ? " (You)" : ""}",
                                ),
                              );
                            }).toList(),
                            onChanged: (v) async {
                              setDialog(() => userId = v);
                              await loadCurrent();
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: year,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: _inputDecoration(hint: "Year").copyWith(
                              counterText: "",
                            ),
                            onChanged: (v) async {
                              year = v;
                              if (v.length == 4) await loadCurrent();
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _targetModeBtn(
                                  title: "+ Add to Target",
                                  active: mode == "add",
                                  onTap: () => setDialog(() => mode = "add"),
                                ),
                              ),
                              Expanded(
                                child: _targetModeBtn(
                                  title: "Replace Target",
                                  active: mode == "replace",
                                  onTap: () => setDialog(() => mode = "replace"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xffEEF2FF), Color(0xffF5F3FF)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Color(0xffC7D2FE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mode == "add" ? "Amount to Add" : "New Target Amount",
                                  style: const TextStyle(
                                    color: Color(0xff4F46E5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (mode == "add" && userId != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Current target",
                                        style: TextStyle(
                                          color: Color(0xff64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        loadingCurrent ? "..." : money(currentTarget),
                                        style: const TextStyle(
                                          color: Color(0xff0F172A),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                TextField(
                                  controller: amount,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    hint: "e.g. 1,00,00,000 for 1 Cr",
                                  ).copyWith(prefixText: "₹ "),
                                  onChanged: (_) => setDialog(() {}),
                                ),
                                if (entered > 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff4F46E5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      mode == "add"
                                          ? "Total Target  ${money(finalTarget)}"
                                          : "${money(finalTarget)} will replace current target",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: localSaving ? null : () => Navigator.pop(context),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: localSaving ? null : saveTarget,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff4F46E5),
                                foregroundColor: Colors.white,
                              ),
                              child: localSaving
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Text("Set Target"),
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
      },
    );
  }

  Widget _targetModeBtn({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xff4F46E5) : Colors.white,
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xff64748B),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  void showLeadPanel() {
    _showListPanel(
      title: panelTitle,
      icon: Icons.trending_up_rounded,
      count: panelLeads.length,
      child: panelLoading
          ? const Center(child: CircularProgressIndicator())
          : panelLeads.isEmpty
          ? _emptyInline("No leads found")
          : Column(
        children: panelLeads.map((l) {
          return _panelTile(
            title: safeText(l["lead_title"] ?? l["title"] ?? l["subject"]),
            subtitle:
            "${safeText(l["customer_name"], "No customer")} · ${safeText(l["status"], "Open")}",
            amount: money(l["est_value"] ?? l["value"]),
            icon: Icons.trending_up_rounded,
            color: const Color(0xff9333EA),
          );
        }).toList(),
      ),
    );
  }

  void showTenderPanel() {
    _showListPanel(
      title: panelTitle,
      icon: Icons.description_rounded,
      count: panelTenders.length,
      child: panelLoading
          ? const Center(child: CircularProgressIndicator())
          : panelTenders.isEmpty
          ? _emptyInline("No tenders found")
          : Column(
        children: panelTenders.map((t) {
          return _panelTile(
            title: safeText(t["tender_title"] ?? t["title"] ?? t["subject"]),
            subtitle:
            "${safeText(t["customer_name"], "No customer")} · ${safeText(t["result"], "Open")}",
            amount: money(t["est_value"] ?? t["bid_amount"]),
            icon: Icons.description_rounded,
            color: const Color(0xffEA580C),
          );
        }).toList(),
      ),
    );
  }

  void showCustomerPanel() {
    _showListPanel(
      title: panelTitle,
      icon: Icons.business_rounded,
      count: panelCustomers.length,
      child: panelLoading
          ? const Center(child: CircularProgressIndicator())
          : panelCustomers.isEmpty
          ? _emptyInline("No customers found")
          : Column(
        children: panelCustomers.map((c) {
          return _panelTile(
            title: safeText(c["customer_name"] ?? c["name"]),
            subtitle: [
              safeText(c["city"], ""),
              safeText(c["vertical"], ""),
            ].where((e) => e.isNotEmpty).join(" · "),
            amount: money(c["potential_value"]),
            icon: Icons.business_rounded,
            color: AppColors.primaryLight,
          );
        }).toList(),
      ),
    );
  }

  void _showListPanel({
    required String title,
    required IconData icon,
    required int count,
    required Widget child,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: .82,
          minChildSize: .45,
          maxChildSize: .94,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xffF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  _sheetHeader(
                    title: title,
                    subtitle: "$count records",
                    icon: icon,
                    onClose: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      child: child,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _panelTile({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(radius: 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _sheetHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onClose,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetFooter({
    required bool loading,
    required String positiveText,
    required Color color,
    required VoidCallback onCancel,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : onCancel,
                child: const Text("Cancel"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: loading ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                child: loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(positiveText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xff0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                color: Color(0xff64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget progressRow(
      String label,
      dynamic value,
      dynamic target, {
        bool moneyMode = false,
      }) {
    final p = pct(value, target);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                moneyMode
                    ? "${money(value)} / ${money(target)}"
                    : "${value ?? 0} / ${target ?? 0}",
                style: const TextStyle(
                  color: Color(0xff64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          progressBar(p),
        ],
      ),
    );
  }

  Widget progressBar(int value) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: (value / 100).clamp(0, 1),
        minHeight: 8,
        backgroundColor: const Color(0xffE2E8F0),
        color: value >= 80
            ? const Color(0xff059669)
            : value >= 50
            ? AppColors.primaryLight
            : const Color(0xffEA580C),
      ),
    );
  }

  Widget sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _detailMetricGrid(List<_MiniMetric> items) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.65,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: items.map((m) {
        return Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: m.color.withOpacity(.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: m.color.withOpacity(.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.value,
                style: TextStyle(
                  color: m.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                m.label,
                style: const TextStyle(
                  color: Color(0xff0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              Text(
                m.sub,
                style: const TextStyle(
                  color: Color(0xff64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _ringPercent(int value) {
    final color = value >= 80
        ? const Color(0xff059669)
        : value >= 50
        ? AppColors.primaryLight
        : const Color(0xffEA580C);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(.25), width: 4),
      ),
      child: Center(
        child: Text(
          "$value%",
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _avatarBox(String name) {
    final text = name.trim().isEmpty ? "?" : name.trim();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(
          text.substring(0, math.min(2, text.length)).toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget typeBox(String type, {double size = 44}) {
    final color = typeColor(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(typeIcon(type), color: color, size: size * .5),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    return _miniBadge(status, statusColor(status));
  }

  Widget _softInfoChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfo({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPanel({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "$title: $text",
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xff64748B)),
          ),
        ],
      ),
    );
  }

  Widget _emptyInline(String text) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xff64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  BoxDecoration cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xffE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  Widget _segmentedButton({
    required String label,
    required bool active,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryLight : const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active ? AppColors.primaryLight : const Color(0xffE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : AppColors.primaryLight),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topActionChip({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffEEF2FF) : const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xffC7D2FE) : const Color(0xffE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? const Color(0xff4F46E5) : const Color(0xff64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: selected ? const Color(0xff4F46E5) : const Color(0xff64748B),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallToggle(String title, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: active ? const Color(0xff0F172A) : const Color(0xff64748B),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration compactInput(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
    );
  }

  InputDecoration inputDecoration({required String hint, IconData? icon}) {
    return _inputDecoration(hint: hint).copyWith(
      prefixIcon: icon == null ? null : Icon(icon),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xffF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T?>(
      value: value,
      isExpanded: true,
      decoration: _inputDecoration(hint: hint),
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(hint)),
        ...items.map((e) {
          return DropdownMenuItem<T?>(
            value: e,
            child: Text(e.toString(), overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Widget _dateFilterBox({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                size: 17, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formSection({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _dialogTextField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onTap,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      validator: requiredField
          ? (v) => v == null || v.trim().isEmpty ? "$label required" : null
          : null,
      decoration: _inputDecoration(hint: label).copyWith(
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon),
      ),
    );
  }

  Widget _dialogTextArea({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      validator: requiredField
          ? (v) => v == null || v.trim().isEmpty ? "$label required" : null
          : null,
      decoration: _inputDecoration(hint: label),
    );
  }

  Widget _customerDropdown(int? value, Function(int?) onChanged) {
    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      decoration: _inputDecoration(hint: "Customer"),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text("Select Customer")),
        ...customers.map((c) {
          return DropdownMenuItem<int?>(
            value: c["id"],
            child: Text(
              safeText(c["customer_name"] ?? c["name"]),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Widget _statusDropdown(String value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(hint: "Status"),
      items: activityStatuses
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _travelModeDropdown(String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: _inputDecoration(hint: "Travel Mode"),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text("Travel Mode")),
        ...travelModes.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
      ],
      onChanged: onChanged,
    );
  }
}

class _MiniMetric {
  final String label;
  final String value;
  final String sub;
  final Color color;

  _MiniMetric(this.label, this.value, this.sub, this.color);
}

