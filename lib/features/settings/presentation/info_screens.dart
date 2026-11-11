import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/notices.dart';
import '../../../core/widgets/state_views.dart';
import 'settings_screens.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _showLicence(BuildContext context, String title, String asset) async {
    final text = await rootBundle.loadString(asset);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(MwbSpace.gutter),
            child: SelectableText(text, style: ctx.mwb.text.caption.copyWith(height: 1.5)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return SettingsPage(
      title: 'About My Word Bible',
      children: [
        Text(
          'My Word Bible helps believers encounter, understand, experience and share God’s Word in a '
          'deeply personal, accessible and engaging way.',
          style: t.sectionHeading.copyWith(fontSize: 21, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: MwbSpace.md),
        Text(
          'MWB is growing into a Scripture-centred place to discover, listen to, watch and save meaningful '
          'Christian teaching — a thoughtful alternative to distracting feeds.',
          style: t.body,
        ),
        const SizedBox(height: MwbSpace.lg),
        MwbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VERSION', style: t.overline),
              Text(AppConfig.appVersion, style: t.cardTitle),
              const SizedBox(height: MwbSpace.sm),
              Text('SCRIPTURE', style: t.overline),
              Text('King James Version (KJV), public domain. Full text stored on this device.', style: t.supporting),
              const SizedBox(height: MwbSpace.sm),
              Text('SAMPLE CONTENT', style: t.overline),
              Text(
                'Creators, messages and articles in this build are fictional samples written for demonstration. '
                'The audio player uses an original generated tone in place of message recordings.',
                style: t.supporting,
              ),
            ],
          ),
        ),
        const SizedBox(height: MwbSpace.lg),
        Text('FONT LICENCES', style: t.overline),
        for (final (name, asset) in const [
          ('Cormorant Garamond', 'assets/licenses/OFL-Cormorant.txt'),
          ('Lora', 'assets/licenses/OFL-Lora.txt'),
          ('Inter', 'assets/licenses/OFL-Inter.txt'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name, style: t.label.copyWith(fontSize: 15)),
            subtitle: Text('SIL Open Font License 1.1', style: t.caption),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showLicence(context, name, asset),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Open-source software licences', style: t.label.copyWith(fontSize: 15)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
          ),
        ),
      ],
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'Is the Bible text available offline?',
      'Yes. The complete King James Version is stored on your device, so reading and Scripture search work without internet.',
    ),
    (
      'Why can’t I choose other translations?',
      'Modern translations require publisher licences. They are listed so you know what is planned, and will be enabled once licensing is in place.',
    ),
    (
      'Does personalisation change the Bible text?',
      'Never. Personal touches such as “For you today” appear around Scripture. The translation text and its reference are always shown exactly as published.',
    ),
    (
      'Where are my notes and highlights stored?',
      'On this device. Accounts and sync will come with MWB online services. Until then, clearing app data or uninstalling removes them.',
    ),
    (
      'Why does the audio player play a tone?',
      'This build does not include sermon recordings. A short original tone stands in so the player can be used; creator audio will stream when media hosting launches.',
    ),
    (
      'Can I share my own messages?',
      'You can prepare a contribution from Discover. It is saved on your device as a draft; uploading and review will be enabled with MWB online services.',
    ),
    ('How do I see onboarding again?', 'Go to Profile → Privacy & data → Reset onboarding.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    return SettingsPage(
      title: 'Help & support',
      children: [
        for (final (q, a) in _faqs)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: MwbSpace.md),
            expandedAlignment: Alignment.centerLeft,
            title: Text(q, style: t.label.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
            children: [Text(a, style: t.supporting)],
          ),
        const SizedBox(height: MwbSpace.lg),
        const MwbNotice(
          icon: Icons.support_agent_outlined,
          title: 'Contact support',
          message: 'A support channel will be published with the public launch of MWB.',
        ),
      ],
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: MwbConstrained(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MwbEmptyState(
              icon: Icons.explore_off_outlined,
              title: 'Page not found',
              message: 'This page does not exist or has moved.',
            ),
            MwbPrimaryButton(label: 'Go home', expand: false, onPressed: () => context.go(AppRoutes.home)),
          ],
        ),
      ),
    );
  }
}
