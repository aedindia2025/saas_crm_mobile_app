import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_helpers/api_method.dart';
import '../../api_helpers/api_urls.dart';
import 'approval_detail_page.dart';

class ApprovalUiColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primaryLight = Color(0xFF3060A0);
  static const Color bg = Color(0xffF4F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0xffE2E8F0);
  static const Color textDark = Color(0xff0F172A);
  static const Color textSoft = Color(0xff64748B);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryLight, primaryMedium, primaryDark, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

String safeText(dynamic value, [String fallback = '-']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

String fmtDate(dynamic value) {
  final text = safeText(value, '');
  if (text.isEmpty) return '-';
  try {
    final dt = DateTime.parse(text);
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  } catch (_) {
    return text.contains('T') ? text.split('T').first : text.split(' ').first;
  }
}

String money(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return '-';
  final n = num.tryParse(value.toString());
  if (n == null) return value.toString();
  return '₹${n.toStringAsFixed(0)}';
}

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;

  int pendingVisibleCount = 10;
  int historyVisibleCount = 10;
  final int pageLimit = 10;

  bool loadingPending = true;
  bool loadingHistory = true;
  bool refreshing = false;

  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> history = [];

  String token = '';
  String tenantSlug = '';

  String get apiBase => '${ApiUrls.baseUrl}/api/v1';

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (tenantSlug.isNotEmpty) 'X-Tenant-Slug': tenantSlug,
  };

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadTokenAndData();
  }

  void loadMorePendingFromLocal() {
    if (pendingVisibleCount >= pending.length) return;

    setState(() {
      final nextCount = pendingVisibleCount + pageLimit;
      pendingVisibleCount =
      nextCount > pending.length ? pending.length : nextCount;
    });
  }

  void loadMoreHistoryFromLocal() {
    if (historyVisibleCount >= history.length) return;

    setState(() {
      final nextCount = historyVisibleCount + pageLimit;
      historyVisibleCount =
      nextCount > history.length ? history.length : nextCount;
    });
  }

  Future<void> loadTokenAndData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token') ??
        prefs.getString('access_token') ??
        prefs.getString('token') ??
        '';
    tenantSlug = prefs.getString('tenant_slug') ?? '';

    if (token.isEmpty) {
      showError('Token not found');
      if (mounted) {
        setState(() {
          loadingPending = false;
          loadingHistory = false;
        });
      }
      return;
    }

    await Future.wait([loadPending(), loadHistory()]);
  }

  List<Map<String, dynamic>> _itemsFrom(dynamic responseData, String kind) {
    final dynamic raw = responseData is Map && responseData['items'] is List
        ? responseData['items']
        : responseData;

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)..['kind'] = kind)
        .toList();
  }

  Future<void> loadPending({bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (silent) {
        refreshing = true;
      } else {
        loadingPending = true;
      }
    });

    try {
      final results = await Future.wait([
        ApiMethod.getRequest(
          url: '$apiBase/approvals/pending',
          headers: headers,
        ),
        ApiMethod.getRequest(
          url: '$apiBase/approval-workflows/requests/pending',
          headers: headers,
        ),
      ]);

      final legacyRes = results[0];
      final dynamicRes = results[1];
      final rows = <Map<String, dynamic>>[];

      if (legacyRes['statusCode'] == 200) {
        rows.addAll(_itemsFrom(legacyRes['data'], 'legacy'));
      }

      if (dynamicRes['statusCode'] == 200) {
        rows.addAll(_itemsFrom(dynamicRes['data'], 'dynamic'));
      }

      if (legacyRes['statusCode'] != 200 && dynamicRes['statusCode'] != 200) {
        showError('Failed to load pending approvals');
      }

      rows.sort(
            (a, b) => _dateOf(
          b,
          ['created_at', 'requested_at'],
        ).compareTo(
          _dateOf(
            a,
            ['created_at', 'requested_at'],
          ),
        ),
      );

      if (mounted) {
        setState(() {
          pending = rows;
          pendingVisibleCount = 10;
        });
      }
    } catch (e) {
      showError('Pending approvals error: $e');
    } finally {
      if (mounted) {
        setState(() {
          loadingPending = false;
          refreshing = false;
        });
      }
    }
  }

  Future<void> loadHistory() async {
    if (mounted) setState(() => loadingHistory = true);

    try {
      final results = await Future.wait([
        ApiMethod.getRequest(
          url: '$apiBase/approvals/history?page=1&per_page=100',
          headers: headers,
        ),
        ApiMethod.getRequest(
          url: '$apiBase/approval-workflows/requests/history?page=1&per_page=100',
          headers: headers,
        ),
      ]);

      final legacyRes = results[0];
      final dynamicRes = results[1];
      final rows = <Map<String, dynamic>>[];

      if (legacyRes['statusCode'] == 200) {
        rows.addAll(_itemsFrom(legacyRes['data'], 'legacy'));
      }

      if (dynamicRes['statusCode'] == 200) {
        rows.addAll(_itemsFrom(dynamicRes['data'], 'dynamic'));
      }

      if (legacyRes['statusCode'] != 200 && dynamicRes['statusCode'] != 200) {
        showError('Failed to load approval history');
      }

      rows.sort(
            (a, b) => _dateOf(
          b,
          ['decided_at', 'updated_at', 'created_at', 'requested_at'],
        ).compareTo(
          _dateOf(
            a,
            ['decided_at', 'updated_at', 'created_at', 'requested_at'],
          ),
        ),
      );

      if (mounted) {
        setState(() {
          history = rows;
          historyVisibleCount = 10;
        });
      }
    } catch (e) {
      showError('History loading error: $e');
    } finally {
      if (mounted) setState(() => loadingHistory = false);
    }
  }

  DateTime _dateOf(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final parsed = DateTime.tryParse(safeText(item[key], ''));
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> refreshAll() async {
    await Future.wait([loadPending(silent: true), loadHistory()]);
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

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        content: Text(message),
      ),
    );
  }

  String approvalTypeLabel(
      Map<String, dynamic> item, {
        bool group = false,
      }) {
    final action = safeText(item['action'], '');
    final actionLabel = safeText(item['action_label'], '');
    final typeLabel = safeText(item['type_label'], '');

    if (typeLabel != '-') return typeLabel;

    const full = {
      'tender_step1_manager': 'Tender Basic Info Approval (Manager)',
      'tender_step1_ceo': 'Tender Basic Info Approval (CEO)',
      'tender_step2_manager': 'Tender Details Approval (Manager)',
      'tender_step2_ceo': 'Tender Details Approval (CEO)',
      'tender_step3_manager': 'Tender Workings Approval (Manager)',
      'tender_step3_ceo': 'Tender Workings Approval (CEO)',
      'tender_po_manager': 'Tender PO Details Approval (Manager)',
      'convert': 'Lead Conversion Approval',
      'convert_lead_manager': 'Lead Conversion Approval',
      'request': 'Travel Request Approval',
      'expense': 'TA/DA Expense Claim (Manager)',
      'expense_ceo': 'TA/DA Expense Claim (CEO)',
      'release_request': 'EMD/BG Release Approval',
      'submit': 'Quotation Approval',
      'create': 'Customer Creation Approval',
    };

    const short = {
      'tender_step1_manager': 'Basic Info · Manager',
      'tender_step1_ceo': 'Basic Info · CEO',
      'tender_step2_manager': 'Tender Details · Manager',
      'tender_step2_ceo': 'Tender Details · CEO',
      'tender_step3_manager': 'Workings · Manager',
      'tender_step3_ceo': 'Workings · CEO',
      'tender_po_manager': 'PO Details · Manager',
      'convert': 'Lead Conversion',
      'convert_lead_manager': 'Lead Conversion',
      'request': 'Travel Request',
      'expense': 'Expense · Manager',
      'expense_ceo': 'Expense · CEO',
      'release_request': 'Release Approval',
      'submit': 'Quotation',
      'create': 'Customer Approval',
    };

    return (group ? short[action] : full[action]) ??
        (actionLabel == '-' ? action : actionLabel);
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xff059669);
      case 'rejected':
        return const Color(0xffDC2626);
      case 'pending':
        return const Color(0xffD97706);
      default:
        return ApprovalUiColors.textSoft;
    }
  }

  IconData moduleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'customer':
      case 'customers':
        return Icons.business_outlined;
      case 'lead':
      case 'leads':
        return Icons.trending_up;
      case 'tender':
      case 'tenders':
        return Icons.description_outlined;
      case 'travel':
        return Icons.flight_takeoff;
      case 'tada':
        return Icons.receipt_long;
      case 'emdbg':
        return Icons.account_balance_wallet_outlined;
      case 'quotation':
        return Icons.request_quote_outlined;
      default:
        return Icons.approval_outlined;
    }
  }

  Color moduleColor(String module) {
    switch (module.toLowerCase()) {
      case 'customer':
        return const Color(0xff0284C7);
      case 'lead':
        return const Color(0xff7C3AED);
      case 'tender':
        return const Color(0xffEA580C);
      case 'travel':
        return const Color(0xff2563EB);
      case 'tada':
        return const Color(0xff4F46E5);
      case 'emdbg':
        return const Color(0xff0F766E);
      case 'quotation':
        return const Color(0xff059669);
      default:
        return ApprovalUiColors.primaryLight;
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

  Widget approvalCard(
      Map<String, dynamic> item, {
        required bool historyMode,
        bool inGroup = false,
      }) {
    final module = safeText(item['module'], '');
    final status = safeText(item['status'], 'pending');

    final summary = item['summary'] is Map
        ? Map<String, dynamic>.from(item['summary'])
        : <String, dynamic>{};

    final ref = safeText(item['record_ref'], '-');
    final requester = safeText(item['requested_by_name'], '-');

    final customerName = safeText(
      summary['customer_name'] ??
          summary['company_name'] ??
          summary['employee_name'] ??
          summary['client_name'],
      '',
    );

    final purpose = safeText(
      summary['purpose'] ??
          summary['title'] ??
          summary['lead_title'] ??
          summary['subject'] ??
          summary['instrument_type'],
      '',
    );

    final displayStatus = safeText(item['approval_display'], status);
    final currentStep = item['approval_progress_current'] ?? item['current_step_no'];
    final totalStep = item['approval_progress_total'];

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => openApproval(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ApprovalUiColors.border),
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
                color: moduleColor(module).withOpacity(.10),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: moduleColor(module).withOpacity(.13),
                ),
              ),
              child: Icon(
                moduleIcon(module),
                color: moduleColor(module),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ApprovalUiColors.border),
                    ),
                    child: Text(
                      approvalTypeLabel(item, group: inGroup),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ApprovalUiColors.primaryDark,
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
                      color: ApprovalUiColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  if (customerName.isNotEmpty)
                    _miniLine(Icons.business_outlined, customerName),
                  if (purpose.isNotEmpty)
                    _miniLine(Icons.local_offer_outlined, purpose),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 12,
                        color: ApprovalUiColors.textSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$requester · ${fmtDate(item['created_at'] ?? item['requested_at'])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ApprovalUiColors.textSoft,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentStep != null && totalStep != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Step $currentStep of $totalStep',
                      style: const TextStyle(
                        color: ApprovalUiColors.primaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                statusChip(displayStatus),
                const SizedBox(height: 10),
                Icon(
                  Icons.chevron_right,
                  color: ApprovalUiColors.textSoft.withOpacity(.45),
                  size: 21,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 11,
            color: ApprovalUiColors.textSoft,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ApprovalUiColors.textSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String groupKeyForApproval(Map<String, dynamic> item) {
    final module = safeText(item['module'], '').toLowerCase();

    if (module == 'customer' || module == 'customers') {
      return 'Customers';
    } else if (module == 'tender' || module == 'tenders') {
      return 'Tenders';
    } else if (module == 'lead' || module == 'leads') {
      return 'Leads';
    } else if (module == 'travel') {
      return 'Travel Requests';
    } else if (module == 'tada') {
      return 'TA/DA Claims';
    } else if (module == 'emdbg') {
      return 'EMD / BG';
    } else if (module == 'quotation') {
      return 'Quotations';
    } else {
      return 'Others';
    }
  }

  Widget groupedPendingList() {
    if (loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pending.isEmpty) {
      return emptyState(
        title: 'All caught up!',
        subtitle: 'No pending approvals.',
        icon: Icons.check_circle_outline,
        color: const Color(0xff10B981),
      );
    }

    final visiblePending = pending.take(pendingVisibleCount).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final item in visiblePending) {
      final key = groupKeyForApproval(item);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 250) {
          loadMorePendingFromLocal();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => loadPending(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ...grouped.entries.map((entry) {
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
                            color: ApprovalUiColors.textSoft,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Divider(
                            color: ApprovalUiColors.border,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffEEF2FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${entry.value.length}',
                            style: const TextStyle(
                              color: ApprovalUiColors.primaryLight,
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
            }),

            if (pendingVisibleCount < pending.length)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 30),
                child: Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ApprovalUiColors.primaryLight,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget historyList() {
    if (loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (history.isEmpty) {
      return emptyState(
        title: 'No approval history yet',
        subtitle: 'Approved and rejected requests will appear here.',
        icon: Icons.history,
        color: ApprovalUiColors.textSoft,
      );
    }

    final visibleHistory = history.take(historyVisibleCount).toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 250) {
          loadMoreHistoryFromLocal();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: loadHistory,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: visibleHistory.length +
              (historyVisibleCount < history.length ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == visibleHistory.length) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 30),
                child: Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ApprovalUiColors.primaryLight,
                    ),
                  ),
                ),
              );
            }

            return approvalCard(
              visibleHistory[index],
              historyMode: true,
            );
          },
        ),
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
                    child: Icon(
                      icon,
                      color: color,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ApprovalUiColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ApprovalUiColors.textSoft,
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
      backgroundColor: ApprovalUiColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ApprovalUiColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Approvals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: refreshing ? null : refreshAll,
            icon: refreshing
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
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
                border: Border.all(
                  color: Colors.white.withOpacity(.14),
                ),
              ),
              child: TabBar(
                controller: tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: ApprovalUiColors.primaryDark,
                unselectedLabelColor: Colors.white.withOpacity(.78),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    text: pending.isEmpty
                        ? 'Pending'
                        : 'Pending (${pending.length})',
                  ),
                  const Tab(text: 'History'),
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