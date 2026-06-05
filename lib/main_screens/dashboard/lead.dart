import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LeadsTab extends StatefulWidget {
  final String token;
  const LeadsTab({super.key, required this.token});

  @override
  State<LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<LeadsTab> {
  static const baseUrl = "http://103.110.236.187:3076/api/v1";

  bool loading = true;
  Map<String, dynamic>? data;
  String tenantSlug = "";

  String? dateFrom;
  String? dateTo;
  String? assignedTo;
  String? status;
  String? customerId;

  String compareBy = "group";

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tenantSlug = prefs.getString('tenant_slug') ?? '';
    });
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

  String stageLabel(String? priority) {
    if (priority == "High") return "Sales Qualified";
    if (priority == "Medium") return "Opportunity Developing";
    return "Prospect Identified";
  }

  Color stageColor(String? priority) {
    if (priority == "High") return const Color(0xff10b981);
    if (priority == "Medium") return const Color(0xfff59e0b);
    return const Color(0xff0ea5e9);
  }

  Map<String, String> get queryParams {
    final p = <String, String>{};
    if (dateFrom?.isNotEmpty == true) p["date_from"] = dateFrom!;
    if (dateTo?.isNotEmpty == true) p["date_to"] = dateTo!;
    if (assignedTo?.isNotEmpty == true) p["assigned_to"] = assignedTo!;
    if (status?.isNotEmpty == true) p["status"] = status!;
    if (customerId?.isNotEmpty == true) p["customer_id"] = customerId!;
    return p;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    final uri = Uri.parse("$baseUrl/dashboard/tab/leads")
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: {
      'X-Tenant-Slug': tenantSlug,
      "Authorization": "Bearer ${widget.token}",
      "Accept": "application/json",
    });

    if (res.statusCode == 200) {
      data = jsonDecode(res.body);
    } else {
      data = null;
    }

    setState(() => loading = false);
  }

  List<Map<String, dynamic>> get rows {
    final list = data?["table"];
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, dynamic> get summary =>
      Map<String, dynamic>.from(data?["summary"] ?? {});

  Map<String, dynamic> get charts =>
      Map<String, dynamic>.from(data?["charts"] ?? {});

  Map<String, dynamic> get filters =>
      Map<String, dynamic>.from(data?["filters"] ?? {});

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
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
              _header(),
              const SizedBox(height: 12),
              _filterBar(),
              const SizedBox(height: 16),
              _opportunitiesPanel(),
              const SizedBox(height: 16),
              if (n(summary["overdue"]) > 0) ...[
                _overduePanel(),
                const SizedBox(height: 16),
              ],
              _distributionSection(),
              const SizedBox(height: 16),
              _comparisonTable(),
              const SizedBox(height: 16),
              _topLeadsSection(),
              const SizedBox(height: 16),
              _allLeadsTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _allLeadsTable() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("08", "All Leads"),
      const SizedBox(height: 10),
      _card(
        rows.isEmpty
            ? const Padding(padding: EdgeInsets.all(24), child: Text("No leads found"))
            : Column(children: rows.map((r) => _leadRowCard(r)).toList()),
      ),
    ]);
  }

  Widget _leadRowCard(Map<String, dynamic> r) {
    final follow = "${r["follow_up"] ?? ""}";
    final followDate = DateTime.tryParse(follow);
    final overdue = followDate != null &&
        followDate.isBefore(DateTime.now()) &&
        !["Converted", "Lost"].contains("${r["status"] ?? ""}");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xfff1f5f9))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xffe0f2fe),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.track_changes, color: Color(0xff0284c7), size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              "${r["title"] ?? "—"}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xff0f172a)),
            ),
          ),
          _badge("${r["status"] ?? ""}", const Color(0xff64748b)),
        ]),
        const SizedBox(height: 5),
        Text(
          "${r["customer"] ?? "—"} · Ref: ${r["ref"] ?? "—"}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xff64748b), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _inlineValue("Stage", stageLabel("${r["priority"] ?? ""}"), stageColor("${r["priority"] ?? ""}")),
          _inlineValue("Est", fmtRs(r["est_value"]), const Color(0xff7c3aed)),
          _inlineValue("Group", "${r["group"] ?? "—"}", const Color(0xff059669)),
          _inlineValue("Assignee", "${r["assigned_to"] ?? "—"}", const Color(0xff0284c7)),
          _inlineValue("Follow-up", follow.isEmpty ? "—" : follow, overdue ? const Color(0xffdc2626) : const Color(0xff64748b)),
          _inlineValue("Created", "${r["created_at"] ?? "—"}", const Color(0xff64748b)),
        ]),
      ]
      ),
      )]

      ),

    );
  }

  Widget _header() {
    final pipelineValue = n(summary["pipeline_value"]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff020617), Color(0xff0f172a), Color(0xff1e293b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0x1a67e8f9),
                child: Icon(Icons.track_changes, color: Color(0xff67e8f9)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Lead Analytics",
                      style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Sales pipeline intelligence",
                      style: TextStyle(color: Color(0xffcbd5e1), fontSize: 12),
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
          Column(
            children: [
              Row(children: [
                _darkMetric("Total Leads", fmtN(summary["total"]), "Overall lead volume"),
                const SizedBox(width: 10),
                _darkMetric("Active", fmtN(summary["active"]), "Currently in pipeline"),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _darkMetric("Converted", fmtN(summary["converted"]), "Successfully won"),
                const SizedBox(width: 10),
                _darkMetric("Pipeline Value", fmtRs(pipelineValue), "Estimated value"),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkMetric(String title, String value, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          border: Border.all(color: Colors.white.withOpacity(.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xff94a3b8), fontSize: 9, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xff94a3b8), fontSize: 10),
          ),
        ]),
      ),
    );
  }

  Widget _filterBar() {
    final owners = filters["owners"] is List ? filters["owners"] as List : [];
    final statuses = filters["statuses"] is List ? filters["statuses"] as List : [];

    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.filter_alt_outlined, size: 15, color: Color(0xff0284c7)),
            SizedBox(width: 8),
            Text("FILTERS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          ]),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(child: _dateField("FROM DATE", dateFrom, (v) => setState(() => dateFrom = v))),
            const SizedBox(width: 10),
            Expanded(child: _dateField("TO DATE", dateTo, (v) => setState(() => dateTo = v))),
          ]),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: assignedTo,
                isExpanded: true,
                decoration: _input("OWNER"),
                items: owners.map((o) {
                  final id = "${o["id"]}";
                  final name = "${o["name"] ?? id}";
                  return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setState(() => assignedTo = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: status,
                isExpanded: true,
                decoration: _input("STATUS"),
                items: statuses.map((s) {
                  return DropdownMenuItem(value: "$s", child: Text("$s", overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (v) => setState(() => status = v),
              ),
            ),
          ]),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0284c7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    dateFrom = null;
                    dateTo = null;
                    assignedTo = null;
                    status = null;
                    customerId = null;
                  });
                  loadData();
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                child: const Text("Reset"),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _dateField(String label, String? value, Function(String?) onChanged) {
    return TextFormField(
      initialValue: value,
      decoration: _input(label).copyWith(hintText: "YYYY-MM-DD"),
      onChanged: (v) => onChanged(v),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _opportunitiesPanel() {
    final opps = rows
        .where((r) => ["Opportunity Created", "Qualified", "Proposal Sent", "Negotiation"].contains(r["status"]))
        .toList()
      ..sort((a, b) => n(b["est_value"]).compareTo(n(a["est_value"])));

    final top = opps.take(6).toList();
    final totalValue = top.fold<num>(0, (s, r) => s + n(r["est_value"]));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("02", "Opportunities", "Sales Qualified / Opportunity Developing / Proposal stage"),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead("Active Opportunities", "${top.length} opportunities · ${fmtRs(totalValue)} pipeline"),
        if (top.isEmpty)
          const Padding(padding: EdgeInsets.all(28), child: Text("No active opportunities in pipeline"))
        else
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: top.map((r) => _opportunityRow(r)).toList(),
            ),
          ),
      ])),
    ]);
  }

  Widget _opportunityRow(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xfff0f9ff),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffbae6fd)),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xffe0f2fe),
          child: Icon(Icons.trending_up, color: Color(0xff0284c7), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("${r["status"] ?? ""}", style: const TextStyle(color: Color(0xff0284c7), fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text("${r["title"] ?? r["name"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          Text("${r["customer"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtRs(r["est_value"]), style: const TextStyle(color: Color(0xff0284c7), fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          _badge(stageLabel("${r["priority"] ?? ""}"), stageColor("${r["priority"] ?? ""}")),
        ]),
      ]),
    );
  }

  Widget _overduePanel() {
    final today = DateTime.now();
    final overdue = rows.where((r) {
      final f = DateTime.tryParse("${r["follow_up"] ?? ""}");
      final st = "${r["status"] ?? ""}";
      return f != null && f.isBefore(today) && !["Converted", "Lost"].contains(st);
    }).take(10).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("03", "Overdue Follow-ups", "${overdue.length} leads need immediate action"),
      const SizedBox(height: 10),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHead("Overdue Follow-ups", "${overdue.length} pending"),
        if (overdue.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Text("All follow-ups are current"))
        else
          Column(children: overdue.map((r) {
            final f = DateTime.tryParse("${r["follow_up"]}");
            final days = f == null ? 0 : today.difference(f).inDays;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffffe4e6)))),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xffdc2626)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${r["title"] ?? r["name"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text("${r["customer"] ?? "—"} · ${r["assigned_to"] ?? "—"}", style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                ])),
                _badge("${days}d overdue", const Color(0xffdc2626)),
              ]),
            );
          }).toList()),
      ])),
    ]);
  }

  Widget _distributionSection() {
    final byStatus = List<Map<String, dynamic>>.from(charts["by_status"] ?? []);
    final byPriority = List<Map<String, dynamic>>.from(charts["by_priority"] ?? []);
    final monthly = List<Map<String, dynamic>>.from(charts["monthly_trend"] ?? []);
    final bySource = List<Map<String, dynamic>>.from(charts["by_source"] ?? []);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("04", "Distribution & Trends"),
      const SizedBox(height: 10),
      _statusBars(byStatus),
      const SizedBox(height: 12),
      _monthlyTrend(monthly),
      const SizedBox(height: 12),
      _stageBars(byPriority),
      const SizedBox(height: 12),
      _funnel(),
      const SizedBox(height: 12),
      _regionHealth(),
      const SizedBox(height: 12),
      _pipelineFreshness(),
      const SizedBox(height: 12),
      _sourceBars(bySource),
    ]);
  }

  Widget _statusBars(List<Map<String, dynamic>> items) {
    final total = items.fold<num>(0, (s, e) => s + n(e["value"]));
    return _chartBox("By Status", "Lead stage composition",
        Column(children: items.map((d) => _progressRow("${d["name"]}", n(d["value"]), total, const Color(0xff0284c7))).toList()));
  }

  Widget _monthlyTrend(List<Map<String, dynamic>> items) {
    final max = items.isEmpty ? 1 : items.map((e) => n(e["value"])).reduce((a, b) => a > b ? a : b);
    return _chartBox("Monthly Trend", "New leads — last 12 months",
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: items.map((m) {
          final h = max == 0 ? 0.0 : (n(m["value"]) / max) * 180;
          return Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(height: h, width: 18, decoration: BoxDecoration(color: const Color(0xff1e40af), borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Text("${m["month"]}", style: const TextStyle(fontSize: 10, color: Color(0xff64748b))),
            ]),
          );
        }).toList()));
  }

  Widget _stageBars(List<Map<String, dynamic>> items) {
    final total = items.fold<num>(0, (s, e) => s + n(e["value"]));
    return _chartBox("By Stage", "Sales Qualified · Opportunity Developing · Prospect Identified",
        Column(children: items.map((p) {
          final label = stageLabel("${p["name"]}");
          return _progressRow(label, n(p["value"]), total, stageColor("${p["name"]}"));
        }).toList()));
  }

  Widget _funnel() {
    final stages = [
      ["Total", n(summary["total"]), const Color(0xff4338ca)],
      ["Active", n(summary["active"]), const Color(0xff0284c7)],
      ["Qualified", n(summary["qualified"]), const Color(0xffd97706)],
      ["Converted", n(summary["converted"]), const Color(0xff059669)],
    ];
    final max = stages.first[1] as num;

    return _chartBox("Conversion Funnel", "Stage-by-stage progression",
        Column(children: stages.map((s) {
          return _progressRow("${s[0]}", s[1] as num, max, s[2] as Color);
        }).toList()));
  }

  Widget _regionHealth() {
    final map = <String, int>{};
    for (final r in rows) {
      final key = "${r["region"] ?? r["branch"] ?? r["state"] ?? ""}".trim();
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }

    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = list.isEmpty ? 1 : list.first.value;

    return _chartBox("State Performance", "Active · Converted · Lost per region",
        Column(children: list.take(9).map((e) => _progressRow(e.key, e.value, max, const Color(0xff059669))).toList()));
  }

  Widget _pipelineFreshness() {
    final buckets = {
      "≤7d": 0,
      "8–30d": 0,
      "31–90d": 0,
      "91–180d": 0,
      "180d+": 0,
    };

    final now = DateTime.now();
    for (final r in rows) {
      if (["Converted", "Lost"].contains(r["status"])) continue;
      final created = DateTime.tryParse("${r["created_at"] ?? ""}");
      if (created == null) continue;
      final age = now.difference(created).inDays;
      if (age <= 7) buckets["≤7d"] = buckets["≤7d"]! + 1;
      else if (age <= 30) buckets["8–30d"] = buckets["8–30d"]! + 1;
      else if (age <= 90) buckets["31–90d"] = buckets["31–90d"]! + 1;
      else if (age <= 180) buckets["91–180d"] = buckets["91–180d"]! + 1;
      else buckets["180d+"] = buckets["180d+"]! + 1;
    }

    final max = buckets.values.isEmpty ? 1 : buckets.values.reduce((a, b) => a > b ? a : b);

    return _chartBox("Pipeline Freshness", "Active leads by days in pipeline",
        Column(children: buckets.entries.map((e) => _progressRow(e.key, e.value, max, const Color(0xfff59e0b))).toList()));
  }

  Widget _sourceBars(List<Map<String, dynamic>> items) {
    final max = items.isEmpty
        ? 1
        : items.map((e) => n(e["value"])).reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "Lead Source",
      "Leads by acquisition channel",
      ListView(
        padding: EdgeInsets.zero,
        children: items
            .take(10)
            .map((e) => _progressRow(
          "${e["name"]}",
          n(e["value"]),
          max,
          const Color(0xff8b5cf6),
        ))
            .toList(),
      ),
    );
  }

  Widget _comparisonTable() {
    final grouped = <String, Map<String, dynamic>>{};
    final today = DateTime.now();

    for (final r in rows) {
      String key;
      switch (compareBy) {
        case "user":
          key = "${r["assigned_to"] ?? "Unassigned"}";
          break;
        case "state":
          key = "${r["state"] ?? r["region"] ?? "Unknown"}";
          break;
        case "source":
          key = "${r["source"] ?? r["lead_source"] ?? "Direct"}";
          break;
        case "sector":
          key = "${r["industry"] ?? r["vertical"] ?? r["sector"] ?? "General"}";
          break;
        case "month":
          key = "${r["created_at"] ?? ""}".length >= 7 ? "${r["created_at"]}".substring(0, 7) : "Unknown";
          break;
        default:
          key = "${r["group"] ?? r["assigned_group"] ?? r["team"] ?? "No Group"}";
      }

      grouped.putIfAbsent(key, () => {
        "total": 0,
        "high": 0,
        "medium": 0,
        "low": 0,
        "converted": 0,
        "lost": 0,
        "overdue": 0,
        "value": 0.0,
      });

      grouped[key]!["total"]++;
      final p = "${r["priority"] ?? ""}".toLowerCase();
      if (p == "high") grouped[key]!["high"]++;
      else if (p == "medium") grouped[key]!["medium"]++;
      else grouped[key]!["low"]++;

      if (r["status"] == "Converted") grouped[key]!["converted"]++;
      if (r["status"] == "Lost") grouped[key]!["lost"]++;

      final follow = DateTime.tryParse("${r["follow_up"] ?? ""}");
      if (follow != null && follow.isBefore(today) && !["Converted", "Lost"].contains(r["status"])) {
        grouped[key]!["overdue"]++;
      }

      grouped[key]!["value"] += n(r["est_value"]);
    }

    final list = grouped.entries.toList()
      ..sort((a, b) => b.value["total"].compareTo(a.value["total"]));

    final options = {
      "user": "User-wise",
      "group": "Group-wise",
      "state": "State-wise",
      "source": "Source-wise",
      "sector": "Sector-wise",
      "month": "Month-wise",
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("06", "Lead Comparison", "Compare by User · Group · State · Source · Sector · Month"),
      const SizedBox(height: 10),
      _card(
          Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Lead Comparison", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text("Grouped comparison", style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Text("No comparison data"))
                else
                  Column(
                    children: list.take(25).map((e) {
                      final v = e.value;
                      return _leadComparisonRow(e.key, v);
                    }).toList(),
                  )
              ]),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xfff8fafc)),
                columns: const [
                  DataColumn(label: Text("Entity")),
                  DataColumn(label: Text("Total")),
                  DataColumn(label: Text("Sales Qualified")),
                  DataColumn(label: Text("Opportunity Developing")),
                  DataColumn(label: Text("Prospect Identified")),
                  DataColumn(label: Text("Converted")),
                  DataColumn(label: Text("Lost")),
                  DataColumn(label: Text("Pipeline ₹")),
                  DataColumn(label: Text("Overdue")),
                  DataColumn(label: Text("Win Rate")),
                ],
                rows: list.take(25).map((e) {
                  final v = e.value;
                  return DataRow(cells: [
                    DataCell(SizedBox(width: 170, child: Text(e.key, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(fmtN(v["total"]))),
                    DataCell(Text(fmtN(v["high"]))),
                    DataCell(Text(fmtN(v["medium"]))),
                    DataCell(Text(fmtN(v["low"]))),
                    DataCell(Text(fmtN(v["converted"]))),
                    DataCell(Text(fmtN(v["lost"]))),
                    DataCell(Text(fmtRs(v["value"]))),
                    DataCell(Text(fmtN(v["overdue"]))),
                    DataCell(Text("${pct(n(v["converted"]), n(v["total"]))}%")),
                  ]);
                }).toList(),
              ),
            )
          ])),
    ]);
  }


  Widget _leadComparisonRow(String title, Map<String, dynamic> v) {
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
              color: const Color(0xffe0f2fe),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.compare_arrows,
              color: Color(0xff0284c7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                    color: Color(0xff0f172a),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${fmtN(v["total"])} leads · ${fmtN(v["converted"])} converted · ${fmtN(v["overdue"])} overdue",
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
                    _inlineValue("Sales Qualified", fmtN(v["high"]), const Color(0xff10b981)),
                    _inlineValue("Opportunity Developing", fmtN(v["medium"]), const Color(0xfff59e0b)),
                    _inlineValue("Prospect Identified", fmtN(v["low"]), const Color(0xff0ea5e9)),
                    _inlineValue("Pipeline", fmtRs(v["value"]), const Color(0xff7c3aed)),
                    _inlineValue("Lost", fmtN(v["lost"]), const Color(0xffdc2626)),
                    _inlineValue("Win Rate", "${pct(n(v["converted"]), n(v["total"]))}%", const Color(0xff059669)),
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
        text: TextSpan(children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(fontSize: 10, color: Color(0xff64748b), fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900),
          ),
        ]),
      ),
    );
  }

  Widget _topLeadsSection() {
    final topLeads = rows.where((r) => n(r["est_value"]) > 0).toList()
      ..sort((a, b) => n(b["est_value"]).compareTo(n(a["est_value"])));

    final cust = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final name = "${r["customer"] ?? r["customer_name"] ?? "Unknown"}";
      cust.putIfAbsent(name, () => {"count": 0, "value": 0.0});
      cust[name]!["count"]++;
      cust[name]!["value"] += n(r["est_value"]);
    }

    final topCust = cust.entries.toList()
      ..sort((a, b) => b.value["count"].compareTo(a.value["count"]));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section("07", "Top Leads"),
      const SizedBox(height: 10),
      _rankList("Top 10 — Highest Value Leads", topLeads.take(10).map((r) {
        return {
          "title": r["title"] ?? r["name"] ?? "—",
          "sub": "${r["customer"] ?? "—"} · ${stageLabel("${r["priority"] ?? ""}")}",
          "value": fmtRs(r["est_value"]),
        };
      }).toList()),
      const SizedBox(height: 12),
      _rankList("Top 10 — Most Active Customers", topCust.take(10).map((e) {
        return {
          "title": e.key,
          "sub": "${fmtRs(e.value["value"])} pipeline value",
          "value": "${e.value["count"]} leads",
        };
      }).toList()),
    ]);
  }

  Widget _rankList(String title, Iterable<Map<String, dynamic>> items) {
    final list = items.toList();
    return _card(Column(children: [
      _cardHead(title, "Ranked list"),
      if (list.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Text("No data"))
      else
        ...List.generate(list.length, (i) {
          final r = list[i];
          return ListTile(
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: i < 3 ? const Color(0xff0284c7) : const Color(0xfff1f5f9),
              child: Text("${i + 1}", style: TextStyle(fontSize: 10, color: i < 3 ? Colors.white : const Color(0xff64748b))),
            ),
            title: Text("${r["title"]}", maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text("${r["sub"]}", maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text("${r["value"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xff0284c7))),
          );
        })
    ]));
  }

  Widget _progressRow(String label, num value, num total, Color color) {
    final v = total == 0 ? 0.0 : value / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 150, child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        Expanded(child: LinearProgressIndicator(
          value: v.clamp(0, 1),
          minHeight: 9,
          backgroundColor: const Color(0xfff1f5f9),
          valueColor: AlwaysStoppedAnimation(color),
        )),
        const SizedBox(width: 10),
        SizedBox(width: 65, child: Text("${fmtN(value)} (${pct(value, total)}%)", style: const TextStyle(fontSize: 11))),
      ]),
    );
  }

  Widget _chartBox(String title, String sub, Widget child) {
    return _card(
      SizedBox(
        height: 320,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
            const SizedBox(height: 12),
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    if (text.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffe2e8f0)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
      ]),
    );
  }

  Widget _section(String idx, String title, [String? desc]) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xffe0f2fe), borderRadius: BorderRadius.circular(8)),
        child: Text(idx, style: const TextStyle(color: Color(0xff0284c7), fontSize: 11, fontWeight: FontWeight.w900)),
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
}

