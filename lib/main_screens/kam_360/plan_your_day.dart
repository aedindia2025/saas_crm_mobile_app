import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PlanYourDayPage extends StatefulWidget {
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> teamMembers;
  final String baseUrl;
  final String token;

  const PlanYourDayPage({
    super.key,
    required this.customers,
    required this.teamMembers,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<PlanYourDayPage> createState() => _PlanYourDayPageState();
}

class PlanRowModel {
  int? customerId;
  String? customerName;
  int? onBehalfOf;
  String activityType = "Phone Call";
  final subjectController = TextEditingController();

  void dispose() {
    subjectController.dispose();
  }
}

class _PlanYourDayPageState extends State<PlanYourDayPage> {
  bool isSaving = false;

  DateTime selectedDate = DateTime.now();
  int? assignAllTo;

  final List<PlanRowModel> rows = [
    PlanRowModel(),
    PlanRowModel(),
  ];

  final List<String> activityTypes = const [
    "Phone Call",
    "Video Call",
    "In Person Meet",
    "Demo",
    "Site Visit",
    "Follow Up",
    "Email",
  ];

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${widget.token}',
    'X-Tenant-Slug': 'ascent',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  String get selectedDateText {
    return "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  void addRow() {
    setState(() {
      rows.add(PlanRowModel());
    });
  }

  void removeRow(int index) {
    if (rows.length == 1) return;

    setState(() {
      rows[index].dispose();
      rows.removeAt(index);
    });
  }

  void applyAssignToAll() {
    setState(() {
      for (final row in rows) {
        row.onBehalfOf = assignAllTo;
      }
    });
  }

  List<PlanRowModel> get validRows {
    return rows.where((row) {
      return row.customerId != null &&
          row.subjectController.text.trim().isNotEmpty;
    }).toList();
  }

  Future<void> savePlan() async {
    if (validRows.isEmpty) {
      showError("Fill customer and subject to plan");
      return;
    }

    setState(() => isSaving = true);

    try {
      final body = validRows.map((row) {
        return {
          "activity_type": row.activityType,
          "customer_id": row.customerId,
          "subject": row.subjectController.text.trim(),
          "activity_date": selectedDateText,
          "mode": modeForActivity(row.activityType),
          "on_behalf_of": row.onBehalfOf,
        };
      }).toList();

      final response = await http.post(
        Uri.parse("${widget.baseUrl}/kam/activities/bulk"),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint("PLAN DAY BODY => ${jsonEncode(body)}");
      debugPrint("PLAN DAY STATUS => ${response.statusCode}");
      debugPrint("PLAN DAY RESPONSE => ${response.body}");

      setState(() => isSaving = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Activities planned successfully"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        showError(response.body);
      }
    } catch (e) {
      setState(() => isSaving = false);
      showError(e.toString());
    }
  }

  String modeForActivity(String type) {
    switch (type) {
      case "Phone Call":
        return "Phone";
      case "Video Call":
        return "Video Call";
      case "Email":
        return "Email";
      case "In Person Meet":
      case "Demo":
      case "Site Visit":
        return "In-Person";
      case "Follow Up":
        return "Phone";
      default:
        return "Phone";
    }
  }

  Color typeColor(String type) {
    switch (type) {
      case "Phone Call":
        return const Color(0xff2563EB);
      case "Video Call":
        return const Color(0xff0891B2);
      case "In Person Meet":
        return const Color(0xff7C3AED);
      case "Demo":
        return const Color(0xff059669);
      case "Site Visit":
        return const Color(0xffEA580C);
      case "Follow Up":
        return const Color(0xffD97706);
      case "Email":
        return const Color(0xff64748B);
      default:
        return const Color(0xff475569);
    }
  }

  IconData typeIcon(String type) {
    switch (type) {
      case "Phone Call":
        return Icons.phone_outlined;
      case "Video Call":
        return Icons.videocam_outlined;
      case "In Person Meet":
        return Icons.handshake_outlined;
      case "Demo":
        return Icons.desktop_windows_outlined;
      case "Site Visit":
        return Icons.near_me_outlined;
      case "Follow Up":
        return Icons.repeat;
      case "Email":
        return Icons.email_outlined;
      default:
        return Icons.task_alt;
    }
  }

  InputDecoration inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xffCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff2563EB)),
      ),
    );
  }

  Widget typeButton(PlanRowModel row, String type) {
    final selected = row.activityType == type;
    final color = typeColor(type);

    return InkWell(
      onTap: () {
        setState(() {
          row.activityType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.10) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withOpacity(.45) : const Color(0xffCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              typeIcon(type),
              size: 14,
              color: selected ? color : const Color(0xff94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              type,
              style: TextStyle(
                color: selected ? color : const Color(0xff64748B),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget planRow(int index) {
    final row = rows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffCBD5E1),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xffF1F5F9),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: Color(0xff64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: addRow,
                icon: const Icon(Icons.add, size: 18),
              ),
              IconButton(
                onPressed: rows.length == 1 ? null : () => removeRow(index),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: activityTypes.map((e) => typeButton(row, e)).toList(),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<int>(
            value: row.customerId,
            isExpanded: true,
            decoration: inputDecoration(hint: "Customer *"),
            items: widget.customers.map((customer) {
              return DropdownMenuItem<int>(
                value: customer['id'],
                child: Text(
                  customer['customer_name']?.toString() ??
                      customer['name']?.toString() ??
                      "",
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              final selected = widget.customers.firstWhere(
                    (e) => e['id'] == value,
                orElse: () => {},
              );

              setState(() {
                row.customerId = value;
                row.customerName = selected['customer_name']?.toString() ??
                    selected['name']?.toString();
              });
            },
          ),

          const SizedBox(height: 12),

          TextFormField(
            controller: row.subjectController,
            decoration: inputDecoration(hint: "Subject / purpose *"),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<int?>(
            value: row.onBehalfOf,
            isExpanded: true,
            decoration: inputDecoration(hint: "Assign to"),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text("Myself"),
              ),
              ...widget.teamMembers.map((member) {
                return DropdownMenuItem<int?>(
                  value: member['id'],
                  child: Text(
                    member['full_name']?.toString() ??
                        member['user_name']?.toString() ??
                        "",
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                row.onBehalfOf = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget headerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Plan Date",
            style: TextStyle(
              color: Color(0xff64748B),
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xffCBD5E1)),
              ),
              child: Row(
                children: [
                  Text(
                    selectedDateText,
                    style: const TextStyle(
                      color: Color(0xff0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_month_outlined, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Assign All To",
            style: TextStyle(
              color: Color(0xff64748B),
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: assignAllTo,
                  isExpanded: true,
                  decoration: inputDecoration(hint: "Myself"),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Myself (default)"),
                    ),
                    ...widget.teamMembers.map((member) {
                      return DropdownMenuItem<int?>(
                        value: member['id'],
                        child: Text(
                          member['full_name']?.toString() ??
                              member['user_name']?.toString() ??
                              "",
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      assignAllTo = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: applyAssignToAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffEFF6FF),
                  foregroundColor: const Color(0xff2563EB),
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Apply"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "${widget.customers.length} customers · ${validRows.length} of ${rows.length} rows ready",
            style: const TextStyle(
              color: Color(0xff94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Plan Your Day",
              style: TextStyle(
                color: Color(0xff0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "Schedule multiple activities at once",
              style: TextStyle(
                color: Color(0xff64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                headerCard(),
                const SizedBox(height: 16),
                ...List.generate(rows.length, planRow),
                OutlinedButton.icon(
                  onPressed: addRow,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Another Activity"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xff64748B),
                    side: const BorderSide(color: Color(0xffCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xffE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    validRows.isEmpty
                        ? "Fill customer + subject to plan"
                        : "${validRows.length} activities ready",
                    style: TextStyle(
                      color: validRows.isEmpty
                          ? const Color(0xff94A3B8)
                          : const Color(0xff059669),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: isSaving ? null : savePlan,
                  icon: isSaving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.calendar_month, size: 17),
                  label: Text(
                    validRows.length > 1
                        ? "Plan ${validRows.length} Activities"
                        : "Plan Activity",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
}