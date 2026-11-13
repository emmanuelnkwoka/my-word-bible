import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';
import 'buttons.dart';

/// Shows an MWB modal bottom sheet with title, safe area and keyboard
/// handling.
Future<T?> showMwbSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Above the floating navigation, never behind or beside it.
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) {
      final t = ctx.mwb.text;
      final body = Padding(
        padding: EdgeInsets.only(
          left: MwbSpace.gutter,
          right: MwbSpace.gutter,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + MwbSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) Text(title, style: t.sectionHeading),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle, style: t.supporting)],
            if (title != null || subtitle != null) const SizedBox(height: MwbSpace.md),
            Builder(builder: builder),
          ],
        ),
      );
      return scrollable ? SingleChildScrollView(child: body) : body;
    },
  );
}

/// Confirmation dialog for destructive or significant actions.
Future<bool> showMwbConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.mwb.colors;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(MwbSpace.md, 0, MwbSpace.md, MwbSpace.md),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: c.textSecondary, minimumSize: const Size(64, 48)),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? c.error : c.primary,
              minimumSize: const Size(64, 48),
              textStyle: ctx.mwb.text.label.copyWith(fontWeight: FontWeight.w700),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Sheet with a single honest explanation (e.g. a feature that depends on
/// future online services).
Future<void> showMwbInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline_rounded,
}) {
  return showMwbSheet<void>(
    context,
    builder: (ctx) {
      final c = ctx.mwb.colors;
      final t = ctx.mwb.text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.primary),
          const SizedBox(height: MwbSpace.sm),
          Text(title, style: t.sectionHeading),
          const SizedBox(height: MwbSpace.xs),
          Text(message, style: t.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: MwbSpace.xl),
          MwbPrimaryButton(label: 'Understood', onPressed: () => Navigator.of(ctx).pop()),
        ],
      );
    },
  );
}

void showMwbSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
