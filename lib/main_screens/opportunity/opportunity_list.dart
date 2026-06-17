import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_helpers/api_method.dart';

import '../Leads/view_lead.dart';
import 'new_opportunity_page.dart';
import 'opportunity_view_page.dart';

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

class OpportunityList extends StatefulWidget {
  final String tenantSlug;
  const OpportunityList({super.key, required this.tenantSlug});

  @override
  State<OpportunityList> createState() => _OpportunityListState();
}

class _OpportunityListState extends State<OpportunityList> {
  static const String baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1';

  bool showFilters = false;

  final ScrollController _scrollController = ScrollController();

  bool isLoadingMore = false;
  int skip = 0;
  final int limit = 10;
  bool hasMore = true;

  List<Map<String, dynamic>> opportunities = [];
  List<Map<String, dynamic>> allOpportunities = [];

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> assignedUsers = [];

  final TextEditingController searchController = TextEditingController();

  String searchText = '';
  int? selectedCustomerId;
  int? selectedAssignedToId;
  DateTime? fromDate;
  DateTime? toDate;

  bool isLoading = true;
  String? token;
  String? userRole;


  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 250 &&
          hasMore &&
          !isLoadingMore &&
          !isLoading) {
        loadMoreOpportunitiesFromLocal();
      }
    });

    getSharedPref();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void loadMoreOpportunitiesFromLocal() {
    if (!hasMore || isLoadingMore) return;

    setState(() => isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      final nextItems = allOpportunities.skip(skip).take(limit).toList();

      setState(() {
        opportunities.addAll(nextItems);
        skip = opportunities.length;
        hasMore = opportunities.length < allOpportunities.length;
        isLoadingMore = false;
      });
    });
  }

  Future<void> getSharedPref() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    userRole = prefs.getString('role');

    if (token == null) {
      setState(() => isLoading = false);
      showError('Token not found');
      return;
    }

    await loadMasters();
    await fetchOpportunityList();
  }

  Future<void> loadMasters() async {
    if (token == null) return;

    try {
      final customerRes = await ApiMethod.getRequest(
        url: '$baseUrl/leads/team-customers',
        headers: headers,
      );

      final userRes = await ApiMethod.getRequest(
        url: '$baseUrl/leads/team-users',
        headers: headers,
      );

      if (customerRes['statusCode'] == 200) {
        final List data = customerRes['data'];
        customers = data
            .where((x) => x['id'] != null && x['customer_name'] != null)
            .map((x) => {
          'id': int.tryParse(x['id'].toString()),
          'label': x['customer_name'].toString(),
        })
            .where((x) => x['id'] != null && x['label'].toString().trim().isNotEmpty)
            .toList();
      }

      if (userRes['statusCode'] == 200) {
        final List data = userRes['data'];
        assignedUsers = data
            .where((x) => x['id'] != null && x['label'] != null)
            .map((x) => {
          'id': int.tryParse(x['id'].toString()),
          'label': x['label'].toString(),
        })
            .where((x) => x['id'] != null && x['label'].toString().trim().isNotEmpty)
            .toList();
      }

      if (mounted) setState(() {});
    } catch (e) {
      showError(e.toString());
    }
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'X-Tenant-Slug': widget.tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

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
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search opportunities',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        searchController.clear();
                        searchText = '';
                        fetchOpportunityList();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
                    filled: true,
                    fillColor: const Color(0xffF5F7FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    searchText = value;
                    setState(() {});
                  },
                  onSubmitted: (value) {
                    searchText = value;
                    fetchOpportunityList();
                  },
                ),
              ),
              const SizedBox(width: 10),
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
                  ),
                ),
              ),
            ],
          ),

          if (showFilters) ...[
            const SizedBox(height: 12),

            DropdownButtonFormField<int>(
              value: selectedCustomerId,
              isExpanded: true,
              decoration: _filterInputDecoration('All Customers'),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('All Customers'),
                ),
                ...customers.map((c) => DropdownMenuItem<int>(
                  value: c['id'],
                  child: Text(c['label'].toString(), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (value) {
                setState(() => selectedCustomerId = value);
                fetchOpportunityList();
              },
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<int>(
              value: selectedAssignedToId,
              isExpanded: true,
              decoration: _filterInputDecoration('All Assigned To'),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('All Assigned To'),
                ),
                ...assignedUsers.map((u) => DropdownMenuItem<int>(
                  value: u['id'],
                  child: Text(u['label'].toString(), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (value) {
                setState(() => selectedAssignedToId = value);
                fetchOpportunityList();
              },
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _dateFilterBox(
                    label: fromDate == null
                        ? 'From Date'
                        : '${fromDate!.year}-${fromDate!.month.toString().padLeft(2, '0')}-${fromDate!.day.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fromDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => fromDate = picked);
                        fetchOpportunityList();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateFilterBox(
                    label: toDate == null
                        ? 'To Date'
                        : '${toDate!.year}-${toDate!.month.toString().padLeft(2, '0')}-${toDate!.day.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => toDate = picked);
                        fetchOpportunityList();
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: clearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _filterInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xffF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _dateFilterBox({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xffF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primarySlate,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16),
          ],
        ),
      ),
    );
  }

  void clearFilters() {
    searchController.clear();

    setState(() {
      searchText = '';
      selectedCustomerId = null;
      selectedAssignedToId = null;
      fromDate = null;
      toDate = null;
    });

    fetchOpportunityList();
  }

  Future<void> fetchOpportunityList() async {
    if (token == null) return;

    try {
      setState(() {
        isLoading = true;
        isLoadingMore = false;
        skip = 0;
        hasMore = true;
        opportunities.clear();
        allOpportunities.clear();
      });

      final query = <String, String>{};

      if (searchText.trim().isNotEmpty) {
        query['search'] = searchText.trim();
      }

      if (selectedCustomerId != null) {
        query['customer_id'] = selectedCustomerId.toString();
      }

      if (selectedAssignedToId != null) {
        query['assigned_to'] = selectedAssignedToId.toString();
      }

      final uri = Uri.parse('$baseUrl/leads').replace(
        queryParameters: query.isEmpty ? null : query,
      );

      final response = await ApiMethod.getRequest(
        url: uri.toString(),
        headers: headers,
      );

      if (response['statusCode'] == 200) {
        final List res = response['data'];

        final filtered = res
            .where((item) {
          final status = item['status']?.toString() ?? '';
          return status == 'Opportunity Created' || status == 'Converted';
        })
            .map((e) => Map<String, dynamic>.from(e))
            .where((item) {
          final createdAt = DateTime.tryParse(
            item['created_at']?.toString() ?? '',
          );

          if (fromDate != null && createdAt != null) {
            final start = DateTime(
              fromDate!.year,
              fromDate!.month,
              fromDate!.day,
            );
            if (createdAt.isBefore(start)) return false;
          }

          if (toDate != null && createdAt != null) {
            final end = DateTime(
              toDate!.year,
              toDate!.month,
              toDate!.day,
              23,
              59,
              59,
            );
            if (createdAt.isAfter(end)) return false;
          }

          return true;
        })
            .toList();

        if (!mounted) return;

        setState(() {
          allOpportunities = filtered;

          opportunities = allOpportunities.take(limit).toList();
          skip = opportunities.length;
          hasMore = opportunities.length < allOpportunities.length;

          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });

        showError(response['data']?.toString() ?? 'Error fetching opportunities');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });

      showError(e.toString());
    }
  }

  Future<void> deleteOpportunity(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this opportunity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final res = await ApiMethod.deleteRequest(
      url: '$baseUrl/leads/$id',
      headers: headers,
    );

    if (res['statusCode'] == 200 || res['statusCode'] == 204) {
      await refreshList();
    } else {
      showError(res['data']?.toString() ?? 'Failed to delete opportunity');
    }
  }

  // View an opportunity. Direct opportunities (and any converted lead) open the
  // new 5-tab OpportunityViewPage; anything without a valid id falls back to the
  // read-only LeadViewPage.
  void openLeadViewPage(
      Map<String, dynamic> item, {
        TabKey? initialTab,
      }) {
    final id = int.tryParse(item['id']?.toString() ?? '');

    if (id != null && id > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpportunityViewPage(
            leadId: id,
            initialTab: initialTab,
          ),
        ),
      ).then((_) => refreshList());
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadViewPage(
          leadData: Map<String, dynamic>.from(item),
          isReadOnly: true,
        ),
      ),
    );
  }

  Future<void> refreshList() async {
    await fetchOpportunityList();
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String safeText(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String initials(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'OP';
    return text.length >= 2 ? text.substring(0, 2).toUpperCase() : text.toUpperCase();
  }

  String formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final displayHour = hour == 0 ? 12 : hour;
    final ampm = date.hour >= 12 ? 'pm' : 'am';

    return '${displayHour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ampm';
  }

  String formatCurrency(dynamic raw) {
    final value = double.tryParse((raw ?? 0).toString()) ?? 0;

    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';

    return value.toStringAsFixed(0);
  }

  String opportunityStatusText(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? '';
    final approval = item['approval_status']?.toString().toLowerCase() ?? '';

    if (status == 'Converted') return 'Converted';
    if (approval == 'pending') return 'Request Conversion';
    if (approval == 'rejected' || approval == 'rejected opportunity') return 'Rejected';

    return 'Opportunity';
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Converted':
        return const Color(0xff059669);
      case 'Request Conversion':
        return const Color(0xffD97706);
      case 'Rejected':
        return const Color(0xffDC2626);
      default:
        return const Color(0xff7C3AED);
    }
  }

  Color priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'critical':
        return const Color(0xffDC2626);
      case 'medium':
        return const Color(0xffD97706);
      case 'low':
        return const Color(0xff059669);
      default:
        return AppColors.primarySlate;
    }
  }

  Widget header() {
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

                GestureDetector(
                  onTap: () {
                    setState(() {
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
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Opportunities',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${opportunities.length} total records',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                GestureDetector(
                  onTap: () async {
                    // New create flow. NewOpportunityPage itself opens the live
                    // OpportunityViewPage (Quotations tab) on save, so here we
                    // just refresh the list when we come back.
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NewOpportunityPage(),
                      ),
                    );
                    await refreshList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
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
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name) {
    return Container(
      height: 38,
      width: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.headerGradient,
      ),
      child: Text(
        initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget smallInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.primarySlate.withOpacity(0.65)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text.isEmpty ? '-' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget opportunityMenu(Map<String, dynamic> item) {
    final status = safeText(item['status'], '');
    final isConverted = status == 'Converted';

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppColors.primarySlate,
        size: 22,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      color: Colors.white,
      onSelected: (value) async {
        if (value == 'view') {
          openLeadViewPage(item);
        }

        if (value == 'edit') {
          final id = int.tryParse(item['id']?.toString() ?? '');

          if (id == null || id == 0) {
            showError('Opportunity ID not found');
            return;
          }

          // Both direct opportunities and converted leads open the 5-tab
          // OpportunityViewPage. It lands on the Lead Details tab, which has
          // the inline edit form (for a plain lead it shows only that tab).
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OpportunityViewPage(leadId: id),
            ),
          );

          await refreshList();
        }

        if (value == 'delete') {
          await deleteOpportunity(item);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18),
              SizedBox(width: 10),
              Text('View'),
            ],
          ),
        ),

        if (!isConverted)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Edit Opportunity'),
              ],
            ),
          ),

        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget opportunityCard(Map<String, dynamic> item) {
    final title = safeText(item['lead_title'], '');
    final customer = safeText(item['customer_name'], '');
    final statusText = opportunityStatusText(item);
    final priority = safeText(item['priority'], '');
    final approval = safeText(item['approval_status'], 'None');
    final assignedTo = safeText(item['assigned_to_name'], 'Unassigned');
    final contact = safeText(item['contact_person'], '');
    final createdAt = item['created_at'];
    final followUp = item['follow_up'];
    final timeline = item['timeline'];

    final refId = safeText(
      item['opportunity_ref_id'] ?? item['lead_ref_id'] ?? item['id'],
      '',
    );

    final source = safeText(
      item['source'] ?? item['lead_source'] ?? item['source_type'],
      'Direct Enquiry',
    );

    final sourceSub = safeText(
      item['source_detail'] ?? item['lead_source_detail'],
      'Direct',
    );

    final mobile = safeText(item['mobile'], '');
    final email = safeText(item['email'], '');

    final lastActivity = safeText(
      item['last_activity'] ?? item['last_activity_type'],
      statusText == 'Converted' ? 'Convert' : 'Create',
    );

    final statusClr = statusColor(statusText);
    final priorityClr = priorityColor(priority);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE6ECF3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => openOpportunityDetailsDialog(item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [

                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Column(
                    children: [
                      /// OPPORTUNITY HEADER
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppColors.headerGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryDark.withOpacity(.16),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Text(
                              initials(title),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _opportunityLabel('OPPORTUNITY'),
                                const SizedBox(height: 5),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    height: 1.22,
                                    color: Color(0xff0F172A),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.business_outlined,
                                      size: 13,
                                      color: Color(0xff94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        customer,
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
                                  color: AppColors.primaryDark.withOpacity(.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.primaryDark.withOpacity(.10),
                                  ),
                                ),
                                child: Text(
                                  '₹${formatCurrency(item['est_value'])}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              opportunityMenu(item),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      /// STATUS / PRIORITY / STAGE
                      Row(
                        children: [
                          if (statusText.isNotEmpty)
                            _modernOpportunityStatusPill(statusText),
                          if (priority.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _modernOpportunityPriorityPill(priority, priorityClr),
                          ],
                          const Spacer(),
                          _stagePill(statusText == 'Converted' ? 'S3' : 'S2'),
                        ],
                      ),

                      const SizedBox(height: 14),
                      _opportunityThinDivider(),
                      const SizedBox(height: 13),

                      /// SOURCE + OWNER
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _premiumOpportunityInfo(
                              label: 'SOURCE',
                              value: source,
                              subValue: sourceSub,
                              icon: Icons.source_outlined,
                              color: AppColors.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _premiumOpportunityInfo(
                              label: 'OWNER',
                              value: assignedTo,
                              subValue: approval.toLowerCase() == 'approved'
                                  ? 'Approved'
                                  : '',
                              icon: Icons.person_pin_circle_outlined,
                              color: const Color(0xff7C3AED),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),
                      _opportunityThinDivider(),
                      const SizedBox(height: 13),

                      /// TIMELINE + CONTACT
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _premiumOpportunityTimeline(
                              timeline: timeline,
                              followUp: followUp,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _premiumOpportunityContact(
                              contact: contact,
                              mobile: mobile,
                              email: email,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 13),
                      _opportunityThinDivider(),
                      const SizedBox(height: 13),

                      /// LAST ACTIVITY + REF
                      Row(
                        children: [
                          Expanded(
                            child: _premiumOpportunityInfo(
                              label: 'LAST ACTIVITY',
                              value: lastActivity,
                              subValue: formatDate(createdAt),
                              icon: Icons.history_rounded,
                              color: const Color(0xff2563EB),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xffE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.tag_outlined,
                                    size: 14,
                                    color: Color(0xff64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      refId.isEmpty ? 'Ref -' : '#$refId',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xff64748B),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _opportunityLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: .7,
            color: Color(0xff64748B),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 3),
        const Icon(
          Icons.unfold_more_rounded,
          size: 11,
          color: Color(0xffCBD5E1),
        ),
      ],
    );
  }

  Widget _premiumOpportunityInfo({
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
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _opportunityLabel(label),
              const SizedBox(height: 5),
              Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  color: Color(0xff0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subValue.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.3,
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

  Widget _premiumOpportunityTimeline({
    required dynamic timeline,
    required dynamic followUp,
  }) {
    final timelineText = formatDate(timeline);
    final followText = formatDate(followUp);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: const Color(0xffFFF7ED),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.event_available_outlined,
            size: 17,
            color: Color(0xffF59E0B),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _opportunityLabel('TIMELINE'),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      timelineText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.7,
                        color: Color(0xffF59E0B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: Color(0xffF59E0B),
                  ),
                ],
              ),
              if (followText != '-') ...[
                const SizedBox(height: 3),
                Text(
                  'Timeline: $followText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.3,
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

  Widget _premiumOpportunityContact({
    required String contact,
    required String mobile,
    required String email,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: const Color(0xffECFDF5),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            size: 17,
            color: Color(0xff059669),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _opportunityLabel('CONTACT'),
              const SizedBox(height: 5),
              Text(
                contact.trim().isEmpty ? '-' : contact,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff0F172A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  if (mobile.isNotEmpty)
                    _opportunityCircleIcon(
                      icon: Icons.phone_outlined,
                      color: const Color(0xff059669),
                    ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _opportunityCircleIcon(
                      icon: Icons.mail_outline_rounded,
                      color: const Color(0xff2563EB),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modernOpportunityStatusPill(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernOpportunityPriorityPill(String priority, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            priority,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagePill(String stage) {
    final isS3 = stage == 'S3';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isS3 ? const Color(0xffECFDF5) : const Color(0xffF3E8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stage,
        style: TextStyle(
          fontSize: 10.5,
          color: isS3 ? const Color(0xff059669) : const Color(0xff7C3AED),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _opportunityCircleIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 25,
      width: 25,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }

  Widget _opportunityThinDivider() {
    return Container(
      height: 1,
      color: const Color(0xffE8ECF0),
    );
  }

  void openOpportunityDetailsDialog(Map<String, dynamic> item) {
    final statusText = opportunityStatusText(item);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxHeight: 680),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    _avatar(safeText(item['lead_title'], '')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        safeText(item['lead_title'], ''),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                detailRow('Opportunity Ref', safeText(item['opportunity_ref_id'], '-')),
                detailRow('Customer', safeText(item['customer_name'], '')),
                detailRow('Contact', safeText(item['contact_person'], '')),
                detailRow('Mobile', safeText(item['mobile'], '')),
                detailRow('Email', safeText(item['email'], '')),
                detailRow('Priority', safeText(item['priority'], '')),
                detailRow('Stage', statusText),
                detailRow('Approval', safeText(item['approval_status'], 'None')),
                detailRow('Assigned To', safeText(item['assigned_to_name'], '')),
                detailRow('Value', formatCurrency(item['est_value'])),
                detailRow('Timeline', formatDate(item['timeline'])),
                detailRow('Follow Up', formatDate(item['follow_up'])),
                detailRow('Address', safeText(item['customer_address'], '')),
                detailRow('Notes', safeText(item['notes'], '')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      openLeadViewPage(item);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open Opportunity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                productsBox(item),
              ],
            ),
          ),
        ),
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
            width: 116,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDeep,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget productsBox(Map<String, dynamic> item) {
    final products = item['products'];

    if (products is! List || products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: const Text(
          'No products added',
          style: TextStyle(
            color: Color(0xff64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Products & OEM Details',
            style: TextStyle(
              color: AppColors.primaryDeep,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...products.map((p) {
          final product = Map<String, dynamic>.from(p);
          final oems = product['oems'] is List ? product['oems'] as List : [];

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 17, color: Color(0xff7C3AED)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        safeText(product['product_name'], 'Product'),
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _chip(
                      'Qty ${safeText(product['quantity'], '1')}',
                      const Color(0xffF1F5F9),
                      const Color(0xff64748B),
                    ),
                  ],
                ),
                if (safeText(product['description'], '').isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    safeText(product['description'], ''),
                    style: const TextStyle(
                      color: Color(0xff64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (oems.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: oems.map((o) {
                      final m = o is Map ? Map<String, dynamic>.from(o) : {};
                      return _chip(
                        safeText(m['oem_name'], 'OEM'),
                        Colors.white,
                        AppColors.primarySlate,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
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
      color: AppColors.primaryLight,
      onRefresh: refreshList,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          filterPanel(),

          if (opportunities.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'No opportunities found',
                  style: TextStyle(
                    color: Color(0xff64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            ...opportunities.map(opportunityCard),

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