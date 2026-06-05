import 'dart:convert';

import 'package:ascent_crm/api_helpers/api_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF3060A0);

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

class CreateCustomer extends StatefulWidget {
  final Map<String, dynamic>? customerData;

  const CreateCustomer({super.key, this.customerData});

  bool get isEdit => customerData != null;

  @override
  State<CreateCustomer> createState() => _CreateCustomerState();
}

class ContactFormModel {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController designationController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController officePhoneController = TextEditingController();
  final TextEditingController officeEmailController = TextEditingController();

  Map<String, dynamic> toDraftJson() {
    return {
      "contact_name": nameController.text,
      "designation": designationController.text,
      "department": departmentController.text,
      "mobile": mobileController.text,
      "office_phone": officePhoneController.text,
      "office_email": officeEmailController.text,
    };
  }

  void fromJson(Map<String, dynamic> item) {
    nameController.text = item['contact_name']?.toString() ?? '';
    designationController.text = item['designation']?.toString() ?? '';
    departmentController.text = item['department']?.toString() ?? '';
    mobileController.text = item['mobile']?.toString() ?? '';
    officePhoneController.text = item['office_phone']?.toString() ?? '';
    officeEmailController.text = item['office_email']?.toString() ?? '';
  }

  void dispose() {
    nameController.dispose();
    designationController.dispose();
    departmentController.dispose();
    mobileController.dispose();
    officePhoneController.dispose();
    officeEmailController.dispose();
  }
}

class _CreateCustomerState extends State<CreateCustomer> with SingleTickerProviderStateMixin {
  static const String baseUrl = 'http://103.110.236.187:3076/api/v1';
  static const String draftKey = 'create_customer_draft_v2';

  final _formKey = GlobalKey<FormState>();
  late final TabController tabController;

  int currentStep = 0;
  bool isLoading = false;
  bool initialLoading = true;
  bool isBranch = false;
  bool sameAsBilling = false;
  bool isApplyingDraftOrEdit = false;

  String? token;
  String? tenantSlug;
  String? customerNameError;

  List<String> customerNameList = [];
  List<String> groupNameList = [];
  List<Map<String, dynamic>> teamUsers = [];

  Map<String, dynamic>? selectedUser;
  int? assignedUserId;

  final List<String> verticalList = const [
    "BFSI",
    "Central Government",
    "Corporate",
    "Defence",
    "Railways",
    "SMB",
    "State Government",
  ];

  String? selectedVertical;
  String? selectedGroup;
  String selectedStatus = "Prospect";
  String selectedPotential = "Medium";
  String? selectedParentAccount;

  final customerNameController = TextEditingController();
  final divisionController = TextEditingController();
  final gstController = TextEditingController();
  final panController = TextEditingController();
  final websiteController = TextEditingController();
  final potentialValueController = TextEditingController();
  final assignedController = TextEditingController();
  final remarksController = TextEditingController();

  final billingStreetController = TextEditingController();
  final billingPincodeController = TextEditingController();
  final billingCountryController = TextEditingController(text: "India");
  final billingStateController = TextEditingController();
  final billingCityController = TextEditingController();
  final billingAreaController = TextEditingController();

  final shippingStreetController = TextEditingController();
  final shippingPincodeController = TextEditingController();
  final shippingCountryController = TextEditingController(text: "India");
  final shippingStateController = TextEditingController();
  final shippingCityController = TextEditingController();
  final shippingAreaController = TextEditingController();

  final List<ContactFormModel> contacts = [ContactFormModel()];
  int? primaryContactIndex;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    selectedVertical = verticalList.first;
    bindDraftListeners();
    getSharedPref();
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'X-Tenant-Slug': tenantSlug ?? '',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  void bindDraftListeners() {
    final controllers = [
      customerNameController,
      divisionController,
      gstController,
      panController,
      websiteController,
      potentialValueController,
      assignedController,
      remarksController,
      billingStreetController,
      billingPincodeController,
      billingCountryController,
      billingStateController,
      billingCityController,
      billingAreaController,
      shippingStreetController,
      shippingPincodeController,
      shippingCountryController,
      shippingStateController,
      shippingCityController,
      shippingAreaController,
    ];

    for (final controller in controllers) {
      controller.addListener(() {
        if (!isApplyingDraftOrEdit) saveDraft();
      });
    }
  }

  Future<void> getSharedPref() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');
    tenantSlug = prefs.getString('tenant_slug') ?? '';

    if (token != null) {
      await fetchGroupDropDown();
      await fetchCusComBranch();
      await fetchTeamUser();

      isApplyingDraftOrEdit = true;
      if (widget.isEdit) {
        setEditValues();
      } else {
        await loadDraft();
      }
      isApplyingDraftOrEdit = false;
    }

    if (mounted) {
      setState(() => initialLoading = false);
    }
  }

  Future<void> fetchTeamUser() async {
    if (token == null) return;

    try {
      final response = await ApiMethod.getRequest(
        url: '$baseUrl/customers/team-users',
        headers: headers,
      );

      if (response['statusCode'] == 200) {
        final List res = response['data'];
        if (!mounted) return;
        setState(() {
          teamUsers = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint("fetchTeamUser error: $e");
    }
  }

  Future<void> fetchGroupDropDown() async {
    if (token == null) return;

    try {
      final response = await ApiMethod.getRequest(
        url: '$baseUrl/customers/group-dropdown',
        headers: headers,
      );

      if (response['statusCode'] == 200) {
        final List res = response['data'];
        if (!mounted) return;
        setState(() {
          groupNameList = res
              .map((e) => e['group_name'])
              .where((e) => e != null)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty && e.toLowerCase() != "null")
              .toSet()
              .toList();
        });
      }
    } catch (e) {
      debugPrint("fetchGroupDropDown error: $e");
    }
  }

  Future<void> fetchCusComBranch() async {
    if (token == null) return;

    try {
      final response = await ApiMethod.getRequest(
        url: '$baseUrl/customers/dropdown',
        headers: headers,
      );

      if (response['statusCode'] == 200) {
        final List res = response['data'];
        if (!mounted) return;
        setState(() {
          customerNameList = res
              .map((e) => e['customer_name'])
              .where((e) => e != null)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty && e.toLowerCase() != "null")
              .toSet()
              .toList();
        });
      }
    } catch (e) {
      debugPrint("fetchCusComBranch error: $e");
    }
  }

  void setEditValues() {
    final data = widget.customerData;
    if (data == null) return;

    customerNameController.text = data['customer_name']?.toString() ?? '';
    selectedVertical = data['customer_vertical']?.toString().trim();
    divisionController.text = data['division']?.toString() ?? '';
    selectedGroup = data['group_name']?.toString();
    gstController.text = data['gst_number']?.toString() ?? '';
    panController.text = data['pan_number']?.toString() ?? '';
    websiteController.text = data['website']?.toString() ?? '';
    selectedStatus = data['account_status']?.toString() ?? 'Prospect';
    selectedPotential = data['account_potential']?.toString() ?? 'Medium';
    potentialValueController.text = data['potential_value']?.toString() ?? '';
    remarksController.text = data['remarks']?.toString() ?? '';

    assignedUserId = data['assigned_to'];
    assignedController.text = data['assigned_user_name']?.toString() ?? '';

    billingStreetController.text = data['billing_address']?.toString() ?? '';
    billingPincodeController.text = data['billing_pincode']?.toString() ?? '';
    billingCountryController.text = data['billing_country']?.toString() ?? 'India';
    billingStateController.text = data['billing_state']?.toString() ?? '';
    billingCityController.text = data['billing_city']?.toString() ?? '';
    billingAreaController.text = data['billing_area']?.toString() ?? '';

    sameAsBilling = data['shipping_same_as_billing'] == true;

    if (sameAsBilling) {
      copyBillingToShipping();
    } else {
      shippingStreetController.text = data['shipping_address']?.toString() ?? '';
      shippingPincodeController.text = data['shipping_pincode']?.toString() ?? '';
      shippingCountryController.text = data['shipping_country']?.toString() ?? 'India';
      shippingStateController.text = data['shipping_state']?.toString() ?? '';
      shippingCityController.text = data['shipping_city']?.toString() ?? '';
      shippingAreaController.text = data['shipping_area']?.toString() ?? '';
    }

    final editContacts = data['contacts'] ?? [];
    for (final c in contacts) {
      c.dispose();
    }
    contacts.clear();

    if (editContacts is List && editContacts.isNotEmpty) {
      for (int i = 0; i < editContacts.length; i++) {
        final item = Map<String, dynamic>.from(editContacts[i]);
        final contact = ContactFormModel();
        contact.nameController.text = item['contact_name']?.toString() ?? '';
        contact.designationController.text = item['designation']?.toString() ?? '';
        contact.departmentController.text = item['department']?.toString() ?? '';
        contact.mobileController.text = item['mobile']?.toString() ?? '';
        contact.officePhoneController.text = item['office_phone']?.toString() ?? '';
        contact.officeEmailController.text = item['office_email']?.toString() ?? '';
        if (item['is_primary'] == true) primaryContactIndex = i;
        contacts.add(contact);
      }
    } else {
      contacts.add(ContactFormModel());
    }
  }

  Future<void> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw));

      customerNameController.text = data['customer_name']?.toString() ?? '';
      selectedVertical = data['customer_vertical']?.toString().trim();
      divisionController.text = data['division']?.toString() ?? '';
      selectedGroup = data['group_name']?.toString();
      gstController.text = data['gst_number']?.toString() ?? '';
      panController.text = data['pan_number']?.toString() ?? '';
      websiteController.text = data['website']?.toString() ?? '';
      selectedStatus = data['account_status']?.toString() ?? 'Prospect';
      selectedPotential = data['account_potential']?.toString() ?? 'Medium';
      potentialValueController.text = data['potential_value']?.toString() ?? '';
      assignedUserId = int.tryParse(data['assigned_to']?.toString() ?? '');
      assignedController.text = data['assigned_user_name']?.toString() ?? '';
      selectedParentAccount = data['parent_account']?.toString();
      isBranch = data['is_branch'] == true;
      remarksController.text = data['remarks']?.toString() ?? '';

      billingStreetController.text = data['billing_address']?.toString() ?? '';
      billingPincodeController.text = data['billing_pincode']?.toString() ?? '';
      billingCountryController.text = data['billing_country']?.toString() ?? 'India';
      billingStateController.text = data['billing_state']?.toString() ?? '';
      billingCityController.text = data['billing_city']?.toString() ?? '';
      billingAreaController.text = data['billing_area']?.toString() ?? '';

      sameAsBilling = data['shipping_same_as_billing'] == true;
      shippingStreetController.text = data['shipping_address']?.toString() ?? '';
      shippingPincodeController.text = data['shipping_pincode']?.toString() ?? '';
      shippingCountryController.text = data['shipping_country']?.toString() ?? 'India';
      shippingStateController.text = data['shipping_state']?.toString() ?? '';
      shippingCityController.text = data['shipping_city']?.toString() ?? '';
      shippingAreaController.text = data['shipping_area']?.toString() ?? '';

      primaryContactIndex = int.tryParse(data['primary_contact_index']?.toString() ?? '');

      final draftContacts = data['contacts'];
      if (draftContacts is List && draftContacts.isNotEmpty) {
        for (final c in contacts) {
          c.dispose();
        }
        contacts.clear();

        for (final item in draftContacts) {
          final contact = ContactFormModel();
          contact.fromJson(Map<String, dynamic>.from(item));
          contacts.add(contact);
          bindContactDraftListener(contact);
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Draft load error: $e");
    }
  }

  Future<void> saveDraft() async {
    if (widget.isEdit) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(draftKey, jsonEncode(buildDraft()));
    } catch (e) {
      debugPrint("Draft save error: $e");
    }
  }

  Map<String, dynamic> buildDraft() {
    return {
      "customer_name": customerNameController.text,
      "customer_vertical": selectedVertical,
      "division": divisionController.text,
      "group_name": selectedGroup,
      "is_branch": isBranch,
      "parent_account": selectedParentAccount,
      "gst_number": gstController.text,
      "pan_number": panController.text,
      "website": websiteController.text,
      "account_status": selectedStatus,
      "account_potential": selectedPotential,
      "potential_value": potentialValueController.text,
      "assigned_to": assignedUserId,
      "assigned_user_name": assignedController.text,
      "remarks": remarksController.text,
      "billing_address": billingStreetController.text,
      "billing_pincode": billingPincodeController.text,
      "billing_country": billingCountryController.text,
      "billing_state": billingStateController.text,
      "billing_city": billingCityController.text,
      "billing_area": billingAreaController.text,
      "shipping_same_as_billing": sameAsBilling,
      "shipping_address": shippingStreetController.text,
      "shipping_pincode": shippingPincodeController.text,
      "shipping_country": shippingCountryController.text,
      "shipping_state": shippingStateController.text,
      "shipping_city": shippingCityController.text,
      "shipping_area": shippingAreaController.text,
      "primary_contact_index": primaryContactIndex,
      "contacts": contacts.map((e) => e.toDraftJson()).toList(),
    };
  }

  Future<void> clearDraftAndFields() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);

    customerNameController.clear();
    divisionController.clear();
    gstController.clear();
    panController.clear();
    websiteController.clear();
    potentialValueController.clear();
    assignedController.clear();
    remarksController.clear();

    billingStreetController.clear();
    billingPincodeController.clear();
    billingCountryController.text = "India";
    billingStateController.clear();
    billingCityController.clear();
    billingAreaController.clear();

    shippingStreetController.clear();
    shippingPincodeController.clear();
    shippingCountryController.text = "India";
    shippingStateController.clear();
    shippingCityController.clear();
    shippingAreaController.clear();

    for (final c in contacts) {
      c.dispose();
    }
    contacts.clear();
    contacts.add(ContactFormModel());
    bindContactDraftListener(contacts.first);

    selectedVertical = verticalList.first;
    selectedGroup = null;
    selectedStatus = "Prospect";
    selectedPotential = "Medium";
    selectedParentAccount = null;
    assignedUserId = null;
    selectedUser = null;
    sameAsBilling = false;
    isBranch = false;
    primaryContactIndex = null;
  }

  void bindContactDraftListener(ContactFormModel contact) {
    final list = [
      contact.nameController,
      contact.designationController,
      contact.departmentController,
      contact.mobileController,
      contact.officePhoneController,
      contact.officeEmailController,
    ];

    for (final controller in list) {
      controller.addListener(() {
        if (!isApplyingDraftOrEdit) saveDraft();
      });
    }
  }

  bool isCustomerAlreadyExists(String value) {
    final enteredName = value.trim().toLowerCase();
    if (enteredName.isEmpty) return false;

    if (widget.isEdit) {
      final oldName = widget.customerData?['customer_name']?.toString().trim().toLowerCase();
      if (enteredName == oldName) return false;
    }

    return customerNameList.any((name) => name.trim().toLowerCase() == enteredName);
  }

  void checkCustomerNameInstantly(String value) {
    final alreadyExists = isCustomerAlreadyExists(value);

    setState(() {
      if (value.trim().isEmpty) {
        customerNameError = null;
      } else if (alreadyExists) {
        customerNameError = "Name already exists";
      } else {
        customerNameError = null;
      }
    });

    saveDraft();
  }

  Future<void> fetchAddAfterPin({
    required String pincode,
    required bool isBilling,
  }) async {
    if (token == null) return;

    try {
      final response = await ApiMethod.getRequest(
        url: '$baseUrl/customers/pincode/$pincode',
        headers: headers,
      );

      if (response['statusCode'] == 200) {
        final res = response['data'];

        setState(() {
          if (isBilling) {
            billingCountryController.text = res['country'] ?? "India";
            billingStateController.text = res['state'] ?? "";
            billingCityController.text = res['city'] ?? "";
            billingAreaController.text = res['area'] ?? "";

            if (sameAsBilling) copyBillingToShipping();
          } else {
            shippingCountryController.text = res['country'] ?? "India";
            shippingStateController.text = res['state'] ?? "";
            shippingCityController.text = res['city'] ?? "";
            shippingAreaController.text = res['area'] ?? "";
          }
        });

        saveDraft();
      }
    } catch (e) {
      debugPrint("fetchAddAfterPin error: $e");
    }
  }

  void addContact() {
    final contact = ContactFormModel();
    bindContactDraftListener(contact);

    setState(() {
      contacts.add(contact);
    });

    saveDraft();
  }

  void removeContact(int index) {
    if (contacts.length == 1) return;

    setState(() {
      contacts[index].dispose();
      contacts.removeAt(index);

      if (primaryContactIndex == index) {
        primaryContactIndex = null;
      } else if (primaryContactIndex != null && primaryContactIndex! > index) {
        primaryContactIndex = primaryContactIndex! - 1;
      }
    });

    saveDraft();
  }

  void copyBillingToShipping() {
    shippingStreetController.text = billingStreetController.text;
    shippingPincodeController.text = billingPincodeController.text;
    shippingCountryController.text = billingCountryController.text;
    shippingStateController.text = billingStateController.text;
    shippingCityController.text = billingCityController.text;
    shippingAreaController.text = billingAreaController.text;
  }

  bool validateAccountTab() {
    final alreadyExists = isCustomerAlreadyExists(customerNameController.text);

    if (customerNameController.text.trim().isEmpty) {
      showSnack("Customer name is required", Colors.red);
      return false;
    }

    if (alreadyExists) {
      setState(() {
        customerNameError = "Customer/Company/Branch Name already exists";
      });
      showSnack("Customer name already exists", Colors.red);
      return false;
    }

    if ((selectedVertical ?? '').trim().isEmpty) {
      showSnack("Vertical / Sector is required", Colors.red);
      return false;
    }

    if (divisionController.text.trim().isEmpty) {
      showSnack("Division / Department is required", Colors.red);
      return false;
    }

    if ((selectedGroup ?? '').trim().isEmpty) {
      showSnack("Group Name is required", Colors.red);
      return false;
    }

    return true;
  }

  bool validateAddressTab() {
    if (billingStreetController.text.trim().isEmpty) {
      showSnack("Billing street address is required", Colors.red);
      return false;
    }

    if (billingPincodeController.text.trim().length != 6) {
      showSnack("Billing pincode must be 6 digits", Colors.red);
      return false;
    }

    if (billingCountryController.text.trim().isEmpty ||
        billingStateController.text.trim().isEmpty ||
        billingCityController.text.trim().isEmpty ||
        billingAreaController.text.trim().isEmpty) {
      showSnack("Billing country, state, city and area are required", Colors.red);
      return false;
    }

    return true;
  }

  bool validateContactsTab() {
    for (int i = 0; i < contacts.length; i++) {
      final c = contacts[i];

      if (c.nameController.text.trim().isEmpty ||
          c.designationController.text.trim().isEmpty ||
          c.departmentController.text.trim().isEmpty ||
          c.mobileController.text.trim().isEmpty) {
        showSnack("Please complete required fields in Contact ${i + 1}", Colors.red);
        return false;
      }

      if (c.mobileController.text.trim().length != 10) {
        showSnack("Mobile number must be 10 digits in Contact ${i + 1}", Colors.red);
        return false;
      }

      final email = c.officeEmailController.text.trim();
      if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        showSnack("Invalid office email in Contact ${i + 1}", Colors.red);
        return false;
      }
    }

    return true;
  }

  Future<void> saveAndNext() async {
    await saveDraft();

    if (currentStep == 0 && !validateAccountTab()) return;
    if (currentStep == 1 && !validateAddressTab()) return;

    if (currentStep < 2) {
      setState(() {
        currentStep++;
        tabController.animateTo(currentStep);
      });
    }
  }

  void previousStep() {
    saveDraft();

    if (currentStep > 0) {
      setState(() {
        currentStep--;
        tabController.animateTo(currentStep);
      });
    }
  }

  Future<bool> onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {

        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          title: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Discard Changes?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to go back? If you continue, all entered details will be permanently removed.",
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Discard",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      },
    );

    if (shouldLeave == true) {
      if (!widget.isEdit) await clearDraftAndFields();
      if (mounted) Navigator.pop(context);
    }

    return false;
  }

  Future<void> createCustomer() async {
    await saveDraft();

    if (!validateAccountTab()) {
      setState(() {
        currentStep = 0;
        tabController.animateTo(0);
      });
      return;
    }

    if (!validateAddressTab()) {
      setState(() {
        currentStep = 1;
        tabController.animateTo(1);
      });
      return;
    }

    if (!validateContactsTab()) {
      setState(() {
        currentStep = 2;
        tabController.animateTo(2);
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      if (sameAsBilling) copyBillingToShipping();

      final body = {
        "customer_name": customerNameController.text.trim(),
        "group_name": selectedGroup,
        "division": divisionController.text.trim(),
        "customer_vertical": selectedVertical,
        "account_status": selectedStatus,
        "account_potential": selectedPotential,
        "potential_value": potentialValueController.text.trim().isEmpty
            ? null
            : double.tryParse(potentialValueController.text.trim()),
        "assigned_to": assignedUserId,
        "gst_number": gstController.text.trim().isEmpty ? null : gstController.text.trim(),
        "pan_number": panController.text.trim().isEmpty ? null : panController.text.trim(),
        "website": websiteController.text.trim().isEmpty ? null : websiteController.text.trim(),
        "remarks": remarksController.text.trim(),
        "billing_address": billingStreetController.text.trim(),
        "billing_pincode": billingPincodeController.text.trim(),
        "billing_country": billingCountryController.text.trim(),
        "billing_state": billingStateController.text.trim(),
        "billing_city": billingCityController.text.trim(),
        "billing_area": billingAreaController.text.trim(),
        "shipping_same_as_billing": sameAsBilling,
        "shipping_address": shippingStreetController.text.trim(),
        "shipping_pincode": shippingPincodeController.text.trim(),
        "shipping_country": shippingCountryController.text.trim(),
        "shipping_state": shippingStateController.text.trim(),
        "shipping_city": shippingCityController.text.trim(),
        "shipping_area": shippingAreaController.text.trim(),
        "contacts": List.generate(contacts.length, (index) {
          final contact = contacts[index];
          return {
            "contact_name": contact.nameController.text.trim(),
            "designation": contact.designationController.text.trim(),
            "department": contact.departmentController.text.trim(),
            "mobile": contact.mobileController.text.trim(),
            "office_phone": contact.officePhoneController.text.trim().isEmpty
                ? null
                : contact.officePhoneController.text.trim(),
            "office_email": contact.officeEmailController.text.trim().isEmpty
                ? null
                : contact.officeEmailController.text.trim(),
            "is_primary": primaryContactIndex == index,
          };
        }),
      };

      final url = widget.isEdit
          ? "$baseUrl/customers/${widget.customerData!['id']}"
          : "$baseUrl/customers/";

      final response = widget.isEdit
          ? await ApiMethod.putRequest(url: url, headers: headers, body: body)
          : await ApiMethod.postRequest(url: url, headers: headers, body: body);

      setState(() => isLoading = false);

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        if (!widget.isEdit) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(draftKey);
        }

        showSnack(
          widget.isEdit ? "Customer Updated Successfully" : "Customer Created Successfully",
          Colors.green,
        );

        if (mounted) Navigator.pop(context, true);
      } else {
        showSnack(response['data']?.toString() ?? "An error occurred", Colors.red);
      }
    } catch (e) {
      setState(() => isLoading = false);
      showSnack(e.toString(), Colors.red);
    }
  }

  void showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    tabController.dispose();

    customerNameController.dispose();
    divisionController.dispose();
    gstController.dispose();
    panController.dispose();
    websiteController.dispose();
    potentialValueController.dispose();
    assignedController.dispose();
    remarksController.dispose();

    billingStreetController.dispose();
    billingPincodeController.dispose();
    billingCountryController.dispose();
    billingStateController.dispose();
    billingCityController.dispose();
    billingAreaController.dispose();

    shippingStreetController.dispose();
    shippingPincodeController.dispose();
    shippingCountryController.dispose();
    shippingStateController.dispose();
    shippingCityController.dispose();
    shippingAreaController.dispose();

    for (final contact in contacts) {
      contact.dispose();
    }

    super.dispose();
  }

  bool isWide(BuildContext context) => MediaQuery.of(context).size.width >= 760;

  Widget responsiveGrid(List<Widget> children) {
    final wide = isWide(context);
    final rows = <Widget>[];

    for (int i = 0; i < children.length; i += wide ? 2 : 1) {
      if (wide && i + 1 < children.length) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 18),
                Expanded(child: children[i + 1]),
              ],
            ),
          ),
        );
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: children[i],
          ),
        );
      }
    }

    return Column(children: rows);
  }

  Widget appTextField({
    required String title,
    required TextEditingController controller,
    bool requiredField = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    IconData? icon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(title, requiredField),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator ??
              (requiredField
                  ? (value) => value == null || value.trim().isEmpty ? "Required" : null
                  : null),
          decoration: InputDecoration(
            errorText: errorText,
            prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.primaryLight),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget label(String text, bool requiredField) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.primaryDeep,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        children: [
          if (requiredField)
            const TextSpan(
              text: " *",
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget appDropdown({
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool requiredField = false,
    IconData? icon,
  }) {
    final uniqueItems = items
        .where((e) => e.trim().isNotEmpty && e.toLowerCase() != "null")
        .toSet()
        .toList();

    final safeValue = uniqueItems.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(title, requiredField),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: safeValue,
          hint: Text(uniqueItems.isEmpty ? "No data found" : "Select $title"),
          isExpanded: true,
          validator: requiredField
              ? (value) => value == null || value.trim().isEmpty ? "Required" : null
              : null,
          decoration: InputDecoration(
            prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.primaryLight),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
            ),
          ),
          items: uniqueItems.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: uniqueItems.isEmpty
              ? null
              : (value) {
            onChanged(value);
            saveDraft();
          },
        ),
      ],
    );
  }

  Widget card({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primaryDeep,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget accountDetailsTab() {
    return formScroll(
      child: Column(
        children: [
          card(
            title: "Account Details",
            subtitle: "Basic company profile and ownership details",
            icon: Icons.business_center_outlined,
            child: Column(
              children: [
                responsiveGrid([
                  appTextField(
                    title: "Customer/Company/Branch Name",
                    controller: customerNameController,
                    requiredField: true,
                    icon: Icons.business_outlined,
                    errorText: customerNameError,
                    onChanged: checkCustomerNameInstantly,
                  ),
                  branchSelector(),
                ]),
                if (isBranch)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: autocompleteText(
                      title: "Parent Account",
                      hint: "Search Parent Account",
                      options: customerNameList,
                      initialValue: selectedParentAccount,
                      requiredField: true,
                      icon: Icons.account_tree_outlined,
                      onSelected: (value) {
                        setState(() => selectedParentAccount = value);
                        saveDraft();
                      },
                    ),
                  ),
                responsiveGrid([
                  appDropdown(
                    title: "Vertical / Sector",
                    value: selectedVertical,
                    requiredField: true,
                    items: verticalList,
                    icon: Icons.category_outlined,
                    onChanged: (value) => setState(() => selectedVertical = value),
                  ),
                  appTextField(
                    title: "Division / Department",
                    controller: divisionController,
                    requiredField: true,
                    icon: Icons.apartment_outlined,
                  ),
                  autocompleteText(
                    title: "Group Name",
                    hint: "Search or select group",
                    options: groupNameList,
                    initialValue: selectedGroup,
                    requiredField: true,
                    icon: Icons.group_work_outlined,
                    onSelected: (value) {
                      setState(() => selectedGroup = value);
                      saveDraft();
                    },
                  ),
                  appTextField(
                    title: "GST Number",
                    controller: gstController,
                    icon: Icons.receipt_long_outlined,
                    inputFormatters: [UpperCaseTextFormatter()],
                  ),
                  appTextField(
                    title: "PAN Number",
                    controller: panController,
                    icon: Icons.credit_card_outlined,
                    inputFormatters: [UpperCaseTextFormatter()],
                  ),
                  appTextField(
                    title: "Website",
                    controller: websiteController,
                    keyboardType: TextInputType.url,
                    icon: Icons.language_outlined,
                  ),
                ]),
                responsiveGrid([
                  appDropdown(
                    title: "Status",
                    value: selectedStatus,
                    items: const ["Prospect", "Active", "Inactive", "Churned"],
                    icon: Icons.verified_outlined,
                    onChanged: (value) => setState(() => selectedStatus = value ?? "Prospect"),
                  ),
                  appDropdown(
                    title: "Potential",
                    value: selectedPotential,
                    items: const ["Low", "Medium", "High"],
                    icon: Icons.trending_up_outlined,
                    onChanged: (value) => setState(() => selectedPotential = value ?? "Medium"),
                  ),
                  appTextField(
                    title: "Potential Value (₹)",
                    controller: potentialValueController,
                    keyboardType: TextInputType.number,
                    icon: Icons.currency_rupee,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                  autocompleteUser(),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget branchSelector() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_tree_outlined, color: AppColors.primaryLight, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Is this a branch?",
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDeep),
            ),
          ),
          Switch(
            value: isBranch,
            activeColor: AppColors.primaryLight,
            onChanged: (value) {
              setState(() {
                isBranch = value;
                if (!value) selectedParentAccount = null;
              });
              saveDraft();
            },
          ),
        ],
      ),
    );
  }

  Widget addressTab() {
    return formScroll(
      child: Column(
        children: [
          card(
            title: "Billing Address",
            subtitle: "Primary billing location and GST communication address",
            icon: Icons.location_city_outlined,
            child: Column(
              children: [
                appTextField(
                  title: "Street Address",
                  controller: billingStreetController,
                  requiredField: true,
                  maxLines: 3,
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 18),
                responsiveGrid([
                  appTextField(
                    title: "Pincode",
                    controller: billingPincodeController,
                    keyboardType: TextInputType.number,
                    requiredField: true,
                    icon: Icons.pin_drop_outlined,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (value) {
                      saveDraft();
                      if (value.length == 6) {
                        fetchAddAfterPin(pincode: value, isBilling: true);
                      }
                    },
                  ),
                  appTextField(
                    title: "Country",
                    controller: billingCountryController,
                    requiredField: true,
                    icon: Icons.public_outlined,
                  ),
                  appTextField(
                    title: "State",
                    controller: billingStateController,
                    requiredField: true,
                    icon: Icons.map_outlined,
                  ),
                  appTextField(
                    title: "City / District",
                    controller: billingCityController,
                    requiredField: true,
                    icon: Icons.location_city_outlined,
                  ),
                  appTextField(
                    title: "Area / Locality",
                    controller: billingAreaController,
                    requiredField: true,
                    icon: Icons.place_outlined,
                  ),
                ]),
              ],
            ),
          ),
          card(
            title: "Shipping Address",
            subtitle: "Delivery or dispatch address for customer shipments",
            icon: Icons.local_shipping_outlined,
            child: Column(
              children: [
                sameAsBillingTile(),
                const SizedBox(height: 16),
                appTextField(
                  title: "Street Address",
                  controller: shippingStreetController,
                  maxLines: 3,
                  icon: Icons.location_on_outlined,
                  readOnly: sameAsBilling,
                ),
                const SizedBox(height: 18),
                responsiveGrid([
                  appTextField(
                    title: "Pincode",
                    controller: shippingPincodeController,
                    keyboardType: TextInputType.number,
                    icon: Icons.pin_drop_outlined,
                    readOnly: sameAsBilling,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (value) {
                      saveDraft();
                      if (value.length == 6) {
                        fetchAddAfterPin(pincode: value, isBilling: false);
                      }
                    },
                  ),
                  appTextField(
                    title: "Country",
                    controller: shippingCountryController,
                    icon: Icons.public_outlined,
                    readOnly: sameAsBilling,
                  ),
                  appTextField(
                    title: "State",
                    controller: shippingStateController,
                    icon: Icons.map_outlined,
                    readOnly: sameAsBilling,
                  ),
                  appTextField(
                    title: "City / District",
                    controller: shippingCityController,
                    icon: Icons.location_city_outlined,
                    readOnly: sameAsBilling,
                  ),
                  appTextField(
                    title: "Area / Locality",
                    controller: shippingAreaController,
                    icon: Icons.place_outlined,
                    readOnly: sameAsBilling,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sameAsBillingTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_all_outlined, color: AppColors.primaryMedium),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Shipping address same as billing",
              style: TextStyle(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Switch(
            value: sameAsBilling,
            activeColor: AppColors.primaryLight,
            onChanged: (value) {
              setState(() {
                sameAsBilling = value;
                if (value) copyBillingToShipping();
              });
              saveDraft();
            },
          ),
        ],
      ),
    );
  }

  Widget contactsRemarksTab() {
    return formScroll(
      child: Column(
        children: [
          card(
            title: "Contacts",
            subtitle: "Add customer stakeholders and select a primary contact",
            icon: Icons.contacts_outlined,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: addContact,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text("Add Contact"),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
                  ),
                ),
                const SizedBox(height: 4),
                ...List.generate(contacts.length, (index) => contactCard(index)),
              ],
            ),
          ),
          card(
            title: "Remarks / Notes",
            subtitle: "Internal notes, special instructions or customer context",
            icon: Icons.note_alt_outlined,
            child: appTextField(
              title: "Notes",
              controller: remarksController,
              maxLines: 5,
              icon: Icons.notes_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget contactCard(int index) {
    final contact = contacts[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryMedium,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Contact ${index + 1}",
                  style: const TextStyle(
                    color: AppColors.primaryDeep,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: primaryContactIndex,
                    activeColor: AppColors.primaryLight,
                    onChanged: (value) {
                      setState(() => primaryContactIndex = value);
                      saveDraft();
                    },
                  ),
                  const Text("Primary", style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              if (contacts.length > 1)
                IconButton(
                  onPressed: () => removeContact(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          responsiveGrid([
            appTextField(
              title: "Full Name",
              controller: contact.nameController,
              requiredField: true,
              icon: Icons.person_outline,
            ),
            appTextField(
              title: "Designation",
              controller: contact.designationController,
              requiredField: true,
              icon: Icons.badge_outlined,
            ),
            appTextField(
              title: "Department",
              controller: contact.departmentController,
              requiredField: true,
              icon: Icons.account_balance_outlined,
            ),
            appTextField(
              title: "Mobile",
              controller: contact.mobileController,
              keyboardType: TextInputType.phone,
              requiredField: true,
              icon: Icons.phone_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            appTextField(
              title: "Office Phone",
              controller: contact.officePhoneController,
              keyboardType: TextInputType.phone,
              icon: Icons.call_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            appTextField(
              title: "Office Email",
              controller: contact.officeEmailController,
              keyboardType: TextInputType.emailAddress,
              icon: Icons.email_outlined,
            ),
          ]),
        ],
      ),
    );
  }

  Widget autocompleteText({
    required String title,
    required String hint,
    required List<String> options,
    required String? initialValue,
    required Function(String) onSelected,
    bool requiredField = false,
    IconData? icon,
  }) {
    final controller = TextEditingController(text: initialValue ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(title, requiredField),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: initialValue ?? ''),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return options;
            return options.where(
                  (item) => item.toLowerCase().contains(textEditingValue.text.toLowerCase()),
            );
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            textEditingController.text = controller.text;
            textEditingController.selection = TextSelection.fromPosition(
              TextPosition(offset: textEditingController.text.length),
            );

            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              onChanged: (value) {
                onSelected(value);
              },
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: icon == null ? null : Icon(icon, color: AppColors.primaryLight),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelectedOption, viewOptions) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 260,
                    maxWidth: MediaQuery.of(context).size.width - 40,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: viewOptions.length,
                    itemBuilder: (context, index) {
                      final option = viewOptions.elementAt(index);
                      return ListTile(
                        title: Text(option, overflow: TextOverflow.ellipsis),
                        onTap: () => onSelectedOption(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget autocompleteUser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label("Assigned To", false),
        const SizedBox(height: 8),
        Autocomplete<Map<String, dynamic>>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return teamUsers;

            return teamUsers.where((user) {
              final name = user['label'].toString().toLowerCase();
              return name.contains(textEditingValue.text.toLowerCase());
            });
          },
          displayStringForOption: (option) => option['label'] ?? '',
          onSelected: (Map<String, dynamic> selection) {
            setState(() {
              selectedUser = selection;
              assignedUserId = selection['id'];
              assignedController.text = selection['label'];
            });
            saveDraft();
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            textEditingController.text = assignedController.text;
            textEditingController.selection = TextSelection.fromPosition(
              TextPosition(offset: textEditingController.text.length),
            );

            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              onChanged: (value) {
                assignedController.text = value;
                saveDraft();
              },
              decoration: InputDecoration(
                hintText: "Search user",
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryLight),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelectedOption, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 260,
                    maxWidth: MediaQuery.of(context).size.width - 40,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final user = options.elementAt(index);
                      return ListTile(
                        title: Text(user['label'] ?? ''),
                        subtitle: Text(user['role'] ?? ''),
                        onTap: () => onSelectedOption(user),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget formScroll({required Widget child}) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      child: child,
    );
  }

  Widget header() {
    return Container(

      child: SafeArea(
        bottom: false,
        child:  Column(
            children: [
              Container(
          decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,

          ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onWillPop,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          widget.isEdit ? "Edit Customer" : "Add Customer",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              professionalStepTabs(),
/*
              const SizedBox(height: 14),
              stepProgress(),*/
            ],
          ),

      ),
    );
  }

  Widget professionalStepTabs() {
    final steps = ["Account", "Address", "Contacts"];

    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xffD9F1E2).withOpacity(0.75),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final active = currentStep == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (index > currentStep) {
                  if (currentStep == 0 && !validateAccountTab()) return;
                  if (currentStep == 1 && !validateAddressTab()) return;
                }

                saveDraft();
                setState(() {
                  currentStep = index;
                  tabController.animateTo(index);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  steps[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.primaryMedium,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget stepProgress() {
    final labels = ["Account Details", "Billing & Shipping", "Contacts & Notes"];

    return Row(
      children: List.generate(3, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              if (index != 2) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }

  Widget bottomButtons() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDeep.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            if (currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Previous"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDeep,
                    side: const BorderSide(color: AppColors.primaryMedium),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            if (currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : (currentStep == 2 ? createCustomer : saveAndNext),
                icon: isLoading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Icon(currentStep == 2 ? Icons.check_circle_outline : Icons.arrow_forward),
                label: Text(
                  currentStep == 2
                      ? (widget.isEdit ? "Update Customer" : "Submit Customer")
                      : "Save and Next",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) onWillPop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF4F7FB),
        body: initialLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
            : Form(
          key: _formKey,
          child: Column(
            children: [
              header(),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    accountDetailsTab(),
                    addressTab(),
                    contactsRemarksTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: initialLoading ? null : bottomButtons(),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
