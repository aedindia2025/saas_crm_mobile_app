import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

const String kEmdbgApiBaseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1';

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

class EmdBg extends StatefulWidget {
  final String tenantSlug;
  const EmdBg({super.key, required this.tenantSlug});

  @override
  State<EmdBg> createState() => _EmdBgState();
}

class _EmdBgState extends State<EmdBg> {
  bool isLoading = true;
  bool showFilters = false;

  List<Map<String, dynamic>> records = [];

  String selectedCategory = 'All';
  String selectedInstrumentType = 'All';
  String selectedExpiryStatus = 'All';
  String searchText = '';

  final searchController = TextEditingController();

  final instrumentTypes = const [
    'All',
    'EMD',
    'Performance BG',
    'Security Deposit',
    'Advance BG',
    'Retention BG',
    'DD',
    'Online Payment',
  ];

  final expiryStatuses = const [
    'All',
    'Critical',
    'Warning',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      setState(() => isLoading = true);

      final response = await http.get(
        Uri.parse("$kEmdbgApiBaseUrl/emdbg"),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Tenant-Slug': widget.tenantSlug,
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          records = data.map((e) => Map<String, dynamic>.from(e)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        showError(response.body);
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError(e.toString());
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String getCategory(String type) {
    if (type == 'DD' || type == 'Online Payment') return 'Tender Fee';
    if (type == 'EMD') return 'EMD';
    return 'PBG';
  }

  List<Map<String, dynamic>> get filteredRecords {
    return records.where((r) {
      final type = r['instrument_type']?.toString() ?? '';
      final category = getCategory(type);
      final search = searchText.trim().toLowerCase();

      if (selectedCategory != 'All' && category != selectedCategory) {
        return false;
      }

      if (selectedInstrumentType != 'All' && type != selectedInstrumentType) {
        return false;
      }

      if (selectedExpiryStatus != 'All') {
        final expiry = r['expiry_status']?.toString() ?? '';
        if (expiry != selectedExpiryStatus) return false;
      }

      if (search.isNotEmpty) {
        final ref = r['reference_num']?.toString().toLowerCase() ?? '';
        final client = r['client_name']?.toString().toLowerCase() ?? '';
        final tender = r['tender_title']?.toString().toLowerCase() ?? '';
        final sales = r['sales_person_name']?.toString().toLowerCase() ?? '';
        final inst = r['instrument_number']?.toString().toLowerCase() ?? '';

        return ref.contains(search) ||
            client.contains(search) ||
            tender.contains(search) ||
            sales.contains(search) ||
            inst.contains(search);
      }

      return true;
    }).toList();
  }

  List<Map<String, dynamic>> byCategory(String category) {
    final list = filteredRecords.where((r) {
      final type = r['instrument_type']?.toString() ?? '';
      if (category == 'Tender Fee') return type == 'DD' || type == 'Online Payment';
      if (category == 'EMD') return type == 'EMD';
      return [
        'Performance BG',
        'Security Deposit',
        'Advance BG',
        'Retention BG',
      ].contains(type);
    }).toList();

    return list;
  }

  int categoryCount(String category) {
    if (category == 'All') return records.length;
    return records.where((r) => getCategory(r['instrument_type']?.toString() ?? '') == category).length;
  }

  String money(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '0') ?? 0;
    if (n >= 10000000) return "₹${(n / 10000000).toStringAsFixed(2)}Cr";
    if (n >= 100000) return "₹${(n / 100000).toStringAsFixed(2)}L";
    return "₹${n.toStringAsFixed(0)}";
  }

  double total(List<Map<String, dynamic>> list) {
    return list.fold(0, (sum, e) {
      return sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0);
    });
  }

  Color categoryColor(String category) {
    if (category == 'Tender Fee') return const Color(0xffE91E63);
    if (category == 'EMD') return const Color(0xff2563EB);
    return const Color(0xff7C3AED);
  }

  IconData categoryIcon(String category) {
    if (category == 'Tender Fee') return Icons.receipt_long;
    if (category == 'EMD') return Icons.paid_outlined;
    return Icons.account_balance;
  }

  String subTitle(String category) {
    if (category == 'Tender Fee') {
      return "DD & Online Payments — non-refundable bidding cost";
    }
    if (category == 'EMD') {
      return "Earnest Money Deposits — refundable after tender result";
    }
    return "Performance BG, Security Deposit, Advance BG & Retention BG";
  }

  void clearFilters() {
    setState(() {
      selectedCategory = 'All';
      selectedInstrumentType = 'All';
      selectedExpiryStatus = 'All';
      searchText = '';
      searchController.clear();
      showFilters = false;
    });
  }

  Widget header() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: (){

                  Navigator.pop(context);

                },
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EMD / BG Finance",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Track tender fees, EMD and bank guarantees",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget tabsAndFilters() {
    final filterCount =
        (selectedInstrumentType != 'All' ? 1 : 0) + (selectedExpiryStatus != 'All' ? 1 : 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                categoryTab('All', 'All Instruments', Icons.grid_view_rounded),
                categoryTab('Tender Fee', 'Tender Fee', Icons.receipt_long),
                categoryTab('EMD', 'EMD', Icons.paid_outlined),
                categoryTab('PBG', 'Bank Guarantees', Icons.account_balance),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: searchBox()),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => showFilters = !showFilters),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: showFilters || filterCount > 0
                          ? AppColors.primaryDeep
                          : const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: showFilters || filterCount > 0
                            ? AppColors.primaryDeep
                            : const Color(0xffE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: showFilters || filterCount > 0 ? Colors.white : AppColors.primarySlate,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Filters",
                          style: TextStyle(
                            color: showFilters || filterCount > 0 ? Colors.white : AppColors.primarySlate,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        if (filterCount > 0) ...[
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Colors.white,
                            child: Text(
                              "$filterCount",
                              style: const TextStyle(
                                color: AppColors.primaryDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectedInstrumentType != 'All' || selectedExpiryStatus != 'All')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  if (selectedInstrumentType != 'All')
                    activeFilterChip(selectedInstrumentType, () {
                      setState(() => selectedInstrumentType = 'All');
                    }),
                  if (selectedInstrumentType != 'All') const SizedBox(width: 6),
                  if (selectedExpiryStatus != 'All')
                    activeFilterChip(selectedExpiryStatus, () {
                      setState(() => selectedExpiryStatus = 'All');
                    }),
                  const Spacer(),
                  Text(
                    "${filteredRecords.length} records",
                    style: const TextStyle(
                      color: Color(0xff94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          if (showFilters) filterPanel(),
        ],
      ),
    );
  }

  Widget categoryTab(String value, String label, IconData icon) {
    final active = selectedCategory == value;

    return InkWell(
      onTap: () {
        setState(() {
          selectedCategory = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primaryDeep : Colors.transparent,
              width: 2,
            ),
          ),
          color: active ? Colors.white : const Color(0xffF8FAFC),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? AppColors.primaryDeep : const Color(0xff94A3B8),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primaryDeep : const Color(0xff64748B),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            CircleAvatar(
              radius: 9,
              backgroundColor: active ? AppColors.primaryDeep.withOpacity(.08) : const Color(0xffEEF2F7),
              child: Text(
                "${categoryCount(value)}",
                style: TextStyle(
                  color: active ? AppColors.primaryDeep : const Color(0xff94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget searchBox() {
    return TextField(
      controller: searchController,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: "Search by reference, client, tender, sales person...",
        hintStyle: const TextStyle(
          color: Color(0xff94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xff94A3B8)),
        suffixIcon: searchText.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            setState(() {
              searchText = '';
              searchController.clear();
            });
          },
          icon: const Icon(Icons.close_rounded, size: 17),
        ),
        filled: true,
        fillColor: const Color(0xffF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xffE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight),
        ),
      ),
      onChanged: (v) => setState(() => searchText = v),
    );
  }

  Widget activeFilterChip(String text, VoidCallback onClear) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryDeep,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }

  Widget filterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filterTitle("INSTRUMENT TYPE"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: instrumentTypes.map((e) {
              return filterChip(
                text: e,
                active: selectedInstrumentType == e,
                onTap: () => setState(() => selectedInstrumentType = e),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          filterTitle("EXPIRY STATUS"),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: expiryStatuses.map((e) {
              return filterChip(
                text: e,
                active: selectedExpiryStatus == e,
                dotColor: e == 'Critical'
                    ? Colors.red
                    : e == 'Warning'
                    ? Colors.yellow.shade700
                    : e == 'Expired'
                    ? Colors.black54
                    : null,
                onTap: () => setState(() => selectedExpiryStatus = e),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: clearFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Clear filters"),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget filterTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xff94A3B8),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    );
  }

  Widget filterChip({
    required String text,
    required bool active,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryDeep : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? AppColors.primaryDeep : const Color(0xffD8DEE8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryDeep),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              text,
              style: TextStyle(
                color: active ? Colors.white : AppColors.primarySlate,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget sectionHeader(String category, List<Map<String, dynamic>> list) {
    final color = categoryColor(category);
    final released = list.where((e) => e['status'] == 'Released').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(.82), color]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(.18),
                  child: Icon(categoryIcon(category), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category == 'PBG' ? 'Bank Guarantees' : category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subTitle(category),
                        style: TextStyle(
                          color: Colors.white.withOpacity(.78),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "TOTAL VALUE",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      money(total(list)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "${list.length} instruments",
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xff14B8A6), size: 16),
                const SizedBox(width: 7),
                Text(
                  "$released Released",
                  style: const TextStyle(
                    color: Color(0xff64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statusChip(String text, {Color? color}) {
    final c = color ?? const Color(0xff059669);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: c,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget recordCard(Map<String, dynamic> r, String category) {
    final color = categoryColor(category);
    final isReleased = r['status'] == 'Released';
    final amount = money(r['amount']);
    final expiry = r['expiry_date']?.toString();
    final days = r['days_to_expiry'];
    final expiryStatus = r['expiry_status']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffE2E8F0)),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 260, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              statusChip(
                                r['reference_num']?.toString() ?? '-',
                                color: AppColors.primarySlate,
                              ),
                              statusChip(r['status']?.toString() ?? '-'),
                              if (r['approval_status'] != null &&
                                  r['approval_status'].toString() != 'none')
                                statusChip(r['approval_status'].toString(), color: const Color(0xffD97706)),
                              if (r['finance_status'] == 'paid')
                                statusChip("Paid", color: const Color(0xff059669)),
                              if (isReleased)
                                statusChip("Released", color: const Color(0xff14B8A6)),
                              if (expiryStatus == 'Critical')
                                statusChip("Critical", color: Colors.red),
                              if (expiryStatus == 'Warning')
                                statusChip("Warning", color: const Color(0xffD97706)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amount,
                              style: const TextStyle(
                                color: AppColors.primaryDeep,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isReleased ? "✓ Released" : r['status']?.toString() ?? '',
                              style: TextStyle(
                                color: isReleased ? const Color(0xff059669) : const Color(0xff94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r['client_name']?.toString() ?? '-',
                      style: const TextStyle(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        smallInfo(Icons.category_outlined, r['instrument_type']?.toString() ?? '-'),
                        smallInfo(Icons.person_outline, r['sales_person_name']?.toString() ?? '-'),
                        smallInfo(Icons.description_outlined, r['tender_title']?.toString() ?? '-'),
                        if (expiry != null && expiry.isNotEmpty)
                          smallInfo(
                            Icons.calendar_today_outlined,
                            "Exp $expiry ${days != null ? '($days left)' : ''}",
                            color: days != null && days <= 7 ? Colors.red : const Color(0xff64748B),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text(
                          'Tap to view details',
                          style: TextStyle(
                            color: Color(0xff3060A0),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: Color(0xff3060A0), size: 18),
                      ],
                    ),
                    const SizedBox(height: 9),
                    flowStepper(r, category),
                    if (isReleased) ...[
                      const SizedBox(height: 13),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0xffECFDF5),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0xff86EFAC)),
                        ),
                        child: Text(
                          "Instrument Returned / Released: Confirmed on ${r['release_date'] ?? r['return_confirmed_at'] ?? '-'}",
                          style: const TextStyle(
                            color: Color(0xff047857),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget smallInfo(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? const Color(0xff94A3B8)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color ?? const Color(0xff64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget flowStepper(Map<String, dynamic> r, String category) {
    final steps = category == 'Tender Fee'
        ? ['Approved', 'Doc Uploaded', 'Acknowledged', 'Payment Proof', 'Paid']
        : [
      'Approved',
      'Doc Uploaded',
      'Acknowledged',
      'Payment Proof',
      'Paid',
      'Return Doc',
      category == 'PBG' ? 'Released' : 'Returned',
    ];

    int active = 0;
    if (r['approval_status'] == 'approved') active = 1;
    if (r['instrument_document_url'] != null) active = 2;
    if (r['instrument_acknowledged'] == true) active = 3;
    if (r['payment_proof_url'] != null) active = 4;
    if (r['finance_status'] == 'paid') active = 5;
    if (r['return_document_url'] != null) active = 6;
    if (r['return_status'] == 'confirmed' || r['status'] == 'Released') {
      active = steps.length;
    }

    return Wrap(
      spacing: 5,
      runSpacing: 6,
      children: List.generate(steps.length, (i) {
        final done = i < active;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: done ? const Color(0xffD1FAE5) : const Color(0xffF1F5F9),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (done)
                const Icon(Icons.check_circle, size: 11, color: Color(0xff059669)),
              if (done) const SizedBox(width: 4),
              Text(
                steps[i],
                style: TextStyle(
                  color: done ? const Color(0xff047857) : const Color(0xff94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }


  Future<void> openRecordDetail(Map<String, dynamic> record) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmdBgDetailScreen(
          tenantSlug: widget.tenantSlug,
          initialRecord: record,
        ),
      ),
    );

    if (changed == true) {
      await loadData();
    }
  }

  Widget categorySection(String category) {
    final list = byCategory(category);
    if (list.isEmpty) return const SizedBox();

    return Column(
      children: [
        sectionHeader(category, list),
        ...list.map((e) => GestureDetector(
          onTap: () => openRecordDetail(e),
          child: recordCard(e, category),
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget body() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      color: AppColors.primaryLight,
      child: filteredRecords.isEmpty
          ? ListView(
        children: [
          tabsAndFilters(),
          const SizedBox(height: 120),
          const Center(
            child: Text(
              "No EMD/BG records found",
              style: TextStyle(
                color: Color(0xff64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      )
          : ListView(
        padding: EdgeInsets.zero,
        children: [
          tabsAndFilters(),
          if (selectedCategory == 'All') ...[
            categorySection("Tender Fee"),
            categorySection("EMD"),
            categorySection("PBG"),
          ] else
            categorySection(selectedCategory),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F6FA),
      body: Column(
        children: [
          header(),
          Expanded(child: body()),
        ],
      ),
    );
  }
}

class EmdBgDetailScreen extends StatefulWidget {
  final String tenantSlug;
  final Map<String, dynamic> initialRecord;

  const EmdBgDetailScreen({
    super.key,
    required this.tenantSlug,
    required this.initialRecord,
  });

  @override
  State<EmdBgDetailScreen> createState() => _EmdBgDetailScreenState();
}

class _EmdBgDetailScreenState extends State<EmdBgDetailScreen> {
  late Map<String, dynamic> record;
  bool isLoading = false;
  bool isActionBusy = false;
  bool changed = false;
  String role = '';
  List<Map<String, dynamic>> renewals = [];

  @override
  void initState() {
    super.initState();
    record = Map<String, dynamic>.from(widget.initialRecord);
    _loadUserRole();
    refreshRecord();
    loadRenewals();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final possibleRole = prefs.getString('role') ??
        prefs.getString('user_role') ??
        prefs.getString('auth_role') ??
        prefs.getString('current_user_role') ??
        '';
    if (mounted) {
      setState(() => role = possibleRole.toLowerCase());
    }
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ??
        prefs.getString('access_token') ??
        prefs.getString('token');

    final headers = <String, String>{
      'X-Tenant-Slug': widget.tenantSlug,
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  Future<void> refreshRecord() async {
    final id = record['id'];
    if (id == null) return;

    try {
      setState(() => isLoading = true);
      final response = await http.get(
        Uri.parse('$kEmdbgApiBaseUrl/emdbg/$id'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        setState(() {
          record = Map<String, dynamic>.from(jsonDecode(response.body));
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        showError(response.body);
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError(e.toString());
    }
  }

  Future<void> loadRenewals() async {
    final id = record['id'];
    if (id == null) return;

    try {
      final response = await http.get(
        Uri.parse('$kEmdbgApiBaseUrl/emdbg/$id/renewals'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            renewals = data.map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (_) {
      // Renewal history is optional for the detail screen.
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xff059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> postAction(
      String endpoint, {
        Map<String, dynamic>? body,
        String successMessage = 'Updated successfully',
      }) async {
    final id = record['id'];
    if (id == null) return;

    try {
      setState(() => isActionBusy = true);
      final response = await http.post(
        Uri.parse('$kEmdbgApiBaseUrl/emdbg/$id/$endpoint'),
        headers: await _headers(),
        body: jsonEncode(body ?? {}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        changed = true;
        showSuccess(successMessage);
        await refreshRecord();
        await loadRenewals();
      } else {
        showError(response.body);
      }
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => isActionBusy = false);
    }
  }

  Future<bool> confirm(String title, String message, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> requestApproval() async {
    if (await confirm(
      'Request Approval',
      "Send ${text(record['reference_num'])} for manager approval?",
      'Request',
    )) {
      await postAction('request-approval', successMessage: 'Approval requested');
    }
  }

  Future<void> approve(String decision) async {
    String? reason;
    if (decision == 'rejected') {
      reason = await promptText(
        title: 'Rejection reason',
        hint: 'Enter reason',
        required: true,
      );
      if (reason == null || reason.trim().isEmpty) return;
    }

    await postAction(
      'approve',
      body: {
        'decision': decision,
        'rejection_reason': reason,
      },
      successMessage: "${text(record['reference_num'])} $decision",
    );
  }

  Future<void> acknowledgeDocument() async {
    if (await confirm(
      'Acknowledge Document',
      "Acknowledge the instrument document for ${text(record['reference_num'])}?",
      'Acknowledge',
    )) {
      await postAction('acknowledge-instrument', successMessage: 'Document acknowledged');
    }
  }

  Future<void> markPaid() async {
    if (await confirm(
      'Confirm Payment',
      "Mark ${text(record['reference_num'])} as Paid?",
      'Mark Paid',
    )) {
      await postAction('mark-paid', successMessage: 'Marked as paid');
    }
  }

  Future<void> confirmReturn() async {
    if (await confirm(
      'Confirm Return',
      "Confirm return for ${text(record['reference_num'])}?",
      'Confirm Return',
    )) {
      await postAction('confirm-return', successMessage: 'Return confirmed');
    }
  }

  Future<void> encash() async {
    if (await confirm(
      'Mark as Encashed',
      "Mark ${text(record['reference_num'])} as Encashed? This action cannot be undone.",
      'Mark Encashed',
    )) {
      await postAction('encash', successMessage: 'Marked as encashed');
    }
  }

  Future<String?> promptText({
    required String title,
    required String hint,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDeep,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (required && controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  String text(dynamic value) {
    final s = value?.toString() ?? '';
    return s.trim().isEmpty ? '-' : s;
  }

  bool hasValue(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  bool get isAccounts => role == 'accounts';
  bool get isManager => ['admin', 'ceo', 'manager', 'vp'].contains(role);
  bool get isPrivileged => ['admin', 'ceo', 'super_admin'].contains(role);
  bool get canRenewBg => isPrivileged || isManager || isAccounts;

  bool get isPbgType => const [
    'Performance BG',
    'Security Deposit',
    'Advance BG',
    'Retention BG',
  ].contains(record['instrument_type']);

  bool get isTenderFee => const ['DD', 'Online Payment'].contains(record['instrument_type']);
  bool get hasReturnFlow => !isTenderFee;

  String get category {
    final type = text(record['instrument_type']);
    if (type == 'DD' || type == 'Online Payment') return 'Tender Fee';
    if (type == 'EMD') return 'EMD';
    return 'PBG';
  }

  Color get categoryColor {
    if (category == 'Tender Fee') return const Color(0xffE91E63);
    if (category == 'EMD') return const Color(0xff2563EB);
    return const Color(0xff7C3AED);
  }

  IconData get categoryIcon {
    if (category == 'Tender Fee') return Icons.receipt_long;
    if (category == 'EMD') return Icons.paid_outlined;
    return Icons.account_balance;
  }

  String money(dynamic v) {
    final n = double.tryParse(v?.toString() ?? '0') ?? 0;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)}Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)}L';
    return '₹${n.toStringAsFixed(0)}';
  }

  String get actionablePhrase {
    final approvalStatus = text(record['approval_status']) == '-' ? 'none' : text(record['approval_status']);
    final financeStatus = text(record['finance_status']) == '-' ? 'unpaid' : text(record['finance_status']);
    final returnStatus = text(record['return_status']) == '-' ? 'none' : text(record['return_status']);

    if (record['status'] == 'Released' || (returnStatus == 'confirmed' && record['status'] != 'Encashed')) return '';
    if (record['status'] == 'Encashed') return 'Instrument encashed by client';
    if (approvalStatus == 'rejected') return 'Approval rejected — edit and resubmit';
    if (approvalStatus == 'pending') {
      return isManager ? 'Pending your approval — action required' : 'Submitted and awaiting manager approval';
    }

    if (approvalStatus == 'approved') {
      if (!hasValue(record['instrument_document_url'])) {
        return isAccounts ? 'Action required: Upload instrument document' : 'Waiting for accounts to upload document';
      }
      if (record['instrument_acknowledged'] != true) {
        return isAccounts ? 'Waiting for sales to acknowledge the document' : 'Action required: Acknowledge the uploaded document';
      }
      if (!hasValue(record['payment_proof_url'])) {
        if (!isPbgType && record['workings_approved'] == false) return 'Workings approval pending — payment is blocked';
        return isAccounts ? 'Action required: Upload payment proof' : 'Waiting for accounts to upload payment proof';
      }
      if (financeStatus != 'paid') {
        return isAccounts ? 'Action required: Mark as paid' : 'Payment proof uploaded — awaiting accounts confirmation';
      }
      if (!isTenderFee &&
          (record['tender_result'] == 'Won' || record['tender_result'] == 'Lost') &&
          returnStatus == 'none') {
        return isAccounts ? 'Waiting for sales to upload return document' : 'Action required: Upload return document from client';
      }
      if (returnStatus == 'pending_confirmation') {
        return isAccounts ? 'Action required: Confirm the return document' : 'Return document uploaded — awaiting accounts confirmation';
      }
      if (isPbgType && record['expiry_status'] == 'Critical') return 'BG expiring within 7 days — renew immediately';
      if (isPbgType && record['expiry_status'] == 'Warning') return 'BG expiring within 30 days — renew soon';
      if (isPbgType && record['expiry_status'] == 'Expired' && record['status'] != 'Released') {
        return 'BG has expired — upload release letter';
      }
    }

    return '';
  }

  List<String> get flowSteps {
    if (category == 'Tender Fee') {
      return ['Approved', 'Doc Uploaded', 'Acknowledged', 'Payment Proof', 'Paid'];
    }

    return [
      'Approved',
      'Doc Uploaded',
      'Acknowledged',
      'Payment Proof',
      'Paid',
      'Return Doc',
      category == 'PBG' ? 'Released' : 'Returned',
    ];
  }

  int get activeFlowStep {
    int active = 0;

    if (record['approval_status'] == 'approved') active = 1;
    if (hasValue(record['instrument_document_url'])) active = 2;
    if (record['instrument_acknowledged'] == true) active = 3;
    if (hasValue(record['payment_proof_url'])) active = 4;
    if (record['finance_status'] == 'paid') active = 5;

    if (category == 'Tender Fee' && (record['finance_status'] == 'paid' || record['status'] == 'Released')) {
      return flowSteps.length;
    }

    if (hasReturnFlow) {
      if (hasValue(record['return_document_url'])) active = 6;
      if (record['return_status'] == 'confirmed' || record['status'] == 'Released') {
        active = flowSteps.length;
      }
    }

    return active;
  }

  bool get canMarkPaid {
    if (!isAccounts) return false;
    if (record['approval_status'] != 'approved') return false;
    if (record['finance_status'] == 'paid') return false;
    if (!hasValue(record['instrument_document_url'])) return false;
    if (record['instrument_acknowledged'] != true) return false;
    if (!hasValue(record['payment_proof_url'])) return false;
    if (!isPbgType && record['workings_approved'] == false) return false;
    return true;
  }

  String get paymentBlockReason {
    if (!isAccounts || record['approval_status'] != 'approved' || record['finance_status'] == 'paid') return '';
    if (!hasValue(record['instrument_document_url'])) return 'Upload document first.';
    if (record['instrument_acknowledged'] != true) return 'Waiting for sales to acknowledge document.';
    if (!hasValue(record['payment_proof_url'])) return 'Upload payment proof first.';
    if (!isPbgType && record['workings_approved'] == false) return 'Tender workings not yet approved.';
    return 'Complete all steps first.';
  }

  List<_Notice> get notices {
    final list = <_Notice>[];
    final approvalStatus = text(record['approval_status']) == '-' ? 'none' : text(record['approval_status']);
    final financeStatus = text(record['finance_status']) == '-' ? 'unpaid' : text(record['finance_status']);
    final returnStatus = text(record['return_status']) == '-' ? 'none' : text(record['return_status']);
    final tenderWon = record['tender_result'] == 'Won';
    final tenderLost = record['tender_result'] == 'Lost';

    if (approvalStatus == 'rejected') {
      list.add(_Notice(
        icon: Icons.cancel_outlined,
        color: Colors.red,
        title: 'Approval Rejected',
        body: hasValue(record['last_rejection_reason'])
            ? "Reason: ${record['last_rejection_reason']}"
            : 'This record was rejected. Edit and re-submit for approval.',
      ));
    }

    if (approvalStatus == 'pending') {
      list.add(_Notice(
        icon: Icons.schedule,
        color: const Color(0xffD97706),
        title: 'Awaiting Approval',
        body: isManager
            ? 'Action required: Review and approve or reject this instrument.'
            : 'Submitted for manager approval. Locked until decision.',
      ));
    }

    if (approvalStatus == 'approved' && financeStatus != 'paid') {
      if (!hasValue(record['instrument_document_url'])) {
        list.add(_Notice(
          icon: Icons.upload_file,
          color: const Color(0xff2563EB),
          title: isPbgType ? 'Upload BG Draft Document' : 'Upload Instrument Document',
          body: isAccounts
              ? 'Approval granted. Upload the document for the sales team to acknowledge.'
              : 'Waiting for accounts to upload the instrument document.',
        ));
      } else if (record['instrument_acknowledged'] != true) {
        list.add(_Notice(
          icon: Icons.fact_check_outlined,
          color: const Color(0xffD97706),
          title: isAccounts ? 'Waiting for Sales Acknowledgment' : 'Action Required — Acknowledge Document',
          body: isAccounts
              ? 'Document uploaded. Awaiting the sales person to acknowledge receipt.'
              : 'Accounts has uploaded the document. Please review and acknowledge it to proceed.',
        ));
      } else if (!hasValue(record['payment_proof_url'])) {
        if (!isPbgType && record['workings_approved'] == false) {
          list.add(_Notice(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xffD97706),
            title: 'Workings Approval Pending',
            body: 'Payment is blocked until tender workings are approved.',
          ));
        } else {
          list.add(_Notice(
            icon: Icons.upload_file,
            color: const Color(0xff059669),
            title: isAccounts ? 'Upload Payment Proof' : 'Document Acknowledged',
            body: isAccounts
                ? 'Document acknowledged by sales. Upload the payment proof document to proceed.'
                : 'Awaiting accounts to upload payment proof.',
          ));
        }
      } else {
        list.add(_Notice(
          icon: Icons.check_circle_outline,
          color: const Color(0xff059669),
          title: isAccounts ? 'Ready to Mark as Paid' : 'Payment Proof Uploaded',
          body: isAccounts
              ? 'Payment proof uploaded. Click Mark Paid to complete the payment step.'
              : 'Waiting for accounts to confirm and mark as paid.',
        ));
      }
    }

    if (hasReturnFlow && financeStatus == 'paid' && (tenderWon || tenderLost) && returnStatus == 'none') {
      list.add(_Notice(
        icon: Icons.keyboard_return_rounded,
        color: const Color(0xffD97706),
        title: isAccounts ? 'Awaiting Return Document from Sales' : 'Upload Return Document',
        body: isAccounts
            ? 'Tender ${tenderWon ? 'Won' : 'Lost'} — waiting for sales to upload the return document.'
            : 'Tender ${tenderWon ? 'Won' : 'Lost'} — upload the return/discharge document from the client.',
      ));
    }

    if (hasReturnFlow && returnStatus == 'pending_confirmation') {
      list.add(_Notice(
        icon: Icons.pending_actions,
        color: const Color(0xff0F766E),
        title: 'Return Document Uploaded — Awaiting Confirmation',
        body: isAccounts
            ? 'Review the uploaded return document and confirm the return.'
            : 'Waiting for accounts team to verify and confirm the return.',
      ));
    }

    if (isPbgType &&
        record['expiry_status'] == 'Critical' &&
        record['status'] != 'Released' &&
        financeStatus == 'paid') {
      list.add(_Notice(
        icon: Icons.shield_outlined,
        color: Colors.red,
        title: 'BG Expiring Within 7 Days',
        body: "Expires ${text(record['expiry_date'])}. Initiate renewal immediately to avoid encashment risk.",
      ));
    }

    if (record['status'] == 'Released' || returnStatus == 'confirmed') {
      list.add(_Notice(
        icon: Icons.verified_outlined,
        color: const Color(0xff059669),
        title: 'Instrument Returned / Released',
        body: hasValue(record['release_date'])
            ? "Confirmed on ${record['release_date']}.${hasValue(record['release_reference']) ? ' Ref: ${record["release_reference"]}' : ''}"
            : 'This instrument has been returned and closed.',
      ));
    }

    return list;
  }

  String previewUrl(String rawPath) {
    if (rawPath.trim().isEmpty) return '';
    final filePath = rawPath.startsWith('http') ? Uri.parse(rawPath).path : rawPath;
    final params = Uri(queryParameters: {
      'path': filePath,
      'tenant': widget.tenantSlug,
    }).query;
    return '$kEmdbgApiBaseUrl/preview/file?$params';
  }

  Future<void> copyPreviewLink(String rawPath) async {
    final url = previewUrl(rawPath);
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    showSuccess('Preview link copied');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF3F6FA),
        body: Column(
          children: [
            detailHeader(),
            Expanded(
              child: isLoading && record.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                color: AppColors.primaryLight,
                onRefresh: () async {
                  await refreshRecord();
                  await loadRenewals();
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    heroCard(),
                    if (actionablePhrase.isNotEmpty) actionBanner(),
                    noticesBlock(),
                    flowBlock(),
                    infoBlock(),
                    documentBlock(),
                    actionBlock(),
                    renewalBlock(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget detailHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, changed),
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text(record['reference_num']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${text(record['instrument_type'])} · ${text(record['client_name'])}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                IconButton(
                  onPressed: () async {
                    await refreshRecord();
                    await loadRenewals();
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget heroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [categoryColor.withOpacity(.85), categoryColor]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withOpacity(.18),
            child: Icon(categoryIcon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category == 'PBG' ? 'Bank Guarantees' : category,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  text(record['tender_title']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'AMOUNT',
                style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900),
              ),
              Text(
                money(record['amount']),
                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
              ),
              Text(
                text(record['status']),
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget actionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xffFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: Color(0xffEA580C), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              actionablePhrase,
              style: const TextStyle(
                color: Color(0xff9A3412),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget noticesBlock() {
    final list = notices;
    if (list.isEmpty) return const SizedBox();

    return section(
      title: 'Current Status',
      child: Column(
        children: list.map((n) => noticeTile(n)).toList(),
      ),
    );
  }

  Widget noticeTile(_Notice n) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: n.color.withOpacity(.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: n.color.withOpacity(.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(n.icon, color: n.color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: n.color, fontSize: 12, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(text: '${n.title}: ', style: const TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: n.body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget flowBlock() {
    final steps = flowSteps;
    final active = activeFlowStep;

    return section(
      title: 'Workflow',
      child: Wrap(
        spacing: 6,
        runSpacing: 8,
        children: List.generate(steps.length, (i) {
          final done = i < active;
          final current = i == active && active < steps.length;
          final bg = done
              ? const Color(0xffD1FAE5)
              : current
              ? categoryColor.withOpacity(.12)
              : const Color(0xffF1F5F9);
          final fg = done
              ? const Color(0xff047857)
              : current
              ? categoryColor
              : const Color(0xff94A3B8);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: current ? categoryColor.withOpacity(.35) : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(done ? Icons.check_circle : current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 12, color: fg),
                const SizedBox(width: 5),
                Text(
                  steps[i],
                  style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget infoBlock() {
    return section(
      title: 'Instrument Details',
      child: Column(
        children: [
          infoRow('Reference No.', record['reference_num'], mono: true),
          infoRow('Client', record['client_name']),
          infoRow('Customer', record['customer_name_display']),
          infoRow('Tender No.', record['tender_num_display'] ?? record['tender_num']),
          infoRow('Tender Title', record['tender_title']),
          infoRow('Tender Result', record['tender_result']),
          infoRow('Sales Person', record['sales_person_name']),
          infoRow('Sales Email', record['sales_person_email']),
          infoRow('Sales Phone', record['sales_person_phone']),
          infoRow('Instrument Type', record['instrument_type']),
          infoRow('Instrument No.', record['instrument_number'], mono: true),
          infoRow('Amount', money(record['amount']), highlight: AppColors.primaryDeep),
          infoRow('Bank', record['bank_name']),
          infoRow('Branch', record['bank_branch']),
          infoRow('Issued Date', record['issued_date']),
          infoRow('Submitted Date', record['submitted_date']),
          infoRow('Valid From', record['valid_from']),
          infoRow('Expiry Date', record['expiry_date']),
          infoRow('Days to Expiry', record['days_to_expiry']),
          infoRow('Expiry Status', record['expiry_status']),
          infoRow('Approval Status', record['approval_display'] ?? record['approval_status']),
          infoRow('Finance Status', record['finance_status']),
          infoRow('Paid Date', record['finance_paid_date']),
          infoRow('Paid By', record['finance_paid_by_name']),
          infoRow('Return Status', record['return_status']),
          infoRow('Returned / Released Date', record['release_date'] ?? record['return_confirmed_at']),
          infoRow('Created By', record['created_by_name']),
          infoRow('Purpose', record['purpose']),
          infoRow('Notes', record['notes']),
        ],
      ),
    );
  }

  Widget documentBlock() {
    final docs = [
      _DocItem('Instrument Document', 'instrument_document_url', 'instrument_file_size_kb'),
      _DocItem('Payment Proof', 'payment_proof_url', 'payment_proof_size_kb'),
      if (hasReturnFlow) _DocItem('Return Document', 'return_document_url', 'return_file_size_kb'),
      _DocItem('Release Document', 'release_document_url', 'release_file_size_kb'),
    ];

    return section(
      title: 'Documents',
      child: Column(
        children: docs.map((d) => docTile(d)).toList(),
      ),
    );
  }

  Widget docTile(_DocItem doc) {
    final url = record[doc.urlKey]?.toString() ?? '';
    final uploaded = url.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uploaded ? const Color(0xffEEF2FF) : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: uploaded ? const Color(0xffC7D2FE) : const Color(0xffE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            uploaded ? Icons.file_present_rounded : Icons.description_outlined,
            color: uploaded ? const Color(0xff4F46E5) : const Color(0xff94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.label,
                  style: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  uploaded
                      ? 'Uploaded${hasValue(record[doc.sizeKey]) ? ' · ${record[doc.sizeKey]} KB' : ''}'
                      : 'Not uploaded',
                  style: TextStyle(
                    color: uploaded ? const Color(0xff059669) : const Color(0xff94A3B8),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                if (doc.urlKey == 'instrument_document_url' && record['instrument_acknowledged'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'Acknowledged',
                      style: TextStyle(color: Color(0xff2563EB), fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
          if (uploaded)
            TextButton.icon(
              onPressed: () => copyPreviewLink(url),
              icon: const Icon(Icons.link, size: 15),
              label: const Text('Copy link'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff4F46E5),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget actionBlock() {
    final actions = <Widget>[];
    final approvalStatus = text(record['approval_status']) == '-' ? 'none' : text(record['approval_status']);
    final financeStatus = text(record['finance_status']) == '-' ? 'unpaid' : text(record['finance_status']);
    final returnStatus = text(record['return_status']) == '-' ? 'none' : text(record['return_status']);
    final canAct = record['status'] == 'Active' || record['status'] == 'Renewed';

    if (canAct && approvalStatus == 'none') {
      actions.add(actionButton(
        label: 'Request Approval',
        icon: Icons.send,
        color: AppColors.primaryDeep,
        onTap: requestApproval,
      ));
    }

    if (canAct && isManager && approvalStatus == 'pending') {
      actions.add(actionButton(
        label: 'Approve',
        icon: Icons.check_circle,
        color: const Color(0xff059669),
        onTap: () => approve('approved'),
      ));
      actions.add(actionButton(
        label: 'Reject',
        icon: Icons.cancel,
        color: Colors.red,
        onTap: () => approve('rejected'),
      ));
    }

    if (!isAccounts &&
        approvalStatus == 'approved' &&
        hasValue(record['instrument_document_url']) &&
        record['instrument_acknowledged'] != true &&
        financeStatus != 'paid') {
      actions.add(actionButton(
        label: 'Acknowledge Document',
        icon: Icons.fact_check,
        color: const Color(0xff2563EB),
        onTap: acknowledgeDocument,
      ));
    }

    if (isAccounts && approvalStatus == 'approved' && financeStatus != 'paid') {
      if (canMarkPaid) {
        actions.add(actionButton(
          label: 'Mark Paid',
          icon: Icons.payments,
          color: const Color(0xff059669),
          onTap: markPaid,
        ));
      } else {
        actions.add(disabledAction(paymentBlockReason));
      }
    }

    if (isAccounts &&
        hasReturnFlow &&
        hasValue(record['return_document_url']) &&
        returnStatus != 'confirmed') {
      actions.add(actionButton(
        label: 'Confirm Return',
        icon: Icons.keyboard_return,
        color: const Color(0xff0F766E),
        onTap: confirmReturn,
      ));
    }

    if (canAct && isManager && record['status'] != 'Encashed') {
      actions.add(actionButton(
        label: 'Mark Encashed',
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
        onTap: encash,
      ));
    }

    if (actions.isEmpty) return const SizedBox();

    return section(
      title: 'Actions',
      child: isActionBusy
          ? const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
      )
          : Wrap(
        spacing: 9,
        runSpacing: 9,
        children: actions,
      ),
    );
  }

  Widget actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: isActionBusy ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget disabledAction(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xffFFF7ED),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xffFDBA74)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_clock, color: Color(0xffD97706), size: 15),
          const SizedBox(width: 7),
          Text(
            message.isEmpty ? 'Complete all steps first.' : message,
            style: const TextStyle(
              color: Color(0xff9A3412),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget renewalBlock() {
    if (renewals.isEmpty) return const SizedBox();

    return section(
      title: 'Renewal History',
      child: Column(
        children: renewals.map((r) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xffE2E8F0)),
            ),
            child: Column(
              children: [
                infoRow('New Expiry', r['new_expiry_date']),
                infoRow('Reference', r['new_reference']),
                infoRow('Renewed By', r['renewed_by_name']),
                infoRow('Notes', r['notes']),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget section({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Widget infoRow(String label, dynamic value, {Color? highlight, bool mono = false}) {
    final display = value == null || value.toString().trim().isEmpty ? '—' : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: highlight ?? AppColors.primarySlate,
                fontSize: 12,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Notice({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

class _DocItem {
  final String label;
  final String urlKey;
  final String sizeKey;

  const _DocItem(this.label, this.urlKey, this.sizeKey);
}
