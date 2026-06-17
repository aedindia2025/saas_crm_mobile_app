// tabs/quotations_tab.dart
//
// List + manage quotation revisions (Q1/Q2/Q3) — port of QuotationsTab.tsx.
// Status flow: Draft → Sent → Approved/Accepted/Rejected.
// Accepted quotation unlocks the PO tab.

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';
import '../widgets/ui.dart';
import 'quotation_form.dart';
import 'quotation_letter_pad.dart';

const _statusColors = {
  'Draft': [Color(0xFFF3F4F6), Color(0xFF4B5563)],
  'Sent': [Color(0xFFEFF6FF), Color(0xFF1D4ED8)],
  'Approved': [Color(0xFFEEF2FF), Color(0xFF4338CA)],
  'Accepted': [Color(0xFFECFDF5), Color(0xFF047857)],
  'Rejected': [Color(0xFFFEF2F2), Color(0xFFB91C1C)],
};

class QuotationsTab extends StatefulWidget {
  final OpportunityLead lead;
  final ValueChanged<String>? onStatusChange;
  final VoidCallback? onQuotationAccepted;
  final bool disabled;

  const QuotationsTab({
    super.key,
    required this.lead,
    this.onStatusChange,
    this.onQuotationAccepted,
    this.disabled = false,
  });

  @override
  State<QuotationsTab> createState() => _QuotationsTabState();
}

class _QuotationsTabState extends State<QuotationsTab> {
  List<Map<String, dynamic>> _quotations = [];
  bool _loading = true;
  bool _newFormOpen = false;
  int? _inlineEditId;
  bool _revising = false;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.getJson('/quotations/by-lead/${widget.lead.id}');
      final qs = (res is List ? res : [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
          .cast<Map<String, dynamic>>();
      setState(() => _quotations = qs);
      final accepted = qs.cast<Map<String, dynamic>?>().firstWhere(
            (q) => q?['status'] == 'Accepted',
            orElse: () => null,
          );
      final best = accepted ?? (qs.isNotEmpty ? qs.first : null);
      if (best != null) widget.onStatusChange?.call(best['status']?.toString() ?? '');
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(Map<String, dynamic> q, String action) async {
    try {
      await ApiClient.postJson('/quotations/${q['id']}/$action');
      if (!mounted) return;
      Toast.success(context, 'Quotation marked as $action');
      if (action == 'accept') widget.onQuotationAccepted?.call();
      _load();
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    }
  }

  Future<void> _revise(Map<String, dynamic> q) async {
    setState(() => _revising = true);
    try {
      await ApiClient.postJson('/quotations/${q['id']}/revise');
      if (!mounted) return;
      Toast.success(context, 'New revision created');
      _load();
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _revising = false);
    }
  }

  bool get _hasAccepted => _quotations.any((q) => q['status'] == 'Accepted');
  bool get _hasAnyApproved => _quotations.any((q) =>
      q['approval_status'] == 'approved' || q['status'] == 'Accepted' || q['status'] == 'Approved');
  int get _maxRevision =>
      _quotations.fold(0, (m, q) => (q['revision_number'] ?? 0) > m ? q['revision_number'] : m);
  bool get _canAddNew => _quotations.isEmpty;

  Map<String, dynamic>? get _latest {
    if (_quotations.isEmpty) return null;
    final sorted = [..._quotations]
      ..sort((a, b) => (b['revision_number'] ?? 0).compareTo(a['revision_number'] ?? 0));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final latestId = _latest?['id'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quotations',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    _hasAccepted
                        ? 'Quotation accepted — proceed to PO'
                        : 'Create and send quotations to the customer (max 3 revisions)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            if (_canAddNew && !widget.disabled)
              FilledButton.icon(
                onPressed: () => setState(() => _newFormOpen = true),
                icon: const Icon(Icons.add, size: 13),
                label: const Text('New Quotation (Q1)'),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (_hasAccepted)
          _banner(Icons.check, 'Quotation accepted. You can now create the Purchase Order.',
              const Color(0xFFECFDF5), const Color(0xFF065F46), const Color(0xFFA7F3D0)),

        if (!_loading && _quotations.isEmpty) _empty(),

        for (final q in _quotations) ...[
          _QuotationCard(
            quotation: q,
            lead: widget.lead,
            expanded: _expandedId == q['id'],
            onToggle: () => setState(() => _expandedId = _expandedId == q['id'] ? null : q['id']),
            onRefresh: _load,
            onTransition: (a) => _transition(q, a),
            onRevise: () => _revise(q),
            revising: _revising,
            hasAnyApproved: _hasAnyApproved,
            canOpenLetterPad: q['id'] == latestId &&
                (q['approval_status'] == 'approved' || q['status'] == 'Accepted'),
            onEdit: widget.disabled
                ? null
                : () => setState(
                    () => _inlineEditId = _inlineEditId == q['id'] ? null : q['id']),
          ),
          if (_inlineEditId == q['id'] && !widget.disabled)
            _inlineForm('Edit ${q['quotation_number']} — Q${q['revision_number']}',
                existing: q),
          const SizedBox(height: 12),
        ],

        if (_newFormOpen && !widget.disabled)
          _inlineForm('New Quotation (Q1)', existing: null),
      ],
    );
  }

  Widget _inlineForm(String title, {Map<String, dynamic>? existing}) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF).withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            QuotationForm(
              lead: widget.lead,
              existingQuotation: existing,
              onSaved: (_) {
                setState(() {
                  _newFormOpen = false;
                  _inlineEditId = null;
                });
                _load();
              },
              onCancel: () => setState(() {
                _newFormOpen = false;
                _inlineEditId = null;
              }),
            ),
          ],
        ),
      );

  Widget _banner(IconData icon, String text, Color bg, Color fg, Color border) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
        child: Row(children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg))),
        ]),
      );

  Widget _empty() => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            const Icon(Icons.description_outlined, size: 28, color: Color(0xFFD1D5DB)),
            const SizedBox(height: 8),
            const Text('No quotations yet',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 12),
            if (!widget.disabled)
              FilledButton.icon(
                onPressed: () => setState(() => _newFormOpen = true),
                icon: const Icon(Icons.add, size: 13),
                label: const Text('Create Q1'),
              ),
          ],
        ),
      );
}

// ─── Quotation card ───────────────────────────────────────────────────────────

class _QuotationCard extends StatelessWidget {
  final Map<String, dynamic> quotation;
  final OpportunityLead lead;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;
  final void Function(String action) onTransition;
  final VoidCallback onRevise;
  final bool revising;
  final bool hasAnyApproved;
  final bool canOpenLetterPad;
  final VoidCallback? onEdit;

  const _QuotationCard({
    required this.quotation,
    required this.lead,
    required this.expanded,
    required this.onToggle,
    required this.onRefresh,
    required this.onTransition,
    required this.onRevise,
    required this.revising,
    required this.hasAnyApproved,
    required this.canOpenLetterPad,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final q = quotation;
    final status = q['status']?.toString() ?? '';
    final approval = q['approval_status']?.toString() ?? 'none';
    final isDraft = status == 'Draft';
    final isSent = status == 'Sent';
    final isAccepted = status == 'Accepted';
    final rev = q['revision_number'] ?? 1;
    final canRevise =
        approval == 'rejected' && rev < 3 && !isAccepted && !hasAnyApproved;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.description_outlined, size: 15, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(q['quotation_number']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            _revPill(rev),
                            const SizedBox(width: 6),
                            _approvalBadge(approval),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${q['subject'] ?? 'No subject'} · ${Fmt.date(q['created_at'])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(Fmt.money((q['total_amount'] ?? 0) as num),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Icon(expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16, color: const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              decoration:
                  const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusPill(status),
                      if ((q['valid_until'] ?? '').toString().isNotEmpty)
                        Text('Valid until: ${Fmt.date(q['valid_until'])}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      if ((q['ref_number'] ?? '').toString().isNotEmpty)
                        Text('Ref: ${q['ref_number']}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if ((q['line_items'] as List?)?.isNotEmpty ?? false) _lineItems(q),
                  if ((q['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${q['notes']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _actions(context, isDraft, isSent, approval, canRevise, rev),
                  if (approval == 'pending' && status != 'Accepted' && status != 'Approved') ...[
                    const SizedBox(height: 10),
                    _miniBanner(Icons.verified_user_outlined,
                        'Approval request pending. Waiting for approver decision.',
                        const Color(0xFFFFFBEB), const Color(0xFF92400E)),
                  ],
                  if (approval == 'rejected') ...[
                    const SizedBox(height: 10),
                    _rejectionBox(q, canRevise, rev),
                  ],
                  if (isAccepted) ...[
                    const SizedBox(height: 10),
                    _miniBanner(Icons.check,
                        'This quotation is accepted. Proceed to the PO tab to enter Purchase Order details.',
                        const Color(0xFFECFDF5), const Color(0xFF065F46)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, bool isDraft, bool isSent, String approval,
      bool canRevise, int rev) {
    final btns = <Widget>[];

    if (canOpenLetterPad) {
      btns.add(_outlineBtn(Icons.visibility_outlined, 'Letter Pad', () {
        showDialog(
          context: context,
          builder: (_) => QuotationLetterPad(quotation: quotation, lead: lead),
        );
      }));
    } else {
      btns.add(_lockedBtn(Icons.visibility_outlined, 'Letter Pad Locked'));
    }

    if ((isDraft || isSent) && (approval == 'none' || approval.isEmpty)) {
      btns.add(_outlineBtn(Icons.verified_user_outlined, 'Request Approval',
          () => _openApprovalSheet(context),
          color: const Color(0xFFB45309), border: const Color(0xFFFDE68A)));
    }
    if (isDraft && onEdit != null) {
      btns.add(_outlineBtn(Icons.edit_outlined, 'Edit', onEdit!,
          color: const Color(0xFF1D4ED8), border: const Color(0xFFBFDBFE)));
    }
    if (isSent && (approval == 'none' || approval.isEmpty)) {
      btns.add(_outlineBtn(Icons.check, 'Approve', () => onTransition('approve'),
          color: const Color(0xFF4338CA), border: const Color(0xFFC7D2FE)));
      btns.add(_filledBtn(Icons.check, 'Accept', () => onTransition('accept'),
          const Color(0xFF059669)));
      btns.add(_outlineBtn(Icons.close, 'Reject', () => onTransition('reject'),
          color: const Color(0xFFDC2626), border: const Color(0xFFFECACA)));
    }
    if (canRevise) {
      btns.add(_outlineBtn(Icons.copy, 'Revise (Q${rev + 1})', onRevise,
          color: const Color(0xFF7C3AED), border: const Color(0xFFDDD6FE)));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: btns);
  }

  void _openApprovalSheet(BuildContext context) {
    final notes = TextEditingController();
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSB) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF92400E)),
                  SizedBox(width: 6),
                  Text('Submit for Approval',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                ]),
                const SizedBox(height: 4),
                const Text('Sent to your reporting manager / configured approver automatically.',
                    style: TextStyle(fontSize: 10, color: Color(0xFFB45309))),
                const SizedBox(height: 10),
                AppInput(controller: notes, hint: 'Notes (optional)'),
                const SizedBox(height: 10),
                Row(children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                    onPressed: saving
                        ? null
                        : () async {
                            setSB(() => saving = true);
                            try {
                              await ApiClient.postJson(
                                  '/quotations/${quotation['id']}/request-approval',
                                  {'notes': notes.text.trim().isEmpty ? null : notes.text.trim()});
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) Toast.success(context, 'Approval request submitted');
                              onRefresh();
                            } catch (e) {
                              setSB(() => saving = false);
                              if (ctx.mounted) Toast.error(ctx, e.toString());
                            }
                          },
                    child: Text(saving ? 'Submitting…' : 'Submit for Approval'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _lineItems(Map<String, dynamic> q) {
    final items = (q['line_items'] as List).cast<Map<String, dynamic>>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 34,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        headingTextStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
        columns: const [
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Unit')),
          DataColumn(label: Text('Tax %')),
          DataColumn(label: Text('GST')),
          DataColumn(label: Text('Net')),
          DataColumn(label: Text('Total')),
        ],
        rows: [
          for (final it in items)
            DataRow(cells: [
              DataCell(Text(it['description']?.toString() ?? '')),
              DataCell(Text('${it['quantity']}')),
              DataCell(Text('₹${(it['unit_price'] as num? ?? 0).toStringAsFixed(2)}')),
              DataCell(Text('${it['tax_percent']}%')),
              DataCell(Text('₹${_gst(it).toStringAsFixed(2)}')),
              DataCell(Text('₹${_net(it).toStringAsFixed(2)}')),
              DataCell(Text('₹${(it['line_total'] as num? ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
        ],
      ),
    );
  }

  num _net(Map<String, dynamic> it) =>
      it['net_price'] ?? ((it['unit_price'] as num? ?? 0) * (it['quantity'] as num? ?? 0));
  num _gst(Map<String, dynamic> it) =>
      it['gst_value'] ?? (_net(it) * (it['tax_percent'] as num? ?? 0) / 100);

  Widget _rejectionBox(Map<String, dynamic> q, bool canRevise, int rev) {
    final reason = q['rejection_reason'] ?? q['approval_notes'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.close, size: 13, color: Color(0xFFB91C1C)),
            SizedBox(width: 6),
            Text('Approval Rejected',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
          ]),
          if (reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 19),
              child: Text('Reason: $reason',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ),
          if (canRevise)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 19),
              child: Text('Please revise the quotation (Q${rev + 1}) and resubmit for approval.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
            ),
        ],
      ),
    );
  }

  Widget _miniBanner(IconData icon, String text, Color bg, Color fg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: fg))),
        ]),
      );

  Widget _revPill(int rev) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDD6FE))),
        child: Text('Q$rev',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9))),
      );

  Widget _approvalBadge(String s) {
    if (s.isEmpty || s == 'none') return const SizedBox.shrink();
    final label = s == 'pending' ? 'Approval Pending' : s == 'approved' ? 'Approved' : 'Approval Rejected';
    final colors = {
      'pending': [const Color(0xFFFFFBEB), const Color(0xFFB45309)],
      'approved': [const Color(0xFFECFDF5), const Color(0xFF047857)],
      'rejected': [const Color(0xFFFEF2F2), const Color(0xFFDC2626)],
    }[s]!;
    return StatusPill(label, bg: colors[0], fg: colors[1]);
  }

  Widget _statusPill(String s) {
    final c = _statusColors[s] ?? [const Color(0xFFF3F4F6), const Color(0xFF6B7280)];
    return StatusPill(s, bg: c[0], fg: c[1]);
  }

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap,
      {Color color = const Color(0xFF64748B), Color border = const Color(0xFFE5E7EB)}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 12),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  Widget _filledBtn(IconData icon, String label, VoidCallback onTap, Color color) =>
      FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 12),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          minimumSize: const Size(0, 32),
        ),
      );

  Widget _lockedBtn(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF1F5F9))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: const Color(0xFFD1D5DB)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB))),
        ]),
      );
}
