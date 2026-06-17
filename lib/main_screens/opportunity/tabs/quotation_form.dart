// tabs/quotation_form.dart
//
// Create / edit a single quotation revision — port of QuotationForm.tsx.

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';
import '../widgets/searchable_select.dart';
import '../widgets/ui.dart';

class _Line {
  int? id;
  String description;
  String quantity;
  String unitPrice;
  String taxPercent;
  _Line({this.id, this.description = '', this.quantity = '1', this.unitPrice = '0', this.taxPercent = '0'});
}

class _CompanyAddress {
  final int id;
  final String? addressName;
  final String? branchName;
  final String? street;
  final String? area;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final bool isPrimary;
  _CompanyAddress(Map<String, dynamic> j)
      : id = j['id'],
        addressName = j['address_name']?.toString(),
        branchName = j['branch_name']?.toString(),
        street = j['street_address']?.toString(),
        area = j['area_locality']?.toString(),
        city = j['city_district']?.toString(),
        state = j['state']?.toString(),
        pincode = j['pincode']?.toString(),
        country = j['country']?.toString(),
        isPrimary = j['is_primary'] == true;

  String get formatted => [street, area, city, state, pincode, country]
      .where((x) => x != null && x.isNotEmpty)
      .join(', ');

  String get label => [
        addressName ?? branchName ?? 'Address #$id',
        if (isPrimary) 'Primary',
        city,
        state,
      ].where((x) => x != null && x.toString().isNotEmpty).join(' · ');
}

class QuotationForm extends StatefulWidget {
  final OpportunityLead lead;
  final Map<String, dynamic>? existingQuotation;
  final ValueChanged<Map<String, dynamic>> onSaved;
  final VoidCallback onCancel;

  const QuotationForm({
    super.key,
    required this.lead,
    this.existingQuotation,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<QuotationForm> createState() => _QuotationFormState();
}

class _QuotationFormState extends State<QuotationForm> {
  final _subject = TextEditingController();
  String _validUntil = '';
  final _notes = TextEditingController();
  List<TextEditingController> _terms = [TextEditingController()];
  List<_Line> _lines = [_Line()];

  bool _letterPadOpen = false;
  bool _saving = false;

  final _refNumber = TextEditingController();
  final _customerToName = TextEditingController();
  final _customerAddress = TextEditingController();
  final _greeting = TextEditingController(
      text: 'Dear Sir,\n\nGreetings!\n\nWe are pleased to submit our commercial proposal for the same.');
  int? _signatoryId;

  List<Map<String, dynamic>> _users = [];
  List<_CompanyAddress> _companyAddresses = [];
  int? _companyAddressId;
  final _companyAddressText = TextEditingController();

  @override
  void initState() {
    super.initState();
    final q = widget.existingQuotation;
    if (q != null) {
      _subject.text = q['subject']?.toString() ?? '';
      _validUntil = q['valid_until']?.toString() ?? '';
      _notes.text = q['notes']?.toString() ?? '';
      final rawTerms = (q['terms_conditions']?.toString() ?? '')
          .split('\n')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      _terms = (rawTerms.isEmpty ? [''] : rawTerms).map((t) => TextEditingController(text: t)).toList();
      final items = (q['line_items'] as List?) ?? [];
      if (items.isNotEmpty) {
        _lines = items
            .map((i) => _Line(
                  id: i['id'],
                  description: i['description']?.toString() ?? '',
                  quantity: '${i['quantity']}',
                  unitPrice: '${i['unit_price']}',
                  taxPercent: '${i['tax_percent']}',
                ))
            .toList();
      }
      _refNumber.text = q['ref_number']?.toString() ?? '';
      _customerToName.text =
          q['customer_to_name']?.toString() ?? widget.lead.customerName ?? '';
      _customerAddress.text =
          q['customer_address_text']?.toString() ?? widget.lead.customerAddress ?? '';
      _greeting.text = q['greeting_text']?.toString() ?? _greeting.text;
      _signatoryId = q['signatory_user_id'];
      _companyAddressId = q['company_address_id'];
      _companyAddressText.text =
          q['company_address_text']?.toString() ?? q['company_address_override']?.toString() ?? '';
    } else {
      _customerToName.text = widget.lead.customerName ?? '';
      _customerAddress.text = widget.lead.customerAddress ?? '';
      // prefill lines from lead products
      if (widget.lead.products.isNotEmpty) {
        _lines = widget.lead.products.map((p) {
          final m = Map<String, dynamic>.from(p);
          return _Line(
            description: (m['product_name'] ?? m['description'] ?? '').toString(),
            quantity: '${m['quantity'] ?? 1}',
            unitPrice: '${m['unit_price'] ?? 0}',
            taxPercent: '${m['gst_percent'] ?? 0}',
          );
        }).toList();
      }
    }
    _loadUsers();
    _loadCompanyAddresses();
  }

  Future<void> _loadUsers() async {
    try {
      final r = await ApiClient.getJson('/leads/team-users');
      setState(() => _users = (r as List)
          .map((u) => {
                'id': u['id'],
                'full_name': u['label'] ?? u['full_name'],
                'designation': u['designation'],
              })
          .toList());
    } catch (_) {}
  }

  Future<void> _loadCompanyAddresses() async {
    try {
      final r = await ApiClient.getJson('/settings/company-addresses');
      final addrs = ((r is Map ? r['addresses'] : null) as List? ?? [])
          .map((a) => _CompanyAddress(Map<String, dynamic>.from(a)))
          .toList();
      setState(() => _companyAddresses = addrs);
      final q = widget.existingQuotation;
      final hasAddr = q != null &&
          (q['company_address_id'] != null ||
              (q['company_address_text']?.toString().isNotEmpty ?? false) ||
              (q['company_address_override']?.toString().isNotEmpty ?? false));
      if (!hasAddr && addrs.isNotEmpty) {
        final primary = addrs.firstWhere((a) => a.isPrimary, orElse: () => addrs.first);
        setState(() {
          _companyAddressId = primary.id;
          _companyAddressText.text = primary.formatted;
        });
      }
    } catch (_) {}
  }

  // ── totals ──
  double _qty(_Line l) => double.tryParse(l.quantity) ?? 0;
  double _unit(_Line l) => double.tryParse(l.unitPrice) ?? 0;
  double _tax(_Line l) => double.tryParse(l.taxPercent) ?? 0;
  double _base(_Line l) => _qty(l) * _unit(l);
  double _taxAmt(_Line l) => _base(l) * (_tax(l) / 100);
  double get _totalBase => _lines.fold(0, (s, l) => s + _base(l));
  double get _totalTax => _lines.fold(0, (s, l) => s + _taxAmt(l));
  double get _grand => _totalBase + _totalTax;

  Future<void> _save() async {
    if (_lines.isEmpty || _lines.first.description.trim().isEmpty) {
      Toast.error(context, 'At least one line item with a description is required.');
      return;
    }
    final payload = {
      'lead_id': widget.lead.id,
      'customer_id': widget.lead.customerId,
      'subject': _subject.text.trim().isEmpty
          ? 'Quotation for ${widget.lead.leadTitle}'
          : _subject.text.trim(),
      'amount': _totalBase,
      'tax_amount': _totalTax,
      'total_amount': _grand,
      'valid_until': _validUntil.isEmpty ? null : _validUntil,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'terms_conditions': _terms.map((t) => t.text.trim()).where((t) => t.isNotEmpty).join('\n'),
      'ref_number': _refNumber.text.trim().isEmpty ? null : _refNumber.text.trim(),
      'customer_to_name': _customerToName.text.trim().isEmpty ? null : _customerToName.text.trim(),
      'customer_address_text': _customerAddress.text.trim().isEmpty ? null : _customerAddress.text.trim(),
      'greeting_text': _greeting.text.trim().isEmpty ? null : _greeting.text.trim(),
      'signatory_user_id': _signatoryId,
      'company_address_id': _companyAddressId,
      'company_address_text': _companyAddressText.text.trim().isEmpty ? null : _companyAddressText.text.trim(),
      'company_address_override':
          _companyAddressText.text.trim().isEmpty ? null : _companyAddressText.text.trim(),
      'line_items': [
        for (int i = 0; i < _lines.length; i++)
          {
            'description': _lines[i].description,
            'quantity': _qty(_lines[i]) == 0 ? 1 : _qty(_lines[i]),
            'unit_price': _unit(_lines[i]),
            'tax_percent': _tax(_lines[i]),
            'sort_order': i,
          }
      ],
    };
    setState(() => _saving = true);
    try {
      final res = widget.existingQuotation != null
          ? await ApiClient.put('/quotations/${widget.existingQuotation!['id']}', payload)
          : await ApiClient.postJson('/quotations', payload);
      if (!mounted) return;
      Toast.success(context,
          widget.existingQuotation != null ? 'Quotation updated' : 'Quotation created');
      widget.onSaved(res is Map ? Map<String, dynamic>.from(res) : {});
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _customerBar(),
        const SizedBox(height: 16),
        LabeledField(label: 'Subject', child: AppInput(controller: _subject, hint: 'Quotation for ${widget.lead.leadTitle}')),
        const SizedBox(height: 12),
        LabeledField(
          label: 'Valid Until',
          child: DateField(value: _validUntil, onChanged: (v) => setState(() => _validUntil = v)),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Line Items'),
        const SizedBox(height: 8),
        _lineItemsTable(),
        const SizedBox(height: 12),
        _totals(),
        const SizedBox(height: 16),
        _termsEditor(),
        const SizedBox(height: 16),
        _letterPad(),
        const SizedBox(height: 16),
        LabeledField(label: 'Notes', child: AppInput(controller: _notes, maxLines: 3, hint: 'Internal notes…')),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save, size: 14),
              label: Text(_saving
                  ? 'Saving…'
                  : (widget.existingQuotation != null ? 'Update Quotation' : 'Save Quotation')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _customerBar() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CUSTOMER',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                  Text(widget.lead.customerName ?? '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                ],
              ),
            ),
            if ((widget.lead.estValue ?? 0) != 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('EST. VALUE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF60A5FA))),
                  Text(Fmt.moneyShort(widget.lead.estValue),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                ],
              ),
          ],
        ),
      );

  Widget _lineItemsTable() {
    return Column(
      children: [
        for (int i = 0; i < _lines.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppInput(
                        controller: TextEditingController(text: _lines[i].description)
                          ..selection = TextSelection.collapsed(offset: _lines[i].description.length),
                        hint: 'Product / Service',
                        onChanged: (v) => _lines[i].description = v,
                      ),
                    ),
                    if (_lines.length > 1)
                      InkWell(
                        onTap: () => setState(() => _lines.removeAt(i)),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _numField('Qty', _lines[i].quantity, (v) => setState(() => _lines[i].quantity = v))),
                    const SizedBox(width: 6),
                    Expanded(child: _numField('Unit ₹', _lines[i].unitPrice, (v) => setState(() => _lines[i].unitPrice = v))),
                    const SizedBox(width: 6),
                    Expanded(child: _numField('Tax %', _lines[i].taxPercent, (v) => setState(() => _lines[i].taxPercent = v))),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: ${Fmt.money(_base(_lines[i]) + _taxAmt(_lines[i]))}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        InkWell(
          onTap: () => setState(() => _lines.add(_Line())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 2)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, size: 12, color: Color(0xFF2563EB)),
              SizedBox(width: 4),
              Text('Add Line Item',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _numField(String label, String value, ValueChanged<String> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          AppInput(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(offset: value.length),
            keyboardType: TextInputType.number,
            onChanged: onChanged,
          ),
        ],
      );

  Widget _totals() => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 240,
          child: Column(
            children: [
              _totalRow('Subtotal', Fmt.money(_totalBase)),
              _totalRow('Tax', Fmt.money(_totalTax)),
              const Divider(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Fmt.money(_grand),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (_grand > 0)
                          Text('${Fmt.words(_grand)} Rupees Only',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _totalRow(String l, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            Text(r, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ],
        ),
      );

  Widget _termsEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Terms & Conditions  (each point printed as ➢ bullet)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          for (int i = 0; i < _terms.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('${i + 1}.', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppInput(
                      controller: _terms[i],
                      hint: i == 0 ? 'e.g. Payment Terms: 100% Against Delivery' : 'Add another point…',
                    ),
                  ),
                  if (_terms.length > 1)
                    InkWell(
                      onTap: () => setState(() => _terms.removeAt(i)),
                      child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close, size: 13, color: Color(0xFFD1D5DB))),
                    ),
                ],
              ),
            ),
          InkWell(
            onTap: () => setState(() => _terms.add(TextEditingController())),
            child: const Row(children: [
              Icon(Icons.add, size: 11, color: Color(0xFF2563EB)),
              SizedBox(width: 4),
              Text('Add Point', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      );

  Widget _letterPad() => Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _letterPadOpen = !_letterPadOpen),
              child: Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    const Expanded(
                        child: Text('Letter Pad Details',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
                    Icon(_letterPadOpen ? Icons.expand_less : Icons.expand_more, size: 16),
                  ],
                ),
              ),
            ),
            if (_letterPadOpen)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: LabeledField(
                              label: 'Reference Number',
                              child: AppInput(controller: _refNumber, hint: 'e.g. AED/DS/2026-27/KM/001'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SearchableSelect(
                          label: 'Signatory (Proposal From)',
                          placeholder: '— Select user —',
                          clearable: true,
                          value: _signatoryId,
                          options: _users
                              .map((u) => SelectOpt(
                                    u['id'] as int,
                                    '${u['full_name']}${(u['designation'] ?? '').toString().isNotEmpty ? ' (${u['designation']})' : ''}',
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _signatoryId = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    LabeledField(
                        label: 'To (Customer Name / Designation)',
                        child: AppInput(controller: _customerToName, hint: 'The Managing Director, XYZ Ltd')),
                    const SizedBox(height: 12),
                    LabeledField(label: 'Customer Address', child: AppInput(controller: _customerAddress, maxLines: 3)),
                    const SizedBox(height: 12),
                    LabeledField(label: 'Greeting / Opening Paragraph', child: AppInput(controller: _greeting, maxLines: 4)),
                    const SizedBox(height: 12),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: SectionLabel('Company Header')),
                    const SizedBox(height: 8),
                    SearchableSelect(
                      label: 'Company Address',
                      placeholder: '— Select company address —',
                      clearable: true,
                      value: _companyAddressId,
                      options: _companyAddresses
                          .map((a) => SelectOpt(a.id, a.label))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _companyAddressId = v;
                          final found = _companyAddresses
                              .where((a) => a.id == v)
                              .cast<_CompanyAddress?>()
                              .firstOrNull;
                          _companyAddressText.text = found?.formatted ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    LabeledField(
                        label: 'Selected Address Text',
                        child: AppInput(controller: _companyAddressText, maxLines: 2)),
                  ],
                ),
              ),
          ],
        ),
      );
}
