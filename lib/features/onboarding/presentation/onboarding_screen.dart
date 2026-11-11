import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_steps.dart';

/// Four-step onboarding. Completion is persisted and the router then moves
/// the user to Home; onboarding is not shown again unless reset.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final TextEditingController _name;
  final _scroll = ScrollController();
  bool _finishing = false;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(onboardingControllerProvider).firstName);
  }

  @override
  void dispose() {
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final draft = ref.read(onboardingControllerProvider);
    if (draft.isLastStep) {
      await _finish();
      return;
    }
    setState(() => _direction = 1);
    if (ctrl.next()) _resetScroll();
  }

  Future<void> _finish({bool skipDaily = false}) async {
    setState(() => _finishing = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).complete(skipDailyStep: skipDaily);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _back() {
    setState(() => _direction = -1);
    ref.read(onboardingControllerProvider.notifier).back();
    _resetScroll();
  }

  void _skip() {
    final draft = ref.read(onboardingControllerProvider);
    FocusScope.of(context).unfocus();
    if (draft.isLastStep) {
      _finish(skipDaily: true);
      return;
    }
    setState(() => _direction = 1);
    ref.read(onboardingControllerProvider.notifier).skip();
    _resetScroll();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final step = draft.step;

    final stepWidget = switch (step) {
      0 => PersonalStep(nameController: _name),
      1 => const InterestsStep(),
      2 => const ReadingStep(),
      _ => const DailyStep(),
    };

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              MwbConstrained(
                child: Padding(
                  padding: const EdgeInsets.only(top: MwbSpace.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: kMwbMinTouchTarget,
                        child: step > 0
                            ? MwbIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: _back)
                            : null,
                      ),
                      Expanded(
                        child: _ProgressBar(step: step, count: OnboardingDraft.stepCount),
                      ),
                      SizedBox(
                        width: 64,
                        child: step > 0
                            ? TextButton(
                                onPressed: _finishing ? null : _skip,
                                style: TextButton.styleFrom(
                                  foregroundColor: c.textSecondary,
                                  minimumSize: const Size(48, 48),
                                ),
                                child: const Text('Skip'),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: MwbSpace.xl),
                  child: MwbConstrained(
                    child: AnimatedSwitcher(
                      duration: MwbMotion.slow,
                      switchInCurve: MwbMotion.curve,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: Offset(0.06 * _direction, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                      child: KeyedSubtree(
                        key: ValueKey(step),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: MwbSpace.lg),
                            Text('STEP ${step + 1} OF ${OnboardingDraft.stepCount}', style: t.overline),
                            const SizedBox(height: MwbSpace.sm),
                            stepWidget,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border(top: BorderSide(color: c.divider)),
                ),
                child: MwbConstrained(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: MwbSpace.md),
                    child: MwbPrimaryButton(
                      label: draft.isLastStep ? 'Begin my journey' : 'Continue',
                      icon: draft.isLastStep ? null : Icons.arrow_forward_rounded,
                      loading: _finishing,
                      onPressed: _continue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.count});
  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Semantics(
      label: 'Step ${step + 1} of $count',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MwbSpace.xs),
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: c.border),
                        AnimatedFractionallySizedBox(
                          duration: MwbMotion.slow,
                          curve: MwbMotion.curve,
                          alignment: Alignment.centerLeft,
                          widthFactor: i <= step ? 1 : 0,
                          child: ColoredBox(color: c.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
