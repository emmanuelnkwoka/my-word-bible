import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mwb_tokens.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/bible_canon.dart';

/// Chapter grid for one book.
class BookChaptersScreen extends StatelessWidget {
  const BookChaptersScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context) {
    final book = BibleCanon.byId(bookId);
    final t = context.mwb.text;
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const MwbEmptyState(title: 'Book not found', message: 'This book could not be found.'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(book.isOld ? 'Old Testament' : 'New Testament')),
      body: CustomScrollView(
        slivers: [
          MwbSliverPadding(
            top: MwbSpace.xs,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(book.name, style: t.display)),
                  const SizedBox(height: 4),
                  Text('${book.chapterCount} chapters · choose a chapter', style: t.supporting),
                ],
              ),
            ),
          ),
          MwbSliverPadding(
            top: MwbSpace.xl,
            bottom: MwbSpace.xxxl,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 72,
                mainAxisSpacing: MwbSpace.xs,
                crossAxisSpacing: MwbSpace.xs,
              ),
              itemCount: book.chapterCount,
              itemBuilder: (context, i) =>
                  _ChapterTile(number: i + 1, onTap: () => context.push(AppRoutes.reader(book.id, i + 1))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.number, required this.onTap});
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwb.colors;
    return Semantics(
      button: true,
      label: 'Chapter $number',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: MwbRadius.mdAll,
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          borderRadius: MwbRadius.mdAll,
          onTap: onTap,
          child: Center(child: Text('$number', style: context.mwb.text.sectionHeading.copyWith(fontSize: 20))),
        ),
      ),
    );
  }
}
