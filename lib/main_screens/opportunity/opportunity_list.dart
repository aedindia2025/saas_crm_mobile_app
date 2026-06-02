import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../Leads/view_lead.dart';
import 'edit_opportunity.dart';

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
  const OpportunityList({super.key});

  @override
  State<OpportunityList> createState() => _OpportunityListState();
}

class _OpportunityListState extends State<OpportunityList> {
  static const String baseUrl = 'http://103.110.236.187:3076/api/v1';
  static const String tenantSlug = 'ascent';

  bool showFilters = false;

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



  List<Map<String, dynamic>> opportunities = [];

  @override
  void initState() {
    super.initState();
    getSharedPref();
  }


  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> getSharedPref() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');

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
      final customerRes = await http.get(
        Uri.parse('$baseUrl/leads/team-customers'),
        headers: headers,
      );

      final userRes = await http.get(
        Uri.parse('$baseUrl/leads/team-users'),
        headers: headers,
      );

      if (customerRes.statusCode == 200) {
        final List data = jsonDecode(customerRes.body);
        customers = data
            .where((x) => x['id'] != null && x['customer_name'] != null)
            .map((x) => {
          'id': int.tryParse(x['id'].toString()),
          'label': x['customer_name'].toString(),
        })
            .where((x) => x['id'] != null && x['label'].toString().trim().isNotEmpty)
            .toList();
      }

      if (userRes.statusCode == 200) {
        final List data = jsonDecode(userRes.body);
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
    'X-Tenant-Slug': tenantSlug,
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
      setState(() => isLoading = true);

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

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List res = jsonDecode(response.body);

        final filtered = res
            .where((item) {
          final status = item['status']?.toString() ?? '';
          return status == 'Opportunity Created' || status == 'Converted';
        })
            .map((e) => Map<String, dynamic>.from(e))
            .where((item) {
          final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');

          if (fromDate != null && createdAt != null) {
            final start = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
            if (createdAt.isBefore(start)) return false;
          }

          if (toDate != null && createdAt != null) {
            final end = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);
            if (createdAt.isAfter(end)) return false;
          }

          return true;
        })
            .toList();

        setState(() {
          opportunities = filtered;
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

    final res = await http.delete(
      Uri.parse('$baseUrl/leads/$id'),
      headers: headers,
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      await refreshList();
    } else {
      showError(res.body);
    }
  }

  void openLeadViewPage(Map<String, dynamic> item) {
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
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditOpportunity(
                opportunityData: Map<String, dynamic>.from(item),
              ),
            ),
          );

          if (updated == true) {
            await refreshList();
          }
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
    final refId = safeText(item['opportunity_ref_id'] ?? item['lead_ref_id'] ?? item['id'], '');

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openOpportunityDetailsDialog(item),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: AppColors.primaryDeep.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: const Border(
                  bottom: BorderSide(color: Color(0xffE8ECF0)),
                ),
              ),
              child: Row(
                children: [
                  _avatar(title),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.tag_outlined, size: 12, color: Colors.grey),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '# $refId',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCurrency(item['est_value']),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      opportunityMenu(item),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _statusBadge(statusText),
                      const SizedBox(width: 6),
                      if (priority.isNotEmpty)
                        _chip(
                          priority,
                          priorityColor(priority).withOpacity(0.12),
                          priorityColor(priority),
                        ),
                      const SizedBox(width: 6),
                      _chip(
                        statusText == 'Converted' ? 'S3' : 'S2',
                        statusText == 'Converted'
                            ? const Color(0xffECFDF5)
                            : const Color(0xffF3E8FF),
                        statusText == 'Converted'
                            ? const Color(0xff059669)
                            : const Color(0xff7C3AED),
                      ),
                      const Spacer(),
                      if (approval.toLowerCase() == 'approved')
                        _chip(
                          'Approved',
                          const Color(0xffECFDF5),
                          const Color(0xff059669),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: smallInfo(Icons.business_outlined, customer)),
                      Expanded(child: smallInfo(Icons.person_outline, contact)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(child: smallInfo(Icons.assignment_ind_outlined, assignedTo)),
                      Expanded(child: smallInfo(Icons.event_available_outlined, 'Follow: ${formatDate(followUp)}')),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(child: smallInfo(Icons.calendar_today_outlined, formatDate(createdAt))),
                      Expanded(child: smallInfo(Icons.access_time, formatTime(createdAt))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          const SizedBox(height: 24),
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