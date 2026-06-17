// new_opportunity_page.dart
//
// "New Opportunity" creation screen — port of NewOpportunityPage.tsx.
// Shows the same 5-step stepper (only the first "Opportunity Details" step is
// active). On save: POST /leads with lead_type='direct_opportunity' and
// status='Opportunity Created', then opens the Opportunity view on the
// Quotations tab.

import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'models/opportunity_lead.dart';
import 'opportunity_view_page.dart';
import 'widgets/searchable_select.dart';
import 'widgets/ui.dart';

class NewOpportunityPage extends StatefulWidget {
  // Optional: prefill from an existing customer.
  final int? customerId;
  const NewOpportunityPage({super.key, this.customerId});

  @override
  State<NewOpportunityPage> createState() => _NewOpportunityPageState();
}

class _NewOpportunityPageState extends State<NewOpportunityPage> {
  bool _saving = false;

  // masters
  List<SelectOpt> _customers = [];
  List<SelectOpt> _sources = [];
  List<SelectOpt> _products = [];
  List<SelectOpt> _oems = [];
  List<SelectOpt> _users = [];
  List<SelectOpt> _businessUnits = [];

  // form
  final _title = TextEditingController();
  int? _customerId;
  String _customerName = '';
  final _estValue = TextEditingController();
  String _priority = 'Medium';
  int? _sourceId;
  int? _businessUnitId;
  int? _assignedTo;
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
  List<ProdEntry> _productList = [ProdEntry()];

  final _steps = const [
    'Opportunity Details',
    'Quotations',
    'PO Details',
    'Consignee',
    'Work Orders',
  ];

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
    _loadMasters();
    if (widget.customerId != null) _prefillCustomer(widget.customerId!);
  }

  Future<void> _loadMasters() async {
    try {
      final c = await ApiClient.getJson('/leads/team-customers');
      final s = await ApiClient.getJson('/masters/lead-sources');
      final p = await ApiClient.getJson('/masters/products');
      final o = await ApiClient.getJson('/masters/oems');
      final u = await ApiClient.getJson('/masters/users-for-select');
      dynamic bu;
      try {
        bu = await ApiClient.getJson('/masters/business-units');
      } catch (_) {}
      setState(() {
        _customers = (c as List)
            .where((x) => x['customer_name'] != null)
            .map((x) => SelectOpt(x['id'], x['customer_name'].toString()))
            .toList();
        _sources = _opts(s, 'name');
        _products = _opts(p, 'name');
        _oems = _opts(o, 'name');
        _users = (u as List)
            .where((x) => x['label'] != null)
            .map((x) => SelectOpt(x['id'], x['label'].toString()))
            .toList();
        if (bu is List) _businessUnits = _opts(bu, 'name');
      });
    } catch (_) {}
  }

  List<SelectOpt> _opts(dynamic list, String key) => (list as List)
      .where((x) => x[key] != null)
      .map((x) => SelectOpt(x['id'], x[key].toString()))
      .toList();

  Future<void> _prefillCustomer(int id) async {
    setState(() => _customerId = id);
    final found = _customers.where((c) => c.value == id).cast<SelectOpt?>().firstOrNull;
    if (found != null) _customerName = found.label;
    try {
      final c = await ApiClient.getJson('/customers/$id');
      _customerName = c['customer_name']?.toString() ?? _customerName;
      final city = c['billing_city'];
      final state = c['billing_state'];
      if (city != null || state != null) {
        _address.text = [city, state].where((x) => x != null && '$x'.isNotEmpty).join(', ');
      }
      final contacts = (c['contacts'] as List?) ?? [];
      final primary = contacts.firstWhere((x) => x['is_primary'] == true,
          orElse: () => contacts.isNotEmpty ? contacts.first : null);
      if (primary != null) {
        _contact.text = (primary['contact_name'] ?? '').toString();
        _designation.text = (primary['designation'] ?? '').toString();
        _mobile.text = (primary['mobile'] ?? '').toString();
        _email.text = (primary['office_email'] ?? '').toString();
        _department.text = (primary['department'] ?? '').toString();
      }
      setState(() {});
    } catch (_) {}
  }

  Future<void> _quickAdd(String endpoint, String label) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add $label'),
        content: AppInput(controller: ctrl, hint: 'Enter $label name'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    try {
      final res = await ApiClient.postJson(endpoint, {'name': value});
      final opt = SelectOpt(res['id'], res['name'].toString());
      setState(() {
        if (endpoint.contains('lead-sources')) {
          _sources = [..._sources, opt];
          _sourceId = opt.value;
        } else {
          _products = [..._products, opt];
        }
      });
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      Toast.error(context, 'Opportunity title is required');
      return;
    }
    if (_mobile.text.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(_mobile.text)) {
      Toast.error(context, 'Mobile must be 10 digits');
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiClient.postJson('/leads', {
        'lead_type': 'direct_opportunity',
        'status': 'Opportunity Created',
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
        'business_unit_id': _businessUnitId,
        'priority': _priority,
        'est_value': _estValue.text.isNotEmpty ? num.tryParse(_estValue.text) : null,
        'region': _region.text,
        'branch': _branch.text,
        'timeline': _timeline.text,
        'follow_up': _followUp.isEmpty ? null : _followUp,
        'product_description': _productDesc.text,
        'notes': _notes.text,
        'assigned_to': _assignedTo,
        'products': _productList
            .where((p) => p.productName.trim().isNotEmpty)
            .map((p) => p.toJson())
            .toList(),
      });
      final id = res['id'];
      if (!mounted) return;
      Toast.success(context, 'Opportunity created');
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OpportunityViewPage(leadId: id, initialTab: TabKey.quotations),
      ));
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('New Opportunity',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 17)),
        leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B))),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _stepper(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: _form(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (int i = 0; i < _steps.length; i++) ...[
                _step(i, _steps[i]),
                if (i < _steps.length - 1)
                  Container(
                      width: 48,
                      height: 2,
                      margin: const EdgeInsets.only(top: 20, left: 6, right: 6),
                      color: const Color(0xFFE2E8F0)),
              ]
            ],
          ),
        ),
      );

  Widget _step(int i, String label) {
    final active = i == 0;
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(
                  color: active ? const Color(0xFFDBEAFE) : const Color(0xFFE5E7EB), width: 4),
            ),
            child: Icon(active ? Icons.business_outlined : Icons.lock_outline,
                size: 17, color: active ? Colors.white : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: active ? const Color(0xFF1D4ED8) : const Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _form() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Opportunity Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const Divider(height: 24),

          LabeledField(
            label: 'Opportunity Title',
            required: true,
            child: AppInput(controller: _title),
          ),

          const SizedBox(height: 12),

          SearchableSelect(
            label: 'Customer / Account',
            options: _customers,
            value: _customerId,
            clearable: true,
            onChanged: (v) {
              if (v == null) {
                setState(() {
                  _customerId = null;
                  _customerName = '';
                });
              } else {
                _prefillCustomer(v);
              }
            },
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
                      child: AppInput(
                        controller: _estValue,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if ((num.tryParse(_estValue.text) ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${Fmt.words(num.parse(_estValue.text))} Rupees',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF60A5FA),
                          ),
                        ),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SearchableSelect(
                  label: 'Source',
                  options: _sources,
                  value: _sourceId,
                  clearable: true,
                  onChanged: (v) => setState(() => _sourceId = v),
                ),
              ),
              IconButton(
                onPressed: () => _quickAdd('/masters/lead-sources', 'Source'),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF2563EB),
                ),
                tooltip: 'Quick add source',
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (_businessUnits.isNotEmpty) ...[
            SearchableSelect(
              label: 'Business Vertical',
              options: _businessUnits,
              value: _businessUnitId,
              clearable: true,
              onChanged: (v) => setState(() => _businessUnitId = v),
            ),
            const SizedBox(height: 12),
          ],

          SearchableSelect(
            label: 'Assigned To',
            options: _users,
            value: _assignedTo,
            clearable: true,
            onChanged: (v) => setState(() => _assignedTo = v),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Region',
                  child: AppInput(controller: _region),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Branch',
                  child: AppInput(controller: _branch),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const SectionLabel('Contact Details'),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Contact Person',
                  child: AppInput(controller: _contact),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Designation',
                  child: AppInput(controller: _designation),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Mobile',
                  child: AppInput(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    digitsOnly: true,
                    maxLength: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Email',
                  child: AppInput(controller: _email),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Department',
                  child: AppInput(controller: _department),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  label: 'Address',
                  child: AppInput(controller: _address),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Expected Timeline',
                  child: AppInput(
                    controller: _timeline,
                    hint: 'e.g. Q2 2025',
                  ),
                ),
              ),
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
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SectionLabel('Products & OEMs'),
              TextButton.icon(
                onPressed: () => _quickAdd('/masters/products', 'Product'),
                icon: const Icon(Icons.add, size: 13),
                label: const Text('Quick add product'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ProductsEditor(
            products: _productList,
            productOptions: _products,
            oemOptions: _oems,
            onChanged: (p) => setState(() => _productList = p),
          ),

          const SizedBox(height: 16),

          LabeledField(
            label: 'Product Description',
            child: AppInput(
              controller: _productDesc,
              maxLines: 3,
              hint: 'Brief description of the requirement...',
            ),
          ),

          const SizedBox(height: 12),

          LabeledField(
            label: 'Notes',
            child: AppInput(
              controller: _notes,
              maxLines: 3,
            ),
          ),

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(
                    _saving ? 'Creating...' : 'Create & Continue',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
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
