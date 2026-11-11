import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/section_heading.dart';
import '../../../core/widgets/segmented.dart';
import '../../../core/widgets/selection.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible.dart';
import '../../library/application/library_controllers.dart';
import '../application/bible_providers.dart';
import 'version_sheet.dart';

enum _Testament { old, newT }

final _testamentProvider = NotifierProvider<_TestamentController, _Testament>(_TestamentController.new);

class _TestamentController extends Notifier<_Testament> {
  @override
  _Testament build() => _Testament.newT;
  void set(_Testament t) => state = t;
}

class BibleHomeScreen extends ConsumerWidget {
  const BibleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    final version = ref.watch(activeVersionProvider);
    final books = ref.watch(bibleBooksProvider);
    final testament = ref.watch(_testamentProvider);
    final history = ref.watch(readingHistoryProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            MwbSliverPadding(
              top: MwbSpace.lg,
              sliver: SliverToBoxAdapter(
                child: MwbPageTitle(
                  overline: 'Scripture',
                  title: 'The Bible',
                  trailing: Semantics(
                    button: true,
                    label: 'Bible version: ${version.name}. Change version',
                    excludeSemantics: true,
                    child: MwbChip(
                      label: version.abbreviation,
                      icon: Icons.translate_rounded,
                      onTap: () => showVersionSheet(context),
                    ),
                  ),
                ),
              ),
            ),
            MwbSliverPadding(
              top: MwbSpace.lg,
              sliver: SliverToBoxAdapter(
                child: MwbSearchField(
                  hint: 'Search verses or a reference, e.g. John 3:16',
                  readOnly: true,
                  onTap: () => context.push(AppRoutes.search()),
                ),
              ),
            ),
            if (history.isNotEmpty)
              MwbSliverPadding(
                top: MwbSpace.lg,
                sliver: SliverToBoxAdapter(
                  child: MwbCard(
                    onTap: () =>
                        context.push(AppRoutes.reader(history.first.reference.bookId, history.first.reference.chapter)),
                    semanticLabel: 'Continue reading ${history.first.reference.label}',
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_rounded, color: c.primary),
                        const SizedBox(width: MwbSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CONTINUE READING', style: t.overline),
                              Text(history.first.reference.label, style: t.cardTitle.copyWith(fontSize: 17)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            MwbSliverPadding(
              top: MwbSpace.xl,
              sliver: SliverToBoxAdapter(
                child: MwbSegmentedControl<_Testament>(
                  options: _Testament.values,
                  value: testament,
                  onChanged: ref.read(_testamentProvider.notifier).set,
                  labelOf: (x) => x == _Testament.old ? 'Old Testament' : 'New Testament',
                ),
              ),
            ),
            MwbSliverPadding(
              top: MwbSpace.md,
              bottom: MwbSpace.xxxl,
              sliver: switch (books) {
                AsyncData(:final value) => _BookList(
                  books: value.where((b) => b.isOld == (testament == _Testament.old)).toList(),
                ),
                AsyncError(:final error) => SliverToBoxAdapter(
                  child: MwbErrorState(error: error, onRetry: () => ref.invalidate(bibleBooksProvider)),
                ),
                _ => const SliverToBoxAdapter(child: MwbLoadingState(message: 'Opening the Bible…')),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.books});
  final List<BibleBookInfo> books;

  @override
  Widget build(BuildContext context) {
    final t = context.mwb.text;
    final c = context.mwb.colors;
    return SliverList.separated(
      itemCount: books.length,
      separatorBuilder: (_, _) => Divider(color: c.divider, height: 1),
      itemBuilder: (context, i) {
        final b = books[i];
        return Semantics(
          button: true,
          label: '${b.name}, ${b.chapterCount} chapters',
          excludeSemantics: true,
          child: InkWell(
            onTap: () =>
                b.chapterCount == 1 ? context.push(AppRoutes.reader(b.id, 1)) : context.push(AppRoutes.book(b.id)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${i + 1}'.padLeft(2, '0'),
                      style: t.caption.copyWith(color: c.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Text(b.name, style: t.sectionHeading.copyWith(fontSize: 20))),
                  Text('${b.chapterCount} ch', style: t.caption),
                  const SizedBox(width: MwbSpace.xs),
                  Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
