import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api_helpers/api_method.dart';
import 'package:http/http.dart' as http;

class ExpenseRow {
  final expenseDateController = TextEditingController();
  final descriptionController = TextEditingController();
  final amountController = TextEditingController(text: '0');
  final fromPlaceController = TextEditingController();
  final toPlaceController = TextEditingController();
  final receiptController = TextEditingController();
  final vendorController = TextEditingController();
  final notesController = TextEditingController();

  String category = 'Transport Fare';
  String docType = 'Receipt';
  PlatformFile? proofFile;

  Map<String, dynamic> toPrefs() => {
    'expense_date': expenseDateController.text,
    'description': descriptionController.text,
    'amount': amountController.text,
    'from_place': fromPlaceController.text,
    'to_place': toPlaceController.text,
    'receipt_number': receiptController.text,
    'vendor_name': vendorController.text,
    'notes': notesController.text,
    'category': category,
    'doc_type': docType,
    'proof_name': proofFile?.name,
    'proof_path': proofFile?.path,
    'proof_size': proofFile?.size,
  };

  void fromPrefs(Map<String, dynamic> data) {
    expenseDateController.text = data['expense_date']?.toString() ?? '';
    descriptionController.text = data['description']?.toString() ?? '';
    amountController.text = data['amount']?.toString() ?? '0';
    fromPlaceController.text = data['from_place']?.toString() ?? '';
    toPlaceController.text = data['to_place']?.toString() ?? '';
    receiptController.text = data['receipt_number']?.toString() ?? '';
    vendorController.text = data['vendor_name']?.toString() ?? '';
    notesController.text = data['notes']?.toString() ?? '';
    category = data['category']?.toString() ?? 'Transport Fare';
    docType = data['doc_type']?.toString() ?? 'Receipt';

    final proofPath = data['proof_path']?.toString();
    final proofName = data['proof_name']?.toString();
    if (proofPath != null && proofPath.isNotEmpty && proofName != null && proofName.isNotEmpty) {
      proofFile = PlatformFile(
        name: proofName,
        path: proofPath,
        size: int.tryParse(data['proof_size']?.toString() ?? '') ?? 0,
      );
    }
  }

  void dispose() {
    expenseDateController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    fromPlaceController.dispose();
    toPlaceController.dispose();
    receiptController.dispose();
    vendorController.dispose();
    notesController.dispose();
  }
}

class NewTravelClaimPage extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String tenantSlug;
  final List<Map<String, dynamic>> requests;

  const NewTravelClaimPage({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.tenantSlug,
    required this.requests,
  });

  @override
  State<NewTravelClaimPage> createState() => _NewTravelClaimPageState();
}

class _NewTravelClaimPageState extends State<NewTravelClaimPage>
    with SingleTickerProviderStateMixin {
  static const String _draftKey = 'new_travel_claim_draft_v1';

  late final TabController _tabController;

  bool saving = false;
  bool declaration = false;
  bool _restoringDraft = true;

  int? travelRequestId;

  final claimDateController = TextEditingController();
  final travelFromController = TextEditingController();
  final travelToController = TextEditingController();
  final fromCityController = TextEditingController();
  final toCityController = TextEditingController();
  final purposeController = TextEditingController();
  final advanceController = TextEditingController(text: '0');
  final daRateController = TextEditingController(text: '0');
  final costCenterController = TextEditingController();
  final budgetCodeController = TextEditingController();
  final departmentController = TextEditingController();
  final notesController = TextEditingController();

  String claimType = 'Travel Expenses';
  String modeOfTravel = 'Train';
  String paymentMode = 'Self-pay (reimburse later)';

  final List<ExpenseRow> expenses = [ExpenseRow()];

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${widget.token}',
    'X-Tenant-Slug': widget.tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _saveDraft();
    });
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        travelRequestId = data['travel_request_id'] == null
            ? null
            : int.tryParse(data['travel_request_id'].toString());
        claimDateController.text = data['claim_date']?.toString() ?? '';
        travelFromController.text = data['travel_date_from']?.toString() ?? '';
        travelToController.text = data['travel_date_to']?.toString() ?? '';
        fromCityController.text = data['from_city']?.toString() ?? '';
        toCityController.text = data['to_city']?.toString() ?? '';
        purposeController.text = data['purpose']?.toString() ?? '';
        advanceController.text = data['advance_taken']?.toString() ?? '0';
        daRateController.text = data['da_rate_per_day']?.toString() ?? '0';
        costCenterController.text = data['cost_center']?.toString() ?? '';
        budgetCodeController.text = data['budget_code']?.toString() ?? '';
        departmentController.text = data['department']?.toString() ?? '';
        notesController.text = data['notes']?.toString() ?? '';
        claimType = data['claim_type']?.toString() ?? 'Travel Expenses';
        modeOfTravel = data['mode_of_travel']?.toString() ?? 'Train';
        paymentMode = data['expense_mode']?.toString() ?? 'Self-pay (reimburse later)';
        declaration = data['declaration'] == true;

        for (final e in expenses) {
          e.dispose();
        }
        expenses.clear();
        final items = data['line_items'];
        if (items is List && items.isNotEmpty) {
          for (final item in items) {
            final row = ExpenseRow();
            row.fromPrefs(Map<String, dynamic>.from(item as Map));
            expenses.add(row);
          }
        } else {
          expenses.add(ExpenseRow());
        }
      } catch (_) {}
    }

    _restoringDraft = false;
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _draftPayload() => {
    'travel_request_id': travelRequestId,
    'claim_date': claimDateController.text,
    'claim_type': claimType,
    'travel_date_from': travelFromController.text,
    'travel_date_to': travelToController.text,
    'from_city': fromCityController.text,
    'to_city': toCityController.text,
    'purpose': purposeController.text,
    'mode_of_travel': modeOfTravel,
    'advance_taken': advanceController.text,
    'da_rate_per_day': daRateController.text,
    'expense_mode': paymentMode,
    'cost_center': costCenterController.text,
    'budget_code': budgetCodeController.text,
    'department': departmentController.text,
    'notes': notesController.text,
    'declaration': declaration,
    'line_items': expenses.map((e) => e.toPrefs()).toList(),
  };

  Future<void> _saveDraft() async {
    if (_restoringDraft) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(_draftPayload()));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _goToTab(int index) async {
    await _saveDraft();
    if (index > _tabController.index && !_validateTab(_tabController.index)) return;
    _tabController.animateTo(index);
    setState(() {});
  }

  bool _validateTab(int index) {
    if (index == 0) {
      if (claimDateController.text.trim().isEmpty ||
          fromCityController.text.trim().isEmpty ||
          toCityController.text.trim().isEmpty ||
          purposeController.text.trim().isEmpty) {
        showError('Please fill required Claim Details before moving next');
        return false;
      }
    }

    if (index == 1) {
      for (final item in expenses) {
        if (item.expenseDateController.text.trim().isEmpty ||
            item.descriptionController.text.trim().isEmpty ||
            (double.tryParse(item.amountController.text.trim()) ?? 0) <= 0) {
          showError('Please fill expense date, description and amount before moving next');
          return false;
        }
        if (item.proofFile == null) {
          showError('Each expense item must have proof document');
          return false;
        }
      }
    }
    return true;
  }

  Future<void> pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text =
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
      await _saveDraft();
    }
  }

  Future<void> pickProofFile(int index) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'csv',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => expenses[index].proofFile = result.files.first);
      await _saveDraft();
    }
  }

  int get numDays {
    final from = DateTime.tryParse(travelFromController.text);
    final to = DateTime.tryParse(travelToController.text);
    if (from == null || to == null) return 0;
    return to.difference(from).inDays + 1;
  }

  double get totalExpenses => expenses.fold(0, (sum, e) {
    return sum + (double.tryParse(e.amountController.text.trim()) ?? 0);
  });

  double get advanceTaken => double.tryParse(advanceController.text.trim()) ?? 0;

  double get netPayable => totalExpenses - advanceTaken;

  void addExpense() {
    setState(() => expenses.add(ExpenseRow()));
    _saveDraft();
  }

  void removeExpense(int index) {
    if (expenses.length == 1) return;
    setState(() {
      expenses[index].dispose();
      expenses.removeAt(index);
    });
    _saveDraft();
  }

  Future<void> saveClaim() async {
    await _saveDraft();

    if (!_validateTab(0) || !_validateTab(1)) return;

    if (!declaration) {
      showError('Please accept employee declaration');
      return;
    }

    setState(() => saving = true);

    try {
      final body = {
        'travel_request_id': travelRequestId,
        'claim_date': claimDateController.text.trim(),
        'claim_type': claimType,
        'travel_date_from': travelFromController.text.trim().isEmpty
            ? null
            : travelFromController.text.trim(),
        'travel_date_to': travelToController.text.trim().isEmpty
            ? null
            : travelToController.text.trim(),
        'num_days': numDays,
        'from_city': fromCityController.text.trim(),
        'to_city': toCityController.text.trim(),
        'purpose': purposeController.text.trim(),
        'mode_of_travel': modeOfTravel,
        'advance_taken': advanceTaken,
        'da_rate_per_day': double.tryParse(daRateController.text.trim()) ?? 0,
        'expense_mode': paymentMode,
        'cost_center': costCenterController.text.trim().isEmpty
            ? null
            : costCenterController.text.trim(),
        'budget_code': budgetCodeController.text.trim().isEmpty
            ? null
            : budgetCodeController.text.trim(),
        'department': departmentController.text.trim().isEmpty
            ? null
            : departmentController.text.trim(),
        'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        'line_items': expenses.map((e) {
          return {
            'expense_date': e.expenseDateController.text.trim(),
            'category': e.category,
            'description': e.descriptionController.text.trim(),
            'from_place': e.fromPlaceController.text.trim().isEmpty
                ? null
                : e.fromPlaceController.text.trim(),
            'to_place': e.toPlaceController.text.trim().isEmpty
                ? null
                : e.toPlaceController.text.trim(),
            'amount': double.tryParse(e.amountController.text.trim()) ?? 0,
            'receipt_number': e.receiptController.text.trim().isEmpty
                ? null
                : e.receiptController.text.trim(),
            'vendor_name': e.vendorController.text.trim().isEmpty
                ? null
                : e.vendorController.text.trim(),
            'notes': e.notesController.text.trim().isEmpty ? null : e.notesController.text.trim(),
          };
        }).toList(),
      };

      final response = await ApiMethod.postRequest(
        url: '${widget.baseUrl}/travel/tada',
        headers: headers,
        body: body,
      );

      if (response['statusCode'] != 200 && response['statusCode'] != 201) {
        await _clearDraft();
        setState(() => saving = false);
        showError(response['data']?.toString() ?? 'Error saving claim');
        return;
      }

      final created = response['data'];
      final claimId = created['id'];
      final lineItems = created['line_items'] ?? [];

      for (int i = 0; i < expenses.length; i++) {
        if (i < lineItems.length) {
          final itemId = lineItems[i]['id'];
          await uploadProof(claimId: claimId, lineItemId: itemId, row: expenses[i]);
        }
      }

      await _clearDraft();
      setState(() => saving = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Travel claim saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      await _clearDraft();
      if (mounted) setState(() => saving = false);
      showError(e.toString());
    }
  }

  Future<void> uploadProof({
    required dynamic claimId,
    required dynamic lineItemId,
    required ExpenseRow row,
  }) async {
    final file = row.proofFile;
    if (file == null || file.path == null) return;

    final response = await ApiMethod.multipartRequest(
      method: 'POST',
      url: '${widget.baseUrl}/travel/tada/$claimId/line-items/$lineItemId/attachments?doc_type=${Uri.encodeComponent(row.docType)}',
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'X-Tenant-Slug': widget.tenantSlug,
        'Accept': 'application/json',
      },
      fields: {},
      files: [
        await http.MultipartFile.fromPath('file', file.path!, filename: file.name),
      ],
    );

    if (response['statusCode'] != 200 && response['statusCode'] != 201) {
      throw Exception(response['data']?.toString() ?? 'Error uploading proof');
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _onAnyChanged() {
    setState(() {});
    _saveDraft();
  }

  InputDecoration inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xff94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon == null ? null : Icon(icon, size: 19, color: AppColors.primarySlate),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4),
      ),
    );
  }

  Widget label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xff334155),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
        ),
      ),
    );
  }

  Widget field({
    required String labelText,
    required TextEditingController controller,
    String hint = '',
    bool required = false,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(labelText, required: required),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (_) => _onAnyChanged(),
          decoration: inputDecoration(hint, icon: icon),
        ),
      ],
    );
  }

  Widget dropdownField<T>({
    required String labelText,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String hint = '',
    bool required = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(labelText, required: required),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: inputDecoration(hint, icon: icon),
          items: items,
          onChanged: (v) {
            onChanged(v);
            _saveDraft();
          },
        ),
      ],
    );
  }

  Widget sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.headerGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget gap([double h = 14]) => SizedBox(height: h);

  Widget approvalWorkflow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLight.withOpacity(.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user_outlined, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text('Approval Workflow', style: TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: workflowStep('1', 'Submit')),
              workflowLine(),
              Expanded(child: workflowStep('2', 'Manager')),
              workflowLine(),
              Expanded(child: workflowStep('3', 'CEO')),
              workflowLine(),
              Expanded(child: workflowStep('4', 'Accounts')),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Each expense item requires a proof document before submission.',
            style: TextStyle(color: AppColors.primarySlate, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget workflowStep(String no, String text) {
    return Column(
      children: [
        Container(
          height: 30,
          width: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.headerGradient),
          child: Text(no, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.primaryDeep, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget workflowLine() => Container(height: 2, width: 16, margin: const EdgeInsets.only(bottom: 20), color: const Color(0xffBFDBFE));

  Widget tabHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: const Color(0xffF1F5F9), borderRadius: BorderRadius.circular(18)),
        child: TabBar(
          controller: _tabController,
          onTap: (index) => _goToTab(index),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(.08), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textSoft,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          tabs: const [
            Tab(text: 'Claim Details'),
            Tab(text: 'Expense Items'),
            Tab(text: 'Additional Info'),
          ],
        ),
      ),
    );
  }

  Widget claimDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        approvalWorkflow(),
        gap(16),
        sectionCard(
          title: 'Claim Details',
          subtitle: 'Travel request, claim, route and budget details',
          icon: Icons.description_outlined,
          child: Column(
            children: [
              dropdownField<int>(
                labelText: 'Travel Request',
                value: travelRequestId,
                hint: 'Select approved request...',
                icon: Icons.flight_takeoff_rounded,
                items: widget.requests.where((e) => e['status'] == 'Approved').map((e) {
                  return DropdownMenuItem<int>(
                    value: e['id'],
                    child: Text('${e['request_number']} - ${e['purpose']}', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    travelRequestId = v;
                    final req = widget.requests.firstWhere((e) => e['id'] == v, orElse: () => {});
                    fromCityController.text = req['from_city']?.toString() ?? '';
                    toCityController.text = req['to_city']?.toString() ?? '';
                    purposeController.text = req['purpose']?.toString() ?? '';
                    travelFromController.text = req['travel_date']?.toString() ?? '';
                    travelToController.text = req['return_date']?.toString() ?? '';
                    advanceController.text = req['advance_amount']?.toString() ?? '0';
                  });
                },
              ),
              gap(),
              field(labelText: 'Claim Date', controller: claimDateController, hint: 'yyyy-mm-dd', required: true, readOnly: true, onTap: () => pickDate(claimDateController), icon: Icons.calendar_today_outlined),
              gap(),
              dropdownField<String>(
                labelText: 'Claim Type',
                value: claimType,
                hint: 'Claim Type',
                icon: Icons.category_outlined,
                items: const ['Travel Expenses', 'Local Conveyance', 'Daily Allowance', 'Travel + Daily Allowance'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => claimType = v!),
              ),
              gap(),
              Row(
                children: [
                  Expanded(child: field(labelText: 'Travel Date From', controller: travelFromController, hint: 'yyyy-mm-dd', readOnly: true, onTap: () => pickDate(travelFromController), icon: Icons.event_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: field(labelText: 'Travel Date To', controller: travelToController, hint: 'yyyy-mm-dd', readOnly: true, onTap: () => pickDate(travelToController), icon: Icons.event_available_outlined)),
                ],
              ),
              gap(),
              field(labelText: 'No. of Days', controller: TextEditingController(text: numDays.toString()), hint: 'Auto-calculated', readOnly: true, icon: Icons.timelapse_outlined),
              gap(),
              Row(
                children: [
                  Expanded(child: field(labelText: 'From City', controller: fromCityController, hint: 'Departure city', required: true, icon: Icons.location_on_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: field(labelText: 'To City', controller: toCityController, hint: 'Destination city', required: true, icon: Icons.flag_outlined)),
                ],
              ),
              gap(),
              field(labelText: 'Purpose', controller: purposeController, hint: 'e.g. Customer visit', required: true, maxLines: 2, icon: Icons.notes_outlined),
              gap(),
              dropdownField<String>(
                labelText: 'Mode of Travel',
                value: modeOfTravel,
                hint: 'Mode of Travel',
                icon: Icons.train_outlined,
                items: const ['Train', 'Bus', 'Bike','Flight', 'Taxi/Cab', 'Own Vehicle', 'Company Car','Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => modeOfTravel = v!),
              ),
              gap(),
              Row(
                children: [
                  Expanded(child: field(labelText: 'Advance Taken (₹)', controller: advanceController, hint: '0', keyboardType: TextInputType.number, icon: Icons.currency_rupee_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: field(labelText: 'DA Rate / Day (₹)', controller: daRateController, hint: '0', keyboardType: TextInputType.number, icon: Icons.payments_outlined)),
                ],
              ),
              gap(),
              dropdownField<String>(
                labelText: 'Payment Mode',
                value: paymentMode,
                hint: 'Payment Mode',
                icon: Icons.credit_card_outlined,
                items: const ['Self-pay (reimburse later)', 'Company credit card','Cash advance', 'Direct vendor payment'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => paymentMode = v!),
              ),
              gap(),
              Row(
                children: [
                  Expanded(child: field(labelText: 'Cost Center', controller: costCenterController, hint: 'e.g. SALES-WEST', icon: Icons.account_tree_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: field(labelText: 'Budget Code', controller: budgetCodeController, hint: 'Internal code', icon: Icons.qr_code_2_outlined)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget expenseItemsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sectionCard(
          title: 'Expense Items',
          subtitle: 'Add every bill with date, category, amount and proof',
          icon: Icons.receipt_long,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffFDE68A)),
                ),
                child: const Text(
                  'Each item must have a proof document before submission.',
                  style: TextStyle(color: Color(0xffB45309), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              gap(),
              ...List.generate(expenses.length, expenseCard),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: addExpense,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    side: const BorderSide(color: AppColors.primaryLight),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: summaryBox('Total Expenses', '₹${totalExpenses.toStringAsFixed(0)}')),
            const SizedBox(width: 10),
            Expanded(child: summaryBox('Advance Taken', '₹${advanceTaken.toStringAsFixed(0)}')),
          ],
        ),
        gap(10),
        summaryBox('Net Payable', '₹${netPayable.toStringAsFixed(0)}', green: true),
        gap(16),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget expenseCard(int index) {
    final row = expenses[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xffF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xffDBEAFE),
                  child: Text('${index + 1}', style: const TextStyle(color: Color(0xff2563EB), fontSize: 12, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Expense ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark))),
                if (expenses.length > 1)
                  IconButton(onPressed: () => removeExpense(index), icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                field(labelText: 'Expense Date', controller: row.expenseDateController, hint: 'yyyy-mm-dd', required: true, readOnly: true, onTap: () => pickDate(row.expenseDateController), icon: Icons.calendar_today_outlined),
                gap(),
                dropdownField<String>(
                  labelText: 'Category',
                  value: row.category,
                  hint: 'Category',
                  icon: Icons.category_outlined,
                  items: const ['Transport Fare', 'Auto / Cab','Fuel', 'Accommodation', 'Meals','Daily Allowance', 'Communication', 'Toll / Parking', 'Miscellaneous'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => row.category = v!),
                ),
                gap(),
                field(labelText: 'Amount (₹)', controller: row.amountController, hint: '0', required: true, keyboardType: TextInputType.number, icon: Icons.currency_rupee_rounded),
                gap(),
                field(labelText: 'Description', controller: row.descriptionController, hint: 'e.g. Train ticket Chennai to Trichy', required: true, icon: Icons.description_outlined),
                gap(),
                Row(
                  children: [
                    Expanded(child: field(labelText: 'From Place', controller: row.fromPlaceController, hint: 'Optional', icon: Icons.my_location_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: field(labelText: 'To Place', controller: row.toPlaceController, hint: 'Optional', icon: Icons.place_outlined)),
                  ],
                ),
                gap(),
                field(labelText: 'Receipt / Bill No.', controller: row.receiptController, hint: 'Optional', icon: Icons.numbers_outlined),
                gap(),
                field(labelText: 'Vendor / Payee', controller: row.vendorController, hint: 'Optional', icon: Icons.storefront_outlined),
                gap(),
                field(labelText: 'Item Notes', controller: row.notesController, hint: 'Optional', icon: Icons.note_alt_outlined),
                gap(),
                attachProofBox(index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget attachProofBox(int index) {
    final row = expenses[index];
    final hasFile = row.proofFile != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xffECFDF5) : const Color(0xffFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasFile ? const Color(0xff86EFAC) : const Color(0xffFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label('Attach Proof', required: true),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: row.docType,
                  decoration: inputDecoration('Doc Type', icon: Icons.file_present_outlined),
                  items: const ['Receipt', 'Invoice', 'Ticket', 'Bill', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    setState(() => row.docType = v!);
                    _saveDraft();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pickProofFile(index),
                  icon: const Icon(Icons.upload_file),
                  label: Text(hasFile ? 'Change File' : 'Attach File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasFile ? const Color(0xff059669) : const Color(0xffDC2626),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasFile ? row.proofFile!.name : 'No proof attached',
            style: TextStyle(color: hasFile ? const Color(0xff059669) : const Color(0xffDC2626), fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget additionalInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        sectionCard(
          title: 'Additional Info',
          subtitle: 'Department, notes and employee declaration',
          icon: Icons.note_alt_outlined,
          child: Column(
            children: [
              field(labelText: 'Department', controller: departmentController, hint: 'e.g. Sales, Operations', icon: Icons.apartment_outlined),
              gap(),
              field(labelText: 'Notes / Special Instructions', controller: notesController, hint: 'Any additional context for the approver...', maxLines: 4, icon: Icons.sticky_note_2_outlined),
              gap(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffE2E8F0)),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: declaration,
                  activeColor: AppColors.primaryLight,
                  title: const Text('Employee Declaration', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  subtitle: const Text(
                    'I confirm that all expenses submitted are genuine business expenses and the attached documents are valid.',
                    style: TextStyle(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (v) {
                    setState(() => declaration = v ?? false);
                    _saveDraft();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget summaryBox(String title, String value, {bool green = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: green ? const Color(0xff059669) : const Color(0xff0F172A), fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Color(0xff94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget nextButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget bottomBar() {
    final currentIndex = _tabController.index;
    final isFirstTab = currentIndex == 0;
    final isLastTab = currentIndex == 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xffE2E8F0))),
      ),
      child: Row(
        children: [
          if (!isFirstTab)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                  await _saveDraft();
                  _tabController.animateTo(currentIndex - 1);
                  setState(() {});
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

          if (!isFirstTab) const SizedBox(width: 12),

          Expanded(
            child: ElevatedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                if (isLastTab) {
                  await saveClaim();
                } else {
                  await _goToTab(currentIndex + 1);
                }
              },
              icon: saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Icon(
                isLastTab
                    ? Icons.save_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                saving
                    ? 'Saving...'
                    : isLastTab
                    ? 'Save Claim'
                    : 'Next',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isLastTab ? AppColors.primaryDark : AppColors.primaryLight,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    claimDateController.dispose();
    travelFromController.dispose();
    travelToController.dispose();
    fromCityController.dispose();
    toCityController.dispose();
    purposeController.dispose();
    advanceController.dispose();
    daRateController.dispose();
    costCenterController.dispose();
    budgetCodeController.dispose();
    departmentController.dispose();
    notesController.dispose();
    for (final e in expenses) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringDraft) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.headerGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 16),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('New Travel Claim', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('Fields marked * are required', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
                      child: Text('₹${netPayable.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          tabHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [claimDetailsTab(), expenseItemsTab(), additionalInfoTab()],
            ),
          ),
          bottomBar(),
        ],
      ),
    );
  }
}

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF3060A0);

  static const Color bg = Color(0xffF4F7FB);
  static const Color card = Colors.white;
  static const Color border = Color(0xffDDE6F0);
  static const Color textDark = Color(0xff0F172A);
  static const Color textSoft = Color(0xff64748B);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF3060A0),
      Color(0xFF3060A0),
      Color(0xFF3060A0),
      Color(0xFF204070),
      Color(0xFF103050),
      Color(0xFF102040),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
