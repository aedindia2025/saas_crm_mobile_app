import 'dart:convert';

import 'package:ascent_crm/api_helpers/api_method.dart';
import 'package:flutter/material.dart';
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

class CreateLead extends StatefulWidget {
  final Map<String, dynamic>? leadData;

  const CreateLead({super.key, this.leadData});

  bool get isEdit => leadData != null;

  @override
  State<CreateLead> createState() => _CreateLeadState();
}

class ProductRowModel {
  int? productId;
  String productName = "";
  final quantityController = TextEditingController(text: "1");
  final descriptionController = TextEditingController();
  List<OemRowModel> oems = [OemRowModel()];

  Map<String, dynamic> toJson() {
    return {
      "product_id": productId,
      "product_name": productName,
      "quantity": quantityController.text,
      "description": descriptionController.text,
      "oems": oems.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    productId = json["product_id"];
    productName = json["product_name"]?.toString() ?? "";
    quantityController.text = json["quantity"]?.toString() ?? "1";
    descriptionController.text = json["description"]?.toString() ?? "";
    oems.clear();
    final list = json["oems"];
    if (list is List && list.isNotEmpty) {
      for (final item in list) {
        final oem = OemRowModel();
        oem.fromJson(Map<String, dynamic>.from(item));
        oems.add(oem);
      }
    } else {
      oems.add(OemRowModel());
    }
  }

  void dispose() {
    quantityController.dispose();
    descriptionController.dispose();
    for (final oem in oems) {
      oem.dispose();
    }
  }
}

class OemRowModel {
  int? oemId;
  String oemName = "";

  Map<String, dynamic> toJson() => {"oem_id": oemId, "oem_name": oemName};

  void fromJson(Map<String, dynamic> json) {
    oemId = json["oem_id"];
    oemName = json["oem_name"]?.toString() ?? "";
  }

  void dispose() {}
}

class _CreateLeadState extends State<CreateLead> with SingleTickerProviderStateMixin {
  static const String baseUrl = "http://103.110.236.187:3076/api/v1";
  static const String draftKey = "create_lead_draft_v1";

  final _formKey = GlobalKey<FormState>();
  late TabController tabController;

  bool isLoading = false;
  bool isMasterLoading = true;
  int currentTab = 0;
  String? token;
  String? tenantSlug;

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> sources = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> competitors = [];
  List<Map<String, dynamic>> productsMaster = [];
  List<Map<String, dynamic>> oemsMaster = [];

  int? selectedCustomerId;
  String? selectedCustomerName;
  int? selectedSourceId;
  String? selectedSourceName;
  int? assignedToId;
  String? assignedToName;
  int? workingGroupId;

  String selectedPriority = "Medium";
  String selectedStatus = "Assigned";

  List<int> selectedCompetitorIds = [];
  List<ProductRowModel> productRows = [ProductRowModel()];

  final customerNameController = TextEditingController();
  final customerAddressController = TextEditingController();
  final departmentController = TextEditingController();
  final contactPersonController = TextEditingController();
  final designationController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final leadTitleController = TextEditingController();
  final estValueController = TextEditingController();
  final tenderRefController = TextEditingController();
  final timelineController = TextEditingController();
  final followUpController = TextEditingController();
  final productDescriptionController = TextEditingController();
  final notesController = TextEditingController();
  final regionController = TextEditingController();
  final branchController = TextEditingController();

  final List<String> priorities = const ["Low", "Medium", "High"];
  final List<String> statuses = const ["Assigned", "Qualified", "Lost"];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        setState(() => currentTab = tabController.index);
      }
    });
    loadInitialData();
  }

  Map<String, String> get headers => {
    "Authorization": "Bearer $token",
    "X-Tenant-Slug": tenantSlug ?? "",
    "Accept": "application/json",
    "Content-Type": "application/json",
  };

  Future<void> loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("auth_token");
    tenantSlug = prefs.getString("tenant_slug") ?? "";
    if (token == null) {
      setState(() => isMasterLoading = false);
      showError("Token not found");
      return;
    }
    await Future.wait([
      fetchCustomers(),
      fetchSources(),
      fetchUsers(),
      fetchCompetitors(),
      fetchProducts(),
      fetchOems(),
    ]);
    if (widget.isEdit) {
      setEditValues();
    } else {
      await loadDraft();
    }
    setState(() => isMasterLoading = false);
  }

  Future<List> getApiList(String url) async {
    final response = await ApiMethod.getRequest(url: url, headers: headers);
    if (response['statusCode'] == 200) return response['data'];
    return [];
  }

  Future<void> fetchCustomers() async {
    final res = await getApiList("$baseUrl/leads/team-customers");
    customers = res
        .map((e) => {
      "id": e["id"],
      "label": e["customer_name"],
      "approval_status": e["approval_status"],
      "approval_display": e["approval_display"],
      "is_active": e["is_active"],
    })
        .where((e) => e["id"] != null && e["label"] != null)
        .toList();
  }

  Future<void> fetchSources() async {
    final res = await getApiList("$baseUrl/masters/lead-sources");
    sources = res
        .map((e) => {"id": e["id"], "label": e["name"]})
        .where((e) => e["id"] != null && e["label"] != null)
        .toList();
  }

  Future<void> fetchUsers() async {
    final res = await getApiList("$baseUrl/leads/team-users");
    users = res
        .map((e) => {"id": e["id"], "label": e["label"], "role": e["role"]})
        .where((e) => e["id"] != null && e["label"] != null)
        .toList();
    if (users.isNotEmpty && assignedToId == null && !widget.isEdit) {
      assignedToId = users.first["id"];
      assignedToName = users.first["label"];
    }
  }

  Future<void> fetchCompetitors() async {
    final res = await getApiList("$baseUrl/masters/competitors");
    competitors = res
        .map((e) => {"id": e["id"], "label": e["name"]})
        .where((e) => e["id"] != null && e["label"] != null)
        .toList();
  }

  Future<void> fetchProducts() async {
    final res = await getApiList("$baseUrl/masters/products");
    productsMaster = res
        .map((e) => {"id": e["id"], "label": e["name"]})
        .where((e) => e["id"] != null && e["label"] != null)
        .toList();
  }

  Future<void> fetchOems() async {
    final res = await getApiList("$baseUrl/masters/oems");
    oemsMaster = res
        .map((e) => {"id": e["id"], "label": e["name"]})
        .where((e) => e["id"] != null && e["label"] != null)
        .toList();
  }

  Future<void> fetchCustomerActiveContact(int customerId) async {
    try {
      final response = await ApiMethod.getRequest(
        url: "$baseUrl/leads/customer/$customerId/active-contact",
        headers: headers,
      );
      if (response['statusCode'] == 200) {
        final data = response['data'];
        setState(() {
          customerNameController.text = data["customer_name"] ?? "";
          customerAddressController.text = data["customer_address"] ?? "";
          departmentController.text = data["department"] ?? "";
          contactPersonController.text = data["contact_name"] ?? "";
          designationController.text = data["contact_designation"] ?? "";
          mobileController.text = data["contact_phone"] ?? "";
          emailController.text = data["contact_email"] ?? "";
        });
        await saveDraft();
      }
    } catch (e) {
      debugPrint("fetchCustomerActiveContact error: $e");
    }
  }

  Future<void> quickAddMaster({
    required String title,
    required String label,
    required String url,
    required Future<void> Function() reload,
    required void Function(Map<String, dynamic> item) onCreated,
  }) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> closeDialog() async {
              focusNode.unfocus();
              FocusManager.instance.primaryFocus?.unfocus();

              await Future.delayed(const Duration(milliseconds: 120));

              if (dialogContext.mounted) {
                Navigator.of(dialogContext, rootNavigator: true).pop();
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDeep,
                ),
              ),
              content: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: false,
                textInputAction: TextInputAction.done,
                decoration: inputDecoration(
                  hint: label,
                  icon: Icons.add_circle_outline_rounded,
                ),
                onSubmitted: (_) async {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : closeDialog,
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                    final name = controller.text.trim();

                    if (name.isEmpty) {
                      showError("$label is required");
                      return;
                    }

                    focusNode.unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();

                    setDialogState(() => isSaving = true);

                    try {
                      final response = await ApiMethod.postRequest(
                        url: url,
                        headers: headers,
                        body: {"name": name},
                      );

                      if (response['statusCode'] == 200 ||
                          response['statusCode'] == 201) {
                        final data = response['data'];

                        await closeDialog();

                        await Future.delayed(
                          const Duration(milliseconds: 250),
                        );

                        await reload();

                        if (!mounted) return;

                        onCreated({
                          "id": data["id"],
                          "label": data["name"] ?? name,
                        });

                        if (mounted) setState(() {});

                        await saveDraft();
                      } else {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                        showError(response['data']?.toString() ?? "An error occurred");
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        setDialogState(() => isSaving = false);
                      }
                      showError(e.toString());
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Save",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    focusNode.dispose();
    controller.dispose();
  }

  Future<void> addSourceQuick() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Future.delayed(const Duration(milliseconds: 150));

    await quickAddMaster(
      title: "Add Source",
      label: "Source Name",
      url: "$baseUrl/masters/lead-sources",
      reload: fetchSources,
      onCreated: (item) {
        selectedSourceId = item["id"];
        selectedSourceName = item["label"];
      },
    );
  }


  Future<void> addCompetitorQuick() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Future.delayed(const Duration(milliseconds: 150));

    await quickAddMaster(
      title: "Add Competitor",
      label: "Competitor Name",
      url: "$baseUrl/masters/competitors",
      reload: fetchCompetitors,
      onCreated: (item) {
        final id = item["id"];
        if (id != null && !selectedCompetitorIds.contains(id)) {
          selectedCompetitorIds.add(id);
        }
      },
    );
  }

  void setEditValues() {
    final data = widget.leadData;
    if (data == null) return;
    selectedCustomerId = data["customer_id"];
    selectedCustomerName = data["customer_name"];
    selectedSourceId = data["source_id"];
    assignedToId = data["assigned_to"];
    assignedToName = data["assigned_to_name"];
    workingGroupId = data["working_group_id"];
    selectedPriority = data["priority"]?.toString() ?? "Medium";
    selectedStatus = data["status"]?.toString() ?? "Assigned";
    customerNameController.text = data["customer_name"]?.toString() ?? "";
    customerAddressController.text = data["customer_address"]?.toString() ?? "";
    departmentController.text = data["department"]?.toString() ?? "";
    contactPersonController.text = data["contact_person"]?.toString() ?? "";
    designationController.text = data["designation"]?.toString() ?? "";
    mobileController.text = data["mobile"]?.toString() ?? "";
    emailController.text = data["email"]?.toString() ?? "";
    leadTitleController.text = data["lead_title"]?.toString() ?? "";
    estValueController.text = data["est_value"]?.toString() ?? "";
    tenderRefController.text = data["tender_id_ref"]?.toString() ?? "";
    timelineController.text = data["timeline"]?.toString() ?? "";
    followUpController.text = data["follow_up"]?.toString() ?? "";
    productDescriptionController.text = data["product_description"]?.toString() ?? "";
    notesController.text = data["notes"]?.toString() ?? "";
    regionController.text = data["region"]?.toString() ?? "";
    branchController.text = data["branch"]?.toString() ?? "";
    selectedCompetitorIds = List<int>.from(data["competitor_ids"] ?? []);
    for (final row in productRows) row.dispose();
    productRows.clear();
    final products = data["products"] ?? [];
    if (products is List && products.isNotEmpty) {
      for (final p in products) {
        final row = ProductRowModel();
        row.productId = p["product_id"];
        row.productName = p["product_name"]?.toString() ?? "";
        row.quantityController.text = p["quantity"]?.toString() ?? "1";
        row.descriptionController.text = p["description"]?.toString() ?? "";
        row.oems.clear();
        final oems = p["oems"] ?? [];
        if (oems is List && oems.isNotEmpty) {
          for (final o in oems) {
            final oem = OemRowModel();
            oem.oemId = o["oem_id"];
            oem.oemName = o["oem_name"]?.toString() ?? "";
            row.oems.add(oem);
          }
        } else {
          row.oems.add(OemRowModel());
        }
        productRows.add(row);
      }
    } else {
      productRows.add(ProductRowModel());
    }
  }

  Map<String, dynamic> draftMap() => {
    "selectedCustomerId": selectedCustomerId,
    "selectedCustomerName": selectedCustomerName,
    "selectedSourceId": selectedSourceId,
    "selectedSourceName": selectedSourceName,
    "assignedToId": assignedToId,
    "assignedToName": assignedToName,
    "workingGroupId": workingGroupId,
    "selectedPriority": selectedPriority,
    "selectedStatus": selectedStatus,
    "selectedCompetitorIds": selectedCompetitorIds,
    "customerName": customerNameController.text,
    "customerAddress": customerAddressController.text,
    "department": departmentController.text,
    "contactPerson": contactPersonController.text,
    "designation": designationController.text,
    "mobile": mobileController.text,
    "email": emailController.text,
    "leadTitle": leadTitleController.text,
    "estValue": estValueController.text,
    "tenderRef": tenderRefController.text,
    "timeline": timelineController.text,
    "followUp": followUpController.text,
    "productDescription": productDescriptionController.text,
    "notes": notesController.text,
    "region": regionController.text,
    "branch": branchController.text,
    "products": productRows.map((e) => e.toJson()).toList(),
  };

  Future<void> saveDraft() async {
    if (widget.isEdit) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftKey, jsonEncode(draftMap()));
  }

  Future<void> loadDraft() async {
    if (widget.isEdit) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      selectedCustomerId = data["selectedCustomerId"];
      selectedCustomerName = data["selectedCustomerName"];
      selectedSourceId = data["selectedSourceId"];
      selectedSourceName = data["selectedSourceName"];
      assignedToId = data["assignedToId"];
      assignedToName = data["assignedToName"];
      workingGroupId = data["workingGroupId"];
      selectedPriority = data["selectedPriority"] ?? "Medium";
      selectedStatus = data["selectedStatus"] ?? "Assigned";
      selectedCompetitorIds = List<int>.from(data["selectedCompetitorIds"] ?? []);
      customerNameController.text = data["customerName"] ?? "";
      customerAddressController.text = data["customerAddress"] ?? "";
      departmentController.text = data["department"] ?? "";
      contactPersonController.text = data["contactPerson"] ?? "";
      designationController.text = data["designation"] ?? "";
      mobileController.text = data["mobile"] ?? "";
      emailController.text = data["email"] ?? "";
      leadTitleController.text = data["leadTitle"] ?? "";
      estValueController.text = data["estValue"] ?? "";
      tenderRefController.text = data["tenderRef"] ?? "";
      timelineController.text = data["timeline"] ?? "";
      followUpController.text = data["followUp"] ?? "";
      productDescriptionController.text = data["productDescription"] ?? "";
      notesController.text = data["notes"] ?? "";
      regionController.text = data["region"] ?? "";
      branchController.text = data["branch"] ?? "";
      final products = data["products"];
      for (final row in productRows) row.dispose();
      productRows.clear();
      if (products is List && products.isNotEmpty) {
        for (final item in products) {
          final row = ProductRowModel();
          row.fromJson(Map<String, dynamic>.from(item));
          productRows.add(row);
        }
      } else {
        productRows.add(ProductRowModel());
      }
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);
  }

  Future<void> pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryLight, onPrimary: Colors.white, onSurface: AppColors.primaryDeep),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text = "${picked.year}-${picked.month.toString().padLeft(2, "0")}-${picked.day.toString().padLeft(2, "0")}";
      await saveDraft();
    }
  }

  void addProductRow() {
    setState(() => productRows.add(ProductRowModel()));
    saveDraft();
  }

  void removeProductRow(int index) {
    if (productRows.length == 1) return;
    setState(() {
      productRows[index].dispose();
      productRows.removeAt(index);
    });
    saveDraft();
  }

  void addOemRow(int productIndex) {
    setState(() => productRows[productIndex].oems.add(OemRowModel()));
    saveDraft();
  }

  void removeOemRow(int productIndex, int oemIndex) {
    if (productRows[productIndex].oems.length == 1) return;
    setState(() => productRows[productIndex].oems.removeAt(oemIndex));
    saveDraft();
  }

  bool validateTab(int tab) {
    if (tab == 0) {
      if (selectedCustomerId == null) return _errorFalse("Please select customer account");
      if (customerNameController.text.trim().isEmpty) return _errorFalse("Customer name is required");
      if (customerAddressController.text.trim().isEmpty) return _errorFalse("Customer address is required");
      if (departmentController.text.trim().isEmpty) return _errorFalse("Department is required");
      if (contactPersonController.text.trim().isEmpty) return _errorFalse("Contact person is required");
      if (designationController.text.trim().isEmpty) return _errorFalse("Designation is required");
      final mobile = mobileController.text.replaceAll(RegExp(r"\D"), "");
      if (mobile.length != 10) return _errorFalse("Mobile number must be 10 digits");
      if (emailController.text.trim().isEmpty) return _errorFalse("Email is required");
    }
    if (tab == 1) {
      if (leadTitleController.text.trim().isEmpty) return _errorFalse("Lead title is required");
      if (selectedSourceId == null) return _errorFalse("Please select source");
      if (estValueController.text.trim().isEmpty) return _errorFalse("Estimated value is required");
      if (timelineController.text.trim().isEmpty) return _errorFalse("Timeline is required");
      if (followUpController.text.trim().isEmpty) return _errorFalse("Follow-up date is required");
      if (assignedToId == null) return _errorFalse("Please select assigned user");
    }
    return true;
  }

  bool _errorFalse(String message) {
    showError(message);
    return false;
  }

  bool validateForm() => validateTab(0) && validateTab(1);

  Future<void> saveNext() async {
    await saveDraft();
    if (!validateTab(currentTab)) return;
    if (currentTab < 2) {
      tabController.animateTo(currentTab + 1);
      setState(() => currentTab = currentTab + 1);
    } else {
      await createLead();
    }
  }

  Future<void> goPrevious() async {
    await saveDraft();
    if (currentTab > 0) {
      tabController.animateTo(currentTab - 1);
      setState(() => currentTab = currentTab - 1);
    }
  }

  Future<bool> confirmBack() async {
    if (widget.isEdit) return true;

    final shouldLeave = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Discard Draft",
      barrierColor: Colors.black.withOpacity(.40),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width > 600
                ? 400
                : MediaQuery.of(context).size.width * .90,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// ICON
                    Container(
                      height: 62,
                      width: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xffFEF2F2),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xffDC2626),
                        size: 32,
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// TITLE
                    const Text(
                      "Discard Lead Draft?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff0F172A),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// DESCRIPTION
                    Text(
                      "If you go back now, all entered values will be removed and the saved draft will be cleared permanently.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 26),

                    /// BUTTONS
                    Row(
                      children: [

                        /// STAY BUTTON
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                              const Size(double.infinity, 46),
                              side: const BorderSide(
                                color: Color(0xffCBD5E1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              "Stay",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff475569),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        /// DISCARD BUTTON
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.pop(context, true),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              "Discard",
                            ),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor:
                              const Color(0xffDC2626),
                              foregroundColor: Colors.white,
                              minimumSize:
                              const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
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
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return Transform.scale(
          scale: Tween<double>(
            begin: .92,
            end: 1,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ).value,
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );

    if (shouldLeave == true) {
      await clearDraft();
      return true;
    }

    return false;
  }

  Future<void> createLead() async {
    if (!validateForm()) return;
    setState(() => isLoading = true);
    try {
      final body = {
        "customer_id": selectedCustomerId,
        "customer_name": customerNameController.text.trim(),
        "customer_address": customerAddressController.text.trim(),
        "department": departmentController.text.trim(),
        "contact_person": contactPersonController.text.trim(),
        "designation": designationController.text.trim(),
        "mobile": mobileController.text.trim(),
        "email": emailController.text.trim(),
        "lead_title": leadTitleController.text.trim(),
        "source_id": selectedSourceId,
        "priority": selectedPriority,
        "status": selectedStatus,
        "est_value": double.tryParse(estValueController.text.trim()) ?? 0,
        "tender_id_ref": tenderRefController.text.trim(),
        "timeline": timelineController.text.trim(),
        "follow_up": followUpController.text.trim(),
        "product_description": productDescriptionController.text.trim(),
        "notes": notesController.text.trim(),
        "competitor_ids": selectedCompetitorIds,
        "assigned_to": assignedToId,
        "working_group_id": workingGroupId,
        "region": regionController.text.trim(),
        "branch": branchController.text.trim(),
        "products": productRows.where((p) => p.productId != null || p.productName.trim().isNotEmpty).map((p) {
          return {
            "product_id": p.productId,
            "product_name": p.productName,
            "quantity": int.tryParse(p.quantityController.text.trim()) ?? 1,
            "description": p.descriptionController.text.trim(),
            "oems": p.oems
                .where((o) => o.oemId != null || o.oemName.trim().isNotEmpty)
                .map((o) => {"oem_id": o.oemId, "oem_name": o.oemName})
                .toList(),
          };
        }).toList(),
      };
      final url = widget.isEdit ? "$baseUrl/leads/${widget.leadData!["id"]}" : "$baseUrl/leads";
      final response = widget.isEdit
          ? await ApiMethod.putRequest(url: url, headers: headers, body: body)
          : await ApiMethod.postRequest(url: url, headers: headers, body: body);

      setState(() => isLoading = false);
      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        await clearDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEdit ? "Lead Updated Successfully" : "Lead Created Successfully"),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      } else {
        showError(response['data']?.toString() ?? "An error occurred");
      }
    } catch (e) {
      setState(() => isLoading = false);
      showError(e.toString());
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  Widget pageHeader() {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: const BoxDecoration(gradient: AppColors.headerGradient),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      final canLeave = await confirmBack();
                      if (canLeave && mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(widget.isEdit ? "Edit Lead" : "Create Lead", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  if (!widget.isEdit)
                    TextButton.icon(
                      onPressed: clearDraftAndFields,
                      icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white, size: 17),
                      label: const Text("Clear", style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            professionalStepTabs(),
          ],
        ),
      ),
    );
  }

  Future<void> clearDraftAndFields() async {
    await clearDraft();
    setState(() {
      selectedCustomerId = null;
      selectedCustomerName = null;
      selectedSourceId = null;
      selectedSourceName = null;
      assignedToId = users.isNotEmpty ? users.first["id"] : null;
      assignedToName = users.isNotEmpty ? users.first["label"] : null;
      workingGroupId = null;
      selectedPriority = "Medium";
      selectedStatus = "Assigned";
      selectedCompetitorIds.clear();
      customerNameController.clear();
      customerAddressController.clear();
      departmentController.clear();
      contactPersonController.clear();
      designationController.clear();
      mobileController.clear();
      emailController.clear();
      leadTitleController.clear();
      estValueController.clear();
      tenderRefController.clear();
      timelineController.clear();
      followUpController.clear();
      productDescriptionController.clear();
      notesController.clear();
      regionController.clear();
      branchController.clear();
      for (final row in productRows) row.dispose();
      productRows = [ProductRowModel()];
      currentTab = 0;
      tabController.animateTo(0);
    });
  }

  Widget professionalStepTabs() {
    final steps = ["Customer", "Lead Info", "More"];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: const Color(0xffD9F1E2).withOpacity(0.75), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: List.generate(steps.length, (index) {
          final active = currentTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                if (index > currentTab) {
                  if (currentTab == 0 && !validateTab(0)) return;
                  if (currentTab == 1 && !validateTab(1)) return;
                }
                await saveDraft();
                setState(() {
                  currentTab = index;
                  tabController.animateTo(index);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: active ? AppColors.primaryLight : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Text(steps[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : AppColors.primaryMedium, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget sectionCard({required String title, required IconData icon, String? subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withOpacity(.06), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(height: 38, width: 38, decoration: BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: AppColors.primaryDeep, fontSize: 16, fontWeight: FontWeight.w900)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xff64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }

  Widget fieldLabel(String label, bool requiredField) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: AppColors.primarySlate, fontWeight: FontWeight.w800, fontSize: 13),
        children: [if (requiredField) const TextSpan(text: " *", style: TextStyle(color: Colors.red))],
      ),
    );
  }

  InputDecoration inputDecoration({String? hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 19, color: AppColors.primarySlate.withOpacity(.65)),
      filled: true,
      fillColor: const Color(0xffF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xffE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red)),
    );
  }

  Widget appTextField({required String label, required TextEditingController controller, bool requiredField = false, TextInputType keyboardType = TextInputType.text, int maxLines = 1, bool readOnly = false, VoidCallback? onTap, IconData? icon, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      fieldLabel(label, requiredField),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: (_) => saveDraft(),
        validator: requiredField ? (value) => value == null || value.trim().isEmpty ? "Required" : null : null,
        decoration: inputDecoration(hint: hint, icon: icon),
      ),
    ]);
  }

  Widget mapDropdown({required String label, required int? value, required List<Map<String, dynamic>> items, required Function(Map<String, dynamic>?) onChanged, bool requiredField = false, String hint = "Select", IconData? icon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      fieldLabel(label, requiredField),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value: value,
        isExpanded: true,
        decoration: inputDecoration(hint: hint, icon: icon),
        validator: requiredField ? (value) => value == null ? "Required" : null : null,
        items: items.map((item) => DropdownMenuItem<int>(value: item["id"], child: Text(item["label"]?.toString() ?? "", overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (id) async {
          final selected = items.where((e) => e["id"] == id).cast<Map<String, dynamic>?>().firstOrNull;
          onChanged(selected);
          await saveDraft();
        },
      ),
    ]);
  }

  Widget stringDropdown({required String label, required String value, required List<String> items, required Function(String?) onChanged, bool requiredField = false, IconData? icon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      fieldLabel(label, requiredField),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: inputDecoration(icon: icon),
        items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
        onChanged: (value) async {
          onChanged(value);
          await saveDraft();
        },
      ),
    ]);
  }

  Widget rowTwo(Widget first, Widget second) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 560) return Column(children: [first, const SizedBox(height: 14), second]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: first), const SizedBox(width: 14), Expanded(child: second)]);
    });
  }

  Widget addButton({required VoidCallback onTap}) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add, size: 15),
      label: const Text("+Add"),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: EdgeInsets.zero,
        minimumSize: const Size(54, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget sourceDropdownWithAdd() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: fieldLabel("Source", true)), addButton(onTap: addSourceQuick)]),
      const SizedBox(height: 8),
      DropdownButtonFormField<int>(
        value: selectedSourceId,
        isExpanded: true,
        decoration: inputDecoration(hint: "Select source", icon: Icons.campaign_outlined),
        validator: (value) => value == null ? "Required" : null,
        items: sources.map((item) => DropdownMenuItem<int>(value: item["id"], child: Text(item["label"]?.toString() ?? "", overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (id) async {
          final selected = sources.where((e) => e["id"] == id).cast<Map<String, dynamic>?>().firstOrNull;
          setState(() {
            selectedSourceId = selected?["id"];
            selectedSourceName = selected?["label"];
          });
          await saveDraft();
        },
      ),
    ]);
  }

  Widget customerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(children: [
        sectionCard(
          title: "Customer",
          icon: Icons.business_rounded,
          subtitle: "Select account and billing location",
          child: Column(children: [
            mapDropdown(
              label: "Customer Account",
              value: selectedCustomerId,
              items: customers,
              requiredField: true,
              hint: "Select customer",
              icon: Icons.apartment_rounded,
              onChanged: (selected) {
                setState(() {
                  selectedCustomerId = selected?["id"];
                  selectedCustomerName = selected?["label"];
                });
                if (selectedCustomerId != null) fetchCustomerActiveContact(selectedCustomerId!);
              },
            ),
            const SizedBox(height: 14),
            appTextField(label: "Customer Name", controller: customerNameController, requiredField: true, icon: Icons.badge_rounded),
            const SizedBox(height: 14),
            appTextField(label: "Customer Address", controller: customerAddressController, requiredField: true, icon: Icons.location_on_outlined, maxLines: 2),
          ]),
        ),
        sectionCard(
          title: "Contact Details",
          icon: Icons.contacts_rounded,
          subtitle: "Auto-filled from active primary contact",
          child: Column(children: [
            rowTwo(
              appTextField(label: "Department", controller: departmentController, requiredField: true, icon: Icons.account_tree_outlined),
              appTextField(label: "Contact Person", controller: contactPersonController, requiredField: true, icon: Icons.person_outline_rounded),
            ),
            const SizedBox(height: 14),
            rowTwo(
              appTextField(label: "Designation", controller: designationController, requiredField: true, icon: Icons.work_outline_rounded),
              appTextField(label: "Mobile", controller: mobileController, requiredField: true, keyboardType: TextInputType.phone, icon: Icons.phone_android_rounded),
            ),
            const SizedBox(height: 14),
            appTextField(label: "Email", controller: emailController, requiredField: true, keyboardType: TextInputType.emailAddress, icon: Icons.email_outlined),
          ]),
        ),
      ]),
    );
  }

  Widget leadInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(children: [
        sectionCard(
          title: "Lead Information",
          icon: Icons.track_changes_rounded,
          subtitle: "Lead title, source, value and ownership",
          child: Column(children: [
            appTextField(label: "Lead Name / Title", controller: leadTitleController, requiredField: true, icon: Icons.title_rounded),
            const SizedBox(height: 14),
            rowTwo(
              sourceDropdownWithAdd(),
              stringDropdown(label: "Priority", value: selectedPriority, items: priorities, requiredField: true, icon: Icons.flag_outlined, onChanged: (value) => setState(() => selectedPriority = value!)),
            ),
            const SizedBox(height: 14),
            rowTwo(
              appTextField(label: "Estimated Value", controller: estValueController, requiredField: true, keyboardType: TextInputType.number, icon: Icons.currency_rupee_rounded),
              appTextField(label: "Tender ID Reference", controller: tenderRefController, icon: Icons.numbers_rounded),
            ),
            const SizedBox(height: 14),
            rowTwo(
              appTextField(label: "Timeline", controller: timelineController, requiredField: true, readOnly: true, icon: Icons.calendar_month_outlined, onTap: () => pickDate(timelineController)),
              appTextField(label: "Follow-up Date", controller: followUpController, requiredField: true, readOnly: true, icon: Icons.event_available_outlined, onTap: () => pickDate(followUpController)),
            ),
            const SizedBox(height: 14),
            mapDropdown(
              label: "Assigned To",
              value: assignedToId,
              items: users,
              requiredField: true,
              hint: "Select user",
              icon: Icons.assignment_ind_outlined,
              onChanged: (selected) => setState(() {
                assignedToId = selected?["id"];
                assignedToName = selected?["label"];
              }),
            ),
            const SizedBox(height: 14),
            rowTwo(
              stringDropdown(label: "Status", value: selectedStatus, items: statuses, icon: Icons.sync_alt_rounded, onChanged: (value) => setState(() => selectedStatus = value!)),
              appTextField(label: "Region", controller: regionController, icon: Icons.public_rounded),
            ),
            const SizedBox(height: 14),
            appTextField(label: "Branch", controller: branchController, icon: Icons.account_balance_rounded),
          ]),
        ),
      ]),
    );
  }

  Widget competitorMultiSelect() {
    final selectedNames = competitors.where((e) => selectedCompetitorIds.contains(e["id"])).map((e) => e["label"].toString()).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: fieldLabel("Competitors", false)), addButton(onTap: addCompetitorQuick)]),
      const SizedBox(height: 8),
      InkWell(
        onTap: openCompetitorDialog,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xffF8FAFC), border: Border.all(color: const Color(0xffE2E8F0)), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            const Icon(Icons.groups_2_outlined, color: AppColors.primarySlate, size: 19),
            const SizedBox(width: 10),
            Expanded(child: Text(selectedNames.isEmpty ? "Select competitors" : selectedNames.join(", "), style: TextStyle(color: selectedNames.isEmpty ? const Color(0xff94A3B8) : AppColors.primaryDeep, fontWeight: FontWeight.w700))),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ]),
        ),
      ),
    ]);
  }

  void openCompetitorDialog() {
    final tempIds = List<int>.from(selectedCompetitorIds);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Select Competitors", style: TextStyle(color: AppColors.primaryDeep, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: double.maxFinite,
            child: competitors.isEmpty
                ? const Text("No competitors found")
                : ListView.builder(
              shrinkWrap: true,
              itemCount: competitors.length,
              itemBuilder: (context, index) {
                final item = competitors[index];
                final id = item["id"];
                return CheckboxListTile(
                  value: tempIds.contains(id),
                  activeColor: AppColors.primaryLight,
                  title: Text(item["label"]),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        tempIds.add(id);
                      } else {
                        tempIds.remove(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                setState(() => selectedCompetitorIds = tempIds);
                await saveDraft();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Done", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget productSection() {
    return Column(children: [
      ...List.generate(productRows.length, (index) {
        final row = productRows[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xffF8FAFC), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.primaryLight.withOpacity(.20))),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
                child: Text("Product ${index + 1}", style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const Spacer(),
              if (productRows.length > 1) IconButton(onPressed: () => removeProductRow(index), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
            ]),
            const SizedBox(height: 12),
            rowTwo(
              mapDropdown(
                label: "Product",
                value: row.productId,
                items: productsMaster,
                hint: "Select product",
                icon: Icons.inventory_2_outlined,
                onChanged: (selected) => setState(() {
                  row.productId = selected?["id"];
                  row.productName = selected?["label"] ?? "";
                }),
              ),
              appTextField(label: "Quantity", controller: row.quantityController, keyboardType: TextInputType.number, icon: Icons.format_list_numbered_rounded),
            ),
            const SizedBox(height: 14),
            appTextField(label: "Product Description", controller: row.descriptionController, icon: Icons.description_outlined),
            const SizedBox(height: 14),
            Row(children: [
              const Text("OEM / Vendors", style: TextStyle(color: AppColors.primarySlate, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton.icon(onPressed: () => addOemRow(index), icon: const Icon(Icons.add_circle_outline_rounded, size: 16), label: const Text("Add OEM")),
            ]),
            ...List.generate(row.oems.length, (oemIndex) {
              final oem = row.oems[oemIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(
                    child: mapDropdown(
                      label: "OEM",
                      value: oem.oemId,
                      items: oemsMaster,
                      hint: "Select OEM",
                      icon: Icons.factory_outlined,
                      onChanged: (selected) => setState(() {
                        oem.oemId = selected?["id"];
                        oem.oemName = selected?["label"] ?? "";
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (row.oems.length > 1) IconButton(onPressed: () => removeOemRow(index, oemIndex), icon: const Icon(Icons.close_rounded, color: Colors.red)),
                ]),
              );
            }),
          ]),
        );
      }),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: addProductRow,
          icon: const Icon(Icons.add_rounded),
          label: const Text("Add Another Product"),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryLight, side: const BorderSide(color: AppColors.primaryLight), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ),
      ),
    ]);
  }

  Widget moreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        children: [
          sectionCard(
            title: "Competitors",
            icon: Icons.groups_2_rounded,
            subtitle: "Select known competitors for this lead",
            child: competitorMultiSelect(),
          ),
          sectionCard(
            title: "Description & Notes",
            icon: Icons.notes_rounded,
            subtitle: "Qualification notes and internal remarks",
            child: Column(
              children: [
                appTextField(
                  label: "Product / Description",
                  controller: productDescriptionController,
                  maxLines: 4,
                  icon: Icons.description_outlined,
                ),
                const SizedBox(height: 14),
                appTextField(
                  label: "Internal Notes",
                  controller: notesController,
                  maxLines: 4,
                  icon: Icons.sticky_note_2_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: AppColors.primaryDeep.withOpacity(.10), blurRadius: 18, offset: const Offset(0, -6))], borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (currentTab > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : goPrevious,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text("Previous"),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.primarySlate, padding: const EdgeInsets.symmetric(vertical: 15), side: const BorderSide(color: Color(0xffCBD5E1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          if (currentTab > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : saveNext,
              icon: isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(currentTab == 2 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded),
              label: Text(currentTab == 2 ? (widget.isEdit ? "Submit Update" : "Submit") : "Save Next"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0, textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canLeave = await confirmBack();
        if (canLeave && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF3F6FA),
        body: isMasterLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
            : Form(
          key: _formKey,
          child: Column(children: [
            pageHeader(),
            Expanded(
              child: TabBarView(
                controller: tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [customerTab(), leadInfoTab(),  moreTab()],
              ),
            ),
            bottomBar(),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    customerNameController.dispose();
    customerAddressController.dispose();
    departmentController.dispose();
    contactPersonController.dispose();
    designationController.dispose();
    mobileController.dispose();
    emailController.dispose();
    leadTitleController.dispose();
    estValueController.dispose();
    tenderRefController.dispose();
    timelineController.dispose();
    followUpController.dispose();
    productDescriptionController.dispose();
    notesController.dispose();
    regionController.dispose();
    branchController.dispose();
    for (final row in productRows) row.dispose();
    super.dispose();
  }
}
