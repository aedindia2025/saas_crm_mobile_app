import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DashboardApi {
  static const String baseUrl = "http://103.110.236.187:3076/api/v1";

  static Future<Map<String, dynamic>> fetchOverview(String token) async {
    final url = "$baseUrl/dashboard";

    final res = await http.get(
      Uri.parse(url),
      headers: {
        'X-Tenant-Slug': 'ascent',
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    debugPrint("Dashboard URL: $url");
    debugPrint("Status: ${res.statusCode}");
    debugPrint("Body: ${res.body}");

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception("Dashboard API failed: ${res.statusCode}");
  }
}


class OverviewTab extends StatefulWidget {
  final String token;
  const OverviewTab({super.key, required this.token});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = DashboardApi.fetchOverview(widget.token);
  }

  void refresh() {
    setState(() {
      future = DashboardApi.fetchOverview(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xfff4f7fb),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xfff4f7fb),
            body: Center(child: Text("Dashboard loading failed")),
          );
        }

        final data = snap.data ?? {};
        final ov = data["overview"] ?? {};

        return Scaffold(
          backgroundColor: const Color(0xfff4f7fb),
          body: RefreshIndicator(
            onRefresh: () async => refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  _HeroHeader(overview: ov, onRefresh: refresh),
                  const SizedBox(height: 14),
                  _KpiGrid(overview: ov),
                  const SizedBox(height: 14),
                  _LeadTrendCard(data: data),
                  const SizedBox(height: 14),
                  _PipelineValueCard(overview: ov),
                  const SizedBox(height: 14),
                  _TenderOutcomeCard(data: data),
                  const SizedBox(height: 14),
                  _CalendarCard(overview: ov),
                  const SizedBox(height: 14),
                  _LeadStatusCard(data: data),
                  const SizedBox(height: 14),
                  _ActivityFeedCard(data: data),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

num n(dynamic v) => v == null ? 0 : num.tryParse(v.toString()) ?? 0;

String fmtN(dynamic v) => NumberFormat.decimalPattern('en_IN').format(n(v));

String fmtRs(dynamic v) {
  final value = n(v);
  if (value == 0) return "₹ 0";
  if (value >= 10000000) return "₹ ${(value / 10000000).toStringAsFixed(2)} Cr";
  if (value >= 100000) return "₹ ${(value / 100000).toStringAsFixed(2)} L";
  return "₹ ${NumberFormat.decimalPattern('en_IN').format(value.round())}";
}


class _HeroHeader extends StatelessWidget {
  final Map overview;
  final VoidCallback onRefresh;
  const _HeroHeader({required this.overview, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final tenderValue = n(overview["tender_value"]);
    final wonValue = n(overview["won_value"]);
    final winRate = tenderValue == 0 ? 0 : ((wonValue / tenderValue) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff102642), Color(0xff3b82f6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x263b82f6), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: "Good morning, ",
                          style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: "Admin.",
                          style: TextStyle(color: Color(0xffbfdbfe), fontSize: 19, fontWeight: FontWeight.w900),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: const TextStyle(color: Color(0xffdbeafe), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _HeroMetric("Tender Value", fmtRs(tenderValue))),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric("Won Value", fmtRs(wonValue))),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric("Win Rate", "$winRate%")),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label, value;
  const _HeroMetric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xffbfdbfe), fontSize: 9, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final Map overview;
  const _KpiGrid({required this.overview});

  @override
  Widget build(BuildContext context) {
    final leadCount = n(overview["lead_count"]) != 0 ? n(overview["lead_count"]) : n(overview["total_leads"]);
    final oppCount = n(overview["total_opportunities"]);
    final workOrders = n(overview["total_work_orders"]) != 0 ? n(overview["total_work_orders"]) : n(overview["active_work_orders"]);
    final emdbg = n(overview["total_emdbg"]) != 0 ? n(overview["total_emdbg"]) : n(overview["emdbg_count"]);

    final cards = [
      ["Leads", fmtN(leadCount), fmtRs(overview["lead_value"]), const Color(0xff1e40af), Icons.track_changes],
      ["Opportunities", fmtN(oppCount), fmtRs(overview["opportunity_value"]), const Color(0xff0d9488), Icons.trending_up],
      ["Tenders", fmtN(overview["total_tenders"]), fmtRs(overview["tender_value"]), const Color(0xff7c3aed), Icons.description],
      ["Work Orders", fmtN(workOrders), fmtRs(overview["work_order_value"]), const Color(0xffea580c), Icons.grid_view],
      ["Won", fmtN(overview["won_tenders"]), fmtRs(overview["won_value"]), const Color(0xff059669), Icons.check_circle],
      ["EMD / BG", fmtN(emdbg), fmtRs(overview["emdbg_value"]), const Color(0xff2563eb), Icons.shield],
      ["Customers", fmtN(overview["total_customers"]), fmtRs(overview["customer_value"]), const Color(0xffd97706), Icons.groups],
      ["Approvals", fmtN(overview["pending_approvals"]), "${fmtN(overview["total_approvals"])} total", const Color(0xffef4444), Icons.verified],
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: cards.map((c) {
        return _KpiCard(
          c[0] as String,
          c[1] as String,
          c[2] as String,
          c[3] as Color,
          c[4] as IconData,
        );
      }).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title, count, amount;
  final Color color;
  final IconData icon;

  const _KpiCard(this.title, this.count, this.amount, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 4)),
        gradient: LinearGradient(
          colors: [color.withOpacity(.08), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.center,
        ),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          const Spacer(),
          Text(
            count,
            style: const TextStyle(color: Color(0xff0f172a), fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            amount,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xff94a3b8), fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title, subtitle;
  final Color color;
  final IconData icon;
  final Widget child;
  final double height;

  const _Panel({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.child,
    this.height = 330,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Container(height: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              CircleAvatar(radius: 17, backgroundColor: color.withOpacity(.12), child: Icon(icon, size: 16, color: color)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xff0f172a))),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                ]),
              ),
            ]),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.all(14), child: child)),
        ],
      ),
    );
  }
}

class _LeadTrendCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LeadTrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = (data["monthly_trend"] as List? ?? []);
    final maxY = rows.isEmpty ? 10 : rows.map((e) => n(e["leads"])).reduce((a, b) => a > b ? a : b).toDouble().clamp(10, double.infinity);

    return _Panel(
      title: "Lead Trend",
      subtitle: "New leads per month",
      color: const Color(0xff1e40af),
      icon: Icons.show_chart,
      child: rows.isEmpty
          ? const Center(child: Text("No data yet"))
          : LineChart(LineChartData(
        minY: 0,
        maxY: maxY.toDouble(),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= rows.length) return const SizedBox();
            return Text("${rows[i]["month"]}", style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8)));
          })),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(rows.length, (i) => FlSpot(i.toDouble(), n(rows[i]["leads"]).toDouble())),
            color: const Color(0xff1e40af),
            barWidth: 2.4,
            isCurved: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: const Color(0xff1e40af).withOpacity(.10)),
          )
        ],
      )),
    );
  }
}

class _PipelineValueCard extends StatelessWidget {
  final Map overview;
  const _PipelineValueCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final values = [
      ["Leads", n(overview["lead_value"]), const Color(0xff2563eb)],
      ["Opportunities", n(overview["opportunity_value"]), const Color(0xff7c3aed)],
      ["Tenders", n(overview["tender_value"]), const Color(0xfff97316)],
      ["Won", n(overview["won_value"]), const Color(0xff059669)],
      ["EMD / BG", n(overview["emdbg_value"]), const Color(0xffdc2626)],
    ];

    final total = values.fold<num>(0, (s, e) => s + (e[1] as num));
    final highest = values.reduce((a, b) => (a[1] as num) > (b[1] as num) ? a : b);

    return _Panel(
      height: 360,
      title: "Pipeline Value",
      subtitle: "₹ distribution by stage",
      color: const Color(0xff7c3aed),
      icon: Icons.trending_up,
      child: Column(
        children: [
          Row(children: [
            _MiniInfo("Total", fmtRs(total)),
            const SizedBox(width: 8),
            _MiniInfo("Highest", highest[0] as String),
            const SizedBox(width: 8),
            _MiniInfo("Stages", "${values.length}"),
          ]),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: values.map((e) {
                final pct = total == 0 ? 1 : (((e[1] as num) / total) * 100).round().clamp(1, 100);
                return Expanded(flex: pct, child: Container(height: 24, color: e[2] as Color));
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (_, i) {
                final e = values[i];
                final p = total == 0 ? 0 : (((e[1] as num) / total) * 100).round();
                return Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: e[2] as Color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e[0] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    Text(fmtRs(e[1]), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Text("$p%", style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String a, b;
  const _MiniInfo(this.a, this.b);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffedf2f7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a, style: const TextStyle(fontSize: 10, color: Color(0xff64748b), fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(b, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xff0f172a), fontWeight: FontWeight.w900)),
      ]),
    ),
  );
}

class _TenderOutcomeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TenderOutcomeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = data["tender_by_result"] as List? ?? [];
    final maxY = rows.isEmpty ? 10 : rows.map((e) => n(e["count"])).reduce((a, b) => a > b ? a : b).toDouble().clamp(10, double.infinity);

    return _Panel(
      title: "Tender Outcomes",
      subtitle: "Win / Loss / Pending",
      color: const Color(0xff7c3aed),
      icon: Icons.description,
      child: rows.isEmpty
          ? const Center(child: Text("No tender data"))
          : BarChart(BarChartData(
        maxY: maxY.toDouble(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= rows.length) return const SizedBox();
            return Text("${rows[i]["result"]}", style: const TextStyle(fontSize: 10));
          })),
        ),
        barGroups: List.generate(rows.length, (i) {
          final result = "${rows[i]["result"]}";
          final color = result == "Won"
              ? const Color(0xff059669)
              : result == "Lost"
              ? const Color(0xffef4444)
              : const Color(0xffffd54f);
          return BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: n(rows[i]["count"]).toDouble(), color: color, width: 24)],
          );
        }),
      )),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final Map overview;
  const _CalendarCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final bids = overview["upcoming_bid_dates"] as List? ?? [];
    final urgent = bids.where((e) => e["priority"] == "urgent").length;
    final upcoming = bids.where((e) => e["priority"] != "urgent").length;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDay = DateTime(now.year, now.month, 1).weekday % 7;

    bool hasBid(int day) {
      return bids.any((b) {
        final d = DateTime.tryParse("${b["submission_date"]}");
        return d != null && d.year == now.year && d.month == now.month && d.day == day;
      });
    }

    return _Panel(
      height: 380,
      title: "Upcoming Bid Dates",
      subtitle: "Tender submission calendar",
      color: const Color(0xff2563eb),
      icon: Icons.event_note,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _SideCount("Urgent", "$urgent", "Due within 3 days", const Color(0xffdc2626))),
            const SizedBox(width: 10),
            Expanded(child: _SideCount("Upcoming", "$upcoming", "Next 30 days", const Color(0xffd97706))),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xfff8fafc), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Text(DateFormat('MMMM yyyy').format(now), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
                        .map((e) => Text(e, style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8), fontWeight: FontWeight.w900)))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 7,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(firstDay + daysInMonth, (i) {
                        if (i < firstDay) return const SizedBox();
                        final day = i - firstDay + 1;
                        final today = day == now.day;
                        final bid = hasBid(day);
                        return Center(
                          child: Container(
                            width: 34,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: today ? const Color(0xff2563eb) : bid ? const Color(0xfffff7ed) : null,
                              borderRadius: BorderRadius.circular(7),
                              border: bid && !today ? Border.all(color: const Color(0xffffedd5)) : null,
                            ),
                            child: Text(
                              "$day",
                              style: TextStyle(
                                color: today ? Colors.white : const Color(0xff334155),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideCount extends StatelessWidget {
  final String title, count, sub;
  final Color color;
  const _SideCount(this.title, this.count, this.sub, this.color);

  @override
  Widget build(BuildContext context) => Container(
    height: 86,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      const SizedBox(height: 6),
      Text(count, style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w900)),
      Text(sub, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10)),
    ]),
  );
}

class _LeadStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LeadStatusCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = data["lead_by_status"] as List? ?? [];
    final colors = [
      const Color(0xff0284c7),
      const Color(0xff059669),
      const Color(0xff6366f1),
      const Color(0xfff97316),
      const Color(0xffef4444),
    ];

    return _Panel(
      title: "Leads by Status",
      subtitle: "Pipeline composition",
      color: const Color(0xff6366f1),
      icon: Icons.track_changes,
      child: rows.isEmpty
          ? const Center(child: Text("No lead data"))
          : PieChart(PieChartData(
        centerSpaceRadius: 48,
        sectionsSpace: 3,
        sections: List.generate(rows.length, (i) {
          return PieChartSectionData(
            value: n(rows[i]["count"]).toDouble(),
            color: colors[i % colors.length],
            showTitle: false,
          );
        }),
      )),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActivityFeedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = data["recent_activity"] as List? ?? [];

    return _Panel(
      height: 380,
      title: "Activity Feed",
      subtitle: "Latest system events",
      color: const Color(0xff0d9488),
      icon: Icons.monitor_heart,
      child: items.isEmpty
          ? const Center(child: Text("No recent activity"))
          : ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 18, color: Color(0xffedf2f7)),
        itemBuilder: (_, i) {
          final item = items[i];
          final module = "${item["module"] ?? "SYS"}";
          final createdAt = DateTime.tryParse("${item["created_at"]}");
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xfff1f5f9), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  module.length > 4 ? module.substring(0, 4).toUpperCase() : module.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xff64748b)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${item["description"] ?? ""}", style: const TextStyle(fontSize: 12, color: Color(0xff334155), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(module, style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8))),
                ]),
              ),
              const SizedBox(width: 8),
              Text(
                createdAt == null ? "" : DateFormat('dd-MM, h:mm a').format(createdAt),
                style: const TextStyle(fontSize: 9, color: Color(0xff94a3b8), fontFamily: "monospace"),
              ),
            ],
          );
        },
      ),
    );
  }
}