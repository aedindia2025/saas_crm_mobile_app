import 'dart:convert';
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

class EmdBg extends StatefulWidget {
  const EmdBg({super.key});

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
        Uri.parse("http://103.110.236.187:3076/api/v1/emdbg"),
        headers: {
          'Authorization': 'Bearer $token',
          'X-Tenant-Slug': 'ascent',
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
                    const SizedBox(height: 13),
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

  Widget categorySection(String category) {
    final list = byCategory(category);
    if (list.isEmpty) return const SizedBox();

    return Column(
      children: [
        sectionHeader(category, list),
        ...list.map((e) => recordCard(e, category)),
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