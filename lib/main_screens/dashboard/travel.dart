import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TravelTab extends StatefulWidget {
  final String token;

  const TravelTab({
    super.key,
    required this.token,
  });

  @override
  State<TravelTab> createState() => _TravelTabState();
}

class _TravelTabState extends State<TravelTab> {
  static const baseUrl = "http://103.110.236.187:3076/api/v1";

  bool loading = true;
  Map<String, dynamic>? data;

  String? dateFrom;
  String? dateTo;
  String? status;
  String? employeeId;
  String? mode;

  bool get isMobile => MediaQuery.of(context).size.width < 700;
  bool get isTablet => MediaQuery.of(context).size.width < 1100;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  num n(dynamic v) => v == null ? 0 : num.tryParse(v.toString()) ?? 0;

  String fmtN(dynamic v) {
    return NumberFormat.decimalPattern('en_IN').format(n(v));
  }

  String fmtRs(dynamic v) {
    final value = n(v);

    if (value == 0) return "₹ 0";
    if (value >= 10000000) {
      return "₹ ${(value / 10000000).toStringAsFixed(2)} Cr";
    }
    if (value >= 100000) {
      return "₹ ${(value / 100000).toStringAsFixed(2)} L";
    }

    return "₹ ${fmtN(value.round())}";
  }

  int pct(num a, num b) => b == 0 ? 0 : ((a / b) * 100).round();

  Map<String, String> get queryParams {
    final p = <String, String>{};

    if (dateFrom?.isNotEmpty == true) p["date_from"] = dateFrom!;
    if (dateTo?.isNotEmpty == true) p["date_to"] = dateTo!;
    if (status?.isNotEmpty == true) p["status"] = status!;
    if (employeeId?.isNotEmpty == true) p["employee_id"] = employeeId!;
    if (mode?.isNotEmpty == true) p["mode"] = mode!;

    return p;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    final uri = Uri.parse("$baseUrl/dashboard/tab/travel")
        .replace(queryParameters: queryParams);

    final res = await http.get(
      uri,
      headers: {
        'X-Tenant-Slug': 'ascent',
        "Authorization": "Bearer ${widget.token}",
        "Accept": "application/json",
      },
    );

    data = res.statusCode == 200 ? jsonDecode(res.body) : null;

    setState(() => loading = false);
  }

  Map<String, dynamic> get summary {
    return Map<String, dynamic>.from(data?["summary"] ?? {});
  }

  Map<String, dynamic> get charts {
    return Map<String, dynamic>.from(data?["charts"] ?? {});
  }

  Map<String, dynamic> get filters {
    return Map<String, dynamic>.from(data?["filters"] ?? {});
  }

  List<Map<String, dynamic>> get rows {
    final list = data?["table"];

    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  List<Map<String, dynamic>> get pendingRows {
    return rows.where((r) {
      final st = "${r["status"] ?? ""}";
      return st == "Pending" || st == "Submitted";
    }).take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Scaffold(
        backgroundColor: Color(0xfff5f7fb),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final total = n(summary["total"]);
    final approved = n(summary["approved"]);
    final pending = n(summary["pending"]);
    final rejected = n(summary["rejected"]);
    final completed = n(summary["completed"]);
    final advanceTotal = n(summary["advance_total"]);

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fb),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            children: [
              _header(total, approved, pending, advanceTotal),
              const SizedBox(height: 16),
              _filterBar(),
              const SizedBox(height: 20),

              _section("01", "Request flow"),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isMobile ? 1.35 : 1.55,
                children: [
                  _kpi(
                    "Total Requests",
                    fmtN(total),
                    "This month",
                    Icons.navigation,
                    const Color(0xff7e22ce),
                  ),
                  _kpi(
                    "Approved",
                    fmtN(approved),
                    "${pct(approved, total)}% approval rate",
                    Icons.check_circle,
                    const Color(0xff059669),
                  ),
                  _kpi(
                    "Pending",
                    fmtN(pending),
                    "Awaiting decision",
                    Icons.pending_actions,
                    const Color(0xffd97706),
                  ),
                  _kpi(
                    "Rejected",
                    fmtN(rejected),
                    "This period",
                    Icons.cancel,
                    const Color(0xffdc2626),
                  ),
                  _kpi(
                    "Completed",
                    fmtN(completed),
                    "Trips done",
                    Icons.done_all,
                    const Color(0xff0284c7),
                  ),
                  _kpi(
                    "Advance Total",
                    fmtRs(advanceTotal),
                    "Disbursed",
                    Icons.currency_rupee,
                    const Color(0xff7e22ce),
                  ),
                ],
              ),

              if (pending > 0) ...[
                const SizedBox(height: 20),
                _section(
                  "02",
                  "Pending approvals",
                  "${fmtN(pending)} awaiting action",
                ),
                const SizedBox(height: 10),
                _pendingPanel(),
              ],

              const SizedBox(height: 20),
              _section(
                pending > 0 ? "03" : "02",
                "Distribution & trends",
              ),
              const SizedBox(height: 10),
              isMobile
                  ? Column(
                children: [
                  _statusDistribution(),
                  const SizedBox(height: 14),
                  _modeDistribution(),
                  const SizedBox(height: 14),
                  _monthlyTrend(),
                ],
              )
                  : Row(
                children: [
                  Expanded(child: _statusDistribution()),
                  const SizedBox(width: 14),
                  Expanded(child: _modeDistribution()),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: _monthlyTrend()),
                ],
              ),

              const SizedBox(height: 20),
              _section(
                "05",
                "Employee comparison",
                "Travel by team member",
              ),
              const SizedBox(height: 10),
              _employeeComparisonTable(),

              const SizedBox(height: 20),
              _section("06", "All requests"),
              const SizedBox(height: 10),
              _allRequestsTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
      num total,
      num approved,
      num pending,
      num advance,
      ) {
    if (isMobile) {
      return _card(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xfff3e8ff),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.navigation,
                      color: Color(0xff7e22ce),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Travel & TA/DA",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Travel requests · approvals · advance tracking",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff64748b),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mobileHeadStat("Total", fmtN(total), const Color(0xff0f172a)),
                  _mobileHeadStat("Approved", fmtN(approved), const Color(0xff059669)),
                  _mobileHeadStat("Pending", fmtN(pending), const Color(0xffd97706)),
                  _mobileHeadStat("Advance", fmtRs(advance), const Color(0xff0284c7)),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : loadData,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(loading ? "Refreshing..." : "Refresh"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff7e22ce),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xfff3e8ff),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.navigation,
                color: Color(0xff7e22ce),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Travel & TA/DA",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Travel requests · approvals · advance tracking",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff64748b),
                    ),
                  ),
                ],
              ),
            ),
            _headStat("Total", fmtN(total), const Color(0xff0f172a)),
            _headStat("Approved", fmtN(approved), const Color(0xff059669)),
            _headStat("Pending", fmtN(pending), const Color(0xffd97706)),
            _headStat("Advance", fmtRs(advance), const Color(0xff0284c7)),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: loading ? null : loadData,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(loading ? "Refreshing..." : "Refresh"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff7e22ce),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileHeadStat(String label, String value, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xff94a3b8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headStat(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xff94a3b8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final statuses =
    filters["statuses"] is List ? filters["statuses"] as List : [];
    final modes = filters["modes"] is List ? filters["modes"] as List : [];
    final employees =
    filters["employees"] is List ? filters["employees"] as List : [];

    if (isMobile) {
      return _card(
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      "From",
                      dateFrom,
                          (v) => dateFrom = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateField(
                      "To",
                      dateTo,
                          (v) => dateTo = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _dropdown(
                "Status",
                status,
                statuses,
                    (v) => setState(() => status = v),
              ),
              const SizedBox(height: 10),
              _dropdown(
                "Mode",
                mode,
                modes,
                    (v) => setState(() => mode = v),
              ),
              const SizedBox(height: 10),
              _employeeDropdown(employees),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loadData,
                      child: const Text("Apply"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text("Reset"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _dateField("From", dateFrom, (v) => dateFrom = v),
            const SizedBox(width: 10),
            _dateField("To", dateTo, (v) => dateTo = v),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdown(
                "Status",
                status,
                statuses,
                    (v) => setState(() => status = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dropdown(
                "Mode",
                mode,
                modes,
                    (v) => setState(() => mode = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _employeeDropdown(employees),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: loadData,
              child: const Text("Apply"),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _resetFilters,
              child: const Text("Reset"),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      dateFrom = null;
      dateTo = null;
      status = null;
      mode = null;
      employeeId = null;
    });

    loadData();
  }

  Widget _employeeDropdown(List employees) {
    return DropdownButtonFormField<String>(
      value: employeeId,
      decoration: _input("Employee"),
      isExpanded: true,
      items: employees.map((e) {
        if (e is Map) {
          final id = "${e["id"]}";
          final name = "${e["name"] ?? e["employee_name"] ?? id}";

          return DropdownMenuItem(
            value: id,
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        return DropdownMenuItem(
          value: "$e",
          child: Text(
            "$e",
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => employeeId = v),
    );
  }

  Widget _dateField(
      String label,
      String? value,
      Function(String?) onChanged,
      ) {
    return SizedBox(
      width: isMobile ? null : 145,
      child: TextFormField(
        key: ValueKey("$label-$value"),
        initialValue: value,
        decoration: _input(label).copyWith(
          hintText: "YYYY-MM-DD",
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dropdown(
      String label,
      String? value,
      List items,
      ValueChanged<String?> onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _input(label),
      isExpanded: true,
      items: items.map((e) {
        return DropdownMenuItem(
          value: "$e",
          child: Text(
            "$e",
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xffe2e8f0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xff7e22ce),
        ),
      ),
    );
  }

  Widget _kpi(
      String title,
      String value,
      String sub,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          top: BorderSide(
            color: color,
            width: 4,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xff64748b),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff64748b),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingPanel() {
    if (pendingRows.isEmpty) return const SizedBox();

    if (isMobile) {
      return _card(
        Column(
          children: [
            _pendingHeader(),
            ...pendingRows.map((r) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _mobileRequestCard(
                  r,
                  compact: true,
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    return _card(
      Column(
        children: [
          _pendingHeader(),
          ...pendingRows.map((r) {
            return ListTile(
              title: Text(
                "${r["employee"] ?? r["employee_name"] ?? "—"} — ${r["from_city"] ?? "—"} → ${r["to_city"] ?? "—"}",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                "${r["travel_date"] ?? "—"} · ${r["visit_type"] ?? r["mode"] ?? "—"} · ${r["purpose"] ?? ""}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _badge(
                    "${r["mode"] ?? r["mode_of_travel"] ?? "Road"}",
                    const Color(0xff64748b),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtRs(r["advance_amount"]),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _badge(
                    "Pending",
                    const Color(0xffd97706),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _pendingHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xfffffbeb),
        border: Border(
          bottom: BorderSide(
            color: Color(0xffffe3a3),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xffd97706),
          ),
          const SizedBox(width: 8),
          const Text(
            "Pending approval",
            style: TextStyle(
              color: Color(0xff92400e),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          _badge(
            "${pendingRows.length}",
            const Color(0xffd97706),
          ),
        ],
      ),
    );
  }

  Widget _statusDistribution() {
    final list = charts["by_status"] is List
        ? List<Map<String, dynamic>>.from(charts["by_status"])
        : _deriveStatus();

    final total = list.fold<num>(
      0,
          (s, e) => s + n(e["value"]),
    );

    return _chartBox(
      "By status",
      "Request status distribution",
      Column(
        children: list.map((e) {
          return _progressRow(
            "${e["name"]}",
            n(e["value"]),
            total,
            _statusColor("${e["name"]}"),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _deriveStatus() {
    final m = <String, int>{};

    for (final r in rows) {
      final s = "${r["status"] ?? "Unknown"}";
      m[s] = (m[s] ?? 0) + 1;
    }

    return m.entries.map((e) {
      return {
        "name": e.key,
        "value": e.value,
      };
    }).toList();
  }

  Widget _modeDistribution() {
    final list = charts["by_mode"] is List
        ? List<Map<String, dynamic>>.from(charts["by_mode"])
        : _deriveMode();

    final max = list.isEmpty
        ? 1
        : list.map((e) => n(e["value"])).reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "By travel mode",
      "Requests by mode",
      Column(
        children: list.map((e) {
          return _progressRow(
            "${e["name"]}",
            n(e["value"]),
            max,
            const Color(0xff7e22ce),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _deriveMode() {
    final m = <String, int>{};

    for (final r in rows) {
      final s = "${r["mode"] ?? r["mode_of_travel"] ?? "Road"}";
      m[s] = (m[s] ?? 0) + 1;
    }

    return m.entries.map((e) {
      return {
        "name": e.key,
        "value": e.value,
      };
    }).toList();
  }

  Widget _monthlyTrend() {
    final list = charts["monthly_trend"] is List
        ? List<Map<String, dynamic>>.from(charts["monthly_trend"])
        : [];

    final max = list.isEmpty
        ? 1
        : list.map((e) => n(e["value"])).reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "Monthly requests",
      "Last 6 months",
      list.isEmpty
          ? const Center(
        child: Text(
          "No trend data",
          style: TextStyle(color: Color(0xff94a3b8)),
        ),
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: list.map((m) {
          final h = max == 0 ? 0.0 : (n(m["value"]) / max) * 175;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: isMobile ? 18 : 22,
                  height: h,
                  decoration: BoxDecoration(
                    color: const Color(0xff7e22ce).withOpacity(.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${m["month"]}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xff64748b),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _employeeComparisonTable() {
    final m = <String, Map<String, dynamic>>{};

    for (final r in rows) {
      final e = "${r["employee"] ?? r["employee_name"] ?? "Unknown"}";

      m.putIfAbsent(e, () {
        return {
          "total": 0,
          "approved": 0,
          "pending": 0,
          "rejected": 0,
          "completed": 0,
          "advance": 0.0,
        };
      });

      m[e]!["total"]++;

      final st = "${r["status"] ?? ""}".toLowerCase();

      if (st == "approved") m[e]!["approved"]++;
      if (st == "pending" || st == "submitted") m[e]!["pending"]++;
      if (st == "rejected") m[e]!["rejected"]++;
      if (st == "completed") m[e]!["completed"]++;

      m[e]!["advance"] += n(r["advance_amount"]);
    }

    final list = m.entries.toList();
    list.sort(
          (a, b) => n(b.value["total"]).compareTo(n(a.value["total"])),
    );

    if (isMobile) {
      if (list.isEmpty) {
        return _emptyCard("No employee summary available");
      }

      return _card(
        Column(
          children: [
            _cardHead(
              "Employee travel summary",
              "Requests · approvals · advance disbursed",
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: list.map((e) {
                  final v = e.value;
                  final approvalRate = pct(
                    n(v["approved"]),
                    n(v["total"]),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _mobileInfoCard(
                      title: e.key,
                      subtitle: "Approval $approvalRate%",
                      badge: _badge(
                        "$approvalRate%",
                        approvalRate >= 70
                            ? const Color(0xff059669)
                            : approvalRate >= 40
                            ? const Color(0xffd97706)
                            : const Color(0xffdc2626),
                      ),
                      rows: [
                        _infoPair("Total", fmtN(v["total"])),
                        _infoPair("Approved", fmtN(v["approved"])),
                        _infoPair("Pending", fmtN(v["pending"])),
                        _infoPair("Rejected", fmtN(v["rejected"])),
                        _infoPair("Completed", fmtN(v["completed"])),
                        _infoPair("Advance", fmtRs(v["advance"])),
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

    return _card(
      Column(
        children: [
          _cardHead(
            "Employee travel summary",
            "Requests · approvals · advance disbursed",
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xfff8fafc),
              ),
              columns: const [
                DataColumn(label: Text("Employee")),
                DataColumn(label: Text("Total")),
                DataColumn(label: Text("Approved")),
                DataColumn(label: Text("Pending")),
                DataColumn(label: Text("Rejected")),
                DataColumn(label: Text("Completed")),
                DataColumn(label: Text("Advance ₹")),
                DataColumn(label: Text("Approval %")),
              ],
              rows: list.map((e) {
                final v = e.value;
                final approvalRate = pct(
                  n(v["approved"]),
                  n(v["total"]),
                );

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        e.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    DataCell(Text(fmtN(v["total"]))),
                    DataCell(Text(fmtN(v["approved"]))),
                    DataCell(Text(fmtN(v["pending"]))),
                    DataCell(Text(fmtN(v["rejected"]))),
                    DataCell(Text(fmtN(v["completed"]))),
                    DataCell(Text(fmtRs(v["advance"]))),
                    DataCell(
                      _badge(
                        "$approvalRate%",
                        approvalRate >= 70
                            ? const Color(0xff059669)
                            : approvalRate >= 40
                            ? const Color(0xffd97706)
                            : const Color(0xffdc2626),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _allRequestsTable() {
    if (isMobile) {
      if (rows.isEmpty) {
        return _emptyCard("No travel requests available");
      }

      return Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _mobileRequestCard(r),
          );
        }).toList(),
      );
    }

    return _card(
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xfff8fafc),
          ),
          columns: const [
            DataColumn(label: Text("Req #")),
            DataColumn(label: Text("Employee")),
            DataColumn(label: Text("Purpose")),
            DataColumn(label: Text("Type")),
            DataColumn(label: Text("From")),
            DataColumn(label: Text("To")),
            DataColumn(label: Text("Travel")),
            DataColumn(label: Text("Return")),
            DataColumn(label: Text("Mode")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("Adv?")),
            DataColumn(label: Text("Advance ₹")),
          ],
          rows: rows.map((r) {
            final adv = r["advance_required"] == true ||
                "${r["advance_required"]}".toLowerCase() == "true" ||
                "${r["advance_required"]}" == "1";

            return DataRow(
              cells: [
                DataCell(Text("${r["request_number"] ?? "—"}")),
                DataCell(
                  Text(
                    "${r["employee"] ?? r["employee_name"] ?? "—"}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Text(
                      "${r["purpose"] ?? "—"}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  _badge(
                    "${r["visit_type"] ?? ""}",
                    const Color(0xff64748b),
                  ),
                ),
                DataCell(Text("${r["from_city"] ?? "—"}")),
                DataCell(Text("${r["to_city"] ?? "—"}")),
                DataCell(Text("${r["travel_date"] ?? "—"}")),
                DataCell(Text("${r["return_date"] ?? "—"}")),
                DataCell(Text("${r["mode"] ?? "—"}")),
                DataCell(
                  _badge(
                    "${r["status"] ?? ""}",
                    _statusColor("${r["status"] ?? ""}"),
                  ),
                ),
                DataCell(
                  Text(
                    adv ? "YES" : "NO",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: adv
                          ? const Color(0xff059669)
                          : const Color(0xff94a3b8),
                    ),
                  ),
                ),
                DataCell(Text(fmtRs(r["advance_amount"]))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _mobileRequestCard(
      Map<String, dynamic> r, {
        bool compact = false,
      }) {
    final adv = r["advance_required"] == true ||
        "${r["advance_required"]}".toLowerCase() == "true" ||
        "${r["advance_required"]}" == "1";

    return _mobileInfoCard(
      title: "${r["employee"] ?? r["employee_name"] ?? "—"}",
      subtitle:
      "${r["from_city"] ?? "—"} → ${r["to_city"] ?? "—"}",
      badge: _badge(
        "${r["status"] ?? ""}",
        _statusColor("${r["status"] ?? ""}"),
      ),
      rows: [
        if (!compact) _infoPair("Req #", "${r["request_number"] ?? "—"}"),
        _infoPair("Purpose", "${r["purpose"] ?? "—"}"),
        _infoPair("Type", "${r["visit_type"] ?? "—"}"),
        _infoPair("Travel", "${r["travel_date"] ?? "—"}"),
        if (!compact) _infoPair("Return", "${r["return_date"] ?? "—"}"),
        _infoPair(
          "Mode",
          "${r["mode"] ?? r["mode_of_travel"] ?? "Road"}",
        ),
        _infoPair("Advance?", adv ? "YES" : "NO"),
        _infoPair("Advance", fmtRs(r["advance_amount"])),
      ],
    );
  }

  Widget _mobileInfoCard({
    required String title,
    required String subtitle,
    required Widget badge,
    required List<MapEntry<String, String>> rows,
  }) {
    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff64748b),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                badge,
              ],
            ),
            const SizedBox(height: 12),
            _infoGrid(rows),
          ],
        ),
      ),
    );
  }

  MapEntry<String, String> _infoPair(String label, String value) {
    return MapEntry(label, value);
  }

  Widget _infoGrid(List<MapEntry<String, String>> rows) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: rows.map((e) {
        return SizedBox(
          width: isMobile
              ? (MediaQuery.of(context).size.width - 58) / 2
              : 180,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xffeef2f7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.key.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xff94a3b8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff0f172a),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyCard(String text) {
    return _card(
      Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xff94a3b8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();

    if (s == "approved" || s == "completed") {
      return const Color(0xff059669);
    }

    if (s == "pending" || s == "submitted") {
      return const Color(0xffd97706);
    }

    if (s == "rejected") {
      return const Color(0xffdc2626);
    }

    return const Color(0xff64748b);
  }

  Widget _progressRow(
      String label,
      num value,
      num total,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 88 : 120,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: total == 0
                  ? 0
                  : (value / total).clamp(0, 1).toDouble(),
              minHeight: 10,
              backgroundColor: const Color(0xfff1f5f9),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: isMobile ? 48 : 70,
            child: Text(
              isMobile
                  ? fmtN(value)
                  : "${fmtN(value)} (${pct(value, total)}%)",
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBox(
      String title,
      String sub,
      Widget child,
      ) {
    return _card(
      Container(
        height: isMobile ? 260 : 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xff64748b),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    if (text.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xffe6eaf1),
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0d0f172a),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHead(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xffe2e8f0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff64748b),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
      String idx,
      String title, [
        String? desc,
      ]) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xfff3e8ff),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            idx,
            style: const TextStyle(
              color: Color(0xff7e22ce),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (desc != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              desc,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff64748b),
              ),
            ),
          ),
        ],
      ],
    );
  }
}