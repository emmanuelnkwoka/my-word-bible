import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';
import '../../bible/application/bible_providers.dart';
import '../../personalisation/presentation/presented_scripture.dart';
import '../../share/scripture_share_sheet.dart';
import '../application/social_providers.dart';
import 'social_widgets.dart';

/// Following, followers and finding people.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _query = TextEditingController();
  Future<List<PublicProfile>>? _results;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final following = ref.watch(profilesProvider(ref.watch(followingProvider).toList())).value ?? const [];
    final followers = ref.watch(profilesProvider(ref.watch(followersProvider).toList())).value ?? const [];
    final live = ref.watch(userDirectoryProvider).isLive;

    Widget people(List<PublicProfile> list, String emptyTitle, String emptyMessage) => list.isEmpty
        ? MwbEmptyState(icon: Icons.people_outline_rounded, title: emptyTitle, message: emptyMessage, compact: true)
        : ListView(
            padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
            children: [
              for (final p in list)
                PersonTile(
                  key: Key('people.${p.userId}'),
                  person: p,
                  onTap: () => context.push(AppRoutes.person(p.userId)),
                ),
            ],
          );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('People'),
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('people.tab.find'), text: 'Find'),
              Tab(key: Key('people.tab.following'), text: 'Following'),
              Tab(key: Key('people.tab.followers'), text: 'Followers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
              children: [
                if (!live)
                  const SocialNotice(
                    icon: Icons.science_outlined,
                    message: 'Accounts are not live yet: search finds the sample community on this phone.',
                  ),
                const SizedBox(height: MwbSpace.sm),
                TextField(
                  key: const Key('people.search'),
                  controller: _query,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '@username, MWB ID or name'),
                  onChanged: (q) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 200), () {
                      if (mounted) {
                        final next = q.trim().isEmpty ? null : ref.read(socialActionsProvider).search(q);
      setState(() { _results = next; });
                      }
                    });
                  },
                ),
                FutureBuilder<List<PublicProfile>>(
                  future: _results ?? Future.value(live ? const [] : DemoUserDirectory.people.where((p) => !p.isRestricted).toList()),
                  builder: (context, snap) => Column(
                    children: [
                      for (final p in snap.data ?? const <PublicProfile>[])
                        if (!ref.watch(blockedUsersProvider).contains(p.userId))
                          PersonTile(
                            key: Key('people.find.${p.userId}'),
                            person: p,
                            onTap: () => context.push(AppRoutes.person(p.userId)),
                          ),
                    ],
                  ),
                ),
              ],
            ),
            people(following, 'Not following anyone', 'Follow people to see the Scripture they share publicly in Discover.'),
            people(followers, 'No followers yet', 'People who follow you will appear here.'),
          ],
        ),
      ),
    );
  }
}

/// A person's public profile. Shows only public information.
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final value = ref.watch(publicProfileProvider(userId));
    final following = ref.watch(followingProvider).contains(userId);
    final actions = ref.read(socialActionsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (value.value != null)
            PopupMenuButton<String>(
              key: const Key('person.more'),
              onSelected: (v) async {
                final p = value.value!;
                if (v == 'block') {
                  final ok = await showMwbConfirmDialog(
                    context,
                    title: 'Block ${p.displayName}?',
                    message: 'They won’t be able to share with you, and you won’t see them in search.',
                    confirmLabel: 'Block',
                    destructive: true,
                  );
                  if (ok) {
                    await actions.block(userId);
                    if (context.mounted) context.pop();
                  }
                } else {
                  await actions.report(userId, 'Reported from profile');
                  if (context.mounted) showMwbSnack(context, 'Report saved on this device.');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report')),
                PopupMenuItem(value: 'block', key: Key('person.block'), child: Text('Block')),
              ],
            ),
        ],
      ),
      body: value.when(
        loading: () => const MwbLoadingState(),
        error: (e, _) => MwbErrorState(error: e),
        data: (p) {
          if (p == null) {
            return const MwbEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile not available',
              message: 'This person can’t be found, or you have blocked them.',
            );
          }
          return ListView(
            padding: MwbLayout.pagePadding(context, top: MwbSpace.sm, bottom: MwbSpace.xxl),
            children: [
              Center(child: PersonAvatar(initials: p.initials, tone: p.tone, size: 84)),
              const SizedBox(height: MwbSpace.sm),
              Center(child: Text(p.displayName, style: t.pageHeading)),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p.handle, style: t.supporting),
                    if (p.isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
                  ],
                ),
              ),
              if (p.followsYou)
                Center(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('Follows you', style: t.caption))),
              if (p.bio.isNotEmpty && !p.isRestricted) ...[
                const SizedBox(height: MwbSpace.sm),
                Text(p.bio, textAlign: TextAlign.center, style: t.body),
              ],
              const SizedBox(height: MwbSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: following
                        ? MwbSecondaryButton(
                            key: const Key('person.unfollow'),
                            label: 'Following',
                            icon: Icons.how_to_reg_rounded,
                            onPressed: () => actions.unfollow(userId),
                          )
                        : MwbPrimaryButton(
                            key: const Key('person.follow'),
                            label: 'Follow',
                            icon: Icons.person_add_alt_1_rounded,
                            onPressed: () async {
                              try {
                                await actions.follow(userId);
                              } on SocialFailure catch (e) {
                                if (context.mounted) showMwbSnack(context, e.message);
                              }
                            },
                          ),
                  ),
                ],
              ),
              const SizedBox(height: MwbSpace.xl),
              if (p.isRestricted)
                const SocialNotice(icon: Icons.lock_outline_rounded, message: 'This profile is private.')
              else ...[
                Text('SHARED PUBLICLY', style: t.overline),
                const SizedBox(height: MwbSpace.xs),
                if (p.publicActivity.isEmpty)
                  Text('Nothing shared publicly yet.', style: t.supporting)
                else
                  for (final a in p.publicActivity)
                    PublicActivityTile(activity: a),
              ],
              const SizedBox(height: MwbSpace.lg),
              Text(
                'Following is always your choice. Opening someone’s shared Scripture never follows them for you.',
                style: t.caption.copyWith(color: c.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A publicly shared verse with read and share actions.
class PublicActivityTile extends ConsumerWidget {
  const PublicActivityTile({super.key, required this.activity, this.person});
  final PublicScriptureActivity activity;
  final PublicProfile? person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mwb.colors;
    final t = context.mwb.text;
    final r = activity.reference;
    return Container(
      margin: const EdgeInsets.only(bottom: MwbSpace.xs),
      padding: const EdgeInsets.all(MwbSpace.md),
      decoration: BoxDecoration(color: c.surface, borderRadius: MwbRadius.lgAll, border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (person != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => context.push(AppRoutes.person(person!.userId)),
                child: Row(
                  children: [
                    PersonAvatar(initials: person!.initials, tone: person!.tone, size: 26),
                    const SizedBox(width: 8),
                    Text(person!.displayName, style: t.label.copyWith(fontWeight: FontWeight.w600)),
                    if (person!.isDemo) ...[const SizedBox(width: 6), const DemoBadge()],
                  ],
                ),
              ),
            ),
          Text('${r.label} · ${activity.versionId}', style: t.scriptureReference),
          Builder(
            builder: (context) {
              final verse = FutureBuilder(
                future: ref.read(bibleRepositoryProvider).passage(activity.versionId, r),
                builder: (context, snap) => Text(
                  snap.data?.text ?? '…',
                  style: t.scripture.copyWith(fontSize: 16, height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              );
              // The reader's own personal title and reception, only when they
              // belong to the same translation as the verse shown.
              return ref.watch(textVersionProvider).id == activity.versionId
                  ? EditorialLayersAround(reference: r, receptionFontSize: 13.5, child: verse)
                  : verse;
            },
          ),
          if (activity.note != null) ...[
            const SizedBox(height: 4),
            Text(activity.note!, style: t.supporting.copyWith(fontStyle: FontStyle.italic)),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.reader(r.bookId, r.chapter, verse: r.verseStart)),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('Read'),
              ),
              TextButton.icon(
                key: Key('activity.share.${r.key}'),
                onPressed: () async {
                  final s = await loadShareScripture(ref.read(bibleRepositoryProvider), r, activity.versionId);
                  if (context.mounted) await showScriptureShareSheet(context, s);
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
