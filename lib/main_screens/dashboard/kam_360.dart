import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KAM360Tab extends StatefulWidget {
  final String token;
  const KAM360Tab({super.key, required this.token});

  @override
  State<KAM360Tab> createState() => _KAM360TabState();
}

class _KAM360TabState extends State<KAM360Tab> {
  static const baseUrl = "https://ascent.crm.azcentrix.com:4447/api/v1";

  bool loading = true;
  Map<String, dynamic>? data;
  String? tenantSlug;

  String? dateFrom;
  String? dateTo;
  String? group;

  int? expandedKamId;
  int? loadingCustomerId;
  final Map<int, List<Map<String, dynamic>>> customerCache = {};

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

  int score(Map<String, dynamic> k) {
    final custRate = n(k["customers_total"]) == 0 ? 0 : pct(n(k["customers_active"]), n(k["customers_total"]));
    final convRate = n(k["leads_total"]) == 0 ? 0 : pct(n(k["leads_converted"]), n(k["leads_total"]));
    final winRate = n(k["tenders_total"]) == 0 ? 0 : pct(n(k["tenders_won"]), n(k["tenders_total"]));
    final overdue = n(k["leads_total"]) == 0 ? 100 : 100 - pct(n(k["leads_overdue"]), n(k["leads_total"]));
    return (custRate * .2 + convRate * .35 + winRate * .3 + overdue * .15).round();
  }

  Map<String, String> get queryParams {
    final p = <String, String>{};
    if (dateFrom?.isNotEmpty == true) p["date_from"] = dateFrom!;
    if (dateTo?.isNotEmpty == true) p["date_to"] = dateTo!;
    if (group?.isNotEmpty == true) p["group"] = group!;
    return p;
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    try {
      final uri = Uri.parse("$baseUrl/dashboard/tab/kam360")
          .replace(queryParameters: queryParams);

      final res = await http.get(uri, headers: {
        'X-Tenant-Slug': tenantSlug ?? '',
        "Authorization": "Bearer ${widget.token}",
        "Accept": "application/json",
      });

      if (res.statusCode == 200) {
        data = jsonDecode(res.body);
      } else if (res.statusCode == 404) {
        final fallback = Uri.parse("$baseUrl/kam/team-360").replace(
          queryParameters: dateFrom == null ? {} : {"period": dateFrom!.substring(0, 7)},
        );

        final fallbackRes = await http.get(fallback, headers: {
          'X-Tenant-Slug': tenantSlug ?? '',
          "Authorization": "Bearer ${widget.token}",
          "Accept": "application/json",
        });

        data = fallbackRes.statusCode == 200
            ? _fromKamTeam360(jsonDecode(fallbackRes.body))
            : null;
      } else {
        data = null;
      }
    } catch (_) {
      data = null;
    }

    setState(() => loading = false);
  }

  Map<String, dynamic> _fromKamTeam360(Map payload) {
    final members = payload["members"] is List ? payload["members"] as List : [];

    final kams = members.where((m) {
      final role = "${m["role"] ?? ""}".toLowerCase();
      return role != "admin" && role != "ceo";
    }).map((m) {
      final row = {
        "id": n(m["user_id"]).toInt(),
        "name": m["user_name"] ?? m["full_name"] ?? "Unassigned",
        "group": m["group_name"] ?? "${m["group_id"] ?? "Unassigned"}",
        "region": "",
        "customers_total": n(m["customers"]),
        "customers_active": n(m["customers"]),
        "leads_total": n(m["lead_count"]),
        "leads_converted": 0,
        "leads_lost": 0,
        "leads_overdue": 0,
        "leads_pipeline": n(m["lead_value"]),
        "tenders_total": n(m["tender_count"]),
        "tenders_won": n(m["won_tender_count"]),
        "tenders_bid_value": n(m["tender_value"]),
        "travel_total": n(m["total"]),
        "emdbg_active": 0,
        "sales_target": n(m["sales_target"]),
        "won_tender_value": n(m["won_tender_value"]),
        "customers_with_win": n(m["customers_with_win"]),
        "customers_pending": n(m["customers_pending"]),
      };
      row["score"] = score(Map<String, dynamic>.from(row));
      return row;
    }).toList();

    final groups = _deriveGroups(kams.cast<Map<String, dynamic>>());

    return {
      "summary": {
        "total_kams": kams.length,
        "groups": groups.length,
        "total_leads": kams.fold<num>(0, (s, k) => s + n(k["leads_total"])),
        "total_tenders": kams.fold<num>(0, (s, k) => s + n(k["tenders_total"])),
      },
      "kams": kams,
      "groups": groups,
      "charts": {},
      "filters": {
        "groups": groups.map((g) => g["name"]).toList(),
        "owners": kams.map((k) => {"id": k["id"], "name": k["name"]}).toList(),
      }
    };
  }

  Map<String, dynamic> get summary => Map<String, dynamic>.from(data?["summary"] ?? {});
  Map<String, dynamic> get filters => Map<String, dynamic>.from(data?["filters"] ?? {});
  Map<String, dynamic> get charts => Map<String, dynamic>.from(data?["charts"] ?? {});

  List<Map<String, dynamic>> get kams {
    final list = data?["kams"];
    if (list is List) return list.map((e) => Map<String, dynamic>.from(e)).toList();
    return [];
  }

  List<Map<String, dynamic>> get groups {
    final list = data?["groups"];
    if (list is List) return list.map((e) => Map<String, dynamic>.from(e)).toList();
    return _deriveGroups(kams);
  }

  List<Map<String, dynamic>> _deriveGroups(List<Map<String, dynamic>> source) {
    final m = <String, Map<String, dynamic>>{};

    for (final k in source) {
      final name = "${k["group"] ?? "Unassigned"}";

      m.putIfAbsent(name, () => {
        "name": name,
        "members": 0,
        "customers_total": 0,
        "customers_active": 0,
        "leads_total": 0,
        "leads_converted": 0,
        "tenders_total": 0,
        "tenders_won": 0,
        "pipeline": 0.0,
      });

      m[name]!["members"]++;
      m[name]!["customers_total"] += n(k["customers_total"]);
      m[name]!["customers_active"] += n(k["customers_active"]);
      m[name]!["leads_total"] += n(k["leads_total"]);
      m[name]!["leads_converted"] += n(k["leads_converted"]);
      m[name]!["tenders_total"] += n(k["tenders_total"]);
      m[name]!["tenders_won"] += n(k["tenders_won"]);
      m[name]!["pipeline"] += n(k["leads_pipeline"]);
    }

    final list = m.values.toList();
    list.sort((a, b) => n(b["pipeline"]).compareTo(n(a["pipeline"])));
    return list;
  }

  Future<void> toggleKamCustomers(int kamId) async {
    if (expandedKamId == kamId) {
      setState(() => expandedKamId = null);
      return;
    }

    setState(() {
      expandedKamId = kamId;
      loadingCustomerId = kamId;
    });

    if (customerCache.containsKey(kamId)) {
      setState(() => loadingCustomerId = null);
      return;
    }

    try {
      final uri = Uri.parse("$baseUrl/kam/plan-customers")
          .replace(queryParameters: {"user_id": "$kamId", "own_only": "true"});

      final res = await http.get(uri, headers: {
        'X-Tenant-Slug': tenantSlug ?? '',
        "Authorization": "Bearer ${widget.token}",
        "Accept": "application/json",
      });

      if (res.statusCode == 200) {
        final parsed = jsonDecode(res.body);
        final list = parsed is List ? parsed : [];
        customerCache[kamId] = list.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        customerCache[kamId] = [];
      }
    } catch (_) {
      customerCache[kamId] = [];
    }

    setState(() => loadingCustomerId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) {
      return const Scaffold(
        backgroundColor: Color(0xfff5f7fb),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalKams = n(summary["total_kams"]) != 0 ? n(summary["total_kams"]) : kams.length;
    final totalPipeline = kams.fold<num>(0, (s, k) => s + n(k["leads_pipeline"]));
    final totalTarget = n(summary["total_sales_target"]) != 0
        ? n(summary["total_sales_target"])
        : kams.fold<num>(0, (s, k) => s + n(k["sales_target"]));
    final totalWon = n(summary["total_won_value"]) != 0
        ? n(summary["total_won_value"])
        : kams.fold<num>(0, (s, k) => s + n(k["won_tender_value"]));
    final customersWon = n(summary["total_customers_with_win"]) != 0
        ? n(summary["total_customers_with_win"])
        : kams.fold<num>(0, (s, k) => s + n(k["customers_with_win"]));
    final teamAch = totalTarget > 0 ? pct(totalWon, totalTarget) : 0;

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
              _header(totalKams, totalWon, totalTarget, teamAch),
              const SizedBox(height: 14),
              _filterBar(),
              const SizedBox(height: 18),

              _section("01", "Team Overview"),
              const SizedBox(height: 10),
              _kpi("Team Achievement", totalTarget > 0 ? "$teamAch%" : "—",
                  totalTarget > 0 ? "${fmtRs(totalWon)} of ${fmtRs(totalTarget)}" : "No targets set",
                  Icons.trending_up, _achievementColor(teamAch)),
              const SizedBox(height: 10),
              _kpi("Won Value", fmtRs(totalWon), "Tender wins this period",
                  Icons.emoji_events, const Color(0xff059669)),
              const SizedBox(height: 10),
              _kpi("Customers Won", fmtN(customersWon), "Customers with wins",
                  Icons.groups, const Color(0xff0284c7)),
              const SizedBox(height: 10),
              _kpi("Active Pipeline", fmtRs(totalPipeline), "Estimated lead value",
                  Icons.timeline, const Color(0xff4338ca)),

              if (groups.isNotEmpty) ...[
                const SizedBox(height: 18),
                _section("02", "Group Performance", "${groups.length} groups"),
                const SizedBox(height: 10),
                _groupCards(),
                const SizedBox(height: 12),
                _groupComparisonTable(),
              ],

              const SizedBox(height: 18),
              _section("03", "KAM Scorecard", "Tap row to expand customer detail"),
              const SizedBox(height: 10),
              _kamScorecardTable(),

              const SizedBox(height: 18),
              _section("04", "Leaderboard", "Top performers by category"),
              const SizedBox(height: 10),
              _leaderboard(),

              const SizedBox(height: 18),
              _section("05", "Target Achievement", "Won value vs target"),
              const SizedBox(height: 10),
              _targetAchievementBars(),

              const SizedBox(height: 18),
              _section("06", "Sales Performance"),
              const SizedBox(height: 10),
              _targetVsWonChart(),
              const SizedBox(height: 12),
              _salesPerformanceTable(),

              const SizedBox(height: 18),
              _section("07", "Performance Charts"),
              const SizedBox(height: 10),
              _groupPerformanceChart(),

              if (kams.any((k) => n(k["leads_overdue"]) > 0)) ...[
                const SizedBox(height: 18),
                _overdueAlertStrip(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(num totalKams, num totalWon, num target, num ach) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff020617), Color(0xff1e293b), Color(0xff4338ca)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.explore, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("KAM 360°",
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text("Cross-module performance view",
                    style: TextStyle(color: Color(0xffcbd5e1), fontSize: 12)),
              ]),
            ),
            IconButton(
              onPressed: loading ? null : loadData,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _headStat("KAMs", fmtN(totalKams))),
            const SizedBox(width: 8),
            Expanded(child: _headStat("Won Value", fmtRs(totalWon))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _headStat("Target", fmtRs(target))),
            const SizedBox(width: 8),
            Expanded(child: _headStat("Achieved", target > 0 ? "$ach%" : "—")),
          ]),
        ],
      ),
    );
  }

  Widget _headStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xffbfdbfe))),
        const SizedBox(height: 6),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
      ]),
    );
  }

  Widget _filterBar() {
    final groupOptions = filters["groups"] is List ? filters["groups"] as List : [];

    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Expanded(child: _dateField("From", dateFrom, (v) => dateFrom = v)),
            const SizedBox(width: 10),
            Expanded(child: _dateField("To", dateTo, (v) => dateTo = v)),
          ]),
          if (groupOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: group,
              isExpanded: true,
              decoration: _input("Group"),
              items: groupOptions
                  .map((g) => DropdownMenuItem(value: "$g", child: Text("$g", overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => group = v),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4338ca),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    group = null;
                  });
                  loadData();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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

  Widget _kpi(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0d000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Row(children: [
        CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
        ])),
      ]),
    );
  }

  Widget _groupCards() {
    return Column(
      children: groups.take(4).map((g) {
        final rank = groups.indexOf(g) + 1;
        final convRate = n(g["leads_total"]) == 0 ? 0 : pct(n(g["leads_converted"]), n(g["leads_total"]));
        final winRate = n(g["tenders_total"]) == 0 ? 0 : pct(n(g["tenders_won"]), n(g["tenders_total"]));

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xffeef2ff),
                    child: Text("#$rank",
                        style: const TextStyle(color: Color(0xff4338ca), fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("${g["name"]}", maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text("${fmtN(g["members"])} members",
                        style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                  ])),
                  Text(fmtRs(g["pipeline"]),
                      style: const TextStyle(color: Color(0xff4338ca), fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _miniCell("Customers", fmtN(g["customers_total"]), "${pct(n(g["customers_active"]), n(g["customers_total"]))}%"),
                  _miniCell("Leads", fmtN(g["leads_total"]), "$convRate%"),
                  _miniCell("Tenders", fmtN(g["tenders_total"]), "$winRate%"),
                  _miniCell("Won", fmtN(g["tenders_won"]), "won"),
                ]),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _leaderboard() {
    final topConv = [...kams]..sort((a, b) => n(b["leads_converted"]).compareTo(n(a["leads_converted"])));
    final topWon = [...kams]..sort((a, b) => n(b["won_tender_value"]).compareTo(n(a["won_tender_value"])));
    final topCust = [...kams]..sort((a, b) => n(b["customers_with_win"]).compareTo(n(a["customers_with_win"])));
    final topAch = [...kams].where((k) => n(k["sales_target"]) > 0).toList()
      ..sort((a, b) => (n(b["won_tender_value"]) / n(b["sales_target"]))
          .compareTo(n(a["won_tender_value"]) / n(a["sales_target"])));

    return Column(children: [
      _leaderCard("Top converters", Icons.trending_up, topConv.take(3).toList(),
              (k) => "${fmtN(k["leads_converted"])} conv", const Color(0xff059669)),
      const SizedBox(height: 10),
      _leaderCard("Top won value", Icons.emoji_events, topWon.take(3).toList(),
              (k) => fmtRs(k["won_tender_value"]), const Color(0xff4338ca)),
      const SizedBox(height: 10),
      _leaderCard("Customers won", Icons.groups, topCust.take(3).toList(),
              (k) => "${fmtN(k["customers_with_win"])} cust", const Color(0xff0284c7)),
      const SizedBox(height: 10),
      _leaderCard("Target achievers", Icons.star, topAch.take(3).toList(),
              (k) => "${pct(n(k["won_tender_value"]), n(k["sales_target"]))}% of target", const Color(0xffd97706)),
    ]);
  }

  Widget _progressRow(String label, num value, num total, Color color, {String? extra}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtN(value),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff4338ca),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: total == 0 ? 0 : (value / total).clamp(0, 1),
            minHeight: 9,
            backgroundColor: const Color(0xfff1f5f9),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          if (extra != null) ...[
            const SizedBox(height: 5),
            Text(
              extra,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xff64748b),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartBox(String title, String sub, Widget child) {
    return _card(Container(
      height: 300,
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
        const SizedBox(height: 14),
        Expanded(child: child),
      ]),
    ));
  }

  Widget _section(String idx, String title, [String? desc]) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xffeef2ff), borderRadius: BorderRadius.circular(9)),
        child: Text(idx,
            style: const TextStyle(color: Color(0xff4338ca), fontSize: 11, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        if (desc != null) ...[
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xff64748b))),
        ],
      ])),
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

  Color _achievementColor(num v) {
    if (v >= 100) return const Color(0xff059669);
    if (v >= 60) return const Color(0xff0284c7);
    if (v >= 30) return const Color(0xffd97706);
    return const Color(0xffdc2626);
  }


  Widget _miniCell(String label, String value, String sub) {
    return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Color(0xff94a3b8), fontWeight: FontWeight.w900)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xff64748b))),
    ]));
  }

  Widget _groupComparisonTable() {
    return _card(Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: groups.map((g) {
          final conv = pct(n(g["leads_converted"]), n(g["leads_total"]));
          final win = pct(n(g["tenders_won"]), n(g["tenders_total"]));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffe2e8f0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(
                  backgroundColor: Color(0xffeef2ff),
                  child: Icon(Icons.groups_2, color: Color(0xff4338ca), size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("${g["name"]}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ),
                Text(fmtRs(g["pipeline"]),
                    style: const TextStyle(color: Color(0xff4338ca), fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniInfo("Members", fmtN(g["members"])),
                  _miniInfo("Customers", fmtN(g["customers_total"])),
                  _miniInfo("Active Cust", fmtN(g["customers_active"])),
                  _miniInfo("Leads", fmtN(g["leads_total"])),
                  _miniInfo("Converted", fmtN(g["leads_converted"])),
                  _miniInfo("Conv %", "$conv%"),
                  _miniInfo("Tenders", fmtN(g["tenders_total"])),
                  _miniInfo("Won", fmtN(g["tenders_won"])),
                  _miniInfo("Win %", "$win%"),
                ],
              ),
            ]),
          );
        }).toList(),
      ),
    ));
  }

// REPLACE _kamScorecardTable()
  Widget _kamScorecardTable() {
    final sorted = [...kams]..sort((a, b) {
      final bs = n(b["score"] ?? score(b));
      final as = n(a["score"] ?? score(a));
      return bs.compareTo(as);
    });

    return _card(Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: sorted.map((k) {
          final kamId = n(k["id"]).toInt();
          final isExpanded = expandedKamId == kamId;
          final s = n(k["score"] ?? score(k)).toInt();
          final color = s >= 70
              ? const Color(0xff059669)
              : s >= 45
              ? const Color(0xffd97706)
              : const Color(0xffdc2626);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isExpanded ? const Color(0xffeef2ff) : const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isExpanded ? const Color(0xffc7d2fe) : const Color(0xffe2e8f0),
              ),
            ),
            child: Column(children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => toggleKamCustomers(kamId),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xff4338ca),
                        child: Text(
                          "${k["name"] ?? "?"}".substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("${k["name"] ?? "—"}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text("${k["group"] ?? "—"}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                        ]),
                      ),
                      _badge("Score $s", color),
                      const SizedBox(width: 4),
                      Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: const Color(0xff64748b)),
                    ]),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (s / 100).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: const Color(0xffe2e8f0),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _miniInfo("Customers", fmtN(k["customers_total"])),
                        _miniInfo("Active", fmtN(k["customers_active"])),
                        _miniInfo("Leads", fmtN(k["leads_total"])),
                        _miniInfo("Converted", fmtN(k["leads_converted"])),
                        _miniInfo("Lost", fmtN(k["leads_lost"])),
                        _miniInfo("Pipeline", fmtRs(k["leads_pipeline"])),
                        _miniInfo("Tenders", fmtN(k["tenders_total"])),
                        _miniInfo("Won", fmtN(k["tenders_won"])),
                        _miniInfo("Travel", fmtN(k["travel_total"])),
                        _miniInfo("EMD/BG", fmtN(k["emdbg_active"])),
                        _miniInfo("Target", n(k["sales_target"]) > 0 ? fmtRs(k["sales_target"]) : "—"),
                        _miniInfo("Won ₹", n(k["won_tender_value"]) > 0 ? fmtRs(k["won_tender_value"]) : "—"),
                      ],
                    ),
                  ]),
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1, color: Color(0xffc7d2fe)),
                _customerDetail(k),
              ],
            ]),
          );
        }).toList(),
      ),
    ));
  }

// REPLACE _customerDetail()
  Widget _customerDetail(Map<String, dynamic> kam) {
    final id = n(kam["id"]).toInt();

    if (loadingCustomerId == id) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text("Loading customers…"),
        ]),
      );
    }

    final customers = customerCache[id] ?? [];

    if (customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("No customers found", style: TextStyle(color: Color(0xff94a3b8))),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: customers.map((c) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffe2e8f0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${c["customer_name"] ?? "—"}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text("${c["vertical"] ?? "—"}",
                  style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniInfo("Lead ₹", n(c["lead_value"]) > 0 ? fmtRs(c["lead_value"]) : "—"),
                  _miniInfo("Tender ₹", n(c["tender_value"]) > 0 ? fmtRs(c["tender_value"]) : "—"),
                  _miniInfo("Won ₹", n(c["won_value"]) > 0 ? fmtRs(c["won_value"]) : "—"),
                ],
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _scoreBar(int score) {
    final color = score >= 70
        ? const Color(0xff059669)
        : score >= 45
        ? const Color(0xffd97706)
        : const Color(0xffdc2626);

    return SizedBox(
      width: 90,
      child: Row(children: [
        Expanded(
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 7,
            backgroundColor: const Color(0xfff1f5f9),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 7),
        Text("$score", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      ]),
    );
  }


  Widget _leaderCard(String title, IconData icon, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) metric, Color color) {
    return _card(Column(children: [
      _cardHead(title, "Top performers"),
      ...List.generate(items.length, (i) {
        final k = items[i];
        return ListTile(
          dense: true,
          leading: Text(i == 0 ? "🥇" : i == 1 ? "🥈" : "🥉"),
          title: Text("${k["name"]}", maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("${k["group"]}", maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(metric(k), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        );
      }),
    ]));
  }

  Widget _targetAchievementBars() {
    final list = [...kams].where((k) => n(k["sales_target"]) > 0).toList()
      ..sort((a, b) => (n(b["won_tender_value"]) / n(b["sales_target"])).compareTo(n(a["won_tender_value"]) / n(a["sales_target"])));

    return _card(Column(children: [
      _cardHead("Target achievement", "${list.length} KAMs with targets set"),
      ...list.map((k) {
        final ach = pct(n(k["won_tender_value"]), n(k["sales_target"]));
        final color = _achievementColor(ach);
        return ListTile(
          leading: CircleAvatar(child: Text("${k["name"]}".substring(0, 1).toUpperCase())),
          title: Text("${k["name"]}", maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: LinearProgressIndicator(
            value: (ach / 100).clamp(0, 1),
            minHeight: 7,
            backgroundColor: const Color(0xfff1f5f9),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          trailing: SizedBox(
            width: 180,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("$ach%", style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              Text("${fmtRs(k["won_tender_value"])} of ${fmtRs(k["sales_target"])}", style: const TextStyle(fontSize: 10, color: Color(0xff64748b))),
            ]),
          ),
        );
      })
    ]));
  }

  Widget _targetVsWonChart() {
    final list = [...kams].where((k) => n(k["sales_target"]) > 0 || n(k["won_tender_value"]) > 0).toList()
      ..sort((a, b) => n(b["won_tender_value"]).compareTo(n(a["won_tender_value"])));

    final max = list.isEmpty ? 1 : list.take(12).map((k) => n(k["sales_target"]) > n(k["won_tender_value"]) ? n(k["sales_target"]) : n(k["won_tender_value"])).reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "Target vs Won",
      "Per KAM · sorted by won value",
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: list.take(12).map((k) {
        final targetH = max == 0 ? 0.0 : (n(k["sales_target"]) / max) * 190;
        final wonH = max == 0 ? 0.0 : (n(k["won_tender_value"]) / max) * 190;
        return Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 10, height: targetH, color: const Color(0xff6366f1).withOpacity(.5)),
              const SizedBox(width: 3),
              Container(width: 10, height: wonH, color: const Color(0xff10b981)),
            ]),
            const SizedBox(height: 6),
            Text("${k["name"]}".length > 8 ? "${k["name"]}".substring(0, 8) : "${k["name"]}", style: const TextStyle(fontSize: 9)),
          ]),
        );
      }).toList()),
    );
  }

  Widget _salesPerformanceTable() {
    return _kamScorecardTable();
  }


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
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xff94a3b8),
              )),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _groupPerformanceChart() {
    final list = groups.take(8).toList();
    final max = list.isEmpty
        ? 1
        : list.map((g) => n(g["leads_total"])).reduce((a, b) => a > b ? a : b);

    return _chartBox(
      "Group lead performance",
      "Total leads vs conversions",
      ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final g = list[i];

          return _progressRow(
            "${g["name"]}",
            n(g["leads_total"]),
            max,
            const Color(0xff4338ca),
            extra: "Converted ${fmtN(g["leads_converted"])} · Won ${fmtN(g["tenders_won"])}",
          );
        },
      ),
    );
  }

  Widget _overdueAlertStrip() {
    final list = [...kams].where((k) => n(k["leads_overdue"]) > 0).toList()
      ..sort((a, b) => n(b["leads_overdue"]).compareTo(n(a["leads_overdue"])));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffffe3a3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xffd97706)),
          SizedBox(width: 8),
          Text("KAMs with overdue follow-ups", style: TextStyle(color: Color(0xff92400e), fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: list.map((k) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffffe3a3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text("${k["name"]}", style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _badge("${fmtN(k["leads_overdue"])} overdue", const Color(0xffd97706)),
              ]),
            );
          }).toList(),
        )
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

}