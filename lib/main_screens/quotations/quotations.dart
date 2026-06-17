import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF0B1F3A);
  static const Color primaryDeep = Color(0xFF07172C);
  static const Color primaryMedium = Color(0xFF174A7C);
  static const Color primarySlate = Color(0xFF334155);
  static const Color primaryLight = Color(0xFF2F80ED);

  static const Color pageBg = Color(0xFFF3F6FB);
  static const Color cardBg = Colors.white;
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color borderSoft = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color purple = Color(0xFF7C3AED);
  static const Color cyan = Color(0xFF06B6D4);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF2F80ED),
      Color(0xFF174A7C),
      Color(0xFF0B1F3A),
      Color(0xFF07172C),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [
      Color(0xFF2F80ED),
      Color(0xFF174A7C),
      Color(0xFF0B1F3A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF0B1F3A).withOpacity(0.12),
      blurRadius: 30,
      offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0B1F3A).withOpacity(0.07),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get liftedShadow => [
    BoxShadow(
      color: const Color(0xFF0B1F3A).withOpacity(0.10),
      blurRadius: 32,
      offset: const Offset(0, 18),
    ),
  ];
}


class Quotation extends StatefulWidget {
  const Quotation({super.key});

  @override
  State<Quotation> createState() => _QuotationState();
}

class _QuotationState extends State<Quotation> {

  static const String baseUrl =  'https://ascent.crm.azcentrix.com:4447/api/v1';

  String? token;
  String? tenantSlug;
  bool loading = false;
  bool showCreateForm = false;

  List<Map<String, dynamic>> quotations = [];
  List<Map<String, dynamic>> groups = [];

  String activeCard = 'all';
  String search = '';
  String customerFilter = '';
  String stageFilter = '';
  DateTime? fromDate;
  DateTime? toDate;

  Map<String, dynamic>? selectedGroup;

  final currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    getSharedPref();
  }

  Future<void> getSharedPref() async {
    setState(() => loading = true);

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    tenantSlug = prefs.getString('tenant_slug') ?? '';

    if (token == null || token!.isEmpty) {
      if (mounted) setState(() => loading = false);
      showSnack('Token not found', error: true);
      return;
    }
    if (tenantSlug == null || tenantSlug!.isEmpty) {
      if (mounted) setState(() => loading = false);
      showSnack('Tenant slug not found', error: true);
      return;
    }

    await loadQuotations();
  }

  Map<String, String> get headers => {
    if (token != null && token!.isNotEmpty)
      'Authorization': 'Bearer $token',
    if (tenantSlug != null && tenantSlug!.isNotEmpty)
      'X-Tenant-Slug': tenantSlug!,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Uri apiUri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> apiGet(String path) async {
    final res = await http.get(apiUri(path), headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(parseError(res.body));
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> apiPost(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      apiUri(path),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(parseError(res.body));
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> apiPut(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      apiUri(path),
      headers: headers,
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(parseError(res.body));
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  String parseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['detail']?.toString() ?? 'Something went wrong';
    } catch (_) {
      return 'Something went wrong';
    }
  }

  void showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: error ? AppColors.danger : AppColors.success,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> loadQuotations() async {
    setState(() => loading = true);
    try {
      final data = await apiGet('/quotations/all');
      quotations = List<Map<String, dynamic>>.from(data ?? []);
      buildGroups();
    } catch (e) {
      showSnack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void buildGroups() {
    final Map<String, Map<String, dynamic>> map = {};

    for (final q in quotations) {
      final leadId = q['lead_id'];
      final tenderId = q['tender_id'];
      final key = leadId != null
          ? 'lead_$leadId'
          : tenderId != null
          ? 'tender_$tenderId'
          : 'none_${q['id']}';

      map.putIfAbsent(key, () {
        return {
          'key': key,
          'source_type': q['source_type'] ?? 'opportunity',
          'sourceRef': q['lead_ref_id'] ?? q['tender_num'] ?? '',
          'sourceTitle': q['lead_title'] ?? q['tender_title'] ?? q['subject'] ?? '',
          'customer': q['customer_name'] ?? '',
          'customer_id': q['customer_id'],
          'quotations': <Map<String, dynamic>>[],
        };
      });

      (map[key]!['quotations'] as List<Map<String, dynamic>>).add(q);
    }

    groups = map.values.map((g) {
      final revs = List<Map<String, dynamic>>.from(g['quotations']);
      revs.sort((a, b) {
        final ar = int.tryParse('${a['revision_number'] ?? 0}') ?? 0;
        final br = int.tryParse('${b['revision_number'] ?? 0}') ?? 0;
        return br.compareTo(ar);
      });

      final latest = revs.isNotEmpty ? revs.first : <String, dynamic>{};
      final approval = latest['approval_status']?.toString() ?? 'none';
      final status = latest['status']?.toString() ?? '—';

      String latestStatus;
      if (approval == 'pending') {
        latestStatus = 'Approval Pending';
      } else if (approval == 'rejected') {
        latestStatus = 'Approval Rejected';
      } else {
        latestStatus = status;
      }

      return {
        ...g,
        'quotations': revs,
        'latest': latest,
        'latestStatus': latestStatus,
        'revisionCount': revs.length,
        'totalValue': toDouble(latest['total_amount']),
      };
    }).toList();

    groups.sort((a, b) {
      final ad = '${a['latest']?['created_at'] ?? ''}';
      final bd = '${b['latest']?['created_at'] ?? ''}';
      return bd.compareTo(ad);
    });

    setState(() {});
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String fmtDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';
    try {
      final dt = DateTime.parse(value.toString());
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return value.toString().split('T').first;
    }
  }

  String shortMoney(double value) {
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(0)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

  List<Map<String, dynamic>> get filteredGroups {
    return groups.where((g) {
      final latest = Map<String, dynamic>.from(g['latest'] ?? {});
      final sourceType = '${g['source_type'] ?? ''}';
      final customer = '${g['customer'] ?? ''}'.toLowerCase();
      final title = '${g['sourceTitle'] ?? ''}'.toLowerCase();
      final ref = '${g['sourceRef'] ?? ''}'.toLowerCase();
      final latestStatus = '${g['latestStatus'] ?? ''}';
      final status = '${latest['status'] ?? ''}';
      final approval = '${latest['approval_status'] ?? 'none'}';

      if (activeCard == 'opportunity' && sourceType != 'opportunity') return false;
      if (activeCard == 'approval' && (approval == 'none' || approval.isEmpty)) return false;
      if (activeCard == 'Approval Pending' && approval != 'pending') return false;
      if (activeCard != 'all' &&
          activeCard != 'opportunity' &&
          activeCard != 'approval' &&
          activeCard != 'Approval Pending' &&
          status != activeCard) {
        return false;
      }

      if (customerFilter.isNotEmpty && customer != customerFilter.toLowerCase()) {
        return false;
      }

      if (stageFilter.isNotEmpty) {
        if (stageFilter == 'Approval Pending' && approval != 'pending') return false;
        if (stageFilter == 'Approval Rejected' && approval != 'rejected') return false;
        if (stageFilter != 'Approval Pending' &&
            stageFilter != 'Approval Rejected' &&
            status != stageFilter) {
          return false;
        }
      }

      if (search.trim().isNotEmpty) {
        final s = search.toLowerCase();
        if (!customer.contains(s) && !title.contains(s) && !ref.contains(s) && !latestStatus.toLowerCase().contains(s)) {
          return false;
        }
      }

      final createdRaw = latest['created_at']?.toString();
      if (createdRaw != null && createdRaw.isNotEmpty) {
        DateTime? created;
        try {
          created = DateTime.parse(createdRaw);
        } catch (_) {}
        if (created != null) {
          if (fromDate != null && created.isBefore(DateTime(fromDate!.year, fromDate!.month, fromDate!.day))) {
            return false;
          }
          if (toDate != null) {
            final end = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);
            if (created.isAfter(end)) return false;
          }
        }
      }

      return true;
    }).toList();
  }

  List<String> get customers {
    final set = <String>{};
    for (final g in groups) {
      final c = '${g['customer'] ?? ''}';
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get kpiCards {
    double valueWhere(bool Function(Map<String, dynamic>) test) {
      return groups.where(test).fold(0.0, (sum, g) => sum + toDouble(g['totalValue']));
    }

    return [
      {
        'key': 'all',
        'label': 'All',
        'count': groups.length,
        'value': groups.fold(0.0, (sum, g) => sum + toDouble(g['totalValue'])),
        'color': Colors.blue,
      },
      {
        'key': 'opportunity',
        'label': 'Opportunity',
        'count': groups.where((g) => g['source_type'] == 'opportunity').length,
        'value': valueWhere((g) => g['source_type'] == 'opportunity'),
        'color': Colors.indigo,
      },
      {
        'key': 'approval',
        'label': 'Approval',
        'count': groups.where((g) {
          final a = '${g['latest']?['approval_status'] ?? 'none'}';
          return a != 'none' && a.isNotEmpty;
        }).length,
        'value': valueWhere((g) {
          final a = '${g['latest']?['approval_status'] ?? 'none'}';
          return a != 'none' && a.isNotEmpty;
        }),
        'color': Colors.green,
      },
      {
        'key': 'Approval Pending',
        'label': 'Pending',
        'count': groups.where((g) => g['latest']?['approval_status'] == 'pending').length,
        'value': valueWhere((g) => g['latest']?['approval_status'] == 'pending'),
        'color': Colors.amber,
      },
      {
        'key': 'Draft',
        'label': 'Draft',
        'count': groups.where((g) => g['latest']?['status'] == 'Draft').length,
        'value': valueWhere((g) => g['latest']?['status'] == 'Draft'),
        'color': Colors.grey,
      },
    ];
  }

  Color statusColor(String status, String approval) {
    if (approval == 'pending') return Colors.amber;
    if (approval == 'approved') return Colors.green;
    if (approval == 'rejected') return Colors.red;

    switch (status) {
      case 'Draft':
        return Colors.grey;
      case 'Sent':
        return Colors.blue;
      case 'Approved':
        return Colors.indigo;
      case 'Accepted':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void clearFilters() {
    setState(() {
      activeCard = 'all';
      customerFilter = '';
      stageFilter = '';
      fromDate = null;
      toDate = null;
      search = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showCreateForm) {
      return QuotationFormScreen(
        baseUrl: baseUrl,
        headers: headers,
        apiGet: apiGet,
        apiPost: apiPost,
        apiPut: apiPut,
        onBack: () => setState(() => showCreateForm = false),
        onSaved: () async {
          setState(() => showCreateForm = false);
          await loadQuotations();
        },
        showSnack: showSnack,
      );
    }

    if (selectedGroup != null) {
      final liveGroup = groups.firstWhere(
            (g) => g['key'] == selectedGroup!['key'],
        orElse: () => selectedGroup!,
      );

      return QuotationDetailScreen(
        group: liveGroup,
        currency: currency,
        fmtDate: fmtDate,
        toDouble: toDouble,
        toInt: toInt,
        apiPost: apiPost,
        apiPut: apiPut,
        apiGet: apiGet,
        headers: headers,
        baseUrl: baseUrl,
        showSnack: showSnack,
        onBack: () => setState(() => selectedGroup = null),
        onRefresh: loadQuotations,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 66,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryDark,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
          ),
        ),
        title: const Text(
          'Quotations',
          style: TextStyle(fontWeight: FontWeight.w700,color: Colors.white),
        ),
        leading: IconButton(onPressed: (){Navigator.pop(context);},
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: loading ? null : loadQuotations,
            icon: loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.refresh,color: Colors.white),
          ),
          IconButton(
            onPressed: () => setState(() => showCreateForm = true),
            icon: const Icon(Icons.add,color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadQuotations,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          children: [
            buildSearchBox(),
            const SizedBox(height: 12),
            buildKpiCards(),
            const SizedBox(height: 12),
            buildFilters(),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredGroups.isEmpty)
              buildEmpty()
            else
              ...filteredGroups.map(buildGroupCard),
          ],
        ),
      ),

    /*  floatingActionButton: FloatingActionButton.extended(
        elevation: 10,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () => setState(() => showCreateForm = true),
        icon: const Icon(Icons.add),
        label: const Text('New Quotation'),
      ),*/
    );
  }

  Widget buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppColors.cardShadow,
      ),
      child: TextField(
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search quotation, customer, source...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.search_rounded, color: AppColors.primaryLight),
          ),
          suffixIcon: search.isNotEmpty
              ? IconButton(
            onPressed: () => setState(() => search = ''),
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => search = v),
      ),
    );
  }

  Widget buildKpiCards() {
    return SizedBox(
      height: 124, // increased from 118
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kpiCards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final card = kpiCards[i];
          final key = card['key'].toString();
          final color = card['color'] as Color;
          final selected = activeCard == key;

          return GestureDetector(
            onTap: () => setState(() => activeCard = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 138,
              padding: const EdgeInsets.all(13), // reduced from 15
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                  colors: [
                    color.withOpacity(.95),
                    color.withOpacity(.72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? Colors.transparent : color.withOpacity(.16),
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: color.withOpacity(.25),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ]
                    : AppColors.cardShadow,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? Colors.white.withOpacity(.16)
                            : color.withOpacity(.08),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        key == 'all'
                            ? Icons.dashboard_rounded
                            : key == 'opportunity'
                            ? Icons.work_rounded
                            : key == 'approval'
                            ? Icons.verified_user_rounded
                            : key == 'Approval Pending'
                            ? Icons.pending_actions_rounded
                            : Icons.edit_document,
                        color: selected ? Colors.white : color,
                        size: 20, // reduced from 21
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${card['count']}',
                          style: TextStyle(
                            color: selected ? Colors.white : color,
                            fontSize: 26, // reduced from 28
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card['label'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withOpacity(.86)
                              : AppColors.textDark,
                          fontSize: 11.5,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shortMoney(toDouble(card['value'])),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white.withOpacity(.72)
                              : AppColors.textMuted,
                          fontSize: 10.5,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildFilters() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Filter Quotations',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: clearFilters,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: customerFilter.isEmpty ? null : customerFilter,
                  isExpanded: true,
                  decoration: inputDecoration('Customer'),
                  selectedItemBuilder: (context) => customers
                      .map((c) => Text(
                    c,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ))
                      .toList(),
                  items: customers
                      .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => customerFilter = v ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: stageFilter.isEmpty ? null : stageFilter,
                  isExpanded: true,
                  decoration: inputDecoration('Stage'),
                  selectedItemBuilder: (context) => ['Draft', 'Sent', 'Accepted', 'Approval Pending', 'Approval Rejected']
                      .map((s) => Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ))
                      .toList(),
                  items: ['Draft', 'Sent', 'Accepted', 'Approval Pending', 'Approval Rejected']
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => stageFilter = v ?? ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: dateButton('From', fromDate, (d) => setState(() => fromDate = d))),
              const SizedBox(width: 10),
              Expanded(child: dateButton('To', toDate, (d) => setState(() => toDate = d))),
            ],
          ),
        ],
      ),
    );
  }

  Widget dateButton(String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        onPicked(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: inputDecoration(label).copyWith(
          prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18),
        ),
        child: Text(
          value == null ? label : DateFormat('dd MMM yyyy').format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null ? AppColors.textMuted : AppColors.textDark,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4),
      ),
    );
  }

  Widget buildGroupCard(Map<String, dynamic> g) {
    final latest = Map<String, dynamic>.from(g['latest'] ?? {});
    final status = '${latest['status'] ?? '—'}';
    final approval = '${latest['approval_status'] ?? 'none'}';
    final color = statusColor(status, approval);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => setState(() => selectedGroup = g),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(.95), color.withOpacity(.65)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(.18),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${g['sourceTitle'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.25,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${g['customer'] ?? '—'}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(.08),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryLight),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip(g['source_type'] == 'tender' ? 'Tender' : 'Opportunity', AppColors.primaryLight),
                    chip('${g['sourceRef'] ?? '—'}', AppColors.primaryMedium),
                    chip('${g['revisionCount']} Rev', AppColors.purple),
                    chip('${g['latestStatus'] ?? status}', color),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Latest Value',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        currency.format(toDouble(g['totalValue'])),
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      fmtDate(latest['created_at']),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget buildEmpty() {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.description_outlined, size: 38, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'No quotations found',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try changing filters or create a new quotation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class QuotationDetailScreen extends StatefulWidget {
  const QuotationDetailScreen({
    super.key,
    required this.group,
    required this.currency,
    required this.fmtDate,
    required this.toDouble,
    required this.toInt,
    required this.apiPost,
    required this.apiPut,
    required this.apiGet,
    required this.headers,
    required this.baseUrl,
    required this.showSnack,
    required this.onBack,
    required this.onRefresh,
  });

  final Map<String, dynamic> group;
  final NumberFormat currency;
  final String Function(dynamic) fmtDate;
  final double Function(dynamic) toDouble;
  final int Function(dynamic) toInt;
  final Future<dynamic> Function(String, [Map<String, dynamic>?]) apiPost;
  final Future<dynamic> Function(String, Map<String, dynamic>) apiPut;
  final Future<dynamic> Function(String) apiGet;
  final Map<String, String> headers;
  final String baseUrl;
  final void Function(String, {bool error}) showSnack;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  int? expandedId;
  int? editingId;
  bool actionLoading = false;

  List<Map<String, dynamic>> get revisions {
    final list = List<Map<String, dynamic>>.from(widget.group['quotations'] ?? []);
    list.sort((a, b) => widget.toInt(a['revision_number']).compareTo(widget.toInt(b['revision_number'])));
    return list;
  }

  bool get hasApproved {
    return revisions.any((q) {
      return q['approval_status'] == 'approved' ||
          q['status'] == 'Accepted' ||
          q['status'] == 'Approved';
    });
  }

  int get maxRevision {
    if (revisions.isEmpty) return 1;
    return revisions.map((q) => widget.toInt(q['revision_number'])).reduce((a, b) => a > b ? a : b);
  }

  Future<void> performAction(String path, String success) async {
    setState(() => actionLoading = true);
    try {
      await widget.apiPost(path);
      widget.showSnack(success);
      await widget.onRefresh();
      setState(() {});
    } catch (e) {
      widget.showSnack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> requestApproval(Map<String, dynamic> q) async {
    final notesController = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Submit for Approval',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Submit'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    await performAction(
      '/quotations/${q['id']}/request-approval',
      'Approval request submitted',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (editingId != null) {
      final q = revisions.firstWhere((x) => x['id'] == editingId);
      return QuotationFormScreen(
        baseUrl: widget.baseUrl,
        headers: widget.headers,
        apiGet: widget.apiGet,
        apiPost: widget.apiPost,
        apiPut: widget.apiPut,
        editQuotation: q,
        showSnack: widget.showSnack,
        onBack: () => setState(() => editingId = null),
        onSaved: () async {
          setState(() => editingId = null);
          await widget.onRefresh();
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 66,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryDark,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
          ),
        ),
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        title: const Text('Quotation History',style: TextStyle(color: Colors.white),),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          children: [
            buildHeaderCard(),
            const SizedBox(height: 12),
            ...revisions.map(buildRevisionCard),
          ],
        ),
      ),
    );
  }

  Widget buildHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.premiumGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.group['sourceRef'] ?? '—'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(.72),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${widget.group['sourceTitle'] ?? 'Quotation'}',
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.business_rounded, color: Colors.white70, size: 17),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${widget.group['customer'] ?? '—'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRevisionCard(Map<String, dynamic> q) {
    final id = widget.toInt(q['id']);
    final isExpanded = expandedId == id;
    final status = '${q['status'] ?? ''}';
    final approval = '${q['approval_status'] ?? 'none'}';
    final isDraft = status == 'Draft';
    final isApproved = approval == 'approved' || status == 'Accepted';
    final canRevise = approval == 'rejected' &&
        widget.toInt(q['revision_number']) < 3 &&
        !hasApproved &&
        widget.toInt(q['revision_number']) == maxRevision;

    final color = approval == 'pending'
        ? Colors.amber
        : approval == 'rejected'
        ? Colors.red
        : approval == 'approved'
        ? Colors.green
        : status == 'Draft'
        ? Colors.grey
        : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => expandedId = isExpanded ? null : id),
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(.1),
              child: Text(
                'Q${q['revision_number']}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.purple),
              ),
            ),
            title: Text(
              '${q['quotation_number'] ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(widget.fmtDate(q['created_at'])),
            trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    badge(
                      approval == 'pending'
                          ? 'Approval Pending'
                          : approval == 'rejected'
                          ? 'Approval Rejected'
                          : approval == 'approved'
                          ? 'Approved'
                          : status,
                      color,
                    ),
                    const Spacer(),
                    Text(
                      widget.currency.format(widget.toDouble(q['total_amount'])),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isApproved)
                      actionButton(
                        icon: Icons.visibility,
                        label: 'Letter Pad',
                        color: Colors.indigo,
                        onTap: () => showLetterPad(q),
                      ),
                    if (isDraft)
                      actionButton(
                        icon: Icons.edit,
                        label: 'Edit',
                        color: Colors.blue,
                        onTap: () => setState(() => editingId = id),
                      ),
                    if (isDraft)
                      actionButton(
                        icon: Icons.send,
                        label: 'Send',
                        color: Colors.blue,
                        onTap: () => performAction('/quotations/$id/send', 'Marked as Sent'),
                      ),
                    if ((isDraft || status == 'Sent') && !hasApproved && (approval == 'none' || approval.isEmpty))
                      actionButton(
                        icon: Icons.verified_user,
                        label: 'Approval',
                        color: Colors.amber,
                        onTap: () => requestApproval(q),
                      ),
                    if (canRevise)
                      actionButton(
                        icon: Icons.copy,
                        label: 'Revise Q${widget.toInt(q['revision_number']) + 1}',
                        color: Colors.purple,
                        onTap: () => performAction('/quotations/$id/revise', 'New revision created'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isExpanded) buildExpanded(q),
        ],
      ),
    );
  }

  Widget buildExpanded(Map<String, dynamic> q) {
    final items = List<Map<String, dynamic>>.from(q['line_items'] ?? []);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (q['approval_status'] == 'rejected' && '${q['rejection_reason'] ?? ''}'.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                'Rejected Reason: ${q['rejection_reason']}',
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700),
              ),
            ),
          const Text('Line Items', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item['description'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: smallInfo('Qty', '${item['quantity'] ?? 0}')),
                      Expanded(child: smallInfo('Unit', widget.currency.format(widget.toDouble(item['unit_price'])))),
                      Expanded(child: smallInfo('Tax', '${item['tax_percent'] ?? 0}%')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.currency.format(widget.toDouble(item['line_total'])),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          totalRow('Subtotal', q['amount']),
          totalRow('Tax', q['tax_amount']),
          totalRow('Total', q['total_amount'], bold: true),
        ],
      ),
    );
  }

  Widget totalRow(String label, dynamic value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500)),
          const Spacer(),
          Text(
            widget.currency.format(widget.toDouble(value)),
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget smallInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        border: Border.all(color: color.withOpacity(.25)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }

  Widget actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: actionLoading ? null : onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(.06),
        side: BorderSide(color: color.withOpacity(.20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void showLetterPad(Map<String, dynamic> q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuotationLetterPadView(
        quotation: q,
        currency: widget.currency,
        toDouble: widget.toDouble,
        fmtDate: widget.fmtDate,
      ),
    );
  }
}

class QuotationFormScreen extends StatefulWidget {
  const QuotationFormScreen({
    super.key,
    required this.baseUrl,
    required this.headers,
    required this.apiGet,
    required this.apiPost,
    required this.apiPut,
    required this.onBack,
    required this.onSaved,
    required this.showSnack,
    this.editQuotation,
  });

  final String baseUrl;
  final Map<String, String> headers;
  final Future<dynamic> Function(String) apiGet;
  final Future<dynamic> Function(String, [Map<String, dynamic>?]) apiPost;
  final Future<dynamic> Function(String, Map<String, dynamic>) apiPut;
  final VoidCallback onBack;
  final Future<void> Function() onSaved;
  final void Function(String, {bool error}) showSnack;
  final Map<String, dynamic>? editQuotation;

  @override
  State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends State<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool loading = false;
  bool saving = false;
  bool submitApproval = false;
  bool letterPadOpen = false;

  String sourceType = 'opportunity';
  int? selectedSourceId;

  List<Map<String, dynamic>> opportunities = [];
  List<Map<String, dynamic>> tenders = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> companyAddresses = [];

  final subjectCtrl = TextEditingController();
  final validUntilCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  final refCtrl = TextEditingController();
  final customerToCtrl = TextEditingController();
  final customerAddressCtrl = TextEditingController();
  final greetingCtrl = TextEditingController(
    text: 'Dear Sir,\n\nGreetings!\n\nWe are pleased to submit our commercial proposal for the same.',
  );
  final companyAddressTextCtrl = TextEditingController();

  int? signatoryId;
  int? companyAddressId;

  List<LineItemData> lines = [LineItemData()];
  List<TextEditingController> termsControllers = [TextEditingController()];

  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  bool get isEdit => widget.editQuotation != null;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    setState(() => loading = true);

    try {
      if (!isEdit) {
        final opp = await widget.apiGet('/quotations/opportunities-dropdown');
        opportunities = List<Map<String, dynamic>>.from(opp ?? []);

        try {
          final ten = await widget.apiGet('/tenders/dropdown');
          tenders = List<Map<String, dynamic>>.from(ten ?? []);
        } catch (_) {}
      }

      try {
        final u = await widget.apiGet('/masters/users-for-select');
        users = List<Map<String, dynamic>>.from(u ?? []);
      } catch (_) {}

      try {
        final addr = await widget.apiGet('/settings/company-addresses');
        companyAddresses = List<Map<String, dynamic>>.from(addr?['addresses'] ?? []);
        final primary = companyAddresses.cast<Map<String, dynamic>?>().firstWhere(
              (a) => a?['is_primary'] == true,
          orElse: () => companyAddresses.isNotEmpty ? companyAddresses.first : null,
        );
        if (!isEdit && primary != null) {
          companyAddressId = toIntOrNull(primary['id']);
          companyAddressTextCtrl.text = formatCompanyAddress(primary);
        }
      } catch (_) {}

      if (isEdit) fillEditData(widget.editQuotation!);
    } catch (e) {
      widget.showSnack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void fillEditData(Map<String, dynamic> q) {
    subjectCtrl.text = '${q['subject'] ?? ''}';
    validUntilCtrl.text = '${q['valid_until'] ?? ''}'.split('T').first;
    if (validUntilCtrl.text == 'null') validUntilCtrl.clear();

    notesCtrl.text = '${q['notes'] ?? ''}';
    refCtrl.text = '${q['ref_number'] ?? ''}';
    customerToCtrl.text = '${q['customer_to_name'] ?? q['customer_name'] ?? ''}';
    customerAddressCtrl.text = '${q['customer_address_text'] ?? ''}';
    greetingCtrl.text = '${q['greeting_text'] ?? greetingCtrl.text}';
    signatoryId = toIntOrNull(q['signatory_user_id']);
    companyAddressId = toIntOrNull(q['company_address_id']);
    companyAddressTextCtrl.text = '${q['company_address_text'] ?? q['company_address_override'] ?? ''}';

    final items = List<Map<String, dynamic>>.from(q['line_items'] ?? []);
    lines = items.isEmpty
        ? [LineItemData()]
        : items.map((i) {
      return LineItemData(
        description: '${i['description'] ?? ''}',
        quantity: '${i['quantity'] ?? 1}',
        unitPrice: '${i['unit_price'] ?? 0}',
        taxPercent: '${i['tax_percent'] ?? 0}',
      );
    }).toList();

    final terms = '${q['terms_conditions'] ?? ''}'
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    termsControllers = terms.isEmpty
        ? [TextEditingController()]
        : terms.map((e) => TextEditingController(text: e)).toList();
  }

  int? toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String formatCompanyAddress(Map<String, dynamic> a) {
    return [
      a['street_address'],
      a['area_locality'],
      a['city_district'],
      a['state'],
      a['pincode'],
      a['country'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
  }

  String companyAddressLabel(Map<String, dynamic> a) {
    return [
      a['address_name'] ?? a['branch_name'] ?? 'Address #${a['id']}',
      a['is_primary'] == true ? 'Primary' : '',
      a['city_district'],
      a['state'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' · ');
  }

  double get subtotal => lines.fold(0, (s, l) => s + l.base);
  double get taxTotal => lines.fold(0, (s, l) => s + l.taxAmount);
  double get grandTotal => subtotal + taxTotal;

  void onSourceSelected(int? id) {
    setState(() => selectedSourceId = id);
    if (id == null) return;

    if (sourceType == 'opportunity') {
      final opp = opportunities.firstWhere((o) => toIntOrNull(o['id']) == id, orElse: () => {});
      if (opp.isEmpty) return;

      if ('${opp['customer_name'] ?? ''}'.isNotEmpty) {
        customerToCtrl.text = '${opp['customer_name']}';
      }

      final products = List<Map<String, dynamic>>.from(opp['products'] ?? []);
      if (products.isNotEmpty) {
        setState(() {
          lines = products.map((p) {
            return LineItemData(
              description: '${p['product_name'] ?? p['description'] ?? ''}',
              quantity: '${p['quantity'] ?? 1}',
              unitPrice: '${p['unit_price'] ?? 0}',
              taxPercent: '${p['gst_percent'] ?? 0}',
            );
          }).toList();
        });
      }
    } else {
      final tender = tenders.firstWhere((t) => toIntOrNull(t['id']) == id, orElse: () => {});
      if (tender.isEmpty) return;

      final products = List<Map<String, dynamic>>.from(tender['products'] ?? []);
      if (products.isNotEmpty) {
        setState(() {
          lines = products.map((p) {
            return LineItemData(
              description: '${p['product_name'] ?? p['description'] ?? ''}',
              quantity: '${p['quantity'] ?? 1}',
              unitPrice: '${p['unit_price'] ?? 0}',
              taxPercent: '${p['gst_percent'] ?? 0}',
            );
          }).toList();
        });
      }
    }
  }

  Map<String, dynamic> buildPayload() {
    Map<String, dynamic>? selected;

    if (!isEdit) {
      selected = sourceType == 'opportunity'
          ? opportunities.firstWhere((o) => toIntOrNull(o['id']) == selectedSourceId, orElse: () => {})
          : tenders.firstWhere((t) => toIntOrNull(t['id']) == selectedSourceId, orElse: () => {});
    }

    final payload = <String, dynamic>{
      'subject': subjectCtrl.text.trim().isEmpty
          ? 'Quotation for ${selected?['lead_title'] ?? selected?['tender_title'] ?? ''}'
          : subjectCtrl.text.trim(),
      'amount': subtotal,
      'tax_amount': taxTotal,
      'total_amount': grandTotal,
      'valid_until': validUntilCtrl.text.trim().isEmpty ? null : validUntilCtrl.text.trim(),
      'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      'terms_conditions': termsControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n')
          .trim()
          .isEmpty
          ? null
          : termsControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join('\n'),
      'ref_number': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
      'customer_to_name': customerToCtrl.text.trim().isEmpty ? null : customerToCtrl.text.trim(),
      'customer_address_text': customerAddressCtrl.text.trim().isEmpty ? null : customerAddressCtrl.text.trim(),
      'greeting_text': greetingCtrl.text.trim().isEmpty ? null : greetingCtrl.text.trim(),
      'signatory_user_id': signatoryId,
      'company_address_id': companyAddressId,
      'company_address_text': companyAddressTextCtrl.text.trim().isEmpty ? null : companyAddressTextCtrl.text.trim(),
      'line_items': lines.asMap().entries.map((entry) {
        final i = entry.key;
        final l = entry.value;
        return {
          'description': l.descriptionCtrl.text.trim(),
          'quantity': toDouble(l.quantityCtrl.text) == 0 ? 1 : toDouble(l.quantityCtrl.text),
          'unit_price': toDouble(l.unitPriceCtrl.text),
          'tax_percent': toDouble(l.taxCtrl.text),
          'sort_order': i,
        };
      }).toList(),
    };

    if (!isEdit) {
      if (sourceType == 'opportunity') {
        payload['lead_id'] = selectedSourceId;
        payload['customer_id'] = selected?['customer_id'];
      } else {
        payload['tender_id'] = selectedSourceId;
        payload['customer_id'] = selected?['customer_id'];
      }
    }

    return payload;
  }

  Future<void> save({bool approval = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (!isEdit && selectedSourceId == null) {
      widget.showSnack(sourceType == 'opportunity' ? 'Select an opportunity' : 'Select a tender', error: true);
      return;
    }

    if (lines.where((l) => l.descriptionCtrl.text.trim().isNotEmpty).isEmpty) {
      widget.showSnack('At least one line item is required', error: true);
      return;
    }

    setState(() {
      saving = true;
      submitApproval = approval;
    });

    try {
      if (isEdit) {
        await widget.apiPut('/quotations/${widget.editQuotation!['id']}', buildPayload());
        widget.showSnack('Quotation updated');
      } else {
        final created = await widget.apiPost('/quotations', buildPayload());
        if (approval && created?['id'] != null) {
          try {
            await widget.apiPost('/quotations/${created['id']}/request-approval');
            widget.showSnack('Quotation created and submitted for approval');
          } catch (e) {
            widget.showSnack('Quotation created. Approval request failed.', error: true);
          }
        } else {
          widget.showSnack('Quotation created');
        }
      }

      await widget.onSaved();
    } catch (e) {
      widget.showSnack(e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          submitApproval = false;
        });
      }
    }
  }

  Future<void> pickValidDate() async {
    DateTime initial = DateTime.now();
    try {
      if (validUntilCtrl.text.isNotEmpty) {
        initial = DateTime.parse(validUntilCtrl.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      validUntilCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEdit ? 'Edit Quotation' : 'New Quotation (Q1)';

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 66,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryDark,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
          ),
        ),
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          children: [
            if (!isEdit) buildSourceSection(),
            buildBasicSection(),
            buildLineItemsSection(),
            buildTermsSection(),
            buildLetterPadSection(),
            buildNotesSection(),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12, offset: const Offset(0, -4)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : widget.onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.borderSoft),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: saving ? null : () => save(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: saving && !submitApproval
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEdit ? 'Update' : 'Save'),
                ),
              ),
              if (!isEdit) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : () => save(approval: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: saving && submitApproval
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSourceSection() {
    final sourceList = sourceType == 'opportunity' ? opportunities : tenders;

    return formCard(
      title: 'Source',
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'opportunity', label: Text('Opportunity'), icon: Icon(Icons.work_outline)),
              ButtonSegment(value: 'tender', label: Text('Tender'), icon: Icon(Icons.assignment_outlined)),
            ],
            selected: {sourceType},
            onSelectionChanged: (s) {
              setState(() {
                sourceType = s.first;
                selectedSourceId = null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: selectedSourceId,
            isExpanded: true,
            decoration: inputDecoration(sourceType == 'opportunity' ? 'Select Opportunity *' : 'Select Tender *'),
            items: sourceList.map((item) {
              final id = toIntOrNull(item['id']);
              final label = sourceType == 'opportunity'
                  ? '${item['lead_ref_id'] ?? ''} — ${item['lead_title'] ?? ''} (${item['customer_name'] ?? ''})'
                  : '${item['tender_num'] ?? ''} — ${item['tender_title'] ?? ''} (${item['customer_name'] ?? ''})';
              return DropdownMenuItem<int>(
                value: id,
                child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: onSourceSelected,
          ),
        ],
      ),
    );
  }

  Widget buildBasicSection() {
    return formCard(
      title: 'Quotation Details',
      child: Column(
        children: [
          TextFormField(
            controller: subjectCtrl,
            decoration: inputDecoration('Subject'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: validUntilCtrl,
            readOnly: true,
            onTap: pickValidDate,
            decoration: inputDecoration('Valid Until').copyWith(
              suffixIcon: const Icon(Icons.calendar_month),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLineItemsSection() {
    return formCard(
      title: 'Line Items',
      child: Column(
        children: [
          ...lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Item ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (lines.length > 1)
                        IconButton(
                          onPressed: () => setState(() => lines.removeAt(index)),
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                    ],
                  ),
                  TextFormField(
                    controller: line.descriptionCtrl,
                    decoration: inputDecoration('Description *'),
                    validator: (v) {
                      if (index == 0 && (v == null || v.trim().isEmpty)) {
                        return 'Description required';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: line.quantityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration('Qty'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: line.unitPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration('Unit Price'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: line.taxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration('Tax %'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.primaryLight.withOpacity(.14)),
                      ),
                      child: Text(
                        'Total: ${currency.format(line.total)}',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => setState(() => lines.add(LineItemData())),
            icon: const Icon(Icons.add),
            label: const Text('Add Line Item'),
          ),
          const Divider(height: 28),
          totalRow('Subtotal', subtotal),
          totalRow('Tax', taxTotal),
          totalRow('Grand Total', grandTotal, bold: true),
          if (grandTotal > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${numberToWords(grandTotal)} Rupees Only',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildTermsSection() {
    return formCard(
      title: 'Terms & Conditions',
      child: Column(
        children: [
          ...termsControllers.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('${i + 1}.', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: c,
                      decoration: inputDecoration(i == 0 ? 'Payment Terms...' : 'Add another point...'),
                    ),
                  ),
                  if (termsControllers.length > 1)
                    IconButton(
                      onPressed: () => setState(() => termsControllers.removeAt(i)),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => termsControllers.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Add Point'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLetterPadSection() {
    return formCard(
      title: 'Letter Pad Details',
      trailing: IconButton(
        onPressed: () => setState(() => letterPadOpen = !letterPadOpen),
        icon: Icon(letterPadOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
      ),
      child: letterPadOpen
          ? Column(
        children: [
          TextFormField(controller: refCtrl, decoration: inputDecoration('Reference Number')),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: signatoryId,
            isExpanded: true,
            decoration: inputDecoration('Signatory'),
            items: users.map((u) {
              return DropdownMenuItem<int>(
                value: toIntOrNull(u['id']),
                child: Text('${u['label'] ?? u['full_name'] ?? u['name'] ?? ''}'),
              );
            }).toList(),
            onChanged: (v) => setState(() => signatoryId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: customerToCtrl, decoration: inputDecoration('To Customer / Designation')),
          const SizedBox(height: 12),
          TextFormField(
            controller: customerAddressCtrl,
            decoration: inputDecoration('Customer Address'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: greetingCtrl,
            decoration: inputDecoration('Greeting / Opening Paragraph'),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: companyAddressId,
            isExpanded: true,
            decoration: inputDecoration('Company Address'),
            items: companyAddresses.map((a) {
              return DropdownMenuItem<int>(
                value: toIntOrNull(a['id']),
                child: Text(companyAddressLabel(a), maxLines: 2, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                companyAddressId = v;
                final found = companyAddresses.firstWhere(
                      (a) => toIntOrNull(a['id']) == v,
                  orElse: () => {},
                );
                if (found.isNotEmpty) {
                  companyAddressTextCtrl.text = formatCompanyAddress(found);
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: companyAddressTextCtrl,
            decoration: inputDecoration('Selected Address Text'),
            maxLines: 3,
          ),
        ],
      )
          : Text(
        'Tap to add reference number, customer address, greeting, signatory and company header.',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget buildNotesSection() {
    return formCard(
      title: 'Notes',
      child: TextFormField(
        controller: notesCtrl,
        maxLines: 3,
        decoration: inputDecoration('Internal notes'),
      ),
    );
  }

  Widget formCard({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.layers_rounded, size: 18, color: AppColors.primaryLight),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4),
      ),
    );
  }

  Widget totalRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          const Spacer(),
          Text(currency.format(value), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  String numberToWords(double n) {
    final num = n.abs().floor();
    if (num == 0) return 'Zero';

    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];

    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String two(int x) {
      if (x < 20) return ones[x];
      return '${tens[x ~/ 10]}${x % 10 != 0 ? ' ${ones[x % 10]}' : ''}'.trim();
    }

    String three(int x) {
      if (x == 0) return '';
      if (x < 100) return two(x);
      return '${ones[x ~/ 100]} Hundred${x % 100 != 0 ? ' ${two(x % 100)}' : ''}';
    }

    final cr = num ~/ 10000000;
    final lk = (num % 10000000) ~/ 100000;
    final th = (num % 100000) ~/ 1000;
    final rest = num % 1000;

    final parts = <String>[];
    if (cr > 0) parts.add('${three(cr)} Crore');
    if (lk > 0) parts.add('${two(lk)} Lakh');
    if (th > 0) parts.add('${two(th)} Thousand');
    if (rest > 0) parts.add(three(rest));

    return parts.join(' ');
  }
}

class LineItemData {
  LineItemData({
    String description = '',
    String quantity = '1',
    String unitPrice = '0',
    String taxPercent = '0',
  })  : descriptionCtrl = TextEditingController(text: description),
        quantityCtrl = TextEditingController(text: quantity),
        unitPriceCtrl = TextEditingController(text: unitPrice),
        taxCtrl = TextEditingController(text: taxPercent);

  final TextEditingController descriptionCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController unitPriceCtrl;
  final TextEditingController taxCtrl;

  double parse(String v) => double.tryParse(v) ?? 0;

  double get qty => parse(quantityCtrl.text);
  double get unitPrice => parse(unitPriceCtrl.text);
  double get taxPercent => parse(taxCtrl.text);
  double get base => qty * unitPrice;
  double get taxAmount => base * taxPercent / 100;
  double get total => base + taxAmount;
}

class QuotationLetterPadView extends StatelessWidget {
  const QuotationLetterPadView({
    super.key,
    required this.quotation,
    required this.currency,
    required this.toDouble,
    required this.fmtDate,
  });

  final Map<String, dynamic> quotation;
  final NumberFormat currency;
  final double Function(dynamic) toDouble;
  final String Function(dynamic) fmtDate;

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(quotation['line_items'] ?? []);
    final signatory = Map<String, dynamic>.from(quotation['signatory'] ?? {});

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .5,
      maxChildSize: .96,
      builder: (_, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Quotation Letter Pad',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Text(
              '${quotation['company_name_override'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            if ('${quotation['company_address_text'] ?? ''}'.isNotEmpty)
              Text('${quotation['company_address_text']}'),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(child: Text('Ref: ${quotation['ref_number'] ?? quotation['quotation_number'] ?? '—'}')),
                Text('Date: ${fmtDate(quotation['created_at'])}'),
              ],
            ),
            const SizedBox(height: 18),
            if ('${quotation['customer_to_name'] ?? ''}'.isNotEmpty)
              Text('${quotation['customer_to_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            if ('${quotation['customer_address_text'] ?? ''}'.isNotEmpty)
              Text('${quotation['customer_address_text']}'),
            const SizedBox(height: 18),
            Text('${quotation['greeting_text'] ?? ''}'),
            const SizedBox(height: 18),
            Text(
              '${quotation['subject'] ?? 'Quotation'}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['description'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: Text('Qty: ${item['quantity'] ?? 0}')),
                        Expanded(child: Text('Tax: ${item['tax_percent'] ?? 0}%')),
                        Text(currency.format(toDouble(item['line_total']))),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 26),
            totalRow('Subtotal', quotation['amount']),
            totalRow('Tax', quotation['tax_amount']),
            totalRow('Grand Total', quotation['total_amount'], bold: true),
            const SizedBox(height: 18),
            if ('${quotation['terms_conditions'] ?? ''}'.isNotEmpty) ...[
              const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...'${quotation['terms_conditions']}'
                  .split('\n')
                  .where((e) => e.trim().isNotEmpty)
                  .map((e) => Text('➢ $e')),
              const SizedBox(height: 24),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('For Authorised Signatory'),
                  const SizedBox(height: 34),
                  Text(
                    '${signatory['full_name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if ('${signatory['designation'] ?? ''}'.isNotEmpty)
                    Text('${signatory['designation']}'),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget totalRow(String label, dynamic value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          const Spacer(),
          Text(currency.format(toDouble(value)), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }
}