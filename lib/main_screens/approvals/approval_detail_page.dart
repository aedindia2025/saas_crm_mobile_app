import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utile/app_colors.dart';


class ApprovalDetailPage extends StatefulWidget {
  final Map<String, dynamic> approval;
  final String apiBase;
  final Map<String, String> headers;

  const ApprovalDetailPage({
    super.key,
    required this.approval,
    required this.apiBase,
    required this.headers,
  });

  @override
  State<ApprovalDetailPage> createState() => _ApprovalDetailPageState();
}

class _ApprovalDetailPageState extends State<ApprovalDetailPage> {
  bool loading = true;
  bool deciding = false;

  Map<String, dynamic> approval = {};
  Map<String, dynamic> summary = {};

  final TextEditingController notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    approval = Map<String, dynamic>.from(widget.approval);
    loadSummary();
  }

  Widget travelSummary() {
    return Column(
      children: [
        infoPanel(
          title: "Tab 1 — Trip Summary",
          icon: Icons.flight_takeoff,
          color: const Color(0xff2563EB),
          children: [
            infoRow("Employee", summary["employee_name"], highlight: true),
            infoRow("Request No.", summary["request_number"]),
            infoRow("Purpose", summary["purpose"], highlight: true),
            infoRow("Visit Type", summary["visit_type"]),
            infoRow("Source", safeText(summary["source"]) == "kam" ? "KAM" : "Direct"),
            infoRow("From City", summary["from_city"]),
            infoRow("To City", summary["to_city"]),
            infoRow("Travel Date", summary["travel_date"]),
            infoRow("Return Date", summary["return_date"]),
            infoRow("Total Days", "${safeText(summary["total_days"], "1")} day(s)"),
            infoRow("Outside District / City", summary["is_outside_district"] == true ? "Yes" : "No"),
          ],
        ),
        infoPanel(
          title: "Tab 2 — CRM Linkage",
          icon: Icons.business_outlined,
          color: const Color(0xff0284C7),
          children: [
            infoRow("Account / Customer", summary["account_name"], highlight: true),
            infoRow("Contact Person", summary["contact_name"]),
            infoRow("Contact Phone", summary["contact_phone"]),
            infoRow("Lead / Reference ID", summary["lead_ref"] ?? summary["lead_id"]),
            infoRow("Linked Opportunity", summary["opportunity_id"]),
            infoRow("Linked Tender", summary["tender_label"] ?? summary["tender_id"]),
            infoRow("KAM Activity", summary["kam_activity_subject"]),
          ],
        ),
        infoPanel(
          title: "Tab 3 — Travel & Budgets",
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xff059669),
          children: [
            infoRow("Transport Mode", summary["transport_mode"]),
            infoRow("Vehicle Number", summary["vehicle_number"]),
            infoRow("Estimated KMs", summary["estimated_kms"]),
            infoRow("Booking Ref", summary["advance_booking_ref"]),
            infoRow("Estimated Total", money(summary["estimated_total"]), highlight: true),
            infoRow("Advance Required", summary["advance_required"] == true ? "Yes" : "No"),
            infoRow("Advance Amount", money(summary["advance_amount"])),
            infoRow("Cost Center", summary["cost_center"]),
            infoRow("Budget Code", summary["budget_code"]),
          ],
        ),
        infoPanel(
          title: "Tab 4 — Accommodation",
          icon: Icons.home_outlined,
          color: const Color(0xff7C3AED),
          children: [
            infoRow("Accommodation Required", summary["accommodation_required"] == true ? "Yes" : "No"),
            infoRow("Accommodation Type", summary["accommodation_type"]),
            infoRow("Hotel Name", summary["hotel_name"]),
            infoRow("Check-in Date", summary["check_in_date"]),
            infoRow("Check-out Date", summary["check_out_date"]),
            infoRow("Accommodation Cost", money(summary["accommodation_cost"])),
          ],
        ),
        infoPanel(
          title: "Tab 5 — Additional Info",
          icon: Icons.notes_outlined,
          color: const Color(0xffD97706),
          children: [
            infoRow("Travel Companions", summary["companions"]),
            infoRow("Status", summary["status"]),
            infoRow("Notes / Remarks", summary["notes"]),
          ],
        ),
      ],
    );
  }

  Widget tadaSummary() {
    final items = summary["line_items"] is List ? summary["line_items"] as List : [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Row(
            children: [
              Expanded(child: amountTile("Total Amount", money(summary["total_amount"]))),
              const SizedBox(width: 8),
              Expanded(child: amountTile("Advance Taken", money(summary["advance_taken"]))),
              const SizedBox(width: 8),
              Expanded(child: amountTile("Net Payable", money(summary["net_payable"]), green: true)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        infoPanel(
          title: "Claim Details",
          icon: Icons.receipt_long,
          color: AppColors.primaryLight,
          children: [
            infoRow("Employee", summary["employee_name"], highlight: true),
            infoRow("Claim No.", summary["claim_number"]),
            infoRow("Purpose", summary["purpose"], highlight: true),
            infoRow("Claim Date", summary["claim_date"]),
            infoRow("Travel From", summary["travel_date_from"]),
            infoRow("Travel To", summary["travel_date_to"]),
            infoRow("Status", summary["overall_status"]),
          ],
        ),
        sectionTitle("Expense Items (${items.length})", Icons.payments_outlined, const Color(0xff059669)),
        ...items.map((item) {
          final m = item is Map ? item : {};
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeText(m["description"], "Expense"),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                infoRow("Category", m["category"]),
                infoRow("Amount", money(m["amount"]), highlight: true),
                infoRow("Expense Date", m["expense_date"]),
                infoRow("From Place", m["from_place"]),
                infoRow("To Place", m["to_place"]),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget amountTile(String title, String value, {bool green = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: green ? const Color(0xffECFDF5) : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green ? const Color(0xffBBF7D0) : AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: green ? const Color(0xff047857) : AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSoft,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget leadSummary() {
    final products = summary["products"] is List ? summary["products"] as List : [];

    return Column(
      children: [
        infoPanel(
          title: "Lead Overview",
          icon: Icons.trending_up,
          color: const Color(0xff7C3AED),
          children: [
            infoRow("Lead Title", summary["title"] ?? summary["lead_title"], highlight: true),
            infoRow("Company", summary["company_name"], highlight: true),
            infoRow("Lead Type", summary["lead_type"]),
            infoRow("Status", summary["status"]),
            infoRow("Source", summary["source"]),
            infoRow("Priority", summary["priority"]),
            infoRow("Region", summary["region"]),
            infoRow("Industry", summary["industry"]),
            infoRow("Assigned To", summary["assigned_to_name"]),
            infoRow("Created By", summary["created_by_name"]),
          ],
        ),
        infoPanel(
          title: "Opportunity Details",
          icon: Icons.workspace_premium_outlined,
          color: const Color(0xff059669),
          children: [
            infoRow("Est. Value", money(summary["estimated_value"]), highlight: true),
            infoRow("Probability", summary["probability"] == null ? null : "${summary["probability"]}%"),
            infoRow("Expected Close", summary["expected_close_date"]),
            infoRow("Deal Stage", summary["deal_stage"]),
            infoRow("Opportunity Type", summary["opportunity_type"]),
          ],
        ),
        infoPanel(
          title: "Requirements & Notes",
          icon: Icons.description_outlined,
          color: const Color(0xffD97706),
          children: [
            infoRow("Description", summary["description"]),
            infoRow("Requirements", summary["requirements"]),
            infoRow("Notes", summary["notes"]),
          ],
        ),
        sectionTitle("Products / Items (${products.length})", Icons.inventory_2_outlined, const Color(0xff7C3AED)),
        if (products.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: const Center(
              child: Text(
                "No products added to this lead",
                style: TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else
          ...products.map((p) {
            final m = p is Map ? p : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeText(m["product_name"] ?? m["name"], "Product"),
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  infoRow("OEM / Brand", m["oem_name"] ?? m["brand"]),
                  infoRow("Quantity", m["quantity"] ?? m["qty"]),
                  infoRow("Unit Price", money(m["unit_price"] ?? m["price"])),
                  infoRow("Total Price", money(m["total_price"] ?? m["amount"]), highlight: true),
                  infoRow("Specification", m["specification"]),
                ],
              ),
            );
          }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget customerSummary() {
    final contacts = summary["contacts"] is List ? summary["contacts"] as List : [];
    final billing = summary["billing_consignees"] is List ? summary["billing_consignees"] as List : [];
    final shipping = summary["shipping_consignees"] is List ? summary["shipping_consignees"] as List : [];

    return Column(
      children: [
        infoPanel(
          title: "Account Details",
          icon: Icons.business_outlined,
          color: const Color(0xff0284C7),
          children: [
            infoRow("Customer Name", summary["customer_name"], highlight: true),
            infoRow("Account Status", summary["account_status"]),
            infoRow("Potential", summary["account_potential"]),
            infoRow("Potential Value", money(summary["potential_value"])),
            infoRow("Industry", summary["industry"]),
            infoRow("Vertical", summary["customer_vertical"]),
            infoRow("Division", summary["division"]),
            infoRow("Group", summary["group_name"]),
            infoRow("Owner / KAM", summary["assigned_to_name"]),
            infoRow("Created By", summary["created_by_name"]),
          ],
        ),
        infoPanel(
          title: "Legal & Financial",
          icon: Icons.credit_card,
          color: AppColors.primaryLight,
          children: [
            infoRow("GST Number", summary["gst_number"]),
            infoRow("PAN Number", summary["pan_number"]),
            infoRow("Annual Revenue", money(summary["annual_revenue"])),
            infoRow("Employee Count", summary["employee_count"]),
            infoRow("Website", summary["website"]),
          ],
        ),
        infoPanel(
          title: "Billing Address",
          icon: Icons.location_on_outlined,
          color: const Color(0xffEA580C),
          children: [infoRow("Address", summary["billing_address"], highlight: true)],
        ),
        infoPanel(
          title: "Shipping Address",
          icon: Icons.local_shipping_outlined,
          color: const Color(0xff0F766E),
          children: [
            infoRow(
              "Address",
              summary["shipping_same_as_billing"] == true
                  ? "Same as billing"
                  : summary["shipping_address"],
              highlight: true,
            ),
          ],
        ),
        sectionTitle("Contacts (${contacts.length})", Icons.people_outline, const Color(0xff7C3AED)),
        ...contacts.map((ct) {
          final m = ct is Map ? ct : {};
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeText(m["contact_name"], "Contact"),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                infoRow("Designation", m["designation"]),
                infoRow("Department", m["department"]),
                infoRow("Mobile", m["mobile"]),
                infoRow("Office Phone", m["office_phone"]),
                infoRow("Office Email", m["office_email"]),
                infoRow("Personal Email", m["personal_email"]),
                infoRow("Primary", m["is_primary"] == true ? "Yes" : "No"),
              ],
            ),
          );
        }),
        simpleListSection("Billing Consignees", billing),
        simpleListSection("Shipping Consignees", shipping),
        infoPanel(
          title: "Remarks",
          icon: Icons.notes_outlined,
          color: const Color(0xffD97706),
          children: [infoRow("Remarks", summary["remarks"])],
        ),
      ],
    );
  }

  Widget simpleListSection(String title, List items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        sectionTitle(title, Icons.list_alt_outlined, AppColors.primaryLight),
        ...items.map((e) {
          final m = e is Map ? e : {};
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeText(m["name"], "-"),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  safeText(m["address"], "-"),
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget emdbgSummary() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Row(
            children: [
              Expanded(child: amountTile("Instrument Type", safeText(summary["instrument_type"]))),
              const SizedBox(width: 8),
              Expanded(child: amountTile("Amount", money(summary["amount"]), green: true)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        infoPanel(
          title: "Client & Tender",
          icon: Icons.business_outlined,
          color: const Color(0xffEA580C),
          children: [
            infoRow("Client", summary["client_name"], highlight: true),
            infoRow("Tender No.", summary["tender_num"]),
            infoRow("Tender Title", summary["tender_title"]),
            infoRow("PO Number", summary["po_number"]),
            infoRow("PO Date", summary["po_date"]),
            infoRow("WO Value", money(summary["wo_value"])),
          ],
        ),
        infoPanel(
          title: "Instrument Details",
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xff0F766E),
          children: [
            infoRow("Reference No.", summary["reference_num"], highlight: true),
            infoRow("Bank", summary["bank_name"]),
            infoRow("Bank Branch", summary["bank_branch"]),
            infoRow("Instrument No.", summary["instrument_number"]),
            infoRow("Issued Date", summary["issued_date"]),
            infoRow("Submitted", summary["submitted_date"]),
            infoRow("Valid From", summary["valid_from"]),
            infoRow("Expiry Date", summary["expiry_date"], highlight: true),
            infoRow("Status", summary["status"]),
            infoRow("Purpose", summary["purpose"]),
            infoRow("Notes", summary["notes"]),
            infoRow("Created By", summary["created_by_name"]),
          ],
        ),
      ],
    );
  }

  Widget tenderSummary() {
    final step1 = summary["step1"] is Map ? summary["step1"] as Map : {};
    final step2 = summary["step2"] is Map ? summary["step2"] as Map : {};
    final step3 = summary["step3"] is Map ? summary["step3"] as Map : {};
    final step4 = summary["step4"] is Map ? summary["step4"] as Map : {};
    final step5 = summary["step5"] is Map ? summary["step5"] as Map : {};
    final step7 = summary["step7"] is Map ? summary["step7"] as Map : {};

    final products = step1["products"] is List ? step1["products"] as List : [];
    final finalProducts = step3["final_products"] is List ? step3["final_products"] as List : [];
    final bidders = step4["bidders"] is List ? step4["bidders"] as List : [];
    final documents = summary["documents"] is List ? summary["documents"] as List : [];

    return Column(
      children: [
        infoPanel(
          title: "Tab 1 — Basic Info",
          icon: Icons.description_outlined,
          color: const Color(0xffEA580C),
          children: [
            infoRow("Customer", step1["customer_name"], highlight: true),
            infoRow("Tender Title", step1["tender_title"], highlight: true),
            infoRow("Portal Ref No.", step1["portal_ref_number"]),
            infoRow("Est. Value", money(step1["est_value"])),
            infoRow("Source Portal", step1["source_portal"]),
            infoRow("Stage", step1["tender_status"]),
            infoRow("Published Date", step1["published_date"]),
            infoRow("Pre-Bid Date", step1["pre_bid_date"]),
            infoRow("Submission Date", step1["submission_date"]),
            infoRow("Assigned To", step1["assigned_to_name"]),
            infoRow("RFP Document", step1["rfp_document"]),
          ],
        ),
        sectionTitle("Products / BOQ (${products.length})", Icons.inventory_2_outlined, AppColors.primaryLight),
        ...products.map((p) {
          final m = p is Map ? p : {};
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeText(m["product_name"], "Product"),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                infoRow("Quantity", m["quantity"]),
                infoRow("Unit Price", money(m["unit_price"])),
                infoRow("GST %", m["gst_percent"]),
                infoRow("Works Item", m["is_works_item"] == true ? "Yes" : "No"),
              ],
            ),
          );
        }),
        infoPanel(
          title: "Tab 2 — Tender Details (Financials)",
          icon: Icons.payments_outlined,
          color: const Color(0xffD97706),
          children: [
            infoRow("Tender Fee Required", step2["tender_fee_required"] == true ? "Yes" : "No"),
            infoRow("Tender Fee Amount", money(step2["tender_fee_amount"])),
            infoRow("Tender Fee Method", step2["tender_fee_method"]),
            infoRow("EMD Required", step2["emd_required"] == true ? "Yes" : "No"),
            infoRow("EMD Amount", money(step2["emd_amount"])),
            infoRow("EMD Method", step2["emd_payment_method"]),
            infoRow("EMD Bank", step2["emd_bank_name"]),
            infoRow("PBG Required", step2["pbg_required"] == true ? "Yes" : "No"),
            infoRow("PBG Amount", money(step2["pbg_amount"])),
            infoRow("Split Order", step2["split_order"] == true ? "Yes" : "No"),
            infoRow("Reverse Auction", step2["reverse_auction"] == true ? "Yes" : "No"),
          ],
        ),
        if (step3.isNotEmpty) ...[
          infoPanel(
            title: "Tab 3 — Workings",
            icon: Icons.layers_outlined,
            color: AppColors.primaryLight,
            children: [
              infoRow("Corrigendum Document", step3["corrigendum_document"]),
              infoRow("Workings Document", step3["workings_document"]),
            ],
          ),
          sectionTitle("Final BOQ (${finalProducts.length})", Icons.fact_check_outlined, AppColors.primaryLight),
          ...finalProducts.map((p) {
            final m = p is Map ? p : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeText(m["product_name"], "Product"),
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  infoRow("OEM", m["oem_name"]),
                  infoRow("Authorization No.", m["authorization_num"]),
                  infoRow("Quantity", m["quantity"]),
                  infoRow("Unit Price", money(m["unit_price"])),
                  infoRow("GST %", m["gst_percent"]),
                  infoRow("Total Price", money(m["total_price"]), highlight: true),
                ],
              ),
            );
          }),
        ],
        if (step4.isNotEmpty) ...[
          infoPanel(
            title: "Tab 4 — Tech Bid",
            icon: Icons.verified_outlined,
            color: const Color(0xff0F766E),
            children: [
              infoRow("Eligibility", step4["tech_bid_eligible"], highlight: true),
            ],
          ),
          sectionTitle("Bidders (${bidders.length})", Icons.groups_outlined, const Color(0xff0F766E)),
          ...bidders.map((b) {
            final m = b is Map ? b : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeText(m["bidder_name"], "Bidder"),
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  infoRow("Bidder Type", m["bidder_type"]),
                ],
              ),
            );
          }),
        ],
        if (step5.isNotEmpty)
          infoPanel(
            title: "Tab 5 — Result",
            icon: Icons.emoji_events_outlined,
            color: const Color(0xff059669),
            children: [
              infoRow("Result", step5["result"], highlight: true),
              infoRow("Result Date", step5["result_date"]),
              infoRow("Our Bid Amount", money(step5["bid_amount"])),
              infoRow("RA Final Bid", money(step5["reverse_auction_final_bid"])),
            ],
          ),
        if (step7.isNotEmpty)
          infoPanel(
            title: "Tab 6 — PO Details",
            icon: Icons.assignment_turned_in_outlined,
            color: const Color(0xff2563EB),
            children: [
              infoRow("PO Number", step7["po_num"], highlight: true),
              infoRow("PO Date", step7["po_date"]),
              infoRow("PO Value", money(step7["po_value"])),
              infoRow("No. of Consignees", step7["no_of_consignee"]),
              infoRow("Delivery Date", step7["dlvry_date"]),
              infoRow("Completion Days", step7["completion_days"]),
              infoRow("Completion Date", step7["completion_date"]),
              infoRow("Warranty Months", step7["wrnty_mth"]),
              infoRow("Site Engineer", step7["site_eng"]),
              infoRow("Engineer Phone", step7["eng_phone"]),
              infoRow("Penalty / LD", step7["penalty"] == true ? "Yes" : "No"),
              infoRow("LD Type", step7["ld_type"]),
              infoRow("LD Percent", step7["ld_percent"]),
              infoRow("Payment Terms", step7["pmnt_terms"]),
              infoRow("Scope of Work", step7["sow"]),
            ],
          ),
        sectionTitle("All Documents (${documents.length})", Icons.folder_copy_outlined, AppColors.primaryLight),
        if (documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: const Text(
              "No documents available",
              style: TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700),
            ),
          )
        else
          ...documents.map((doc) {
            final m = doc is Map ? doc : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safeText(m["file_name"], "Document"),
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  infoRow("Type", m["doc_type"]),
                  infoRow("File", m["file_url"] ?? m["file_path"]),
                ],
              ),
            );
          }),
      ],
    );
  }

  bool get isDynamic => safeText(approval["kind"], "").toLowerCase() == "dynamic";

  Future<void> loadSummary() async {
    setState(() => loading = true);

    if (isDynamic) {
      setState(() {
        summary = approval["summary"] is Map
            ? Map<String, dynamic>.from(approval["summary"])
            : {};
        loading = false;
      });
      return;
    }

    try {
      final id = approval["id"];
      final response = await http.get(
        Uri.parse("${widget.apiBase}/approvals/$id/summary"),
        headers: widget.headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          approval = Map<String, dynamic>.from(data);
          summary = data["summary"] is Map
              ? Map<String, dynamic>.from(data["summary"])
              : {};
        });
      } else {
        showError("Failed to load approval details");
      }
    } catch (e) {
      showError("Approval details error: $e");
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> decide(String decision) async {
    final notes = notesController.text.trim();

    if (decision == "rejected" && notes.isEmpty) {
      showError("Please provide a reason for rejection.");
      return;
    }

    setState(() => deciding = true);

    try {
      final uri = isDynamic
          ? Uri.parse("${widget.apiBase}/approval-workflows/requests/${approval["id"]}/decision")
          : Uri.parse("${widget.apiBase}/approvals/${approval["id"]}/decide");

      final body = isDynamic
          ? {
        "decision": decision,
        "remarks": notes,
      }
          : {
        "decision": decision,
        "notes": notes,
        "rejection_reason": decision == "rejected" ? notes : null,
      };

      final response = await http.post(
        uri,
        headers: widget.headers,
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSuccess(
          decision == "approved"
              ? "Approved successfully"
              : "Rejected - requester will be notified",
        );

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        String msg = "Approval action failed";
        try {
          final data = jsonDecode(response.body);
          msg = safeText(data["detail"] ?? data["error"], msg);
        } catch (_) {}
        showError(msg);
      }
    } catch (e) {
      showError("Approval request failed: $e");
    }

    if (mounted) setState(() => deciding = false);
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.green, content: Text(message)),
    );
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }

  bool get isPending => safeText(approval["status"], "").toLowerCase() == "pending";

  String get module => safeText(approval["module"], "");
  String get status => safeText(approval["status"], "pending");

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return const Color(0xff059669);
      case "rejected":
        return const Color(0xffDC2626);
      case "pending":
        return const Color(0xffD97706);
      default:
        return const Color(0xff64748B);
    }
  }

  IconData moduleIcon(String module) {
    switch (module.toLowerCase()) {
      case "customer":
        return Icons.business_outlined;
      case "lead":
        return Icons.trending_up;
      case "tender":
        return Icons.description_outlined;
      case "travel":
        return Icons.flight_takeoff;
      case "tada":
        return Icons.receipt_long;
      case "emdbg":
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.approval_outlined;
    }
  }

  Widget statusChip(String text) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget header() {
    final recordRef = safeText(approval["record_ref"], "-");
    final requestedBy = safeText(approval["requested_by_name"], "-");
    final typeLabel = approvalTypeLabel(approval);

    final customerName = safeText(
      summary["company_name"] ??
          summary["customer_name"] ??
          summary["employee_name"] ??
          summary["client_name"],
      "",
    );

    final purpose = safeText(
      summary["purpose"] ??
          summary["title"] ??
          summary["lead_title"] ??
          summary["instrument_type"],
      "",
    );

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(.18)),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(.18)),
                    ),
                    child: Icon(moduleIcon(module), color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.72),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: .6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recordRef,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusChip(safeText(approval["approval_display"], status)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _headerMini(Icons.person_outline, "Requested by $requestedBy"),
                  if (customerName.isNotEmpty)
                    _headerMini(Icons.business_outlined, customerName),
                  if (purpose.isNotEmpty)
                    _headerMini(Icons.local_offer_outlined, purpose),
                  _headerMini(Icons.calendar_today_outlined, fmtDate(approval["created_at"])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerMini(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(.64)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(.84),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String approvalTypeLabel(Map<String, dynamic> item) {
    final action = safeText(item["action"], "");
    final actionLabel = safeText(item["action_label"], "");
    final typeLabel = safeText(item["type_label"], "");

    if (typeLabel != "-") return typeLabel;

    const labels = {
      "tender_step1_manager": "Tender Basic Info Approval (Manager)",
      "tender_step1_ceo": "Tender Basic Info Approval (CEO)",
      "tender_step2_manager": "Tender Details Approval (Manager)",
      "tender_step2_ceo": "Tender Details Approval (CEO)",
      "tender_step3_manager": "Tender Workings Approval (Manager)",
      "tender_step3_ceo": "Tender Workings Approval (CEO)",
      "tender_po_manager": "Tender PO Details Approval (Manager)",
      "convert": "Lead Conversion Approval",
      "convert_lead_manager": "Lead Conversion Approval",
      "request": "Travel Request Approval",
      "expense": "TA/DA Expense Claim (Manager)",
      "expense_ceo": "TA/DA Expense Claim (CEO)",
      "release_request": "EMD/BG Release Approval",
      "create": "Customer Creation Approval",
    };

    return labels[action] ?? (actionLabel == "-" ? action : actionLabel);
  }

  Widget requesterCard() {
    final requestNotes = safeText(approval["request_notes"], "");
    final decisionNotes = safeText(approval["decision_notes"], "");
    final rejectionReason = safeText(approval["rejection_reason"], "");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: const Color(0xffEEF2FF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppColors.primaryLight,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Requested by ${safeText(approval["requested_by_name"], "-")}",
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                if (requestNotes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    requestNotes,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  fmtDate(approval["created_at"]),
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isPending && (decisionNotes.isNotEmpty || rejectionReason.isNotEmpty)) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: status == "rejected"
                          ? const Color(0xffFEF2F2)
                          : const Color(0xffECFDF5),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: status == "rejected"
                            ? const Color(0xffFECACA)
                            : const Color(0xffBBF7D0),
                      ),
                    ),
                    child: Text(
                      status == "rejected"
                          ? "Reason: ${rejectionReason.isNotEmpty ? rejectionReason : decisionNotes}"
                          : "Notes: $decisionNotes",
                      style: TextStyle(
                        color: status == "rejected"
                            ? const Color(0xffB91C1C)
                            : const Color(0xff047857),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }

  InputDecoration notesDecoration() {
    return InputDecoration(
      hintText: "Add your notes or reason for decision…",
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.primaryLight),
      ),
    );
  }

  Widget notesBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_outlined, size: 17, color: AppColors.textSoft),
              const SizedBox(width: 8),
              const Text(
                "Notes / Comments",
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              if (isPending) ...[
                const SizedBox(width: 5),
                const Text(
                  "· required for rejection",
                  style: TextStyle(
                    color: Color(0xffDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            enabled: isPending && !deciding,
            maxLines: 4,
            decoration: notesDecoration(),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoRow(String label, dynamic value, {bool highlight = false}) {
    final text = safeText(value, "");
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSoft,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isEmpty ? "—" : text,
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
                fontSize: highlight ? 13.5 : 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget infoPanel({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(title, icon, color),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: cardDecoration(),
          child: Column(children: children),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget summaryView() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (summary.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: cardDecoration(),
        child: const Center(
          child: Text(
            "No details available",
            style: TextStyle(
              color: AppColors.textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final type = safeText(summary["type"], module).toLowerCase();

    if (type == "travel") return travelSummary();
    if (type == "tada") return tadaSummary();
    if (type == "tender") return tenderSummary();
    if (type == "lead") return leadSummary();
    if (type == "customer") return customerSummary();
    if (type == "emdbg") return emdbgSummary();

    return genericSummary();
  }

  Widget genericSummary() {
    return infoPanel(
      title: "Approval Details",
      icon: Icons.info_outline,
      color: AppColors.primaryLight,
      children: summary.entries
          .map((e) => infoRow(e.key.toString(), e.value?.toString()))
          .toList(),
    );
  }

  Widget footer() {
    if (!isPending) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor(status).withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusColor(status).withOpacity(.22)),
                ),
                child: Text(
                  safeText(approval["approval_display"], status).toUpperCase(),
                  style: TextStyle(
                    color: statusColor(status),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton(
              onPressed: deciding ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSoft,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
              child: const Text("Cancel"),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: deciding ? null : () => decide("rejected"),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text("Reject"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffDC2626),
                  side: const BorderSide(color: Color(0xffFECACA), width: 1.4),
                  backgroundColor: const Color(0xffFEF2F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: deciding ? null : () => decide("approved"),
                icon: deciding
                    ? const SizedBox(
                  height: 17,
                  width: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text("Approve"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          header(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadSummary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  requesterCard(),
                  const SizedBox(height: 14),
                  summaryView(),
                  notesBox(),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
          footer(),
        ],
      ),
    );
  }
}


String safeText(dynamic value, [String fallback = "-"]) {
  final text = value?.toString().trim() ?? "";
  return text.isEmpty ? fallback : text;
}

String fmtDate(dynamic value) {
  final text = safeText(value, "");
  if (text.isEmpty) return "-";
  try {
    final dt = DateTime.parse(text);
    return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
  } catch (_) {
    return text.contains("T") ? text.split("T").first : text.split(" ").first;
  }
}

String money(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return "-";
  final n = num.tryParse(value.toString());
  if (n == null) return value.toString();
  return "₹${n.toStringAsFixed(0)}";
}