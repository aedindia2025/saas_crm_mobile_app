// tabs/lead_details_tab.dart
//
// View + inline edit for an Opportunity's lead details — port of LeadDetailsTab.tsx.

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';
import '../widgets/searchable_select.dart';
import '../widgets/ui.dart';

class LeadDetailsTab extends StatefulWidget {
  final OpportunityLead lead;
  final VoidCallback? onLeadUpdated;
  final VoidCallback? onNext;
  final bool disabled;

  const LeadDetailsTab({
    super.key,
    required this.lead,
    this.onLeadUpdated,
    this.onNext,
    this.disabled = false,
  });

  @override
  State<LeadDetailsTab> createState() => _LeadDetailsTabState();
}

class _LeadDetailsTabState extends State<LeadDetailsTab> {
  bool _editing = false;
  bool _saving = false;
  List _activities = [];

  // master data
  List<SelectOpt> _customers = [];
  List<SelectOpt> _sources = [];
  List<SelectOpt> _products = [];
  List<SelectOpt> _oems = [];
  List<SelectOpt> _users = [];

  // form state
  final _title = TextEditingController();
  int? _customerId;
  String _customerName = '';
  final _estValue = TextEditingController();
  String _priority = 'Medium';
  int? _sourceId;
  final _region = TextEditingController();
  final _branch = TextEditingController();
  final _contact = TextEditingController();
  final _designation = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _department = TextEditingController();
  final _address = TextEditingController();
  final _timeline = TextEditingController();
  String _followUp = '';
  final _productDesc = TextEditingController();
  final _notes = TextEditingController();
  int? _assignedTo;
  List<ProdEntry> _products2 = [ProdEntry()];

  bool get _isManagerOrAbove => true; // wire to your auth/role store if needed

  @override
  void initState() {
    super.initState();
    _loadMasters();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final r = await ApiClient.getJson('/kam/activities', query: {'lead_id': widget.lead.id});
      setState(() => _activities = r is List ? r : []);
    } catch (_) {}
  }

  Future<void> _loadMasters() async {
    try {
      final c = await ApiClient.getJson('/leads/team-customers');
      final s = await ApiClient.getJson('/masters/lead-sources');
      final p = await ApiClient.getJson('/masters/products');
      final o = await ApiClient.getJson('/masters/oems');
      final u = await ApiClient.getJson('/masters/users-for-select');
      setState(() {
        _customers = (c as List)
            .where((x) => x['customer_name'] != null)
            .map((x) => SelectOpt(x['id'], x['customer_name'].toString(),
                approvalStatus: (x['approval_status'] ?? '').toString().toLowerCase()))
            .toList();
        _sources = _opts(s, 'name');
        _products = _opts(p, 'name');
        _oems = _opts(o, 'name');
        _users = (u as List)
            .where((x) => x['label'] != null)
            .map((x) => SelectOpt(x['id'], x['label'].toString()))
            .toList();
      });
    } catch (_) {}
  }

  List<SelectOpt> _opts(dynamic list, String key) => (list as List)
      .where((x) => x[key] != null)
      .map((x) => SelectOpt(x['id'], x[key].toString()))
      .toList();

  void _populate() {
    final l = widget.lead;
    _title.text = l.leadTitle;
    _customerId = l.customerId;
    _customerName = l.customerName ?? '';
    _estValue.text = l.estValue != null ? l.estValue.toString() : '';
    _priority = l.priority ?? 'Medium';
    _sourceId = l.sourceId;
    _region.text = l.region ?? '';
    _branch.text = l.branch ?? '';
    _contact.text = l.contactPerson ?? '';
    _designation.text = l.designation ?? '';
    _mobile.text = l.mobile ?? '';
    _email.text = l.email ?? '';
    _department.text = l.department ?? '';
    _address.text = l.customerAddress ?? '';
    _timeline.text = l.timeline ?? '';
    _followUp = (l.followUp ?? '').length >= 10 ? l.followUp!.substring(0, 10) : '';
    _productDesc.text = l.productDescription ?? '';
    _notes.text = l.notes ?? '';
    _assignedTo = l.assignedTo;
    final prods = l.products
        .map((p) => ProdEntry.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    _products2 = prods.isEmpty ? [ProdEntry()] : prods;
  }

  Future<void> _onCustomerSelect(int? id) async {
    setState(() => _customerId = id);
    if (id == null) {
      setState(() => _customerName = '');
      return;
    }
    final found = _customers.firstWhere((c) => c.value == id, orElse: () => SelectOpt(0, ''));
    if (found.value != 0) _customerName = found.label;
    try {
      final c = await ApiClient.getJson('/customers/$id');
      final city = c['billing_city'];
      final state = c['billing_state'];
      if (city != null || state != null) {
        _address.text = [city, state].where((x) => x != null && '$x'.isNotEmpty).join(', ');
      }
      final contacts = (c['contacts'] as List?) ?? [];
      final primary = contacts.firstWhere((x) => x['is_primary'] == true,
          orElse: () => contacts.isNotEmpty ? contacts.first : null);
      if (primary != null) {
        if (_contact.text.isEmpty) _contact.text = (primary['contact_name'] ?? '').toString();
        if (_designation.text.isEmpty) _designation.text = (primary['designation'] ?? '').toString();
        if (_mobile.text.isEmpty) _mobile.text = (primary['mobile'] ?? '').toString();
        if (_email.text.isEmpty) _email.text = (primary['office_email'] ?? '').toString();
        if (_department.text.isEmpty) _department.text = (primary['department'] ?? '').toString();
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      Toast.error(context, 'Title is required');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.put('/leads/${widget.lead.id}', {
        'lead_title': _title.text.trim(),
        'customer_id': _customerId,
        'customer_name': _customerName,
        'customer_address': _address.text,
        'department': _department.text,
        'contact_person': _contact.text,
        'designation': _designation.text,
        'mobile': _mobile.text,
        'email': _email.text,
        'source_id': _sourceId,
        'priority': _priority,
        'est_value': _estValue.text.isNotEmpty ? num.tryParse(_estValue.text) : null,
        'region': _region.text,
        'branch': _branch.text,
        'timeline': _timeline.text,
        'follow_up': _followUp.isEmpty ? null : _followUp,
        'product_description': _productDesc.text,
        'notes': _notes.text,
        'assigned_to': _assignedTo,
        'products': _products2
            .where((p) => p.productName.trim().isNotEmpty)
            .map((p) => p.toJson())
            .toList(),
      });
      if (!mounted) return;
      Toast.success(context, 'Opportunity updated');
      setState(() => _editing = false);
      widget.onLeadUpdated?.call();
      if (widget.lead.isDirect) widget.onNext?.call();
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _editing ? _buildEdit() : _buildView();
  }

  // ── READ-ONLY VIEW ───────────────────────────────────────────────────────

  Widget _buildView() {
    final l = widget.lead;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Section(
          title: 'Opportunity Details',
          action: widget.disabled
              ? null
              : OutlinedButton.icon(
                  onPressed: () {
                    _populate();
                    setState(() => _editing = true);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 13),
                  label: const Text('Edit Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
          child: Column(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  InfoRow(
                      label: 'Opportunity Title',
                      value: l.leadTitle,
                      icon: Icons.label_outline,
                      wide: true),
                  InfoRow(
                      label: 'Estimated Value',
                      value: Fmt.moneyShort(l.estValue),
                      icon: Icons.attach_money,
                      valueColor: const Color(0xFF047857)),
                  InfoRow(label: 'Priority', value: l.priority ?? '—'),
                  InfoRow(label: 'Region', value: l.region ?? '—', icon: Icons.place_outlined),
                  InfoRow(label: 'Branch', value: l.branch ?? '—'),
                  InfoRow(label: 'Timeline', value: l.timeline ?? '—', icon: Icons.schedule),
                  InfoRow(
                      label: 'Follow Up', value: Fmt.date(l.followUp), icon: Icons.event_outlined),
                ],
              ),
              if ((l.productDescription ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _block('Product Description', l.productDescription!),
              ],
              if ((l.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _block('Notes', l.notes!, accent: true),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Section(
          title: 'Customer / Account',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoRow(
                  label: 'Company',
                  value: l.customerName ?? '—',
                  icon: Icons.business_outlined,
                  wide: true),
              InfoRow(label: 'Contact Person', value: l.contactPerson ?? '—', icon: Icons.person_outline),
              InfoRow(label: 'Designation', value: l.designation ?? '—'),
              InfoRow(label: 'Department', value: l.department ?? '—'),
              InfoRow(label: 'Mobile', value: l.mobile ?? '—', icon: Icons.phone_outlined),
              InfoRow(label: 'Email', value: l.email ?? '—', icon: Icons.mail_outline),
              InfoRow(
                  label: 'Address',
                  value: l.customerAddress ?? '—',
                  icon: Icons.place_outlined,
                  wide: true),
            ],
          ),
        ),
        if (l.products.isNotEmpty) ...[
          const SizedBox(height: 12),
          Section(
            title: 'Products & OEMs',
            child: Column(
              children: [
                for (final p in l.products) _productCard(Map<String, dynamic>.from(p)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Section(
          title: 'Timeline',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoRow(label: 'Lead Created', value: Fmt.date(l.createdAt), icon: Icons.event_outlined),
              InfoRow(label: 'Opportunity Created', value: Fmt.date(l.opportunityCreatedAt)),
              InfoRow(label: 'Assigned To', value: l.assignedToName ?? '—', icon: Icons.person_outline),
            ],
          ),
        ),
        if (_activities.isNotEmpty) ...[
          const SizedBox(height: 12),
          _activitiesCard(),
        ],
      ],
    );
  }

  Widget _block(String title, String body, {bool accent = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: accent ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8))),
            const SizedBox(height: 4),
            Text(body,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: accent ? const Color(0xFF1E40AF) : const Color(0xFF334155))),
          ],
        ),
      );

  Widget _productCard(Map<String, dynamic> p) {
    final oems = ((p['oems'] as List?) ?? [])
        .where((o) => (o['oem_name'] ?? '').toString().isNotEmpty)
        .toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((p['product_name'] ?? '').toString(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    if ((p['description'] ?? '').toString().isNotEmpty)
                      Text(p['description'].toString(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                child: Text('Qty: ${p['quantity'] ?? 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              ),
            ],
          ),
          if (oems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in oems)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.factory_outlined, size: 10, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(o['oem_name'].toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _activitiesCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFEFF6FF),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.timeline, size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Text('FOLLOW-UP ACTIVITIES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_activities.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ),
          for (final a in _activities)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                    child: const Icon(Icons.schedule, size: 12, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((a['subject'] ?? '').toString(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(Fmt.date(a['activity_date']),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        if ((a['description'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(a['description'].toString(),
                                style: const TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8))),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── EDIT FORM ───────────────────────────────────────────────────────────

  Widget _buildEdit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Edit Opportunity Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const Spacer(),
              IconButton(
                  onPressed: () => setState(() => _editing = false),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8))),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          LabeledField(
              label: 'Opportunity Title', required: true, child: AppInput(controller: _title)),
          const SizedBox(height: 12),
          SearchableSelect(
            label: 'Customer / Account',
            options: _customers,
            value: _customerId,
            onChanged: (v) => _onCustomerSelect(v),
            clearable: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabeledField(
                        label: 'Est. Value (₹)',
                        child: AppInput(controller: _estValue, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                    if ((num.tryParse(_estValue.text) ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${Fmt.words(num.parse(_estValue.text))} Rupees',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF60A5FA))),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Priority',
                  child: AppDropdown<String>(
                    value: _priority,
                    items: const ['Low', 'Medium', 'High'],
                    onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SearchableSelect(
                    label: 'Source',
                    options: _sources,
                    value: _sourceId,
                    onChanged: (v) => setState(() => _sourceId = v),
                    clearable: true),
              ),
              const SizedBox(width: 12),
              if (_isManagerOrAbove)
                Expanded(
                  child: SearchableSelect(
                      label: 'Assigned To',
                      options: _users,
                      value: _assignedTo,
                      onChanged: (v) => setState(() => _assignedTo = v),
                      clearable: true),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledField(label: 'Region', child: AppInput(controller: _region))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Branch', child: AppInput(controller: _branch))),
          ]),
          const SizedBox(height: 16),
          const SectionLabel('Contact Details'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: LabeledField(label: 'Contact Person', child: AppInput(controller: _contact))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Designation', child: AppInput(controller: _designation))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: LabeledField(
                    label: 'Mobile',
                    child: AppInput(controller: _mobile, keyboardType: TextInputType.phone, digitsOnly: true, maxLength: 10))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Email', child: AppInput(controller: _email))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledField(label: 'Department', child: AppInput(controller: _department))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Address', child: AppInput(controller: _address))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: LabeledField(
                    label: 'Expected Timeline',
                    child: AppInput(controller: _timeline, hint: 'e.g. Q2 2025'))),
            const SizedBox(width: 12),
            Expanded(
              child: LabeledField(
                label: 'Follow Up Date',
                child: DateField(
                  value: _followUp,
                  onChanged: (v) => setState(() => _followUp = v),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionLabel('Products & OEMs'),
          const SizedBox(height: 8),
          ProductsEditor(
            products: _products2,
            productOptions: _products,
            oemOptions: _oems,
            onChanged: (p) => setState(() => _products2 = p),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: LabeledField(
                    label: 'Product Description',
                    child: AppInput(controller: _productDesc, maxLines: 3))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Notes', child: AppInput(controller: _notes, maxLines: 3))),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                  onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save, size: 14),
                label: Text(_saving ? 'Saving…' : 'Update Opportunity'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
