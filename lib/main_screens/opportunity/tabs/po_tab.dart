// tabs/po_tab.dart
//
// PO Details for the Direct Opportunity flow — port of POTab.tsx.
// Saves to POST /workorders with lead_id (multipart/form-data).
// Does NOT create a separate Work Order module entry.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';
import '../widgets/searchable_select.dart';
import '../widgets/ui.dart';

const _woTypes = ['Supply', 'AMC', 'Installation', 'Service', 'Turnkey', 'Other'];

class POTab extends StatefulWidget {
  final OpportunityLead lead;
  final ValueChanged<String>? onStatusChange;
  final VoidCallback? onPOSaved;
  final bool disabled;

  const POTab({
    super.key,
    required this.lead,
    this.onStatusChange,
    this.onPOSaved,
    this.disabled = false,
  });

  @override
  State<POTab> createState() => _POTabState();
}

class _POTabState extends State<POTab> {
  Map<String, dynamic>? _poData;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  List<String> _errors = [];
  PlatformFile? _poDocFile;
  List<SelectOpt> _users = [];

  // form
  String _woType = 'Supply';
  final _customerName = TextEditingController();
  final _projectTitle = TextEditingController();
  final _poNumber = TextEditingController();
  String _poDate = '';
  final _poValue = TextEditingController();
  final _woValue = TextEditingController();
  final _warranty = TextEditingController(text: '12');
  final _noConsignee = TextEditingController(text: '1');
  String _deliveryDate = '';
  String _installationDate = '';
  final _siteLocation = TextEditingController();
  int? _siteEngineer;
  final _siteEngineerPhone = TextEditingController();
  final _advance = TextEditingController(text: '0');
  final _retention = TextEditingController(text: '0');
  final _paymentTerms = TextEditingController();
  final _scopeOfWork = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      dynamic poRes;
      try {
        poRes = await ApiClient.getJson('/workorders/by-lead/${widget.lead.id}');
      } catch (_) {}
      final usersRes = await ApiClient.getJson('/workorders/users');
      _users = (((usersRes is Map ? usersRes['users'] : null) as List?) ?? [])
          .map((u) => SelectOpt(
              u['id'],
              '${u['full_name']}${u['employee_code'] != null ? ' (${u['employee_code']})' : ''}'))
          .toList();

      if (poRes is Map) {
        _poData = Map<String, dynamic>.from(poRes);
        final po = _poData!;
        _woType = po['wo_type']?.toString() ?? 'Supply';
        _customerName.text = po['customer_name']?.toString() ?? widget.lead.customerName ?? '';
        _projectTitle.text = po['project_title']?.toString() ?? widget.lead.leadTitle;
        _poNumber.text = po['po_number']?.toString() ?? '';
        _poDate = po['po_date']?.toString() ?? '';
        _poValue.text = '${po['po_value'] ?? ''}';
        _woValue.text = '${po['wo_value'] ?? ''}';
        _warranty.text = '${po['warranty_months'] ?? 12}';
        _noConsignee.text = '${po['no_of_consignee'] ?? 1}';
        _deliveryDate = po['delivery_date']?.toString() ?? '';
        _installationDate = po['installation_date']?.toString() ?? '';
        _siteLocation.text = po['site_location']?.toString() ?? '';
        _siteEngineer = po['site_engineer'] is int
            ? po['site_engineer']
            : int.tryParse('${po['site_engineer']}');
        _siteEngineerPhone.text = po['site_engineer_phone']?.toString() ?? '';
        _advance.text = '${po['advance_percent'] ?? 0}';
        _retention.text = '${po['retention_percent'] ?? 0}';
        _paymentTerms.text = po['payment_terms']?.toString() ?? '';
        _scopeOfWork.text = po['scope_of_work']?.toString() ?? '';
        widget.onStatusChange?.call('done');
      } else {
        _customerName.text = widget.lead.customerName ?? '';
        _projectTitle.text = widget.lead.leadTitle;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _validate() {
    final e = <String>[];
    if (_poNumber.text.trim().isEmpty) e.add('PO Number is required');
    if (_poDate.isEmpty) e.add('PO Date is required');
    if ((num.tryParse(_poValue.text) ?? 0) <= 0) e.add('PO Value must be greater than 0');
    if ((num.tryParse(_woValue.text) ?? 0) <= 0) e.add('WO Value must be greater than 0');
    if (_deliveryDate.isEmpty) e.add('Delivery Date is required');
    if (_installationDate.isEmpty) e.add('Installation Date is required');
    if (_siteLocation.text.trim().isEmpty) e.add('Site Location is required');
    if (_siteEngineer == null) e.add('Site Engineer is required');
    if (_siteEngineerPhone.text.trim().isEmpty) e.add('Engineer Phone is required');
    if (_scopeOfWork.text.trim().isEmpty) e.add('Scope of Work is required');
    if (_paymentTerms.text.trim().isEmpty) e.add('Payment Terms are required');
    if (_poDocFile == null && (_poData?['po_doc'] == null)) e.add('PO Document upload is required');
    return e;
  }

  Future<void> _pickDoc() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _poDocFile = res.files.first);
  }

  Future<void> _save() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }
    setState(() {
      _errors = [];
      _saving = true;
    });
    try {
      final fields = <String, String>{
        'lead_id': widget.lead.id.toString(),
        'wo_type': _woType,
        'customer_name': _customerName.text,
        'project_title': _projectTitle.text,
        'po_number': _poNumber.text,
        'po_date': _poDate,
        'po_value': '${num.tryParse(_poValue.text) ?? 0}',
        'wo_value': '${num.tryParse(_woValue.text) ?? 0}',
        'warranty_months': '${int.tryParse(_warranty.text) ?? 12}',
        'no_of_consignee': '${int.tryParse(_noConsignee.text) ?? 1}',
        'delivery_date': _deliveryDate,
        'installation_date': _installationDate,
        'site_location': _siteLocation.text,
        'site_engineer': '${_siteEngineer ?? ''}',
        'site_engineer_phone': _siteEngineerPhone.text,
        'advance_percent': _advance.text,
        'retention_percent': _retention.text,
        'payment_terms': _paymentTerms.text,
        'scope_of_work': _scopeOfWork.text,
      };
      if (_poData?['wo_number'] != null) fields['wrk_order_id'] = '${_poData!['wo_number']}';
      fields.removeWhere((k, v) => v.isEmpty);

      final files = <MultipartFile>[];
      if (_poDocFile != null && _poDocFile!.bytes != null) {
        // storage quota pre-check (mirror web flow)
        await ApiClient.multipart('/storage/check-file', fields: {
          if (_poData?['po_doc'] != null) 'replace_file_url': '${_poData!['po_doc']}',
        }, files: [
          MultipartFile(field: 'files', filename: _poDocFile!.name, bytes: _poDocFile!.bytes!),
        ]);
        files.add(MultipartFile(
            field: 'po_doc_file', filename: _poDocFile!.name, bytes: _poDocFile!.bytes!));
      }

      await ApiClient.multipart('/workorders', fields: fields, files: files);
      if (!mounted) return;
      Toast.success(context, 'PO Details saved');
      widget.onStatusChange?.call('done');
      widget.onPOSaved?.call();
      setState(() {
        _editing = false;
        _poDocFile = null;
      });
      _load();
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _previewExisting() async {
    final path = _poData?['po_doc']?.toString();
    if (path == null) return;
    final url = '${ApiClient.baseUrl}/preview/file?path=${Uri.encodeComponent(path)}';
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (mounted) Toast.error(context, 'Could not open document');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Loading…', style: TextStyle(color: Color(0xFF94A3B8))),
        ]),
      );
    }

    final isNew = _poData == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_poData != null && !_editing) _summary(),
        if ((isNew || _editing) && !widget.disabled) _form(isNew),
      ],
    );
  }

  Widget _summary() {
    final po = _poData!;
    final metrics = [
      ['PO Value', Fmt.money((po['po_value'] ?? 0) as num)],
      ['WO Value', Fmt.money((po['wo_value'] ?? 0) as num)],
      ['WO Type', po['wo_type']?.toString() ?? '—'],
      ['PO Date', Fmt.date(po['po_date'])],
      ['Delivery Date', Fmt.date(po['delivery_date'])],
      ['Warranty', '${po['warranty_months'] ?? 12} months'],
      ['No. of Consignees', '${po['no_of_consignee'] ?? 1}'],
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(po['po_number']?.toString() ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const SizedBox(width: 8),
                      const StatusPill('PO Saved',
                          bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFA7F3D0)),
                    ]),
                    const SizedBox(height: 2),
                    Text(po['project_title']?.toString() ?? widget.lead.leadTitle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              if (!widget.disabled)
                OutlinedButton(onPressed: () => setState(() => _editing = true), child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final m in metrics)
                Container(
                  width: (MediaQuery.of(context).size.width - 32 - 20 - 20) / 3,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m[0].toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 4),
                      Text(m[1], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          if (po['po_doc'] != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _previewExisting,
              icon: const Icon(Icons.visibility_outlined, size: 13),
              label: const Text('Preview PO Document'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _form(bool isNew) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errors.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                  SizedBox(width: 6),
                  Text('Please fix the following:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C))),
                ]),
                const SizedBox(height: 6),
                for (final e in _errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4),
                    child: Text('•  $e', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
        _formSection('Basic Details', [
          Row(children: [
            Expanded(
              child: SearchableSelect(
                label: 'WO Type',
                options: [for (int i = 0; i < _woTypes.length; i++) SelectOpt(i, _woTypes[i])],
                value: _woTypes.indexOf(_woType),
                onChanged: (v) => setState(() => _woType = _woTypes[v ?? 0]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Customer Name', required: true, child: AppInput(controller: _customerName))),
          ]),
          const SizedBox(height: 12),
          LabeledField(label: 'Project Title', child: AppInput(controller: _projectTitle)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledField(label: 'PO Number', required: true, child: AppInput(controller: _poNumber))),
            const SizedBox(width: 12),
            Expanded(
                child: LabeledField(
                    label: 'PO Date',
                    required: true,
                    child: DateField(value: _poDate, onChanged: (v) => setState(() => _poDate = v)))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _moneyField('PO Value (₹)', _poValue)),
            const SizedBox(width: 12),
            Expanded(child: _moneyField('WO Value (₹)', _woValue)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: LabeledField(
                    label: 'Warranty (months)',
                    child: AppInput(controller: _warranty, keyboardType: TextInputType.number, digitsOnly: true))),
            const SizedBox(width: 12),
            Expanded(
                child: LabeledField(
                    label: 'No. of Consignees',
                    required: true,
                    child: AppInput(controller: _noConsignee, keyboardType: TextInputType.number, digitsOnly: true))),
          ]),
          const SizedBox(height: 12),
          _poDocBox(),
        ]),
        const SizedBox(height: 16),
        _formSection('Schedule', [
          Row(children: [
            Expanded(
                child: LabeledField(
                    label: 'Delivery Date',
                    required: true,
                    child: DateField(value: _deliveryDate, onChanged: (v) => setState(() => _deliveryDate = v)))),
            const SizedBox(width: 12),
            Expanded(
                child: LabeledField(
                    label: 'Installation Date',
                    required: true,
                    child: DateField(value: _installationDate, onChanged: (v) => setState(() => _installationDate = v)))),
          ]),
          const SizedBox(height: 12),
          LabeledField(label: 'Site Location', required: true, child: AppInput(controller: _siteLocation)),
          const SizedBox(height: 12),
          SearchableSelect(
            label: 'Site Engineer',
            required: true,
            options: _users,
            value: _siteEngineer,
            placeholder: 'Search by name or employee code…',
            onChanged: (v) => setState(() => _siteEngineer = v),
          ),
          const SizedBox(height: 12),
          LabeledField(label: 'Engineer Phone', required: true, child: AppInput(controller: _siteEngineerPhone, keyboardType: TextInputType.phone)),
        ]),
        const SizedBox(height: 16),
        _formSection('Payment Terms', [
          Row(children: [
            Expanded(child: LabeledField(label: 'Advance %', child: AppInput(controller: _advance, keyboardType: TextInputType.number))),
            const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Retention %', child: AppInput(controller: _retention, keyboardType: TextInputType.number))),
          ]),
          const SizedBox(height: 12),
          LabeledField(
              label: 'Payment Terms',
              required: true,
              child: AppInput(controller: _paymentTerms, maxLines: 4, hint: 'Describe payment terms…')),
        ]),
        const SizedBox(height: 16),
        _formSection('Scope of Work', [
          AppInput(controller: _scopeOfWork, maxLines: 5, hint: 'Describe the scope of work…'),
        ]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_editing)
              OutlinedButton(
                  onPressed: () => setState(() {
                        _editing = false;
                        _errors = [];
                      }),
                  child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save, size: 14),
              label: Text(_saving ? 'Saving…' : 'Save PO Details'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moneyField(String label, TextEditingController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledField(
              label: label,
              required: true,
              child: AppInput(controller: c, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          if ((num.tryParse(c.text) ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${Fmt.words(num.parse(c.text))} Only',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF6B7280))),
            ),
        ],
      );

  Widget _poDocBox() {
    final existing = _poData?['po_doc']?.toString();
    final hasNew = _poDocFile != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF).withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 15, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              const Expanded(
                  child: Text('PO Document',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
              if (existing != null && !hasNew)
                TextButton.icon(
                    onPressed: _previewExisting,
                    icon: const Icon(Icons.visibility_outlined, size: 12),
                    label: const Text('Preview')),
              TextButton.icon(
                  onPressed: _pickDoc,
                  icon: const Icon(Icons.upload, size: 12),
                  label: Text(existing != null ? 'Re-upload' : 'Upload')),
              if (hasNew)
                IconButton(
                    onPressed: () => setState(() => _poDocFile = null),
                    icon: const Icon(Icons.close, size: 14, color: Color(0xFFF87171))),
            ],
          ),
          if (hasNew)
            _docChip(Icons.check_circle, _poDocFile!.name,
                '${(_poDocFile!.size / 1024).toStringAsFixed(0)} KB · ready to upload',
                const Color(0xFF10B981))
          else if (existing != null)
            _docChip(Icons.description, existing.split('/').last, 'Saved ✓', const Color(0xFF3B82F6))
          else
            InkWell(
              onTap: _pickDoc,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Column(children: [
                  Icon(Icons.upload, size: 20, color: Color(0xFF9CA3AF)),
                  SizedBox(height: 4),
                  Text('Click to upload PDF, JPG, or PNG',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _docChip(IconData icon, String name, String meta, Color color) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color))),
          Text(meta, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
        ]),
      );

  Widget _formSection(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}
