import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../theme/app_theme.dart';
import '../theme/mwb_tokens.dart';
import 'buttons.dart';

/// Calm empty state with an optional action.
class MwbEmptyState extends StatelessWidget {
  const MwbEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_stories_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? MwbSpace.lg : MwbSpace.xxxl, horizontal: MwbSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(icon, color: c.primary, size: 24),
          ),
          const SizedBox(height: MwbSpace.md),
          Text(title, style: t.sectionHeading.copyWith(fontSize: 21), textAlign: TextAlign.center),
          const SizedBox(height: MwbSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(message, style: t.supporting, textAlign: TextAlign.center),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: MwbSpace.lg),
            MwbSecondaryButton(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}

/// Quiet loading indicator with optional caption.
class MwbLoadingState extends StatelessWidget {
  const MwbLoadingState({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return Semantics(
      label: message ?? 'Loading',
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? MwbSpace.lg : MwbSpace.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            if (message != null) ...[const SizedBox(height: MwbSpace.sm), Text(message!, style: t.caption)],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry action and a human-readable message.
class MwbErrorState extends StatelessWidget {
  const MwbErrorState({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  static String messageFor(Object error) =>
      error is AppFailure ? error.message : 'Something unexpected happened. Please try again.';

  @override
  Widget build(BuildContext context) {
    final unavailable = error is FeatureUnavailableFailure;
    return MwbEmptyState(
      compact: compact,
      icon: unavailable ? Icons.cloud_off_outlined : Icons.error_outline_rounded,
      title: unavailable ? 'Not available yet' : 'Something went wrong',
      message: messageFor(error),
      actionLabel: onRetry == null || unavailable ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Renders an [AsyncValue] with consistent loading and error states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingMessage,
    this.compact = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? loadingMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MwbMotion.medium,
      child: switch (value) {
        AsyncData(:final value) => KeyedSubtree(key: const ValueKey('data'), child: data(value)),
        AsyncError(:final error) => KeyedSubtree(
          key: const ValueKey('error'),
          child: MwbErrorState(error: error, onRetry: onRetry, compact: compact),
        ),
        _ => KeyedSubtree(
          key: const ValueKey('loading'),
          child: MwbLoadingState(message: loadingMessage, compact: compact),
        ),
      },
    );
  }
}
