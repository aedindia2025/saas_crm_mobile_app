import 'package:flutter/material.dart';
import '../../utile/app_colors.dart';

class LeadViewPage extends StatelessWidget {
  final Map<String, dynamic> leadData;
  final bool isReadOnly;

  const LeadViewPage({
    super.key,
    required this.leadData,
    this.isReadOnly = true,
  });

  String safeText(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String formatCurrency(dynamic raw) {
    final value = double.tryParse((raw ?? 0).toString()) ?? 0;
    if (value >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '₹${(value / 1000).toStringAsFixed(1)}K';
    return '₹${value.toStringAsFixed(0)}';
  }

  int leadStep() {
    final status = safeText(leadData['status'], '');
    if (status == 'Converted') return 3;
    if (status == 'Opportunity Created') return 2;
    return 1;
  }

  Color stepActiveColor(int step) {
    if (step == 1) return const Color(0xff2563EB);
    if (step == 2) return const Color(0xff10B981);
    return const Color(0xff3B82F6);
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Assigned':
        return const Color(0xff2563EB);
      case 'Opportunity Created':
        return const Color(0xff10B981);
      case 'Converted':
        return const Color(0xff3B82F6);
      case 'Lost':
        return const Color(0xffDC2626);
      default:
        return AppColors.primarySlate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = safeText(leadData['status'], 'Assigned');
    final title = safeText(
      leadData['lead_title'] ?? leadData['lead_name'],
      'Lead Details',
    );
    final customer = safeText(leadData['customer_name']);
    final currentStep = leadStep();

    return Scaffold(
      backgroundColor: const Color(0xffF3F6FA),
      body: Column(
        children: [
          _topBar(context),
          _webStepHeader(currentStep),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                children: [
                  _leadHeroCard(title, customer, status),
                  const SizedBox(height: 14),

                  _section(
                    title: 'Lead Info',
                    subtitle: 'Customer, contact, dates',
                    icon: Icons.person_search_rounded,
                    children: [
                      _infoTile('Lead Title', title, Icons.title_rounded),
                      _infoTile('Lead Ref ID', safeText(leadData['lead_ref_id']), Icons.tag_outlined),
                      _infoTile('Customer', customer, Icons.business_outlined),
                      _infoTile('Customer Address', safeText(leadData['customer_address']), Icons.location_on_outlined),
                      _infoTile('Department', safeText(leadData['department']), Icons.apartment_outlined),
                      _infoTile('Contact Person', safeText(leadData['contact_person']), Icons.person_outline),
                      _infoTile('Designation', safeText(leadData['designation']), Icons.badge_outlined),
                      _infoTile('Mobile', safeText(leadData['mobile']), Icons.phone_outlined),
                      _infoTile('Email', safeText(leadData['email']), Icons.mail_outline),
                      _infoTile('Source', safeText(leadData['source_name'] ?? leadData['source_id']), Icons.source_outlined),
                      _infoTile('Priority', safeText(leadData['priority']), Icons.flag_outlined),
                      _infoTile('Timeline', safeText(leadData['timeline']), Icons.calendar_today_outlined),
                      _infoTile('Follow Up', safeText(leadData['follow_up']), Icons.event_available_outlined),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _section(
                    title: 'Opportunity',
                    subtitle: 'Products, OEMs',
                    icon: Icons.trending_up_rounded,
                    children: [
                      _infoTile(
                        'Opportunity Ref ID',
                        safeText(leadData['opportunity_ref_id']),
                        Icons.confirmation_number_outlined,
                      ),
                      _infoTile(
                        'Estimated Value',
                        formatCurrency(leadData['est_value'] ?? leadData['lead_value']),
                        Icons.currency_rupee_rounded,
                      ),
                      _infoTile(
                        'Product Description',
                        safeText(leadData['product_description']),
                        Icons.description_outlined,
                      ),
                      _infoTile('Notes', safeText(leadData['notes']), Icons.note_alt_outlined),
                      _infoTile(
                        'Competitors',
                        _competitorText(leadData['competitor_ids']),
                        Icons.groups_2_outlined,
                      ),
                      const SizedBox(height: 4),
                      _productsBlock(),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _section(
                    title: 'Conversion',
                    subtitle: 'Approval, tender',
                    icon: Icons.fact_check_outlined,
                    children: [
                      _infoTile(
                        'Status',
                        status,
                        Icons.circle_outlined,
                        valueColor: statusColor(status),
                      ),
                      _infoTile(
                        'Assigned To',
                        safeText(leadData['assigned_to_name'] ?? leadData['assigned_to']),
                        Icons.person_pin_outlined,
                      ),
                      _infoTile(
                        'Working Group',
                        safeText(leadData['working_group_name'] ?? leadData['working_group_id']),
                        Icons.groups_outlined,
                      ),
                      _infoTile(
                        'Approval Status',
                        safeText(leadData['approval_display'] ?? leadData['approval_status']),
                        Icons.verified_user_outlined,
                      ),
                      _infoTile(
                        'Tender Ref',
                        safeText(leadData['tender_id_ref']),
                        Icons.assignment_outlined,
                      ),
                      if (safeText(leadData['rejection_reason'], '').isNotEmpty)
                        _infoTile(
                          'Rejection Reason',
                          safeText(leadData['rejection_reason']),
                          Icons.error_outline_rounded,
                          valueColor: const Color(0xffDC2626),
                        ),
                    ],
                  ),

                  if (status == 'Converted') ...[
                    const SizedBox(height: 14),
                    _readonlyBanner(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Lead View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: const Text(
                  'View Only',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webStepHeader(int currentStep) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          _stepItem(
            step: 1,
            currentStep: currentStep,
            title: 'Lead Info',
            subtitle: 'Customer, contact, dates',
            icon: Icons.person_search_rounded,
          ),
          _stepLine(currentStep >= 2),
          _stepItem(
            step: 2,
            currentStep: currentStep,
            title: 'Opportunity',
            subtitle: 'Products, OEMs',
            icon: Icons.trending_up_rounded,
          ),
          _stepLine(currentStep >= 3),
          _stepItem(
            step: 3,
            currentStep: currentStep,
            title: 'Conversion',
            subtitle: 'Approval, tender',
            icon: Icons.check_box_outlined,
          ),
        ],
      ),
    );
  }

  Widget _stepItem({
    required int step,
    required int currentStep,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final active = currentStep >= step;
    final color = active ? stepActiveColor(step) : const Color(0xff93A4B8);

    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: active ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? color.withOpacity(.20) : const Color(0xffBFDBFE),
                width: 4,
              ),
              boxShadow: active
                  ? [
                BoxShadow(
                  color: color.withOpacity(.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
                  : [],
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : const Color(0xff2563EB),
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: active ? color : const Color(0xff475569),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff8CA0BA),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 38),
        color: active ? const Color(0xff86EFAC) : const Color(0xffE2E8F0),
      ),
    );
  }

  Widget _leadHeroCard(String title, String customer, String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.visibility_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _chip(status, color.withOpacity(.10), color),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.headerGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xff64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
      String label,
      String value,
      IconData icon, {
        Color? valueColor,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primarySlate.withOpacity(.72)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.primaryDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productsBlock() {
    final products = leadData['products'];

    if (products is! List || products.isEmpty) {
      return _emptyBox('No product details available');
    }

    return Column(
      children: List.generate(products.length, (index) {
        final product = products[index] as Map<String, dynamic>;
        final oems = product['oems'];

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xffF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product ${index + 1}',
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              _smallLine(Icons.inventory_2_outlined, safeText(product['product_name'])),
              _smallLine(Icons.format_list_numbered_rounded, 'Qty: ${safeText(product['quantity'], '1')}'),
              if (safeText(product['description'], '').isNotEmpty)
                _smallLine(Icons.description_outlined, safeText(product['description'])),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (oems is List && oems.isNotEmpty)
                    ? oems.map<Widget>((o) {
                  return _chip(
                    safeText(o['oem_name']),
                    const Color(0xffEEF2FF),
                    AppColors.primaryLight,
                  );
                }).toList()
                    : [
                  _chip(
                    'No OEM',
                    const Color(0xffF1F5F9),
                    const Color(0xff64748B),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _smallLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primarySlate.withOpacity(.65)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.primaryDeep,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff64748B),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _readonlyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff059669).withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xff059669).withOpacity(.16)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xff059669)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Converted lead is view-only. This lead has already been converted and cannot be edited.',
              style: TextStyle(
                color: Color(0xff059669),
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _competitorText(dynamic competitors) {
    if (competitors is List && competitors.isNotEmpty) {
      return competitors.join(', ');
    }
    return '-';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryDeep.withOpacity(.05),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}