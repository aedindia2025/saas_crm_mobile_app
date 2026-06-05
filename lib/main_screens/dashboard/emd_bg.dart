import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EMDBGTab extends StatefulWidget {
  final String token;
  const EMDBGTab({super.key, required this.token});

  @override
  State<EMDBGTab> createState() => _EMDBGTabState();
}

class _EMDBGTabState extends State<EMDBGTab> {
  static const baseUrl = "http://103.110.236.187:3076/api/v1";

  bool loading = true;
  Map<String, dynamic>? data;
  String? tenantSlug;

  String? dateFrom;
  String? dateTo;
  String? status;
  String? financeStatus;
  String? type;
  String? bank;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  num n(dynamic v) => v == null ? 0 : num.tryParse(v.toString()) ?? 0;
  String fmtN(dynamic v) => NumberFormat.decimalPattern('en_IN').format(n(v));

  String fmtRs(dynamic v) {
    final value = n(v);
    if (value == 0) return "₹ 0";
    if (value >= 10000000) return "₹ ${(value / 10000000).toStringAsFixed(2)} Cr";
    if (value >= 100000) return "₹ ${(value / 100000).toStringAsFixed(2)} L";
    return "₹ ${fmtN(value.round())}";
  }

  int pct(num a, num b) => b == 0 ? 0 : ((a / b) * 100).round();

  Map<String, String> get queryParams {
    final p = <String, String>{};
    if (dateFrom?.isNotEmpty == true) p["date_from"] = dateFrom!;
    if (dateTo?.isNotEmpty == true) p["date_to"] = dateTo!;
    if (status?.isNotEmpty == true) p["status"] = status!;
    if (financeStatus?.isNotEmpty == true) p["finance_status"] = financeStatus!;
    if (type?.isNotEmpty == true) p["type"] = type!;
    if (bank?.isNotEmpty == true) p["bank"] = bank!;
    return p;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    if (tenantSlug == null) {
      final prefs = await SharedPreferences.getInstance();
      tenantSlug = prefs.getString('tenant_slug') ?? '';
    }

    final uri = Uri.parse("$baseUrl/dashboard/tab/emdbg")
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: {
      'X-Tenant-Slug': tenantSlug!,
      "Authorization": "Bearer ${widget.token}",
      "Accept": "application/json",
    });

    data = res.statusCode == 200 ? jsonDecode(res.body) : null;
    setState(() => loading = false);
  }

  Map<String, dynamic> get summary =>
      Map<String, dynamic>.from(data?["summary"] ?? {});

  Map<String, dynamic> get charts =>
      Map<String, dynamic>.from(data?["charts"] ?? {});

  Map<String, dynamic> get filters =>
      Map<String, dynamic>.from(data?["filters"] ?? {});

  List<Map<String, dynamic>> get rows {
    final list = data?["table"];
    if (list is List) return list.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get criticalRows {
    final list = rows.where((r) {
      final dl = n(r["days_left"]);
      return r["days_left"] != null && dl >= 0 && dl <= 7;
    }).toList();
    list.sort((a, b) => n(a["days_left"]).compareTo(n(b["days_left"])));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Scaffold(
        backgroundColor: Color(0xfff5f7fb),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activeCount = n(summary["active"]) != 0
        ? n(summary["active"])
        : rows.where((r) => "${r["status"]}".toLowerCase() == "active").length;

    final totalValue = n(summary["total_value"]) != 0
        ? n(summary["total_value"])
        : rows.fold<num>(0, (s, r) => s + n(r["instrument_amount"] ?? r["amount"]));

    final expiring7 =
    n(summary["expiring_7"]) != 0 ? n(summary["expiring_7"]) : criticalRows.length;

    final unpaid = n(summary["finance_unpaid"]) != 0
        ? n(summary["finance_unpaid"])
        : rows.where((r) => "${r["finance_status"]}".toLowerCase() == "unpaid").length;

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
              _header(activeCount, totalValue, expiring7, unpaid),
              const SizedBox(height: 14),
              _filterBar(),
              const SizedBox(height: 18),

              _section("02", "Critical Expiry Alert", "Expiring within 7 days"),
              const SizedBox(height: 10),
              _criticalAlertPanel(),
              const SizedBox(height: 18),

              _section("03", "Distribution & Expiry Risk", "Risk buckets, banks and trend"),
              const SizedBox(height: 10),
              _expiryRiskBuckets(),
              const SizedBox(height: 12),
              _bankExposureChart(),
              const SizedBox(height: 12),
              _monthlyTrend(),
              const SizedBox(height: 18),

              _section("04", "Instrument Type Analysis", "EMD · BG · DD"),
              const SizedBox(height: 10),
              _instrumentTypeDistribution(),
              const SizedBox(height: 12),
              _typeWiseExposure(),
              const SizedBox(height: 18),

              _section("06", "Customer Exposure", "Top customers by value"),
              const SizedBox(height: 10),
              _customerExposureList(),
              const SizedBox(height: 18),

              _section("07", "Status Analysis", "Instrument status breakdown"),
              const SizedBox(height: 10),
              _statusAnalysisTable(),
              const SizedBox(height: 18),

              _section("08", "Finance & Risk Intelligence", "Payment and instrument status"),
              const SizedBox(height: 10),
              _financeStatusPanel(),
              const SizedBox(height: 12),
              _instrumentStatusPanel(),
              const SizedBox(height: 18),

              _section("09", "All Instruments", "Complete instrument registry"),
              const SizedBox(height: 10),
              _allInstrumentsTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(num active, num exposure, num critical, num unpaid) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1e1b4b), Color(0xff4338ca), Color(0xff2563eb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x264338ca), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.shield, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "EMD / BG Control Center",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Finance risk · expiry intelligence",
                      style: TextStyle(color: Color(0xffdbeafe), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading ? null : loadData,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _headStat("Active", fmtN(active), const Color(0xffdbeafe))),
            const SizedBox(width: 8),
            Expanded(child: _headStat("Exposure", fmtRs(exposure), const Color(0xffffffff))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _headStat("Critical", fmtN(critical), critical > 0 ? const Color(0xffffcdd2) : const Color(0xffbbf7d0))),
            const SizedBox(width: 8),
            Expanded(child: _headStat("Unpaid", fmtN(unpaid), unpaid > 0 ? const Color(0xffffe3a3) : const Color(0xffbbf7d0))),
          ]),
        ],
      ),
    );
  }

  Widget _headStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xffbfdbfe),
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final statuses = filters["statuses"] is List ? filters["statuses"] as List : [];
    final financeStatuses =
    filters["finance_statuses"] is List ? filters["finance_statuses"] as List : [];
    final types = filters["types"] is List ? filters["types"] as List : [];
    final banks = filters["banks"] is List ? filters["banks"] as List : [];

    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _dateField("From", dateFrom, (v) => dateFrom = v)),
              const SizedBox(width: 10),
              Expanded(child: _dateField("To", dateTo, (v) => dateTo = v)),
            ]),
            const SizedBox(height: 10),
            _dropdown("Status", status, statuses, (v) => setState(() => status = v)),
            const SizedBox(height: 10),
            _dropdown("Finance", financeStatus, financeStatuses,
                    (v) => setState(() => financeStatus = v)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _dropdown("Type", type, types, (v) => setState(() => type = v))),
              const SizedBox(width: 10),
              Expanded(child: _dropdown("Bank", bank, banks, (v) => setState(() => bank = v))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loadData,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text("Apply"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff4338ca),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      dateFrom = null;
                      dateTo = null;
                      status = null;
                      financeStatus = null;
                      type = null;
                      bank = null;
                    });
                    loadData();
                  },
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text("Reset"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, String? value, Function(String?) onChanged) {
    return TextFormField(
      initialValue: value,
      decoration: _input(label).copyWith(hintText: "YYYY-MM-DD"),
      onChanged: onChanged,
    );
  }

  Widget _dropdown(String label, String? value, List items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: _input(label),
      items: items
          .map((e) => DropdownMenuItem(value: "$e", child: Text("$e", overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: const Color(0xfff8fafc),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff4338ca), width: 1.4),
      ),
    );
  }

  Widget _criticalAlertPanel() {
    if (criticalRows.isEmpty) {
      return _card(
        const Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xffdcfce7),
                child: Icon(Icons.check_circle, color: Color(0xff059669)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "No critical expirations — all instruments secure",
                  style: TextStyle(color: Color(0xff059669), fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _card(Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xfffff1f2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(color: Color(0xffffcdd2))),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xffdc2626)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Critical Alert — Expiring ≤7 Days",
                style: TextStyle(color: Color(0xff991b1b), fontWeight: FontWeight.w900),
              ),
            ),
            _badge("${criticalRows.length}", const Color(0xffdc2626)),
          ]),
        ),
        ...criticalRows.take(8).map((e) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xfff1f5f9))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xffffe4e6),
                  child: Text(
                    "${e["type"] ?? "EMD"}".substring(0, 1),
                    style: const TextStyle(color: Color(0xffdc2626), fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      "${e["client"] ?? "—"}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${e["bank"] ?? "—"} · ${e["expiry_date"] ?? "—"}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    fmtRs(e["amount"]),
                    style: const TextStyle(color: Color(0xffdc2626), fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  _daysBadge(e["days_left"]),
                ]),
              ],
            ),
          );
        }),
      ],
    ));
  }

  Widget _chartBox(String title, String sub, Widget child) {
    return _card(
      Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
          const SizedBox(height: 14),
          Expanded(child: child),
        ]),
      ),
    );
  }

  Widget _section(String idx, String title, [String? desc]) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xffeef2ff),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          idx,
          style: const TextStyle(
            color: Color(0xff4338ca),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          if (desc != null) ...[
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xff64748b))),
          ],
        ]),
      ),
    ]);
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6eaf1)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0d0f172a), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHead(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffe2e8f0)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
      ]),
    );
  }


  Widget _expiryRiskBuckets() {
    final buckets = {
      "Expired": 0,
      "≤7 days": 0,
      "8–15 days": 0,
      "16–30 days": 0,
      "31–60 days": 0,
      ">60 days": 0,
    };

    for (final r in rows) {
      if (r["days_left"] == null) continue;
      final dl = n(r["days_left"]);
      if (dl < 0) buckets["Expired"] = buckets["Expired"]! + 1;
      else if (dl <= 7) buckets["≤7 days"] = buckets["≤7 days"]! + 1;
      else if (dl <= 15) buckets["8–15 days"] = buckets["8–15 days"]! + 1;
      else if (dl <= 30) buckets["16–30 days"] = buckets["16–30 days"]! + 1;
      else if (dl <= 60) buckets["31–60 days"] = buckets["31–60 days"]! + 1;
      else buckets[">60 days"] = buckets[">60 days"]! + 1;
    }

    final max = buckets.values.isEmpty ? 1 : buckets.values.reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "Expiry Risk Timeline",
      "Instruments by days-to-expiry bucket",
      Column(children: buckets.entries.map((e) {
        return _progressRow(e.key, e.value, max, _bucketColor(e.key));
      }).toList()),
    );
  }

  Color _bucketColor(String key) {
    switch (key) {
      case "Expired":
        return const Color(0xff0b1220);
      case "≤7 days":
        return const Color(0xffdc2626);
      case "8–15 days":
        return const Color(0xfff97316);
      case "16–30 days":
        return const Color(0xffd97706);
      case "31–60 days":
        return const Color(0xff0284c7);
      default:
        return const Color(0xff059669);
    }
  }

  Widget _bankExposureChart() {
    final m = <String, num>{};
    for (final r in rows) {
      final b = "${r["bank"] ?? "Unknown"}";
      m[b] = (m[b] ?? 0) + n(r["amount"]);
    }

    final list = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = list.isEmpty ? 1 : list.first.value;

    return _chartBox(
      "Bank-wise Exposure ₹",
      "Top 8 banks by total instrument value",
      Column(children: list.take(8).map((e) {
        return _progressRow(e.key, e.value, max, const Color(0xff4338ca), money: true);
      }).toList()),
    );
  }

  Widget _monthlyTrend() {
    final trend = charts["monthly_trend"] is List
        ? List<Map<String, dynamic>>.from(charts["monthly_trend"])
        : _deriveMonthlyTrend();

    final max = trend.isEmpty ? 1 : trend.map((e) => n(e["issued"])).reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "Monthly Trend",
      "Instruments issued vs released over time",
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: trend.map((m) {
          final h = max == 0 ? 0.0 : (n(m["issued"]) / max) * 170;
          return Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                height: h,
                width: 18,
                decoration: BoxDecoration(
                  color: const Color(0xff4338ca).withOpacity(.75),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text("${m["name"]}", style: const TextStyle(fontSize: 9, color: Color(0xff64748b))),
            ]),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _deriveMonthlyTrend() {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final dt = "${r["issued_date"] ?? ""}";
      if (dt.length < 7) continue;
      final key = dt.substring(0, 7);
      m.putIfAbsent(key, () => {"name": key, "issued": 0, "released": 0, "value": 0.0});
      m[key]!["issued"]++;
      m[key]!["value"] += n(r["amount"]);
      if ("${r["status"]}".toLowerCase() == "released") m[key]!["released"]++;
    }
    final list = m.values.toList();
    list.sort((a, b) => "${a["name"]}".compareTo("${b["name"]}"));
    return list.take(12).toList();
  }

  Widget _instrumentTypeDistribution() {
    final typeRows = _typeRows();
    final total = typeRows.fold<num>(0, (s, e) => s + n(e["count"]));

    return _chartBox(
      "By Instrument Type",
      "Count distribution · EMD · BG · DD · others",
      Column(children: typeRows.map((t) {
        return _progressRow("${t["name"]}", n(t["count"]), total, _typeColor(typeRows.indexOf(t)));
      }).toList()),
    );
  }

  Widget _typeWiseExposure() {
    final typeRows = _typeRows();
    final max = typeRows.isEmpty ? 1 : typeRows.map((e) => n(e["value"])).reduce((a, b) => a > b ? a : b);

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHead("Type-wise Exposure", "Instrument count · value · active vs expiring"),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: typeRows.map((t) {
          final i = typeRows.indexOf(t);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: _typeColor(i), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${t["name"]}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: max == 0 ? 0 : n(t["value"]) / max,
                  minHeight: 7,
                  backgroundColor: const Color(0xfff1f5f9),
                  valueColor: AlwaysStoppedAnimation(_typeColor(i)),
                )
              ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtRs(t["value"]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                Text("${fmtN(t["count"])} · ${fmtN(t["active"])} active",
                    style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8))),
              ]),
            ]),
          );
        }).toList()),
      )
    ]));
  }

  List<Map<String, dynamic>> _typeRows() {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final t = "${r["type"] ?? "Unknown"}";
      m.putIfAbsent(t, () => {"name": t, "count": 0, "value": 0.0, "active": 0, "expiring": 0});
      m[t]!["count"]++;
      m[t]!["value"] += n(r["amount"]);
      if ("${r["status"]}".toLowerCase() == "active") m[t]!["active"]++;
      final dl = n(r["days_left"]);
      if (r["days_left"] != null && dl >= 0 && dl <= 30) m[t]!["expiring"]++;
    }
    final list = m.values.toList();
    list.sort((a, b) => n(b["value"]).compareTo(n(a["value"])));
    return list;
  }

  Color _typeColor(int i) {
    const colors = [
      Color(0xff4338ca),
      Color(0xffdc2626),
      Color(0xffd97706),
      Color(0xff0284c7),
      Color(0xff7c3aed),
      Color(0xff059669),
      Color(0xffdb2777),
    ];
    return colors[i % colors.length];
  }

  Widget _customerExposureList() {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final c = "${r["client"] ?? "Unknown"}";
      m.putIfAbsent(c, () => {"name": c, "count": 0, "value": 0.0, "critical": 0});
      m[c]!["count"]++;
      m[c]!["value"] += n(r["amount"]);
      final dl = n(r["days_left"]);
      if (r["days_left"] != null && dl >= 0 && dl <= 7) m[c]!["critical"]++;
    }

    final list = m.values.toList();
    list.sort((a, b) => n(b["value"]).compareTo(n(a["value"])));
    final max = list.isEmpty ? 1 : n(list.first["value"]);

    return _card(Column(children: [
      _cardHead("Top 10 — Customer Exposure", "Highest instrument value by customer"),
      ...list.take(10).map((c) {
        return ListTile(
          leading: Text("${list.indexOf(c) + 1}".padLeft(2, "0"),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xff94a3b8))),
          title: Text("${c["name"]}", maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: LinearProgressIndicator(
            value: max == 0 ? 0 : n(c["value"]) / max,
            minHeight: 6,
            backgroundColor: const Color(0xfff1f5f9),
            valueColor: const AlwaysStoppedAnimation(Color(0xff4338ca)),
          ),
          trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(fmtRs(c["value"]), style: const TextStyle(fontWeight: FontWeight.w900)),
            Text("${fmtN(c["count"])} instruments", style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8))),
          ]),
        );
      })
    ]));
  }

  Widget _statusAnalysisTable() {
    return _analysisTable("status", "Instrument Status Breakdown", "Count and exposure by status");
  }

  Widget _analysisTable(String key, String title, String sub) {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final k = "${r[key] ?? "Unknown"}";
      m.putIfAbsent(k, () => {"count": 0, "value": 0.0, "critical": 0});
      m[k]!["count"]++;
      m[k]!["value"] += n(r["amount"]);
      final dl = n(r["days_left"]);
      if (r["days_left"] != null && dl >= 0 && dl <= 15) m[k]!["critical"]++;
    }

    final list = m.entries.toList();
    list.sort((a, b) => n(b.value["value"]).compareTo(n(a.value["value"])));
    final totalVal = list.fold<num>(0, (s, e) => s + n(e.value["value"]));

    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardHead(title, sub),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: list.map((e) {
              final v = e.value;
              final color = _statusColor(e.key);
              final share = pct(n(v["value"]), totalVal);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: color.withOpacity(.12),
                        child: Icon(Icons.verified_user_outlined, color: color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ),
                      _badge("$share%", color),
                    ]),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: totalVal == 0 ? 0 : (n(v["value"]) / totalVal).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: const Color(0xffe2e8f0),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _miniInfo("Count", fmtN(v["count"])),
                        _miniInfo("At Risk ≤15d", n(v["critical"]) > 0 ? fmtN(v["critical"]) : "—"),
                        _miniInfo("Exposure", fmtRs(v["value"])),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ));
  }

  Widget _financeStatusPanel() => _statusBars("finance_status", "Finance Status", "Payment status distribution by exposure value");

  Widget _instrumentStatusPanel() => _statusBars("status", "Instrument Status", "Active · Released · Expired · Encashed");

  Widget _statusBars(String key, String title, String sub) {
    final m = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final k = "${r[key] ?? "Unknown"}";
      m.putIfAbsent(k, () => {"count": 0, "value": 0.0});
      m[k]!["count"]++;
      m[k]!["value"] += n(r["amount"]);
    }

    final list = m.entries.toList();
    list.sort((a, b) => n(b.value["value"]).compareTo(n(a.value["value"])));
    final total = list.fold<num>(0, (s, e) => s + n(e.value["value"]));

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHead(title, sub),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: list.map((e) {
          final color = _statusColor(e.key);
          return _progressRow(e.key, n(e.value["value"]), total, color, money: true, count: n(e.value["count"]));
        }).toList()),
      )
    ]));
  }

// REPLACE _allInstrumentsTable()
  Widget _allInstrumentsTable() {
    return _card(Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: rows.map((r) {
          final statusColor = _statusColor("${r["status"] ?? ""}");
          final financeColor = _statusColor("${r["finance_status"] ?? ""}");

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffe2e8f0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xffeef2ff),
                    child: Text(
                      "${r["type"] ?? "I"}".isEmpty ? "I" : "${r["type"] ?? "I"}".substring(0, 1),
                      style: const TextStyle(
                        color: Color(0xff4338ca),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        "${r["ref"] ?? "—"}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "${r["client"] ?? "—"}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtRs(r["amount"]),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _badge("${r["type"] ?? ""}", const Color(0xff0284c7)),
                    _badge("${r["status"] ?? ""}", statusColor),
                    _badge("${r["finance_status"] ?? ""}", financeColor),
                    _badge("${r["return_status"] ?? "—"}", const Color(0xff64748b)),
                    _daysBadge(r["days_left"]),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniInfo("Tender No", "${r["tender_num"] ?? "—"}"),
                    _miniInfo("Bank", "${r["bank"] ?? "—"}"),
                    _miniInfo("Issued", "${r["issued_date"] ?? "—"}"),
                    _miniInfo("Expiry", "${r["expiry_date"] ?? "—"}"),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ));
  }

  // ADD this helper inside _EMDBGTabState
  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Color(0xff94a3b8),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == "active" || s == "paid" || s == "released") return const Color(0xff059669);
    if (s == "expired" || s == "overdue" || s == "encashed") return const Color(0xffdc2626);
    if (s == "unpaid" || s == "pending") return const Color(0xffd97706);
    return const Color(0xff64748b);
  }

  Widget _progressRow(String label, num value, num total, Color color, {bool money = false, num? count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (value / total).clamp(0, 1),
            minHeight: 9,
            backgroundColor: const Color(0xfff1f5f9),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            count == null
                ? money ? fmtRs(value) : "${fmtN(value)} (${pct(value, total)}%)"
                : "${fmtN(count)} · ${fmtRs(value)}",
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }

  Widget _daysBadge(dynamic days) {
    if (days == null) return _badge("—", const Color(0xff94a3b8));

    final d = n(days);
    Color color;
    String label;

    if (d < 0) {
      color = const Color(0xff0b1220);
      label = "${d.abs().round()}d overdue";
    } else if (d <= 7) {
      color = const Color(0xffdc2626);
      label = "${d.round()}d";
    } else if (d <= 30) {
      color = const Color(0xffd97706);
      label = "${d.round()}d";
    } else {
      color = const Color(0xff059669);
      label = "${d.round()}d";
    }

    return _badge(label, color);
  }

  Widget _badge(String text, Color color) {
    if (text.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

}