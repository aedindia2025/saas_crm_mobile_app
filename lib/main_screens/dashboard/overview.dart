import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardApi {
  static const String baseUrl = "https://ascent.crm.azcentrix.com:4447/api/v1";

  static Future<Map<String, dynamic>> fetchOverview(String token, String tenantSlug) async {
    final url = "$baseUrl/dashboard";

    final res = await http.get(
      Uri.parse(url),
      headers: {
        'X-Tenant-Slug': tenantSlug,
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
  String? tenantSlug;

  @override
  void initState() {
    super.initState();
    future = _initAndFetch();
  }

  Future<Map<String, dynamic>> _initAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    tenantSlug = prefs.getString('tenant_slug') ?? '';
    return DashboardApi.fetchOverview(widget.token, tenantSlug!);
  }

  void refresh() {
    setState(() {
      if (tenantSlug != null) {
        future = DashboardApi.fetchOverview(widget.token, tenantSlug!);
      } else {
        future = _initAndFetch();
      }
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
    final winRate =
    tenderValue == 0 ? 0 : ((wonValue / tenderValue) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xff0f172a),
            Color(0xff1d4ed8),
            Color(0xff60a5fa),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2563eb).withOpacity(0.28),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Container(
              height: 135,
              width: 135,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: -45,
            child: Container(
              height: 115,
              width: 115,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "Good morning, ",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              TextSpan(
                                text: "Admin.",
                                style: TextStyle(
                                  color: Color(0xffdbeafe),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: Colors.white.withOpacity(0.78),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                DateFormat('EEEE, d MMMM yyyy')
                                    .format(DateTime.now()),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Material(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: onRefresh,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        "Tender Value",
                        fmtRs(tenderValue),
                        Icons.description_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetric(
                        "Won Value",
                        fmtRs(wonValue),
                        Icons.emoji_events_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetric(
                        "Win Rate",
                        "$winRate%",
                        Icons.trending_up_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _HeroMetric(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
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
    final leadCount = n(overview["lead_count"]) != 0
        ? n(overview["lead_count"])
        : n(overview["total_leads"]);

    final oppCount = n(overview["total_opportunities"]);

    final workOrders = n(overview["total_work_orders"]) != 0
        ? n(overview["total_work_orders"])
        : n(overview["active_work_orders"]);

    final emdbg = n(overview["total_emdbg"]) != 0
        ? n(overview["total_emdbg"])
        : n(overview["emdbg_count"]);

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

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final c = cards[index];

        return _ElegantKpiCard(
          title: c[0] as String,
          value: c[1] as String,
          subtitle: c[2] as String,
          color: c[3] as Color,
          icon: c[4] as IconData,
        );
      },
    );
  }
}

class _ElegantKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _ElegantKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.78),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Icon(
              icon,
              size: 96,
              color: Colors.white.withOpacity(0.10),
            ),
          ),

          Positioned(
            right: 14,
            top: 14,
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),

                const Spacer(),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
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

// REPLACE FROM: class _CalendarCard ... END OF _ActivityFeedCard

class _CalendarCard extends StatefulWidget {
  final Map overview;
  const _CalendarCard({required this.overview});

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  late DateTime calMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    calMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final bids = widget.overview["upcoming_bid_dates"] as List? ?? [];
    final bidDates = bids.map((b) {
      final d = DateTime.tryParse("${b["submission_date"]}");
      return {
        ...Map<String, dynamic>.from(b as Map),
        "dateObj": d,
        "urgent": b["priority"] == "urgent",
      };
    }).where((b) => b["dateObj"] != null).toList();

    final urgent = bidDates.where((b) => b["urgent"] == true).length;
    final normal = bidDates.where((b) => b["urgent"] != true).length;

    final year = calMonth.year;
    final month = calMonth.month;
    final today = DateTime.now();
    final firstDay = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    Map? bidForDay(int day) {
      for (final b in bidDates) {
        final d = b["dateObj"] as DateTime;
        if (d.year == year && d.month == month && d.day == day) return b;
      }
      return null;
    }

    void showBid(Map bid) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${bid["title"] ?? bid["tender_num"] ?? ""}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text("${bid["customer"] ?? ""}", style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
            const SizedBox(height: 14),
            _BidInfo("Tender No", bid["tender_num"]),
            _BidInfo("Submission", bid["submission_date"]),
            _BidInfo("Days Left", bid["days_left"]),
            _BidInfo("Est. Value", fmtRs(bid["est_value"])),
            _BidInfo("Portal", bid["portal"]),
            _BidInfo("Status", bid["status"]),
          ]),
        ),
      );
    }

    return _Panel(
      height: 410,
      title: "Upcoming Bid Dates",
      subtitle: "Tender submission calendar",
      color: const Color(0xff2563eb),
      icon: Icons.description,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xfff1f5f9)),
              ),
              child: Column(children: [
                Row(children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => calMonth = DateTime(year, month - 1, 1)),
                    icon: const Icon(Icons.chevron_left, size: 18, color: Color(0xff94a3b8)),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(calMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xff334155)),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => calMonth = DateTime(year, month + 1, 1)),
                    icon: const Icon(Icons.chevron_right, size: 18, color: Color(0xff94a3b8)),
                  ),
                ]),
                Row(
                  children: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                      .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xff94a3b8))))))
                      .toList(),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 7,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: List.generate(firstDay + daysInMonth, (i) {
                      if (i < firstDay) return const SizedBox();
                      final day = i - firstDay + 1;
                      final isToday = today.year == year && today.month == month && today.day == day;
                      final bid = bidForDay(day);
                      final urgentBid = bid?["urgent"] == true;

                      return InkWell(
                        onTap: bid == null ? null : () => showBid(bid),
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(alignment: Alignment.center, children: [
                          Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? const Color(0xff2563eb)
                                  : bid == null
                                  ? null
                                  : urgentBid
                                  ? const Color(0xfffff1f2)
                                  : const Color(0xfffffbeb),
                              borderRadius: BorderRadius.circular(7),
                              border: bid == null || isToday
                                  ? null
                                  : Border.all(color: urgentBid ? const Color(0xfffecdd3) : const Color(0xfffde68a)),
                            ),
                            child: Text(
                              "$day",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? Colors.white
                                    : urgentBid
                                    ? const Color(0xffb91c1c)
                                    : bid != null
                                    ? const Color(0xffb45309)
                                    : const Color(0xff334155),
                              ),
                            ),
                          ),
                          if (bid != null)
                            Positioned(
                              bottom: 3,
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: isToday ? Colors.white : urgentBid ? const Color(0xffef4444) : const Color(0xfff59e0b),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ]),
                      );
                    }),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 118,
            child: Column(children: [
              Expanded(child: _SideCount("Urgent", fmtN(urgent), "Due within 3 days", const Color(0xffdc2626))),
              const SizedBox(height: 10),
              Expanded(child: _SideCount("Upcoming", fmtN(normal), "Next 30 days", const Color(0xffd97706))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _BidInfo extends StatelessWidget {
  final String k;
  final dynamic v;
  const _BidInfo(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(k, style: const TextStyle(fontSize: 12, color: Color(0xff64748b)))),
      Flexible(child: Text("${v ?? "—"}", textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
    ]),
  );
}

class _LeadStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LeadStatusCard({required this.data});

  Color _statusColor(String s, int i) {
    const fallback = [
      Color(0xff1e40af), Color(0xff7c3aed), Color(0xffea580c),
      Color(0xff059669), Color(0xffdc2626), Color(0xff0d9488),
    ];
    switch (s) {
      case "Assigned": return const Color(0xff6366f1);
      case "Qualified": return const Color(0xff4338ca);
      case "Opportunity Created": return const Color(0xff0284c7);
      case "Converted":
      case "Won": return const Color(0xff059669);
      case "Lost": return const Color(0xffdc2626);
      case "Pending": return const Color(0xffd97706);
      default: return fallback[i % fallback.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = data["lead_by_status"] as List? ?? [];

    return _Panel(
      title: "Leads by Status",
      subtitle: "Pipeline composition",
      color: const Color(0xff6366f1),
      icon: Icons.track_changes,
      child: rows.isEmpty
          ? const Center(child: Text("No lead data"))
          : Column(children: [
        Expanded(
          child: PieChart(PieChartData(
            centerSpaceRadius: 52,
            sectionsSpace: 2,
            sections: List.generate(rows.length, (i) {
              final status = "${rows[i]["status"]}";
              return PieChartSectionData(
                value: n(rows[i]["count"]).toDouble(),
                color: _statusColor(status, i),
                showTitle: false,
                radius: 46,
              );
            }),
          )),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 7,
          children: List.generate(rows.length, (i) {
            final status = "${rows[i]["status"]}";
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _statusColor(status, i), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 5),
              Text(status, style: const TextStyle(fontSize: 10, color: Color(0xff64748b), fontWeight: FontWeight.w700)),
            ]);
          }),
        ),
      ]),
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
      subtitle: "Recent system activity",
      color: const Color(0xff0d9488),
      icon: Icons.monitor_heart,
      child: items.isEmpty
          ? const Center(child: Text("No recent activity"))
          : ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xfff1f5f9)),
        itemBuilder: (_, i) {
          final a = items[i];
          final module = "${a["module"] ?? "SYS"}";
          final mod = module.toLowerCase();
          final bg = mod.contains("tender")
              ? const Color(0xfff5f3ff)
              : mod.contains("lead")
              ? const Color(0xfff0f9ff)
              : mod.contains("emd")
              ? const Color(0xfffff1f2)
              : mod.contains("cust")
              ? const Color(0xffecfdf5)
              : const Color(0xfff8fafc);
          final fg = mod.contains("tender")
              ? const Color(0xff6d28d9)
              : mod.contains("lead")
              ? const Color(0xff0369a1)
              : mod.contains("emd")
              ? const Color(0xffb91c1c)
              : mod.contains("cust")
              ? const Color(0xff047857)
              : const Color(0xff64748b);
          final label = module.length > 4 ? module.substring(0, 4).toUpperCase() : module.toUpperCase();
          final dt = DateTime.tryParse("${a["created_at"]}");

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
                child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg, letterSpacing: .5)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${a["description"] ?? ""}", style: const TextStyle(fontSize: 12, color: Color(0xff334155), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(module, style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8), fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(
                dt == null ? "" : DateFormat('dd MMM\nh:mm a').format(dt),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9, color: Color(0xff94a3b8), fontFamily: "monospace"),
              ),
            ]),
          );
        },
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
