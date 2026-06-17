// widgets/ui.dart
//
// Shared presentational widgets used across the Opportunity tabs, styled to
// match the web (Tailwind) look as closely as Flutter allows.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/opportunity_lead.dart';
import 'searchable_select.dart';

// ─── Toast ──────────────────────────────────────────────────────────────────

class Toast {
  static void success(BuildContext c, String msg) => _show(c, msg, const Color(0xFF059669));
  static void error(BuildContext c, String msg) => _show(c, msg, const Color(0xFFDC2626));
  static void info(BuildContext c, String msg) => _show(c, msg, const Color(0xFF334155));

  static void _show(BuildContext c, String msg, Color bg) {
    ScaffoldMessenger.of(c)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const Section({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 0,
                      maxWidth: 150,
                      minHeight: 40,
                    ),
                    child: IntrinsicWidth(
                      child: action!,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF64748B)));
}

// ─── Info row (read-only key/value) ───────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool wide;
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardW = wide ? double.infinity : (w - 32 - 10) / 2;
    return SizedBox(
      width: wide ? double.infinity : cardW,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Color(0xFF94A3B8))),
            const SizedBox(height: 3),
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(value.isEmpty ? '—' : value,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: valueColor ?? const Color(0xFF1E293B))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Labeled field wrapper ────────────────────────────────────────────────────

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;
  const LabeledField({super.key, required this.label, required this.child, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
            children: required
                ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : const [],
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

// ─── Text input ───────────────────────────────────────────────────────────────

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final bool digitsOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const AppInput({
    super.key,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.digitsOnly = false,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      inputFormatters: [
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3B82F6))),
      ),
    );
  }
}

// ─── Dropdown ─────────────────────────────────────────────────────────────────

class AppDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  const AppDropdown({super.key, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      ),
      items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text('$e'))).toList(),
      onChanged: onChanged,
    );
  }
}

// ─── Date field ───────────────────────────────────────────────────────────────

class DateField extends StatelessWidget {
  final String value; // yyyy-MM-dd
  final ValueChanged<String> onChanged;
  final DateTime? firstDate;
  const DateField({super.key, required this.value, required this.onChanged, this.firstDate});

  @override
  Widget build(BuildContext context) {
    final parsed = value.isNotEmpty ? DateTime.tryParse(value) : null;
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? now,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: DateTime(now.year + 10),
        );
        if (picked != null) onChanged(DateFormat('yyyy-MM-dd').format(picked));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD1D5DB))),
        child: Row(
          children: [
            Expanded(
              child: Text(parsed != null ? DateFormat('dd MMM yyyy').format(parsed) : 'Select date',
                  style: TextStyle(
                      fontSize: 14,
                      color: parsed != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
            ),
            const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ─── Status pill ───────────────────────────────────────────────────────────────

class StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final Color? border;
  const StatusPill(this.text, {super.key, required this.bg, required this.fg, this.border});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

// ─── Products editor (shared by Lead Details edit + New Opportunity) ───────────

class ProductsEditor extends StatelessWidget {
  final List<ProdEntry> products;
  final List<SelectOpt> productOptions;
  final List<SelectOpt> oemOptions;
  final ValueChanged<List<ProdEntry>> onChanged;

  const ProductsEditor({
    super.key,
    required this.products,
    required this.productOptions,
    required this.oemOptions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int pi = 0; pi < products.length; pi++) _productCard(pi),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => onChanged([...products, ProdEntry()]),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 2, style: BorderStyle.solid),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text('Add Product',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _productCard(int pi) {
    final prod = products[pi];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 4),
              Text('Product ${pi + 1}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
              const Spacer(),
              if (products.length > 1)
                InkWell(
                  onTap: () => onChanged([...products]..removeAt(pi)),
                  child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFF87171)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SearchableSelect(
                  label: 'Product',
                  options: productOptions,
                  value: prod.productId,
                  onChanged: (v) {
                    final opt = productOptions.where((o) => o.value == v).cast<SelectOpt?>().firstOrNull;
                    final copy = [...products];
                    copy[pi] = ProdEntry(
                      productId: v,
                      productName: opt?.label ?? '',
                      quantity: prod.quantity,
                      description: prod.description,
                      oems: [OemEntry()],
                    );
                    onChanged(copy);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: LabeledField(
                  label: 'Qty',
                  child: AppInput(
                    controller: TextEditingController(text: prod.quantity)
                      ..selection = TextSelection.collapsed(offset: prod.quantity.length),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final copy = [...products];
                      copy[pi].quantity = v;
                      onChanged(copy);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: 'Description',
            child: AppInput(
              controller: TextEditingController(text: prod.description)
                ..selection = TextSelection.collapsed(offset: prod.description.length),
              hint: 'Spec / notes',
              onChanged: (v) {
                final copy = [...products];
                copy[pi].description = v;
                onChanged(copy);
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Icon(Icons.factory_outlined, size: 10, color: Color(0xFF64748B)),
              SizedBox(width: 4),
              Text('OEM / VENDORS',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 6),
          for (int oi = 0; oi < prod.oems.length; oi++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: SearchableSelect(
                      options: oemOptions,
                      value: prod.oems[oi].oemId,
                      placeholder: 'Select OEM',
                      onChanged: (v) {
                        final opt = oemOptions.where((o) => o.value == v).cast<SelectOpt?>().firstOrNull;
                        final copy = [...products];
                        copy[pi].oems[oi] = OemEntry(oemId: v, oemName: opt?.label ?? '');
                        onChanged(copy);
                      },
                    ),
                  ),
                  if (prod.oems.length > 1)
                    InkWell(
                      onTap: () {
                        final copy = [...products];
                        copy[pi].oems.removeAt(oi);
                        onChanged(copy);
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.close, size: 14, color: Color(0xFFF87171)),
                      ),
                    ),
                ],
              ),
            ),
          InkWell(
            onTap: () {
              final copy = [...products];
              copy[pi].oems.add(OemEntry());
              onChanged(copy);
            },
            child: const Row(
              children: [
                Icon(Icons.add, size: 10, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text('Add OEM',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
