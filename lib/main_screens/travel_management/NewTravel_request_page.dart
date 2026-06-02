import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NewTravelRequestPage extends StatefulWidget {
  final String baseUrl;
  final String token;
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? editData;

  const NewTravelRequestPage({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.customers,
    this.editData,
  });

  @override
  State<NewTravelRequestPage> createState() => _NewTravelRequestPageState();
}

class _NewTravelRequestPageState extends State<NewTravelRequestPage> {
  int step = 1;
  bool saving = false;

  static const String draftKey = 'new_travel_request_draft';

  final advanceAmountController = TextEditingController();
  final accommodationCostController = TextEditingController();
  final hotelNameController = TextEditingController();
  final checkInDateController = TextEditingController();
  final checkOutDateController = TextEditingController();
  final costCenterController = TextEditingController();
  final budgetCodeController = TextEditingController();

  String accommodationType = 'Not Required';

  final purposeController = TextEditingController();
  final fromCityController = TextEditingController();
  final toCityController = TextEditingController();
  final travelDateController = TextEditingController();
  final returnDateController = TextEditingController();

  final contactNameController = TextEditingController();
  final contactPhoneController = TextEditingController();
  final leadRefController = TextEditingController();
  final opportunityRefController = TextEditingController();
  final tenderRefController = TextEditingController();
  final workingGroupController = TextEditingController();

  final transportModeController = TextEditingController();
  final vehicleNumberController = TextEditingController();
  final estimatedKmsController = TextEditingController();
  final bookingRefController = TextEditingController();
  final estimatedCostController = TextEditingController();

  final companionsController = TextEditingController();
  final notesController = TextEditingController();

  int? customerId;
  String visitType = 'Customer Visit';
  bool outsideDistrict = false;
  bool advanceRequired = false;
  bool accommodationRequired = false;

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${widget.token}',
    'X-Tenant-Slug': 'ascent',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };


  @override
  void initState() {
    super.initState();
    if (widget.editData != null) {
      loadEditData(widget.editData!);
    } else {
      loadDraft();
    }
  }


  Map<String, dynamic> draftData() => {
    'step': step,
    'purpose': purposeController.text,
    'visit_type': visitType,
    'outside_district': outsideDistrict,
    'from_city': fromCityController.text,
    'to_city': toCityController.text,
    'travel_date': travelDateController.text,
    'return_date': returnDateController.text,
    'customer_id': customerId,
    'contact_name': contactNameController.text,
    'contact_phone': contactPhoneController.text,
    'lead_id': leadRefController.text,
    'opportunity_id': opportunityRefController.text,
    'tender_id': tenderRefController.text,
    'working_group_id': workingGroupController.text,
    'transport_mode': transportModeController.text,
    'vehicle_number': vehicleNumberController.text,
    'estimated_kms': estimatedKmsController.text,
    'booking_ref': bookingRefController.text,
    'estimated_cost': estimatedCostController.text,
    'advance_required': advanceRequired,
    'advance_amount': advanceAmountController.text,
    'accommodation_required': accommodationRequired,
    'accommodation_type': accommodationType,
    'hotel_name': hotelNameController.text,
    'check_in_date': checkInDateController.text,
    'check_out_date': checkOutDateController.text,
    'accommodation_cost': accommodationCostController.text,
    'cost_center': costCenterController.text,
    'budget_code': budgetCodeController.text,
    'companions': companionsController.text,
    'notes': notesController.text,
  };

  Future<void> saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftKey, jsonEncode(draftData()));
  }

  Future<void> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null) return;

    final data = jsonDecode(raw);

    setState(() {
      step = data['step'] ?? 1;
      purposeController.text = data['purpose'] ?? '';
      visitType = data['visit_type'] ?? 'Customer Visit';
      outsideDistrict = data['outside_district'] ?? false;
      fromCityController.text = data['from_city'] ?? '';
      toCityController.text = data['to_city'] ?? '';
      travelDateController.text = data['travel_date'] ?? '';
      returnDateController.text = data['return_date'] ?? '';
      customerId = data['customer_id'];
      contactNameController.text = data['contact_name'] ?? '';
      contactPhoneController.text = data['contact_phone'] ?? '';
      leadRefController.text = data['lead_id'] ?? '';
      opportunityRefController.text = data['opportunity_id'] ?? '';
      tenderRefController.text = data['tender_id'] ?? '';
      workingGroupController.text = data['working_group_id'] ?? '';
      transportModeController.text = data['transport_mode'] ?? '';
      vehicleNumberController.text = data['vehicle_number'] ?? '';
      estimatedKmsController.text = data['estimated_kms'] ?? '';
      bookingRefController.text = data['booking_ref'] ?? '';
      estimatedCostController.text = data['estimated_cost'] ?? '';
      advanceRequired = data['advance_required'] ?? false;
      advanceAmountController.text = data['advance_amount'] ?? '';
      accommodationRequired = data['accommodation_required'] ?? false;
      accommodationType = data['accommodation_type'] ?? 'Not Required';
      hotelNameController.text = data['hotel_name'] ?? '';
      checkInDateController.text = data['check_in_date'] ?? '';
      checkOutDateController.text = data['check_out_date'] ?? '';
      accommodationCostController.text = data['accommodation_cost'] ?? '';
      costCenterController.text = data['cost_center'] ?? '';
      budgetCodeController.text = data['budget_code'] ?? '';
      companionsController.text = data['companions'] ?? '';
      notesController.text = data['notes'] ?? '';
    });
  }

  void loadEditData(Map<String, dynamic> data) {
    setState(() {
      step = 1;
      purposeController.text = data['purpose']?.toString() ?? '';
      visitType = data['visit_type']?.toString() ?? 'Customer Visit';
      outsideDistrict = data['is_outside_district'] == true;
      fromCityController.text = data['from_city']?.toString() ?? '';
      toCityController.text = data['to_city']?.toString() ?? '';
      travelDateController.text = data['travel_date']?.toString() ?? '';
      returnDateController.text = data['return_date']?.toString() ?? '';
      customerId = data['customer_id'] == null
          ? (data['account_id'] == null ? null : int.tryParse(data['account_id'].toString()))
          : int.tryParse(data['customer_id'].toString());
      contactNameController.text = data['contact_name']?.toString() ?? '';
      contactPhoneController.text = data['contact_phone']?.toString() ?? '';
      leadRefController.text = data['lead_id']?.toString() ?? '';
      opportunityRefController.text = data['opportunity_id']?.toString() ?? '';
      tenderRefController.text = data['tender_id']?.toString() ?? '';
      workingGroupController.text = data['working_group_id']?.toString() ?? '';
      transportModeController.text = data['transport_mode']?.toString() ?? '';
      vehicleNumberController.text = data['vehicle_number']?.toString() ?? '';
      estimatedKmsController.text = data['estimated_kms']?.toString() ?? '';
      bookingRefController.text = data['advance_booking_ref']?.toString() ?? '';
      estimatedCostController.text = (data['estimated_cost'] ?? data['estimated_total'])?.toString() ?? '';
      advanceRequired = data['advance_required'] == true;
      advanceAmountController.text = data['advance_amount']?.toString() ?? '';
      accommodationRequired = data['accommodation_required'] == true;
      accommodationType = data['accommodation_type']?.toString() ?? 'Not Required';
      hotelNameController.text = data['hotel_name']?.toString() ?? '';
      checkInDateController.text = data['check_in_date']?.toString() ?? '';
      checkOutDateController.text = data['check_out_date']?.toString() ?? '';
      accommodationCostController.text = data['accommodation_cost']?.toString() ?? '';
      costCenterController.text = data['cost_center']?.toString() ?? '';
      budgetCodeController.text = data['budget_code']?.toString() ?? '';
      companionsController.text = data['companions']?.toString() ?? '';
      notesController.text = data['notes']?.toString() ?? '';
    });
  }


  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);
  }

  Future<bool> confirmBack() async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Discard Dialog",
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return Transform.scale(
          scale: curved.value,
          child: Opacity(
            opacity: animation.value,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      /// Warning Icon
                      Container(
                        height: 78,
                        width: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade400,
                              Colors.orange.shade400,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),

                      const SizedBox(height: 22),

                      /// Title
                      const Text(
                        "Discard Changes?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// Description
                      Text(
                        "If you go back now, all entered values will be permanently removed.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 30),

                      /// Buttons
                      Row(
                        children: [

                          /// Cancel Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Keep Editing",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          /// Confirm Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: AppColors.primaryDark,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Discard",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      await clearDraft();
      return true;
    }

    return false;
  }

  Future<void> pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryLight,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.primaryDeep,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.text =
      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> createRequest() async {
    if (purposeController.text.trim().isEmpty ||
        fromCityController.text.trim().isEmpty ||
        toCityController.text.trim().isEmpty ||
        travelDateController.text.trim().isEmpty ||
        returnDateController.text.trim().isEmpty) {
      showError('Please fill required fields');
      return;
    }

    final phone = contactPhoneController.text.trim();
    if (phone.isNotEmpty && phone.length != 10) {
      showError('Contact Phone must be exactly 10 digits');
      return;
    }

    if (advanceRequired &&
        (double.tryParse(advanceAmountController.text.trim()) ?? 0) <= 0) {
      showError('Please enter the advance amount requested');
      return;
    }

    if (accommodationRequired) {
      if (accommodationType == 'Not Required') {
        showError('Please select accommodation type');
        return;
      }
    }

    setState(() => saving = true);

    try {
      final body = {
        'purpose': purposeController.text.trim(),
        'visit_type': visitType,
        'from_city': fromCityController.text.trim(),
        'to_city': toCityController.text.trim(),
        'travel_date': travelDateController.text.trim(),
        'return_date': returnDateController.text.trim(),
        'is_outside_district': outsideDistrict,
        'account_id': customerId,
        'contact_name': contactNameController.text.trim().isEmpty
            ? null
            : contactNameController.text.trim(),
        'contact_phone': phone.isEmpty ? null : phone,
        'lead_id': leadRefController.text.trim().isEmpty
            ? null
            : int.tryParse(leadRefController.text.trim()),
        'opportunity_id': opportunityRefController.text.trim().isEmpty
            ? null
            : int.tryParse(opportunityRefController.text.trim()),
        'tender_id': tenderRefController.text.trim().isEmpty
            ? null
            : int.tryParse(tenderRefController.text.trim()),
        'working_group_id': workingGroupController.text.trim().isEmpty
            ? null
            : int.tryParse(workingGroupController.text.trim()),
        'transport_mode': transportModeController.text.trim().isEmpty
            ? null
            : transportModeController.text.trim(),
        'vehicle_number': vehicleNumberController.text.trim().isEmpty
            ? null
            : vehicleNumberController.text.trim(),
        'estimated_kms': estimatedKmsController.text.trim().isEmpty
            ? null
            : double.tryParse(estimatedKmsController.text.trim()),
        'advance_booking_ref': bookingRefController.text.trim().isEmpty
            ? null
            : bookingRefController.text.trim(),
        'estimated_cost': estimatedCostController.text.trim().isEmpty
            ? null
            : double.tryParse(estimatedCostController.text.trim()),
        'advance_required': advanceRequired,
        'advance_amount': advanceRequired
            ? double.tryParse(advanceAmountController.text.trim())
            : 0,
        'accommodation_required': accommodationRequired,
        'accommodation_type':
        accommodationRequired ? accommodationType : 'Not Required',
        'hotel_name': accommodationRequired &&
            hotelNameController.text.trim().isNotEmpty
            ? hotelNameController.text.trim()
            : null,
        'check_in_date': accommodationRequired &&
            checkInDateController.text.trim().isNotEmpty
            ? checkInDateController.text.trim()
            : null,
        'check_out_date': accommodationRequired &&
            checkOutDateController.text.trim().isNotEmpty
            ? checkOutDateController.text.trim()
            : null,
        'accommodation_cost': accommodationRequired
            ? double.tryParse(accommodationCostController.text.trim())
            : null,
        'cost_center': costCenterController.text.trim().isEmpty
            ? null
            : costCenterController.text.trim(),
        'budget_code': budgetCodeController.text.trim().isEmpty
            ? null
            : budgetCodeController.text.trim(),
        'companions': companionsController.text.trim().isEmpty
            ? null
            : companionsController.text.trim(),
        'notes': notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      };

      final isEdit = widget.editData != null && widget.editData!['id'] != null;
      final response = isEdit
          ? await http.put(
        Uri.parse('${widget.baseUrl}/travel/requests/${widget.editData!['id']}'),
        headers: headers,
        body: jsonEncode(body),
      )
          : await http.post(
        Uri.parse('${widget.baseUrl}/travel/requests'),
        headers: headers,
        body: jsonEncode(body),
      );

      setState(() => saving = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(widget.editData == null ? 'Travel request created' : 'Travel request updated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await clearDraft();
        Navigator.pop(context, true);
      } else {
        showError(response.body);
      }
    } catch (e) {
      setState(() => saving = false);
      showError(e.toString());
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool validateStepOne() {
    if (purposeController.text.trim().isEmpty ||
        fromCityController.text.trim().isEmpty ||
        toCityController.text.trim().isEmpty ||
        travelDateController.text.trim().isEmpty ||
        returnDateController.text.trim().isEmpty) {
      showError('Please fill required travel fields');
      return false;
    }

    final phone = contactPhoneController.text.trim();
    if (phone.isNotEmpty && phone.length != 10) {
      showError('Contact Phone must be exactly 10 digits');
      return false;
    }

    return true;
  }

  void goNext() {
    if (step == 1 && !validateStepOne()) return;
    setState(() => step = 2);
  }

  InputDecoration inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xff94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 19, color: AppColors.primarySlate.withOpacity(.72)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
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
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
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
          onChanged: (_) => setState(() {}),
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
          dropdownColor: Colors.white,
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData icon = Icons.toggle_on_outlined,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? const Color(0xffEFF6FF) : const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? const Color(0xffBFDBFE) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              gradient: value ? AppColors.headerGradient : null,
              color: value ? null : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: value ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              color: value ? Colors.white : AppColors.primarySlate,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primaryLight,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget section({
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget stepHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xffF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: stepSegment(
                title: 'Step 1 Travel Info',
                active: step == 1,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: stepSegment(
                title: 'Step 2 Request Details',
                active: step == 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget stepSegment({
    required String title,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: active
            ? [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : [],
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: active ? const Color(0xff7C3AED) : AppColors.primarySlate,
        ),
      ),
    );
  }

  Widget stepItem(int no, String title, String sub, IconData icon) {
    final active = step >= no;
    final current = step == no;
    final color = active ? AppColors.primaryLight : const Color(0xff94A3B8);

    return SizedBox(
      width: 112,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              gradient: active ? AppColors.headerGradient : null,
              color: active ? null : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? color.withOpacity(.18) : const Color(0xffBFDBFE),
                width: 4,
              ),
              boxShadow: current
                  ? [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
                  : [],
            ),
            child: Icon(
              step > no ? Icons.check_rounded : icon,
              color: active ? Colors.white : AppColors.primaryLight,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AppColors.primaryDark : AppColors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
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

  Widget stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 38),
        decoration: BoxDecoration(
          color: active ? const Color(0xff86EFAC) : const Color(0xffE2E8F0),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget gap([double h = 14]) => SizedBox(height: h);

  Widget stepOne() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        section(
          title: 'Travel Details',
          subtitle: 'Purpose, route and travel schedule',
          icon: Icons.flight_takeoff_rounded,
          child: Column(
            children: [
              field(
                labelText: 'Purpose of Travel',
                controller: purposeController,
                hint: 'e.g. Customer visit',
                required: true,
                maxLines: 2,
                icon: Icons.description_outlined,
              ),
              gap(),
              dropdownField<String>(
                labelText: 'Visit Type',
                value: visitType,
                hint: 'Select visit type',
                required: true,
                icon: Icons.work_outline_rounded,
                items: const [
                  'Customer Visit',
                  'Site Visit',
                  'Training',
                  'Conference',
                  'Meeting',
                  'Demo / Presentation',
                  'Audit',
                  'Follow-up',
                  'Other',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => visitType = v ?? 'Customer Visit'),
              ),
              gap(),
              switchCard(
                title: 'Outside District / City',
                subtitle: 'Enable this if travel is outside the local district or city',
                value: outsideDistrict,
                icon: Icons.map_outlined,
                onChanged: (v) => setState(() => outsideDistrict = v),
              ),
              gap(),
              Row(
                children: [
                  Expanded(
                    child: field(
                      labelText: 'From City',
                      controller: fromCityController,
                      hint: 'Departure city',
                      required: true,
                      icon: Icons.my_location_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(
                      labelText: 'To City',
                      controller: toCityController,
                      hint: 'Destination city',
                      required: true,
                      icon: Icons.place_outlined,
                    ),
                  ),
                ],
              ),
              gap(),
              Row(
                children: [
                  Expanded(
                    child: field(
                      labelText: 'Travel Date',
                      controller: travelDateController,
                      hint: 'yyyy-mm-dd',
                      required: true,
                      readOnly: true,
                      onTap: () => pickDate(travelDateController),
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(
                      labelText: 'Return Date',
                      controller: returnDateController,
                      hint: 'yyyy-mm-dd',
                      required: true,
                      readOnly: true,
                      onTap: () => pickDate(returnDateController),
                      icon: Icons.event_available_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        section(
          title: 'CRM Linkage',
          subtitle: 'Customer, contact and related CRM references',
          icon: Icons.business_center_outlined,
          child: Column(
            children: [
              dropdownField<int>(
                labelText: 'Account / Customer',
                value: customerId,
                hint: 'Search customer...',
                icon: Icons.business_outlined,
                items: widget.customers.map((c) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(c['id'].toString()) ?? c['id'],
                    child: Text(
                      c['customer_name']?.toString() ??
                          c['label']?.toString() ??
                          '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => customerId = v),
              ),
              gap(),
              Row(
                children: [
                  Expanded(
                    child: field(
                      labelText: 'Contact Person',
                      controller: contactNameController,
                      hint: 'Name of person to meet',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(
                      labelText: 'Contact Phone',
                      controller: contactPhoneController,
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      icon: Icons.phone_outlined,
                    ),
                  ),
                ],
              ),
              gap(),
              Row(
                children: [
                  Expanded(
                    child: field(
                      labelText: 'Linked Opportunity',
                      controller: opportunityRefController,
                      hint: 'Opportunity ID',
                      keyboardType: TextInputType.number,
                      icon: Icons.trending_up_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(
                      labelText: 'Lead / Reference ID',
                      controller: leadRefController,
                      hint: 'Lead ID',
                      keyboardType: TextInputType.number,
                      icon: Icons.tag_outlined,
                    ),
                  ),
                ],
              ),
              gap(),
              Row(
                children: [
                  Expanded(
                    child: field(
                      labelText: 'Linked Tender',
                      controller: tenderRefController,
                      hint: 'Tender ID',
                      keyboardType: TextInputType.number,
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(
                      labelText: 'Working Group',
                      controller: workingGroupController,
                      hint: 'Working group ID',
                      keyboardType: TextInputType.number,
                      icon: Icons.groups_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget stepTwo() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        section(
          title: 'Advance Request',
          subtitle: '',
          icon: Icons.credit_card_outlined,
          child: Column(
            children: [

              gap(),
              switchCard(
                title: 'Request Cash Advance',
                subtitle: 'Enable this to request advance amount before travel',
                value: advanceRequired,
                icon: Icons.payments_outlined,
                onChanged: (v) {
                  setState(() {
                    advanceRequired = v;
                    if (!advanceRequired) advanceAmountController.clear();
                  });
                },
              ),
              if (advanceRequired) ...[
                gap(),
                field(
                  labelText: 'Advance Amount Required (INR)',
                  controller: advanceAmountController,
                  hint: 'Enter advance amount',
                  required: true,
                  keyboardType: TextInputType.number,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ],
          ),
        ),
        section(
          title: 'Accommodation',
          subtitle: 'Stay requirement, hotel and check-in details',
          icon: Icons.hotel_outlined,
          child: Column(
            children: [
              switchCard(
                title: 'Accommodation Required',
                subtitle: 'Enable this if stay arrangement is needed',
                value: accommodationRequired,
                icon: Icons.bed_outlined,
                onChanged: (v) {
                  setState(() {
                    accommodationRequired = v;
                    if (!accommodationRequired) {
                      accommodationType = 'Not Required';
                      hotelNameController.clear();
                      checkInDateController.clear();
                      checkOutDateController.clear();
                      accommodationCostController.clear();
                    } else {
                      accommodationType = 'Company Guest House';
                    }
                  });
                },
              ),
              if (accommodationRequired) ...[
                gap(),
                dropdownField<String>(
                  labelText: 'Accommodation Type',
                  value: accommodationType,
                  hint: 'Select accommodation type',
                  required: true,
                  icon: Icons.apartment_outlined,
                  items: const [
                    'Company Guest House',
                    'Hotel (Self-Book)',
                    'Hotel (Company Arranged)',
                    'Customer Arranged',
                    'Home Stay',
                    'Not Required',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    setState(() => accommodationType = v ?? 'Not Required');
                  },
                ),
                gap(),
                field(
                  labelText: 'Hotel / Property Name',
                  controller: hotelNameController,
                  hint: 'Hotel or property name',
                  icon: Icons.location_city_outlined,
                ),
                gap(),
                Row(
                  children: [
                    Expanded(
                      child: field(
                        labelText: 'Check-in Date',
                        controller: checkInDateController,
                        hint: 'yyyy-mm-dd',
                        readOnly: true,
                        onTap: () => pickDate(checkInDateController),
                        icon: Icons.login_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: field(
                        labelText: 'Check-out Date',
                        controller: checkOutDateController,
                        hint: 'yyyy-mm-dd',
                        readOnly: true,
                        onTap: () => pickDate(checkOutDateController),
                        icon: Icons.logout_outlined,
                      ),
                    ),
                  ],
                ),
                gap(),
                field(
                  labelText: 'Estimated Accommodation Cost (INR)',
                  controller: accommodationCostController,
                  hint: 'Per night or total',
                  keyboardType: TextInputType.number,
                  icon: Icons.currency_rupee_rounded,
                ),
              ],
            ],
          ),
        ),

        section(
          title: 'Additional Info',
          subtitle: 'Companions and special instructions for approver',
          icon: Icons.note_alt_outlined,
          child: Column(
            children: [
              field(
                labelText: 'Travel Companions',
                controller: companionsController,
                hint: 'Names of colleagues travelling together',
                icon: Icons.group_outlined,
              ),
              gap(),
              field(
                labelText: 'Notes / Special Instructions',
                controller: notesController,
                hint: 'Any additional context',
                maxLines: 4,
                icon: Icons.sticky_note_2_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xffE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (step == 2)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                    await saveDraft();
                    setState(() => step = 1);
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Previous'),
                ),
              )
            else
              Expanded(
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                    final ok = await confirmBack();
                    if (ok && mounted) Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                  await saveDraft();

                  if (step == 1) {
                    goNext();
                  } else {
                    await createRequest();
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
                  step == 1
                      ? Icons.arrow_forward_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  saving
                      ? 'Saving...'
                      : step == 1
                      ? 'Next'
                      : 'Create Request',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  step == 1 ? AppColors.primaryLight : AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    advanceAmountController.dispose();
    accommodationCostController.dispose();
    hotelNameController.dispose();
    checkInDateController.dispose();
    checkOutDateController.dispose();
    costCenterController.dispose();
    budgetCodeController.dispose();
    purposeController.dispose();
    fromCityController.dispose();
    toCityController.dispose();
    travelDateController.dispose();
    returnDateController.dispose();
    contactNameController.dispose();
    contactPhoneController.dispose();
    leadRefController.dispose();
    opportunityRefController.dispose();
    tenderRefController.dispose();
    workingGroupController.dispose();
    transportModeController.dispose();
    vehicleNumberController.dispose();
    estimatedKmsController.dispose();
    bookingRefController.dispose();
    estimatedCostController.dispose();
    companionsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                    IconButton(
                      onPressed: () async {
                        final ok = await confirmBack();
                        if (ok && mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),

                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:  [
                          Text(
                            widget.editData == null ? 'New Travel Request' : 'Edit Travel Request',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Actual expenses are claimed after travel',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(.12)),
                      ),
                      child: Text(
                        'Step $step/2',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          stepHeader(),
          Expanded(child: step == 1 ? stepOne() : stepTwo()),
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
