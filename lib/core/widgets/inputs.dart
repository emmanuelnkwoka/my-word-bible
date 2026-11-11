import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

/// Labelled text input with validation support.
class MwbTextField extends StatelessWidget {
  const MwbTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
    this.inputFormatters,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.errorText,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: MwbSpace.xs),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofocus: autofocus,
          focusNode: focusNode,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          obscureText: obscureText,
          style: t.body,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: t.caption,
            helperMaxLines: 3,
            errorText: errorText,
            errorMaxLines: 3,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Password input with a visibility toggle.
class MwbPasswordField extends StatefulWidget {
  const MwbPasswordField({super.key, this.label = 'Password', this.controller, this.validator, this.onSubmitted});

  final String label;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<MwbPasswordField> createState() => _MwbPasswordFieldState();
}

class _MwbPasswordFieldState extends State<MwbPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return MwbTextField(
      label: widget.label,
      controller: widget.controller,
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      obscureText: _obscured,
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: const [AutofillHints.password],
      suffix: IconButton(
        tooltip: _obscured ? 'Show password' : 'Hide password',
        icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}

/// Rounded search input. Can act as a button that opens full search.
class MwbSearchField extends StatelessWidget {
  const MwbSearchField({
    super.key,
    this.controller,
    this.hint = 'Search Scripture, topics, messages',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: t.body,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary, size: 22),
        suffixIcon: controller == null
            ? null
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close_rounded, size: 20, color: c.textSecondary),
                        onPressed: () {
                          controller!.clear();
                          onClear?.call();
                        },
                      ),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MwbRadius.pill),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MwbRadius.pill),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MwbRadius.pill),
          borderSide: BorderSide(color: c.primary, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
    if (readOnly && onTap != null) {
      return Semantics(button: true, label: hint, excludeSemantics: true, child: field);
    }
    return field;
  }
}
