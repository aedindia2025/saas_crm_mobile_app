import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


class TendersTab extends StatefulWidget {
  final String token;
  const TendersTab({super.key, required this.token});

  @override
  State<TendersTab> createState() => _TendersTabState();
}

class _TendersTabState extends State<TendersTab> {
  static const baseUrl = "http://103.110.236.187:3076/api/v1";

  bool loading = true;
  Map<String, dynamic>? data;

  String? dateFrom;
  String? dateTo;
  String? assignedTo;
  String? status;
  String? result;
  String? customerId;

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
    if (assignedTo?.isNotEmpty == true) p["assigned_to"] = assignedTo!;
    if (status?.isNotEmpty == true) p["status"] = status!;
    if (result?.isNotEmpty == true) p["result"] = result!;
    if (customerId?.isNotEmpty == true) p["customer_id"] = customerId!;
    return p;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    final uri = Uri.parse("$baseUrl/dashboard/tab/tenders")
        .replace(queryParameters: queryParams);

    final res = await http.get(uri, headers: {
      'X-Tenant-Slug': 'ascent',
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

  Map<String, dynamic> get summary =>
      Map<String, dynamic>.from(data?["summary"] ?? {});

  Map<String, dynamic> get charts =>
      Map<String, dynamic>.from(data?["charts"] ?? {});

  Map<String, dynamic> get topLists =>
      Map<String, dynamic>.from(data?["top_lists"] ?? {});

  Map<String, dynamic> get filters =>
      Map<String, dynamic>.from(data?["filters"] ?? {});

  List<Map<String, dynamic>> get tableRows {
    final list = data?["table"];
    if (list is List) return list.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get alerts {
    final list = data?["alerts"];
    if (list is List) return list.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get calendar {
    final list = data?["calendar"];
    if (list is List) return list.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

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
              _moduleHeader(),
              const SizedBox(height: 12),
              _filterBar(),
              const SizedBox(height: 16),

              if (alerts.isNotEmpty) ...[
                _section("01", "Smart Alerts", "${alerts.length} items need attention"),
                const SizedBox(height: 10),
                _alertBanner(),
                const SizedBox(height: 16),
              ],

              _section("03", "Finance Metrics", "Value · EMD · deadlines"),
              const SizedBox(height: 10),
              _financeKpis(),
              const SizedBox(height: 16),

              _section("04", "Pipeline & Results", "Stage conversion funnel · outcome distribution"),
              const SizedBox(height: 10),
              _stagePipeline(),
              const SizedBox(height: 12),
              _resultBreakdown(),
              const SizedBox(height: 16),

              _section("05", "Trends & Channels", "Monthly volume · portal distribution"),
              const SizedBox(height: 10),
              _monthlyTrend(),
              const SizedBox(height: 12),
              _portalBars(),
              const SizedBox(height: 16),

              _section("06", "Bid Submission Calendar", "Deadline heat map · upcoming list"),
              const SizedBox(height: 10),
              _bidCalendar(),
              const SizedBox(height: 16),

              _section("07", "Portal Comparison", "Win rate · bid value by channel"),
              const SizedBox(height: 10),
              _portalTable(),
              const SizedBox(height: 16),

              _section("08", "Top Performers", "Highest value · top customers · top KAMs"),
              const SizedBox(height: 10),
              _topPerformers(),
              const SizedBox(height: 16),

              _section("10", "All Tenders", "${tableRows.length} records"),
              const SizedBox(height: 10),
              _allTendersTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moduleHeader() {
    final winRate = n(summary["total"]) == 0
        ? 0
        : pct(n(summary["won"]), n(summary["total"]));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe2e8f0)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 16)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xffeff6ff),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description, color: Color(0xff1e40af)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Tender Analytics",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    "Pipeline · outcomes · bid calendar",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ]),
              ),
              IconButton(
                onPressed: loading ? null : loadData,
                icon: const Icon(Icons.refresh, color: Color(0xff1e40af)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _headerStat("Total", fmtN(summary["total"]), const Color(0xff0f172a))),
            const SizedBox(width: 8),
            Expanded(child: _headerStat("Active", fmtN(summary["active"]), const Color(0xff0284c7))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _headerStat("Won", fmtN(summary["won"]), const Color(0xff059669))),
            const SizedBox(width: 8),
            Expanded(child: _headerStat("Win Rate", "$winRate%", const Color(0xff7c3aed))),
          ]),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffedf2f7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xff94a3b8))),
        const SizedBox(height: 5),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }

  Widget _filterBar() {
    final owners = filters["owners"] is List ? filters["owners"] as List : [];
    final statuses = filters["statuses"] is List ? filters["statuses"] as List : [];
    final results = filters["results"] is List ? filters["results"] as List : [];

    return _card(Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Expanded(child: _dateField("From", dateFrom, (v) => dateFrom = v)),
          const SizedBox(width: 10),
          Expanded(child: _dateField("To", dateTo, (v) => dateTo = v)),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: assignedTo,
          isExpanded: true,
          decoration: _input("Owner"),
          items: owners.map((o) {
            final id = "${o["id"]}";
            final name = "${o["name"] ?? id}";
            return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) => setState(() => assignedTo = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: status,
          isExpanded: true,
          decoration: _input("Status"),
          items: statuses.map((s) => DropdownMenuItem(value: "$s", child: Text("$s"))).toList(),
          onChanged: (v) => setState(() => status = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: result,
          isExpanded: true,
          decoration: _input("Result"),
          items: results.map((s) => DropdownMenuItem(value: "$s", child: Text("$s"))).toList(),
          onChanged: (v) => setState(() => result = v),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1e40af),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text("Apply"),
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
                  result = null;
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
    ));
  }

  Widget _dateField(String label, String? value, Function(String?) onChanged) {
    return TextFormField(
      initialValue: value,
      decoration: _input(label).copyWith(hintText: "YYYY-MM-DD"),
      onChanged: onChanged,
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xffe2e8f0)),
      ),
    );
  }

  Widget _alertBanner() {
    return _card(Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xfffffbeb),
            border: Border(bottom: BorderSide(color: Color(0xffffedd5))),
          ),
          child: Row(children: [
            const Icon(Icons.notifications_active, color: Color(0xffdc2626), size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text("Smart Alerts", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            _badge("${alerts.length} active", const Color(0xffdc2626)),
          ]),
        ),
        ...alerts.take(6).map((a) {
          final sev = "${a["severity"] ?? "low"}";
          final color = sev == "high"
              ? const Color(0xffdc2626)
              : sev == "medium"
              ? const Color(0xffd97706)
              : const Color(0xff0284c7);
          return ListTile(
            dense: true,
            leading: Icon(Icons.warning_amber_rounded, color: color),
            title: Text("${a["message"] ?? ""}",
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          );
        }),
      ],
    ));
  }

  Widget _financeKpis() {
    final avgBid = n(summary["total"]) == 0 ? 0 : n(summary["pipeline_value"]) / n(summary["total"]);

    final cards = [
      ["Won Value", fmtRs(summary["won_value"]), "Year to date", const Color(0xff059669), Icons.emoji_events],
      ["Pending Value", fmtRs(summary["pending_value"] ?? summary["pipeline_value"]), "Open pipeline", const Color(0xffd97706), Icons.hourglass_bottom],
      ["Avg Bid Value", fmtRs(avgBid), "Per tender", const Color(0xff0284c7), Icons.bar_chart],
      ["EMD Required", fmtN(summary["emd_required_count"]), "Tenders need EMD", const Color(0xff64748b), Icons.shield],
      ["EMD Value", fmtRs(summary["emd_total_value"]), "Total EMD at stake", const Color(0xff7c3aed), Icons.currency_rupee],
      ["Bids Due 7d", fmtN(summary["upcoming_bids"]), "${fmtN(summary["urgent_bids"])} urgent", const Color(0xffdc2626), Icons.calendar_today],
    ];

    return Column(
      children: cards.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _kpiCard(
            c[0] as String,
            c[1] as String,
            c[2] as String,
            c[3] as Color,
            c[4] as IconData,
          ),
        );
      }).toList(),
    );
  }

  Widget _kpiCard(String title, String value, String sub, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10)],
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color, size: 19)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
        ])),
      ]),
    );
  }

  Widget _stagePipeline() {
    final stages = charts["pipeline_stages"] is List
        ? List<Map<String, dynamic>>.from(charts["pipeline_stages"])
        : _derivePipelineStages();

    if (stages.isEmpty) return _empty("No pipeline data");

    final maxCount = stages.map((e) => n(e["count"])).reduce((a, b) => a > b ? a : b);
    final colors = {
      "Aligned": const Color(0xff6366f1),
      "Evaluation": const Color(0xff8b5cf6),
      "Pre-Bid": const Color(0xff0284c7),
      "Submitted": const Color(0xff0d9488),
      "Reverse Auction": const Color(0xffd97706),
      "Closed": const Color(0xff64748b),
    };

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHead("Stage Pipeline", "Tender flow · count · value · conversion"),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: stages.map((s) {
          final stage = "${s["stage"]}";
          final color = colors[stage] ?? const Color(0xff64748b);
          final count = n(s["count"]);
          final value = n(s["value"]);
          final conversion = n(s["conversion"]);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(stage, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(fmtN(count), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 7),
              LinearProgressIndicator(
                value: maxCount == 0 ? 0 : count / maxCount,
                minHeight: 10,
                backgroundColor: const Color(0xfff1f5f9),
                valueColor: AlwaysStoppedAnimation(color.withOpacity(.75)),
              ),
              const SizedBox(height: 5),
              Row(children: [
                Text(fmtRs(value), style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                const Spacer(),
                Text("${conversion.round()}%", style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
              ]),
            ]),
          );
        }).toList()),
      )
    ]));
  }

  List<Map<String, dynamic>> _derivePipelineStages() {
    final order = ["Aligned", "Evaluation", "Pre-Bid", "Submitted", "Reverse Auction", "Closed"];
    final m = <String, Map<String, dynamic>>{};
    for (final r in tableRows) {
      final st = "${r["status"] ?? r["tender_status"] ?? "Aligned"}";
      m.putIfAbsent(st, () => {"stage": st, "count": 0, "value": 0.0});
      m[st]!["count"]++;
      m[st]!["value"] += n(r["est_value"]);
    }
    return order.where((x) => m.containsKey(x)).map((x) => m[x]!).toList();
  }

  Widget _resultBreakdown() {
    final byResult = charts["by_result"] is List
        ? List<Map<String, dynamic>>.from(charts["by_result"])
        : _deriveByResult();

    final total = byResult.fold<num>(0, (s, e) => s + n(e["count"] ?? e["value"]));
    final colors = {
      "Won": const Color(0xff059669),
      "Lost": const Color(0xffdc2626),
      "Pending": const Color(0xffd97706),
      "Cancelled": const Color(0xff94a3b8),
    };

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHead("Tender Results", "Win / Loss / Pending breakdown"),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: byResult.map((r) {
          final name = "${r["name"] ?? r["result"] ?? "Pending"}";
          final value = n(r["count"] ?? r["value"]);
          final color = colors[name] ?? const Color(0xff64748b);
          return _progressRow(name, value, total, color);
        }).toList()),
      )
    ]));
  }

  List<Map<String, dynamic>> _deriveByResult() {
    final m = <String, int>{};
    for (final r in tableRows) {
      final k = "${r["result"] ?? "Pending"}";
      m[k] = (m[k] ?? 0) + 1;
    }
    return m.entries.map((e) => {"name": e.key, "count": e.value}).toList();
  }

  Widget _monthlyTrend() {
    final items = charts["monthly_trend"] is List
        ? List<Map<String, dynamic>>.from(charts["monthly_trend"])
        : [];

    final max = items.isEmpty ? 1 : items.map((e) => n(e["count"])).reduce((a, b) => a > b ? a : b);

    return _card(Container(
      height: 280,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Monthly Trend", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const Text("Tender count · won value · submitted value",
            style: TextStyle(fontSize: 11, color: Color(0xff64748b))),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: items.map((m) {
                final h = max == 0 ? 0.0 : (n(m["count"]) / max) * 170;
                return SizedBox(
                  width: 52,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(fmtRs(m["won_value"]), overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 8, color: Color(0xff059669))),
                    const SizedBox(height: 4),
                    Container(
                      height: h,
                      width: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xff1e40af).withOpacity(.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text("${m["month"]}", style: const TextStyle(fontSize: 10, color: Color(0xff64748b))),
                  ]),
                );
              }).toList(),
            ),
          ),
        )
      ]),
    ));
  }

  Widget _portalBars() {
    final portals = charts["by_portal"] is List
        ? List<Map<String, dynamic>>.from(charts["by_portal"])
        : _derivePortal();

    final max = portals.isEmpty ? 1 : portals.map((e) => n(e["value"])).reduce((a, b) => a > b ? a : b);

    return _card(Container(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("By Portal", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const Text("Tender count per source", style: TextStyle(fontSize: 11, color: Color(0xff64748b))),
        const SizedBox(height: 14),
        ...portals.take(8).map((p) {
          return _progressRow("${p["name"]}", n(p["value"]), max, const Color(0xff7c3aed));
        }),
      ]),
    ));
  }

  List<Map<String, dynamic>> _derivePortal() {
    final m = <String, int>{};
    for (final r in tableRows) {
      final p = "${r["portal"] ?? r["source_portal"] ?? "Direct"}";
      m[p] = (m[p] ?? 0) + 1;
    }
    return m.entries.map((e) => {"name": e.key, "value": e.value}).toList();
  }

  Widget _bidCalendar() {
    final source = calendar.isNotEmpty
        ? calendar
        : tableRows.where((r) => r["submission_date"] != null).toList();

    final now = DateTime.now();
    final upcoming = source.where((r) {
      final d = DateTime.tryParse("${r["submission_date"] ?? r["date"] ?? ""}");
      if (d == null) return false;
      final diff = d.difference(now).inDays;
      return diff >= 0 && diff <= 14;
    }).toList();

    return _card(Column(
      children: [
        _calendarGrid(source),
        const Divider(height: 1),
        _cardHead("Next 14 Days", "${upcoming.length} upcoming"),
        SizedBox(
          height: 240,
          child: upcoming.isEmpty
              ? const Center(child: Text("No upcoming bids"))
              : ListView.separated(
            itemCount: upcoming.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = upcoming[i];
              final d = DateTime.tryParse("${r["submission_date"] ?? r["date"]}");
              final diff = d == null ? 0 : d.difference(now).inDays;
              return ListTile(
                dense: true,
                title: Text("${r["title"] ?? r["tender_title"] ?? "#${r["id"]}"}",
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text("${r["customer"] ?? r["customer_name"] ?? ""}"),
                trailing: _daysBadge(diff),
              );
            },
          ),
        ),
      ],
    ));
  }

  Widget _calendarGrid(List<Map<String, dynamic>> events) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1).weekday % 7;
    final days = DateTime(now.year, now.month + 1, 0).day;

    bool hasEvent(int day) {
      return events.any((e) {
        final d = DateTime.tryParse("${e["submission_date"] ?? e["date"] ?? ""}");
        return d != null && d.year == now.year && d.month == now.month && d.day == day;
      });
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Text(DateFormat("MMMM yyyy").format(now), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ["S", "M", "T", "W", "T", "F", "S"]
              .map((e) => Text(e, style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8), fontWeight: FontWeight.w900)))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(firstDay + days, (i) {
            if (i < firstDay) return const SizedBox();
            final day = i - firstDay + 1;
            final today = day == now.day;
            final event = hasEvent(day);
            return Container(
              margin: const EdgeInsets.all(3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: today
                    ? const Color(0xff1e40af)
                    : event
                    ? const Color(0xffffedd5)
                    : const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("$day",
                  style: TextStyle(
                    color: today ? Colors.white : const Color(0xff334155),
                    fontWeight: event || today ? FontWeight.w900 : FontWeight.w500,
                  )),
            );
          }),
        )
      ]),
    );
  }

  Widget _portalTable() {
    final m = <String, Map<String, dynamic>>{};
    for (final r in tableRows) {
      final p = "${r["portal"] ?? r["source_portal"] ?? "Direct"}";
      m.putIfAbsent(p, () => {"total": 0, "won": 0, "lost": 0, "pending": 0, "bid": 0.0});
      m[p]!["total"]++;
      final res = "${r["result"] ?? ""}".toLowerCase();
      if (res == "won") m[p]!["won"]++;
      else if (res == "lost") m[p]!["lost"]++;
      else m[p]!["pending"]++;
      m[p]!["bid"] += n(r["bid_amount"]);
    }

    final rows = m.entries.toList()..sort((a, b) => b.value["total"].compareTo(a.value["total"]));

    return _card(SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xfff8fafc)),
        columns: const [
          DataColumn(label: Text("Portal")),
          DataColumn(label: Text("Total")),
          DataColumn(label: Text("Won")),
          DataColumn(label: Text("Lost")),
          DataColumn(label: Text("Pending")),
          DataColumn(label: Text("Win %")),
          DataColumn(label: Text("Total Bid")),
        ],
        rows: rows.map((e) {
          final v = e.value;
          return DataRow(cells: [
            DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800))),
            DataCell(Text(fmtN(v["total"]))),
            DataCell(Text(fmtN(v["won"]))),
            DataCell(Text(fmtN(v["lost"]))),
            DataCell(Text(fmtN(v["pending"]))),
            DataCell(_badge("${pct(n(v["won"]), n(v["total"]))}%", const Color(0xff059669))),
            DataCell(Text(fmtRs(v["bid"]))),
          ]);
        }).toList(),
      ),
    ));
  }

  Widget _topPerformers() {
    final highestEstimated = topLists["highest_estimated"] is List
        ? List<Map<String, dynamic>>.from(topLists["highest_estimated"])
        : <Map<String, dynamic>>[];
    final highestBid = topLists["highest_bid"] is List
        ? List<Map<String, dynamic>>.from(topLists["highest_bid"])
        : <Map<String, dynamic>>[];

    return Column(children: [
      _topList("Top by Estimated Value", highestEstimated, "value", const Color(0xff1e40af)),
      const SizedBox(height: 12),
      _topList("Top by Bid Amount", highestBid, "bid", const Color(0xff059669)),
      const SizedBox(height: 12),
      _topCustomers(),
      const SizedBox(height: 12),
      _topUsers(),
    ]);
  }

  Widget _topList(String title, List<Map<String, dynamic>> items, String valueKey, Color color) {
    return _card(Column(children: [
      _cardHead(title, "Ranked list"),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(24), child: Text("No data"))
      else
        ...List.generate(items.take(10).length, (i) {
          final r = items[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: i < 3 ? color : const Color(0xfff1f5f9),
              child: Text("${i + 1}", style: TextStyle(fontSize: 10, color: i < 3 ? Colors.white : const Color(0xff64748b))),
            ),
            title: Text("${r["title"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text("${r["customer"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(fmtRs(r[valueKey]), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          );
        }),
    ]));
  }

  Widget _topCustomers() {
    final customers = topLists["top_customers"] is List
        ? List<Map<String, dynamic>>.from(topLists["top_customers"])
        : <Map<String, dynamic>>[];

    return _card(Column(children: [
      _cardHead("Top Customers by Tender Value", "Estimated value · bid amount · count"),
      ...customers.take(8).map((c) => ListTile(
        dense: true,
        title: Text("${c["name"] ?? c["customer_name"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text("${fmtN(c["total"] ?? c["count"])} tenders · ${fmtN(c["won"])} won"),
        trailing: Text(fmtRs(c["est_value"] ?? c["value"]), style: const TextStyle(fontWeight: FontWeight.w900)),
      ))
    ]));
  }

  Widget _topUsers() {
    final users = topLists["top_users"] is List
        ? List<Map<String, dynamic>>.from(topLists["top_users"])
        : <Map<String, dynamic>>[];

    return _card(Column(children: [
      _cardHead("Top KAMs by Tender Performance", "Assigned tenders · won count · win rate"),
      ...users.take(8).map((u) {
        final wr = pct(n(u["won"]), n(u["total"]));
        return ListTile(
          dense: true,
          title: Text("${u["name"] ?? u["assigned_to_name"] ?? "—"}", maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("${fmtN(u["total"])} assigned · ${fmtN(u["won"])} won"),
          trailing: _badge("$wr%", wr >= 40 ? const Color(0xff059669) : const Color(0xffd97706)),
        );
      })
    ]));
  }

  Widget _allTendersTable() {
    return _card(SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xfff8fafc)),
        columns: const [
          DataColumn(label: Text("No.")),
          DataColumn(label: Text("Title")),
          DataColumn(label: Text("Customer")),
          DataColumn(label: Text("Portal")),
          DataColumn(label: Text("Status")),
          DataColumn(label: Text("Result")),
          DataColumn(label: Text("Est ₹")),
          DataColumn(label: Text("Bid ₹")),
          DataColumn(label: Text("Deadline")),
          DataColumn(label: Text("Days Left")),
          DataColumn(label: Text("KAM")),
        ],
        rows: tableRows.map((r) {
          final d = DateTime.tryParse("${r["submission_date"] ?? ""}");
          final diff = d == null ? null : d.difference(DateTime.now()).inDays;
          return DataRow(cells: [
            DataCell(Text("${r["num"] ?? "—"}")),
            DataCell(SizedBox(width: 220, child: Text("${r["title"] ?? "—"}", overflow: TextOverflow.ellipsis))),
            DataCell(Text("${r["customer"] ?? "—"}")),
            DataCell(_badge("${r["portal"] ?? ""}", const Color(0xff64748b))),
            DataCell(_badge("${r["status"] ?? ""}", const Color(0xff0284c7))),
            DataCell(_badge("${r["result"] ?? ""}", _resultColor("${r["result"] ?? ""}"))),
            DataCell(Text(fmtRs(r["est_value"]))),
            DataCell(Text(fmtRs(r["bid_amount"]))),
            DataCell(Text("${r["submission_date"] ?? "—"}")),
            DataCell(diff == null ? const Text("—") : _daysBadge(diff)),
            DataCell(Text("${r["assigned_to"] ?? "—"}")),
          ]);
        }).toList(),
      ),
    ));
  }

  Color _resultColor(String value) {
    if (value == "Won") return const Color(0xff059669);
    if (value == "Lost") return const Color(0xffdc2626);
    return const Color(0xffd97706);
  }

  Widget _daysBadge(int diff) {
    Color color;
    String label;
    if (diff < 0) {
      color = const Color(0xffdc2626);
      label = "${diff.abs()}d overdue";
    } else if (diff == 0) {
      color = const Color(0xffdc2626);
      label = "Due today";
    } else if (diff <= 3) {
      color = const Color(0xffdc2626);
      label = "${diff}d left";
    } else if (diff <= 7) {
      color = const Color(0xffd97706);
      label = "${diff}d left";
    } else {
      color = const Color(0xff64748b);
      label = "${diff}d left";
    }
    return _badge(label, color);
  }

  Widget _progressRow(String label, num value, num total, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 105, child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (value / total).clamp(0, 1),
            minHeight: 9,
            backgroundColor: const Color(0xfff1f5f9),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 58, child: Text(fmtN(value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
      ]),
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
        border: Border.all(color: const Color(0xffe2e8f0)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0d000000), blurRadius: 16, offset: Offset(0, 4))],
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

  Widget _section(String idx, String title, [String? desc]) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xffdbeafe), borderRadius: BorderRadius.circular(8)),
        child: Text(idx, style: const TextStyle(color: Color(0xff1e40af), fontSize: 11, fontWeight: FontWeight.w900)),
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

  Widget _empty(String text) {
    return _card(SizedBox(
      height: 160,
      child: Center(child: Text(text, style: const TextStyle(color: Color(0xff94a3b8)))),
    ));
  }
}