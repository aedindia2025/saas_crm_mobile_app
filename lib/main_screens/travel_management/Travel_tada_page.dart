import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'NewTravel_claim_page.dart';
import 'NewTravel_request_page.dart';

class TravelTadaPage extends StatefulWidget {
  const TravelTadaPage({super.key});

  @override
  State<TravelTadaPage> createState() => _TravelTadaPageState();
}

class _TravelTadaPageState extends State<TravelTadaPage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  final String baseUrl = "http://103.110.236.187:3076/api/v1";

  bool loadingTravel = true;
  bool loadingClaims = true;

  String? token;

  List<Map<String, dynamic>> travelRequests = [];
  List<Map<String, dynamic>> claims = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> teamUsers = [];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    loadAll();
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'X-Tenant-Slug': 'ascent',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');

    if (token == null) return;

    await Future.wait([
      fetchTravelRequests(),
      fetchClaims(),
      fetchCustomers(),
      fetchTeamUsers(),
    ]);
  }

  Future<dynamic> getApi(String path) async {
    final response = await http.get(
      Uri.parse("$baseUrl$path"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(response.body);
  }

  Future<void> fetchTravelRequests() async {
    try {
      setState(() => loadingTravel = true);
      final data = await getApi("/travel/requests");

      setState(() {
        travelRequests = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        loadingTravel = false;
      });
    } catch (e) {
      setState(() => loadingTravel = false);
      showError(e.toString());
    }
  }

  Future<void> fetchClaims() async {
    try {
      setState(() => loadingClaims = true);
      final data = await getApi("/travel/tada");

      setState(() {
        claims = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
        loadingClaims = false;
      });
    } catch (e) {
      setState(() => loadingClaims = false);
      showError(e.toString());
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final data = await getApi("/travel/team-customers");
      setState(() {
        customers = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
      });
    } catch (_) {}
  }

  Future<void> fetchTeamUsers() async {
    try {
      final data = await getApi("/travel/team-users");
      setState(() {
        teamUsers = List<Map<String, dynamic>>.from(
          data.map((e) => Map<String, dynamic>.from(e)),
        );
      });
    } catch (_) {}
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  String money(dynamic value) {
    final n = double.tryParse(value?.toString() ?? "0") ?? 0;
    return "₹${n.toStringAsFixed(0)}";
  }

  Color statusColor(String status) {
    switch (status) {
      case "Approved":
      case "CEO Approved":
      case "Accounts Approved":
      case "Paid":
        return const Color(0xff059669);
      case "Rejected":
        return const Color(0xffDC2626);
      case "Submitted":
      case "Manager Approved":
        return const Color(0xffD97706);
      default:
        return const Color(0xff64748B);
    }
  }

  Widget statusChip(String status) {
    final c = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget travelCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? "Draft";
    final accent = statusColor(status);
    final canEdit = status != "Approved";

    return InkWell(
      onTap: () => openTravelDetails(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 160,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xffEFF6FF),
                          child: Icon(
                            Icons.flight_takeoff,
                            color: Color(0xff2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['request_number']?.toString() ?? "-",
                                  style: const TextStyle(
                                    color: Color(0xff2563EB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              statusChip(status),
                            ],
                          ),
                        ),
                        Text(
                          item['visit_type']?.toString() ?? "",
                          style: const TextStyle(
                            color: Color(0xff64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['purpose']?.toString() ?? "-",
                      style: const TextStyle(
                        color: Color(0xff0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        info(Icons.location_on_outlined,
                            "${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}"),
                        info(Icons.calendar_today_outlined,
                            "${item['travel_date'] ?? '-'} - ${item['return_date'] ?? '-'}"),
                        if ((item['account_name'] ?? '').toString().isNotEmpty)
                          info(Icons.business_outlined, item['account_name']),
                        if ((item['employee_name'] ?? '').toString().isNotEmpty)
                          info(Icons.person_outline, item['employee_name']),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        if (status == "Draft" || status == "Rejected")
                          ElevatedButton.icon(
                            onPressed: () => submitTravel(item['id']),
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: Text(status == "Rejected" ? "Re-submit" : "Submit"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                        if (status == "Draft" || status == "Rejected")
                          const SizedBox(width: 8),

                        if (status == "Draft" || status == "Rejected" || status == "Submitted")
                          TextButton.icon(
                          //  onPressed: () => openEditTravelRequest(item),
                            onPressed: () => confirmSubmitTravel(item),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text("Edit"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryLight,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          )
                        else if (status == "Approved")
                          const Text(
                            "✓ Approved - you may travel",
                            style: TextStyle(
                              color: Color(0xff059669),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          const Text(
                            "View only",
                            style: TextStyle(
                              color: AppColors.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                        const Spacer(),

                        if (item['advance_required'] == true)
                          miniChip("Advance Req.", const Color(0xff7C3AED)),
                        const SizedBox(width: 6),
                        if (item['accommodation_required'] == true)
                          miniChip("Stay Required", const Color(0xff0F766E)),
                      ],
                    )

                  /*  Row(
                      children: [
                        if (canEdit)
                          TextButton.icon(
                            onPressed: () => openEditTravelRequest(item),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text("Edit"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryLight,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          )
                        else
                          const Text(
                            "✓ Approved - you may travel",
                            style: TextStyle(
                              color: Color(0xff059669),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const Spacer(),
                        if (item['advance_required'] == true)
                          miniChip("Advance Req.", const Color(0xff7C3AED)),
                        const SizedBox(width: 6),
                        if (item['accommodation_required'] == true)
                          miniChip("Stay Required", const Color(0xff0F766E)),
                      ],
                    ),*/
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> confirmSubmitTravel(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Submit Travel Request?"),
        content: Text(
          "Do you want to submit ${item['request_number'] ?? 'this request'} for approval?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Submit"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await submitTravel(item['id']);
    }
  }

  Widget claimCard(Map<String, dynamic> item) {
    final status = item['overall_status']?.toString() ?? "Draft";
    final accent = statusColor(status);

    return InkWell(
      onTap: () => openClaimDetails(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 145,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xffEEF2FF),
                          child: Icon(
                            Icons.receipt_long,
                            color: Color(0xff4F46E5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['claim_number']?.toString() ?? "-",
                                  style: const TextStyle(
                                    color: Color(0xff4F46E5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              statusChip(status),
                            ],
                          ),
                        ),
                        Text(
                          money(item['net_payable']),
                          style: const TextStyle(
                            color: Color(0xff0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['purpose']?.toString() ?? "-",
                      style: const TextStyle(
                        color: Color(0xff0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        info(Icons.location_on_outlined,
                            "${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}"),
                        info(Icons.calendar_today_outlined,
                            item['claim_date']?.toString() ?? "-"),
                        info(Icons.person_outline,
                            item['employee_name']?.toString() ?? "-"),
                        info(Icons.list_alt,
                            "${(item['line_items'] as List?)?.length ?? 0} items"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        miniChip(
                          item['has_all_proofs'] == true
                              ? "Proofs Attached"
                              : "Proof Missing",
                          item['has_all_proofs'] == true
                              ? const Color(0xff059669)
                              : const Color(0xffDC2626),
                        ),
                        const Spacer(),
                        const Text(
                          "View only",
                          style: TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget info(IconData icon, dynamic text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xff94A3B8)),
        const SizedBox(width: 5),
        Text(
          text?.toString() ?? "-",
          style: const TextStyle(
            color: Color(0xff64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> submitTravel(int id) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/travel/requests/$id/submit"),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSuccess("Travel request submitted");
        fetchTravelRequests();
      } else {
        showError(response.body);
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  Future<void> submitClaim(int id) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/travel/tada/$id/submit"),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSuccess("Claim submitted");
        fetchClaims();
      } else {
        showError(response.body);
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  Widget travelTab() {
    final total = travelRequests.length;
    final pending = travelRequests
        .where((e) =>
    e['status'] == "Submitted" ||
        e['approval_status']?.toString().toLowerCase() == "pending")
        .length;
    final approved = travelRequests.where((e) => e['status'] == "Approved").length;
    final rejected = travelRequests.where((e) => e['status'] == "Rejected").length;

    return RefreshIndicator(
      onRefresh: fetchTravelRequests,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            "Travel Request",
            style: TextStyle(
              color: Color(0xff0F172A),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Plan and track business travel",
            style: TextStyle(color: Color(0xff64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              statCard("Total", total.toString(), Icons.flight_takeoff,
                  const Color(0xff2563EB)),
              const SizedBox(width: 10),
              statCard("Pending", pending.toString(), Icons.access_time,
                  const Color(0xffD97706)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              statCard("Approved", approved.toString(), Icons.check_circle,
                  const Color(0xff059669)),
              const SizedBox(width: 10),
              statCard("Rejected", rejected.toString(), Icons.cancel,
                  const Color(0xffDC2626)),
            ],
          ),
          const SizedBox(height: 18),
          if (loadingTravel)
            const Center(child: CircularProgressIndicator())
          else if (travelRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text("No travel requests found")),
            )
          else
            ...travelRequests.map(travelCard),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget claimsTab() {
    final total = claims.length;
    final draft = claims.where((e) => e['overall_status'] == "Draft").length;
    final submitted = claims.where((e) => e['overall_status'] == "Submitted").length;
    final paid = claims.where((e) => e['overall_status'] == "Paid").length;

    return RefreshIndicator(
      onRefresh: fetchClaims,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            "Travel Claims",
            style: TextStyle(
              color: Color(0xff0F172A),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Claim travel expenses after your trip",
            style: TextStyle(color: Color(0xff64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              statCard("Total", total.toString(), Icons.receipt_long,
                  const Color(0xff2563EB)),
              const SizedBox(width: 10),
              statCard("Draft", draft.toString(), Icons.edit_document,
                  const Color(0xff64748B)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              statCard("Submitted", submitted.toString(), Icons.access_time,
                  const Color(0xffD97706)),
              const SizedBox(width: 10),
              statCard("Paid", paid.toString(), Icons.check_circle,
                  const Color(0xff059669)),
            ],
          ),
          const SizedBox(height: 18),
          if (loadingClaims)
            const Center(child: CircularProgressIndicator())
          else if (claims.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text("No travel claims found")),
            )
          else
            ...claims.map(claimCard),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void openTravelDetails(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? "Draft";
    final canEdit = status != "Approved";

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .95,
            maxWidth: 980,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              dialogHeader(
                title: "Travel Request Details",
                subtitle: item['request_number']?.toString() ?? "",
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      travelHeroDetails(item),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: detailSection(
                          title: "Trip Summary",
                          icon: Icons.flight_takeoff,
                          children: [
                            detailBox("Employee", item['employee_name']),
                            detailBox("Source", item['source_label'] ?? item['source'] ?? "Direct"),
                            detailBox("From City", item['from_city']),
                            detailBox("To City", item['to_city']),
                            detailBox("Travel Date", item['travel_date']),
                            detailBox("Return Date", item['return_date']),
                            detailBox("Total Days", item['total_days']),
                            detailBox(
                              "Outside District / City",
                              item['is_outside_district'] == true ? "Yes" : "No",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, c) {
                          final isWide = c.maxWidth > 760;
                          final cardWidth = isWide ? (c.maxWidth - 16) / 2 : c.maxWidth;

                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: detailSection(
                                  title: "Transport",
                                  icon: Icons.directions_transit_outlined,
                                  children: [
                                    detailBox("Mode Of Travel", _valueOr(item['mode_of_travel'] ?? item['transport_mode'], "Not set")),
                                    detailBox("Class Of Travel", item['class_of_travel']),
                                    detailBox("Vehicle Number", item['vehicle_number']),
                                    detailBox("Estimated Kms", item['estimated_kms']),
                                    detailBox("Booking / PNR Ref", item['advance_booking_ref']),
                                  ],
                                ),
                              ),

                              SizedBox(
                                width: cardWidth,
                                child: detailSection(
                                  title: "Accommodation",
                                  icon: Icons.home_outlined,
                                  children: [
                                    detailBox("Accommodation Required", item['accommodation_required'] == true ? "Yes" : "No"),
                                    detailBox("Accommodation Type", _valueOr(item['accommodation_type'], "Not Required")),
                                    detailBox("Hotel Name", item['hotel_name']),
                                    detailBox("Check In Date", item['check_in_date']),
                                    detailBox("Check Out Date", item['check_out_date']),
                                    detailBox("Accommodation Cost", item['accommodation_cost'] == null ? null : money(item['accommodation_cost'])),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              dialogFooter(
                canEdit: canEdit,
                onEdit: () {
                  Navigator.pop(context);
                  openEditTravelRequest(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _valueOr(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? "";
    return text.isEmpty ? fallback : text;
  }

  void openClaimDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(14),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              dialogHeader(
                title: item['claim_number']?.toString() ?? "Travel Claim",
                subtitle: "TA/DA claim details",
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      claimHeroDetails(item),
                      const SizedBox(height: 16),
                      if (item['has_all_proofs'] != true)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xffFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xffFECACA)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Color(0xffDC2626), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Every expense item needs at least one proof document before submission.",
                                  style: TextStyle(
                                    color: Color(0xffDC2626),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      claimExpenseItems(item),
                    ],
                  ),
                ),
              ),
              dialogFooter(canEdit: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget detail(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xff334155), fontSize: 14),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value.toString()),
          ],
        ),
      ),
    );
  }



  Widget dialogHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget dialogFooter({
    required bool canEdit,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (canEdit)
            ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text("Edit"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          if (canEdit) const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget travelHeroDetails(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffF8FAFC), Colors.white, Color(0xffEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              statusChip(item['approval_display']?.toString() ?? item['status']?.toString() ?? "Draft"),
              miniChip(item['visit_type']?.toString() ?? "-", AppColors.primaryLight),
              miniChip(item['request_number']?.toString() ?? "-", AppColors.primaryLight),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item['purpose']?.toString() ?? "-",
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Travel request overview and trip information",
            style: TextStyle(
              color: AppColors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              info(Icons.location_on_outlined, "${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}"),
              info(Icons.calendar_today_outlined, "${item['travel_date'] ?? '-'} - ${item['return_date'] ?? '-'}"),
              info(Icons.person_outline, item['employee_name']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: topInfoBox("Trip Days", item['total_days']?.toString() ?? "--")),
              const SizedBox(width: 10),
              Expanded(child: topInfoBox("Transport", item['transport_mode']?.toString().isNotEmpty == true ? item['transport_mode'].toString() : "Not set")),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: topInfoBox("Advance", item['advance_required'] == true ? "Yes" : "No")),
              const SizedBox(width: 10),
              Expanded(child: topInfoBox("Stay", item['accommodation_required'] == true ? "Yes" : "No")),
            ],
          ),
        ],
      ),
    );
  }

  Widget claimHeroDetails(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffF8FAFC), Colors.white, Color(0xffEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              statusChip(item['overall_status']?.toString() ?? "Draft"),
              miniChip(item['claim_date']?.toString() ?? "-", AppColors.primaryLight),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item['purpose']?.toString() ?? "-",
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${item['from_city'] ?? '-'} → ${item['to_city'] ?? '-'}",
            style: const TextStyle(
              color: AppColors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: topInfoBox("Total Expenses", money(item['total_amount']))),
              const SizedBox(width: 10),
              Expanded(child: topInfoBox("Advance Taken", money(item['advance_taken']))),
            ],
          ),
          const SizedBox(height: 10),
          topInfoBox("Net Payable", money(item['net_payable'])),
        ],
      ),
    );
  }

  Widget topInfoBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget detailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryLight),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth > 520;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: children.map((child) {
                    return SizedBox(
                      width: isWide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                      child: child,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget detailBox(String label, dynamic value) {
    final text = _valueOr(value, "-");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSoft,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }


  Widget claimExpenseItems(Map<String, dynamic> item) {
    final items = item['line_items'] is List ? item['line_items'] as List : [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primaryLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Expense Items (${items.length})",
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Text(
                  "View only",
                  style: TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "No expense items found",
                style: TextStyle(color: AppColors.textSoft),
              ),
            )
          else
            ...items.map((raw) {
              final e = Map<String, dynamic>.from(raw as Map);
              final attachments = e['attachments'] is List ? e['attachments'] as List : [];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e['description']?.toString() ?? "-",
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          money(e['amount']),
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${e['category'] ?? '-'} • ${e['expense_date'] ?? '-'}"
                          "${(e['from_place'] ?? '').toString().isNotEmpty ? ' • ${e['from_place']}' : ''}"
                          "${(e['to_place'] ?? '').toString().isNotEmpty ? ' → ${e['to_place']}' : ''}",
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    miniChip(
                      attachments.isNotEmpty ? "Proof Attached" : "Proof Missing",
                      attachments.isNotEmpty ? const Color(0xff059669) : const Color(0xffDC2626),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void openEditTravelRequest(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTravelRequestPage(
          baseUrl: baseUrl,
          token: token!,
          customers: customers,
          editData: item,
        ),
      ),
    ).then((value) {
      if (value == true) fetchTravelRequests();
    });
  }

  void openCreateTravelRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTravelRequestPage(
          baseUrl: baseUrl,
          token: token!,
          customers: customers,
        ),
      ),
    ).then((value) {
      if (value == true) fetchTravelRequests();
    });
  }

  void openCreateClaim() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewTravelClaimPage(
          baseUrl: baseUrl,
          token: token!,
          requests: travelRequests,
        ),
      ),
    ).then((value) {
      if (value == true) fetchClaims();
    });
  }



  @override
  Widget build(BuildContext context) {
    final isTravelTab = tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primaryDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Travel Management",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.14)),
              ),
              child: TabBar(
                controller: tabController,
                onTap: (_) => setState(() {}),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: Colors.white.withOpacity(.78),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    text: "Travel Requests",
                  ),
                  Tab(
                    text: "Travel Claims",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: isTravelTab ? openCreateTravelRequest : openCreateClaim,
        icon: const Icon(Icons.add),
        label: Text(isTravelTab ? "New Request" : "New Claim"),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          travelTab(),
          claimsTab(),
        ],
      ),
    );
  }
}

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF3060A0);

  static const Color bg = Color(0xffF4F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0xffDDE6F0);
  static const Color textDark = Color(0xff0F172A);
  static const Color textSoft = Color(0xff64748B);

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