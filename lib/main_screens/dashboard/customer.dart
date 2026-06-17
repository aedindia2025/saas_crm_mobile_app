import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomersTab extends StatefulWidget {
  final String token;
  const CustomersTab({super.key, required this.token});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  static const String baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1';

  bool loading = true;
  String? errorText;
  String? tenantSlug;

  Map<String, dynamic> stats = {};
  Map<String, dynamic> filterOpts = {};
  List<Map<String, dynamic>> tableRows = [];
  List<Map<String, dynamic>> masterGroups = [];

  String? dateFrom;
  String? dateTo;
  String? assignedTo;
  String? group;
  String? activeState;
  String? activeSector;
  String compareBy = 'state';

  final Map<String, String> stateAbbr = const {
    'Andhra Pradesh': 'AP',
    'Arunachal Pradesh': 'AR',
    'Assam': 'AS',
    'Bihar': 'BR',
    'Chandigarh': 'CH',
    'Chhattisgarh': 'CG',
    'Delhi': 'DL',
    'Goa': 'GA',
    'Gujarat': 'GJ',
    'Haryana': 'HR',
    'Himachal Pradesh': 'HP',
    'J&K': 'JK',
    'Jammu & Kashmir': 'JK',
    'Jharkhand': 'JH',
    'Karnataka': 'KA',
    'Kerala': 'KL',
    'Ladakh': 'LA',
    'Madhya Pradesh': 'MP',
    'Maharashtra': 'MH',
    'Manipur': 'MN',
    'Meghalaya': 'ML',
    'Mizoram': 'MZ',
    'Nagaland': 'NL',
    'Odisha': 'OD',
    'Puducherry': 'PY',
    'Punjab': 'PB',
    'Rajasthan': 'RJ',
    'Sikkim': 'SK',
    'Tamil Nadu': 'TN',
    'Telangana': 'TS',
    'Tripura': 'TR',
    'Uttar Pradesh': 'UP',
    'Uttarakhand': 'UK',
    'West Bengal': 'WB',
  };

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        tenantSlug = prefs.getString('tenant_slug') ?? '';
      });
      await loadData();
    }
  }

  num n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(',', '')) ?? 0;
  }

  String s(dynamic v) => (v ?? '').toString().trim();
  String dash(dynamic v) => s(v).isEmpty ? '—' : s(v);

  String fmtN(dynamic v) => NumberFormat.decimalPattern('en_IN').format(n(v));

  int pct(num a, num b) => b == 0 ? 0 : ((a / b) * 100).round().clamp(0, 999);

  String fmtRs(dynamic v) {
    final value = n(v);
    if (value == 0) return '₹ 0';
    if (value >= 10000000) return '₹ ${(value / 10000000).toStringAsFixed(2)} Cr';
    if (value >= 100000) return '₹ ${(value / 100000).toStringAsFixed(2)} L';
    return '₹ ${fmtN(value.round())}';
  }

  String cName(Map r) => dash(r['customer_name'] ?? r['name'] ?? r['company_name']);
  String cState(Map r) => s(r['billing_state'] ?? r['state']);
  String cSector(Map r) => s(r['customer_vertical'] ?? r['industry'] ?? r['sector'] ?? r['vertical']);
  String cStatus(Map r) => s(r['account_status'] ?? r['status']);
  String cUser(Map r) => s(r['assigned_user_name'] ?? r['assigned_to']);
  num cPotential(Map r) => n(r['potential_value'] ?? r['potential']);
  String cGroup(Map r) => s(r['group_name'] ?? r['assigned_group'] ?? r['team'] ?? r['group']);
  String cCity(Map r) => s(r['billing_city'] ?? r['city']);

  String groupKeyForRow(Map<String, dynamic> r) {
    final direct = cGroup(r);
    if (direct.isNotEmpty) return direct;

    final assigned = int.tryParse(s(r['assigned_to']));
    if (assigned != null) {
      for (final g in masterGroups) {
        final members = g['members'];
        if (members is List && members.any((m) => n((m as Map)['id']).toInt() == assigned)) {
          return dash(g['name']);
        }
      }
    }
    return 'Unassigned';
  }

  Map<String, String> get queryParams {
    final p = <String, String>{};
    if (s(dateFrom).isNotEmpty) p['date_from'] = dateFrom!;
    if (s(dateTo).isNotEmpty) p['date_to'] = dateTo!;
    if (s(assignedTo).isNotEmpty) p['assigned_to'] = assignedTo!;
    if (s(group).isNotEmpty) p['group'] = group!;
    if (s(activeState).isNotEmpty) p['state'] = activeState!;
    if (s(activeSector).isNotEmpty) p['sector'] = activeSector!;
    return p;
  }

  Future<dynamic> getJson(String path, [Map<String, String>? params]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final res = await http.get(uri, headers: {
      'X-Tenant-Slug': tenantSlug ?? '',
      'Authorization': 'Bearer ${widget.token}',
      'Accept': 'application/json',
    });

    print("res=customer== ${res}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$path failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body);
  }

  List<Map<String, dynamic>> asRows(dynamic data) {
    final list = data is Map && data['items'] is List ? data['items'] : data is List ? data : const [];
    return list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> loadData() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final p = queryParams;
      final result = await Future.wait([
        getJson('/customers/stats', p).catchError((_) => <String, dynamic>{}),
        getJson('/customers/', {...p, 'page': '1', 'page_size': '300'}).catchError((_) => []),
        getJson('/customers/filter-options').catchError((_) => <String, dynamic>{}),
        getJson('/groups/').catchError((_) => []),
      ]);

      if (!mounted) return;
      setState(() {
        stats = Map<String, dynamic>.from(result[0] is Map ? result[0] as Map : {});
        tableRows = asRows(result[1]);
        filterOpts = Map<String, dynamic>.from(result[2] is Map ? result[2] as Map : {});
        masterGroups = asRows(result[3]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get filteredRows {
    return tableRows.where((r) {
      if (activeState != null && cState(r) != activeState) return false;
      if (activeSector != null && cSector(r) != activeSector) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> grouped(String keyType, {List<Map<String, dynamic>>? source}) {
    final rows = source ?? filteredRows;
    final m = <String, Map<String, dynamic>>{};

    for (final r in rows) {
      var key = 'Unknown';
      if (keyType == 'state') key = cState(r).isEmpty ? 'Unknown' : cState(r);
      if (keyType == 'sector') key = cSector(r).isEmpty ? 'General' : cSector(r);
      if (keyType == 'status') key = cStatus(r).isEmpty ? 'Unknown' : cStatus(r);
      if (keyType == 'user') key = cUser(r).isEmpty ? 'Unassigned' : cUser(r);
      if (keyType == 'group') key = groupKeyForRow(r);

      m.putIfAbsent(key, () => {
        'key': key,
        'count': 0,
        'active': 0,
        'potential': 0.0,
        'lead': 0.0,
        'tender': 0.0,
        'won': 0.0,
      });

      m[key]!['count'] += 1;
      if (cStatus(r).toLowerCase() == 'active') m[key]!['active'] += 1;
      m[key]!['potential'] += n(r['potential_value'] ?? r['potential']);
      m[key]!['lead'] += n(r['lead_value'] ?? r['total_lead_value']);
      m[key]!['tender'] += n(r['tender_value'] ?? r['total_tender_value']);
      m[key]!['won'] += n(r['won_value'] ?? r['won_tender_value']);
    }

    final list = m.values.toList();
    list.sort((a, b) => n(b['count']).compareTo(n(a['count'])));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final totalCustomers = n(stats['total_customers'] ?? stats['total'] ?? tableRows.length);
    final activeCustomers = n(stats['active_customers'] ??
        stats['active'] ??
        tableRows.where((r) => cStatus(r).toLowerCase() == 'active').length);
    final newCustomers = n(stats['new_customers'] ?? stats['new_this_month']);
    final totalPotential = n(stats['total_potential'] ??
        stats['potential_value_total'] ??
        stats['customer_potential_value'] ??
        tableRows.fold<num>(0, (sum, r) => sum + cPotential(r)));

    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xfff5f7fb),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(totalCustomers, activeCustomers, totalPotential),
              const SizedBox(height: 12),
              if (errorText != null) ...[
                _errorCard(errorText!),
                const SizedBox(height: 12),
              ],
              _filterBar(),
              if (activeState != null || activeSector != null) ...[
                const SizedBox(height: 10),
                _activeFilterBanner(),
              ],
              const SizedBox(height: 16),
              _section('01', 'Customer KPI Summary'),
              const SizedBox(height: 10),
              _kpiCards(totalCustomers, activeCustomers, newCustomers, totalPotential),
              const SizedBox(height: 18),
              _statusAndSector(),
              const SizedBox(height: 18),
              _sectorAnalysis(),
              const SizedBox(height: 18),
              _comparisonTable(),
              const SizedBox(height: 18),
              _topCustomers(),
              const SizedBox(height: 18),
              _allCustomersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(num total, num active, num potential) {
    return _card(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xffeef2ff),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.groups, color: Color(0xff4f46e5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Customer Analytics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('${fmtN(total)} customers · ${fmtRs(potential)} potential',
                          style: const TextStyle(fontSize: 12, color: Color(0xff64748b))),
                    ],
                  ),
                ),
                IconButton(onPressed: loadData, icon: const Icon(Icons.refresh, color: Color(0xff4f46e5))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _mobileHeadMetric('Total', fmtN(total), const Color(0xff0f172a))),
                const SizedBox(width: 8),
                Expanded(child: _mobileHeadMetric('Active', fmtN(active), const Color(0xff059669))),
                const SizedBox(width: 8),
                Expanded(child: _mobileHeadMetric('Potential', fmtRs(potential), const Color(0xff2563eb))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileHeadMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xff94a3b8))),
        const SizedBox(height: 5),
        Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  Widget _filterBar() {
    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.filter_alt_outlined, size: 14, color: Color(0xff334155)),
              SizedBox(width: 8),
              Text(
                'FILTERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff334155),
                  letterSpacing: 1.4,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _dateField('FROM DATE', dateFrom, (v) => setState(() => dateFrom = v))),
              const SizedBox(width: 10),
              Expanded(child: _dateField('TO DATE', dateTo, (v) => setState(() => dateTo = v))),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0f172a),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, String? value, Function(String?) onChanged) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();

        final initialDate = DateTime.tryParse(value ?? '') ?? now;

        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 10),
          helpText: label,
          confirmText: 'Apply',
          cancelText: 'Cancel',
        );

        if (picked != null) {
          onChanged(DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: _input(label).copyWith(
          hintText: 'yyyy-mm-dd',
          suffixIcon: const Icon(Icons.calendar_today, size: 17),
        ),
        child: Text(
          value?.isNotEmpty == true ? value! : 'yyyy-mm-dd',
          style: TextStyle(
            fontSize: 13,
            color: value?.isNotEmpty == true
                ? const Color(0xff0f172a)
                : const Color(0xff64748b),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _activeFilterBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffeef2ff),
        border: Border.all(color: const Color(0xffc7d2fe)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.filter_alt, size: 15, color: Color(0xff4338ca)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Filtered: ${filteredRows.length} customers',
                style: const TextStyle(color: Color(0xff4338ca), fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => setState(() {
              activeState = null;
              activeSector = null;
            }),
            child: const Text('Clear'),
          ),
        ]),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (activeState != null) _chip(activeState!, const Color(0xff4f46e5)),
          if (activeSector != null) _chip(activeSector!, const Color(0xff7c3aed)),
        ]),
      ]),
    );
  }

  Widget _kpiCards(num total, num active, num newly, num potential) {
    final avgPotential = total == 0 ? 0 : potential / total;
    final cards = [
      ['Total Customers', fmtN(total), 'All accounts', Icons.groups, const Color(0xff4f46e5)],
      ['Active Customers', fmtN(active), '${pct(active, total)}% active', Icons.verified, const Color(0xff059669)],
      ['New Customers', fmtN(newly), 'This month', Icons.trending_up, const Color(0xff0284c7)],
      ['Potential Value', fmtRs(potential), 'Avg ${fmtRs(avgPotential)}', Icons.currency_rupee, const Color(0xff7c3aed)],
    ];

    return Column(
      children: cards.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _kpi(c[0] as String, c[1] as String, c[2] as String, c[3] as IconData, c[4] as Color),
        );
      }).toList(),
    );
  }

  Widget _kpi(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
          ]),
        ),
      ]),
    );
  }

  Widget _statusAndSector() {
    final stateDist = grouped('state').take(15).toList();
    final sectorDist = grouped('sector').take(10).toList();
    final maxState = stateDist.isEmpty ? 1 : n(stateDist.first['count']);
    final maxSector = sectorDist.isEmpty ? 1 : n(sectorDist.first['count']);
    final colors = const [
      Color(0xff6366f1),
      Color(0xff8b5cf6),
      Color(0xff06b6d4),
      Color(0xff10b981),
      Color(0xfff59e0b),
      Color(0xffef4444),
      Color(0xffec4899),
      Color(0xff14b8a6),
      Color(0xff3b82f6),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('02', 'Status & Sector Distribution'),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead('Customers by State', 'Top 15 states — tap row to filter'),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: stateDist.map((d) {
              final name = d['key'];
              final count = n(d['count']);
              final selected = activeState == name;
              return InkWell(
                onTap: () => setState(() => activeState = selected ? null : name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    SizedBox(width: 92, child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                    Expanded(
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: maxState == 0 ? 0 : count / maxState,
                        backgroundColor: const Color(0xfff1f5f9),
                        valueColor: AlwaysStoppedAnimation(selected ? const Color(0xff4338ca) : const Color(0xff818cf8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(fmtN(count), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ])),
      const SizedBox(height: 12),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead('Top Sectors', 'Customer count by industry / vertical'),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: List.generate(sectorDist.length, (i) {
              final d = sectorDist[i];
              final color = colors[i % colors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d['key'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  SizedBox(
                    width: 70,
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: maxSector == 0 ? 0 : n(d['count']) / maxSector,
                      backgroundColor: const Color(0xfff1f5f9),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(fmtN(d['count']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              );
            }),
          ),
        ),
      ])),
    ]);
  }

  Widget _sectorAnalysis() {
    final sectorChips = grouped('sector', source: tableRows).take(14).toList();
    final sectorRows = grouped('sector');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('04', 'Sector Analysis', 'Tap a sector to filter'),
      const SizedBox(height: 10),

      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead('Filter by Sector', 'Choose a sector to narrow list'),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sectorChips.map((c) {
              final sector = c['key'];
              final selected = activeSector == sector;

              return ChoiceChip(
                label: Text('$sector (${fmtN(c['count'])})'),
                selected: selected,
                onSelected: (_) {
                  setState(() => activeSector = selected ? null : sector);
                },
                showCheckmark: false,
                selectedColor: const Color(0xff2563eb),
                backgroundColor: const Color(0xfff1f5f9),
                side: BorderSide(
                  color: selected ? const Color(0xff2563eb) : const Color(0xffe2e8f0),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xff475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              );
            }).toList(),
          ),
        ),
      ])),

      const SizedBox(height: 14),

      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead('Customer Distribution by Sector', 'List view only'),
        if (sectorRows.isEmpty)
          _empty('No sector data')
        else
          Column(children: sectorRows.map((r) => _sectorRowCard(r)).toList()),
      ])),
    ]);
  }

  Widget _selectCard({
    required String title,
    required String count,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.10) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : const Color(0xffe2e8f0), width: selected ? 1.4 : 1),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? color : color.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.business_center_outlined, color: selected ? Colors.white : color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xff0f172a))),
              const SizedBox(height: 4),
              Text(count, style: const TextStyle(fontSize: 11, color: Color(0xff64748b), fontWeight: FontWeight.w700)),
            ])),
            Icon(selected ? Icons.check_circle : Icons.chevron_right, color: selected ? color : const Color(0xff94a3b8), size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _sectorRowCard(Map<String, dynamic> r) {
    final total = filteredRows.length;
    final selected = activeSector == r['key'];

    return InkWell(
      onTap: () => setState(() => activeSector = selected ? null : r['key']),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffeff6ff) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xfff1f5f9))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? const Color(0xff2563eb) : const Color(0xfff1f5f9),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.business_center_outlined,
                color: selected ? Colors.white : const Color(0xff64748b),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['key']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff0f172a),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${fmtN(r['count'])} customers · ${pct(n(r['count']), total)}% share · Active ${pct(n(r['active']), n(r['count']))}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _inlineValue('Potential', fmtRs(r['potential']), const Color(0xff7c3aed)),
                      _inlineValue('Leads', fmtRs(r['lead']), const Color(0xff2563eb)),
                      _inlineValue('Tenders', fmtRs(r['tender']), const Color(0xffd97706)),
                      _inlineValue('Won', fmtRs(r['won']), const Color(0xff059669)),
                    ],
                  ),
                ],
              ),
            ),

            Icon(
              selected ? Icons.check_circle : Icons.chevron_right,
              color: selected ? const Color(0xff2563eb) : const Color(0xff94a3b8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonTable() {
    final rows = grouped(compareBy).take(25).toList();
    final options = const {
      'state': 'State-wise',
      'sector': 'Sector-wise',
      'group': 'Group-wise',
      'status': 'Status-wise',
      'user': 'User-wise',
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('05', 'Comparison', 'Compare by State · Sector · Group · Status · User'),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Customer Comparison', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('Grouped by ${options[compareBy]} · ${rows.length} segments', style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options.entries.map((e) {
                final selected = compareBy == e.key;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) => setState(() => compareBy = e.key),
                  selectedColor: const Color(0xff4f46e5),
                  labelStyle: TextStyle(color: selected ? Colors.white : const Color(0xff475569), fontSize: 11, fontWeight: FontWeight.w700),
                );
              }).toList(),
            ),
          ]),
        ),
        if (rows.isEmpty)
          _empty('No comparison data')
        else
          Column(children: rows.map((r) => _comparisonRowCard(r)).toList()),
      ])),
    ]);
  }

  Widget _comparisonRowCard(Map<String, dynamic> r) {
    final total = filteredRows.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xfff1f5f9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xffeef2ff),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.compare_arrows,
              color: Color(0xff4f46e5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['key']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff0f172a),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${fmtN(r['count'])} customers · ${pct(n(r['count']), total)}% share · ${fmtN(r['active'])} active',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: total == 0 ? 0 : n(r['count']) / total,
                    backgroundColor: const Color(0xfff1f5f9),
                    valueColor: const AlwaysStoppedAnimation(Color(0xff4f46e5)),
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _inlineValue('Potential', fmtRs(r['potential']), const Color(0xff7c3aed)),
                    _inlineValue('Leads', fmtRs(r['lead']), const Color(0xff2563eb)),
                    _inlineValue('Tenders', fmtRs(r['tender']), const Color(0xffd97706)),
                    _inlineValue('Won', fmtRs(r['won']), const Color(0xff059669)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineValue(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xff64748b),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topCustomers() {
    final rows = [...filteredRows].where((r) => cPotential(r) > 0).toList();
    rows.sort((a, b) => cPotential(b).compareTo(cPotential(a)));
    final top = rows.take(10).toList();
    final maxPotential = top.isEmpty ? 1 : cPotential(top.first);
    final allEqual = top.length > 1 && top.every((r) => cPotential(r) == maxPotential);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('06', 'Top Accounts — Highest Potential Value'),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead('Top 10 Customers by Potential', allEqual ? 'All accounts have same potential value (${fmtRs(maxPotential)})' : 'Ranked by estimated revenue opportunity'),
        if (top.isEmpty)
          _empty('No potential value set — edit customer records to add a potential value')
        else
          Column(children: List.generate(top.length, (i) {
            final r = top[i];
            final value = cPotential(r);
            final status = cStatus(r);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xfff1f5f9)))),
              child: Row(children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: i < 3 ? const Color(0xff4f46e5) : const Color(0xfff1f5f9),
                  child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i < 3 ? Colors.white : const Color(0xff64748b))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(cName(r), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    if (status.isNotEmpty) ...[const SizedBox(width: 6), _smallBadge(status)],
                  ]),
                  const SizedBox(height: 4),
                  Text('${dash(cSector(r))} · ${dash(cState(r))}${cUser(r).isNotEmpty ? ' · KAM: ${cUser(r)}' : ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8))),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtRs(value), style: const TextStyle(fontSize: 12, color: Color(0xff7c3aed), fontWeight: FontWeight.w900)),
                  if (s(r['account_potential']).isNotEmpty) Text('${r['account_potential']}', style: const TextStyle(fontSize: 10, color: Color(0xff64748b))),
                ]),
              ]),
            );
          })),
      ])),
    ]);
  }

  Widget _allCustomersList() {
    final title = 'All Customers${activeState != null ? ' — $activeState' : ''}${activeSector != null ? ' / $activeSector' : ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('07', title, 'Mobile row-wise cards with every web table field'),
      const SizedBox(height: 10),
      _card(
        filteredRows.isEmpty
            ? _empty('No customers found')
            : Column(children: filteredRows.map((r) => _customerRowCard(r)).toList()),
      ),
    ]);
  }

  Widget _customerRowCard(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xfff1f5f9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xffeef2ff),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.groups,
              color: Color(0xff4f46e5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      cName(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff0f172a),
                      ),
                    ),
                  ),
                  if (cStatus(r).isNotEmpty) _smallBadge(cStatus(r)),
                ]),

                const SizedBox(height: 5),

                Text(
                  '${dash(cSector(r))} · ${dash(cState(r))} · ${dash(cCity(r))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _inlineValue('Potential', fmtRs(cPotential(r)), const Color(0xff7c3aed)),
                    _inlineValue('Category', dash(r['account_potential']), const Color(0xffd97706)),
                    _inlineValue('KAM', dash(cUser(r)), const Color(0xff2563eb)),
                    _inlineValue('Group', dash(cGroup(r)), const Color(0xff059669)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(List<List<String>> items) {
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          return SizedBox(
            width: itemWidth,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item[0].toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xff94a3b8))),
                const SizedBox(height: 4),
                Text(item[1], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xff0f172a))),
              ]),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _section(String idx, String title, [String? desc]) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xffeef2ff), borderRadius: BorderRadius.circular(8)),
        child: Text(idx, style: const TextStyle(color: Color(0xff4f46e5), fontSize: 11, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xff0f172a))),
          if (desc != null) ...[
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xff64748b))),
          ],
        ]),
      ),
    ]);
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xffe2e8f0))),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6eaf1)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0d0f172a), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _cardHead(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffe2e8f0))), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xff0f172a))),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
      ]),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }

  Widget _smallBadge(String text) {
    if (text.isEmpty) return const SizedBox();
    Color bg = const Color(0xfff1f5f9);
    Color fg = const Color(0xff64748b);
    final status = text.toLowerCase();
    if (status == 'active') {
      bg = const Color(0xffdcfce7);
      fg = const Color(0xff047857);
    } else if (status == 'prospect') {
      bg = const Color(0xffdbeafe);
      fg = const Color(0xff1d4ed8);
    } else if (status == 'inactive') {
      bg = const Color(0xfff1f5f9);
      fg = const Color(0xff475569);
    } else if (status == 'churned') {
      bg = const Color(0xffffe4e6);
      fg = const Color(0xffdc2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _empty(String text) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xff94a3b8), fontSize: 12, fontWeight: FontWeight.w600))),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffff1f2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffffcdd2)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xffbe123c), fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
