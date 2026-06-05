import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_helpers/api_method.dart';
import '../../api_helpers/api_urls.dart';
import 'approval_detail_page.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF3060A0);

  static const Color bg = Color(0xffF4F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0xffE2E8F0);
  static const Color textDark = Color(0xff0F172A);
  static const Color textSoft = Color(0xff64748B);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
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

String safeText(dynamic value, [String fallback = "-"]) {
  final text = value?.toString().trim() ?? "";
  return text.isEmpty ? fallback : text;
}

String fmtDate(dynamic value) {
  final text = safeText(value, "");
  if (text.isEmpty) return "-";
  try {
    final dt = DateTime.parse(text);
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  } catch (_) {
    return text.contains("T") ? text.split("T").first : text.split(" ").first;
  }
}

String money(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return "-";
  final n = num.tryParse(value.toString());
  if (n == null) return value.toString();
  return "₹${n.toStringAsFixed(0)}";
}

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  bool loadingPending = true;
  bool loadingHistory = true;
  bool refreshing = false;

  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> history = [];

  String token = "";
  String tenantSlug = "";

  String get  apiBase => "${ApiUrls.baseUrl}/api/v1";

  Map<String, String> get headers => {
    "Authorization": "Bearer $token",
    "Accept": "application/json",
    "Content-Type": "application/json",
    "X-Tenant-Slug": tenantSlug,
  };

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadToken();
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("auth_token") ?? "";
    tenantSlug = prefs.getString("tenant_slug") ?? "";

    if (token.isEmpty) {
      showError("Token not found");
      if (mounted) {
        setState(() {
          loadingPending = false;
          loadingHistory = false;
        });
      }
      return;
    }

    await Future.wait([
      loadPending(),
      loadHistory(),
    ]);
  }

  Future<void> loadPending({bool silent = false}) async {
    if (mounted && !silent) setState(() => loadingPending = true);
    if (mounted && silent) setState(() => refreshing = true);

    try {
      final results = await Future.wait([
        ApiMethod.getRequest(
          url: "$apiBase/approvals/pending",
          headers: headers,
        ),
        ApiMethod.getRequest(
          url: "$apiBase/approval-workflows/requests/pending",
          headers: headers,
        ),
      ]);

      final legacyRes = results[0];
      final dynamicRes = results[1];

      List<Map<String, dynamic>> legacyItems = [];
      List<Map<String, dynamic>> dynamicItems = [];

      if (legacyRes['statusCode'] == 200) {
        final data = legacyRes['data'];
        legacyItems = data is Map && data["items"] is List
            ? List<Map<String, dynamic>>.from(data["items"])
            : data is List
            ? List<Map<String, dynamic>>.from(data)
            : [];
        legacyItems = legacyItems.map((e) => {...e, "kind": "legacy"}).toList();
      }

      if (dynamicRes['statusCode'] == 200) {
        final data = dynamicRes['data'];
        dynamicItems = data is Map && data["items"] is List
            ? List<Map<String, dynamic>>.from(data["items"])
            : data is List
            ? List<Map<String, dynamic>>.from(data)
            : [];
        dynamicItems = dynamicItems.map((e) => {...e, "kind": "dynamic"}).toList();
      }

      final rows = [...legacyItems, ...dynamicItems];

      rows.sort((a, b) {
        final da = DateTime.tryParse(safeText(a["created_at"], "")) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(safeText(b["created_at"], "")) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      if (mounted) setState(() => pending = rows);

      debugPrint("LEGACY PENDING: ${legacyRes['statusCode']} ${legacyRes['data']}");
      debugPrint("DYNAMIC PENDING: ${dynamicRes['statusCode']} ${dynamicRes['data']}");
    } catch (e) {
      showError("Pending approvals error: $e");
    }

    if (mounted) {
      setState(() {
        loadingPending = false;
        refreshing = false;
      });
    }
  }

  Future<void> loadHistory() async {
    if (mounted) setState(() => loadingHistory = true);

    try {
      final results = await Future.wait([
        ApiMethod.getRequest(
          url: "$apiBase/approvals/history?page=1&per_page=50",
          headers: headers,
        ),
        ApiMethod.getRequest(
          url: "$apiBase/approval-workflows/requests/history?page=1&per_page=50",
          headers: headers,
        ),
      ]);

      final legacyRes = results[0];
      final dynamicRes = results[1];

      List<Map<String, dynamic>> legacyItems = [];
      List<Map<String, dynamic>> dynamicItems = [];

      if (legacyRes['statusCode'] == 200) {
        final data = legacyRes['data'];

        legacyItems = data is Map && data["items"] is List
            ? List<Map<String, dynamic>>.from(data["items"])
            : data is List
            ? List<Map<String, dynamic>>.from(data)
            : <Map<String, dynamic>>[];

        legacyItems = legacyItems
            .map((item) => {
          ...item,
          "kind": "legacy",
        })
            .toList();
      }

      if (dynamicRes['statusCode'] == 200) {
        final data = dynamicRes['data'];

        dynamicItems = data is Map && data["items"] is List
            ? List<Map<String, dynamic>>.from(data["items"])
            : data is List
            ? List<Map<String, dynamic>>.from(data)
            : <Map<String, dynamic>>[];

        dynamicItems = dynamicItems
            .map((item) => {
          ...item,
          "kind": "dynamic",
        })
            .toList();
      }

      if (legacyRes['statusCode'] != 200 && dynamicRes['statusCode'] != 200) {
        showError("Failed to load approval history");
      }

      final rows = [...legacyItems, ...dynamicItems];

      rows.sort((a, b) {
        final da = DateTime.tryParse(
          safeText(a["decided_at"] ?? a["updated_at"] ?? a["created_at"], ""),
        ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final db = DateTime.tryParse(
          safeText(b["decided_at"] ?? b["updated_at"] ?? b["created_at"], ""),
        ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return db.compareTo(da);
      });

      if (mounted) setState(() => history = rows);

      debugPrint("LEGACY HISTORY: ${legacyRes['statusCode']} ${legacyRes['data']}");
      debugPrint("DYNAMIC HISTORY: ${dynamicRes['statusCode']} ${dynamicRes['data']}");
    } catch (e) {
      showError("History loading error: $e");
    }

    if (mounted) setState(() => loadingHistory = false);
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadPending(silent: true),
      loadHistory(),
    ]);
  }

  void openApproval(Map<String, dynamic> approval) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApprovalDetailPage(
          approval: approval,
          apiBase: apiBase,
          headers: headers,
        ),
      ),
    ).then((_) => refreshAll());
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.green, content: Text(message)),
    );
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupPending() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in pending) {
      final module = safeText(item["module"], "").toLowerCase();

      final key = module == "customer"
          ? "Customers"
          : module == "tender"
          ? "Tenders"
          : module == "lead"
          ? "Leads"
          : module == "travel"
          ? "Travel Requests"
          : module == "tada"
          ? "TA/DA Claims"
          : module == "emdbg"
          ? "EMD / BG"
          : "Others";

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return grouped;
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return const Color(0xff059669);
      case "rejected":
        return const Color(0xffDC2626);
      case "pending":
        return const Color(0xffD97706);
      default:
        return const Color(0xff64748B);
    }
  }

  IconData moduleIcon(String module) {
    switch (module.toLowerCase()) {
      case "customer":
      case "customers":
        return Icons.business_outlined;
      case "lead":
      case "leads":
        return Icons.trending_up;
      case "tender":
      case "tenders":
        return Icons.description_outlined;
      case "travel":
        return Icons.flight_takeoff;
      case "tada":
        return Icons.receipt_long;
      case "emdbg":
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.approval_outlined;
    }
  }

  Color moduleSoftColor(String module) {
    switch (module.toLowerCase()) {
      case "customer":
        return const Color(0xffE0F2FE);
      case "lead":
        return const Color(0xffF3E8FF);
      case "tender":
        return const Color(0xffFFEDD5);
      case "travel":
        return const Color(0xffDBEAFE);
      case "tada":
        return const Color(0xffE0E7FF);
      case "emdbg":
        return const Color(0xffCCFBF1);
      default:
        return const Color(0xffEEF2FF);
    }
  }

  Color moduleIconColor(String module) {
    switch (module.toLowerCase()) {
      case "customer":
        return const Color(0xff0284C7);
      case "lead":
        return const Color(0xff7C3AED);
      case "tender":
        return const Color(0xffEA580C);
      case "travel":
        return const Color(0xff2563EB);
      case "tada":
        return const Color(0xff4F46E5);
      case "emdbg":
        return const Color(0xff0F766E);
      default:
        return AppColors.primaryLight;
    }
  }

  Widget statusChip(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10.5,
        ),
      ),
    );
  }

  String approvalTypeLabel(Map<String, dynamic> item, {bool group = false}) {
    final action = safeText(item["action"], "");
    final actionLabel = safeText(item["action_label"], "");
    final typeLabel = safeText(item["type_label"], "");

    if (typeLabel != "-") return typeLabel;

    const full = {
      "tender_step1_manager": "Tender Basic Info Approval (Manager)",
      "tender_step1_ceo": "Tender Basic Info Approval (CEO)",
      "tender_step2_manager": "Tender Details Approval (Manager)",
      "tender_step2_ceo": "Tender Details Approval (CEO)",
      "tender_step3_manager": "Tender Workings Approval (Manager)",
      "tender_step3_ceo": "Tender Workings Approval (CEO)",
      "tender_po_manager": "Tender PO Details Approval (Manager)",
      "convert": "Lead Conversion Approval",
      "convert_lead_manager": "Lead Conversion Approval",
      "request": "Travel Request Approval",
      "expense": "TA/DA Expense Claim (Manager)",
      "expense_ceo": "TA/DA Expense Claim (CEO)",
      "release_request": "EMD/BG Release Approval",
      "create": "Customer Creation Approval",
    };

    const short = {
      "tender_step1_manager": "Basic Info Approval · Manager",
      "tender_step1_ceo": "Basic Info Approval · CEO",
      "tender_step2_manager": "Tender Details · Manager",
      "tender_step2_ceo": "Tender Details · CEO",
      "tender_step3_manager": "Workings Approval · Manager",
      "tender_step3_ceo": "Workings Approval · CEO",
      "tender_po_manager": "PO Details Approval · Manager",
      "convert": "Lead Conversion Approval",
      "convert_lead_manager": "Lead Conversion Approval",
      "request": "Travel Request Approval",
      "expense": "Expense Claim · Manager",
      "expense_ceo": "Expense Claim · CEO",
      "release_request": "Release Approval",
      "create": "Customer Approval",
    };

    return group
        ? short[action] ?? (actionLabel == "-" ? action : actionLabel)
        : full[action] ?? (actionLabel == "-" ? action : actionLabel);
  }

  Widget approvalCard(
      Map<String, dynamic> item, {
        required bool historyMode,
        bool inGroup = false,
      }) {
    final module = safeText(item["module"], "");
    final status = safeText(item["status"], "pending");
    final summary = item["summary"] is Map ? item["summary"] as Map : {};

    final customerName = safeText(
      summary["company_name"] ??
          summary["customer_name"] ??
          summary["employee_name"] ??
          summary["client_name"],
      "",
    );

    final purpose = safeText(
      summary["purpose"] ?? summary["title"] ?? summary["lead_title"],
      "",
    );

    final requester = safeText(item["requested_by_name"], "-");
    final ref = safeText(item["record_ref"], "-");

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openApproval(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.035),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: moduleSoftColor(module),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: moduleIconColor(module).withOpacity(.12)),
              ),
              child: Icon(
                moduleIcon(module),
                color: moduleIconColor(module),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      approvalTypeLabel(item, group: inGroup),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    ref,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  if (customerName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 12, color: AppColors.textSoft),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (purpose.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_offer_outlined,
                            size: 11, color: AppColors.textSoft),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            purpose,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 12, color: AppColors.textSoft),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "$requester · ${fmtDate(item["created_at"])}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                statusChip(safeText(item["approval_display"], status)),
                const SizedBox(height: 10),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSoft.withOpacity(.45),
                  size: 21,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget groupedPendingList() {
    if (loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pending.isEmpty) {
      return emptyState(
        title: "All caught up!",
        subtitle: "No pending approvals.",
        icon: Icons.check_circle_outline,
        color: const Color(0xff10B981),
      );
    }

    final groups = groupPending();

    return RefreshIndicator(
      onRefresh: () => loadPending(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: groups.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 5, 4, 10),
                child: Row(
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xffEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${entry.value.length}",
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...entry.value.map(
                    (item) => approvalCard(
                  item,
                  historyMode: false,
                  inGroup: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget historyList() {
    if (loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (history.isEmpty) {
      return emptyState(
        title: "No approval history yet",
        subtitle: "Approved and rejected requests will appear here.",
        icon: Icons.history,
        color: AppColors.textSoft,
      );
    }

    return RefreshIndicator(
      onRefresh: loadHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (_, index) {
          return approvalCard(
            history[index],
            historyMode: true,
          );
        },
      ),
    );
  }

  Widget emptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return RefreshIndicator(
      onRefresh: refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * .23),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, color: color, size: 38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Approvals",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
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
                tabs: [
                  Tab(text: pending.isEmpty ? "Pending" : "Pending (${pending.length})"),
                  const Tab(text: "History"),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          groupedPendingList(),
          historyList(),
        ],
      ),
    );
  }
}

