// widgets/searchable_select.dart
//
// Lightweight searchable single-select dropdown — Flutter equivalent of the
// web <SearchableSelect>. Opens a bottom sheet with a filter box.

import 'package:flutter/material.dart';

class SelectOpt {
  final int value;
  final String label;
  final String? approvalStatus;
  final String? subtitle;
  SelectOpt(this.value, this.label, {this.approvalStatus, this.subtitle});
}

class SearchableSelect extends StatelessWidget {
  final String? label;
  final List<SelectOpt> options;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String placeholder;
  final bool clearable;
  final bool required;
  final String? error;

  const SearchableSelect({
    super.key,
    this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select',
    this.clearable = false,
    this.required = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        options.where((o) => o.value == value).cast<SelectOpt?>().firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                children: required
                    ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                    : const [],
              ),
            ),
          ),
        InkWell(
          onTap: () => _openSheet(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: error != null ? const Color(0xFFF87171) : const Color(0xFFD1D5DB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        color: selected == null ? const Color(0xFF9CA3AF) : const Color(0xFF111827)),
                  ),
                ),
                if (clearable && selected != null)
                  InkWell(
                    onTap: () => onChanged(null),
                    child: const Icon(Icons.close, size: 15, color: Color(0xFF9CA3AF)),
                  ),
                const Icon(Icons.expand_more, size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
      ],
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _SelectSheet(
        title: label ?? 'Select',
        options: options,
        value: value,
        onSelected: (v) {
          onChanged(v);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _SelectSheet extends StatefulWidget {
  final String title;
  final List<SelectOpt> options;
  final int? value;
  final ValueChanged<int> onSelected;

  const _SelectSheet({
    required this.title,
    required this.options,
    required this.value,
    required this.onSelected,
  });

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => o.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final o = filtered[i];
                  final sel = o.value == widget.value;
                  return ListTile(
                    title: Text(o.label, style: const TextStyle(fontSize: 14)),
                    subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
                    trailing: sel ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
                    selected: sel,
                    onTap: () => widget.onSelected(o.value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
