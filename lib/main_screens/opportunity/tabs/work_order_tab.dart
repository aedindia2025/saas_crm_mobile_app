// tabs/work_order_tab.dart
//
// Work Order status & progress for direct opportunities — port of WorkOrderTab.tsx.
// Reads GET /workorders/by-lead/{lead_id}; updates via
// PATCH /workorders/{id}/progress?progress=0&status=Won|Lost (query params).
//
// FIX:
// - Prevents "BoxConstraints forces an infinite width" caused by app/global
//   button styles that set OutlinedButton minimum width to infinity inside Rows.
// - Makes the header and action buttons responsive on small screens.

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/opportunity_lead.dart';
import '../widgets/ui.dart';

const _woStatuses = ['Won', 'Lost'];

class WorkOrderTab extends StatefulWidget {
  final OpportunityLead lead;
  final ValueChanged<String>? onStatusChange;
  final ValueChanged<bool>? onWonStatusLoaded;

  const WorkOrderTab({
    super.key,
    required this.lead,
    this.onStatusChange,
    this.onWonStatusLoaded,
  });

  @override
  State<WorkOrderTab> createState() => _WorkOrderTabState();
}

class _WorkOrderTabState extends State<WorkOrderTab> {
  Map<String, dynamic>? _po;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String _status = 'Draft';

  ButtonStyle get _compactOutlinedButtonStyle => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 40),
    fixedSize: null,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
  );

  ButtonStyle get _compactFilledButtonStyle => FilledButton.styleFrom(
    minimumSize: const Size(0, 40),
    fixedSize: null,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      dynamic res;
      try {
        res = await ApiClient.getJson('/workorders/by-lead/${widget.lead.id}');
      } catch (_) {}
      if (res is Map) {
        _po = Map<String, dynamic>.from(res);
        final s = _po!['wo_status']?.toString() ?? 'Draft';
        _status = s;
        widget.onStatusChange?.call(s);
        widget.onWonStatusLoaded?.call(s == 'Won' || s == 'Completed');
      }
    } catch (_) {
      // Keep UI non-blocking; caller already shows the empty state when _po is null.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update() async {
    if (_po == null || _saving) return;

    if (mounted) setState(() => _saving = true);
    try {
      await ApiClient.patch(
        '/workorders/${_po!['id']}/progress',
        query: {'progress': 0, 'status': _status},
      );
      if (!mounted) return;
      Toast.success(context, 'Work Order status updated');
      widget.onStatusChange?.call(_status);
      setState(() => _editing = false);
      await _load();
    } catch (e) {
      if (mounted) Toast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Loading…', style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    if (_po == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Column(
          children: [
            Icon(Icons.error_outline, size: 26, color: Color(0xFFFBBF24)),
            SizedBox(height: 6),
            Text(
              'No Work Order Found',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Complete PO Details first. The Work Order becomes available once PO data is saved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
      );
    }

    final po = _po!;
    final currentStatus = po['wo_status']?.toString() ?? 'Draft';
    final progress = _asNum(po['progress_percent']);
    final statusColors = {
      'Won': [const Color(0xFFECFDF5), const Color(0xFF047857), const Color(0xFFA7F3D0)],
      'Lost': [const Color(0xFFFEF2F2), const Color(0xFFB91C1C), const Color(0xFFFECACA)],
    }[currentStatus] ??
        [const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFFE5E7EB)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final showEditButton = !_editing && !['Won', 'Lost', 'Completed'].contains(currentStatus);
                  final isNarrow = constraints.maxWidth < 340;

                  final titleBlock = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                po['po_number']?.toString() ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: StatusPill(
                                currentStatus,
                                bg: statusColors[0],
                                fg: statusColors[1],
                                border: statusColors[2],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          po['project_title']?.toString() ?? widget.lead.leadTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  );

                  final editButton = showEditButton
                      ? SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: _compactOutlinedButtonStyle,
                      onPressed: () => setState(() {
                        _status = _woStatuses.contains(currentStatus) ? currentStatus : _woStatuses.first;
                        _editing = true;
                      }),
                      child: const Text('Edit Status'),
                    ),
                  )
                      : const SizedBox.shrink();

                  if (isNarrow && showEditButton) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _workOrderIcon(),
                            const SizedBox(width: 10),
                            titleBlock,
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: editButton),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _workOrderIcon(),
                      const SizedBox(width: 10),
                      titleBlock,
                      if (showEditButton) ...[
                        const SizedBox(width: 8),
                        editButton,
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = [
                    _metric(Icons.attach_money, 'PO Value', Fmt.money(_asNum(po['po_value']))),
                    _metric(Icons.attach_money, 'WO Value', Fmt.money(_asNum(po['wo_value']))),
                    _metric(Icons.event_outlined, 'Delivery', Fmt.date(po['delivery_date'])),
                  ];

                  if (constraints.maxWidth < 330) {
                    return Column(
                      children: [
                        metrics[0],
                        const SizedBox(height: 8),
                        metrics[1],
                        const SizedBox(height: 8),
                        metrics[2],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: metrics[0]),
                      const SizedBox(width: 10),
                      Expanded(child: metrics[1]),
                      const SizedBox(width: 10),
                      Expanded(child: metrics[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Progress', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const Spacer(),
                  Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: (progress / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                ),
              ),
            ],
          ),
        ),
        if (_editing) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Update Status & Progress'),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Outcome',
                  child: AppDropdown<String>(
                    value: _woStatuses.contains(_status) ? _status : _woStatuses.first,
                    items: _woStatuses,
                    onChanged: (v) => setState(() => _status = v ?? 'Won'),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cancel = SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        style: _compactOutlinedButtonStyle,
                        onPressed: () => setState(() {
                          _editing = false;
                          _status = currentStatus;
                        }),
                        child: const Text('Cancel'),
                      ),
                    );

                    final update = SizedBox(
                      height: 40,
                      child: FilledButton.icon(
                        style: _compactFilledButtonStyle,
                        onPressed: _saving ? null : _update,
                        icon: const Icon(Icons.save, size: 14),
                        label: Text(_saving ? 'Saving…' : 'Update'),
                      ),
                    );

                    if (constraints.maxWidth < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cancel,
                          const SizedBox(height: 8),
                          update,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        cancel,
                        const SizedBox(width: 8),
                        update,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _workOrderIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF7C3AED)),
    );
  }

  Widget _metric(IconData icon, String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}