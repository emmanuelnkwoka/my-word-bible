import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';

/// Inline notice that honestly states a current limitation.
class MwbNotice extends StatelessWidget {
  const MwbNotice({super.key, required this.message, this.icon = Icons.info_outline_rounded, this.title});

  final String message;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Container(
      padding: const EdgeInsets.all(MwbSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MwbRadius.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.primary),
          const SizedBox(width: MwbSpace.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) Text(title!, style: t.label.copyWith(fontWeight: FontWeight.w600)),
                Text(message, style: t.caption.copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small label marking illustrative sample data.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key, this.label = 'Sample'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Semantics(
      label: '$label content',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.border),
        ),
        child: Text(
          label.toUpperCase(),
          style: context.mwb.text.caption.copyWith(fontSize: 9.5, letterSpacing: 0.8, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Circular initials avatar (placeholder for profile images).
class MwbAvatar extends StatelessWidget {
  const MwbAvatar({super.key, required this.initials, this.size = 44, this.tone});

  final String initials;
  final double size;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone ?? c.selected,
          border: Border.all(color: c.primary.withValues(alpha: 0.35)),
        ),
        child: Text(
          initials,
          style: context.mwb.text.sectionHeading.copyWith(fontSize: size * 0.4, color: c.primaryStrong, height: 1),
        ),
      ),
    );
  }
}
