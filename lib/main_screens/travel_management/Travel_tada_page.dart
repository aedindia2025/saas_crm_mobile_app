import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_helpers/api_method.dart';

import 'NewTravel_claim_page.dart';
import 'NewTravel_request_page.dart';

class TravelTadaPage extends StatefulWidget {
  const TravelTadaPage({super.key});

  @override
  State<TravelTadaPage> createState() => _TravelTadaPageState();
}

class _TravelTadaPageState extends State<TravelTadaPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final String baseUrl = "https://ascent.crm.azcentrix.com:4447/api/v1";

  bool loadingTravel = true;
  bool loadingClaims = true;

  String? token;
  String tenantSlug = '';

  // current user (mirrors web useAuthStore -> user.role / user.id)
  String myRole = '';
  int? myId;

  // ─── Filters (mirror web statusFilter / memberFilter / customerFilter) ───
  String statusFilter = '';
  String memberFilter = '';
  String customerFilter = '';

  List<Map<String, dynamic>> travelRequests = [];
  List<Map<String, dynamic>> claims = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> teamUsers = [];

  bool get isManagerUp =>
      ['admin', 'ceo', 'vp', 'manager'].contains(myRole.toLowerCase());

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() => setState(() {}));
    loadAll();
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'X-Tenant-Slug': tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    tenantSlug = prefs.getString('tenant_slug') ?? '';

    // NOTE: adjust these pref keys to whatever your app stores the
    // logged-in user under. Used for canSubmit / canEditRequest gating.
    myRole = prefs.getString('user_role') ??
        prefs.getString('role') ??
        '';
    myId = prefs.getInt('user_id') ??
        int.tryParse(prefs.getString('user_id') ?? '');

    if (token == null) return;

    await Future.wait([
      fetchTravelRequests(),
      fetchClaims(),
      fetchCustomers(),
      fetchTeamUsers(),
    ]);
  }

  Future<dynamic> getApi(String path) async {
    final response = await ApiMethod.getRequest(
      url: "$baseUrl$path",
      headers: headers,
    );

    if (response['statusCode'] == 200) {
      return response['data'];
    }

    throw Exception(response['data']?.toString() ?? 'API Error');
  }

  Future<void> fetchTravelRequests() async {
    try {
      setState(() => loadingTravel = true);
      final data = await getApi("/travel/requests");

      setState(() {
        travelRequests = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        loadingTravel = false;
      });
    } catch (e) {
      setState(() => loadingTravel = false);
      showError(e.toString());
    }
  }

  Future<void> fetchClaims() async {
    try {
      setState(() => loadingClaims = true);
      final data = await getApi("/travel/tada");

      setState(() {
        claims = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        loadingClaims = false;
      });
    } catch (e) {
      setState(() => loadingClaims = false);
      showError(e.toString());
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final data = await getApi("/travel/team-customers");
      setState(() {
        customers = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
      });
    } catch (_) {}
  }

  Future<void> fetchTeamUsers() async {
    try {
      final data = await getApi("/travel/team-users");
      setState(() {
        teamUsers = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        teamUsers.sort((a, b) => (a['label'] ?? a['full_name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(
            (b['label'] ?? b['full_name'] ?? '').toString().toLowerCase()));
      });
    } catch (_) {}
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  String money(dynamic value) {
    final n = double.tryParse(value?.toString() ?? "0") ?? 0;
    return "₹${n.toStringAsFixed(0)}";
  }

  String moneyInr(dynamic value) {
    final n = double.tryParse(value?.toString() ?? "0") ?? 0;
    // Group like web Number().toLocaleString()
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return "INR ${buf.toString()}";
  }

  String _valueOr(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? fallback : text;
  }

  // ═══════════════════════════════════════════════════════════════
  // STATUS / APPROVAL META  (ported from web getApprovalStatusMeta)
  // ═══════════════════════════════════════════════════════════════

  _ApprovalMeta approvalMeta(Map<String, dynamic> req) {
    final approvalStatus =
    (req['approval_status']?.toString() ?? '').trim().toLowerCase();
    final rawLabel = req['approval_display'] is String
        ? (req['approval_display'] as String).trim()
        : '';
    final rawCurrent = num.tryParse(req['approval_progress_current']?.toString() ?? '');
    final rawTotal = num.tryParse(req['approval_progress_total']?.toString() ?? '');
    final hasCurrent = rawCurrent != null;
    final hasTotal = rawTotal != null && rawTotal > 0;
    final isPending =
        approvalStatus == 'pending' || req['status'] == 'Submitted';
    final current = hasCurrent ? rawCurrent : 0;
    final total = hasTotal ? rawTotal : null;

    String statusLabel = rawLabel;
    final pendingRe = RegExp(r'^pending$', caseSensitive: false);
    if (isPending && total != null &&
        (statusLabel.isEmpty || pendingRe.hasMatch(statusLabel))) {
      statusLabel = "Pending ($current/$total)";
    } else if (isPending && statusLabel.isEmpty) {
      statusLabel = 'Pending';
    } else if (statusLabel.isEmpty) {
      statusLabel = req['status']?.toString() ?? 'Draft';
    }

    return _ApprovalMeta(
      isPending: isPending,
      visualStatus: isPending ? 'Pending' : (req['status']?.toString() ?? 'Draft'),
      statusLabel: statusLabel,
    );
  }

  // Tailwind STATUS_CFG ported (bg, text/dot, border)
  _StatusColors statusColors(String status) {
    switch (status) {
      case 'Pending':
      case 'Submitted':
      case 'Manager Approved':
        return _StatusColors(
          const Color(0xffFFFBEB), const Color(0xffB45309),
          const Color(0xffFDE68A), const Color(0xffFBBF24),
        );
      case 'Approved':
      case 'CEO Approved':
      case 'Accounts Approved':
      case 'Paid':
        return _StatusColors(
          const Color(0xffECFDF5), const Color(0xff047857),
          const Color(0xffA7F3D0), const Color(0xff10B981),
        );
      case 'Rejected':
        return _StatusColors(
          const Color(0xffFFF1F2), const Color(0xffE11D48),
          const Color(0xffFECDD3), const Color(0xffF43F5E),
        );
      case 'Completed':
        return _StatusColors(
          const Color(0xffEFF6FF), const Color(0xff1D4ED8),
          const Color(0xffBFDBFE), const Color(0xff3B82F6),
        );
      case 'Cancelled':
        return _StatusColors(
          const Color(0xffF1F5F9), const Color(0xff94A3B8),
          const Color(0xffE2E8F0), const Color(0xffCBD5E1),
        );
      case 'Draft':
      default:
        return _StatusColors(
          const Color(0xffF1F5F9), const Color(0xff475569),
          const Color(0xffE2E8F0), const Color(0xff94A3B8),
        );
    }
  }

  Color statusAccent(String status) {
    switch (status) {
      case 'Pending':
      case 'Submitted':
      case 'Manager Approved':
        return const Color(0xffFBBF24);
      case 'Approved':
      case 'CEO Approved':
      case 'Accounts Approved':
      case 'Paid':
        return const Color(0xff10B981);
      case 'Rejected':
        return const Color(0xffF43F5E);
      case 'Completed':
        return const Color(0xff3B82F6);
      case 'Cancelled':
        return const Color(0xffCBD5E1);
      case 'Draft':
      default:
        return const Color(0xffCBD5E1);
    }
  }

  Widget statusChip(String status, {String? label}) {
    final c = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label ?? status,
            style: TextStyle(
              color: c.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget sourceBadge(Map<String, dynamic> item) {
    if (item['source']?.toString() != 'kam') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffC7D2FE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 11, color: Color(0xff4F46E5)),
          SizedBox(width: 3),
          Text("KAM",
              style: TextStyle(
                  color: Color(0xff4F46E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _normMode(String? mode) => (mode ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s/]+'), '_');

  Widget? transportBadge(String? mode) {
    final key = _normMode(mode);
    if (key.isEmpty) return null;
    late IconData icon;
    late Color bg;
    late Color fg;
    late String label;
    switch (key) {
      case 'flight':
        icon = Icons.flight; bg = const Color(0xffF0F9FF); fg = const Color(0xff0284C7); label = 'Flight'; break;
      case 'train':
        icon = Icons.train; bg = const Color(0xffF5F3FF); fg = const Color(0xff7C3AED); label = 'Train'; break;
      case 'bus':
        icon = Icons.directions_bus; bg = const Color(0xffF0FDFA); fg = const Color(0xff0D9488); label = 'Bus'; break;
      case 'own_vehicle':
        icon = Icons.directions_car; bg = const Color(0xffFFF7ED); fg = const Color(0xffEA580C); label = 'Own Vehicle'; break;
      case 'company_car':
        icon = Icons.directions_car; bg = const Color(0xffEFF6FF); fg = const Color(0xff2563EB); label = 'Company Car'; break;
      case 'bike':
        icon = Icons.two_wheeler; bg = const Color(0xffFFF1F2); fg = const Color(0xffF43F5E); label = 'Bike'; break;
      case 'taxi_cab':
        icon = Icons.local_taxi; bg = const Color(0xffFEFCE8); fg = const Color(0xffA16207); label = 'Taxi / Cab'; break;
      default:
        icon = Icons.navigation; bg = const Color(0xffF1F5F9); fg = const Color(0xff64748B);
        label = (mode ?? '').isNotEmpty ? mode! : 'Other';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ROLE GATING (ported from web canSubmit / canEditRequest)
  // ═══════════════════════════════════════════════════════════════

  bool canSubmit(Map<String, dynamic> req) {
    final status = req['status']?.toString();
    final isOwn = myId != null &&
        int.tryParse(req['employee_id']?.toString() ?? '') == myId;
    return (status == 'Draft' || status == 'Rejected') &&
        (isOwn || isManagerUp);
  }

  bool canEditRequest(Map<String, dynamic> req) {
    final status = req['status']?.toString();
    final isOwn = myId != null &&
        int.tryParse(req['employee_id']?.toString() ?? '') == myId;
    return ['Draft', 'Rejected', 'Submitted'].contains(status) &&
        (isOwn || isManagerUp);
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTERING + STATS  (ported from web)
  // ═══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get filteredRequests {
    return travelRequests.where((r) {
      if (statusFilter.isNotEmpty && r['status'] != statusFilter) return false;
      if (memberFilter.isNotEmpty &&
          (r['employee_id']?.toString() ?? '') != memberFilter) return false;
      if (customerFilter.isNotEmpty) {
        final cid =
            (r['customer_id'] ?? r['account_id'])?.toString() ?? '';
        if (cid != customerFilter) return false;
      }
      return true;
    }).toList();
  }

  int get statTotal => travelRequests.length;
  int get statKam =>
      travelRequests.where((r) => r['source'] == 'kam').length;
  int get statPending => travelRequests
      .where((r) =>
  (r['approval_status']?.toString().toLowerCase() ?? '') == 'pending' ||
      r['status'] == 'Submitted')
      .length;
  int get statApproved =>
      travelRequests.where((r) => r['status'] == 'Approved').length;
  int get statRejected =>
      travelRequests.where((r) => r['status'] == 'Rejected').length;

  // member options derived from team-users (fallback to requests)
  List<Map<String, String>> get memberOptions {
    if (teamUsers.isNotEmpty) {
      return teamUsers
          .where((u) => u['id'] != null)
          .map((u) => {
        'value': u['id'].toString(),
        'label':
        (u['label'] ?? u['full_name'] ?? u['username'] ?? '')
            .toString(),
      })
          .where((e) => e['value']!.isNotEmpty && e['label']!.isNotEmpty)
          .toList();
    }
    final seen = <String>{};
    final out = <Map<String, String>>[];
    for (final r in travelRequests) {
      final v = r['employee_id']?.toString();
      final l = r['employee_name']?.toString();
      if (v != null && l != null && l.isNotEmpty && seen.add(v)) {
        out.add({'value': v, 'label': l});
      }
    }
    out.sort((a, b) => a['label']!.compareTo(b['label']!));
    return out;
  }

  List<Map<String, String>> get customerOptions => customers
      .where((c) => c['id'] != null)
      .map((c) => {
    'value': c['id'].toString(),
    'label': (c['customer_name'] ?? c['label'] ?? '').toString(),
  })
      .where((e) => e['value']!.isNotEmpty && e['label']!.isNotEmpty)
      .toList();

  // ═══════════════════════════════════════════════════════════════
  // SHARED LITTLE WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget info(IconData icon, dynamic text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xff94A3B8)),
        const SizedBox(width: 5),
        Text(
          text?.toString() ?? "-",
          style: const TextStyle(
            color: Color(0xff64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget miniChip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTER BAR
  // ═══════════════════════════════════════════════════════════════

  Widget filterDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> options,
    required String allLabel,
    required ValueChanged<String> onChanged,
    double width = 170,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xff64748B),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .4)),
        const SizedBox(height: 5),
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value.isEmpty ? '' : value,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: const TextStyle(
                  color: Color(0xff334155),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem(value: '', child: Text(allLabel)),
                ...options.map((o) => DropdownMenuItem(
                  value: o['value'],
                  child: Text(o['label'] ?? '',
                      overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => onChanged(v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget filterBar() {
    final hasFilter = statusFilter.isNotEmpty ||
        memberFilter.isNotEmpty ||
        customerFilter.isNotEmpty;

    const statusOptions = [
      'Approved', 'Rejected', 'Submitted', 'Draft', 'Completed', 'Cancelled',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          filterDropdown(
            label: 'Status',
            value: statusFilter,
            allLabel: 'All Statuses',
            width: 150,
            options:
            statusOptions.map((s) => {'value': s, 'label': s}).toList(),
            onChanged: (v) => setState(() => statusFilter = v),
          ),
          filterDropdown(
            label: 'Member',
            value: memberFilter,
            allLabel: 'All Members',
            width: 170,
            options: memberOptions,
            onChanged: (v) => setState(() => memberFilter = v),
          ),
          filterDropdown(
            label: 'Customer',
            value: customerFilter,
            allLabel: 'All Customers',
            width: 190,
            options: customerOptions,
            onChanged: (v) => setState(() => customerFilter = v),
          ),
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  statusFilter = '';
                  memberFilter = '';
                  customerFilter = '';
                }),
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffE11D48),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Showing ",
                      style: TextStyle(
                          color: Color(0xff64748B), fontSize: 12)),
                  Text("${filteredRequests.length}",
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                  const Text(" requests",
                      style: TextStyle(
                          color: Color(0xff64748B), fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TRAVEL REQUEST CARD  (ported from web list card)
  // ═══════════════════════════════════════════════════════════════

  Widget travelCard(Map<String, dynamic> item) {
    final meta = approvalMeta(item);
    final accent = statusAccent(meta.visualStatus);
    final status = item['status']?.toString() ?? 'Draft';
    final pendingApproverName =
    (item['approval_requested_to_name'] ?? item['requested_to_name'])
        ?.toString();
    final tBadge = transportBadge(item['transport_mode']?.toString());

    return InkWell(
      onTap: () => openTravelDetails(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── header row ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xffEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.flight_takeoff,
                              color: Color(0xff2563EB),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['request_number']?.toString() ?? "-",
                                        style: const TextStyle(
                                          color: Color(0xff1D4ED8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    statusChip(
                                      meta.visualStatus,
                                      label: meta.statusLabel,
                                    ),
                                    sourceBadge(item),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item['purpose']?.toString() ?? "-",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xff1E293B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xffF1F5F9),
                              ),
                            ),
                            child: Text(
                              item['visit_type']?.toString() ?? "",
                              style: const TextStyle(
                                color: Color(0xff64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ── route / dates / transport ──
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Color(0xff94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${item['from_city'] ?? '-'}",
                                style: const TextStyle(
                                  color: Color(0xff334155),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 12,
                                  color: Color(0xffCBD5E1),
                                ),
                              ),
                              Text(
                                "${item['to_city'] ?? '-'}",
                                style: const TextStyle(
                                  color: Color(0xff334155),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          info(
                            Icons.calendar_today_outlined,
                            (item['return_date'] != null &&
                                item['return_date'] != item['travel_date'])
                                ? "${item['travel_date'] ?? '-'} - ${item['return_date']}"
                                : "${item['travel_date'] ?? '-'}",
                          ),
                          if (tBadge != null) tBadge,
                        ],
                      ),

                      // ── account / cost / employee ──
                      if ((item['account_name'] ?? '').toString().isNotEmpty ||
                          item['estimated_cost'] != null ||
                          (isManagerUp &&
                              (item['employee_name'] ?? '')
                                  .toString()
                                  .isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            if ((item['account_name'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.business_outlined,
                                    size: 12,
                                    color: Color(0xff4F46E5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['account_name'].toString(),
                                    style: const TextStyle(
                                      color: Color(0xff4F46E5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            if (item['estimated_cost'] != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.attach_money,
                                    size: 12,
                                    color: Color(0xff059669),
                                  ),
                                  Text(
                                    moneyInr(item['estimated_cost']),
                                    style: const TextStyle(
                                      color: Color(0xff059669),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            if (isManagerUp &&
                                (item['employee_name'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                              info(Icons.person_outline, item['employee_name']),
                          ],
                        ),
                      ],

                      // ── kam line ──
                      if ((item['kam_activity_subject'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt,
                              size: 11,
                              color: Color(0xff6366F1),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "KAM: ${item['kam_activity_subject']}",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff6366F1),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ── rejection reason ──
                      if (status == 'Rejected' &&
                          (item['rejection_reason'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xffFECDD3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.cancel,
                                size: 14,
                                color: Color(0xffF43F5E),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item['rejection_reason'].toString(),
                                  style: const TextStyle(
                                    color: Color(0xffE11D48),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── footer actions ──
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xffF1F5F9)),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (canEditRequest(item))
                            _outlineBtn(
                              icon: Icons.edit_outlined,
                              label: "Edit",
                              onTap: () => openEditTravelRequest(item),
                            ),

                          if (status == 'Draft' && canSubmit(item))
                            _filledBtn(
                              icon: Icons.chevron_right,
                              label: "Submit for Approval",
                              color: const Color(0xff2563EB),
                              onTap: () => submitTravel(item['id']),
                            )
                          else if (status == 'Rejected' && canSubmit(item))
                            _filledBtn(
                              icon: Icons.refresh,
                              label: "Re-submit",
                              color: const Color(0xffD97706),
                              onTap: () => submitTravel(item['id']),
                            )
                          else if (meta.isPending && !isManagerUp)
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 260),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 13,
                                      color: Color(0xffD97706),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        pendingApproverName != null &&
                                            pendingApproverName.isNotEmpty
                                            ? "Pending approval from $pendingApproverName"
                                            : "Pending approval",
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xffD97706),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (status == 'Approved')
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 13,
                                      color: Color(0xff059669),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Approved - you may travel",
                                      style: TextStyle(
                                        color: Color(0xff059669),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),

                          if (item['advance_required'] == true)
                            miniChip(
                              "Advance Req.",
                              const Color(0xff7C3AED),
                              icon: Icons.credit_card,
                            ),

                          if (item['accommodation_required'] == true)
                            miniChip(
                              "Stay Required",
                              const Color(0xff0F766E),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        maximumSize: const Size(220, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: const Color(0xff1D4ED8),
        side: const BorderSide(color: Color(0xffBFDBFE)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _filledBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 38),
        maximumSize: const Size(240, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TRAVEL DETAILS DIALOG  (ported from web Modal + collapsible sections)
  // ═══════════════════════════════════════════════════════════════

  void openTravelDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .95,
            maxWidth: 980,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              dialogHeader(
                title: "Travel Request Details",
                subtitle: item['request_number']?.toString() ?? "",
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      travelHeroDetails(item),
                      const SizedBox(height: 16),

                      CollapsibleSection(
                        title: "Trip Summary",
                        icon: Icons.flight_takeoff,
                        children: [
                          detailField("Employee", item['employee_name']),
                          detailField(
                              "Source",
                              item['source_label'] ?? item['source']),
                          detailField("From City", item['from_city']),
                          detailField("To City", item['to_city']),
                          detailField("Travel Date", item['travel_date']),
                          detailField("Return Date", item['return_date']),
                          detailField("Total Days", item['total_days']),
                          detailField(
                            "Outside District / City",
                            item['is_outside_district'] == true ? "Yes" : "No",
                          ),
                        ],
                      ),

                      // CRM Linkage
                      if ((item['account_name'] ?? '').toString().isNotEmpty ||
                          (item['contact_name'] ?? '').toString().isNotEmpty ||
                          (item['contact_phone'] ?? '').toString().isNotEmpty ||
                          item['opportunity_id'] != null ||
                          item['lead_id'] != null ||
                          item['tender_id'] != null ||
                          (item['kam_activity_subject'] ?? '')
                              .toString()
                              .isNotEmpty)
                        CollapsibleSection(
                          title: "CRM Linkage",
                          icon: Icons.business_center_outlined,
                          children: [
                            detailField(
                                "Account / Customer", item['account_name']),
                            detailField(
                                "Linked Opportunity", item['opportunity_id']),
                            detailField("Contact Person", item['contact_name']),
                            detailField("Contact Phone", item['contact_phone']),
                            detailField("Lead / Reference ID", item['lead_id']),
                            detailField(
                              "Linked Tender",
                              (item['tender_num'] ?? '').toString().isNotEmpty
                                  ? "${item['tender_num']}${(item['tender_title'] ?? '').toString().isNotEmpty ? ' – ${item['tender_title']}' : ''}"
                                  : (item['tender_id'] != null
                                  ? "Tender #${item['tender_id']}"
                                  : null),
                            ),
                            detailField(
                                "KAM Activity", item['kam_activity_subject']),
                          ],
                        ),

                      // Travel & Budget
                      if ((item['transport_mode'] ?? '')
                          .toString()
                          .isNotEmpty ||
                          (item['vehicle_number'] ?? '')
                              .toString()
                              .isNotEmpty ||
                          item['estimated_kms'] != null ||
                          (item['advance_booking_ref'] ?? '')
                              .toString()
                              .isNotEmpty ||
                          item['estimated_cost'] != null ||
                          item['advance_required'] == true ||
                          item['advance_amount'] != null)
                        CollapsibleSection(
                          title: "Travel & Budget",
                          icon: Icons.credit_card_outlined,
                          children: [
                            detailFieldWidget(
                              "Transport Mode",
                              transportBadge(
                                  item['transport_mode']?.toString()),
                            ),
                            detailField(
                                "Vehicle Number", item['vehicle_number']),
                            detailField("Estimated Distance (km)",
                                item['estimated_kms']),
                            detailField("Booking / PNR Reference",
                                item['advance_booking_ref']),
                            detailField(
                              "Estimated Cost",
                              item['estimated_cost'] == null
                                  ? null
                                  : moneyInr(item['estimated_cost']),
                            ),
                            detailField("Advance Required",
                                item['advance_required'] == true ? "Yes" : "No"),
                            detailField(
                              "Advance Amount",
                              item['advance_amount'] == null
                                  ? null
                                  : moneyInr(item['advance_amount']),
                            ),
                          ],
                        ),

                      // Accommodation
                      if (item['accommodation_required'] == true ||
                          (item['accommodation_type'] ?? '')
                              .toString()
                              .isNotEmpty ||
                          (item['hotel_name'] ?? '').toString().isNotEmpty ||
                          (item['check_in_date'] ?? '')
                              .toString()
                              .isNotEmpty ||
                          (item['check_out_date'] ?? '')
                              .toString()
                              .isNotEmpty ||
                          item['accommodation_cost'] != null)
                        CollapsibleSection(
                          title: "Accommodation",
                          icon: Icons.home_outlined,
                          children: [
                            detailField(
                                "Accommodation Required",
                                item['accommodation_required'] == true
                                    ? "Yes"
                                    : "No"),
                            detailField("Accommodation Type",
                                item['accommodation_type']),
                            detailField("Hotel / Property Name",
                                item['hotel_name'],
                                fullWidth: true),
                            detailField("Check-in Date", item['check_in_date']),
                            detailField(
                                "Check-out Date", item['check_out_date']),
                            detailField(
                              "Accommodation Cost",
                              item['accommodation_cost'] == null
                                  ? null
                                  : moneyInr(item['accommodation_cost']),
                            ),
                          ],
                        ),

                      // Additional Info
                      if ((item['companions'] ?? '').toString().isNotEmpty ||
                          (item['notes'] ?? '').toString().isNotEmpty ||
                          (item['rejection_reason'] ?? '')
                              .toString()
                              .isNotEmpty)
                        CollapsibleSection(
                          title: "Additional Info",
                          icon: Icons.note_alt_outlined,
                          children: [
                            detailField("Travel Companions",
                                item['companions'],
                                fullWidth: true),
                            detailField("Notes / Special Instructions",
                                item['notes'],
                                fullWidth: true),
                            detailField("Rejection Reason",
                                item['rejection_reason'],
                                fullWidth: true),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              dialogFooter(
                canEdit: canEditRequest(item),
                onEdit: () {
                  Navigator.pop(context);
                  openEditTravelRequest(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget travelHeroDetails(Map<String, dynamic> item) {
    final meta = approvalMeta(item);
    final tBadge = transportBadge(item['transport_mode']?.toString());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffF8FAFC), Colors.white, Color(0xffEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              statusChip(meta.visualStatus, label: meta.statusLabel),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(item['visit_type']?.toString() ?? "-",
                    style: const TextStyle(
                        color: Color(0xff64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item['request_number']?.toString() ?? "-",
                    style: const TextStyle(
                        color: Color(0xff1D4ED8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
              sourceBadge(item),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item['purpose']?.toString() ?? "-",
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Travel request overview and trip information",
            style: TextStyle(
              color: AppColors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              info(Icons.location_on_outlined,
                  "${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}"),
              info(Icons.calendar_today_outlined,
                  "${item['travel_date'] ?? '-'} - ${item['return_date'] ?? '-'}"),
              if ((item['employee_name'] ?? '').toString().isNotEmpty)
                info(Icons.person_outline, item['employee_name']),
              if ((item['account_name'] ?? '').toString().isNotEmpty)
                info(Icons.business_outlined, item['account_name']),
            ],
          ),
          if (item['status'] == 'Rejected' &&
              (item['rejection_reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xffFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffFECDD3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xffF43F5E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("REJECTED REQUEST",
                            style: TextStyle(
                                color: Color(0xffF43F5E),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4)),
                        const SizedBox(height: 4),
                        Text(item['rejection_reason'].toString(),
                            style: const TextStyle(
                                color: Color(0xffE11D48), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: topInfoBox(
                      "Trip Days", item['total_days']?.toString() ?? "--")),
              const SizedBox(width: 10),
              Expanded(
                child: topInfoBoxWidget(
                  "Transport",
                  tBadge ?? const Text("Not set",
                      style: TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: topInfoBox("Advance",
                      item['advance_required'] == true ? "Required" : "No")),
              const SizedBox(width: 10),
              Expanded(
                  child: topInfoBox("Stay",
                      item['accommodation_required'] == true
                          ? "Required"
                          : "No")),
            ],
          ),
        ],
      ),
    );
  }

  Widget topInfoBox(String title, String value) =>
      topInfoBoxWidget(title, Text(
        value,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ));

  Widget topInfoBoxWidget(String title, Widget value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: value),
        ],
      ),
    );
  }

  // DetailField — hides when empty (web behaviour)
  Widget detailField(String label, dynamic value, {bool fullWidth = false}) {
    final text = value?.toString().trim() ?? "";
    if (text.isEmpty) return const SizedBox.shrink();
    return _DetailFieldTag(
      fullWidth: fullWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSoft,
                  letterSpacing: .4)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 42),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }

  Widget detailFieldWidget(String label, Widget? value) {
    if (value == null) return const SizedBox.shrink();
    return _DetailFieldTag(
      fullWidth: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSoft,
                  letterSpacing: .4)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 42),
            alignment: Alignment.centerLeft,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: value,
          ),
        ],
      ),
    );
  }

  Widget dialogHeader({required String title, required String subtitle}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget dialogFooter({required bool canEdit, VoidCallback? onEdit}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (canEdit)
            Flexible(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text("Edit"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(110, 42),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (canEdit) const SizedBox(width: 10),
          Flexible(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size(110, 42),
                padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Close"),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUBMIT
  // ═══════════════════════════════════════════════════════════════

  Future<void> submitTravel(int id) async {
    try {
      final response = await ApiMethod.postRequest(
        url: "$baseUrl/travel/requests/$id/submit",
        headers: headers,
        body: {},
      );

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        final data = response['data'];
        if (data is Map && data['status'] == 'Approved') {
          showSuccess(data['message']?.toString() ?? "Travel request auto-approved");
        } else if (data is Map &&
            (data['requested_to']?.toString().isNotEmpty ?? false)) {
          showSuccess("Submitted to ${data['requested_to']}");
        } else {
          showSuccess("Travel request submitted successfully");
        }
        fetchTravelRequests();
      } else {
        showError(response['data']?.toString() ??
            'Error submitting travel request');
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TRAVEL TAB
  // ═══════════════════════════════════════════════════════════════

  Widget travelTab() {
    final list = filteredRequests;

    return RefreshIndicator(
      onRefresh: fetchTravelRequests,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            "Travel Request",
            style: TextStyle(
              color: Color(0xff0F172A),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Plan and track business travel - expense claims are filed after the trip",
            style: TextStyle(color: Color(0xff64748B)),
          ),
          const SizedBox(height: 16),

          // ── Stats (5, mirrors web) ──
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 10) / 2;
            final cards = [
              statCard("Total", statTotal.toString(), Icons.flight_takeoff,
                  const Color(0xff2563EB)),
              statCard("From KAM", statKam.toString(), Icons.bolt,
                  const Color(0xff6366F1)),
              statCard("Pending Review", statPending.toString(),
                  Icons.access_time, const Color(0xffD97706)),
              statCard("Approved", statApproved.toString(),
                  Icons.check_circle, const Color(0xff059669)),
              statCard("Rejected", statRejected.toString(), Icons.cancel,
                  const Color(0xffDC2626)),
            ];
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
              cards.map((e) => SizedBox(width: w, child: e)).toList(),
            );
          }),

          const SizedBox(height: 14),
          filterBar(),
          const SizedBox(height: 16),

          if (loadingTravel)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.symmetric(vertical: 60),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.flight_takeoff,
                      size: 40, color: Color(0xffCBD5E1)),
                  SizedBox(height: 10),
                  Text("No travel requests found",
                      style: TextStyle(
                          color: Color(0xff64748B),
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text("Try changing filters or create a new request",
                      style: TextStyle(
                          color: Color(0xff94A3B8), fontSize: 12)),
                ],
              ),
            )
          else
            ...list.map(travelCard),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CLAIMS TAB  (preserved from original)
  // ═══════════════════════════════════════════════════════════════

  Widget claimCard(Map<String, dynamic> item) {
    final status = item['overall_status']?.toString() ?? "Draft";
    final accent = statusAccent(status);

    return InkWell(
      onTap: () => openClaimDetails(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 145,
              decoration: BoxDecoration(
                color: accent,
                borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xffEEF2FF),
                          child: Icon(Icons.receipt_long,
                              color: Color(0xff4F46E5)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xffEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['claim_number']?.toString() ?? "-",
                                  style: const TextStyle(
                                      color: Color(0xff4F46E5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                              statusChip(status),
                            ],
                          ),
                        ),
                        Text(
                          money(item['net_payable']),
                          style: const TextStyle(
                              color: Color(0xff0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['purpose']?.toString() ?? "-",
                      style: const TextStyle(
                          color: Color(0xff0F172A),
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        info(Icons.location_on_outlined,
                            "${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}"),
                        info(Icons.calendar_today_outlined,
                            item['claim_date']?.toString() ?? "-"),
                        info(Icons.person_outline,
                            item['employee_name']?.toString() ?? "-"),
                        info(Icons.list_alt,
                            "${(item['line_items'] as List?)?.length ?? 0} items"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        miniChip(
                          item['has_all_proofs'] == true
                              ? "Proofs Attached"
                              : "Proof Missing",
                          item['has_all_proofs'] == true
                              ? const Color(0xff059669)
                              : const Color(0xffDC2626),
                        ),
                        const Spacer(),
                        const Text("View only",
                            style: TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget claimsTab() {
    final total = claims.length;
    final draft = claims.where((e) => e['overall_status'] == "Draft").length;
    final submitted =
        claims.where((e) => e['overall_status'] == "Submitted").length;
    final paid = claims.where((e) => e['overall_status'] == "Paid").length;

    return RefreshIndicator(
      onRefresh: fetchClaims,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            "Travel Claims",
            style: TextStyle(
                color: Color(0xff0F172A),
                fontSize: 23,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text("Claim travel expenses after your trip",
              style: TextStyle(color: Color(0xff64748B))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: statCard("Total", total.toString(),
                      Icons.receipt_long, const Color(0xff2563EB))),
              const SizedBox(width: 10),
              Expanded(
                  child: statCard("Draft", draft.toString(),
                      Icons.edit_document, const Color(0xff64748B))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: statCard("Submitted", submitted.toString(),
                      Icons.access_time, const Color(0xffD97706))),
              const SizedBox(width: 10),
              Expanded(
                  child: statCard("Paid", paid.toString(),
                      Icons.check_circle, const Color(0xff059669))),
            ],
          ),
          const SizedBox(height: 18),
          if (loadingClaims)
            const Center(child: CircularProgressIndicator())
          else if (claims.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text("No travel claims found")),
            )
          else
            ...claims.map(claimCard),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void openClaimDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              dialogHeader(
                title: item['claim_number']?.toString() ?? "Travel Claim",
                subtitle: "TA/DA claim details",
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      claimHeroDetails(item),
                      const SizedBox(height: 16),
                      if (item['has_all_proofs'] != true)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xffFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border:
                            Border.all(color: const Color(0xffFECACA)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Color(0xffDC2626), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Every expense item needs at least one proof document before submission.",
                                  style: TextStyle(
                                      color: Color(0xffDC2626),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      claimExpenseItems(item),
                    ],
                  ),
                ),
              ),
              dialogFooter(canEdit: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget claimHeroDetails(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffF8FAFC), Colors.white, Color(0xffEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              statusChip(item['overall_status']?.toString() ?? "Draft"),
              miniChip(item['claim_date']?.toString() ?? "-",
                  AppColors.primaryLight),
            ],
          ),
          const SizedBox(height: 14),
          Text(item['purpose']?.toString() ?? "-",
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text("${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}",
              style: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: topInfoBox(
                      "Total Expenses", money(item['total_amount']))),
              const SizedBox(width: 10),
              Expanded(
                  child: topInfoBox(
                      "Advance Taken", money(item['advance_taken']))),
            ],
          ),
          const SizedBox(height: 10),
          topInfoBox("Net Payable", money(item['net_payable'])),
        ],
      ),
    );
  }

  Widget claimExpenseItems(Map<String, dynamic> item) {
    final items =
    item['line_items'] is List ? item['line_items'] as List : [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.receipt_long,
                    color: AppColors.primaryLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Expense Items (${items.length})",
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ),
                const Text("View only",
                    style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("No expense items found",
                  style: TextStyle(color: AppColors.textSoft)),
            )
          else
            ...items.map((raw) {
              final e = Map<String, dynamic>.from(raw as Map);
              final attachments =
              e['attachments'] is List ? e['attachments'] as List : [];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border:
                  Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e['description']?.toString() ?? "-",
                              style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ),
                        Text(money(e['amount']),
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${e['category'] ?? '-'} • ${e['expense_date'] ?? '-'}"
                          "${(e['from_place'] ?? '').toString().isNotEmpty ? ' • ${e['from_place']}' : ''}"
                          "${(e['to_place'] ?? '').toString().isNotEmpty ? ' → ${e['to_place']}' : ''}",
                      style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    miniChip(
                      attachments.isNotEmpty
                          ? "Proof Attached"
                          : "Proof Missing",
                      attachments.isNotEmpty
                          ? const Color(0xff059669)
                          : const Color(0xffDC2626),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  void openEditTravelRequest(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTravelRequestPage(
          baseUrl: baseUrl,
          token: token!,
          tenantSlug: tenantSlug,
          customers: customers,
          editData: item,
        ),
      ),
    ).then((value) {
      if (value == true) fetchTravelRequests();
    });
  }

  void openCreateTravelRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTravelRequestPage(
          baseUrl: baseUrl,
          token: token!,
          tenantSlug: tenantSlug,
          customers: customers,
        ),
      ),
    ).then((value) {
      if (value == true) fetchTravelRequests();
    });
  }

  void openCreateClaim() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTravelClaimPage(
          baseUrl: baseUrl,
          token: token!,
          tenantSlug: tenantSlug,
          requests: travelRequests,
        ),
      ),
    ).then((value) {
      if (value == true) fetchClaims();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTravelTab = tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Travel Management",
          style:
          TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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
                    fontWeight: FontWeight.w900, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(text: "Travel Requests"),
                  Tab(text: "Travel Claims"),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: isTravelTab ? openCreateTravelRequest : openCreateClaim,
        icon: const Icon(Icons.add),
        label: Text(isTravelTab ? "New Request" : "New Claim"),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          travelTab(),
          claimsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Collapsible section (ported from web CollapsibleSection)
// Lays children into a responsive 2-column wrap; honours _DetailFieldTag.fullWidth
// ═══════════════════════════════════════════════════════════════

class CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool defaultOpen;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.defaultOpen = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool open = widget.defaultOpen;

  @override
  Widget build(BuildContext context) {
    final visible = widget.children
        .where((w) => w is! SizedBox || (w).key != null || w.runtimeType != SizedBox)
        .toList();
    // Filter out empty (SizedBox.shrink) fields
    final realChildren = widget.children
        .where((w) => !(w is SizedBox && w.width == 0.0 && w.height == 0.0))
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => open = !open),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xffEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon,
                        size: 16, color: const Color(0xff3B82F6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark)),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Color(0xff94A3B8)),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: Color(0xffF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth > 520;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: realChildren.map((child) {
                      final full = child is _DetailFieldTag && child.fullWidth;
                      final w = (!isWide || full)
                          ? c.maxWidth
                          : (c.maxWidth - 12) / 2;
                      return SizedBox(width: w, child: child);
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Tag wrapper so CollapsibleSection knows which fields are full width
class _DetailFieldTag extends StatelessWidget {
  final bool fullWidth;
  final Widget child;
  const _DetailFieldTag({required this.fullWidth, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _ApprovalMeta {
  final bool isPending;
  final String visualStatus;
  final String statusLabel;
  _ApprovalMeta({
    required this.isPending,
    required this.visualStatus,
    required this.statusLabel,
  });
}

class _StatusColors {
  final Color bg;
  final Color text;
  final Color border;
  final Color dot;
  _StatusColors(this.bg, this.text, this.border, this.dot);
}

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF3060A0);

  static const Color bg = Color(0xffF4F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0xffDDE6F0);
  static const Color textDark = Color(0xff0F172A);
  static const Color textSoft = Color(0xff64748B);

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