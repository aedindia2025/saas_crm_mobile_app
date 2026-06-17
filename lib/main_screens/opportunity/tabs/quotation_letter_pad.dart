// tabs/quotation_letter_pad.dart
//
// Printable proposal preview — port of QuotationLetterPad.tsx.
// On-screen preview + "Print / PDF" via the `printing` + `pdf` packages.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';

class QuotationLetterPad extends StatefulWidget {
  final Map<String, dynamic> quotation;
  final OpportunityLead lead;
  const QuotationLetterPad({super.key, required this.quotation, required this.lead});

  @override
  State<QuotationLetterPad> createState() => _QuotationLetterPadState();
}

class _QuotationLetterPadState extends State<QuotationLetterPad> {
  Map<String, String> _company = {};
  Map<String, dynamic>? _primaryAddress;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final raw = await ApiClient.getJson('/settings/settings');
      final flat = <String, String>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          flat[k.toString()] =
              (v is Map && v['value'] is String) ? v['value'] : (v?.toString() ?? '');
        });
      }
      setState(() => _company = flat);
    } catch (_) {}
    try {
      final r = await ApiClient.getJson('/settings/company-addresses');
      final addrs = (r is Map ? r['addresses'] : null) as List? ?? [];
      final primary = addrs.firstWhere((a) => a['is_primary'] == true,
          orElse: () => addrs.isNotEmpty ? addrs.first : null);
      if (primary != null) setState(() => _primaryAddress = Map<String, dynamic>.from(primary));
    } catch (_) {}
  }

  String get _companyAddress {
    if (_primaryAddress != null) {
      final p = _primaryAddress!;
      return [
        p['street_address'],
        p['area_locality'],
        p['city_district'],
        p['state'],
        p['pincode'],
        p['country']
      ].where((x) => x != null && '$x'.isNotEmpty).join(', ');
    }
    return [
      _company['street_address'],
      _company['city_district'],
      _company['state'],
      _company['pincode']
    ].where((x) => x != null && '$x'.isNotEmpty).join(', ');
  }

  String get _resolvedCompanyAddress =>
      (widget.quotation['company_address_text']?.toString().isNotEmpty ?? false)
          ? widget.quotation['company_address_text']
          : (widget.quotation['company_address_override']?.toString().isNotEmpty ?? false)
              ? widget.quotation['company_address_override']
              : _companyAddress;

  String _fmt(num n) =>
      NumberFormat('#,##0.00', 'en_IN').format(n);

  String _fmtDate(dynamic v) {
    if (v == null || '$v'.isEmpty) return '—';
    final d = DateTime.tryParse('$v');
    if (d == null) return '$v';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  num _net(Map it) => it['net_price'] ?? ((it['unit_price'] as num? ?? 0) * (it['quantity'] as num? ?? 0));
  num _gst(Map it) => it['gst_value'] ?? (_net(it) * (it['tax_percent'] as num? ?? 0) / 100);

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final items = (q['line_items'] as List?) ?? [];
    final sig = (q['signatory'] as Map?) ?? {};
    final terms = (q['terms_conditions']?.toString() ?? '')
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final greeting = (q['greeting_text']?.toString() ?? '')
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final addressLines = (q['customer_address_text']?.toString() ?? widget.lead.customerAddress ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Letter Pad Preview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  FilledButton.icon(
                    onPressed: _printPdf,
                    icon: const Icon(Icons.print, size: 13),
                    label: const Text('Print / PDF'),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 16)),
                ],
              ),
            ),
            // preview body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // company header
                      Container(
                        padding: const EdgeInsets.only(bottom: 10),
                        decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 2))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(child: SizedBox(height: 40)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_resolvedCompanyAddress,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
                                  if ((_company['phone'] ?? '').isNotEmpty)
                                    Text('Ph: ${_company['phone']}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(q['subject']?.toString() ?? 'Commercial Proposal',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                      const SizedBox(height: 12),
                      Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: _fmtDate(q['created_at'])),
                      ])),
                      if ((q['ref_number'] ?? '').toString().isNotEmpty)
                        Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Ref: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: q['ref_number'].toString()),
                        ])),
                      const SizedBox(height: 12),
                      const Text('To'),
                      Text(q['customer_to_name']?.toString() ?? widget.lead.customerName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      for (final l in addressLines) Text(l),
                      const SizedBox(height: 12),
                      Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Subject: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: q['subject']?.toString() ?? ''),
                      ])),
                      const SizedBox(height: 12),
                      for (final p in greeting)
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p, textAlign: TextAlign.justify)),
                      const SizedBox(height: 4),
                      const Text('Commercial Proposal:',
                          style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      const SizedBox(height: 8),
                      _previewTable(items),
                      const SizedBox(height: 14),
                      if (terms.isNotEmpty) ...[
                        const Text('TERMS & CONDITIONS:',
                            style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        const SizedBox(height: 6),
                        for (final t in terms)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('➢  '),
                              Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ]),
                          ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                          'We request you to kindly contact us for any further clarifications or additional information required regarding this proposal.',
                          textAlign: TextAlign.justify),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if ((sig['full_name'] ?? '').toString().isNotEmpty)
                              Text(sig['full_name'].toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            if ((sig['designation'] ?? '').toString().isNotEmpty)
                              Text(sig['designation'].toString()),
                            if ((sig['phone'] ?? '').toString().isNotEmpty)
                              Text('+91 ${sig['phone']}${(sig['email'] ?? '').toString().isNotEmpty ? ' / ${sig['email']}' : ''}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewTable(List items) {
    return Table(
      border: TableBorder.all(color: const Color(0xFF9CA3AF)),
      columnWidths: const {
        0: FixedColumnWidth(28),
        1: FlexColumnWidth(3),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFF3F4F6)),
          children: [
            _Cell('S.No', bold: true, center: true),
            _Cell('Item Description', bold: true),
            _Cell('Qty', bold: true, center: true),
            _Cell('Unit', bold: true, right: true),
            _Cell('GST%', bold: true, center: true),
            _Cell('GST Val', bold: true, right: true),
            _Cell('Net', bold: true, right: true),
            _Cell('Total', bold: true, right: true),
          ],
        ),
        for (int i = 0; i < items.length; i++)
          TableRow(children: [
            _Cell('${i + 1}', center: true),
            _Cell(items[i]['description']?.toString() ?? ''),
            _Cell(_fmt(items[i]['quantity'] as num? ?? 0), center: true),
            _Cell(_fmt(items[i]['unit_price'] as num? ?? 0), right: true),
            _Cell('${items[i]['tax_percent']}%', center: true),
            _Cell(_fmt(_gst(items[i])), right: true),
            _Cell(_fmt(_net(items[i])), right: true),
            _Cell(_fmt(items[i]['line_total'] as num? ?? 0), right: true, bold: true),
          ]),
      ],
    );
  }

  // ── PDF generation ──
  Future<void> _printPdf() async {
    final q = widget.quotation;
    final items = (q['line_items'] as List?) ?? [];
    final sig = (q['signatory'] as Map?) ?? {};
    final terms = (q['terms_conditions']?.toString() ?? '')
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final greeting = (q['greeting_text']?.toString() ?? '')
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final addressLines = (q['customer_address_text']?.toString() ?? widget.lead.customerAddress ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.SizedBox()),
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(_resolvedCompanyAddress,
                      textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
                  if ((_company['phone'] ?? '').isNotEmpty)
                    pw.Text('Ph: ${_company['phone']}', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
            ],
          ),
          pw.Divider(thickness: 1.4),
          pw.Center(
            child: pw.Text(q['subject']?.toString() ?? 'Commercial Proposal',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Date: ${_fmtDate(q['created_at'])}'),
          if ((q['ref_number'] ?? '').toString().isNotEmpty) pw.Text('Ref: ${q['ref_number']}'),
          pw.SizedBox(height: 10),
          pw.Text('To'),
          pw.Text(q['customer_to_name']?.toString() ?? widget.lead.customerName ?? '',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final l in addressLines) pw.Text(l),
          pw.SizedBox(height: 10),
          pw.Text('Subject: ${q['subject'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          for (final p in greeting)
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5), child: pw.Text(p, textAlign: pw.TextAlign.justify)),
          pw.Text('Commercial Proposal:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
            },
            headers: const ['S.No', 'Item Description', 'Qty', 'Unit Price', 'GST %', 'GST Value', 'Net Price', 'Total'],
            data: [
              for (int i = 0; i < items.length; i++)
                [
                  '${i + 1}',
                  items[i]['description']?.toString() ?? '',
                  _fmt(items[i]['quantity'] as num? ?? 0),
                  _fmt(items[i]['unit_price'] as num? ?? 0),
                  '${items[i]['tax_percent']}%',
                  _fmt(_gst(items[i])),
                  _fmt(_net(items[i])),
                  _fmt(items[i]['line_total'] as num? ?? 0),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          if (terms.isNotEmpty) ...[
            pw.Text('TERMS & CONDITIONS:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 4),
            for (final t in terms)
              pw.Bullet(text: t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
          ],
          pw.Text(
              'We request you to kindly contact us for any further clarifications or additional information required regarding this proposal.',
              textAlign: pw.TextAlign.justify),
          pw.SizedBox(height: 30),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              if ((sig['full_name'] ?? '').toString().isNotEmpty)
                pw.Text(sig['full_name'].toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if ((sig['designation'] ?? '').toString().isNotEmpty) pw.Text(sig['designation'].toString()),
              if ((sig['phone'] ?? '').toString().isNotEmpty)
                pw.Text('+91 ${sig['phone']}${(sig['email'] ?? '').toString().isNotEmpty ? ' / ${sig['email']}' : ''}'),
            ]),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool center;
  final bool right;
  const _Cell(this.text, {this.bold = false, this.center = false, this.right = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Text(text,
            textAlign: center ? TextAlign.center : (right ? TextAlign.right : TextAlign.left),
            style: TextStyle(fontSize: 10, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}
