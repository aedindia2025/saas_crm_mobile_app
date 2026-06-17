import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../api_helpers/api_method.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryDeep = Color(0xFF102040);
  static const Color primaryMedium = Color(0xFF204070);
  static const Color primarySlate = Color(0xFF304050);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF94A3B8);
  static const Color text = Color(0xFF0F172A);
  static const Color purple = Color(0xFF9333EA);
}

class SelectOption {
  final int value;
  final String label;
  final String? subtitle;
  final String? approvalStatus;

  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.approvalStatus,
  });
}

class OemEntry {
  int? oemId;
  String oemName;

  OemEntry({this.oemId, this.oemName = ''});

  Map<String, dynamic> toJson() => {
    'oem_id': oemId,
    'oem_name': oemName,
  };
}

class ProductEntry {
  int? productId;
  String productName;
  String quantity;
  String description;
  List<OemEntry> oems;

  ProductEntry({
    this.productId,
    this.productName = '',
    this.quantity = '1',
    this.description = '',
    List<OemEntry>? oems,
  }) : oems = oems ?? [OemEntry()];

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': double.tryParse(quantity.trim()) ?? 1,
    'description': description,
    'oems': oems
        .where((o) => o.oemName.trim().isNotEmpty)
        .map((o) => o.toJson())
        .toList(),
  };
}

class NewOpportunityFlutterWebLogic extends StatefulWidget {
  final String tenantSlug;
  final String baseUrl;
  final String? userRole;
  final void Function(int leadId)? onCreated;
  final bool popOnCancel;

  /// Edit mode fields.
  ///
  /// Use this for Direct Opportunity edit:
  /// NewOpportunityFlutterWebLogic(
  ///   tenantSlug: widget.tenantSlug,
  ///   userRole: userRole,
  ///   isEditMode: true,
  ///   editLeadId: id,
  ///   initialData: item,
  ///   onCreated: (_) => Navigator.pop(context, true),
  /// )
  final bool isEditMode;
  final int? editLeadId;
  final Map<String, dynamic>? initialData;

  /// For web-style landing when this widget is reused with a preferred tab.
  /// New create flow still starts from Opportunity Details because no lead id exists
  /// until save. After save it opens OpportunityDirectTabsPage on Quotations.
  final OpportunityTabKey initialTab;

  const NewOpportunityFlutterWebLogic({
    super.key,
    required this.tenantSlug,
    this.baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1',
    this.userRole,
    this.onCreated,
    this.popOnCancel = true,
    this.isEditMode = false,
    this.editLeadId,
    this.initialData,
    this.initialTab = OpportunityTabKey.lead,
  });

  @override
  State<NewOpportunityFlutterWebLogic> createState() =>
      _NewOpportunityFlutterWebLogicState();
}

class _NewOpportunityFlutterWebLogicState
    extends State<NewOpportunityFlutterWebLogic> {
  static const List<String> priorities = ['Low', 'Medium', 'High'];
  static const Set<String> managerRoles = {
    'manager',
    'vp',
    'ceo',
    'admin',
    'super_admin',
  };

  String? token;
  bool loadingMasters = true;
  bool saving = false;
  bool addingSource = false;
  bool savingSource = false;
  bool addingProduct = false;
  bool savingProduct = false;

  List<SelectOption> customers = [];
  List<SelectOption> sources = [];
  List<SelectOption> productOptions = [];
  List<SelectOption> oemOptions = [];
  List<SelectOption> userOptions = [];
  List<SelectOption> businessVerticalOptions = [];

  final title = TextEditingController();
  final customerName = TextEditingController();
  final estValue = TextEditingController();
  String priority = 'Medium';
  final newSourceName = TextEditingController();
  final newProductName = TextEditingController();
  final region = TextEditingController();
  final branch = TextEditingController();
  final contactPerson = TextEditingController();
  final designation = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final department = TextEditingController();
  final address = TextEditingController();
  final timeline = TextEditingController();
  final followUp = TextEditingController();
  final productDesc = TextEditingController();
  final notes = TextEditingController();

  int? customerId;
  int? sourceId;
  int? assignedTo;
  int? businessVerticalId;
  List<ProductEntry> products = [ProductEntry()];
  late OpportunityTabKey activeCreateTab;

  // After creating a direct opportunity, keep the user inside this widget
  // and render the real direct-opportunity tab view. This avoids any parent
  // onCreated/openLeadViewPage code reopening the old Lead Details screen.
  int? createdDirectOpportunityId;

  String get apiBase => widget.baseUrl.endsWith('/')
      ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
      : widget.baseUrl;

  bool get isManagerOrAbove =>
      managerRoles.contains((widget.userRole ?? '').toLowerCase());

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${token ?? ''}',
    'X-Tenant-Slug': widget.tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    activeCreateTab = widget.initialTab;

    if (widget.initialData != null) {
      _applyLeadData(widget.initialData!);
    }

    loadMasters();
  }

  @override
  void dispose() {
    title.dispose();
    customerName.dispose();
    estValue.dispose();
    newSourceName.dispose();
    newProductName.dispose();
    region.dispose();
    branch.dispose();
    contactPerson.dispose();
    designation.dispose();
    mobile.dispose();
    email.dispose();
    department.dispose();
    address.dispose();
    timeline.dispose();
    followUp.dispose();
    productDesc.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> loadMasters() async {
    setState(() => loadingMasters = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');

      final results = await Future.wait([
        ApiMethod.getRequest(url: '$apiBase/leads/team-customers', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/lead-sources', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/products', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/oems', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/users-for-select', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/business-units', headers: headers),
      ]);

      if (!mounted) return;
      setState(() {
        customers = _mapCustomers(results[0]['data']);
        sources = _mapSimple(results[1]['data']);
        productOptions = _mapSimple(results[2]['data']);
        oemOptions = _mapSimple(results[3]['data']);
        userOptions = _mapUsers(results[4]['data']);
        businessVerticalOptions = _mapBusinessUnits(results[5]['data']);
      });

      if (widget.isEditMode && widget.editLeadId != null) {
        await _loadEditDataFromServer(widget.editLeadId!);
      }
    } catch (_) {
      // Same as web: master loading errors are silent, form still opens.
    } finally {
      if (mounted) setState(() => loadingMasters = false);
    }
  }

  Future<void> _loadEditDataFromServer(int id) async {
    try {
      final r = await ApiMethod.getRequest(url: '$apiBase/leads/$id', headers: headers);
      if (r['statusCode'] == 200 && r['data'] is Map) {
        if (!mounted) return;
        setState(() => _applyLeadData(Map<String, dynamic>.from(r['data'])));
      }
    } catch (_) {
      // Keep initialData if server fetch fails.
    }
  }

  void _applyLeadData(Map<String, dynamic> data) {
    title.text = _safe(data['lead_title'], '');
    customerId = _toInt(data['customer_id']);
    customerName.text = _safe(data['customer_name'], '');
    estValue.text = _safe(data['est_value'], '');
    final incomingPriority = _safe(data['priority'], 'Medium');
    priority = priorities.contains(incomingPriority) ? incomingPriority : 'Medium';
    sourceId = _toInt(data['source_id']);
    businessVerticalId = _toInt(data['business_vertical_id']);
    assignedTo = _toInt(data['assigned_to']);

    region.text = _safe(data['region'], '');
    branch.text = _safe(data['branch'], '');
    contactPerson.text = _safe(data['contact_person'], '');
    designation.text = _safe(data['designation'], '');
    mobile.text = _safe(data['mobile'], '');
    email.text = _safe(data['email'], '');
    department.text = _safe(data['department'], '');
    address.text = _safe(data['customer_address'], '');
    timeline.text = _dateOnly(data['timeline']);
    followUp.text = _dateOnly(data['follow_up']);
    productDesc.text = _safe(data['product_description'], '');
    notes.text = _safe(data['notes'], '');

    products = _mapProductsFromLead(data['products']);
  }

  List<ProductEntry> _mapProductsFromLead(dynamic raw) {
    if (raw is! List || raw.isEmpty) return [ProductEntry()];

    final mapped = <ProductEntry>[];

    for (final item in raw) {
      if (item is! Map) continue;
      final p = Map<String, dynamic>.from(item);

      final oems = <OemEntry>[];
      if (p['oems'] is List) {
        for (final rawOem in p['oems'] as List) {
          if (rawOem is Map) {
            final o = Map<String, dynamic>.from(rawOem);
            final oemName = _safe(o['oem_name'], '');
            final oemId = _toInt(o['oem_id']);
            if (oemName.isNotEmpty || oemId != null) {
              oems.add(OemEntry(oemId: oemId, oemName: oemName));
            }
          }
        }
      }

      mapped.add(
        ProductEntry(
          productId: _toInt(p['product_id']),
          productName: _safe(p['product_name'], ''),
          quantity: _safe(p['quantity'], '1'),
          description: _safe(p['description'], ''),
          oems: oems.isEmpty ? [OemEntry()] : oems,
        ),
      );
    }

    return mapped.isEmpty ? [ProductEntry()] : mapped;
  }

  List<SelectOption> _mapCustomers(dynamic data) {
    if (data is! List) return [];
    return data
        .where((x) => x is Map && _safe(x['customer_name'], '').isNotEmpty)
        .map((x) => SelectOption(
      value: _toInt(x['id']) ?? 0,
      label: _safe(x['customer_name'], ''),
      approvalStatus: _safe(x['approval_status'], '').toLowerCase().isEmpty
          ? null
          : _safe(x['approval_status'], '').toLowerCase(),
    ))
        .where((x) => x.value != 0)
        .toList();
  }

  List<SelectOption> _mapSimple(dynamic data) {
    if (data is! List) return [];
    return data
        .where((x) => x is Map && _safe(x['name'], '').isNotEmpty)
        .map((x) => SelectOption(value: _toInt(x['id']) ?? 0, label: _safe(x['name'], '')))
        .where((x) => x.value != 0)
        .toList();
  }

  List<SelectOption> _mapUsers(dynamic data) {
    if (data is! List) return [];
    return data
        .where((x) => x is Map && _safe(x['label'], '').isNotEmpty)
        .map((x) => SelectOption(value: _toInt(x['id']) ?? 0, label: _safe(x['label'], '')))
        .where((x) => x.value != 0)
        .toList();
  }

  List<SelectOption> _mapBusinessUnits(dynamic data) {
    if (data is! List) return [];
    return data.where((x) => x is Map && _toInt(x['id']) != null).map((x) {
      final unitName = _safe(x['name'], '').isNotEmpty
          ? _safe(x['name'], '')
          : _safe(x['business_unit'], '');
      final verticalName = _firstNonEmpty([
        x['vertical_name'],
        x['category_name'],
        x['business_vertical'],
        x['business_category'],
      ]);
      return SelectOption(
        value: _toInt(x['id']) ?? 0,
        label: unitName,
        subtitle: verticalName.isNotEmpty ? 'Vertical: $verticalName' : null,
      );
    }).where((x) => x.value != 0 && x.label.isNotEmpty).toList();
  }

  Future<void> handleCustomerSelect(int? id) async {
    setState(() {
      customerId = id;
      if (id == null) customerName.text = '';
    });
    if (id == null) return;

    final found = customers.where((c) => c.value == id).firstOrNull;
    if (found != null) customerName.text = found.label;

    try {
      final r = await ApiMethod.getRequest(url: '$apiBase/customers/$id', headers: headers);
      if (r['statusCode'] != 200 || r['data'] is! Map) return;
      final c = Map<String, dynamic>.from(r['data']);

      final city = _safe(c['billing_city'], '');
      final state = _safe(c['billing_state'], '');
      if (city.isNotEmpty || state.isNotEmpty) {
        address.text = [city, state].where((x) => x.isNotEmpty).join(', ');
      }

      Map<String, dynamic>? primary;
      if (c['contacts'] is List && (c['contacts'] as List).isNotEmpty) {
        final contacts = (c['contacts'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        primary = contacts.where((x) => x['is_primary'] == true).firstOrNull ?? contacts.first;
      }

      if (primary != null) {
        if (contactPerson.text.trim().isEmpty) {
          contactPerson.text = _safe(primary['contact_name'], '');
        }
        if (designation.text.trim().isEmpty) {
          designation.text = _safe(primary['designation'], '');
        }
        if (mobile.text.trim().isEmpty) {
          mobile.text = _safe(primary['mobile'], '');
        }
        if (email.text.trim().isEmpty) {
          email.text = _safe(primary['office_email'], '');
        }
        if (department.text.trim().isEmpty) {
          department.text = _safe(primary['department'], '');
        }
      }
    } catch (_) {
      // Same as web: customer autofill failure is silent.
    }
  }

  Future<void> handleQuickAddSource() async {
    final name = newSourceName.text.trim();
    if (name.isEmpty) return;
    setState(() => savingSource = true);
    try {
      final r = await ApiMethod.postRequest(
        url: '$apiBase/masters/lead-sources',
        headers: headers,
        body: {'name': name},
      );
      if ((r['statusCode'] == 200 || r['statusCode'] == 201) && r['data'] is Map) {
        final d = Map<String, dynamic>.from(r['data']);
        final opt = SelectOption(value: _toInt(d['id']) ?? 0, label: _safe(d['name'], name));
        if (opt.value != 0) {
          setState(() {
            sources = [...sources, opt];
            sourceId = opt.value;
            newSourceName.clear();
            addingSource = false;
          });
        }
      }
    } catch (_) {
      // Same as web: silent quick-add failure.
    } finally {
      if (mounted) setState(() => savingSource = false);
    }
  }

  Future<void> handleQuickAddProduct() async {
    final name = newProductName.text.trim();
    if (name.isEmpty) return;
    setState(() => savingProduct = true);
    try {
      final r = await ApiMethod.postRequest(
        url: '$apiBase/masters/products',
        headers: headers,
        body: {'name': name},
      );
      if ((r['statusCode'] == 200 || r['statusCode'] == 201) && r['data'] is Map) {
        final d = Map<String, dynamic>.from(r['data']);
        final opt = SelectOption(value: _toInt(d['id']) ?? 0, label: _safe(d['name'], name));
        if (opt.value != 0) {
          setState(() {
            productOptions = [...productOptions, opt];
            newProductName.clear();
            addingProduct = false;
          });
        }
      }
    } catch (_) {
      // Same as web: silent quick-add failure.
    } finally {
      if (mounted) setState(() => savingProduct = false);
    }
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _validateOpportunityForm() {
    final missing = <String>[];

    if (customerId == null) missing.add('Customer Account');
    if (customerName.text.trim().isEmpty) missing.add('Customer Name');
    if (address.text.trim().isEmpty) missing.add('Customer Address');

    if (department.text.trim().isEmpty) missing.add('Department');
    if (contactPerson.text.trim().isEmpty) missing.add('Contact Person');
    if (designation.text.trim().isEmpty) missing.add('Designation');

    final mobileDigits = _digitsOnly(mobile.text);
    if (mobileDigits.isEmpty) {
      missing.add('Mobile');
    } else if (mobileDigits.length != 10) {
      return 'Mobile number must be 10 digits';
    }

    final emailValue = email.text.trim();
    if (emailValue.isEmpty) {
      missing.add('Email');
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailValue)) {
      return 'Enter a valid email';
    }

    if (title.text.trim().isEmpty) missing.add('Lead Title');
    if (sourceId == null) missing.add('Source');
    if (businessVerticalId == null) missing.add('Business Vertical');
    if (priority.trim().isEmpty) missing.add('Priority');
    if (estValue.text.trim().isEmpty) missing.add('Estimated Value');
    if (assignedTo == null) missing.add('Assigned To');
    if (followUp.text.trim().isEmpty) missing.add('Follow Up Date');
    if (timeline.text.trim().isEmpty) missing.add('Timeline Date');

    final hasProduct = products.any(
          (p) => p.productId != null || p.productName.trim().isNotEmpty,
    );
    if (!hasProduct) {
      return 'Please add at least one product in Products & OEM Details';
    }

    if (missing.isNotEmpty) {
      return 'Please fill: ${missing.join(', ')}';
    }

    return null;
  }

  int? _extractCreatedLeadId(Map response) {
    final data = response['data'];

    int? fromMap(Map raw) {
      return _toInt(
        raw['id'] ??
            raw['lead_id'] ??
            raw['leadId'] ??
            raw['opportunity_id'] ??
            raw['opportunityId'],
      ) ??
          (raw['lead'] is Map ? fromMap(Map<String, dynamic>.from(raw['lead'])) : null) ??
          (raw['opportunity'] is Map
              ? fromMap(Map<String, dynamic>.from(raw['opportunity']))
              : null) ??
          (raw['data'] is Map ? fromMap(Map<String, dynamic>.from(raw['data'])) : null);
    }

    if (data is Map) {
      final id = fromMap(Map<String, dynamic>.from(data));
      if (id != null) return id;
    }

    return fromMap(Map<String, dynamic>.from(response));
  }

  Future<void> handleSave() async {
    final validationError = _validateOpportunityForm();
    if (validationError != null) {
      _snack(validationError, Colors.red);
      return;
    }

    final selectedCustomer = customers.where((c) => c.value == customerId).firstOrNull;
    if (selectedCustomer?.approvalStatus == 'pending') {
      _snack('Selected customer is pending approval. Cannot create an opportunity for it.', Colors.red);
      return;
    }

    final payload = <String, dynamic>{
      'lead_title': title.text.trim(),
      'customer_id': customerId,
      'customer_name': customerName.text.trim(),
      'customer_address': address.text.trim(),
      'department': department.text.trim(),
      'contact_person': contactPerson.text.trim(),
      'designation': designation.text.trim(),
      'mobile': _digitsOnly(mobile.text),
      'email': email.text.trim(),
      'source_id': sourceId,
      'business_vertical_id': businessVerticalId,
      'priority': priority,
      'status': 'Opportunity Created',
      'lead_type': 'direct_opportunity',
      'est_value': double.tryParse(estValue.text.trim()),
      'region': region.text.trim(),
      'branch': branch.text.trim(),
      'timeline': timeline.text.trim().isEmpty ? null : timeline.text.trim(),
      'follow_up': followUp.text.trim().isEmpty ? null : followUp.text.trim(),
      'product_description': productDesc.text.trim(),
      'notes': notes.text.trim(),
      'assigned_to': assignedTo,
      'products': products
          .where((p) => p.productId != null || p.productName.trim().isNotEmpty)
          .map((p) => p.toJson())
          .toList(),
    };

    setState(() => saving = true);
    try {
      final r = widget.isEditMode && widget.editLeadId != null
          ? await _updateLead(widget.editLeadId!, payload)
          : await ApiMethod.postRequest(url: '$apiBase/leads', headers: headers, body: payload);

      if (r['statusCode'] == 200 || r['statusCode'] == 201) {
        final id = widget.isEditMode
            ? (r['data'] is Map ? _toInt((r['data'] as Map)['id']) ?? widget.editLeadId : widget.editLeadId)
            : _extractCreatedLeadId(r);

        _snack(
          widget.isEditMode ? 'Opportunity updated' : 'Opportunity created',
          Colors.green,
        );

        if (id != null) {
          if (widget.isEditMode) {
            widget.onCreated?.call(id);
            if (widget.onCreated == null && mounted) {
              Navigator.pop(context, true);
            }
          } else if (mounted) {
            // Important: do not call widget.onCreated here and do not pop back
            // to OpportunityList. Some parent screens reopen the old Lead Details
            // page. Push the real workflow page directly and force Quotations.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OpportunityDirectTabsPage(
                  tenantSlug: widget.tenantSlug,
                  baseUrl: apiBase,
                  leadId: id,
                  initialTab: OpportunityTabKey.quotations,
                ),
              ),
            );
            return;
          }
        } else if (mounted) {
          if (widget.isEditMode) {
            Navigator.pop(context, true);
          } else {
            _snack(
              'Opportunity created, but created ID was not returned by API. Please reopen it from Opportunities.',
              Colors.orange,
            );
          }
        }
      } else {
        _snack(
          _apiError(
            r,
            fallback: widget.isEditMode
                ? 'Failed to update opportunity'
                : 'Failed to create opportunity',
          ),
          Colors.red,
        );
      }
    } catch (e) {
      _snack(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<Map<String, dynamic>> _updateLead(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$apiBase/leads/$id');

    Future<Map<String, dynamic>> send(String method) async {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      request.body = jsonEncode(payload);

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      dynamic decoded;
      if (body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(body);
        } catch (_) {
          decoded = body;
        }
      }

      return {
        'statusCode': streamed.statusCode,
        'data': decoded,
      };
    }

    final putRes = await send('PUT');

    // Some backends expose PATCH instead of PUT. This keeps the screen usable
    // without depending on a custom ApiMethod.putRequest implementation.
    if (putRes['statusCode'] == 404 || putRes['statusCode'] == 405) {
      return send('PATCH');
    }

    return putRes;
  }

  @override
  Widget build(BuildContext context) {
    // Once the direct opportunity is created, this page must behave like the web
    // OpportunityView route (/opportunities/:id), not like the create form.
    // This is the safest fix for the repeated "still lands on Lead Details" issue.
    if (!widget.isEditMode && createdDirectOpportunityId != null) {
      return OpportunityDirectTabsPage(
        tenantSlug: widget.tenantSlug,
        baseUrl: apiBase,
        leadId: createdDirectOpportunityId!,
        initialTab: OpportunityTabKey.quotations,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _stepperTabs(),
            Expanded(
              child: loadingMasters
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryLight))
                  : RefreshIndicator(
                color: AppColors.primaryLight,
                onRefresh: loadMasters,
                child: _newOpportunityTabBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newOpportunityTabBody() {
    if (activeCreateTab != OpportunityTabKey.lead) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _lockedWorkflowCard(activeCreateTab),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _hint(),
        _coreSection(),
        _contactSection(),
        _timelineSection(),
        _productsSection(),
        _notesSection(),
        _actions(),
      ],
    );
  }

  Widget _lockedWorkflowCard(OpportunityTabKey tab) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Icon(tab.icon, color: const Color(0xFFF59E0B), size: 34),
          const SizedBox(height: 12),
          Text(
            tab.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fill Opportunity Details and tap Create Opportunity. After save, this screen will open the live opportunity workflow and land on Quotations, exactly like the web flow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final titleText = title.text.trim();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: saving
                ? null
                : () {
              if (widget.popOnCancel) Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primarySlate),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chip(
                  'Direct Opportunity',
                  Icons.business_outlined,
                  const Color(0xFF7E22CE),
                  const Color(0xFFFAF5FF),
                  const Color(0xFFE9D5FF),
                ),
                const SizedBox(height: 8),
                Text(
                  titleText.isEmpty
                      ? (widget.isEditMode ? 'Edit Opportunity' : 'New Opportunity')
                      : titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.isEditMode
                      ? 'Editing opportunity details'
                      : 'Fill in lead details to create',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperTabs() {
    final tabs = <Map<String, dynamic>>[
      {'key': OpportunityTabKey.lead, 'label': 'Opportunity Details', 'icon': Icons.business_outlined},
      {'key': OpportunityTabKey.quotations, 'label': 'Quotations', 'icon': Icons.description_outlined},
      {'key': OpportunityTabKey.po, 'label': 'PO Details', 'icon': Icons.currency_rupee_rounded},
      {'key': OpportunityTabKey.consignee, 'label': 'Consignee', 'icon': Icons.local_shipping_outlined},
      {'key': OpportunityTabKey.workorder, 'label': 'Work Orders', 'icon': Icons.assignment_outlined},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final key = tab['key'] as OpportunityTabKey;
            final active = activeCreateTab == key;
            final locked = key != OpportunityTabKey.lead;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: locked
                      ? () => setState(() => activeCreateTab = key)
                      : () => setState(() => activeCreateTab = key),
                  child: SizedBox(
                    width: 124,
                    child: Column(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: active ? AppColors.primaryLight : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFF1F5F9),
                              width: 5,
                            ),
                            boxShadow: active
                                ? [
                              BoxShadow(
                                color: AppColors.primaryLight.withOpacity(.16),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ]
                                : null,
                          ),
                          child: Icon(
                            locked && !active ? Icons.lock_outline_rounded : tab['icon'] as IconData,
                            size: 16,
                            color: active ? Colors.white : const Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          tab['label'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: active
                                ? AppColors.primaryLight
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(height: 5),
                          _smallBadge(
                            'Locked',
                            const Color(0xFF94A3B8),
                            const Color(0xFFF8FAFC),
                            const Color(0xFFE2E8F0),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (index < tabs.length - 1)
                  Container(
                    margin: const EdgeInsets.only(top: 20, left: 8, right: 8),
                    width: 58,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _hint() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business_outlined, size: 15, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isEditMode
                  ? 'Update the opportunity details below. Quotations, PO, Consignee and Work Orders stay in the opportunity view.'
                  : 'Fill in the lead details and tap Create Opportunity. Quotations, PO, Consignee and Work Orders unlock after creation.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coreSection() {
    return _card(
      title: 'Opportunity Details',
      icon: Icons.business_outlined,
      children: [
        _field(
          'Opportunity Title *',
          title,
          hint: 'e.g. Supply of UPS Systems - XYZ Corp',
          onChanged: (_) => setState(() {}),
        ),
        _selectField(
          'Customer / Account',
          customers,
          customerId,
          handleCustomerSelect,
          hint: 'Search customer...',
        ),
        _row(
          _field('Est. Value (₹)', estValue, number: true),
          _dropdown('Priority', priorities, priority, (v) {
            setState(() => priority = v ?? 'Medium');
          }),
        ),
        _sourceField(),
        _selectField(
          'Business Vertical',
          businessVerticalOptions,
          businessVerticalId,
              (v) => setState(() => businessVerticalId = v),
          hint: 'Select business vertical...',
        ),
        if (isManagerOrAbove)
          _selectField(
            'Assigned To',
            userOptions,
            assignedTo,
                (v) => setState(() => assignedTo = v),
            hint: 'Select user...',
          ),
        _row(_field('Region', region), _field('Branch', branch)),
      ],
    );
  }

  Widget _sourceField() {
    if (addingSource) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.primarySlate,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _plainTextField(
                    newSourceName,
                    hint: 'Source name...',
                    autoFocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                _squareButton(
                  savingSource ? null : handleQuickAddSource,
                  savingSource ? Icons.hourglass_empty : Icons.save_outlined,
                  AppColors.primaryLight,
                ),
                const SizedBox(width: 6),
                _squareButton(
                      () => setState(() {
                    addingSource = false;
                    newSourceName.clear();
                  }),
                  Icons.close_rounded,
                  const Color(0xFF64748B),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Source',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primarySlate,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => addingSource = true),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Source'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryLight,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        _selectField(
          '',
          sources,
          sourceId,
              (v) => setState(() => sourceId = v),
          hint: 'Lead source...',
          hideLabel: true,
        ),
      ],
    );
  }

  Widget _contactSection() {
    return _card(
      title: 'Contact Details',
      icon: Icons.person_outline_rounded,
      children: [
        _row(_field('Contact Person', contactPerson), _field('Designation', designation)),
        _row(
          _field('Mobile', mobile, number: true, maxLength: 10, digitsOnly: true),
          _field('Email', email, keyboardType: TextInputType.emailAddress),
        ),
        _row(_field('Department', department), _field('Address', address)),
      ],
    );
  }

  Widget _timelineSection() {
    return _card(
      title: 'Timeline',
      icon: Icons.calendar_month_outlined,
      children: [
        _row(
          _dateField('Expected Timeline', timeline),
          _dateField('Follow Up Date', followUp),
        ),
      ],
    );
  }

  Widget _productsSection() {
    return _card(
      title: 'Products & OEMs',
      icon: Icons.inventory_2_outlined,
      children: [
        ...List.generate(products.length, (pi) => _productCard(pi)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => products.add(ProductEntry())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Product'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
              side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _productCard(int pi) {
    final prod = products[pi];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF).withOpacity(.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product ${pi + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              if (products.length > 1)
                IconButton(
                  onPressed: () => setState(() => products.removeAt(pi)),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                  constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                ),
            ],
          ),
          if (pi == 0 && addingProduct) ...[
            const Text(
              'Product',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.primarySlate,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _plainTextField(
                    newProductName,
                    hint: 'Product name...',
                    autoFocus: true,
                  ),
                ),
                const SizedBox(width: 8),
                _squareButton(
                  savingProduct ? null : handleQuickAddProduct,
                  savingProduct ? Icons.hourglass_empty : Icons.save_outlined,
                  AppColors.primaryLight,
                ),
                const SizedBox(width: 6),
                _squareButton(
                      () => setState(() {
                    addingProduct = false;
                    newProductName.clear();
                  }),
                  Icons.close_rounded,
                  const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Product',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primarySlate,
                    ),
                  ),
                ),
                if (pi == 0)
                  TextButton.icon(
                    onPressed: () => setState(() => addingProduct = true),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Product'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            _selectField(
              '',
              productOptions,
              prod.productId,
                  (v) {
                final opt = productOptions.where((o) => o.value == v).firstOrNull;
                setState(() {
                  prod.productId = v;
                  prod.productName = opt?.label ?? '';
                  prod.oems = [OemEntry()];
                });
              },
              hint: 'Select product',
              hideLabel: true,
            ),
          ],
          _field(
            'Qty',
            TextEditingController(text: prod.quantity),
            number: true,
            onChanged: (v) => prod.quantity = v,
          ),
          _field(
            'Description',
            TextEditingController(text: prod.description),
            hint: 'Spec / notes',
            onChanged: (v) => prod.description = v,
          ),
          const SizedBox(height: 4),
          const Text(
            'OEM / Vendors',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF64748B),
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(prod.oems.length, (oi) => _oemRow(pi, oi)),
          TextButton.icon(
            onPressed: () => setState(() => prod.oems.add(OemEntry())),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add OEM'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oemRow(int pi, int oi) {
    final prod = products[pi];
    final oem = prod.oems[oi];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _selectField(
              '',
              oemOptions,
              oem.oemId,
                  (v) {
                final opt = oemOptions.where((o) => o.value == v).firstOrNull;
                setState(() {
                  oem.oemId = v;
                  oem.oemName = opt?.label ?? '';
                });
              },
              hint: 'Select OEM',
              hideLabel: true,
            ),
          ),
          if (prod.oems.length > 1)
            IconButton(
              onPressed: () => setState(() => prod.oems.removeAt(oi)),
              icon: const Icon(Icons.close_rounded, color: Colors.red, size: 17),
            ),
        ],
      ),
    );
  }

  Widget _notesSection() {
    return _card(
      title: 'Description & Notes',
      icon: Icons.notes_outlined,
      children: [
        _field(
          'Product Description',
          productDesc,
          hint: 'Brief description of the requirement...',
          maxLines: 3,
        ),
        _field('Notes', notes, maxLines: 3),
      ],
    );
  }

  Widget _actions() {
    final saveText = widget.isEditMode ? 'Update Opportunity' : 'Create Opportunity';
    final savingText = widget.isEditMode ? 'Updating...' : 'Creating...';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving
                ? null
                : () {
              if (widget.popOnCancel) Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: saving || title.text.trim().isEmpty ? null : handleSave,
            icon: saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.save_outlined, size: 18,color: Colors.white,),
            label: Text(saving ? savingText : saveText,
              style: TextStyle(color: Colors.white),),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
      String label,
      TextEditingController controller, {
        String? hint,
        bool number = false,
        bool digitsOnly = false,
        int? maxLength,
        int maxLines = 1,
        TextInputType? keyboardType,
        ValueChanged<String>? onChanged,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.primarySlate,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType ??
                (number
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text),
            onChanged: (v) {
              if (digitsOnly) {
                final cleaned = v.replaceAll(RegExp(r'\D'), '');
                final sliced = maxLength == null
                    ? cleaned
                    : cleaned.substring(
                  0,
                  cleaned.length > maxLength ? maxLength : cleaned.length,
                );
                if (sliced != v) {
                  controller.value = TextEditingValue(
                    text: sliced,
                    selection: TextSelection.collapsed(offset: sliced.length),
                  );
                }
                onChanged?.call(sliced);
              } else {
                onChanged?.call(v);
              }
            },
            decoration: _inputDecoration(hint),
          ),
        ],
      ),
    );
  }

  Widget _plainTextField(
      TextEditingController controller, {
        String? hint,
        bool autoFocus = false,
      }) {
    return TextField(
      controller: controller,
      autofocus: autoFocus,
      decoration: _inputDecoration(hint),
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.primarySlate,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            readOnly: true,
            decoration: _inputDecoration('YYYY-MM-DD').copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            onTap: () async {
              final now = DateTime.now();
              final current = DateTime.tryParse(controller.text.trim());
              final picked = await showDatePicker(
                context: context,
                initialDate: current ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) {
                controller.text =
                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
      String label,
      List<String> options,
      String value,
      ValueChanged<String?> onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.primarySlate,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            decoration: _inputDecoration(null),
            items: options
                .map(
                  (o) => DropdownMenuItem(
                value: o,
                child: Text(
                  o,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _selectField(
      String label,
      List<SelectOption> options,
      int? value,
      ValueChanged<int?> onChanged, {
        String? hint,
        bool hideLabel = false,
      }) {
    final selected = options.where((o) => o.value == value).firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideLabel) ...[
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.primarySlate,
              ),
            ),
            const SizedBox(height: 6),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await _showOptionPicker(
                title: label.isEmpty ? hint ?? 'Select' : label,
                options: options,
                selected: value,
              );
              if (picked != -999999) onChanged(picked == 0 ? null : picked);
            },
            child: InputDecorator(
              decoration: _inputDecoration(hint).copyWith(
                suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              child: Text(
                selected?.label ?? hint ?? 'Select',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected == null ? AppColors.muted : AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _showOptionPicker({
    required String title,
    required List<SelectOption> options,
    int? selected,
  }) async {
    final query = TextEditingController();
    int result = -999999;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        List<SelectOption> filtered = options;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyFilter(String q) {
              final term = q.toLowerCase().trim();
              setSheetState(() {
                filtered = term.isEmpty
                    ? options
                    : options
                    .where(
                      (o) =>
                  o.label.toLowerCase().contains(term) ||
                      (o.subtitle ?? '').toLowerCase().contains(term),
                )
                    .toList();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    TextField(
                      controller: query,
                      onChanged: applyFilter,
                      decoration: _inputDecoration('Search...'),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.clear_rounded, color: AppColors.muted),
                      title: const Text(
                        'Clear selection',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onTap: () {
                        result = 0;
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                        child: Text(
                          'No options found',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final opt = filtered[i];
                          final isSelected = opt.value == selected;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              opt.label,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: opt.subtitle == null ? null : Text(opt.subtitle!),
                            trailing: isSelected
                                ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryLight,
                            )
                                : null,
                            onTap: () {
                              result = opt.value;
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    query.dispose();
    return result;
  }

  Widget _row(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) return Column(children: [a, b]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _squareButton(VoidCallback? onPressed, IconData icon, Color color) {
    return SizedBox(
      height: 48,
      width: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 17),
      ),
    );
  }

  Widget _chip(String text, IconData? icon, Color fg, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String text, Color fg, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.4),
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _apiError(Map res, {String fallback = 'Request failed'}) {
    final data = res['data'];
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is List) {
        return detail
            .map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString())
            .join(', ');
      }
      return detail.toString();
    }
    if (data is List) return data.map((e) => e.toString()).join(', ');
    return data?.toString() ?? fallback;
  }

  String _safe(dynamic value, [String fallback = '-']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  String _dateOnly(dynamic value) {
    final raw = _safe(value, '');
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final text = _safe(v, '');
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}



class EditOpportunityPage extends StatefulWidget {
  final String tenantSlug;
  final int opportunityId;
  final Map<String, dynamic>? initialData;
  final String baseUrl;

  const EditOpportunityPage({
    super.key,
    required this.tenantSlug,
    required this.opportunityId,
    this.initialData,
    this.baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1',
  });

  @override
  State<EditOpportunityPage> createState() => _EditOpportunityPageState();
}

class _EditOpportunityPageState extends State<EditOpportunityPage> {
  static const Color primaryDark = Color(0xFF103050);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF94A3B8);
  static const Color text = Color(0xFF0F172A);

  static const List<String> priorities = ['Low', 'Medium', 'High'];

  String? token;
  bool loading = true;
  bool saving = false;
  bool loadingMasters = false;
  bool addingProductMaster = false;
  bool savingProductMaster = false;
  bool addingOemMaster = false;
  bool savingOemMaster = false;

  List<SelectOption> customers = [];
  List<SelectOption> productsMaster = [];
  List<SelectOption> oemsMaster = [];
  List<SelectOption> sources = [];
  List<SelectOption> users = [];
  List<SelectOption> businessUnits = [];

  final leadTitle = TextEditingController();
  final customerName = TextEditingController();
  final estValue = TextEditingController();
  final region = TextEditingController();
  final branch = TextEditingController();
  final contactPerson = TextEditingController();
  final designation = TextEditingController();
  final mobile = TextEditingController();
  final email = TextEditingController();
  final department = TextEditingController();
  final address = TextEditingController();
  final timeline = TextEditingController();
  final followUp = TextEditingController();
  final productDescription = TextEditingController();
  final notes = TextEditingController();
  final newProductName = TextEditingController();
  final newOemName = TextEditingController();

  int? customerId;
  int? sourceId;
  int? businessVerticalId;
  int? assignedTo;
  String priority = 'Medium';

  List<ProductRow> products = [ProductRow()];

  String get apiBase => widget.baseUrl.endsWith('/')
      ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
      : widget.baseUrl;

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${token ?? ''}',
    'X-Tenant-Slug': widget.tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _applyData(widget.initialData!);
    }
    init();
  }

  @override
  void dispose() {
    leadTitle.dispose();
    customerName.dispose();
    estValue.dispose();
    region.dispose();
    branch.dispose();
    contactPerson.dispose();
    designation.dispose();
    mobile.dispose();
    email.dispose();
    department.dispose();
    address.dispose();
    timeline.dispose();
    followUp.dispose();
    productDescription.dispose();
    notes.dispose();
    newProductName.dispose();
    newOemName.dispose();
    super.dispose();
  }

  Future<void> init() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('auth_token');

    if (token == null || token!.isEmpty) {
      setState(() => loading = false);
      showError('Token not found');
      return;
    }

    await Future.wait([
      loadMasters(),
      loadOpportunity(),
    ]);

    if (mounted) setState(() => loading = false);
  }

  Future<void> loadMasters() async {
    setState(() => loadingMasters = true);
    try {
      final results = await Future.wait([
        ApiMethod.getRequest(url: '$apiBase/leads/team-customers', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/products', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/oems', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/lead-sources', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/users-for-select', headers: headers),
        ApiMethod.getRequest(url: '$apiBase/masters/business-units', headers: headers),
      ]);

      if (!mounted) return;
      setState(() {
        customers = _mapCustomers(results[0]['data']);
        productsMaster = _mapSimple(results[1]['data']);
        oemsMaster = _mapSimple(results[2]['data']);
        sources = _mapSimple(results[3]['data']);
        users = _mapUsers(results[4]['data']);
        businessUnits = _mapBusinessUnits(results[5]['data']);
      });
    } catch (_) {
      // keep silent like web
    } finally {
      if (mounted) setState(() => loadingMasters = false);
    }
  }

  Future<void> loadOpportunity() async {
    try {
      final res = await ApiMethod.getRequest(
        url: '$apiBase/leads/${widget.opportunityId}',
        headers: headers,
      );

      if (res['statusCode'] == 200 && res['data'] is Map) {
        if (!mounted) return;
        setState(() => _applyData(Map<String, dynamic>.from(res['data'])));
      }
    } catch (_) {
      // if initialData exists, keep it
    }
  }

  void _applyData(Map<String, dynamic> data) {
    leadTitle.text = safe(data['lead_title'], '');
    customerId = toInt(data['customer_id']);
    customerName.text = safe(data['customer_name'], '');
    estValue.text = safe(data['est_value'], '');

    final incomingPriority = safe(data['priority'], 'Medium');
    priority = priorities.contains(incomingPriority) ? incomingPriority : 'Medium';

    sourceId = toInt(data['source_id']);
    businessVerticalId = toInt(data['business_vertical_id']);
    assignedTo = toInt(data['assigned_to']);

    region.text = safe(data['region'], '');
    branch.text = safe(data['branch'], '');
    contactPerson.text = safe(data['contact_person'], '');
    designation.text = safe(data['designation'], '');
    mobile.text = safe(data['mobile'], '');
    email.text = safe(data['email'], '');
    department.text = safe(data['department'], '');
    address.text = safe(data['customer_address'], '');
    timeline.text = dateOnly(data['timeline']);
    followUp.text = dateOnly(data['follow_up']);
    productDescription.text = safe(data['product_description'], '');
    notes.text = safe(data['notes'], '');

    products = mapProducts(data['products']);
  }

  List<ProductRow> mapProducts(dynamic raw) {
    if (raw is! List || raw.isEmpty) return [ProductRow()];

    final rows = <ProductRow>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final p = Map<String, dynamic>.from(item);

      final oemRows = <OemRow>[];
      if (p['oems'] is List) {
        for (final rawOem in p['oems'] as List) {
          if (rawOem is Map) {
            final o = Map<String, dynamic>.from(rawOem);
            final name = safe(o['oem_name'], '');
            final id = toInt(o['oem_id']);
            if (name.isNotEmpty || id != null) {
              oemRows.add(OemRow(oemId: id, oemName: name));
            }
          }
        }
      }

      rows.add(ProductRow(
        productId: toInt(p['product_id']),
        productName: safe(p['product_name'], ''),
        quantity: safe(p['quantity'], '1'),
        description: safe(p['description'], ''),
        oems: oemRows,
      ));
    }

    return rows.isEmpty ? [ProductRow()] : rows;
  }

  Future<void> handleCustomerSelect(int? id) async {
    setState(() {
      customerId = id;
      if (id == null) customerName.text = '';
    });

    if (id == null) return;

    final selected = customers.where((c) => c.value == id).firstOrNull;
    if (selected != null) customerName.text = selected.label;

    try {
      final res = await ApiMethod.getRequest(url: '$apiBase/customers/$id', headers: headers);
      if (res['statusCode'] != 200 || res['data'] is! Map) return;

      final c = Map<String, dynamic>.from(res['data']);
      final city = safe(c['billing_city'], '');
      final state = safe(c['billing_state'], '');

      if (city.isNotEmpty || state.isNotEmpty) {
        address.text = [city, state].where((x) => x.isNotEmpty).join(', ');
      }

      Map<String, dynamic>? primary;
      if (c['contacts'] is List && (c['contacts'] as List).isNotEmpty) {
        final contacts = (c['contacts'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        primary = contacts.where((x) => x['is_primary'] == true).firstOrNull ?? contacts.first;
      }

      if (primary != null) {
        if (contactPerson.text.trim().isEmpty) contactPerson.text = safe(primary['contact_name'], '');
        if (designation.text.trim().isEmpty) designation.text = safe(primary['designation'], '');
        if (mobile.text.trim().isEmpty) mobile.text = safe(primary['mobile'], '');
        if (email.text.trim().isEmpty) email.text = safe(primary['office_email'], '');
        if (department.text.trim().isEmpty) department.text = safe(primary['department'], '');
      }
    } catch (_) {}
  }

  Future<void> addProductMaster() async {
    final name = newProductName.text.trim();
    if (name.isEmpty) return;

    setState(() => savingProductMaster = true);
    try {
      final res = await ApiMethod.postRequest(
        url: '$apiBase/masters/products',
        headers: headers,
        body: {'name': name},
      );

      if ((res['statusCode'] == 200 || res['statusCode'] == 201) && res['data'] is Map) {
        final d = Map<String, dynamic>.from(res['data']);
        final opt = SelectOption(value: toInt(d['id']) ?? 0, label: safe(d['name'], name));
        if (opt.value != 0) {
          setState(() {
            productsMaster = [...productsMaster, opt];
            addingProductMaster = false;
            newProductName.clear();
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => savingProductMaster = false);
    }
  }

  Future<void> addOemMaster() async {
    final name = newOemName.text.trim();
    if (name.isEmpty) return;

    setState(() => savingOemMaster = true);
    try {
      final res = await ApiMethod.postRequest(
        url: '$apiBase/masters/oems',
        headers: headers,
        body: {'name': name},
      );

      if ((res['statusCode'] == 200 || res['statusCode'] == 201) && res['data'] is Map) {
        final d = Map<String, dynamic>.from(res['data']);
        final opt = SelectOption(value: toInt(d['id']) ?? 0, label: safe(d['name'], name));
        if (opt.value != 0) {
          setState(() {
            oemsMaster = [...oemsMaster, opt];
            addingOemMaster = false;
            newOemName.clear();
          });
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => savingOemMaster = false);
    }
  }

  Future<void> saveOpportunity() async {
    if (leadTitle.text.trim().isEmpty) {
      showError('Opportunity title is required');
      return;
    }

    final customer = customers.where((c) => c.value == customerId).firstOrNull;
    if (customer?.approvalStatus == 'pending') {
      showError('Selected customer is pending approval.');
      return;
    }

    final payload = {
      'lead_title': leadTitle.text.trim(),
      'customer_id': customerId,
      'customer_name': customerName.text,
      'customer_address': address.text,
      'department': department.text,
      'contact_person': contactPerson.text,
      'designation': designation.text,
      'mobile': mobile.text,
      'email': email.text,
      'source_id': sourceId,
      'business_vertical_id': businessVerticalId,
      'priority': priority,
      'status': safe(widget.initialData?['status'], 'Opportunity Created'),
      'lead_type': safe(widget.initialData?['lead_type'], 'lead'),
      'est_value': estValue.text.trim().isEmpty ? null : double.tryParse(estValue.text.trim()),
      'region': region.text,
      'branch': branch.text,
      'timeline': timeline.text.trim().isEmpty ? null : timeline.text.trim(),
      'follow_up': followUp.text.trim().isEmpty ? null : followUp.text.trim(),
      'product_description': productDescription.text,
      'notes': notes.text,
      'assigned_to': assignedTo,
      'products': products
          .where((p) => p.productName.trim().isNotEmpty)
          .map((p) => p.toJson())
          .toList(),
    };

    setState(() => saving = true);

    try {
      final res = await updateLead(widget.opportunityId, payload);

      if (res['statusCode'] == 200 || res['statusCode'] == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opportunity updated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        showError(apiError(res, fallback: 'Failed to update opportunity'));
      }
    } catch (e) {
      showError(e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<Map<String, dynamic>> updateLead(int id, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$apiBase/leads/$id');

    Future<Map<String, dynamic>> send(String method) async {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);
      request.body = jsonEncode(payload);

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      dynamic decoded;
      if (body.trim().isNotEmpty) {
        try {
          decoded = jsonDecode(body);
        } catch (_) {
          decoded = body;
        }
      }

      return {
        'statusCode': streamed.statusCode,
        'data': decoded,
      };
    }

    final putRes = await send('PUT');
    if (putRes['statusCode'] == 404 || putRes['statusCode'] == 405) {
      return send('PATCH');
    }
    return putRes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            header(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: primaryLight))
                  : Stack(
                children: [
                  RefreshIndicator(
                    color: primaryLight,
                    onRefresh: () async {
                      await loadMasters();
                      await loadOpportunity();
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        basicDetailsSection(),
                        contactDetailsSection(),
                        timelineSection(),
                        productsSection(),
                        notesSection(),
                      ],
                    ),
                  ),
                  footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Edit Opportunity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Editing opportunity details',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: muted),
          ),
        ],
      ),
    );
  }

  Widget basicDetailsSection() {
    return card(
      title: 'Opportunity Details',
      subtitle: 'Update basic opportunity information',
      icon: Icons.business_outlined,
      children: [
        field('Opportunity Title *', leadTitle),
        selectField('Customer / Account', customers, customerId, handleCustomerSelect, hint: 'Select customer'),
        row2(
          field('Est. Value (₹)', estValue, number: true),
          dropdown('Priority', priorities, priority, (v) => setState(() => priority = v ?? 'Medium')),
        ),
        selectField('Source', sources, sourceId, (v) => setState(() => sourceId = v), hint: 'Select source'),
        selectField('Business Vertical', businessUnits, businessVerticalId, (v) => setState(() => businessVerticalId = v), hint: 'Select business vertical'),
        selectField('Assigned To', users, assignedTo, (v) => setState(() => assignedTo = v), hint: 'Select user'),
        row2(field('Region', region), field('Branch', branch)),
      ],
    );
  }

  Widget contactDetailsSection() {
    return card(
      title: 'Contact Details',
      subtitle: 'Update contact details for this opportunity',
      icon: Icons.person_outline,
      children: [
        row2(field('Contact Person', contactPerson), field('Designation', designation)),
        row2(
          field('Mobile', mobile, number: true, digitsOnly: true, maxLength: 10),
          field('Email', email, keyboardType: TextInputType.emailAddress),
        ),
        row2(field('Department', department), field('Address', address)),
      ],
    );
  }

  Widget timelineSection() {
    return card(
      title: 'Timeline',
      subtitle: 'Expected timeline and follow-up date',
      icon: Icons.calendar_today_outlined,
      children: [
        row2(
          dateField('Expected Timeline', timeline),
          dateField('Follow Up Date', followUp),
        ),
      ],
    );
  }

  Widget productsSection() {
    return card(
      title: 'Products & OEM Details',
      subtitle: 'Capture products and OEM/vendors for this opportunity',
      icon: Icons.inventory_2_outlined,
      trailing: loadingMasters
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              outlinedMiniButton(Icons.download_outlined, 'Sample Excel', () {
                showInfo('Sample Excel download is not connected in Flutter yet.');
              }),
              outlinedMiniButton(Icons.upload_file_outlined, 'Import Excel', () {
                showInfo('Import Excel is not connected in Flutter yet.');
              }, green: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(products.length, productCard),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => products.add(ProductRow())),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Product Row'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryLight,
              side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.4),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget productCard(int index) {
    final product = products[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 15, color: primaryLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'PRODUCT ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
              if (products.length > 1)
                IconButton(
                  onPressed: () => setState(() => products.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                ),
            ],
          ),
          row2(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Product', style: labelStyle)),
                    TextButton(
                      onPressed: () => setState(() => addingProductMaster = true),
                      child: const Text('+ New'),
                    ),
                  ],
                ),
                if (addingProductMaster) quickAddProductMaster() else selectField('', productsMaster, product.productId, (v) {
                  final opt = productsMaster.where((p) => p.value == v).firstOrNull;
                  setState(() {
                    product.productId = v;
                    product.productName = opt?.label ?? '';
                  });
                }, hint: 'Select product', hideLabel: true),
              ],
            ),
            field(
              'Quantity',
              TextEditingController(text: product.quantity),
              number: true,
              onChanged: (v) => product.quantity = v,
            ),
          ),
          field(
            'Description',
            TextEditingController(text: product.description),
            hint: 'Specification or notes',
            onChanged: (v) => product.description = v,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.factory_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'OEM / VENDORS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => addingOemMaster = true),
                child: const Text('+ Add to Master'),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () => setState(() => product.oems.add(OemRow())),
                icon: const Icon(Icons.add_circle_outline, size: 15),
                label: const Text('Add OEM Row'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (addingOemMaster) quickAddOemMaster(),
          const SizedBox(height: 8),
          if (product.oems.isEmpty)
            const SizedBox.shrink()
          else
            ...List.generate(product.oems.length, (oemIndex) => oemRow(index, oemIndex)),
        ],
      ),
    );
  }

  Widget quickAddProductMaster() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: plainField(newProductName, hint: 'Product name')),
          const SizedBox(width: 8),
          squareIconButton(savingProductMaster ? null : addProductMaster, Icons.save_outlined, primaryLight),
          const SizedBox(width: 6),
          squareIconButton(() {
            setState(() {
              addingProductMaster = false;
              newProductName.clear();
            });
          }, Icons.close, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget quickAddOemMaster() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(child: plainField(newOemName, hint: 'OEM name')),
          const SizedBox(width: 8),
          squareIconButton(savingOemMaster ? null : addOemMaster, Icons.save_outlined, primaryLight),
          const SizedBox(width: 6),
          squareIconButton(() {
            setState(() {
              addingOemMaster = false;
              newOemName.clear();
            });
          }, Icons.close, const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget oemRow(int productIndex, int oemIndex) {
    final product = products[productIndex];
    final oem = product.oems[oemIndex];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: selectField('', oemsMaster, oem.oemId, (v) {
              final opt = oemsMaster.where((o) => o.value == v).firstOrNull;
              setState(() {
                oem.oemId = v;
                oem.oemName = opt?.label ?? '';
              });
            }, hint: 'Select OEM', hideLabel: true),
          ),
          if (product.oems.length > 1) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => setState(() => product.oems.removeAt(oemIndex)),
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget notesSection() {
    return card(
      title: 'Description & Notes',
      subtitle: 'Update description and internal notes',
      icon: Icons.notes_outlined,
      children: [
        field('Product Description', productDescription, maxLines: 3),
        field('Notes', notes, maxLines: 3),
      ],
    );
  }

  Widget footer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.96),
          border: const Border(top: BorderSide(color: border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryDark,
                  side: const BorderSide(color: border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: saving ? null : saveOpportunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update Opportunity'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget card({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryLight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: text)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget field(
      String label,
      TextEditingController controller, {
        String? hint,
        bool number = false,
        bool digitsOnly = false,
        int? maxLength,
        int maxLines = 1,
        TextInputType? keyboardType,
        ValueChanged<String>? onChanged,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType ?? (number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
            onChanged: (v) {
              if (digitsOnly) {
                final cleaned = v.replaceAll(RegExp(r'\D'), '');
                final limited = maxLength == null || cleaned.length <= maxLength ? cleaned : cleaned.substring(0, maxLength);
                if (limited != v) {
                  controller.value = TextEditingValue(text: limited, selection: TextSelection.collapsed(offset: limited.length));
                }
                onChanged?.call(limited);
              } else {
                onChanged?.call(v);
              }
            },
            decoration: inputDecoration(hint),
          ),
        ],
      ),
    );
  }

  Widget plainField(TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      decoration: inputDecoration(hint),
    );
  }

  Widget dateField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            readOnly: true,
            decoration: inputDecoration('YYYY-MM-DD').copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            onTap: () async {
              final now = DateTime.now();
              final current = DateTime.tryParse(controller.text.trim());
              final picked = await showDatePicker(
                context: context,
                initialDate: current ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );

              if (picked != null) {
                controller.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            },
          ),
        ],
      ),
    );
  }

  Widget dropdown(String label, List<String> options, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            decoration: inputDecoration(null),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontWeight: FontWeight.w800)))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget selectField(
      String label,
      List<SelectOption> options,
      int? value,
      ValueChanged<int?> onChanged, {
        String? hint,
        bool hideLabel = false,
      }) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideLabel) ...[
            Text(label, style: labelStyle),
            const SizedBox(height: 6),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showOptionPicker(label.isEmpty ? hint ?? 'Select' : label, options, value);
              if (picked != -999999) {
                onChanged(picked == 0 ? null : picked);
              }
            },
            child: InputDecorator(
              decoration: inputDecoration(hint).copyWith(suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded)),
              child: Text(
                selected?.label ?? hint ?? 'Select',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected == null ? muted : text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> showOptionPicker(String title, List<SelectOption> options, int? selected) async {
    int result = -999999;
    final query = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) {
        List<SelectOption> filtered = options;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void filter(String text) {
              final term = text.toLowerCase().trim();
              setSheetState(() {
                filtered = term.isEmpty
                    ? options
                    : options.where((o) => o.label.toLowerCase().contains(term) || (o.subtitle ?? '').toLowerCase().contains(term)).toList();
              });
            }

            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * .72,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                    TextField(controller: query, onChanged: filter, decoration: inputDecoration('Search...')),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.clear_rounded),
                      title: const Text('Clear selection', style: TextStyle(fontWeight: FontWeight.w800)),
                      onTap: () {
                        result = 0;
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No options found'))
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final opt = filtered[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(opt.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: opt.subtitle == null ? null : Text(opt.subtitle!),
                            trailing: opt.value == selected ? const Icon(Icons.check_circle, color: primaryLight) : null,
                            onTap: () {
                              result = opt.value;
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    query.dispose();
    return result;
  }

  Widget row2(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: [a, b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget outlinedMiniButton(IconData icon, String text, VoidCallback onTap, {bool green = false}) {
    final color = green ? const Color(0xFF059669) : primaryLight;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(.25)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget squareIconButton(VoidCallback? onTap, IconData icon, Color color) {
    return SizedBox(
      height: 48,
      width: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Icon(icon, size: 17),
      ),
    );
  }

  InputDecoration inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryLight, width: 1.4)),
    );
  }

  List<SelectOption> _mapCustomers(dynamic data) {
    if (data is! List) return [];
    return data
        .where((x) => x is Map && safe(x['customer_name'], '').isNotEmpty)
        .map((x) => SelectOption(
      value: toInt(x['id']) ?? 0,
      label: safe(x['customer_name'], ''),
      approvalStatus: safe(x['approval_status'], '').toLowerCase().isEmpty
          ? null
          : safe(x['approval_status'], '').toLowerCase(),
    ))
        .where((x) => x.value != 0)
        .toList();
  }

  List<SelectOption> _mapSimple(dynamic data) {
    if (data is! List) return [];
    return data
        .where((x) => x is Map && safe(x['name'], '').isNotEmpty)
        .map((x) => SelectOption(value: toInt(x['id']) ?? 0, label: safe(x['name'], '')))
        .where((x) => x.value != 0)
        .toList();
  }

  List<SelectOption> _mapUsers(dynamic data) {
    if (data is! List) return [];
    return data
        .where((x) => x is Map && safe(x['label'], '').isNotEmpty)
        .map((x) => SelectOption(value: toInt(x['id']) ?? 0, label: safe(x['label'], '')))
        .where((x) => x.value != 0)
        .toList();
  }

  List<SelectOption> _mapBusinessUnits(dynamic data) {
    if (data is! List) return [];
    return data.where((x) => x is Map && toInt(x['id']) != null).map((x) {
      final unitName = safe(x['name'], '').isNotEmpty ? safe(x['name'], '') : safe(x['business_unit'], '');
      final vertical = firstNonEmpty([
        x['vertical_name'],
        x['category_name'],
        x['business_vertical'],
        x['business_category'],
      ]);
      return SelectOption(
        value: toInt(x['id']) ?? 0,
        label: unitName,
        subtitle: vertical.isEmpty ? null : 'Vertical: $vertical',
      );
    }).where((x) => x.value != 0 && x.label.isNotEmpty).toList();
  }

  static const TextStyle labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: Color(0xFF304050),
  );

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: primaryDark, behavior: SnackBarBehavior.floating),
    );
  }

  String apiError(Map res, {String fallback = 'Request failed'}) {
    final data = res['data'];
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is List) {
        return detail.map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString()).join(', ');
      }
      return detail.toString();
    }
    if (data is List) return data.map((e) => e.toString()).join(', ');
    return data?.toString() ?? fallback;
  }

  String safe(dynamic value, [String fallback = '-']) {
    final textValue = value?.toString().trim() ?? '';
    return textValue.isEmpty || textValue.toLowerCase() == 'null' ? fallback : textValue;
  }

  String dateOnly(dynamic value) {
    final raw = safe(value, '');
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  String firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final textValue = safe(value, '');
      if (textValue.isNotEmpty) return textValue;
    }
    return '';
  }

  int? toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}


class ProductRow {
  int? productId;
  String productName;
  String quantity;
  String description;
  List<OemRow> oems;

  ProductRow({
    this.productId,
    this.productName = '',
    this.quantity = '1',
    this.description = '',
    List<OemRow>? oems,
  }) : oems = oems ?? [];

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': double.tryParse(quantity.trim()) ?? 1,
      'description': description,
      'oems': oems.where((o) => o.oemName.trim().isNotEmpty).map((o) => o.toJson()).toList(),
    };
  }
}

class OemRow {
  int? oemId;
  String oemName;

  OemRow({
    this.oemId,
    this.oemName = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'oem_id': oemId,
      'oem_name': oemName,
    };
  }
}

extension FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


// -----------------------------------------------------------------------------
// Web-equivalent Direct Opportunity tabs screen.
// This is the Flutter equivalent of OpportunityView.tsx tab landing logic:
// - direct_opportunity shows Lead Details, Quotations, PO Details, Consignee, Work Orders
// - initialTab from create flow opens Quotations immediately
// - if there is a Work Order, open Work Orders
// - else if an Accepted quotation exists, open PO
// - else if any quotation exists, open Quotations
// - PO / Consignee / Work Order stay locked until prerequisites are complete
// -----------------------------------------------------------------------------

enum OpportunityTabKey { lead, quotations, po, consignee, workorder }

extension OpportunityTabKeyX on OpportunityTabKey {
  String get apiKey {
    switch (this) {
      case OpportunityTabKey.lead:
        return 'lead';
      case OpportunityTabKey.quotations:
        return 'quotations';
      case OpportunityTabKey.po:
        return 'po';
      case OpportunityTabKey.consignee:
        return 'consignee';
      case OpportunityTabKey.workorder:
        return 'workorder';
    }
  }

  String get label {
    switch (this) {
      case OpportunityTabKey.lead:
        return 'Opportunity Details';
      case OpportunityTabKey.quotations:
        return 'Quotations';
      case OpportunityTabKey.po:
        return 'PO Details';
      case OpportunityTabKey.consignee:
        return 'Consignee';
      case OpportunityTabKey.workorder:
        return 'Work Orders';
    }
  }

  IconData get icon {
    switch (this) {
      case OpportunityTabKey.lead:
        return Icons.business_outlined;
      case OpportunityTabKey.quotations:
        return Icons.description_outlined;
      case OpportunityTabKey.po:
        return Icons.currency_rupee_rounded;
      case OpportunityTabKey.consignee:
        return Icons.local_shipping_outlined;
      case OpportunityTabKey.workorder:
        return Icons.assignment_outlined;
    }
  }
}

class OpportunityDirectTabsPage extends StatefulWidget {
  final String tenantSlug;
  final String baseUrl;
  final int leadId;
  final OpportunityTabKey? initialTab;

  const OpportunityDirectTabsPage({
    super.key,
    required this.tenantSlug,
    required this.leadId,
    this.baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1',
    this.initialTab,
  });

  @override
  State<OpportunityDirectTabsPage> createState() => _OpportunityDirectTabsPageState();
}

class _OpportunityDirectTabsPageState extends State<OpportunityDirectTabsPage> {
  String? token;
  bool loading = true;
  bool isWon = false;
  bool hasAcceptedQuotation = false;
  bool hasPO = false;
  String? error;

  Map<String, dynamic>? lead;
  Map<String, dynamic>? workOrder;
  Map<String, dynamic>? po;
  List<Map<String, dynamic>> quotations = [];
  List<Map<String, dynamic>> consignees = [];

  OpportunityTabKey activeTab = OpportunityTabKey.lead;
  final Map<OpportunityTabKey, String> tabStatuses = {};
  bool _autoTabApplied = false;

  String get apiBase => widget.baseUrl.endsWith('/')
      ? widget.baseUrl.substring(0, widget.baseUrl.length - 1)
      : widget.baseUrl;

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${token ?? ''}',
    'X-Tenant-Slug': widget.tenantSlug,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    activeTab = widget.initialTab ?? OpportunityTabKey.lead;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
      if (token == null || token!.isEmpty) {
        throw Exception('Token not found');
      }

      final leadRes = await ApiMethod.getRequest(
        url: '$apiBase/leads/${widget.leadId}',
        headers: headers,
      );
      if (leadRes['statusCode'] != 200 || leadRes['data'] is! Map) {
        throw Exception(_apiText(leadRes['data'], 'Failed to load opportunity'));
      }
      lead = Map<String, dynamic>.from(leadRes['data']);

      workOrder = await _getMapOrNull('$apiBase/workorders/by-lead/${widget.leadId}');
      quotations = await _getList('$apiBase/quotations/by-lead/${widget.leadId}');
      po = await _getMapOrNull('$apiBase/opportunity-po/by-lead/${widget.leadId}')
          ?? await _getMapOrNull('$apiBase/opportunity-po/${widget.leadId}');
      consignees = await _getList('$apiBase/consignees/by-lead/${widget.leadId}');
      if (consignees.isEmpty) {
        consignees = await _getList('$apiBase/opportunity-consignees/by-lead/${widget.leadId}');
      }

      hasAcceptedQuotation = quotations.any((q) => q['status'] == 'Accepted');
      hasPO = po != null && (po!['id'] != null || _safe(po!['po_number']).isNotEmpty);

      final woStatus = _safe(workOrder?['wo_status'], '');
      isWon = woStatus == 'Won' || woStatus == 'Completed';

      tabStatuses.clear();
      if (quotations.isNotEmpty) {
        final accepted = quotations.where((q) => q['status'] == 'Accepted').firstOrNull;
        tabStatuses[OpportunityTabKey.quotations] = _safe(accepted?['status'], _safe(quotations.first['status'], 'Draft'));
      }
      if (hasPO) tabStatuses[OpportunityTabKey.po] = _safe(po?['wo_status'], 'done');
      if (consignees.isNotEmpty) tabStatuses[OpportunityTabKey.consignee] = 'done';
      if (workOrder != null) tabStatuses[OpportunityTabKey.workorder] = _safe(workOrder?['wo_status'], 'Draft');

      if (isWon) {
        tabStatuses[OpportunityTabKey.quotations] ??= 'Won';
        tabStatuses[OpportunityTabKey.po] ??= 'Won';
        tabStatuses[OpportunityTabKey.consignee] ??= 'done';
        tabStatuses[OpportunityTabKey.workorder] ??= 'Won';
      }

      if (!_autoTabApplied) {
        _autoTabApplied = true;
        if (widget.initialTab != null) {
          activeTab = widget.initialTab!;
        } else if (isWon || workOrder != null) {
          activeTab = OpportunityTabKey.workorder;
        } else if (hasAcceptedQuotation) {
          activeTab = OpportunityTabKey.po;
        } else if (quotations.isNotEmpty) {
          activeTab = OpportunityTabKey.quotations;
        } else {
          activeTab = OpportunityTabKey.lead;
        }
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>?> _getMapOrNull(String url) async {
    try {
      final r = await ApiMethod.getRequest(url: url, headers: headers);
      if (r['statusCode'] == 200 && r['data'] is Map) {
        return Map<String, dynamic>.from(r['data']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String url) async {
    try {
      final r = await ApiMethod.getRequest(url: url, headers: headers);
      if (r['statusCode'] == 200 && r['data'] is List) {
        return (r['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  bool _isLocked(OpportunityTabKey tab) {
    if (isWon) return false;
    if (!hasAcceptedQuotation &&
        (tab == OpportunityTabKey.po || tab == OpportunityTabKey.consignee || tab == OpportunityTabKey.workorder)) {
      return true;
    }
    if (hasAcceptedQuotation && !hasPO &&
        (tab == OpportunityTabKey.consignee || tab == OpportunityTabKey.workorder)) {
      return true;
    }
    return false;
  }

  void _changeTab(OpportunityTabKey tab) {
    if (_isLocked(tab)) {
      _snack(_lockMessage(tab), Colors.orange);
      return;
    }
    setState(() => activeTab = tab);
  }

  String _lockMessage(OpportunityTabKey tab) {
    if (tab == OpportunityTabKey.po) return 'Accept a quotation first to unlock PO Details.';
    if (tab == OpportunityTabKey.consignee || tab == OpportunityTabKey.workorder) {
      return hasAcceptedQuotation
          ? 'Save PO Details first to unlock this tab.'
          : 'Accept a quotation and save PO Details first.';
    }
    return 'This tab is locked.';
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
      );
    }

    if (error != null || lead == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: Colors.white, foregroundColor: AppColors.text, title: const Text('Opportunity')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 34),
                const SizedBox(height: 10),
                Text(error ?? 'Opportunity not found', textAlign: TextAlign.center),
                const SizedBox(height: 14),
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _tabsBar(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryLight,
                onRefresh: _loadAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [_activeBody()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final title = _safe(lead?['lead_title'], 'Opportunity');
    final customer = _safe(lead?['customer_name'], '-');
    final estValue = _money(lead?['est_value']);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primarySlate),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_safe(lead?['lead_ref_id']).isNotEmpty)
                      _miniBadge(_safe(lead?['lead_ref_id']), const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                    const SizedBox(width: 6),
                    _miniBadge('Direct Opportunity', AppColors.purple, const Color(0xFFFAF5FF)),
                    if (isWon) ...[
                      const SizedBox(width: 6),
                      _miniBadge('Won - Read Only', const Color(0xFF059669), const Color(0xFFECFDF5)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                const SizedBox(height: 3),
                Text(
                  '$customer  •  $estValue',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primarySlate),
          ),
        ],
      ),
    );
  }

  Widget _tabsBar() {
    final tabs = OpportunityTabKey.values;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final active = tab == activeTab;
            final locked = _isLocked(tab);
            final status = tabStatuses[tab];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _changeTab(tab),
                  child: SizedBox(
                    width: 118,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: locked
                                ? const Color(0xFFF1F5F9)
                                : active
                                ? AppColors.primaryLight
                                : _isDone(status)
                                ? const Color(0xFF10B981)
                                : Colors.white,
                            border: Border.all(
                              color: locked
                                  ? const Color(0xFFE2E8F0)
                                  : active
                                  ? const Color(0xFFDBEAFE)
                                  : _isDone(status)
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFDBEAFE),
                              width: 5,
                            ),
                          ),
                          child: Icon(
                            locked ? Icons.lock_outline_rounded : (_isDone(status) ? Icons.check_rounded : tab.icon),
                            size: 16,
                            color: locked ? const Color(0xFF94A3B8) : (active || _isDone(status) ? Colors.white : AppColors.primaryLight),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: locked
                                ? const Color(0xFF94A3B8)
                                : active
                                ? AppColors.primaryLight
                                : const Color(0xFF334155),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(height: 5),
                          _smallTabBadge('Locked', const Color(0xFF64748B), const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)),
                        ] else if (status != null) ...[
                          const SizedBox(height: 5),
                          _smallTabBadge(_statusLabel(status), _statusColor(status), _statusBg(status), _statusBorder(status)),
                        ],
                      ],
                    ),
                  ),
                ),
                if (index < tabs.length - 1)
                  Container(
                    margin: const EdgeInsets.only(top: 20, left: 8, right: 8),
                    width: 54,
                    height: 2,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _activeBody() {
    switch (activeTab) {
      case OpportunityTabKey.lead:
        return _leadDetailsTab();
      case OpportunityTabKey.quotations:
        return _quotationsTab();
      case OpportunityTabKey.po:
        return _poTab();
      case OpportunityTabKey.consignee:
        return _consigneeTab();
      case OpportunityTabKey.workorder:
        return OpportunityWorkOrderTab(
          apiBase: apiBase,
          headers: headers,
          lead: lead!,
          existingWorkOrder: workOrder,
          onChanged: () async {
            await _loadAll();
            setState(() => activeTab = OpportunityTabKey.workorder);
          },
        );
    }
  }

  Widget _leadDetailsTab() {
    return _sectionCard(
      title: 'Opportunity Details',
      icon: Icons.business_outlined,
      action: isWon ? null : TextButton.icon(
        onPressed: () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewOpportunityFlutterWebLogic(
                tenantSlug: widget.tenantSlug,
                baseUrl: apiBase,
                userRole: '',
                isEditMode: true,
                editLeadId: widget.leadId,
                initialData: lead,
              ),
            ),
          );
          if (updated == true) _loadAll();
        },
        icon: const Icon(Icons.edit_outlined, size: 15),
        label: const Text('Edit'),
      ),
      children: [
        _infoGrid([
          _InfoItem('Customer', _safe(lead?['customer_name']), Icons.business_center_outlined),
          _InfoItem('Contact Person', _safe(lead?['contact_person']), Icons.person_outline),
          _InfoItem('Mobile', _safe(lead?['mobile']), Icons.phone_outlined),
          _InfoItem('Email', _safe(lead?['email']), Icons.mail_outline),
          _InfoItem('Estimated Value', _money(lead?['est_value']), Icons.currency_rupee_rounded),
          _InfoItem('Priority', _safe(lead?['priority']), Icons.flag_outlined),
          _InfoItem('Timeline', _dateText(lead?['timeline']), Icons.calendar_month_outlined),
          _InfoItem('Follow Up', _dateText(lead?['follow_up']), Icons.schedule_outlined),
        ]),
        const SizedBox(height: 12),
        _productSummary(),
      ],
    );
  }

  Widget _productSummary() {
    final raw = lead?['products'];
    if (raw is! List || raw.isEmpty) {
      return _emptyBox(Icons.inventory_2_outlined, 'No products added', 'Add products in Opportunity Details.');
    }
    return Column(
      children: raw.whereType<Map>().map((p) {
        final oems = p['oems'] is List
            ? (p['oems'] as List).whereType<Map>().map((o) => _safe(o['oem_name'])).where((x) => x.isNotEmpty).join(', ')
            : '';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_safe(p['product_name'], 'Product'), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.text)),
              const SizedBox(height: 4),
              Text('Qty: ${_safe(p['quantity'], '1')}', style: const TextStyle(fontSize: 12, color: AppColors.primarySlate)),
              if (oems.isNotEmpty) Text('OEM: $oems', style: const TextStyle(fontSize: 12, color: AppColors.primarySlate)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _quotationsTab() {
    return _sectionCard(
      title: 'Quotations',
      icon: Icons.description_outlined,
      action: isWon ? null : ElevatedButton.icon(
        onPressed: () => _snack('Open your Flutter quotation form here.', AppColors.primaryLight),
        icon: const Icon(Icons.add, size: 15),
        label: const Text('New'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      children: [
        if (quotations.isEmpty)
          _emptyBox(Icons.description_outlined, 'No Quotations Found', 'Create a quotation. Once a quotation is Accepted, PO Details unlock.')
        else
          ...quotations.map(_quotationCard),
      ],
    );
  }

  Widget _quotationCard(Map<String, dynamic> q) {
    final status = _safe(q['status'], 'Draft');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.description_outlined, color: AppColors.primaryLight, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_safe(q['quotation_number'], 'Quotation'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(_safe(q['subject'], 'No subject'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              _smallTabBadge(status, _statusColor(status), _statusBg(status), _statusBorder(status)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_money(q['total_amount']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text)),
        ],
      ),
    );
  }

  Widget _poTab() {
    if (!hasPO) {
      return _emptyBox(Icons.warning_amber_rounded, 'No PO Details Found', 'Save PO Details first. Consignee and Work Orders unlock after PO data is saved.');
    }
    return _sectionCard(
      title: 'PO Details',
      icon: Icons.currency_rupee_rounded,
      action: isWon ? null : TextButton.icon(
        onPressed: () => _snack('Open your Flutter PO form here.', AppColors.primaryLight),
        icon: const Icon(Icons.edit_outlined, size: 15),
        label: const Text('Edit'),
      ),
      children: [
        _infoGrid([
          _InfoItem('PO Number', _safe(po?['po_number']), Icons.numbers_outlined),
          _InfoItem('PO Date', _dateText(po?['po_date']), Icons.calendar_month_outlined),
          _InfoItem('PO Value', _money(po?['po_value']), Icons.currency_rupee_rounded),
          _InfoItem('WO Value', _money(po?['wo_value']), Icons.payments_outlined),
          _InfoItem('Delivery Date', _dateText(po?['delivery_date']), Icons.local_shipping_outlined),
          _InfoItem('Site Location', _safe(po?['site_location']), Icons.location_on_outlined),
        ]),
      ],
    );
  }

  Widget _consigneeTab() {
    return _sectionCard(
      title: 'Consignee',
      icon: Icons.local_shipping_outlined,
      action: isWon ? null : ElevatedButton.icon(
        onPressed: () => _snack('Open your Flutter consignee form here.', AppColors.primaryLight),
        icon: const Icon(Icons.add, size: 15),
        label: const Text('Add'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      children: [
        if (consignees.isEmpty)
          _emptyBox(Icons.location_on_outlined, 'No Consignees Found', 'Add delivery destination details.')
        else
          ...consignees.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_safe(c['consignee_name'], 'Consignee'), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text([_safe(c['address']), _safe(c['city']), _safe(c['state']), _safe(c['pincode'])].where((x) => x.isNotEmpty).join(', '), style: const TextStyle(fontSize: 12, color: AppColors.primarySlate)),
                if (_safe(c['contact_person']).isNotEmpty) Text('Contact: ${_safe(c['contact_person'])} ${_safe(c['contact_phone'])}', style: const TextStyle(fontSize: 12, color: AppColors.primarySlate)),
              ],
            ),
          )),
      ],
    );
  }

  Widget _sectionCard({required String title, required IconData icon, Widget? action, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.primaryDeep.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primaryLight, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text))),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoGrid(List<_InfoItem> items) {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 520;
      if (!twoCols) {
        return Column(children: items.map(_infoTile).toList());
      }
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) => SizedBox(width: (c.maxWidth - 10) / 2, child: _infoTile(item))).toList(),
      );
    });
  }

  Widget _infoTile(_InfoItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: AppColors.muted, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w900, letterSpacing: .5)),
                const SizedBox(height: 3),
                Text(item.value.isEmpty ? '-' : item.value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFF59E0B), size: 32),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: fg.withOpacity(.16))),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }

  Widget _smallTabBadge(String text, Color fg, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg)),
    );
  }

  bool _isDone(String? status) => status == 'done' || status == 'Accepted' || status == 'Completed' || status == 'Won';

  String _statusLabel(String status) => status == 'Won' ? 'Won' : _isDone(status) ? 'Done' : status;

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted':
      case 'Completed':
      case 'Won':
      case 'done':
        return const Color(0xFF047857);
      case 'Rejected':
      case 'Lost':
        return const Color(0xFFDC2626);
      case 'Pending':
      case 'Draft':
        return const Color(0xFFD97706);
      default:
        return AppColors.primaryLight;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'Accepted':
      case 'Completed':
      case 'Won':
      case 'done':
        return const Color(0xFFECFDF5);
      case 'Rejected':
      case 'Lost':
        return const Color(0xFFFEF2F2);
      case 'Pending':
      case 'Draft':
        return const Color(0xFFFFFBEB);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _statusBorder(String status) {
    switch (status) {
      case 'Accepted':
      case 'Completed':
      case 'Won':
      case 'done':
        return const Color(0xFFA7F3D0);
      case 'Rejected':
      case 'Lost':
        return const Color(0xFFFECACA);
      case 'Pending':
      case 'Draft':
        return const Color(0xFFFDE68A);
      default:
        return const Color(0xFFBFDBFE);
    }
  }
}

class OpportunityWorkOrderTab extends StatefulWidget {
  final String apiBase;
  final Map<String, String> headers;
  final Map<String, dynamic> lead;
  final Map<String, dynamic>? existingWorkOrder;
  final Future<void> Function()? onChanged;

  const OpportunityWorkOrderTab({
    super.key,
    required this.apiBase,
    required this.headers,
    required this.lead,
    this.existingWorkOrder,
    this.onChanged,
  });

  @override
  State<OpportunityWorkOrderTab> createState() => _OpportunityWorkOrderTabState();
}

class _OpportunityWorkOrderTabState extends State<OpportunityWorkOrderTab> {
  Map<String, dynamic>? po;
  bool loading = true;
  bool saving = false;
  bool editing = false;
  String status = 'Draft';

  static const List<String> woStatuses = ['Won', 'Lost'];

  @override
  void initState() {
    super.initState();
    po = widget.existingWorkOrder;
    if (po != null) {
      status = _safe(po?['wo_status'], 'Draft');
      loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final id = widget.lead['id'];
      final r = await ApiMethod.getRequest(url: '${widget.apiBase}/workorders/by-lead/$id', headers: widget.headers);
      if (r['statusCode'] == 200 && r['data'] is Map) {
        po = Map<String, dynamic>.from(r['data']);
        status = _safe(po?['wo_status'], 'Draft');
      } else {
        po = null;
      }
    } catch (_) {
      po = null;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _update() async {
    if (po?['id'] == null) return;
    setState(() => saving = true);
    try {
      final id = po!['id'];
      final uri = Uri.parse('${widget.apiBase}/workorders/$id/progress').replace(
        queryParameters: {'progress': '0', 'status': status},
      );
      final request = http.Request('PATCH', uri);
      request.headers.addAll(widget.headers);
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        _snack('Work Order status updated', Colors.green);
        setState(() => editing = false);
        await _load();
        await widget.onChanged?.call();
      } else {
        _snack(_apiText(body, 'Failed to update status'), Colors.red);
      }
    } catch (e) {
      _snack(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryLight)),
      );
    }

    if (po == null) {
      return _emptyBox(Icons.warning_amber_rounded, 'No Work Order Found', 'Complete PO Details first. The Work Order becomes available once PO data is saved.');
    }

    final currentStatus = _safe(po?['wo_status'], 'Draft');
    final currentProgress = _toIntLocal(po?['progress_percent']) ?? 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: AppColors.primaryDeep.withOpacity(.04), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(color: const Color(0xFFFAF5FF), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.assignment_outlined, color: AppColors.purple, size: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(_safe(po?['po_number'], '-'), style: const TextStyle(fontSize: 16, color: AppColors.text, fontWeight: FontWeight.w900)),
                            _statusBadge(currentStatus),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(_safe(po?['project_title'], _safe(widget.lead['lead_title'])), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (!editing && !['Won', 'Lost', 'Completed'].contains(currentStatus))
                    TextButton(
                      onPressed: () => setState(() {
                        status = woStatuses.contains(currentStatus) ? currentStatus : woStatuses.first;
                        editing = true;
                      }),
                      child: const Text('Edit Status'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _metricsGrid([
                _InfoItem('PO Value', _money(po?['po_value']), Icons.currency_rupee_rounded),
                _InfoItem('WO Value', _money(po?['wo_value']), Icons.payments_outlined),
                _InfoItem('Delivery Date', _dateText(po?['delivery_date']), Icons.calendar_month_outlined),
              ]),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Progress', style: TextStyle(fontSize: 12, color: AppColors.primarySlate, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('$currentProgress%', style: const TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (currentProgress.clamp(0, 100)) / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: AppColors.primaryLight,
                ),
              ),
              if (!editing) ...[
                const SizedBox(height: 16),
                _metricsGrid([
                  if (_safe(po?['wo_type']).isNotEmpty) _InfoItem('WO Type', _safe(po?['wo_type']), Icons.category_outlined),
                  if (_safe(po?['site_location']).isNotEmpty) _InfoItem('Site Location', _safe(po?['site_location']), Icons.location_on_outlined),
                  if (_safe(po?['installation_date']).isNotEmpty) _InfoItem('Installation Date', _dateText(po?['installation_date']), Icons.calendar_today_outlined),
                  if (_safe(po?['warranty_months']).isNotEmpty) _InfoItem('Warranty', '${_safe(po?['warranty_months'])} months', Icons.verified_outlined),
                ]),
              ],
            ],
          ),
        ),
        if (editing) _editStatusCard(currentStatus),
      ],
    );
  }

  Widget _editStatusCard(String currentStatus) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('UPDATE STATUS & PROGRESS', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w900, letterSpacing: .6)),
          const SizedBox(height: 12),
          const Text('Outcome', style: TextStyle(fontSize: 12, color: AppColors.primarySlate, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: status,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
            items: woStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: saving ? null : (v) => setState(() => status = v ?? woStatuses.first),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : () => setState(() {
                    editing = false;
                    status = currentStatus;
                  }),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: saving ? null : _update,
                  icon: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(saving ? 'Saving...' : 'Update'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(List<_InfoItem> items) {
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final count = width >= 680 ? 3 : width >= 430 ? 2 : 1;
      final itemWidth = (width - ((count - 1) * 10)) / count;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) => SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(13)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(item.icon, color: AppColors.muted, size: 14), const SizedBox(width: 5), Expanded(child: Text(item.label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w800)))]),
                const SizedBox(height: 4),
                Text(item.value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        )).toList(),
      );
    });
  }

  Widget _statusBadge(String status) {
    final colors = _woStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors[1],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors[2]),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: colors[0], fontWeight: FontWeight.w900),
      ),
    );
  }

  List<Color> _woStatusColors(String status) {
    switch (status) {
      case 'Won':
      case 'Completed':
        return const [Color(0xFF047857), Color(0xFFECFDF5), Color(0xFFA7F3D0)];
      case 'Lost':
        return const [Color(0xFFDC2626), Color(0xFFFEF2F2), Color(0xFFFECACA)];
      default:
        return const [Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFDE68A)];
    }
  }

  Widget _emptyBox(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFDE68A))),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFF59E0B), size: 32),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  final IconData icon;
  _InfoItem(this.label, this.value, this.icon);
}

String _safe(dynamic value, [String fallback = '']) {
  final s = value?.toString().trim() ?? '';
  if (s.isEmpty || s.toLowerCase() == 'null') return fallback;
  return s;
}

String _apiText(dynamic raw, String fallback) {
  if (raw == null) return fallback;
  try {
    final data = raw is String ? jsonDecode(raw) : raw;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List) return detail.map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString()).join(', ');
    }
  } catch (_) {}
  final s = raw.toString();
  return s.isEmpty ? fallback : s;
}

int? _toIntLocal(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String _money(dynamic raw) {
  final n = double.tryParse((raw ?? 0).toString()) ?? 0;
  if (n == 0) return '-';
  if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1)}Cr';
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
  return '₹${n.toStringAsFixed(2)}';
}

String _dateText(dynamic value) {
  final s = _safe(value);
  if (s.isEmpty) return '-';
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
}
