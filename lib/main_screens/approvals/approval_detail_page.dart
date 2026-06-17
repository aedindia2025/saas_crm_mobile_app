import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api_helpers/api_method.dart';

class ApprovalDetailColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primaryLight = Color(0xFF3060A0);
  static const Color bg = Color(0xffF4F7FB);
  static const Color border = Color(0xffE2E8F0);
  static const Color textDark = Color(0xff0F172A);
  static const Color textSoft = Color(0xff64748B);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryLight, primaryMedium, primaryDark, primaryDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

String safeText(dynamic value, [String fallback = '-']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

String fmtDate(dynamic value) {
  final text = safeText(value, '');
  if (text.isEmpty) return '-';
  try {
    final dt = DateTime.parse(text);
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  } catch (_) {
    return text.contains('T') ? text.split('T').first : text.split(' ').first;
  }
}

String money(dynamic value) {
  if (value == null || value.toString().trim().isEmpty) return '-';
  final n = num.tryParse(value.toString());
  if (n == null) return value.toString();
  return '₹${n.toStringAsFixed(0)}';
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

Map<String, dynamic> asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

bool hasValue(dynamic value) {
  final text = safeText(value, '');
  return text.isNotEmpty;
}

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

  bool get isDynamic => safeText(approval['kind'], '').toLowerCase() == 'dynamic';
  bool get isPending => safeText(approval['status'], '').toLowerCase() == 'pending';
  String get module => safeText(approval['module'], '').toLowerCase();
  String get status => safeText(approval['status'], 'pending').toLowerCase();

  @override
  void initState() {
    super.initState();
    approval = Map<String, dynamic>.from(widget.approval);
    loadSummary();
  }

  Future<void> loadSummary() async {
    if (mounted) setState(() => loading = true);

    if (isDynamic) {
      summary = asMap(approval['summary']);
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final response = await ApiMethod.getRequest(
        url: '${widget.apiBase}/approvals/${approval['id']}/summary',
        headers: widget.headers,
      );
      if (response['statusCode'] == 200) {
        final data = asMap(response['data']);
        if (mounted) {
          setState(() {
            approval = data.isEmpty ? approval : data;
            summary = asMap(approval['summary']);
          });
        }
      } else {
        showError('Failed to load approval details');
      }
    } catch (e) {
      showError('Approval details error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> decide(String decision) async {
    final notes = notesController.text.trim();
    if (decision == 'rejected' && notes.isEmpty) {
      showError('Please provide a reason for rejection.');
      return;
    }

    setState(() => deciding = true);
    try {
      final url = isDynamic
          ? '${widget.apiBase}/approval-workflows/requests/${approval['id']}/decision'
          : '${widget.apiBase}/approvals/${approval['id']}/decide';
      final body = isDynamic
          ? {'decision': decision, 'remarks': notes}
          : {
        'decision': decision,
        'notes': notes,
        'rejection_reason': decision == 'rejected' ? notes : null,
      };
      final response = await ApiMethod.postRequest(url: url, headers: widget.headers, body: body);
      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        showSuccess(decision == 'approved' ? 'Approved successfully' : 'Rejected - requester will be notified');
        if (mounted) Navigator.pop(context, true);
      } else {
        final data = asMap(response['data']);
        showError(safeText(data['detail'] ?? data['error'], 'Approval action failed'));
      }
    } catch (e) {
      showError('Approval request failed: $e');
    } finally {
      if (mounted) setState(() => deciding = false);
    }
  }

  void showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green.shade700, content: Text(message)));
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text(message)));
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xff059669);
      case 'rejected':
        return const Color(0xffDC2626);
      case 'pending':
        return const Color(0xffD97706);
      default:
        return ApprovalDetailColors.textSoft;
    }
  }

  IconData moduleIcon(String module) {
    switch (module.toLowerCase()) {
      case 'customer':
      case 'customers':
        return Icons.business_outlined;
      case 'lead':
      case 'leads':
        return Icons.trending_up;
      case 'tender':
      case 'tenders':
        return Icons.description_outlined;
      case 'travel':
        return Icons.flight_takeoff;
      case 'tada':
        return Icons.receipt_long;
      case 'emdbg':
        return Icons.account_balance_wallet_outlined;
      case 'quotation':
        return Icons.request_quote_outlined;
      default:
        return Icons.approval_outlined;
    }
  }

  String approvalTypeLabel(Map<String, dynamic> item) {
    final action = safeText(item['action'], '');
    final actionLabel = safeText(item['action_label'], '');
    final typeLabel = safeText(item['type_label'], '');
    if (typeLabel != '-') return typeLabel;
    const labels = {
      'tender_step1_manager': 'Tender Basic Info Approval (Manager)',
      'tender_step1_ceo': 'Tender Basic Info Approval (CEO)',
      'tender_step2_manager': 'Tender Details Approval (Manager)',
      'tender_step2_ceo': 'Tender Details Approval (CEO)',
      'tender_step3_manager': 'Tender Workings Approval (Manager)',
      'tender_step3_ceo': 'Tender Workings Approval (CEO)',
      'tender_po_manager': 'Tender PO Details Approval (Manager)',
      'convert': 'Lead Conversion Approval',
      'convert_lead_manager': 'Lead Conversion Approval',
      'request': 'Travel Request Approval',
      'expense': 'TA/DA Expense Claim (Manager)',
      'expense_ceo': 'TA/DA Expense Claim (CEO)',
      'release_request': 'EMD/BG Release Approval',
      'submit': 'Quotation Approval',
      'create': 'Customer Creation Approval',
    };
    return labels[action] ?? (actionLabel == '-' ? action : actionLabel);
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: ApprovalDetailColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 14, offset: const Offset(0, 7))],
    );
  }

  Widget infoRow(String label, dynamic value, {bool highlight = false}) {
    final text = safeText(value, '');
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: ApprovalDetailColors.textSoft, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: highlight ? ApprovalDetailColors.textDark : const Color(0xff334155),
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13.2,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 9),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Expanded(child: Text(title, style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900, fontSize: 14))),
        ],
      ),
    );
  }

  Widget infoPanel({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    final visible = children.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 17), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900, fontSize: 14)))]),
          const SizedBox(height: 9),
          const Divider(height: 1, color: ApprovalDetailColors.border),
          const SizedBox(height: 2),
          ...visible,
        ],
      ),
    );
  }

  Widget amountTile(String title, String value, {bool green = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: green ? const Color(0xffECFDF5) : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green ? const Color(0xffBBF7D0) : ApprovalDetailColors.border),
      ),
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: green ? const Color(0xff047857) : ApprovalDetailColors.textDark, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 5),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: ApprovalDetailColors.textSoft, fontWeight: FontWeight.w700, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget header() {
    final recordRef = safeText(approval['record_ref'], '-');
    final requestedBy = safeText(approval['requested_by_name'], '-');
    final typeLabel = approvalTypeLabel(approval);
    final customerName = safeText(summary['company_name'] ?? summary['customer_name'] ?? summary['employee_name'] ?? summary['client_name'], '');
    final purpose = safeText(summary['purpose'] ?? summary['title'] ?? summary['lead_title'] ?? summary['subject'] ?? summary['instrument_type'], '');

    return Container(
      decoration: const BoxDecoration(gradient: ApprovalDetailColors.headerGradient),
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
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(.18))),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 19),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.18))),
                    child: Icon(moduleIcon(module), color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.72), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .6)),
                        const SizedBox(height: 3),
                        Text(recordRef, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: Text(safeText(approval['approval_display'], status).toUpperCase(), style: TextStyle(color: statusColor(status), fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _headerMini(Icons.person_outline, 'Requested by $requestedBy'),
                  if (customerName.isNotEmpty) _headerMini(Icons.business_outlined, customerName),
                  if (purpose.isNotEmpty) _headerMini(Icons.local_offer_outlined, purpose),
                  _headerMini(Icons.calendar_today_outlined, fmtDate(approval['created_at'] ?? approval['requested_at'])),
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
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.84), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget requesterCard() {
    final requestNotes = safeText(approval['request_notes'], '');
    final decisionNotes = safeText(approval['decision_notes'], '');
    final rejectionReason = safeText(approval['rejection_reason'], '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 39, width: 39, decoration: BoxDecoration(color: const Color(0xffEEF2FF), borderRadius: BorderRadius.circular(13), border: Border.all(color: ApprovalDetailColors.border)), child: const Icon(Icons.person_outline, color: ApprovalDetailColors.primaryLight, size: 19)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Requested by ${safeText(approval['requested_by_name'], '-')}', style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900, fontSize: 14)),
                if (requestNotes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(requestNotes, style: const TextStyle(color: ApprovalDetailColors.textSoft, fontWeight: FontWeight.w600, height: 1.35)),
                ],
                const SizedBox(height: 6),
                Text(fmtDate(approval['created_at'] ?? approval['requested_at']), style: const TextStyle(color: ApprovalDetailColors.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700)),
                if (!isPending && (decisionNotes.isNotEmpty || rejectionReason.isNotEmpty)) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: status == 'rejected' ? const Color(0xffFEF2F2) : const Color(0xffECFDF5),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: status == 'rejected' ? const Color(0xffFECACA) : const Color(0xffBBF7D0)),
                    ),
                    child: Text(status == 'rejected' ? 'Reason: ${rejectionReason.isNotEmpty ? rejectionReason : decisionNotes}' : 'Notes: $decisionNotes', style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w700, height: 1.3)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget summaryView() {
    if (loading) {
      return Container(padding: const EdgeInsets.all(32), decoration: cardDecoration(), child: const Center(child: CircularProgressIndicator()));
    }
    if (summary.isEmpty) {
      return infoPanel(title: 'Summary', icon: Icons.info_outline, color: ApprovalDetailColors.primaryLight, children: [infoRow('Message', 'No summary data available')]);
    }
    final type = safeText(summary['type'], module).toLowerCase();
    if (type == 'tender' || module == 'tender') return tenderSummary();
    if (type == 'lead' || module == 'lead') return leadSummary();
    if (type == 'travel' || module == 'travel') return travelSummary();
    if (type == 'tada' || module == 'tada') return tadaSummary();
    if (type == 'emdbg' || module == 'emdbg') return emdbgSummary();
    if (type == 'customer' || module == 'customer') return customerSummary();
    if (type == 'quotation' || module == 'quotation') return quotationSummary();
    return genericSummary(summary);
  }

  Widget travelSummary() {
    return Column(children: [
      infoPanel(title: 'Tab 1 — Trip Summary', icon: Icons.flight_takeoff, color: const Color(0xff2563EB), children: [
        infoRow('Employee', summary['employee_name'], highlight: true),
        infoRow('Request No.', summary['request_number']),
        infoRow('Purpose', summary['purpose'], highlight: true),
        infoRow('Visit Type', summary['visit_type']),
        infoRow('Source', safeText(summary['source'], '').toLowerCase() == 'kam' ? 'KAM' : 'Direct'),
        infoRow('From City', summary['from_city']),
        infoRow('To City', summary['to_city']),
        infoRow('Travel Date', summary['travel_date']),
        infoRow('Return Date', summary['return_date']),
        infoRow('Total Days', '${safeText(summary['total_days'], '1')} day(s)'),
        infoRow('Outside District / City', summary['is_outside_district'] == true ? 'Yes' : 'No'),
      ]),
      infoPanel(title: 'Tab 2 — CRM Linkage', icon: Icons.business_outlined, color: const Color(0xff0284C7), children: [
        infoRow('Account / Customer', summary['account_name'], highlight: true),
        infoRow('Contact Person', summary['contact_name']),
        infoRow('Contact Phone', summary['contact_phone']),
        infoRow('Lead / Reference ID', summary['lead_ref'] ?? summary['lead_id']),
        infoRow('Linked Opportunity', summary['opportunity_id']),
        infoRow('Linked Tender', summary['tender_label'] ?? summary['tender_id']),
        infoRow('KAM Activity', summary['kam_activity_subject']),
      ]),
      infoPanel(title: 'Tab 3 — Travel & Budgets', icon: Icons.account_balance_wallet_outlined, color: const Color(0xff059669), children: [
        infoRow('Transport Mode', summary['transport_mode']),
        infoRow('Vehicle Number', summary['vehicle_number']),
        infoRow('Estimated KMs', summary['estimated_kms']),
        infoRow('Booking Ref', summary['advance_booking_ref']),
        infoRow('Estimated Total', money(summary['estimated_total']), highlight: true),
        infoRow('Advance Required', summary['advance_required'] == true ? 'Yes' : 'No'),
        infoRow('Advance Amount', money(summary['advance_amount'])),
        infoRow('Cost Center', summary['cost_center']),
        infoRow('Budget Code', summary['budget_code']),
      ]),
      infoPanel(title: 'Tab 4 — Accommodation', icon: Icons.home_outlined, color: const Color(0xff7C3AED), children: [
        infoRow('Accommodation Required', summary['accommodation_required'] == true ? 'Yes' : 'No'),
        infoRow('Accommodation Type', summary['accommodation_type']),
        infoRow('Hotel Name', summary['hotel_name']),
        infoRow('Check-in Date', summary['check_in_date']),
        infoRow('Check-out Date', summary['check_out_date']),
        infoRow('Accommodation Cost', money(summary['accommodation_cost'])),
      ]),
      infoPanel(title: 'Tab 5 — Additional Info', icon: Icons.notes_outlined, color: const Color(0xffD97706), children: [
        infoRow('Travel Companions', summary['companions']),
        infoRow('Status', summary['status']),
        infoRow('Notes / Remarks', summary['notes']),
      ]),
    ]);
  }

  Widget tadaSummary() {
    final items = asMapList(summary['line_items']);
    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(children: [
          Expanded(child: amountTile('Total Amount', money(summary['total_amount']))),
          const SizedBox(width: 8),
          Expanded(child: amountTile('Advance Taken', money(summary['advance_taken']))),
          const SizedBox(width: 8),
          Expanded(child: amountTile('Net Payable', money(summary['net_payable']), green: true)),
        ]),
      ),
      infoPanel(title: 'Claim Details', icon: Icons.receipt_long, color: ApprovalDetailColors.primaryLight, children: [
        infoRow('Employee', summary['employee_name'], highlight: true),
        infoRow('Claim No.', summary['claim_number']),
        infoRow('Purpose', summary['purpose'], highlight: true),
        infoRow('Claim Date', summary['claim_date']),
        infoRow('Travel From', summary['travel_date_from']),
        infoRow('Travel To', summary['travel_date_to']),
        infoRow('Status', summary['overall_status']),
      ]),
      sectionTitle('Expense Items (${items.length})', Icons.payments_outlined, const Color(0xff059669)),
      if (items.isEmpty) emptyMini('No expense line items') else ...items.map(expenseItemCard),
    ]);
  }

  Widget expenseItemCard(Map<String, dynamic> item) {
    final attachments = asMapList(item['attachments']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(safeText(item['description'], 'Expense'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        infoRow('Category', item['category']),
        infoRow('Amount', money(item['amount']), highlight: true),
        infoRow('Expense Date', item['expense_date']),
        infoRow('From Place', item['from_place']),
        infoRow('To Place', item['to_place']),
        if (attachments.isNotEmpty) ...[
          const Divider(color: ApprovalDetailColors.border),
          ...attachments.map(documentRow),
        ],
      ]),
    );
  }

  Widget leadSummary() {
    final products = asMapList(summary['products']);
    return Column(children: [
      infoPanel(title: 'Lead Overview', icon: Icons.trending_up, color: const Color(0xff7C3AED), children: [
        infoRow('Lead Title', summary['title'] ?? summary['lead_title'], highlight: true),
        infoRow('Company', summary['company_name'] ?? summary['customer_name'], highlight: true),
        infoRow('Lead Type', summary['lead_type']),
        infoRow('Status', summary['status']),
        infoRow('Source', summary['source']),
        infoRow('Priority', summary['priority']),
        infoRow('Region', summary['region']),
        infoRow('Industry', summary['industry']),
        infoRow('Assigned To', summary['assigned_to_name']),
        infoRow('Created By', summary['created_by_name']),
      ]),
      infoPanel(title: 'Contact Information', icon: Icons.contact_phone_outlined, color: const Color(0xff0284C7), children: [
        infoRow('Contact Person', summary['contact_person'] ?? summary['contact_name']),
        infoRow('Email', summary['email']),
        infoRow('Phone', summary['phone']),
      ]),
      infoPanel(title: 'Opportunity Details', icon: Icons.workspace_premium_outlined, color: const Color(0xff059669), children: [
        infoRow('Est. Value', money(summary['estimated_value'] ?? summary['est_value']), highlight: true),
        infoRow('Probability', hasValue(summary['probability']) ? '${summary['probability']}%' : null),
        infoRow('Expected Close', summary['expected_close_date']),
        infoRow('Deal Stage', summary['deal_stage']),
        infoRow('Opportunity Type', summary['opportunity_type']),
      ]),
      infoPanel(title: 'Requirements & Notes', icon: Icons.description_outlined, color: const Color(0xffD97706), children: [
        infoRow('Description', summary['description']),
        infoRow('Requirements', summary['requirements']),
        infoRow('Notes', summary['notes']),
      ]),
      sectionTitle('Products / Items (${products.length})', Icons.inventory_2_outlined, const Color(0xff7C3AED)),
      if (products.isEmpty) emptyMini('No products added to this lead') else ...products.map(productCard),
    ]);
  }

  Widget customerSummary() {
    final contacts = asMapList(summary['contacts']);
    final billing = asMapList(summary['billing_consignees']);
    final shipping = asMapList(summary['shipping_consignees']);
    return Column(children: [
      infoPanel(title: 'Account Details', icon: Icons.business_outlined, color: const Color(0xff0284C7), children: [
        infoRow('Customer Name', summary['customer_name'], highlight: true),
        infoRow('Account Status', summary['account_status']),
        infoRow('Potential', summary['account_potential']),
        infoRow('Potential Value', money(summary['potential_value'])),
        infoRow('Industry', summary['industry']),
        infoRow('Vertical', summary['customer_vertical']),
        infoRow('Division', summary['division']),
        infoRow('Group', summary['group_name']),
        infoRow('Owner / KAM', summary['assigned_to_name']),
        infoRow('Created By', summary['created_by_name']),
      ]),
      infoPanel(title: 'Legal & Financial', icon: Icons.credit_card, color: ApprovalDetailColors.primaryLight, children: [
        infoRow('GST Number', summary['gst_number']),
        infoRow('PAN Number', summary['pan_number']),
        infoRow('Annual Revenue', money(summary['annual_revenue'])),
        infoRow('Employee Count', summary['employee_count']),
        infoRow('Website', summary['website']),
      ]),
      infoPanel(title: 'Billing Address', icon: Icons.location_on_outlined, color: const Color(0xffEA580C), children: [infoRow('Address', summary['billing_address'], highlight: true)]),
      infoPanel(title: 'Shipping Address', icon: Icons.local_shipping_outlined, color: const Color(0xff0F766E), children: [infoRow('Address', summary['shipping_same_as_billing'] == true ? 'Same as billing' : summary['shipping_address'], highlight: true)]),
      sectionTitle('Contacts (${contacts.length})', Icons.people_outline, const Color(0xff7C3AED)),
      if (contacts.isEmpty) emptyMini('No contacts') else ...contacts.map(contactCard),
      simpleListSection('Billing Consignees', billing),
      simpleListSection('Shipping Consignees', shipping),
      infoPanel(title: 'Remarks', icon: Icons.notes_outlined, color: const Color(0xffD97706), children: [infoRow('Remarks', summary['remarks'])]),
    ]);
  }

  Widget emdbgSummary() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(children: [
          Expanded(child: amountTile('Instrument Type', safeText(summary['instrument_type']))),
          const SizedBox(width: 8),
          Expanded(child: amountTile('Amount', money(summary['amount']), green: true)),
        ]),
      ),
      infoPanel(title: 'Client & Tender', icon: Icons.business_outlined, color: const Color(0xffEA580C), children: [
        infoRow('Client', summary['client_name'], highlight: true),
        infoRow('Tender No.', summary['tender_num']),
        infoRow('Tender Title', summary['tender_title']),
        infoRow('PO Number', summary['po_number']),
        infoRow('PO Date', summary['po_date']),
        infoRow('WO Value', money(summary['wo_value'])),
      ]),
      infoPanel(title: 'Instrument Details', icon: Icons.account_balance_wallet_outlined, color: const Color(0xff0F766E), children: [
        infoRow('Reference No.', summary['reference_num'], highlight: true),
        infoRow('Bank', summary['bank_name']),
        infoRow('Bank Branch', summary['bank_branch']),
        infoRow('Instrument No.', summary['instrument_number']),
        infoRow('Issued Date', summary['issued_date']),
        infoRow('Submitted', summary['submitted_date']),
        infoRow('Valid From', summary['valid_from']),
        infoRow('Expiry Date', summary['expiry_date'], highlight: true),
        infoRow('Status', summary['status']),
        infoRow('Approval Status', summary['approval_status']),
        infoRow('Purpose', summary['purpose']),
        infoRow('Notes', summary['notes']),
        infoRow('Created By', summary['created_by_name']),
        infoRow('Document', summary['instrument_document_url']),
      ]),
    ]);
  }

  Widget quotationSummary() {
    final items = asMapList(summary['line_items']);
    return Column(children: [
      infoPanel(title: 'Quotation Details', icon: Icons.request_quote_outlined, color: const Color(0xff059669), children: [
        infoRow('Quotation No.', summary['quotation_number'], highlight: true),
        infoRow('Revision', hasValue(summary['revision_number']) ? 'Q${summary['revision_number']}' : null),
        infoRow('Subject', summary['subject'], highlight: true),
        infoRow('Customer', summary['customer_name']),
        infoRow('Source / Ref', summary['source_ref'] ?? summary['source_title']),
        infoRow('Valid Until', summary['valid_until']),
        infoRow('Status', summary['status']),
        infoRow('Approval Status', summary['approval_status']),
      ]),
      infoPanel(title: 'Financials', icon: Icons.currency_rupee, color: const Color(0xff059669), children: [
        infoRow('Subtotal', money(summary['amount'])),
        infoRow('Tax', money(summary['tax_amount'])),
        infoRow('Grand Total', money(summary['total_amount']), highlight: true),
      ]),
      sectionTitle('Line Items (${items.length})', Icons.inventory_2_outlined, const Color(0xff2563EB)),
      if (items.isEmpty) emptyMini('No line items') else ...items.map(quotationItemCard),
      infoPanel(title: 'Notes & Terms', icon: Icons.notes_outlined, color: const Color(0xffD97706), children: [
        infoRow('Notes', summary['notes']),
        infoRow('Terms', summary['terms_conditions']),
      ]),
    ]);
  }

  Widget tenderSummary() {
    final step1 = asMap(summary['step1']);
    final step2 = asMap(summary['step2']);
    final step3 = asMap(summary['step3']);
    final step4 = asMap(summary['step4']);
    final step5 = asMap(summary['step5']);
    final step7 = asMap(summary['step7']);
    final products = asMapList(step1['products']);
    final finalProducts = asMapList(step3['final_products']);
    final bidders = asMapList(step4['bidders']);
    final documents = asMapList(summary['documents']);
    final poDocuments = asMapList(step7['po_documents']);
    final loss = asMap(step5['loss_analysis']);

    return Column(children: [
      infoPanel(title: 'Tab 1 — Basic Info', icon: Icons.description_outlined, color: const Color(0xffEA580C), children: [
        infoRow('Customer', step1['customer_name'], highlight: true),
        infoRow('Tender Title', step1['tender_title'], highlight: true),
        infoRow('Portal Ref No.', step1['portal_ref_number']),
        infoRow('Est. Value', money(step1['est_value'])),
        infoRow('Source Portal', step1['source_portal']),
        infoRow('Stage', step1['tender_status']),
        infoRow('Published Date', step1['published_date']),
        infoRow('Pre-Bid Date', step1['pre_bid_date']),
        infoRow('Submission Date', step1['submission_date']),
        infoRow('Assigned To', step1['assigned_to_name']),
        documentLinkRow(
          label: 'RFP Document',
          value: step1['rfp_document'],
          fileName: 'RFP Document',
        ),
      ]),
      sectionTitle('Products / BOQ (${products.length})', Icons.inventory_2_outlined, ApprovalDetailColors.primaryLight),
      if (products.isEmpty) emptyMini('No products / BOQ') else ...products.map(productCard),
      infoPanel(title: 'Tab 2 — Tender Details / Financials', icon: Icons.payments_outlined, color: const Color(0xffD97706), children: [
        infoRow('Tender Fee Required', step2['tender_fee_required'] == true ? 'Yes' : 'No'),
        infoRow('Tender Fee Amount', money(step2['tender_fee_amount'])),
        infoRow('Tender Fee Method', step2['tender_fee_method']),
        infoRow('EMD Required', step2['emd_required'] == true ? 'Yes' : 'No'),
        infoRow('EMD Amount', money(step2['emd_amount'])),
        infoRow('EMD Method', step2['emd_payment_method']),
        infoRow('EMD Bank', step2['emd_bank_name']),
        infoRow('PBG Required', step2['pbg_required'] == true ? 'Yes' : 'No'),
        infoRow('PBG Amount', money(step2['pbg_amount'])),
        infoRow('Split Order', step2['split_order'] == true ? 'Yes' : 'No'),
        infoRow('Reverse Auction', step2['reverse_auction'] == true ? 'Yes' : 'No'),
      ]),
      if (step3.isNotEmpty) ...[
        infoPanel(title: 'Tab 3 — Workings', icon: Icons.layers_outlined, color: ApprovalDetailColors.primaryLight, children: [
          infoRow('Corrigendum Document', step3['corrigendum_document']),
          infoRow('Workings Document', step3['workings_document']),
        ]),
        sectionTitle('Final BOQ (${finalProducts.length})', Icons.fact_check_outlined, ApprovalDetailColors.primaryLight),
        if (finalProducts.isEmpty) emptyMini('No final BOQ') else ...finalProducts.map(finalProductCard),
      ],
      if (step4.isNotEmpty) ...[
        infoPanel(title: 'Tab 4 — Tech Bid', icon: Icons.verified_outlined, color: const Color(0xff0F766E), children: [
          infoRow('Eligibility', step4['tech_bid_eligible'], highlight: true),
        ]),
        sectionTitle('Bidders (${bidders.length})', Icons.groups_outlined, const Color(0xff0F766E)),
        if (bidders.isEmpty) emptyMini('No bidders') else ...bidders.map(bidderCard),
      ],
      if (step5.isNotEmpty) ...[
        infoPanel(title: 'Tab 5 — Result', icon: Icons.emoji_events_outlined, color: const Color(0xff059669), children: [
          infoRow('Result', step5['result'], highlight: true),
          infoRow('Result Date', step5['result_date']),
          infoRow('Our Bid Amount', money(step5['bid_amount'])),
          infoRow('RA Final Bid', money(step5['reverse_auction_final_bid'])),
        ]),
        if (loss.isNotEmpty)
          infoPanel(title: 'Loss Analysis', icon: Icons.bar_chart_outlined, color: const Color(0xffDC2626), children: [
            infoRow('Our Position', loss['our_position']),
            infoRow('Competitor', loss['competitor_name']),
            infoRow('Competitor Amount', money(loss['competitor_amount'])),
            infoRow('Our Bid Amount', money(loss['our_bid_amount'])),
            infoRow('L1', '${safeText(loss['l1_company'], '')} ${money(loss['l1_amount'])}'),
            infoRow('L2', '${safeText(loss['l2_company'], '')} ${money(loss['l2_amount'])}'),
            infoRow('L3', '${safeText(loss['l3_company'], '')} ${money(loss['l3_amount'])}'),
            infoRow('Reason', loss['loss_reason']),
          ]),
      ],
      if (step7.isNotEmpty) ...[
        infoPanel(title: 'Tab 6 — PO Details', icon: Icons.assignment_turned_in_outlined, color: const Color(0xff2563EB), children: [
          infoRow('PO Number', step7['po_num'], highlight: true),
          infoRow('PO Date', step7['po_date']),
          infoRow('PO Value', money(step7['po_value'])),
          infoRow('No. of Consignees', step7['no_of_consignee']),
          infoRow('Delivery Date', step7['dlvry_date']),
          infoRow('Completion Days', step7['completion_days']),
          infoRow('Completion Date', step7['completion_date']),
          infoRow('Warranty Months', step7['wrnty_mth']),
          infoRow('Site Engineer', step7['site_eng']),
          infoRow('Engineer Phone', step7['eng_phone']),
          infoRow('Penalty / LD', step7['penalty'] == true ? 'Yes' : 'No'),
          infoRow('LD Type', step7['ld_type']),
          infoRow('LD Percent', step7['ld_percent']),
          infoRow('Payment Terms', step7['pmnt_terms']),
          infoRow('Scope of Work', step7['sow']),
        ]),
        if (poDocuments.isNotEmpty) ...[
          sectionTitle('PO Documents (${poDocuments.length})', Icons.folder_copy_outlined, const Color(0xff2563EB)),
          ...poDocuments.map(documentRow),
        ],
      ],
      sectionTitle('All Documents (${documents.length})', Icons.folder_copy_outlined, ApprovalDetailColors.primaryLight),
      if (documents.isEmpty) emptyMini('No documents available') else ...documents.map(documentRow),
    ]);
  }

  Widget productCard(Map<String, dynamic> p) {
    final oems = asMapList(p['oems']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(safeText(p['product_name'] ?? p['name'], 'Product'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        infoRow('OEM / Brand', p['oem_name'] ?? p['brand']),
        infoRow('Quantity', p['quantity'] ?? p['qty']),
        infoRow('Unit Price', money(p['unit_price'] ?? p['price'])),
        infoRow('GST %', p['gst_percent']),
        infoRow('Works Item', p['is_works_item'] == true ? 'Yes' : null),
        infoRow('Work Type', p['work_type']),
        infoRow('Work Unit', p['work_unit']),
        infoRow('Work Unit Rate', money(p['work_unit_rate'])),
        infoRow('Total Price', money(p['total_price'] ?? p['amount']), highlight: true),
        infoRow('Specification', p['specification']),
        if (oems.isNotEmpty) ...[
          const Divider(color: ApprovalDetailColors.border),
          ...oems.map((o) => infoRow('OEM', '${safeText(o['oem_name'])} ${hasValue(o['authorization_num']) ? '· Auth: ${o['authorization_num']}' : ''} ${o['is_preferred'] == true ? '· Preferred' : ''}')),
        ],
      ]),
    );
  }

  Widget finalProductCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(safeText(p['product_name'], 'Product'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        infoRow('OEM', p['oem_name']),
        infoRow('Authorization No.', p['authorization_num']),
        infoRow('Quantity', p['quantity']),
        infoRow('Unit Price', money(p['unit_price'])),
        infoRow('GST %', p['gst_percent']),
        infoRow('Works Item', p['is_works_item'] == true ? 'Yes' : null),
        infoRow('Work Type', p['work_type']),
        infoRow('Total Price', money(p['total_price']), highlight: true),
      ]),
    );
  }

  Widget bidderCard(Map<String, dynamic> b) {
    final items = asMapList(b['items']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(safeText(b['bidder_name'], 'Bidder'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        infoRow('Bidder Type', b['bidder_type']),
        if (items.isNotEmpty) ...[
          const Divider(color: ApprovalDetailColors.border),
          ...items.map((i) => infoRow('Item', '${safeText(i['product_name'])}${hasValue(i['oem_name']) ? ' · ${i['oem_name']}' : ''}')),
        ],
      ]),
    );
  }

  Widget quotationItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(safeText(item['description'], 'Line item'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        infoRow('Quantity', item['quantity']),
        infoRow('Unit Price', money(item['unit_price'])),
        infoRow('Tax %', item['tax_percent']),
        infoRow('Line Total', money(item['line_total']), highlight: true),
      ]),
    );
  }

  Widget contactCard(Map<String, dynamic> ct) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(safeText(ct['contact_name'], 'Contact'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900))),
          if (ct['is_primary'] == true)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xffDBEAFE), borderRadius: BorderRadius.circular(20)), child: const Text('Primary', style: TextStyle(color: Color(0xff1D4ED8), fontWeight: FontWeight.w900, fontSize: 10))),
        ]),
        const SizedBox(height: 6),
        infoRow('Designation', ct['designation']),
        infoRow('Department', ct['department']),
        infoRow('Mobile', ct['mobile']),
        infoRow('Office Phone', ct['office_phone']),
        infoRow('Office Email', ct['office_email']),
        infoRow('Personal Email', ct['personal_email']),
      ]),
    );
  }

  Widget simpleListSection(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      sectionTitle('$title (${items.length})', Icons.list_alt_outlined, ApprovalDetailColors.primaryLight),
      ...items.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(safeText(e['name'], '-'), style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(safeText(e['address'], '-'), style: const TextStyle(color: ApprovalDetailColors.textSoft, fontWeight: FontWeight.w600, height: 1.35)),
        ]),
      )),
    ]);
  }

  String _rawFilePath(dynamic value) {
    final text = safeText(value, '');
    if (text.isEmpty || text == '-') return '';
    return text;
  }

  String _fileNameFromPath(String path, String fallback) {
    if (path.isEmpty) return fallback;
    final cleanPath = path.split('?').first;
    final parts = cleanPath.split('/');
    final name = parts.isEmpty ? '' : parts.last.trim();
    return name.isEmpty ? fallback : Uri.decodeComponent(name);
  }

  String _previewUrl(String rawPath) {
    final path = _rawFilePath(rawPath);
    if (path.isEmpty) return '';

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final apiBase = widget.apiBase.replaceAll(RegExp(r'/$'), '');
    final tenant = widget.headers['X-Tenant-Slug'] ?? widget.headers['x-tenant-slug'] ?? '';
    final auth = widget.headers['Authorization'] ?? widget.headers['authorization'] ?? '';
    final token = auth.toLowerCase().startsWith('bearer ') ? auth.substring(7).trim() : auth.trim();

    final params = <String, String>{'path': path};
    if (token.isNotEmpty) params['token'] = token;
    if (tenant.isNotEmpty) params['tenant'] = tenant;

    return Uri.parse('$apiBase/preview/file').replace(queryParameters: params).toString();
  }

  Future<void> _openFile(String rawPath) async {
    final url = _previewUrl(rawPath);
    if (url.isEmpty) {
      showError('File path not available');
      return;
    }

    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) showError('Unable to open file');
  }

  IconData _fileIcon(String path) {
    final lower = path.toLowerCase().split('?').first;
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) return Icons.image_outlined;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) return Icons.table_chart_outlined;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget documentLinkRow({
    required String label,
    required dynamic value,
    String fileName = 'File',
  }) {
    final file = _rawFilePath(value);
    if (file.isEmpty) return const SizedBox.shrink();
    final name = _fileNameFromPath(file, fileName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(color: ApprovalDetailColors.textSoft, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openFile(file),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ApprovalDetailColors.border),
                ),
                child: Row(children: [
                  Icon(_fileIcon(file), size: 17, color: ApprovalDetailColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.visibility_outlined, size: 16, color: ApprovalDetailColors.primaryLight),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget documentRow(Map<String, dynamic> doc) {
    final file = _rawFilePath(doc['file_url'] ?? doc['preview_url'] ?? doc['file_path'] ?? doc['path'] ?? doc['url']);
    final fileName = safeText(doc['file_name'] ?? doc['name'], _fileNameFromPath(file, 'Document'));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_fileIcon(file), color: ApprovalDetailColors.primaryLight, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900))),
          if (file.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openFile(file),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: ApprovalDetailColors.primaryLight,
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        infoRow('Type', doc['doc_type']),
        infoRow('Size', hasValue(doc['file_size_kb']) ? '${doc['file_size_kb']} KB' : null),
        infoRow('Uploaded', doc['uploaded_at']),
        documentLinkRow(label: 'File', value: file, fileName: fileName),
      ]),
    );
  }

  Widget genericSummary(Map<String, dynamic> data) {
    final rows = <Widget>[];
    data.forEach((key, value) {
      if (value is Map || value is List) return;
      rows.add(infoRow(key.replaceAll('_', ' ').toUpperCase(), value));
    });
    return infoPanel(title: 'Approval Summary', icon: Icons.info_outline, color: ApprovalDetailColors.primaryLight, children: rows.isEmpty ? [infoRow('Message', 'No displayable fields')] : rows);
  }

  Widget emptyMini(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: ApprovalDetailColors.textSoft, fontWeight: FontWeight.w700)),
    );
  }

  Widget notesBox() {
    if (!isPending) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Decision Notes', style: TextStyle(color: ApprovalDetailColors.textDark, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Add approval notes or rejection reason',
            filled: true,
            fillColor: const Color(0xffF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ApprovalDetailColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ApprovalDetailColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ApprovalDetailColors.primaryLight, width: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget footer() {
    if (!isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ApprovalDetailColors.border))),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
              child: Text(
                'Status: ${safeText(approval['approval_display'], status).toUpperCase()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor(status),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              height: 40,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ),
          ]),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: Colors.white, border: const Border(top: BorderSide(color: ApprovalDetailColors.border)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 14, offset: const Offset(0, -4))]),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: deciding ? null : () => decide('rejected'),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xffDC2626), side: const BorderSide(color: Color(0xffFECACA), width: 1.3), backgroundColor: const Color(0xffFEF2F2), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: deciding ? null : () => decide('approved'),
              icon: deciding ? const SizedBox(height: 17, width: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff059669), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ]),
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
      backgroundColor: ApprovalDetailColors.bg,
      body: Column(children: [
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
      ]),
    );
  }
}
