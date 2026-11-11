import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../application/profile_controllers.dart';

String? validateEmail(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Enter a valid email address.';
  return null;
}

String? validatePassword(String? v) {
  if ((v ?? '').isEmpty) return 'Enter your password.';
  if (v!.length < 8) return 'Passwords have at least 8 characters.';
  return null;
}

/// Sign-in interface. Account services are not part of Foundation V1, so
/// submission validates locally and then explains the current state.
Future<void> showSignInSheet(BuildContext context) => showMwbSheet<void>(
  context,
  title: 'Sign in',
  subtitle: 'Keep your library in sync across devices.',
  builder: (_) => const _SignInForm(),
);

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm();

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(email: _email.text.trim(), password: _password.text);
      ref.invalidate(sessionProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _message = MwbErrorState.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(authRepositoryProvider).accountsAvailable;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!available) ...[
              const MwbNotice(
                icon: Icons.cloud_off_outlined,
                message:
                    'Accounts launch with MWB online services. Until then you can keep using every '
                    'feature as a guest — everything is saved on this device.',
              ),
              const SizedBox(height: MwbSpace.md),
            ],
            MwbTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
            ),
            const SizedBox(height: MwbSpace.md),
            MwbPasswordField(controller: _password, validator: validatePassword, onSubmitted: (_) => _submit()),
            if (_message != null) ...[
              const SizedBox(height: MwbSpace.sm),
              Semantics(
                liveRegion: true,
                child: Text(_message!, style: context.mwb.text.caption.copyWith(color: context.mwb.colors.warning)),
              ),
            ],
            const SizedBox(height: MwbSpace.lg),
            MwbPrimaryButton(label: 'Sign in', loading: _busy, onPressed: _submit),
            const SizedBox(height: MwbSpace.xs),
            Center(
              child: MwbTextButton(label: 'Continue as guest', onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}
