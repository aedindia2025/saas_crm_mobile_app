import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_helpers/api_method.dart';

import 'create_customer.dart';

// ─── App Colors ───────────────────────────────────────────────────────────────
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

// ─── Customer Screen ──────────────────────────────────────────────────────────
class Customer extends StatefulWidget {
  const Customer({super.key});

  @override
  State<Customer> createState() => _CustomerState();
}

class _CustomerState extends State<Customer>  {
  static const String baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1';

  final ScrollController _scrollController = ScrollController();

  String tenantSlug = '';

  String intelligenceSubTab = 'overview';
  String product360SubTab = 'supplied';
  bool show360View = false;
  bool showFilters = false;
  final Set<dynamic> expandedActionCards = {};
  final TextEditingController cityController = TextEditingController();
  String cityText = '';


  bool isLoading = true;
  bool isLoadingMore = false;
  bool is360Loading = false;

  String? token;
  String searchText = '';
  String statusFilter = '';
  int skip = 0;
  final int limit = 10;
  int totalCustomers = 0;
  bool hasMore = true;

  List<Map<String, dynamic>> customers = [];
  Map<String, dynamic>? selected360Customer;
  Map<String, dynamic>? customer360Data;

  final TextEditingController searchController = TextEditingController();
  final List<String> statuses = const ['Active', 'Inactive', 'Prospect', 'Churned'];

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250 &&
          hasMore &&
          !isLoadingMore &&
          !isLoading) {
        fetchCustomerList(reset: false);
      }
    });

    getSharedPref();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> getSharedPref() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    tenantSlug = prefs.getString('tenant_slug') ?? '';
    if (token == null) {
      setState(() => isLoading = false);
      showSnack('Token not found', Colors.red);
      return;
    }
    await Future.wait([fetchCustomerBadge(), fetchCustomerList(reset: true)]);
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'X-Tenant-Slug': tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<void> fetchCustomerBadge() async {
    if (token == null) return;
    try {
      final res = await ApiMethod.getRequest(url: '$baseUrl/customers/badge', headers: headers);
      if (res['statusCode'] == 200) {
        final data = res['data'];
        if (!mounted) return;
        setState(() => totalCustomers = int.tryParse(data['count'].toString()) ?? 0);
      }
    } catch (_) {}
  }

  Future<void> fetchCustomerList({bool reset = false}) async {
    if (token == null) return;

    if (reset) {
      skip = 0;
      hasMore = true;
      customers.clear();
      setState(() => isLoading = true);
    } else {
      setState(() => isLoadingMore = true);
    }

    try {
      final queryParams = <String, String>{
        'skip': skip.toString(),
        'limit': limit.toString(),
      };

      if (searchText.trim().isNotEmpty) {
        queryParams['search'] = searchText.trim();
      }

      if (cityText.trim().isNotEmpty) {
        queryParams['city'] = cityText.trim();
      }

      if (statusFilter.trim().isNotEmpty) {
        queryParams['status'] = statusFilter.trim();
      }

      final uri = Uri.parse('$baseUrl/customers/')
          .replace(queryParameters: queryParams);

      final res = await ApiMethod.getRequest(url: uri.toString(), headers: headers);

      if (res['statusCode'] == 200) {
        final List data = res['data'];
        final newItems = data.map((e) => Map<String, dynamic>.from(e)).toList();

        if (!mounted) return;

        setState(() {
          if (reset) {
            customers = newItems;
          } else {
            customers.addAll(newItems);
          }

          skip = customers.length;
          hasMore = newItems.length == limit;
          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });

        showSnack(res['data']?.toString() ?? 'Error', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });

      showSnack(e.toString(), Colors.red);
    }
  }

  Future<void> load360(Map<String, dynamic> customer) async {
    if (token == null) return;

    setState(() {
      selected360Customer = customer;
      customer360Data = null;
      is360Loading = true;
      show360View = true;
    });

    try {
      final res = await ApiMethod.getRequest(url: '$baseUrl/customers/${customer['id']}/360', headers: headers);

      if (res['statusCode'] == 200) {
        if (!mounted) return;

        setState(() {
          customer360Data = Map<String, dynamic>.from(res['data']);
          is360Loading = false;
        });
      } else {
        if (!mounted) return;

        setState(() => is360Loading = false);
        showSnack(res['data']?.toString() ?? 'Error', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => is360Loading = false);
      showSnack(e.toString(), Colors.red);
    }
  }

  Future<void> refreshAll() async {
    await fetchCustomerBadge();
    await fetchCustomerList(reset: true);
    if (selected360Customer != null) await load360(selected360Customer!);
  }

  Future<void> deleteCustomer(dynamic customerId) async {
    if (token == null) return;
    try {
      setState(() => isLoading = true);
      final res = await ApiMethod.deleteRequest(url: '$baseUrl/customers/$customerId', headers: headers);
      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        showSnack('Customer deleted successfully', Colors.green);
        await refreshAll();
      } else {
        setState(() => isLoading = false);
        showSnack(res['data']?.toString() ?? 'Error', Colors.red);
      }
    } catch (e) {
      setState(() => isLoading = false);
      showSnack(e.toString(), Colors.red);
    }
  }

  Future<void> updateCustomerStatus(dynamic customerId, String selectedStatus) async {
    if (token == null) return;
    try {
      final uri = Uri.parse('$baseUrl/customers/$customerId/status')
          .replace(queryParameters: {'status': selectedStatus});
      final res = await ApiMethod.patchRequest(
        url: uri.toString(),
        headers: headers,
        body: {'account_status': selectedStatus},
      );
      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        showSnack('Status updated successfully', Colors.green);
        await refreshAll();
      } else {
        showSnack(res['data']?.toString() ?? 'Error', Colors.red);
      }
    } catch (e) {
      showSnack(e.toString(), Colors.red);
    }
  }

  void openDeleteDialog(dynamic customerId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Delete",
      barrierColor: Colors.black.withOpacity(.40),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width > 600
                ? 360
                : MediaQuery.of(context).size.width * .88,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// ICON
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xffFEF2F2),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xffDC2626),
                        size: 28,
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// TITLE
                    const Text(
                      "Delete Customer",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff0F172A),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// DESCRIPTION
                    Text(
                      "Are you sure you want to delete this customer?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              side: const BorderSide(
                                color: Color(0xffCBD5E1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff475569),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              deleteCustomer(customerId);
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xffDC2626),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Delete",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      },
      transitionBuilder: (_, animation, __, child) {
        return Transform.scale(
          scale: Tween<double>(
            begin: .92,
            end: 1,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ).value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }

  void openStatusDialog(dynamic customerId, String currentStatus) {
    String selectedStatus =
    statuses.contains(currentStatus) ? currentStatus : 'Active';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Status",
      barrierColor: Colors.black.withOpacity(.40),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Container(
                width: MediaQuery.of(context).size.width > 600
                    ? 370
                    : MediaQuery.of(context).size.width * .88,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        /// ICON
                        Container(
                          height: 58,
                          width: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryLight.withOpacity(.10),
                          ),
                          child: Icon(
                            Icons.sync_alt_rounded,
                            color: AppColors.primaryLight,
                            size: 28,
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// TITLE
                        const Text(
                          "Update Status",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff0F172A),
                          ),
                        ),

                        const SizedBox(height: 10),

                        /// DESCRIPTION
                        Text(
                          "Select a new status for this customer.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 22),

                        /// LABEL
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Customer Status",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// DROPDOWN
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xffF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xffE2E8F0),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: selectedStatus,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.flag_outlined,
                                color: AppColors.primaryLight,
                                size: 20,
                              ),
                            ),
                            items: statuses.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff1E293B),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedStatus = value!;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// BUTTONS
                        Row(
                          children: [

                            /// CANCEL
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize:
                                  const Size(double.infinity, 44),
                                  side: const BorderSide(
                                    color: Color(0xffCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff475569),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            /// UPDATE
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  updateCustomerStatus(
                                    customerId,
                                    selectedStatus,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor:
                                  AppColors.primaryLight,
                                  foregroundColor: Colors.white,
                                  minimumSize:
                                  const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Update",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return Transform.scale(
          scale: Tween<double>(
            begin: .92,
            end: 1,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ).value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }

  void showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String formatCurrency(dynamic raw) {
    final value = double.tryParse((raw ?? 0).toString()) ?? 0;
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

  String safeText(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String initials(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'NA';
    return text.length >= 2 ? text.substring(0, 2).toUpperCase() : text.toUpperCase();
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xff059669);
      case 'inactive':
      case 'churned':
        return const Color(0xff64748B);
      case 'prospect':
        return const Color(0xff2563EB);
      default:
        return AppColors.primaryLight;
    }
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────────
  Widget _statusBadge(String text) {
    final color = statusColor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _avatar(String name, {double size = 40, double fontSize = 14}) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.headerGradient,
      ),
      child: Text(
        initials(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: fontSize),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [


            GestureDetector(
              onTap: () {
                setState(() {
                  show360View = false;
                  Navigator.pop(context);
                });
              },
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show360View ? 'Customer 360' : 'Customers',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    show360View
                        ? safeText(selected360Customer?['customer_name'], '')
                        : '$totalCustomers total records',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            if (!show360View) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: openAddCustomer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.primaryDark),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _headerIconBtn(
                Icons.refresh_rounded,
                selected360Customer == null
                    ? () {}
                    : () => load360(selected360Customer!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ─── Filter Panel ─────────────────────────────────────────────────────────
  Widget filterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _searchBox(
                  controller: searchController,
                  hint: 'Search customer',
                  icon: Icons.search,
                  onSubmitted: (value) {
                    searchText = value;
                    fetchCustomerList(reset: true);
                  },
                  onClear: () {
                    searchController.clear();
                    searchText = '';
                    fetchCustomerList(reset: true);
                  },
                ),
              ),

              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => showFilters = !showFilters),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: showFilters ? AppColors.primaryLight : const Color(0xffF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: showFilters ? Colors.white : AppColors.primarySlate,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (showFilters) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: statusFilter.isEmpty ? null : statusFilter,
                    decoration: InputDecoration(
                      hintText: 'Filter by status',
                      filled: true,
                      fillColor: const Color(0xffF5F7FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      statusFilter = value ?? '';
                      fetchCustomerList(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: OutlinedButton(
                    onPressed: () {
                      searchController.clear();
                      cityController.clear();
                      searchText = '';
                      cityText = '';
                      statusFilter = '';
                      setState(() {});
                      fetchCustomerList(reset: true);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            )
          ],
        ],
      ),
    );
  }

  Widget _searchBox({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Function(String) onSubmitted,
    required VoidCallback onClear,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, size: 19, color: AppColors.primarySlate),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close, size: 17),
        ),
        filled: true,
        fillColor: const Color(0xffF5F7FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: onSubmitted,
    );
  }

  // ─── Customer List Tab ────────────────────────────────────────────────────
  Widget customerListTab() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      onRefresh: refreshAll,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          filterPanel(),

          if (customers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'No customers found',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ...customers.map(customerCard),

          if (isLoadingMore)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 90),
              child: Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 90),
        ],
      ),
    );
  }

  // ─── Customer Card ────────────────────────────────────────────────────────
  Widget customerCard(Map<String, dynamic> item) {
    final contacts = item['contacts'] ?? [];
    final primaryContact = contacts is List && contacts.isNotEmpty
        ? contacts.firstWhere(
          (c) => c is Map && c['is_primary'] == true,
      orElse: () => contacts[0],
    )
        : null;

    final status = safeText(item['account_status'], '');
    final potential = safeText(item['account_potential'], '');
    final vertical = safeText(item['customer_vertical'], '');
    final name = safeText(item['customer_name'], '');
    final groupName = safeText(item['group_name'], '');
    final city = safeText(item['billing_city'], '');
    final state = safeText(item['billing_state'], '');
    final assignedTo = safeText(item['assigned_user_name'], '-');

    final contactName = safeText(primaryContact?['contact_name'], '-');
    final contactMobile = safeText(primaryContact?['mobile'], '');
    final contactEmail = safeText(primaryContact?['office_email'], '');

    final lastActivityType = safeText(
      item['last_activity_type'] ?? item['last_activity'],
      'Phone Call',
    );

    final lastActivityDate = safeText(
      item['last_activity_date'] ?? item['updated_at'] ?? item['created_at'],
      '-',
    );

    final isExpanded = expandedActionCards.contains(item['id']);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffE6EDF5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            /// PREMIUM HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight.withOpacity(.12),
                    AppColors.primaryDark.withOpacity(.04),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: const Border(
                  bottom: BorderSide(color: Color(0xffE6EDF5)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(name, size: 46, fontSize: 15),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  height: 1.22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDeep,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (groupName.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_outlined,
                                size: 13,
                                color: Color(0xff94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  groupName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff94A3B8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 9),

                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (status.isNotEmpty) _statusBadge(status),
                            if (potential.isNotEmpty)
                              _premiumChip(
                                text: potential,
                                icon: Icons.local_fire_department_rounded,
                                bg: const Color(0xffFFF7ED),
                                fg: const Color(0xffC2410C),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withOpacity(.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryDark.withOpacity(.10),
                          ),
                        ),
                        child: Text(
                          formatCurrency(item['potential_value']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              expandedActionCards.remove(item['id']);
                            } else {
                              expandedActionCards.add(item['id']);
                            }
                          });
                        },
                        child: Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? const Color(0xffFEF2F2)
                                : const Color(0xffF1F5F9),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            isExpanded
                                ? Icons.close_rounded
                                : Icons.more_horiz_rounded,
                            size: 19,
                            color: isExpanded
                                ? const Color(0xffDC2626)
                                : AppColors.primarySlate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// DETAILS BODY
            /// DETAILS BODY - NO INNER CARDS
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _flatCustomerInfo(
                          label: 'Segment',
                          value: vertical,
                          subValue: safeText(item['customer_type'], ''),
                          icon: Icons.category_outlined,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _flatCustomerInfo(
                          label: 'Location',
                          value: city,
                          subValue: state,
                          icon: Icons.location_on_outlined,
                          color: const Color(0xff0D9488),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _thinDivider(),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _flatCustomerInfo(
                          label: 'Assigned To',
                          value: assignedTo,
                          subValue: '',
                          icon: Icons.person_pin_circle_outlined,
                          color: const Color(0xff7C3AED),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _flatCustomerInfo(
                          label: 'Last Activity',
                          value: lastActivityType,
                          subValue: _formatCustomerDate(lastActivityDate),
                          icon: Icons.history_rounded,
                          color: const Color(0xff2563EB),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _thinDivider(),
                  const SizedBox(height: 12),

                  _flatContactInfo(
                    name: contactName,
                    mobile: contactMobile,
                    email: contactEmail,
                  ),

                  /// KEEP PREVIOUS QUICK ACTIONS SAME
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    _thinDivider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _actionBtn(
                          icon: Icons.auto_awesome,
                          label: '360',
                          color: AppColors.primaryLight,
                          bg: const Color(0xffEEF2FF),
                          onTap: () => load360(item),
                        ),
                        _actionBtn(
                          icon: Icons.remove_red_eye_outlined,
                          label: 'View',
                          color: const Color(0xff2563EB),
                          bg: const Color(0xffEFF6FF),
                          onTap: () => openQuickViewDialog(item),
                        ),
                        _actionBtn(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          color: const Color(0xff475569),
                          bg: const Color(0xffF1F5F9),
                          onTap: () => openEditCustomer(item),
                        ),
                        _actionBtn(
                          icon: Icons.change_circle_outlined,
                          label: 'Status',
                          color: const Color(0xffD97706),
                          bg: const Color(0xffFEF3C7),
                          onTap: () => openStatusDialog(item['id'], status),
                        ),
                        _actionBtn(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          color: const Color(0xffEF4444),
                          bg: const Color(0xffFEF2F2),
                          onTap: () => openDeleteDialog(item['id']),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flatCustomerInfo({
    required String label,
    required String value,
    required String subValue,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: .6,
                  color: Color(0xff94A3B8),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xff0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subValue.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff94A3B8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _flatContactInfo({
    required String name,
    required String mobile,
    required String email,
  }) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: const Color(0xffECFDF5),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            size: 18,
            color: Color(0xff059669),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTACT',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: .6,
                  color: Color(0xff94A3B8),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name.trim().isEmpty ? '-' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xff0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (mobile.isNotEmpty)
          _roundMiniIcon(
            icon: Icons.phone_outlined,
            color: const Color(0xff059669),
          ),
        if (email.isNotEmpty) ...[
          const SizedBox(width: 7),
          _roundMiniIcon(
            icon: Icons.mail_outline_rounded,
            color: const Color(0xff64748B),
          ),
        ],
      ],
    );
  }

  Widget _thinDivider() {
    return Container(
      height: 1,
      color: const Color(0xffE8ECF0),
    );
  }


  Widget _roundMiniIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 30,
      width: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _premiumChip({
    required String text,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCustomerDate(String value) {
    if (value.trim().isEmpty || value == '-') return '-';

    try {
      final date = DateTime.parse(value);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day-$month-$year';
    } catch (_) {
      if (value.contains('T')) {
        return value.split('T').first;
      }
      return value;
    }
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── 360 Intelligence Tab ─────────────────────────────────────────────────
  Widget intelligenceTab() {
    if (selected360Customer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: const Color(0xffEEF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.auto_awesome, size: 30, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),
              const Text(
                'Customer 360 Intelligence',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the 360 button on any customer card to view complete intelligence.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, height: 1.6, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (is360Loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryLight),
            const SizedBox(height: 12),
            Text(
              'Loading 360 data...',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final data = customer360Data ?? {};
    final customer = Map<String, dynamic>.from(data['customer'] ?? {});

    return RefreshIndicator(
      color: AppColors.primaryLight,
      onRefresh: () async {
        if (selected360Customer != null) await load360(selected360Customer!);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          _intel360Header(customer),
          const SizedBox(height: 12),
          _intelTabBar(),
          const SizedBox(height: 12),
          _intelTabBody(data),
        ],
      ),
    );
  }

  Widget _intelTabBar() {
    final tabs = [
      {'id': 'overview', 'label': 'Overview', 'icon': Icons.bar_chart},
      {'id': 'leads', 'label': 'Leads', 'icon': Icons.trending_up},
      {'id': 'tenders', 'label': 'Tenders', 'icon': Icons.description_outlined},
      {'id': 'workorders', 'label': 'Work Orders', 'icon': Icons.inventory_2_outlined},
      {'id': 'payments', 'label': 'Payments', 'icon': Icons.currency_rupee},
      {'id': 'products', 'label': 'Products', 'icon': Icons.inventory_outlined},
      {'id': 'activities', 'label': 'KAM', 'icon': Icons.timeline},
      {'id': 'emdbg', 'label': 'BG / EMD', 'icon': Icons.shield_outlined},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final t = tabs[i];
          final active = intelligenceSubTab == t['id'];

          return GestureDetector(
            onTap: () => setState(() => intelligenceSubTab = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? AppColors.primaryDeep : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    t['icon'] as IconData,
                    size: 15,
                    color: active ? Colors.white : AppColors.primarySlate,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    t['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AppColors.primarySlate,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _intelTabBody(Map<String, dynamic> data) {
    switch (intelligenceSubTab) {
      case 'leads':
        return _tab360Leads(data);
      case 'tenders':
        return _tab360Tenders(data);
      case 'workorders':
        return _tab360WorkOrders(data);
      case 'payments':
        return _tab360Payments(data);
      case 'products':
        return _tab360Products(data);
      case 'activities':
        return _tab360KAM(data);
      case 'emdbg':
        return _tab360EMDBG(data);
      default:
        return _tab360Overview(data);
    }
  }

  // ─── 360 Tab: Overview (matches web Tab360Overview) ───────────────────────
  Widget _tab360Overview(Map<String, dynamic> data) {
    final flags = data['flags'] is List ? data['flags'] as List : [];
    final pay = Map<String, dynamic>.from(data['payment_summary'] ?? {});
    final leads = Map<String, dynamic>.from(data['lead_summary'] ?? {});
    final tend = Map<String, dynamic>.from(data['tender_summary'] ?? {});
    final wo = Map<String, dynamic>.from(data['workorder_summary'] ?? {});
    final kam = Map<String, dynamic>.from(data['kam_summary'] ?? {});
    final ak = Map<String, dynamic>.from(data['assigned_kam'] ?? {});
    final ps = data['products_supplied'] is List ? data['products_supplied'] as List : [];
    final contacts = data['contacts'] is List ? data['contacts'] as List : [];

    final winRate = tend['win_rate'];
    final winColor = (winRate != null && _numOf(winRate) >= 50)
        ? const Color(0xff047857)
        : const Color(0xffD97706);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Smart flags
        if (flags.isNotEmpty) smartFlags(flags),

        // Revenue Snapshot
        _sectionLabel('Revenue Snapshot', Icons.currency_rupee),
        _webKpiGrid([
          _webKpiCard('Total Billed', formatCurrency(pay['total_billed'])),
          _webKpiCard('Collected', formatCurrency(pay['total_paid']),
              valueColor: const Color(0xff047857)),
          _webKpiCard('Pending', formatCurrency(pay['total_pending']),
              warn: _numOf(pay['total_pending']) > 0),
          _webKpiCard(
            'Avg Days to Pay',
            pay['avg_days_to_pay'] == null ? '—' : '${_numOf(pay['avg_days_to_pay']).round()}d',
            warn: pay['avg_days_to_pay'] != null && _numOf(pay['avg_days_to_pay']) > 45,
          ),
        ]),

        // Business Pipeline
        _sectionLabel('Business Pipeline', Icons.track_changes),
        _webKpiGrid([
          _webKpiCard('Lead Pipeline', formatCurrency(leads['pipeline_value']),
              sub: '${safeText(leads['active'], '0')} active', valueColor: const Color(0xff1D4ED8)),
          _webKpiCard('Tender Pipeline', formatCurrency(tend['pipeline']),
              sub: '${safeText(tend['pending'], '0')} pending', valueColor: const Color(0xff6D28D9)),
          _webKpiCard('WO Active Value', formatCurrency(wo['active_value']),
              sub: '${safeText(wo['active'], '0')} WOs', valueColor: const Color(0xff1D4ED8)),
          _webKpiCard('Win Rate', _winRateText(winRate), valueColor: winColor),
        ]),

        // KAM Activity Health + Key Contacts
        const SizedBox(height: 16),
        _webOverviewKamCard(kam, ak),
        const SizedBox(height: 12),
        _webOverviewContactsCard(contacts),

        // Top Products Supplied
        if (ps.isNotEmpty) ...[
          _sectionLabel('Top Products Supplied', Icons.inventory_outlined),
          ...ps.take(5).map((e) => _webTopProductTile(Map<String, dynamic>.from(e))),
        ],
      ],
    );
  }

  Widget _tab360Leads(Map<String, dynamic> data) {
    final leads = Map<String, dynamic>.from(data['lead_summary'] ?? {});
    final byStage = Map<String, dynamic>.from(leads['by_stage'] ?? {});
    final unconverted = leads['unconverted_leads'] is List ? leads['unconverted_leads'] as List : [];
    final stale = leads['stale_opps'] is List ? leads['stale_opps'] as List : [];
    final recent = leads['recent'] is List ? leads['recent'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _proKpiPanel([
          _proKpi('Total Leads', safeText(leads['total'], '0'), Icons.trending_up, AppColors.primaryDark),
          _proKpi('Active', safeText(leads['active'], '0'), Icons.play_circle_outline, const Color(0xff2563EB)),
          _proKpi('Converted', safeText(leads['converted'], '0'), Icons.check_circle_outline, const Color(0xff059669)),
          _proKpi('Lost', safeText(leads['lost'], '0'), Icons.cancel_outlined, const Color(0xffD97706)),
          _proKpi('Pipeline Value', formatCurrency(leads['pipeline_value']), Icons.currency_rupee, const Color(0xff2563EB)),
          _proKpi('Total Value', formatCurrency(leads['total_value']), Icons.payments_outlined, AppColors.primarySlate),
          _proKpi('Avg Conv. Time', leads['avg_conv_days'] == null ? '-' : '${leads['avg_conv_days']}d', Icons.timer_outlined, AppColors.primaryLight),
          _proKpi('Stale Opps', '${stale.length}', Icons.warning_amber, stale.isNotEmpty ? const Color(0xffEF4444) : AppColors.primarySlate),
        ]),

        if (byStage.isNotEmpty)
          _barSection('Lead Funnel by Stage', Icons.bar_chart, byStage, safeText(leads['total'], '1')),

        _listMini(
          title: 'Leads Not Yet Converted to Tender',
          icon: Icons.warning_amber,
          items: unconverted,
          empty: 'No unconverted leads',
          danger: true,
          builder: (m) => _threeLineTile(
            title: safeText(m['title'], 'Lead'),
            sub: '${safeText(m['ref'], '-')} • ${safeText(m['days_open'], '0')}d open',
            amount: formatCurrency(m['value']),
            status: safeText(m['status'], ''),
            priority: safeText(m['priority'], ''),
          ),
        ),

        _listMini(
          title: 'Stalled Opportunities (>60 days)',
          icon: Icons.schedule,
          items: stale,
          empty: 'No stalled opportunities',
          danger: true,
          builder: (m) => _threeLineTile(
            title: safeText(m['title'], 'Opportunity'),
            sub: '${safeText(m['ref'], '-')} • ${safeText(m['days_open'], '0')} days open',
            amount: formatCurrency(m['value']),
            status: '',
            priority: '',
          ),
        ),

        _listMini(
          title: 'Recent Leads',
          icon: Icons.trending_up,
          items: recent,
          empty: 'No leads yet for this customer',
          builder: (m) => _threeLineTile(
            title: safeText(m['title'], 'Lead'),
            sub: '${safeText(m['ref'], '-')} • ${safeText(m['created'], '')}',
            amount: formatCurrency(m['value'] ?? m['est_value']),
            status: safeText(m['status'], ''),
            priority: safeText(m['priority'], ''),
          ),
        ),
      ],
    );
  }

  Widget _tab360Tenders(Map<String, dynamic> data) {
    final tend = Map<String, dynamic>.from(data['tender_summary'] ?? {});
    final byStatus = Map<String, dynamic>.from(tend['by_status'] ?? {});
    final loss = tend['loss_analyses'] is List ? tend['loss_analyses'] as List : [];
    final recent = tend['recent'] is List ? tend['recent'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _proKpiPanel([
          _proKpi('Total', safeText(tend['total'], '0'), Icons.description_outlined, AppColors.primaryDark),
          _proKpi('Won', safeText(tend['won'], '0'), Icons.emoji_events_outlined, const Color(0xff059669)),
          _proKpi('Lost', safeText(tend['lost'], '0'), Icons.cancel_outlined, const Color(0xffD97706)),
          _proKpi('Pending', safeText(tend['pending'], '0'), Icons.schedule, AppColors.primarySlate),
          _proKpi('Win Rate', '${safeText(tend['win_rate'], '0')}%', Icons.percent, AppColors.primaryLight),
          _proKpi('Won Value', formatCurrency(tend['won_value']), Icons.currency_rupee, const Color(0xff059669)),
          _proKpi('Lost Value', formatCurrency(tend['lost_value']), Icons.money_off, const Color(0xffD97706)),
          _proKpi('Avg Discount', tend['avg_discount'] == null ? '-' : '${tend['avg_discount']}%', Icons.discount_outlined, AppColors.primarySlate),
        ]),

        if (byStatus.isNotEmpty)
          _countGridSection('Tenders by Status', Icons.bar_chart, byStatus),

        _listMini(
          title: 'Loss Analysis',
          icon: Icons.trending_down,
          items: loss,
          empty: 'No loss analysis',
          danger: true,
          builder: (m) => _proInfoTile(
            title: safeText(m['tender_title'], 'Tender'),
            subtitle: 'Our Bid ${formatCurrency(m['our_bid'])} • L1 ${safeText(m['l1_company'], '-')} ${formatCurrency(m['l1_amount'])} • Position ${safeText(m['our_position'], '-')}'
                '${safeText(m['loss_reason'], '').isNotEmpty ? ' • Reason ${safeText(m['loss_reason'], '')}' : ''}',
            trailing: safeText(m['result_date'], ''),
            icon: Icons.trending_down,
          ),
        ),

        _listMini(
          title: 'Recent Tenders',
          icon: Icons.description_outlined,
          items: recent,
          empty: 'No tenders yet',
          builder: (m) => _threeLineTile(
            title: safeText(m['title'] ?? m['tender_title'], 'Tender #${safeText(m['id'], '')}'),
            sub: '${safeText(m['ref'], '-')} ${safeText(m['submission'], '').isNotEmpty ? '• Due ${safeText(m['submission'], '')}' : ''}',
            amount: formatCurrency(m['est_value']),
            status: safeText(m['status'] ?? m['tender_status'], ''),
            priority: safeText(m['result'], ''),
          ),
        ),
      ],
    );
  }

  Widget _tab360WorkOrders(Map<String, dynamic> data) {
    final wo = Map<String, dynamic>.from(data['workorder_summary'] ?? {});
    final delayed = wo['delayed_wos'] is List ? wo['delayed_wos'] as List : [];
    final warranty = wo['warranty_expiring'] is List ? wo['warranty_expiring'] as List : [];
    final recent = wo['recent'] is List ? wo['recent'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _proKpiPanel([
          _proKpi('Total WOs', safeText(wo['total'], '0'), Icons.inventory_2_outlined, AppColors.primaryDark),
          _proKpi('Active', safeText(wo['active'], '0'), Icons.play_circle_outline, const Color(0xff2563EB)),
          _proKpi('Completed', safeText(wo['completed'], '0'), Icons.check_circle_outline, const Color(0xff059669)),
          _proKpi('Delayed', safeText(wo['delayed'], '0'), Icons.warning_amber, const Color(0xffEF4444)),
          _proKpi('Total Value', formatCurrency(wo['total_value']), Icons.currency_rupee, AppColors.primarySlate),
          _proKpi('Active Value', formatCurrency(wo['active_value']), Icons.payments_outlined, const Color(0xff2563EB)),
          _proKpi('Completed Value', formatCurrency(wo['completed_value']), Icons.verified, const Color(0xff059669)),
          _proKpi('Advance Due', formatCurrency(wo['advance_due']), Icons.pending_actions, const Color(0xffD97706)),
        ]),

        _listMini(
          title: 'Delayed Work Orders',
          icon: Icons.warning_amber,
          items: delayed,
          empty: 'No delayed work orders',
          danger: true,
          builder: (m) => _proInfoTile(
            title: safeText(m['wo_number'], 'WO'),
            subtitle: '${safeText(m['project'], '-')} • Due ${safeText(m['due'], '-')}',
            trailing: '${safeText(m['days_late'], '0')}d late',
            icon: Icons.inventory_2_outlined,
          ),
        ),

        _listMini(
          title: 'Warranty Expiring Soon',
          icon: Icons.shield_outlined,
          items: warranty,
          empty: 'No warranty expiring soon',
          builder: (m) => _proInfoTile(
            title: safeText(m['wo_number'], 'WO'),
            subtitle: '${safeText(m['project'], '-')} • ${safeText(m['expiry'], '')}',
            trailing: '${safeText(m['days_left'], '0')}d left',
            icon: Icons.shield_outlined,
          ),
        ),

        _listMini(
          title: 'Recent Work Orders',
          icon: Icons.inventory_2_outlined,
          items: recent,
          empty: 'No work orders yet',
          builder: (m) => _threeLineTile(
            title: safeText(m['wo_number'], 'WO'),
            sub: '${safeText(m['project'], '-')} ${safeText(m['delivery'], '').isNotEmpty ? '• Due ${safeText(m['delivery'], '')}' : ''}',
            amount: formatCurrency(m['value']),
            status: safeText(m['status'], ''),
            priority: '',
          ),
        ),
      ],
    );
  }

  Widget _tab360Payments(Map<String, dynamic> data) {
    final pay = Map<String, dynamic>.from(data['payment_summary'] ?? {});
    final kam = Map<String, dynamic>.from(data['kam_summary'] ?? {});
    final overdue = pay['overdue_invoices'] is List ? pay['overdue_invoices'] as List : [];
    final trend = pay['monthly_trend'] is List ? pay['monthly_trend'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _proKpiPanel([
          _proKpi('Total Billed', formatCurrency(pay['total_billed']), Icons.receipt_long, AppColors.primaryDark),
          _proKpi('Collected', formatCurrency(pay['total_paid']), Icons.check_circle_outline, const Color(0xff059669)),
          _proKpi('Pending', formatCurrency(pay['total_pending']), Icons.schedule, const Color(0xffD97706)),
          _proKpi('Collection Rate', '${safeText(pay['collection_rate'], '0')}%', Icons.percent, AppColors.primaryLight),
          _proKpi('Avg Days to Pay', pay['avg_days_to_pay'] == null ? '-' : '${pay['avg_days_to_pay'].round()}d', Icons.timer_outlined, AppColors.primarySlate),
          _proKpi('Overdue Invoices', safeText(pay['overdue_count'], '0'), Icons.warning_amber, const Color(0xffEF4444)),
          _proKpi('Overdue Amount', formatCurrency(pay['overdue_amount']), Icons.money_off, const Color(0xffEF4444)),
          _proKpi('KAM Collected', formatCurrency(kam['collected']), Icons.person_pin_circle_outlined, const Color(0xff7C3AED)),
        ]),

        _listMini(
          title: 'Overdue Invoices',
          icon: Icons.warning_amber,
          items: overdue,
          empty: 'No overdue invoices',
          danger: true,
          builder: (m) => _proInfoTile(
            title: safeText(m['invoice_number'], 'Invoice'),
            subtitle: 'Due ${safeText(m['due_date'], '-')} • ${formatCurrency((m['total_amount'] ?? 0) - (m['paid_amount'] ?? 0))} unpaid',
            trailing: '${safeText(m['days_overdue'], '0')}d overdue',
            icon: Icons.receipt_long,
          ),
        ),

        if (trend.isNotEmpty) _paymentTrendSection(trend),
      ],
    );
  }

  Widget _tab360Products(Map<String, dynamic> data) {
    final supplied = data['products_supplied'] is List ? data['products_supplied'] as List : [];
    final demanded = data['products_demanded'] is List ? data['products_demanded'] as List : [];
    final gapCount = demanded.where((p) {
      final m = Map<String, dynamic>.from(p);
      return m['lead_no_tender'] == true && (m['lead_count'] ?? 0) >= 1;
    }).length;

    final items = product360SubTab == 'supplied' ? supplied : demanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _smallSwitch('supplied', 'Supplied (${supplied.length})'),
            const SizedBox(width: 8),
            _smallSwitch('demanded', 'Demanded (${demanded.length})'),
            const Spacer(),
            if (gapCount > 0)
              _chip('$gapCount gaps', const Color(0xffFEF3C7), const Color(0xffD97706)),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: product360SubTab == 'supplied' ? const Color(0xffECFDF5) : const Color(0xffEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: product360SubTab == 'supplied' ? const Color(0xffBBF7D0) : const Color(0xffBFDBFE),
            ),
          ),
          child: Text(
            product360SubTab == 'supplied'
                ? 'Products delivered via completed Work Orders — with quantities, OEM make, WO count, and total value.'
                : 'L = Lead, T = Tender, WO = Work Order. No Tender means product in leads but no tender raised yet.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: product360SubTab == 'supplied' ? const Color(0xff047857) : const Color(0xff1D4ED8),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (items.isEmpty)
          _emptyBox(product360SubTab == 'supplied' ? 'No products supplied yet' : 'No product demand data yet')
        else
          ...items.map((e) {
            final m = Map<String, dynamic>.from(e);
            final isGap = m['lead_no_tender'] == true;
            return _proInfoTile(
              title: safeText(m['product_name'], 'Product'),
              subtitle: product360SubTab == 'supplied'
                  ? 'Qty ${safeText(m['qty_supplied'], '0')} • OEMs ${m['oems'] is List ? (m['oems'] as List).join(', ') : '-'} • WOs ${m['wo_numbers'] is List ? (m['wo_numbers'] as List).join(', ') : '-'}'
                  : 'L ${safeText(m['lead_count'], '0')} • T ${safeText(m['tender_count'], '0')} • WO ${safeText(m['wo_count'], '0')}',
              trailing: product360SubTab == 'supplied'
                  ? '${safeText(m['wo_count'], '0')} WO'
                  : isGap ? 'No Tender' : '',
              icon: product360SubTab == 'supplied' ? Icons.inventory_2_outlined : Icons.trending_up,
            );
          }).toList(),
      ],
    );
  }

  // ─── 360 Tab: KAM (matches web Tab360KAM) ─────────────────────────────────
  Widget _tab360KAM(Map<String, dynamic> data) {
    final kam = Map<String, dynamic>.from(data['kam_summary'] ?? {});
    final byType = Map<String, dynamic>.from(kam['by_type'] ?? {});
    final pending = kam['pending_actions'] is List ? kam['pending_actions'] as List : [];
    final recent = kam['recent'] is List ? kam['recent'] as List : [];
    final daysSince = kam['days_since'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big counters: Calls / Meetings / Demos / Site Visits
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            _webKamCounter('Calls', safeText(kam['calls'], '0'), Icons.phone,
                const Color(0xffEFF6FF), const Color(0xff1D4ED8)),
            _webKamCounter('Meetings', safeText(kam['meetings'], '0'), Icons.groups_outlined,
                const Color(0xffF5F3FF), const Color(0xff6D28D9)),
            _webKamCounter('Demos', safeText(kam['demos'], '0'), Icons.video_call_outlined,
                const Color(0xffF0FDFA), const Color(0xff0F766E)),
            _webKamCounter('Site Visits', safeText(kam['site_visits'], '0'), Icons.navigation_outlined,
                const Color(0xffFFFBEB), const Color(0xffB45309)),
          ],
        ),

        const SizedBox(height: 14),

        // 8-item KPI grid
        _webKpiGrid([
          _webKpiCard('Total Activities', safeText(kam['total_activities'], '0')),
          _webKpiCard('Completed', safeText(kam['completed'], '0'),
              valueColor: const Color(0xff047857)),
          _webKpiCard('Open Tasks', safeText(kam['open_tasks'], '0'),
              warn: _numOf(kam['open_tasks']) > 0),
          _webKpiCard('Overdue Tasks', safeText(kam['overdue_tasks'], '0'),
              warn: _numOf(kam['overdue_tasks']) > 0),
          _webKpiCard('Days Since Contact', daysSince == null ? 'Never' : '${daysSince}d',
              warn: daysSince != null && _numOf(daysSince) > 30),
          _webKpiCard('Revenue Tracked', formatCurrency(kam['revenue_tracked']),
              valueColor: const Color(0xff6D28D9)),
          _webKpiCard('KAM Collected', formatCurrency(kam['collected']),
              valueColor: const Color(0xff047857)),
          _webKpiCard('Uncollected', formatCurrency(kam['uncollected']),
              warn: _numOf(kam['uncollected']) > 0),
        ]),

        // Activity Mix (sorted desc, like web)
        if (byType.isNotEmpty)
          _barSection('Activity Mix', Icons.bar_chart, _sortDesc(byType),
              safeText(kam['total_activities'], '1')),

        // Overdue Follow-ups
        _listMini(
          title: 'Overdue Follow-ups',
          icon: Icons.warning_amber,
          items: pending,
          empty: 'No overdue follow-ups',
          danger: true,
          builder: (m) => _proInfoTile(
            title: safeText(m['subject'], 'Follow-up'),
            subtitle: safeText(m['next_action'], ''),
            trailing: '${safeText(m['days_overdue'], '0')}d overdue',
            icon: Icons.pending_actions,
          ),
        ),

        // Recent Activities
        _listMini(
          title: 'Recent Activities',
          icon: Icons.calendar_month_outlined,
          items: recent,
          empty: 'No KAM activities yet',
          builder: (m) => _threeLineTile(
            title: safeText(m['subject'], 'Activity'),
            sub: safeText(m['outcome'], ''),
            amount: safeText(m['date'], ''),
            status: safeText(m['status'], ''),
            priority: safeText(m['type'], ''),
          ),
        ),
      ],
    );
  }

  Widget _tab360EMDBG(Map<String, dynamic> data) {
    final bg = Map<String, dynamic>.from(data['emdbg_summary'] ?? {});
    final expiring = bg['expiring_soon'] is List ? bg['expiring_soon'] as List : [];
    final byType = Map<String, dynamic>.from(bg['by_type'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _proKpiPanel([
          _proKpi('Total Instruments', safeText(bg['total'], '0'), Icons.shield_outlined, AppColors.primaryDark),
          _proKpi('Active', safeText(bg['active'], '0'), Icons.verified_outlined, const Color(0xff059669)),
          _proKpi('Expiring ≤30 days', '${expiring.length}', Icons.warning_amber, const Color(0xffEF4444)),
          _proKpi('Total Exposure', formatCurrency(bg['total_exposure']), Icons.currency_rupee, const Color(0xffD97706)),
        ]),

        _listMini(
          title: 'Expiring Within 30 Days — Act Now',
          icon: Icons.warning_amber,
          items: expiring,
          empty: 'No BG / EMD expiring soon',
          danger: true,
          builder: (m) => _proInfoTile(
            title: safeText(m['ref'], 'Instrument'),
            subtitle: '${safeText(m['type'], '-')} • ${formatCurrency(m['amount'])} • Expiry ${safeText(m['expiry'], '-')}',
            trailing: '${safeText(m['days_left'], '0')}d left',
            icon: Icons.shield_outlined,
          ),
        ),

        if (byType.isNotEmpty)
          _countGridSection('Active Instruments by Type', Icons.shield_outlined, byType),

        if (safeText(bg['total'], '0') == '0') _emptyBox('No BG / EMD instruments on record'),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WEB-MATCHED 360 HELPERS (Overview + KAM)
  // ══════════════════════════════════════════════════════════════════════════

  double _numOf(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;

  String _winRateText(dynamic v) => v == null ? '—' : '${_numOf(v).toStringAsFixed(1)}%';

  Map<String, dynamic> _sortDesc(Map<String, dynamic> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => _numOf(b.value).compareTo(_numOf(a.value)));
    return {for (final e in entries) e.key: e.value};
  }

  // Web KpiCard equivalent (label on top, value, optional sub, warn → rose).
  Widget _webKpiCard(String label, String value,
      {String? sub, Color? valueColor, bool warn = false}) {
    final vc = warn ? const Color(0xffE11D48) : (valueColor ?? const Color(0xff1E293B));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffEEF2F7)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              letterSpacing: .5,
              fontWeight: FontWeight.w800,
              color: Color(0xff94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: vc),
          ),
          if (sub != null && sub.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Color(0xff94A3B8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _webKpiGrid(List<Widget> cards) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.05,
        children: cards,
      ),
    );
  }

  // Big KAM counter (icon + value + "X done").
  Widget _webKamCounter(String label, String value, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: fg),
                ),
                Text(
                  '$label done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xff94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Single label/value row used inside the Overview KAM Activity Health card.
  Widget _webKamRow(String label, String value, {bool warn = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xffF8FAFC))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xff64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: warn ? const Color(0xffD97706) : const Color(0xff334155),
            ),
          ),
        ],
      ),
    );
  }

  // Overview "KAM Activity Health" card — KAM user header + 6 rows.
  Widget _webOverviewKamCard(Map<String, dynamic> kam, Map<String, dynamic> ak) {
    final userName = safeText(ak['user_name'], '');
    final role = safeText(ak['role'], '');
    final daysSince = kam['days_since'];
    final hasUser = userName.trim().isNotEmpty && userName != '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KAM ACTIVITY HEALTH',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: .6,
              fontWeight: FontWeight.w800,
              color: Color(0xff94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          if (hasUser) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xffDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      userName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xff1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff334155),
                          ),
                        ),
                        if (role.trim().isNotEmpty && role != '-')
                          Text(
                            role,
                            style: const TextStyle(fontSize: 11, color: Color(0xff94A3B8)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          _webKamRow('Total Activities', safeText(kam['total_activities'], '0')),
          _webKamRow('Calls Completed', safeText(kam['calls'], '0')),
          _webKamRow('Meetings Done', safeText(kam['meetings'], '0')),
          _webKamRow('Open Tasks', safeText(kam['open_tasks'], '0'),
              warn: _numOf(kam['open_tasks']) > 0),
          _webKamRow('Overdue Tasks', safeText(kam['overdue_tasks'], '0'),
              warn: _numOf(kam['overdue_tasks']) > 0),
          _webKamRow('Days Since Contact', daysSince == null ? 'Never' : '${daysSince}d',
              warn: daysSince != null && _numOf(daysSince) > 30, isLast: true),
        ],
      ),
    );
  }

  // Overview "Key Contacts" card.
  Widget _webOverviewContactsCard(List contacts) {
    final list = contacts.map((e) => Map<String, dynamic>.from(e)).toList();
    final shown = list.take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY CONTACTS (${list.length})',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: .6,
              fontWeight: FontWeight.w800,
              color: Color(0xff94A3B8),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const Text(
              'No contacts on record',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xff94A3B8)),
            )
          else
            ...shown.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final isLast = i == shown.length - 1;
              final name = safeText(m['name'], '');
              final desig = safeText(m['designation'], '');
              final dept = safeText(m['department'], '');
              final sub = (desig.trim().isNotEmpty && desig != '-')
                  ? desig
                  : ((dept.trim().isNotEmpty && dept != '-') ? dept : '—');
              final isPrimary = m['is_primary'] == true;
              final mobile = safeText(m['mobile'], '');
              final email = safeText(m['email'], '');

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xffF8FAFC))),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 26,
                      width: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xffE0E7FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff4338CA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.trim().isEmpty ? '-' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff334155),
                            ),
                          ),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xff94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    if (isPrimary) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xffDBEAFE),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'P',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xff2563EB)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (mobile.trim().isNotEmpty && mobile != '-')
                      _webMiniContactIcon(Icons.phone, const Color(0xff059669), const Color(0xffECFDF5)),
                    if (email.trim().isNotEmpty && email != '-') ...[
                      const SizedBox(width: 5),
                      _webMiniContactIcon(Icons.mail_outline, const Color(0xff2563EB), const Color(0xffEFF6FF)),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _webMiniContactIcon(IconData icon, Color fg, Color bg) {
    return Container(
      height: 24,
      width: 24,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 12, color: fg),
    );
  }

  // Overview "Top Products Supplied" row.
  Widget _webTopProductTile(Map<String, dynamic> p) {
    final oems = p['oems'] is List ? (p['oems'] as List) : [];
    final oemText = oems.isEmpty
        ? ''
        : 'OEM: ${oems.take(2).join(', ')}${oems.length > 2 ? ' +${oems.length - 2}' : ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffF1F5F9)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: const Color(0xffECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xff059669)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeText(p['product_name'], 'Product'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff1E293B)),
                ),
                if (oemText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    oemText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xff94A3B8)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _webTinyBadge('Qty ${safeText(p['qty_supplied'], '0')}',
              const Color(0xffD1FAE5), const Color(0xff047857)),
          const SizedBox(width: 6),
          _webTinyBadge(formatCurrency(p['total_value']),
              const Color(0xffF1F5F9), const Color(0xff475569)),
        ],
      ),
    );
  }

  Widget _webTinyBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _smallSwitch(String id, String label) {
    final active = product360SubTab == id;
    return GestureDetector(
      onTap: () => setState(() => product360SubTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryDeep : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.primaryDeep : const Color(0xffE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : AppColors.primarySlate,
          ),
        ),
      ),
    );
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
      ),
    );
  }

  Widget _listMini({
    required String title,
    required IconData icon,
    required List items,
    required String empty,
    required Widget Function(Map<String, dynamic>) builder,
    bool danger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title, icon),
          if (items.isEmpty)
            _emptyBox(empty)
          else
            ...items.map((e) => builder(Map<String, dynamic>.from(e))).toList(),
        ],
      ),
    );
  }

  Widget _threeLineTile({
    required String title,
    required String sub,
    required String amount,
    required String status,
    required String priority,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                if (sub.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amount.trim().isNotEmpty)
                Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primarySlate)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  if (priority.trim().isNotEmpty) _chip(priority, const Color(0xffEEF2FF), AppColors.primaryLight),
                  if (status.trim().isNotEmpty) _chip(status, const Color(0xffF1F5F9), const Color(0xff475569)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barSection(String title, IconData icon, Map<String, dynamic> data, String totalText) {
    final total = double.tryParse(totalText) ?? 1;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title, icon),
          ...data.entries.map((e) {
            final v = double.tryParse('${e.value}') ?? 0;
            final factor = total <= 0 ? 0.0 : (v / total).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text('${e.key}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: factor,
                        minHeight: 7,
                        backgroundColor: const Color(0xffE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _countGridSection(String title, IconData icon, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title, icon),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: data.entries.map((e) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffEEF2F7)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${e.value}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                    const SizedBox(height: 3),
                    Text('${e.key}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _paymentTrendSection(List trend) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Monthly Payment Trend (12 months)', Icons.bar_chart),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trend.map((e) {
                final m = Map<String, dynamic>.from(e);
                final billed = double.tryParse('${m['billed'] ?? 0}') ?? 0;
                final paid = double.tryParse('${m['paid'] ?? 0}') ?? 0;
                final maxValue = trend.fold<double>(1, (p, x) {
                  final mx = Map<String, dynamic>.from(x);
                  final b = double.tryParse('${mx['billed'] ?? 0}') ?? 0;
                  final pa = double.tryParse('${mx['paid'] ?? 0}') ?? 0;
                  return [p, b, pa].reduce((a, b) => a > b ? a : b);
                });

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: ((billed / maxValue) * 70).clamp(3, 70),
                            decoration: BoxDecoration(color: const Color(0xffCBD5E1), borderRadius: BorderRadius.circular(4)),
                          ),
                          const SizedBox(width: 2),
                          Container(
                            width: 5,
                            height: ((paid / maxValue) * 70).clamp(3, 70),
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(4)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(safeText(m['month'], '').length >= 7 ? safeText(m['month'], '').substring(5) : safeText(m['month'], ''), style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proKpiPanel(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.85,
        children: children,
      ),
    );
  }

  Widget _proKpi(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _proListSection({
    required String title,
    required IconData icon,
    required List items,
    required String empty,
    required Widget Function(dynamic item) builder,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  empty,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            )
          else
            ...items.map(builder).toList(),
        ],
      ),
    );
  }

  Widget _proInfoTile({
    required String title,
    required String subtitle,
    required String trailing,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffEEF2F7)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffEEF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trailing,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _intel360Header(Map<String, dynamic> customer) {
    final name = safeText(customer['name'] ?? selected360Customer?['customer_name'], '');
    final status = safeText(customer['account_status'] ?? selected360Customer?['account_status'], '');
    final vertical = safeText(customer['vertical'] ?? selected360Customer?['customer_vertical'], '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE8ECF0)),
      ),
      child: Row(
        children: [


          const SizedBox(width: 8),

          _avatar(name, size: 46, fontSize: 15),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  children: [
                    if (status.isNotEmpty) _statusBadge(status),
                    if (vertical.isNotEmpty)
                      _chip(vertical, const Color(0xffEEF2FF), AppColors.primaryLight),
                  ],
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [

              const SizedBox(width: 8),
              GestureDetector(
                onTap: selected360Customer == null
                    ? null
                    : () => load360(selected360Customer!),
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xffF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 18,
                    color: AppColors.primarySlate,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget smartFlags(List flags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Smart Flags', Icons.warning_amber_rounded),
        ...flags.map((f) {
          final item = Map<String, dynamic>.from(f);
          final severity = safeText(item['severity'], 'info').toLowerCase();
          final color = severity == 'critical'
              ? const Color(0xffEF4444)
              : severity == 'warning'
              ? const Color(0xffD97706)
              : const Color(0xff2563EB);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(safeText(item['title'], ''),
                          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(safeText(item['detail'], ''),
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      if (safeText(item['action'], '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '→ ${safeText(item['action'], '')}',
                            style: TextStyle(
                                fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.primarySlate),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primarySlate,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // keep old sectionTitle for compatibility with listSection
  Widget sectionTitle(String title, IconData icon) => _sectionLabel(title, icon);

  Widget kpiGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.7,
      children: children,
    );
  }

  Widget kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE8ECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget listSection({
    required String title,
    required IconData icon,
    required List items,
    required String empty,
    required Widget Function(dynamic item) builder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(title, icon),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffE8ECF0)),
            ),
            child: Text(empty,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 13)),
          )
        else
          ...items.take(6).map(builder),
      ],
    );
  }

  Widget simpleTile({required String title, required String subtitle, String trailing = ''}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE8ECF0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ],
            ),
          ),
          if (trailing.isNotEmpty)
            _chip(trailing, const Color(0xffF1F5F9), const Color(0xff475569)),
        ],
      ),
    );
  }

  // ─── Quick View Dialog ────────────────────────────────────────────────────
  void openQuickViewDialog(Map<String, dynamic> item) {
    final contacts = item['contacts'] ?? [];

    final contact =
    contacts is List && contacts.isNotEmpty ? contacts[0] : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bool isMobile = screenWidth < 700;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 16 : 24,
        ),
        child: Container(
          width: isMobile ? screenWidth : 950,
          height: screenHeight * .90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [

              /// HEADER
              Container(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                decoration:  BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.7),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xffEEF2F7),
                    ),
                  ),
                ),
                child: Column(
                  children: [

                    /// TOP HEADER
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: isMobile ? 52 : 60,
                          width: isMobile ? 52 : 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xff2563EB),
                                Color(0xff1D4ED8),
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            safeText(item['customer_name'], 'C')
                                .substring(0, 2)
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: isMobile ? 18 : 22,
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                safeText(item['customer_name'], ''),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(height: 4),


                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,color: Colors.white,),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Text(
                          safeText(item['customer_vertical'], ''),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _modernTag(
                              safeText(item['account_status'], ''),
                              bg: const Color(0xffF1F5F9),
                              textColor: const Color(0xff475569),
                            ),
                            _modernTag(
                              safeText(item['group_name'], ''),
                              bg: const Color(0xffEFF6FF),
                              textColor: const Color(0xff2563EB),
                            ),
                            _modernTag(
                              safeText(item['approval_display'], ''),
                              bg: const Color(0xffFEF3C7),
                              textColor: const Color(0xffB45309),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),


                  ],
                ),
              ),

              /// BODY
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    children: [

                      /// TOP INFO CARDS
                      Row(
                        children: [
                          Expanded(
                            child: _topInfoCard(
                              "Assigned KAM",
                              safeText(item['assigned_user_name'], '-'),
                              Icons.person_outline_rounded,
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: _topInfoCard(
                              "Potential Value",
                              formatCurrency(item['potential_value']),
                              Icons.currency_rupee_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      /// PRIMARY CONTACT
                      _sectionCard(
                        title: "Primary Contact",
                        icon: Icons.person_outline_rounded,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : 230,
                              child: _infoTile(
                                "NAME",
                                safeText(contact?['contact_name'], '-'),
                                Icons.person_outline_rounded,
                              ),
                            ),

                            SizedBox(
                              width: isMobile ? double.infinity : 230,
                              child: _infoTile(
                                "DESIGNATION",
                                safeText(contact?['designation'], '-'),
                                Icons.badge_outlined,
                              ),
                            ),

                            SizedBox(
                              width: isMobile ? double.infinity : 230,
                              child: _infoTile(
                                "DEPARTMENT",
                                safeText(contact?['department'], '-'),
                                Icons.apartment_rounded,
                              ),
                            ),

                            SizedBox(
                              width: isMobile ? double.infinity : 230,
                              child: _infoTile(
                                "MOBILE",
                                safeText(contact?['mobile'], '-'),
                                Icons.call_outlined,
                                valueColor: const Color(0xff2563EB),
                              ),
                            ),

                            SizedBox(
                              width: isMobile ? double.infinity : 230,
                              child: _infoTile(
                                "EMAIL",
                                safeText(contact?['office_email'], '-'),
                                Icons.mail_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// ACCOUNT INFO
                      _sectionCard(
                        title: "Account Information",
                        icon: Icons.business_center_outlined,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : 340,
                              child: _infoTile(
                                "GROUP",
                                safeText(item['group_name'], '-'),
                                Icons.layers_outlined,
                              ),
                            ),

                            SizedBox(
                              width: isMobile ? double.infinity : 340,
                              child: _infoTile(
                                "DIVISION",
                                safeText(item['division'], '-'),
                                Icons.account_tree_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// ADDRESS
                      _sectionCard(
                        title: "Billing Address",
                        icon: Icons.location_on_outlined,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xffF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xffE2E8F0),
                            ),
                          ),
                          child: Text(
                            '${safeText(item['billing_address'], '')}, '
                                '${safeText(item['billing_city'], '')}, '
                                '${safeText(item['billing_state'], '')}, '
                                '${safeText(item['billing_pincode'], '')}',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              height: 1.4,
                              color: const Color(0xff1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// BOTTOM BUTTONS
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 22),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Color(0xffEEF2F7),
                    ),
                  ),
                ),
                child: isMobile
                    ? Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("Edit Customer"),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xff0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),


                    const SizedBox(width: 8),

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Close"),
                      ),
                    ),

                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(110, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text("Close"),
                    ),

                    const SizedBox(width: 12),

                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text("Edit Customer"),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xff0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(170, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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

  /// SECTION CARD
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE2E8F0)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xff64748B)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xff334155),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  /// INFO TILE
  Widget _infoTile(
      String title,
      String value,
      IconData icon, {
        Color? valueColor,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xff94A3B8),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xff94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xff1E293B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// TAG
  Widget _modernTag(
      String text, {
        required Color bg,
        required Color textColor,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// TOP SMALL CARD
  Widget _topInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: Color(0xff94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xff64748B)),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(title,
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDeep, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────
  Future<void> openAddCustomer() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateCustomer()),
    );
    if (added == true) await refreshAll();
  }

  Future<void> openEditCustomer(Map<String, dynamic> item) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCustomer(customerData: Map<String, dynamic>.from(item)),
      ),
    );
    if (updated == true) await refreshAll();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F6FA),
      body: Column(
        children: [
          header(),
          Expanded(
            child: show360View ? intelligenceTab() : customerListTab(),
          ),
        ],
      ),
    );
  }
}
