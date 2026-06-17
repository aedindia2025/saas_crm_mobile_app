  import 'dart:convert';

  import 'package:ascent_crm/main_screens/Leads/view_lead.dart';
  import 'package:flutter/material.dart';
  import 'package:shared_preferences/shared_preferences.dart';

  import '../../api_helpers/api_method.dart';
  import 'create_lead.dart';
  import '../opportunity/opportunity_view_page.dart';

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

  class LeadList extends StatefulWidget {
    const LeadList({super.key});

    @override
    State<LeadList> createState() => _LeadListState();
  }

  class _LeadListState extends State<LeadList> {
    static const String baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1';
    String? tenantSlug;

    final ScrollController _scrollController = ScrollController();

    bool isLoadingMore = false;
    int skip = 0;
    final int limit = 10;
    bool hasMore = true;

    bool showFilters = false;
    bool isLoading = true;
    bool isMasterLoading = false;
    String? token;

    List<Map<String, dynamic>> leads = [];
    List<Map<String, dynamic>> allLeads = [];

    List<Map<String, dynamic>> customers = [];
    List<Map<String, dynamic>> assignedUsers = [];

    final TextEditingController searchController = TextEditingController();

    String searchText = '';
    int? selectedCustomerId;
    int? selectedAssignedToId;
    DateTime? fromDate;
    DateTime? toDate;

    final List<String> statusOptions = const [
      'Assigned',
      'Qualified',
      'Opportunity Created',
      'Lost',
    ];

    @override
    void initState() {
      super.initState();

      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
            hasMore &&
            !isLoadingMore &&
            !isLoading) {
          loadMoreLeadsFromLocal();
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

    void loadMoreLeadsFromLocal() {
      if (!hasMore || isLoadingMore) return;

      setState(() => isLoadingMore = true);

      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;

        final nextItems = allLeads.skip(skip).take(limit).toList();

        setState(() {
          leads.addAll(nextItems);
          skip = leads.length;
          hasMore = leads.length < allLeads.length;
          isLoadingMore = false;
        });
      });
    }

    Future<void> getSharedPref() async {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
      tenantSlug = prefs.getString('tenant_slug');

      if (token == null || tenantSlug == null) {
        setState(() => isLoading = false);
        showSnack(token == null ? 'Token not found' : 'Organization code not found', Colors.red);
        return;
      }

      await loadMasters();
      await fetchLeads(reset: true);
    }

    Map<String, String> get headers => {
      'Authorization': 'Bearer $token',
      'X-Tenant-Slug': tenantSlug ?? '',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

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

          setState(() {
            customers = data
                .where((x) => x['id'] != null && x['customer_name'] != null)
                .map((x) => {
              'id': int.tryParse(x['id'].toString()),
              'label': x['customer_name'].toString(),
            })
                .where((x) => x['id'] != null && x['label'].toString().trim().isNotEmpty)
                .toList();
          });
        } else {
          showSnack('Customer dropdown failed: ${customerRes['data']}', Colors.red);
        }

        if (userRes['statusCode'] == 200) {
          final List data = userRes['data'];

          setState(() {
            assignedUsers = data
                .where((x) => x['id'] != null && x['label'] != null)
                .map((x) => {
              'id': int.tryParse(x['id'].toString()),
              'label': x['label'].toString(),
              'role': x['role']?.toString() ?? '',
            })
                .where((x) => x['id'] != null && x['label'].toString().trim().isNotEmpty)
                .toList();
          });
        } else {
          showSnack('Assigned dropdown failed: ${userRes['data']}', Colors.red);
        }
      } catch (e) {
        showSnack(e.toString(), Colors.red);
      }
    }

    Future<void> fetchLeads({bool reset = true}) async {
      if (token == null) return;

      if (reset) {
        skip = 0;
        hasMore = true;
        allLeads.clear();
        leads.clear();
        setState(() => isLoading = true);
      }

      try {
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
          final List data = response['data'];

          final loaded = data.map((e) {
            return Map<String, dynamic>.from(e);
          }).toList();

          final filtered = loaded.where((lead) {
            final createdAt = DateTime.tryParse(
              lead['created_at']?.toString() ?? '',
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
          }).toList();

          if (!mounted) return;

          setState(() {
            allLeads = filtered;

            leads = allLeads.take(limit).toList();
            skip = leads.length;
            hasMore = leads.length < allLeads.length;

            isLoading = false;
            isLoadingMore = false;
          });
        } else {
          if (!mounted) return;

          setState(() {
            isLoading = false;
            isLoadingMore = false;
          });

          showSnack(extractError(jsonEncode(response['data'])), Colors.red);
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

    Future<void> refreshAll() async {
      await loadMasters();
      await fetchLeads(reset: true);
    }

    Future<void> updateLeadStatus(dynamic leadId, String status) async {
      if (token == null) return;

      try {
        final response = await ApiMethod.patchRequest(
          url: '$baseUrl/leads/$leadId/status',
          headers: headers,
          body: {'status': status},
        );

        if (response['statusCode'] == 200 || response['statusCode'] == 201) {
          showSnack('Status updated successfully', Colors.green);
          fetchLeads(reset: true);
        } else {
          showSnack(extractError(jsonEncode(response['data'])), Colors.red);
        }
      } catch (e) {
        showSnack(e.toString(), Colors.red);
      }
    }

    String extractError(String body) {
      try {
        final data = jsonDecode(body);
        final detail = data['detail'];
        if (detail is String) return detail;
        return body;
      } catch (_) {
        return body;
      }
    }

    void showSnack(String message, Color color) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
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
      if (text.isEmpty) return 'LD';
      return text.length >= 2 ? text.substring(0, 2).toUpperCase() : text.toUpperCase();
    }

    String formatCurrency(dynamic raw) {
      final value = double.tryParse((raw ?? 0).toString()) ?? 0;
      if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
      if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
      if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
      return value.toStringAsFixed(0);
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

    Color statusColor(String status) {
      switch (status.toLowerCase()) {
        case 'converted':
          return const Color(0xff059669);
        case 'lost':
          return const Color(0xffDC2626);
        case 'opportunity created':
          return const Color(0xff7C3AED);
        case 'qualified':
          return const Color(0xff2563EB);
        default:
          return AppColors.primaryLight;
      }
    }

    Color priorityColor(String priority) {
      switch (priority.toLowerCase()) {
        case 'high':
          return const Color(0xffEF4444);
        case 'medium':
          return const Color(0xffF59E0B);
        case 'low':
          return const Color(0xff059669);
        default:
          return AppColors.primarySlate;
      }
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
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
            fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w800,
            fontSize: 11,
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

    Widget header() {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          'Leads',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${leads.length} total records',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.60),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateLead(),
                        ),
                      );

                      if (updated == true) {
                        await refreshAll();
                      }
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
                  SizedBox(width: 5,),
                //  _headerIconBtn(Icons.refresh_rounded, refreshAll),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      );
    }
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
                      hintText: 'Search leads',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 19, color: AppColors.primarySlate),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              onPressed: () {
                                searchController.clear();
                                searchText = '';
                                fetchLeads(reset: true);
                                setState(() {});
                              },
                              icon: const Icon(Icons.close, size: 18),
                            ),

                        ],
                      ),
                      filled: true,
                      fillColor: const Color(0xffF5F7FA),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                      fetchLeads(reset: true);
                    },
                  ),
                ),

                SizedBox(width: 10,),

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
                  ...customers.map((c) {
                    return DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text(
                        c['label'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => selectedCustomerId = value);
                  fetchLeads(reset: true);
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
                  ...assignedUsers.map((u) {
                    return DropdownMenuItem<int>(
                      value: u['id'],
                      child: Text(
                        u['label'].toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => selectedAssignedToId = value);
                  fetchLeads(reset: true);
                },
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _dateFilterBox(
                      label: fromDate == null
                          ? 'From Date'
                          : '${fromDate!.day}/${fromDate!.month}/${fromDate!.year}',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fromDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setState(() => fromDate = picked);
                          fetchLeads(reset: true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateFilterBox(
                      label: toDate == null
                          ? 'To Date'
                          : '${toDate!.day}/${toDate!.month}/${toDate!.year}',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: toDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (picked != null) {
                          setState(() => toDate = picked);
                          fetchLeads(reset: true);
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
                  onPressed: () {
                    searchController.clear();

                    setState(() {
                      searchText = '';
                      selectedCustomerId = null;
                      selectedAssignedToId = null;
                      fromDate = null;
                      toDate = null;
                    });

                    fetchLeads(reset: true);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.primarySlate,
              ),
              const SizedBox(width: 8),
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
            ],
          ),
        ),
      );
    }

    /*Widget filterPanel() {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primarySlate),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () {
                    searchController.clear();
                    searchText = '';
                    fetchLeads();
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
                filled: true,
                fillColor: const Color(0xffF5F7FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (value) {
                searchText = value.trim();
                fetchLeads();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: customerDropdown()),
                const SizedBox(width: 8),
                Expanded(child: assignedDropdown()),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: datePickerBox('yyyy-mm-dd', fromDate, true)),
                const SizedBox(width: 8),
                Expanded(child: datePickerBox('yyyy-mm-dd', toDate, false)),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: clearFilters,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      );
    }*/

    Widget customerDropdown() {
      return DropdownButtonFormField<int?>(
        value: selectedCustomerId,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: Color(0xff1E293B)),
        decoration: filterInputDecoration('All Customers'),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All Customers'),
          ),
          ...customers.map((c) {
            return DropdownMenuItem<int?>(
              value: c['id'] as int?,
              child: Text(
                c['label'].toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() => selectedCustomerId = value);
          fetchLeads(reset: true);
        },
      );
    }

    Widget assignedDropdown() {
      return DropdownButtonFormField<int?>(
        value: selectedAssignedToId,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: Color(0xff1E293B)),
        decoration: filterInputDecoration('All Assigned To'),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All Assigned To'),
          ),
          ...assignedUsers.map((u) {
            return DropdownMenuItem<int?>(
              value: u['id'] as int?,
              child: Text(
                u['label'].toString(),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() => selectedAssignedToId = value);
          fetchLeads(reset: true);
        },
      );
    }

    InputDecoration filterInputDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: const Color(0xffF5F7FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
    }

    Widget datePickerBox(String hint, DateTime? value, bool isFrom) {
      return InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked != null) {
            setState(() {
              if (isFrom) {
                fromDate = picked;
              } else {
                toDate = picked;
              }
            });
            fetchLeads(reset: true);
          }
        },
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xffF5F7FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null
                      ? hint
                      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null ? Colors.grey.shade500 : AppColors.primaryDeep,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primarySlate),
            ],
          ),
        ),
      );
    }

    void clearFilters() {
      setState(() {
        searchController.clear();
        searchText = '';
        selectedCustomerId = null;
        selectedAssignedToId = null;
        fromDate = null;
        toDate = null;
      });

      fetchLeads(reset: true);
    }

    Widget leadListTab() {
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

            if (leads.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Text(
                    'No leads found',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              ...leads.map(leadCard),

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

    Widget leadPopupMenu(Map<String, dynamic> lead) {
      final status = (lead['status'] ?? '').toString();

      final bool isAssigned = status == 'Assigned';
      final bool isConverted = status == 'Converted';
      final bool isOpportunity = status == 'Opportunity Created';

      return PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert_rounded,
          color: AppColors.primarySlate,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        elevation: 10,
        onSelected: (value) async {

          if (value == 'view') {
            if (isOpportunity) {
              final id = int.tryParse(lead['id']?.toString() ?? '');
              if (id != null && id != 0) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => OpportunityViewPage(leadId: id),
                ));
                return;
              }
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LeadViewPage(leadData: lead, isReadOnly: true),
              ),
            );
          }

          if (value == 'edit_lead') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateLead(
                  leadData: lead,
                ),
              ),
            );

            if (result == true) {
              fetchLeads(reset: true);
            }
          }

          if (value == 'edit_opportunity') {
            final id = int.tryParse(lead['id']?.toString() ?? '');

            if (id == null || id == 0) {
              showSnack('Opportunity ID not found', Colors.red);
              return;
            }

            // → the new 5-tab Opportunity screen (lands on Lead Details, which has inline edit)
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OpportunityViewPage(leadId: id),
              ),
            );

            // refresh on return so any edits/status changes show up
            await fetchLeads(reset: true);
          }

        },
        itemBuilder: (context) => [
          _popupItem(
            value: 'view',
            icon: Icons.visibility_outlined,
            title: isOpportunity ? 'View Opportunity' : 'View Lead',
            color: AppColors.primarySlate,
          ),

          if (isAssigned)
            _popupItem(
              value: 'edit_lead',
              icon: Icons.edit_outlined,
              title: 'Edit Lead',
              color: AppColors.primaryLight,
            ),

          if (isOpportunity)
            _popupItem(
              value: 'edit_opportunity',
              icon: Icons.trending_up_rounded,
              title: 'Edit Opportunity',
              color: const Color(0xff7C3AED),
            ),

          if (isConverted)
            _popupInfoItem(
              icon: Icons.lock_outline_rounded,
              title: 'Converted - View Only',
              color: const Color(0xff059669),
            ),
        ],
      );
    }

    PopupMenuItem<String> _popupItem({
      required String value,
      required IconData icon,
      required String title,
      required Color color,
    }) {
      return PopupMenuItem<String>(
        value: value,
        height: 42,
        child: Row(
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
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    PopupMenuItem<String> _popupInfoItem({
      required IconData icon,
      required String title,
      required Color color,
    }) {
      return PopupMenuItem<String>(
        enabled: false,
        height: 42,
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

   /* Widget leadPopupMenu(Map<String, dynamic> item) {
      final status = safeText(item['status'], '');

      return PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert_rounded,
          color: AppColors.primarySlate,
          size: 22,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onSelected: (value) async {
          if (value == 'view') {
            openQuickViewDialog(item);
          }

          if (value == 'edit') {
            await openEditLead(item);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 18),
                SizedBox(width: 10),
                Text('View'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Edit'),
              ],
            ),
          ),
        ],
      );
    }*/

    Widget leadCard(Map<String, dynamic> item) {
      final title = safeText(item['lead_title'], '');
      final customer = safeText(item['customer_name'], '');
      final status = safeText(item['status'], '');
      final priority = safeText(item['priority'], '');
      final assignedTo = safeText(item['assigned_to_name'], 'Unassigned');
      final contact = safeText(item['contact_person'], '');
      final approval = safeText(item['approval_status'], 'None');

      final createdAt = item['created_at'];
      final followUp = item['follow_up'];
      final timeline = item['timeline'];

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
        'Create',
      );

      final isConverted = status.toLowerCase() == 'converted';
      final priorityClr = priorityColor(priority);
      final statusClr = statusColor(status);

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
            onTap: () => openQuickViewDialog(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                children: [


                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                    child: Column(
                      children: [
                        /// LEAD HEADER
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
                                  _leadLabel('LEAD'),
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
                                leadPopupMenu(item),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        /// STATUS / PRIORITY CHIPS
                        Row(
                          children: [
                            if (status.isNotEmpty)
                              GestureDetector(
                                onTap: isConverted ? null : () => openStatusDialog(item),
                                child: _modernStatusPill(status),
                              ),
                            if (priority.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _modernPriorityPill(priority, priorityClr),
                            ],
                            const Spacer(),
                            if (approval != 'None')
                              _miniApprovalPill(approval),
                          ],
                        ),

                        const SizedBox(height: 14),
                        _leadThinDivider(),
                        const SizedBox(height: 13),

                        /// SOURCE + OWNER
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _premiumLeadInfo(
                                label: 'SOURCE',
                                value: source,
                                subValue: sourceSub,
                                icon: Icons.source_outlined,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _premiumLeadInfo(
                                label: 'OWNER',
                                value: assignedTo,
                                subValue: '',
                                icon: Icons.person_pin_circle_outlined,
                                color: const Color(0xff7C3AED),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 13),
                        _leadThinDivider(),
                        const SizedBox(height: 13),

                        /// TIMELINE + CONTACT
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _premiumTimelineInfo(
                                timeline: timeline,
                                followUp: followUp,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _premiumLeadContact(
                                contact: contact,
                                mobile: mobile,
                                email: email,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 13),
                        _leadThinDivider(),
                        const SizedBox(height: 13),

                        /// LAST ACTIVITY
                        Row(
                          children: [
                            Expanded(
                              child: _premiumLeadInfo(
                                label: 'LAST ACTIVITY',
                                value: lastActivity,
                                subValue: formatDate(createdAt),
                                icon: Icons.history_rounded,
                                color: const Color(0xff2563EB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xffE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: 14,
                                    color: Color(0xff64748B),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Tap to view',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff64748B),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
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

    Widget _premiumLeadInfo({
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
                _leadLabel(label),
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

    Widget _premiumTimelineInfo({
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
                _leadLabel('TIMELINE'),
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

    Widget _premiumLeadContact({
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
                _leadLabel('CONTACT'),
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
                      _leadCircleIcon(
                        icon: Icons.phone_outlined,
                        color: const Color(0xff059669),
                      ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _leadCircleIcon(
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

    Widget _modernStatusPill(String status) {
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

    Widget _modernPriorityPill(String priority, Color color) {
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

    Widget _miniApprovalPill(String approval) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          approval,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xff64748B),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    Widget _leadCircleIcon({
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

    Widget _leadTableCell({
      required String label,
      required String value,
      required String subValue,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadLabel(label),
          const SizedBox(height: 6),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.2,
              color: Color(0xff0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subValue.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xff94A3B8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
    }

    Widget _leadLabel(String text) {
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

    Widget _leadStatusCell({
      required String status,
      required VoidCallback? onTap,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadLabel('STATUS'),
          const SizedBox(height: 7),
          GestureDetector(
            onTap: onTap,
            child: status.trim().isEmpty
                ? const Text(
              '-',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xff0F172A),
              ),
            )
                : _statusBadge(status),
          ),
        ],
      );
    }

    Widget _leadPriorityValueCell({
      required String priority,
      required String value,
    }) {
      final color = priorityColor(priority);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadLabel('PRIORITY & VALUE'),
          const SizedBox(height: 6),
          if (priority.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                priority,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '₹$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xff0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    Widget _leadTimelineCell({
      required dynamic timeline,
      required dynamic followUp,
    }) {
      final timelineText = formatDate(timeline);
      final followText = formatDate(followUp);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadLabel('TIMELINE'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  timelineText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xffF59E0B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xffF59E0B),
              ),
            ],
          ),
          if (followText != '-') ...[
            const SizedBox(height: 4),
            Text(
              'Timeline: $followText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xff94A3B8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
    }

    Widget _leadContactCell({
      required String contact,
      required String mobile,
      required String email,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadLabel('CONTACT'),
          const SizedBox(height: 6),
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
          const SizedBox(height: 6),
          Row(
            children: [
              if (mobile.isNotEmpty)
                _leadContactIcon(
                  icon: Icons.phone_outlined,
                  color: const Color(0xff059669),
                ),
              if (email.isNotEmpty) ...[
                const SizedBox(width: 6),
                _leadContactIcon(
                  icon: Icons.mail_outline_rounded,
                  color: const Color(0xff2563EB),
                ),
              ],
            ],
          ),
        ],
      );
    }

    Widget _leadContactIcon({
      required IconData icon,
      required Color color,
    }) {
      return Container(
        height: 24,
        width: 24,
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: color,
        ),
      );
    }

    Widget _leadThinDivider() {
      return Container(
        height: 1,
        color: const Color(0xffE8ECF0),
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

    void openStatusDialog(Map<String, dynamic> item) {
      final currentStatus = safeText(item['status'], '');
      String selectedStatus = statusOptions.contains(currentStatus) ? currentStatus : 'Assigned';

      if (currentStatus == 'Converted') {
        showSnack('Converted leads cannot be moved', Colors.orange);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Update Lead Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setDialogState(() => selectedStatus = value);
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  updateLeadStatus(item['id'], selectedStatus);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Update', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    void openQuickViewDialog(Map<String, dynamic> item) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints(maxHeight: 620),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      _avatar(safeText(item['lead_title'], ''), size: 46, fontSize: 15),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          safeText(item['lead_title'], ''),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                  detailRow('Customer', safeText(item['customer_name'], '')),
                  detailRow('Contact', safeText(item['contact_person'], '')),
                  detailRow('Mobile', safeText(item['mobile'], '')),
                  detailRow('Email', safeText(item['email'], '')),
                  detailRow('Priority', safeText(item['priority'], '')),
                  detailRow('Status', safeText(item['status'], '')),
                  detailRow('Approval', safeText(item['approval_status'], 'None')),
                  detailRow('Assigned To', safeText(item['assigned_to_name'], '')),
                  detailRow('Value', formatCurrency(item['est_value'])),
                  detailRow('Timeline', formatDate(item['timeline'])),
                  detailRow('Follow Up', formatDate(item['follow_up'])),
                  detailRow('Notes', safeText(item['notes'], '')),
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
              width: 110,
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDeep,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }



    Future<void> openEditLead(Map<String, dynamic> item) async {

      final updated = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateLead(leadData: Map<String, dynamic>.from(item)),
        ),
      );

      if (updated == true) await refreshAll();
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xffF3F6FA),
        body: Column(
          children: [
            header(),
            Expanded(child: leadListTab()),
          ],
        ),
      );
    }
  }