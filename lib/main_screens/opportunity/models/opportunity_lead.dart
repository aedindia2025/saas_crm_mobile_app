// models/opportunity_lead.dart
//
// Mirrors the `OpportunityLead` TS interface from OpportunityView.tsx plus the
// product/oem shapes used across the tabs.

import 'package:intl/intl.dart';

class OemEntry {
  int? oemId;
  String oemName;
  OemEntry({this.oemId, this.oemName = ''});

  factory OemEntry.fromJson(Map<String, dynamic> j) =>
      OemEntry(oemId: j['oem_id'], oemName: (j['oem_name'] ?? '').toString());

  Map<String, dynamic> toJson() => {'oem_id': oemId, 'oem_name': oemName};
}

class ProdEntry {
  int? productId;
  String productName;
  String quantity;
  String description;
  List<OemEntry> oems;

  ProdEntry({
    this.productId,
    this.productName = '',
    this.quantity = '1',
    this.description = '',
    List<OemEntry>? oems,
  }) : oems = oems ?? [OemEntry()];

  factory ProdEntry.fromJson(Map<String, dynamic> j) {
    final oemsRaw = (j['oems'] as List?) ?? [];
    final oems = oemsRaw
        .map((o) => OemEntry.fromJson(Map<String, dynamic>.from(o)))
        .toList();
    return ProdEntry(
      productId: j['product_id'],
      productName: (j['product_name'] ?? '').toString(),
      quantity: (j['quantity'] ?? 1).toString(),
      description: (j['description'] ?? '').toString(),
      oems: oems.isEmpty ? [OemEntry()] : oems,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': int.tryParse(quantity) ?? 1,
        'description': description,
        'oems': oems
            .where((o) => o.oemName.trim().isNotEmpty)
            .map((o) => o.toJson())
            .toList(),
      };
}

class OpportunityLead {
  final int id;
  final String leadRefId;
  final String? opportunityRefId;
  final String leadTitle;
  final String? leadType;
  final int? customerId;
  final String? customerName;
  final String? customerAddress;
  final String? department;
  final String? contactPerson;
  final String? designation;
  final String? mobile;
  final String? email;
  final num? estValue;
  final String? priority;
  final String status;
  final String? region;
  final String? branch;
  final String? notes;
  final String? timeline;
  final String? followUp;
  final String? productDescription;
  final List<dynamic> products;
  final int? assignedTo;
  final String? assignedToName;
  final int? sourceId;
  final String? createdAt;
  final String? opportunityCreatedAt;

  OpportunityLead({
    required this.id,
    required this.leadRefId,
    this.opportunityRefId,
    required this.leadTitle,
    this.leadType,
    this.customerId,
    this.customerName,
    this.customerAddress,
    this.department,
    this.contactPerson,
    this.designation,
    this.mobile,
    this.email,
    this.estValue,
    this.priority,
    required this.status,
    this.region,
    this.branch,
    this.notes,
    this.timeline,
    this.followUp,
    this.productDescription,
    this.products = const [],
    this.assignedTo,
    this.assignedToName,
    this.sourceId,
    this.createdAt,
    this.opportunityCreatedAt,
  });

  bool get isDirect => leadType == 'direct_opportunity';

  factory OpportunityLead.fromJson(Map<String, dynamic> j) => OpportunityLead(
        id: j['id'],
        leadRefId: (j['lead_ref_id'] ?? '').toString(),
        opportunityRefId: j['opportunity_ref_id']?.toString(),
        leadTitle: (j['lead_title'] ?? '').toString(),
        leadType: j['lead_type']?.toString(),
        customerId: j['customer_id'],
        customerName: j['customer_name']?.toString(),
        customerAddress: j['customer_address']?.toString(),
        department: j['department']?.toString(),
        contactPerson: j['contact_person']?.toString(),
        designation: j['designation']?.toString(),
        mobile: j['mobile']?.toString(),
        email: j['email']?.toString(),
        estValue: j['est_value'] is num ? j['est_value'] : num.tryParse('${j['est_value']}'),
        priority: j['priority']?.toString(),
        status: (j['status'] ?? '').toString(),
        region: j['region']?.toString(),
        branch: j['branch']?.toString(),
        notes: j['notes']?.toString(),
        timeline: j['timeline']?.toString(),
        followUp: j['follow_up']?.toString(),
        productDescription: j['product_description']?.toString(),
        products: (j['products'] as List?) ?? const [],
        assignedTo: j['assigned_to'],
        assignedToName: j['assigned_to_name']?.toString(),
        sourceId: j['source_id'],
        createdAt: j['created_at']?.toString(),
        opportunityCreatedAt: j['opportunity_created_at']?.toString(),
      );
}

// ─── Shared formatting helpers ────────────────────────────────────────────────

class Fmt {
  static final NumberFormat _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _inrPlain =
      NumberFormat.decimalPattern('en_IN');

  static String money(num n) => _inr.format(n);

  static String moneyShort(num? v) {
    final n = (v ?? 0).toDouble();
    if (n == 0) return '—';
    if (n >= 1e7) return '₹${(n / 1e7).toStringAsFixed(1)}Cr';
    if (n >= 1e5) return '₹${(n / 1e5).toStringAsFixed(1)}L';
    return '₹${_inrPlain.format(n)}';
  }

  static String date(dynamic v) {
    if (v == null || v.toString().isEmpty) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return DateFormat('dd MMM yyyy').format(d);
  }

  static String dateDot(dynamic v) {
    if (v == null || v.toString().isEmpty) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return DateFormat('dd.MM.yyyy').format(d);
  }

  // Indian-system number → words (matches the web numberToWords).
  static String words(num value) {
    final num0 = value.abs().floor();
    if (num0 == 0) return 'Zero';
    const ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String two(int x) =>
        x < 20 ? ones[x] : (tens[x ~/ 10] + (x % 10 != 0 ? ' ${ones[x % 10]}' : '')).trim();
    String three(int x) => x == 0
        ? ''
        : x < 100
            ? two(x)
            : '${ones[x ~/ 100]} Hundred${x % 100 != 0 ? ' ${two(x % 100)}' : ''}';

    final cr = num0 ~/ 10000000;
    final lk = (num0 % 10000000) ~/ 100000;
    final th = (num0 % 100000) ~/ 1000;
    final rest = num0 % 1000;

    final parts = <String>[];
    if (cr != 0) parts.add('${three(cr)} Crore');
    if (lk != 0) parts.add('${two(lk)} Lakh');
    if (th != 0) parts.add('${two(th)} Thousand');
    if (rest != 0) parts.add(three(rest));
    return parts.join(' ');
  }
}
