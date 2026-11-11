import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';
import 'buttons.dart';

/// Editorial section heading with optional overline and action.
class MwbSectionHeading extends StatelessWidget {
  const MwbSectionHeading({
    super.key,
    required this.title,
    this.overline,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? overline;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[Text(overline!.toUpperCase(), style: t.overline), const SizedBox(height: 4)],
                Text(title, style: t.sectionHeading),
                if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: t.supporting)],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.only(left: MwbSpace.xs),
              child: MwbTextButton(label: actionLabel!, onPressed: onAction),
            ),
        ],
      ),
    );
  }
}

/// Page title used at the top of primary tabs.
class MwbPageTitle extends StatelessWidget {
  const MwbPageTitle({super.key, required this.title, this.overline, this.trailing});

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[Text(overline!.toUpperCase(), style: t.overline), const SizedBox(height: 6)],
                Text(title, style: t.pageHeading),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
