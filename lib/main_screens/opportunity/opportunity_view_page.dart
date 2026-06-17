// opportunity_view_page.dart
//
// Full-page view for an Opportunity — Flutter port of OpportunityView.tsx.
//
//   lead_type == 'lead'               → Lead Details tab only
//   lead_type == 'direct_opportunity' → Lead · Quotations · PO · Consignee · Work Orders
//
// Tab-lock logic, auto-tab-on-load and "Won → read only" all mirror the web.

import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'models/opportunity_lead.dart';
import 'tabs/lead_details_tab.dart';
import 'tabs/quotations_tab.dart';
import 'tabs/po_tab.dart';
import 'tabs/consignee_tab.dart';
import 'tabs/work_order_tab.dart';

enum TabKey { lead, quotations, po, consignee, workorder }

class _TabDef {
  final TabKey key;
  final String label;
  final IconData icon;
  const _TabDef(this.key, this.label, this.icon);
}

const _directTabs = <_TabDef>[
  _TabDef(TabKey.lead, 'Opportunity Details', Icons.business_outlined),
  _TabDef(TabKey.quotations, 'Quotations', Icons.description_outlined),
  _TabDef(TabKey.po, 'PO Details', Icons.attach_money),
  _TabDef(TabKey.consignee, 'Consignee', Icons.local_shipping_outlined),
  _TabDef(TabKey.workorder, 'Work Orders', Icons.assignment_outlined),
];

const _leadTabs = <_TabDef>[
  _TabDef(TabKey.lead, 'Lead Details', Icons.business_outlined),
];

class OpportunityViewPage extends StatefulWidget {
  final int leadId;
  // Optional initial tab (e.g. 'quotations' after creating a direct opportunity).
  final TabKey? initialTab;

  const OpportunityViewPage({super.key, required this.leadId, this.initialTab});

  @override
  State<OpportunityViewPage> createState() => _OpportunityViewPageState();
}

class _OpportunityViewPageState extends State<OpportunityViewPage> {
  OpportunityLead? _lead;
  bool _loading = true;
  String? _error;

  TabKey _activeTab = TabKey.lead;
  final Map<TabKey, String> _tabStatuses = {};
  bool _isWon = false;
  bool _hasAcceptedQuotation = false;
  bool _hasPO = false;
  bool _autoTabSet = false;

  @override
  void initState() {
    super.initState();
    _loadLead();
  }

  void _setTabStatus(TabKey key, String status) {
    if (_tabStatuses[key] == status) return;
    setState(() => _tabStatuses[key] = status);
  }

  Future<void> _loadLead() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final leadData = await ApiClient.getJson('/leads/${widget.leadId}');

      // Best-effort parallel fetches (mirror web's .catch(()=>...) fallbacks).
      dynamic wo, poData;
      List quotes = [];
      try {
        wo = await ApiClient.getJson('/workorders/by-lead/${widget.leadId}');
      } catch (_) {}
      try {
        final q = await ApiClient.getJson('/quotations/by-lead/${widget.leadId}');
        quotes = q is List ? q : [];
      } catch (_) {}
      try {
        poData = await ApiClient.getJson('/opportunity-po/by-lead/${widget.leadId}');
      } catch (_) {}

      final lead = OpportunityLead.fromJson(Map<String, dynamic>.from(leadData));
      final accepted = quotes.any((q) => q['status'] == 'Accepted');
      final poExists = poData != null &&
          (poData['id'] != null || (poData['po_number']?.toString().isNotEmpty ?? false));
      final woStatus = wo is Map ? wo['wo_status'] : null;
      final wonOrCompleted = woStatus == 'Won' || woStatus == 'Completed';

      _hasAcceptedQuotation = accepted;
      _hasPO = poExists;
      _isWon = wonOrCompleted;

      if (wonOrCompleted && lead.isDirect) {
        _tabStatuses.putIfAbsent(TabKey.quotations, () => 'Won');
        _tabStatuses.putIfAbsent(TabKey.po, () => 'Won');
        _tabStatuses.putIfAbsent(TabKey.consignee, () => 'done');
        _tabStatuses.putIfAbsent(TabKey.workorder, () => 'Won');
      }

      // Auto-pick initial tab once, only for direct opportunities.
      if (!_autoTabSet && lead.isDirect) {
        _autoTabSet = true;
        if (widget.initialTab != null) {
          _activeTab = widget.initialTab!;
        } else if (wonOrCompleted || wo != null) {
          _activeTab = TabKey.workorder;
        } else if (accepted) {
          _activeTab = TabKey.po;
        } else if (quotes.isNotEmpty) {
          _activeTab = TabKey.quotations;
        }
      }

      if (!mounted) return;
      setState(() {
        _lead = lead;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Locked tabs — identical rules to the web lockedTabs useMemo.
  Set<TabKey> get _lockedTabs {
    final s = <TabKey>{};
    if (_isWon) return s; // won → everything visible (read-only)
    if (!_hasAcceptedQuotation) {
      s.addAll([TabKey.po, TabKey.consignee, TabKey.workorder]);
    } else if (!_hasPO) {
      s.addAll([TabKey.consignee, TabKey.workorder]);
    }
    return s;
  }

  void _onQuotationAccepted() {
    setState(() {
      _hasAcceptedQuotation = true;
      if (_activeTab == TabKey.quotations) _activeTab = TabKey.po;
    });
  }

  void _onPOSaved() {
    setState(() {
      _hasPO = true;
      if (_activeTab == TabKey.po) _activeTab = TabKey.consignee;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
              SizedBox(height: 12),
              Text('Loading opportunity…',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_error != null || _lead == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Opportunity not found',
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back to Opportunities'),
              ),
            ],
          ),
        ),
      );
    }

    final lead = _lead!;
    final tabs = lead.isDirect ? _directTabs : _leadTabs;
    final safeTab = tabs.any((t) => t.key == _activeTab) ? _activeTab : TabKey.lead;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _Header(lead: lead, isWon: _isWon, loading: _loading, onRefresh: _loadLead),
            _TabBar(
              tabs: tabs,
              active: safeTab,
              statuses: _tabStatuses,
              locked: _lockedTabs,
              onChange: (k) => setState(() => _activeTab = k),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _buildTab(safeTab, lead),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(TabKey tab, OpportunityLead lead) {
    switch (tab) {
      case TabKey.lead:
        return LeadDetailsTab(
          lead: lead,
          disabled: _isWon,
          onLeadUpdated: _loadLead,
          onNext: () => setState(() => _activeTab = TabKey.quotations),
        );
      case TabKey.quotations:
        return QuotationsTab(
          lead: lead,
          disabled: _isWon,
          onStatusChange: (s) => _setTabStatus(TabKey.quotations, s),
          onQuotationAccepted: _onQuotationAccepted,
        );
      case TabKey.po:
        return POTab(
          lead: lead,
          disabled: _isWon,
          onStatusChange: (s) => _setTabStatus(TabKey.po, s),
          onPOSaved: _onPOSaved,
        );
      case TabKey.consignee:
        return ConsigneeTab(
          lead: lead,
          disabled: _isWon,
          onStatusChange: (s) => _setTabStatus(TabKey.consignee, s),
        );
      case TabKey.workorder:
        return WorkOrderTab(
          lead: lead,
          onStatusChange: (s) => _setTabStatus(TabKey.workorder, s),
          onWonStatusLoaded: (won) => setState(() => _isWon = won),
        );
    }
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final OpportunityLead lead;
  final bool isWon;
  final bool loading;
  final VoidCallback onRefresh;

  const _Header({
    required this.lead,
    required this.isWon,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Text('Opportunities',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.chevron_right, size: 13, color: Color(0xFF94A3B8)),
              Flexible(
                child: Text(lead.leadTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF64748B)),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (lead.leadRefId.isNotEmpty)
                          _chip('# ${lead.leadRefId}',
                              const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                        if (lead.isDirect)
                          _chip('Direct Opportunity',
                              const Color(0xFFF5F3FF), const Color(0xFF6D28D9))
                        else
                          _chip('From Leads',
                              const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
                        if (isWon)
                          _chip('Won — Read Only',
                              const Color(0xFFECFDF5), const Color(0xFF047857)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(lead.leadTitle,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF020617))),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(lead.customerName ?? '—',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        ),
                        if ((lead.estValue ?? 0) != 0) ...[
                          const SizedBox(width: 8),
                          Text(Fmt.moneyShort(lead.estValue),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF94A3B8)),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
      );
}

// ─── Tab bar (stepper-style, horizontally scrollable) ─────────────────────────

class _TabBar extends StatelessWidget {
  final List<_TabDef> tabs;
  final TabKey active;
  final Map<TabKey, String> statuses;
  final Set<TabKey> locked;
  final ValueChanged<TabKey> onChange;

  const _TabBar({
    required this.tabs,
    required this.active,
    required this.statuses,
    required this.locked,
    required this.onChange,
  });

  bool _isComplete(String? s) =>
      s == 'done' || s == 'Accepted' || s == 'Completed' || s == 'Won';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      margin: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++) ...[
              _step(tabs[i]),
              if (i < tabs.length - 1)
                Container(
                  width: 56,
                  height: 2,
                  margin: const EdgeInsets.only(top: 20, left: 6, right: 6),
                  color: _isComplete(statuses[tabs[i].key])
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFE2E8F0),
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _step(_TabDef t) {
    final isActive = active == t.key;
    final isLocked = locked.contains(t.key);
    final done = _isComplete(statuses[t.key]);

    Color circleBg;
    Color circleFg;
    Color border;
    if (isLocked) {
      circleBg = const Color(0xFFF3F4F6);
      circleFg = const Color(0xFF9CA3AF);
      border = const Color(0xFFE5E7EB);
    } else if (isActive) {
      circleBg = const Color(0xFF2563EB);
      circleFg = Colors.white;
      border = const Color(0xFFDBEAFE);
    } else if (done) {
      circleBg = const Color(0xFF10B981);
      circleFg = Colors.white;
      border = const Color(0xFFD1FAE5);
    } else {
      circleBg = Colors.white;
      circleFg = const Color(0xFF2563EB);
      border = const Color(0xFFDBEAFE);
    }

    final status = statuses[t.key];

    return Opacity(
      opacity: isLocked ? 0.55 : 1,
      child: InkWell(
        onTap: isLocked ? null : () => onChange(t.key),
        child: SizedBox(
          width: 124,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: circleBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 4),
                ),
                child: Icon(
                  isLocked ? Icons.lock_outline : (done ? Icons.check_circle : t.icon),
                  size: 17,
                  color: circleFg,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isLocked
                      ? const Color(0xFF9CA3AF)
                      : isActive
                          ? const Color(0xFF1D4ED8)
                          : done
                              ? const Color(0xFF059669)
                              : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 4),
              if (isLocked)
                _badge('Locked', const Color(0xFFF9FAFB), const Color(0xFF9CA3AF),
                    const Color(0xFFE5E7EB))
              else if (status != null)
                _badge(
                  status == 'Won' ? 'Won' : (done ? 'Done' : status),
                  done ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  done ? const Color(0xFF047857) : const Color(0xFFB45309),
                  done ? const Color(0xFFD1FAE5) : const Color(0xFFFDE68A),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(text.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
      );
}
