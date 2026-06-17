// tabs/consignee_tab.dart
//
// Consignees for the Direct Opportunity flow — port of ConsigneeTab.tsx.
// Table list + add/edit modal, pincode auto-fill, Excel bulk import, mail customer.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';
import '../widgets/ui.dart';

class ConsigneeTab extends StatefulWidget {
  final OpportunityLead lead;
  final ValueChanged<String>? onStatusChange;
  final bool disabled;

  const ConsigneeTab({
    super.key,
    required this.lead,
    this.onStatusChange,
    this.disabled = false,
  });

  @override
  State<ConsigneeTab> createState() => _ConsigneeTabState();
}

class _ConsigneeTabState extends State<ConsigneeTab> {
  List<Map<String, dynamic>> _consignees = [];
  int? _maxCount;
  bool _loading = true;
  bool _importing = false;
  int? _deleting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final consRes = await ApiClient.getJson('/consignees/', query: {'lead_id': widget.lead.id});
      dynamic poRes;
      try {
        poRes = await ApiClient.getJson('/workorders/by-lead/${widget.lead.id}');
      } catch (_) {}
      final rows = (consRes is List ? consRes : [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
          .cast<Map<String, dynamic>>();
      setState(() {
        _consignees = rows;
        if (poRes is Map && poRes['no_of_consignee'] != null) {
          _maxCount = int.tryParse('${poRes['no_of_consignee']}');
        }
      });
      if (rows.isNotEmpty) widget.onStatusChange?.call('done');
    } catch (e) {
      if (mounted) Toast.error(context, 'Failed to load consignees');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _limitReached => _maxCount != null && _consignees.length >= _maxCount!;

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete consignee'),
        content: Text('Delete consignee "${c['consignee_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = c['id']);
    try {
      await ApiClient.delete('/consignees/${c['id']}');
      if (mounted) Toast.success(context, 'Consignee deleted');
      _load();
    } catch (e) {
      if (mounted) Toast.error(context, 'Failed to delete');
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  Future<void> _openModal({Map<String, dynamic>? initial}) async {
    if (initial == null && _limitReached) {
      Toast.error(context, 'Maximum $_maxCount consignee(s) allowed as per PO details');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ConsigneeModal(
        leadId: widget.lead.id,
        initial: initial,
        existingNames: _consignees.map((c) => c['consignee_name'].toString()).toList(),
        maxCount: _maxCount,
        existingCount: _consignees.length,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _import() async {
    if (_limitReached) {
      Toast.error(context, 'Maximum $_maxCount consignee(s) allowed as per PO details');
      return;
    }
    final res = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    setState(() => _importing = true);
    try {
      final r = await ApiClient.multipart(
        '/consignees/bulk-import-lead?lead_id=${widget.lead.id}',
        files: [MultipartFile(field: 'file', filename: f.name, bytes: f.bytes!)],
      );
      final created = (r is Map ? r['created'] : 0) ?? 0;
      final errs = (r is Map ? r['errors'] : null) as List? ?? [];
      if (created > 0 && mounted) Toast.success(context, 'Imported $created consignee(s)');
      if (errs.isNotEmpty && mounted) Toast.error(context, errs.take(3).join(' | '));
      _load();
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _mailCustomer() async {
    final email = widget.lead.email;
    if (email == null || email.isEmpty) {
      Toast.error(context, 'No email address found for this customer');
      return;
    }
    final subject = 'Consignee / Delivery Details — ${widget.lead.leadTitle}';
    final lines = <String>[
      'Dear ${widget.lead.contactPerson ?? widget.lead.customerName ?? 'Sir/Madam'},',
      '',
      'Please find below the consignee / delivery details for "${widget.lead.leadTitle}":',
      '',
      for (int i = 0; i < _consignees.length; i++)
        '${i + 1}. ${_consignees[i]['consignee_name']}'
            '${_consignees[i]['city'] != null ? ' — ${[
                _consignees[i]['city'],
                _consignees[i]['state']
              ].where((x) => x != null).join(', ')}' : ''}'
            '${_consignees[i]['delivery_date'] != null ? ' | Delivery: ${_consignees[i]['delivery_date']}' : ''}',
      '',
      'Regards',
    ];
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(lines.join('\n'))}',
    );
    if (!await launchUrl(uri)) {
      if (mounted) Toast.error(context, 'Could not open mail app');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header
        Row(
          children: [
            const Icon(Icons.place_outlined, size: 16, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            const Text('Consignee / Delivery Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            StatusPill(
              '${_consignees.length}${_maxCount != null ? ' / $_maxCount' : ''}',
              bg: _limitReached ? const Color(0xFFD1FAE5) : const Color(0xFFECFDF5),
              fg: const Color(0xFF047857),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!widget.disabled)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((widget.lead.email ?? '').isNotEmpty)
                OutlinedButton.icon(
                    onPressed: _mailCustomer,
                    icon: const Icon(Icons.mail_outline, size: 12),
                    label: const Text('Mail Customer')),
              OutlinedButton.icon(
                onPressed: _importing || _limitReached ? null : _import,
                icon: _importing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload, size: 12),
                label: Text(_importing ? 'Importing…' : 'Import Excel'),
              ),
              FilledButton.icon(
                onPressed: _limitReached ? null : () => _openModal(),
                icon: const Icon(Icons.add, size: 12),
                label: const Text('Add Consignee'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              ),
            ],
          ),
        const SizedBox(height: 12),

        if (_limitReached && !widget.disabled)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA))),
            child: Text(
                'All $_maxCount consignee slot(s) filled. Remove one to add another.',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_consignees.isEmpty)
          _empty()
        else
          _list(),
      ],
    );
  }

  Widget _empty() => Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 2)),
        child: Column(children: [
          const Icon(Icons.place_outlined, size: 22, color: Color(0xFF6EE7B7)),
          const SizedBox(height: 6),
          const Text('No consignees added yet',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 4),
          const Text('Add manually or bulk import from Excel',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 12),
          if (!widget.disabled)
            FilledButton.icon(
                onPressed: () => _openModal(),
                icon: const Icon(Icons.add, size: 12),
                label: const Text('Add First Consignee'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669))),
        ]),
      );

  Widget _list() => Column(
        children: [
          for (int i = 0; i < _consignees.length; i++) _row(i, _consignees[i]),
        ],
      );

  Widget _row(int i, Map<String, dynamic> c) {
    final loc = [c['city'], c['state']].where((x) => x != null && '$x'.isNotEmpty).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
            child: Text('${i + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['consignee_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (loc.isNotEmpty) loc,
                    if ((c['contact_person'] ?? '').toString().isNotEmpty) c['contact_person'],
                    if ((c['contact_phone'] ?? '').toString().isNotEmpty) c['contact_phone'],
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                if ((c['delivery_date'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: StatusPill('Delivery: ${Fmt.date(c['delivery_date'])}',
                        bg: const Color(0xFFFFFBEB), fg: const Color(0xFFB45309), border: const Color(0xFFFDE68A)),
                  ),
              ],
            ),
          ),
          if (!widget.disabled) ...[
            IconButton(
                onPressed: () => _openModal(initial: c),
                icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF94A3B8))),
            IconButton(
                onPressed: _deleting == c['id'] ? null : () => _delete(c),
                icon: _deleting == c['id']
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline, size: 15, color: Color(0xFF94A3B8))),
          ],
        ],
      ),
    );
  }
}

// ─── Add / Edit modal ────────────────────────────────────────────────────────

class _ConsigneeModal extends StatefulWidget {
  final int leadId;
  final Map<String, dynamic>? initial;
  final List<String> existingNames;
  final int? maxCount;
  final int existingCount;

  const _ConsigneeModal({
    required this.leadId,
    this.initial,
    required this.existingNames,
    this.maxCount,
    required this.existingCount,
  });

  @override
  State<_ConsigneeModal> createState() => _ConsigneeModalState();
}

class _ConsigneeModalState extends State<_ConsigneeModal> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  String _deliveryDate = '';
  final _notes = TextEditingController();

  bool _saving = false;
  bool _pinLoading = false;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _name.text = i['consignee_name']?.toString() ?? '';
      _address.text = i['address']?.toString() ?? '';
      _city.text = i['city']?.toString() ?? '';
      _state.text = i['state']?.toString() ?? '';
      _pincode.text = i['pincode']?.toString() ?? '';
      _contact.text = i['contact_person']?.toString() ?? '';
      _phone.text = i['contact_phone']?.toString() ?? '';
      _deliveryDate = i['delivery_date']?.toString() ?? '';
      _notes.text = i['notes']?.toString() ?? '';
    }
  }

  Future<void> _onPincode(String val) async {
    final cleaned = val.replaceAll(RegExp(r'\D'), '');
    final six = cleaned.length > 6 ? cleaned.substring(0, 6) : cleaned;
    _pincode.text = six;
    if (six.length != 6) return;
    setState(() => _pinLoading = true);
    try {
      final d = await ApiClient.getJson('/customers/pincode/$six');
      if (d is Map) {
        if ((d['city'] ?? '').toString().isNotEmpty) _city.text = d['city'];
        if ((d['state'] ?? '').toString().isNotEmpty) _state.text = d['state'];
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _pinLoading = false);
    }
  }

  bool _validate() {
    final e = <String, String>{};
    final today = DateTime.now();
    if (_name.text.trim().isEmpty) {
      e['name'] = 'Consignee name is required';
    } else {
      final key = _name.text.trim().toLowerCase();
      final others = widget.existingNames.where((n) =>
          widget.initial == null ||
          n.toLowerCase() != (widget.initial!['consignee_name']?.toString().toLowerCase() ?? ''));
      if (others.map((n) => n.toLowerCase()).contains(key)) {
        e['name'] = 'A consignee with this name already exists';
      } else if (widget.initial == null &&
          widget.maxCount != null &&
          widget.existingCount >= widget.maxCount!) {
        e['name'] = 'Consignee limit reached (${widget.maxCount} allowed)';
      }
    }
    if (_address.text.trim().isEmpty) e['address'] = 'Address is required';
    if (_pincode.text.trim().isEmpty) {
      e['pincode'] = 'Pincode is required';
    } else if (!RegExp(r'^\d{6}$').hasMatch(_pincode.text)) {
      e['pincode'] = 'Must be 6 digits';
    }
    if (_city.text.trim().isEmpty) e['city'] = 'City is required';
    if (_state.text.trim().isEmpty) e['state'] = 'State is required';
    if (_contact.text.trim().isEmpty) e['contact'] = 'Contact person is required';
    if (_phone.text.trim().isEmpty) {
      e['phone'] = 'Contact phone is required';
    } else if (!RegExp(r'^\d{10}$').hasMatch(_phone.text)) {
      e['phone'] = 'Must be 10 digits';
    }
    if (_deliveryDate.isEmpty) {
      e['delivery'] = 'Delivery date is required';
    } else {
      final d = DateTime.tryParse(_deliveryDate);
      if (d == null || !d.isAfter(DateTime(today.year, today.month, today.day))) {
        e['delivery'] = 'Must be a future date';
      }
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(e);
    });
    return e.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    final data = {
      'consignee_name': _name.text,
      'address': _address.text,
      'city': _city.text,
      'state': _state.text,
      'pincode': _pincode.text,
      'contact_person': _contact.text,
      'contact_phone': _phone.text,
      'delivery_date': _deliveryDate,
      'notes': _notes.text,
      'items': [],
    };
    try {
      if (widget.initial != null) {
        await ApiClient.put('/consignees/${widget.initial!['id']}', data);
        if (mounted) Toast.success(context, 'Consignee updated');
      } else {
        await ApiClient.postJson('/consignees/', {'lead_id': widget.leadId, ...data});
        if (mounted) Toast.success(context, 'Consignee added');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.place_outlined, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.initial != null ? 'Edit Consignee' : 'Add Consignee',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 16)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _field('Consignee Name', _name, 'name', required: true),
                    const SizedBox(height: 12),
                    _field('Address', _address, 'address', required: true, maxLines: 2),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field('Pincode', _pincode, 'pincode',
                              required: true,
                              digitsOnly: true,
                              maxLength: 6,
                              suffix: _pinLoading ? '⏳' : null,
                              onChanged: _onPincode),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _field('City', _city, 'city', required: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _field('State', _state, 'state', required: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _field('Contact Person', _contact, 'contact', required: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _field('Phone (10 digits)', _phone, 'phone',
                                required: true, digitsOnly: true, maxLength: 10)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LabeledField(
                                label: 'Delivery Date',
                                required: true,
                                child: DateField(
                                  value: _deliveryDate,
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  onChanged: (v) => setState(() {
                                    _deliveryDate = v;
                                    _errors.remove('delivery');
                                  }),
                                ),
                              ),
                              if (_errors['delivery'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('⚠ ${_errors['delivery']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _field('Notes', _notes, 'notes')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(_saving ? 'Saving…' : (widget.initial != null ? 'Update' : 'Save Consignee')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, String key,
      {bool required = false,
      bool digitsOnly = false,
      int? maxLength,
      int maxLines = 1,
      String? suffix,
      ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledField(
          label: suffix != null ? '$label  $suffix' : label,
          required: required,
          child: AppInput(
            controller: c,
            maxLines: maxLines,
            maxLength: maxLength,
            digitsOnly: digitsOnly,
            keyboardType: digitsOnly ? TextInputType.number : null,
            onChanged: (v) {
              setState(() => _errors.remove(key));
              onChanged?.call(v);
            },
          ),
        ),
        if (_errors[key] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('⚠ ${_errors[key]}', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
      ],
    );
  }
}
