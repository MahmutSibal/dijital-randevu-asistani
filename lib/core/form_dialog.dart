import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A field in [showFormDialog]. Give [options] (value → label) to make it a dropdown.
class FormFieldSpec {
  const FormFieldSpec(
    this.key,
    this.label, {
    this.obscure = false,
    this.keyboardType,
    this.options,
    this.optional = false,
    this.minLength,
  });

  final String key;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final Map<Object, String>? options;
  final bool optional;
  final int? minLength;
}

/// Shows a dark dialog with [fields] and returns the entered values, or null if cancelled.
/// Text fields come back trimmed; dropdowns return the selected option key.
Future<Map<String, Object?>?> showFormDialog(
  BuildContext context, {
  required String title,
  required List<FormFieldSpec> fields,
  String submitLabel = 'KAYDET',
}) {
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (_) =>
        _FormDialog(title: title, fields: fields, submitLabel: submitLabel),
  );
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.fields,
    required this.submitLabel,
  });

  final String title;
  final List<FormFieldSpec> fields;
  final String submitLabel;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _form = GlobalKey<FormState>();
  late final _text = {
    for (final f in widget.fields)
      if (f.options == null) f.key: TextEditingController(),
  };
  final _choice = <String, Object?>{};

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(FormFieldSpec f, Object? value) {
    final text = value is String ? value.trim() : value;
    if (!f.optional && (text == null || text == '')) {
      return 'Bu alan zorunludur.';
    }
    if (f.minLength != null &&
        text is String &&
        text.isNotEmpty &&
        text.length < f.minLength!) {
      return 'En az ${f.minLength} karakter olmalıdır.';
    }
    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {
      for (final f in widget.fields)
        f.key: f.options == null ? _text[f.key]!.text.trim() : _choice[f.key],
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: f.options == null
                        ? TextFormField(
                            controller: _text[f.key],
                            obscureText: f.obscure,
                            keyboardType: f.keyboardType,
                            decoration: InputDecoration(labelText: f.label),
                            validator: (v) => _validate(f, v),
                          )
                        : DropdownButtonFormField<Object>(
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceHigh,
                            decoration: InputDecoration(labelText: f.label),
                            items: [
                              for (final e in f.options!.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => _choice[f.key] = v,
                            validator: (v) => _validate(f, v),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.surfaceHigh),
          onPressed: () => Navigator.pop(context),
          child: const Text('İPTAL'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}
