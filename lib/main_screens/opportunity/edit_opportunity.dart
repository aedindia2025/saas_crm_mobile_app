import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_helpers/api_method.dart';

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

class EditOpportunity extends StatefulWidget {
  final Map<String, dynamic> opportunityData;
  final String tenantSlug;

  const EditOpportunity({
    super.key,
    required this.opportunityData,
    required this.tenantSlug,
  });

  @override
  State<EditOpportunity> createState() => _EditOpportunityState();
}

class ProductRowModel {
  int? productId;
  String productName = "";
  final quantityController = TextEditingController(text: "1");
  final descriptionController = TextEditingController();
  List<OemRowModel> oems = [OemRowModel()];

  void dispose() {
    quantityController.dispose();
    descriptionController.dispose();
  }
}

class OemRowModel {
  int? oemId;
  String oemName = "";
}

class _EditOpportunityState extends State<EditOpportunity> {
  bool isLoading = false;
  bool isMasterLoading = true;

  String? token;

  List<Map<String, dynamic>> productsMaster = [];
  List<Map<String, dynamic>> oemsMaster = [];
  List<ProductRowModel> productRows = [];
  final newOemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer $token',
    'X-Tenant-Slug': widget.tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');

    if (token != null) {
      await Future.wait([
        fetchProducts(),
        fetchOems(),
      ]);
    }

    setEditValues();

    if (mounted) setState(() => isMasterLoading = false);
  }

  Future<List> getApiList(String url) async {
    final response = await ApiMethod.getRequest(url: url, headers: headers);

    if (response['statusCode'] == 200) {
      return response['data'] ?? [];
    }

    return [];
  }

  Future<void> fetchProducts() async {
    final res = await getApiList(
      "http://103.110.236.187:3076/api/v1/masters/products",
    );

    productsMaster = res
        .map((e) => {
      "id": e["id"],
      "label": e["name"],
    })
        .where((e) => e["label"] != null)
        .toList();
  }

  Future<void> fetchOems() async {
    final res = await getApiList(
      "http://103.110.236.187:3076/api/v1/masters/oems",
    );

    oemsMaster = res
        .map((e) => {
      "id": e["id"],
      "label": e["name"],
    })
        .where((e) => e["label"] != null)
        .toList();
  }

  void setEditValues() {
    final products = widget.opportunityData['products'] ?? [];

    productRows.clear();

    if (products.isNotEmpty) {
      for (final p in products) {
        final row = ProductRowModel();

        row.productId = p['product_id'];
        row.productName = p['product_name']?.toString() ?? "";
        row.quantityController.text = p['quantity']?.toString() ?? "1";
        row.descriptionController.text = p['description']?.toString() ?? "";

        row.oems.clear();

        final oems = p['oems'] ?? [];

        if (oems.isNotEmpty) {
          for (final o in oems) {
            final oem = OemRowModel();
            oem.oemId = o['oem_id'];
            oem.oemName = o['oem_name']?.toString() ?? "";
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

  void addProductRow() {
    setState(() {
      productRows.add(ProductRowModel());
    });
  }

  void removeProductRow(int index) {
    if (productRows.length == 1) return;

    setState(() {
      productRows[index].dispose();
      productRows.removeAt(index);
    });
  }

  void addOemRow(int productIndex) {
    setState(() {
      productRows[productIndex].oems.add(OemRowModel());
    });
  }

  void removeOemRow(int productIndex, int oemIndex) {
    if (productRows[productIndex].oems.length == 1) return;

    setState(() {
      productRows[productIndex].oems.removeAt(oemIndex);
    });
  }

  Future<void> updateOpportunity() async {
    final validProducts = productRows
        .where((p) => p.productId != null || p.productName.trim().isNotEmpty)
        .toList();

    if (validProducts.isEmpty) {
      showError("Please add at least one product");
      return;
    }

    setState(() => isLoading = true);

    try {
      final body = {
        "customer_id": widget.opportunityData["customer_id"],
        "customer_name": widget.opportunityData["customer_name"],
        "customer_address": widget.opportunityData["customer_address"],
        "department": widget.opportunityData["department"],
        "contact_person": widget.opportunityData["contact_person"],
        "designation": widget.opportunityData["designation"],
        "mobile": widget.opportunityData["mobile"],
        "email": widget.opportunityData["email"],
        "lead_title": widget.opportunityData["lead_title"],
        "source_id": widget.opportunityData["source_id"],
        "priority": widget.opportunityData["priority"] ?? "Medium",
        "status": widget.opportunityData["status"],
        "est_value": double.tryParse(
          widget.opportunityData["est_value"]?.toString() ?? "0",
        ) ??
            0,
        "tender_id_ref": widget.opportunityData["tender_id_ref"],
        "timeline": widget.opportunityData["timeline"],
        "follow_up": widget.opportunityData["follow_up"],
        "product_description": widget.opportunityData["product_description"],
        "notes": widget.opportunityData["notes"],
        "competitor_ids": widget.opportunityData["competitor_ids"] ?? [],
        "assigned_to": widget.opportunityData["assigned_to"],
        "working_group_id": widget.opportunityData["working_group_id"],
        "products": validProducts.map((p) {
          return {
            "product_id": p.productId,
            "product_name": p.productName.trim(),
            "quantity": int.tryParse(p.quantityController.text.trim()) ?? 1,
            "description": p.descriptionController.text.trim().isEmpty
                ? null
                : p.descriptionController.text.trim(),
            "oems": p.oems
                .where((o) => o.oemId != null || o.oemName.trim().isNotEmpty)
                .map((o) => {
              "oem_id": o.oemId,
              "oem_name": o.oemName.trim(),
            })
                .toList(),
          };
        }).toList(),
      };

      final url =
          "http://103.110.236.187:3076/api/v1/leads/${widget.opportunityData['id']}";

      final response = await ApiMethod.putRequest(
        url: url,
        headers: headers,
        body: body,
      );

      if (mounted) setState(() => isLoading = false);

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Opportunity Updated Successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context, true);
      } else {
        showError(response['data']?.toString() ?? "Update failed");
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      showError(e.toString());
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String safeText(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String formatCurrency(dynamic raw) {
    final value = double.tryParse((raw ?? 0).toString()) ?? 0;
    if (value >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  InputDecoration inputDecoration({String? hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xff94A3B8), fontSize: 13),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.primarySlate.withOpacity(.68), size: 19),
      filled: true,
      fillColor: const Color(0xffF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xffE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4),
      ),
    );
  }

  Widget label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.primarySlate,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    );
  }

  Widget mapDropdown({
    required int? value,
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>?) onChanged,
    String hint = "Select",
    IconData? icon,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: inputDecoration(hint: hint, icon: icon),
      items: items.map((item) {
        return DropdownMenuItem<int>(
          value: item["id"],
          child: Text(
            item["label"]?.toString() ?? "",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
      onChanged: (id) {
        final selected = items.where((e) => e["id"] == id).toList();
        onChanged(selected.isEmpty ? null : selected.first);
      },
    );
  }

  Widget header() {
    final title = safeText(widget.opportunityData['lead_title'], 'Edit Opportunity');
    final customer = safeText(widget.opportunityData['customer_name'], '');
    final value = formatCurrency(widget.opportunityData['est_value']);

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: isLoading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Opportunity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.16)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
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
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sectionHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products & OEM Details',
                  style: TextStyle(
                    color: AppColors.primaryDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Capture products, quantities, descriptions and OEM/vendors',
                  style: TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget productCard(int index) {
    final row = productRows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: AppColors.primaryDeep.withOpacity(.035),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: const Border(bottom: BorderSide(color: Color(0xffE8ECF0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Product ${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (productRows.length > 1)
                  IconButton(
                    tooltip: 'Remove product',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => removeProductRow(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 520;
                    final productField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Product'),
                        const SizedBox(height: 8),
                        mapDropdown(
                          value: row.productId,
                          items: productsMaster,
                          hint: 'Select product',
                          icon: Icons.inventory_2_outlined,
                          onChanged: (selected) {
                            setState(() {
                              row.productId = selected?["id"];
                              row.productName = selected?["label"] ?? "";
                            });
                          },
                        ),
                      ],
                    );
                    final qtyField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('Quantity'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: row.quantityController,
                          keyboardType: TextInputType.number,
                          decoration: inputDecoration(
                            hint: 'Qty',
                            icon: Icons.format_list_numbered_rounded,
                          ),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          productField,
                          const SizedBox(height: 14),
                          qtyField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: productField),
                        const SizedBox(width: 14),
                        SizedBox(width: 150, child: qtyField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                label('Description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: row.descriptionController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: inputDecoration(
                    hint: 'Specification or notes',
                    icon: Icons.description_outlined,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primarySlate.withOpacity(.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.factory_outlined,
                        size: 17,
                        color: AppColors.primarySlate,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'OEM / Vendors',
                        style: TextStyle(
                          color: AppColors.primarySlate,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: openAddOemDialog,
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add Master'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(row.oems.length, (oemIndex) {
                  final oem = row.oems[oemIndex];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xffE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: mapDropdown(
                            value: oem.oemId,
                            items: oemsMaster,
                            hint: 'Select OEM / Vendor',
                            icon: Icons.factory_outlined,
                            onChanged: (selected) {
                              setState(() {
                                oem.oemId = selected?["id"];
                                oem.oemName = selected?["label"] ?? "";
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (row.oems.length > 1)
                          IconButton(
                            tooltip: 'Remove OEM',
                            onPressed: () => removeOemRow(index, oemIndex),
                            icon: const Icon(Icons.close_rounded, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                }),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => addOemRow(index),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                    label: const Text('Add OEM Row'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: BorderSide(color: AppColors.primaryLight.withOpacity(.55)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void openAddOemDialog() {
    newOemController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          title: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.factory_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Add OEM / Vendor',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  text: 'OEM Name',
                  style: TextStyle(
                    color: AppColors.primarySlate,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newOemController,
                decoration: inputDecoration(
                  hint: 'Enter OEM / Vendor name',
                  icon: Icons.factory_outlined,
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saveNewOem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> saveNewOem() async {
    final name = newOemController.text.trim();

    if (name.isEmpty) {
      showError("Please enter OEM name");
      return;
    }

    try {
      final response = await ApiMethod.postRequest(
        url: "http://103.110.236.187:3076/api/v1/masters/oems",
        headers: headers,
        body: {"name": name},
      );

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        final data = response['data'];

        final newOem = {
          "id": data["id"],
          "label": data["name"] ?? name,
        };

        setState(() {
          oemsMaster.add(newOem);
        });

        if (mounted) Navigator.pop(context);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OEM / Vendor added successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        showError(response['data']?.toString() ?? "Failed to add OEM");
      }
    } catch (e) {
      showError(e.toString());
    }
  }

  Widget addProductButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: addProductRow,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Another Product'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.primaryLight),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primarySlate,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Color(0xffCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : updateOpportunity,
                icon: isLoading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Update Opportunity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
    return Scaffold(
      backgroundColor: const Color(0xffF3F6FA),
      body: isMasterLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
          : Column(
        children: [
          header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
              child: Column(
                children: [
                  sectionHeader(),
                  const SizedBox(height: 16),
                  ...List.generate(productRows.length, productCard),
                  addProductButton(),
                ],
              ),
            ),
          ),
          bottomBar(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    newOemController.dispose();

    for (final row in productRows) {
      row.dispose();
    }
    super.dispose();
  }
}
