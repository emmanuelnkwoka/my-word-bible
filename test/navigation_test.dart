import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/theme/app_theme.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/features/library/application/library_controllers.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('five tabs are reachable', (tester) async {
    await pumpMwbApp(tester, onboardedStore());
    expect(find.text('DAILY SCRIPTURE'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Bible tab'));
    await settle(tester);
    expect(find.text('The Bible'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Discover tab'));
    await settle(tester);
    expect(find.text('Featured resources'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Library tab'));
    await settle(tester);
    expect(find.text('Saved Scripture'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profile tab'));
    await settle(tester);
    expect(find.text('Theme & appearance'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Home tab'));
    await settle(tester);
    expect(find.text('DAILY SCRIPTURE'), findsOneWidget);
  });

  testWidgets('tabs preserve their navigation stack and state', (tester) async {
    await pumpMwbApp(tester, onboardedStore());

    // Bible: choose Old Testament and open Genesis chapters.
    await tester.tap(find.bySemanticsLabel('Bible tab'));
    await settle(tester);
    await tester.tapText('Old Testament');
    await tester.tap(find.bySemanticsLabel('Genesis, 50 chapters'));
    await settle(tester);
    expect(find.text('50 chapters · choose a chapter'), findsOneWidget);

    // Switch away and back: the pushed chapter screen is still there.
    await tester.tap(find.bySemanticsLabel('Discover tab'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Bible tab'));
    await settle(tester);
    expect(find.text('50 chapters · choose a chapter'), findsOneWidget);

    // Back to the book list: Old Testament is still selected.
    await tester.pageBack();
    await settle(tester);
    expect(find.bySemanticsLabel('Genesis, 50 chapters'), findsOneWidget);
  });

  testWidgets('reader shows canonical text, navigates chapters and records history', (tester) async {
    await pumpMwbApp(tester, onboardedStore());
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    await tester.tap(find.bySemanticsLabel('Bible tab'));
    await settle(tester);
    await tester.tapText('Old Testament');
    await scrollTo(tester, find.bySemanticsLabel('Psalms, 150 chapters'));
    await tester.tap(find.bySemanticsLabel('Psalms, 150 chapters'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Chapter 23'));
    await settle(tester);

    expect(find.text('Chapter 23'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Verse 1\. The LORD is my shepherd; I shall not want\.')), findsOneWidget);
    expect(container.read(readingHistoryProvider).first.reference.label, 'Psalms 23');

    // Select a verse and bookmark it.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Verse 1\.')));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Bookmark'));
    await settle(tester);
    expect(container.read(bookmarksProvider).single.reference.label, 'Psalm 23:1');

    // Next chapter.
    await scrollTo(tester, find.bySemanticsLabel('Next chapter, Psalms 24'));
    await tester.tap(find.bySemanticsLabel('Next chapter, Psalms 24'));
    await settle(tester);
    expect(find.text('Chapter 24'), findsOneWidget);
    expect(container.read(readingHistoryProvider).first.reference.label, 'Psalms 24');
  });

  testWidgets('theme switching applies immediately across the app', (tester) async {
    await pumpMwbApp(tester, onboardedStore());
    MwbTheme current() => Theme.of(tester.element(find.byType(Scaffold).first)).extension<MwbTheme>()!;
    expect(current().themeId, MwbThemeId.classicGold);

    await tester.tap(find.bySemanticsLabel('Profile tab'));
    await settle(tester);
    await tester.tapText('Theme & appearance');

    await scrollTo(tester, find.bySemanticsLabel('Royal Navy theme'));
    await tester.tap(find.bySemanticsLabel('Royal Navy theme'));
    await settle(tester);
    // Previewing does not apply yet.
    expect(current().themeId, MwbThemeId.classicGold);

    await tester.tap(find.byKey(const Key('appearance.apply')));
    await settle(tester);
    expect(current().themeId, MwbThemeId.royalNavy);

    // The mode control sits at the top of the page.
    await tester.drag(verticalScrollable(), const Offset(0, 3000));
    await settle(tester);
    await tester.tapText('Dark');
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
    expect(current().colors, MwbThemes.royalNavy.dark);
  });

  testWidgets('every theme renders the Home screen in light and dark without errors', (tester) async {
    for (final def in MwbThemes.all) {
      for (final mode in ['light', 'dark']) {
        final store = onboardedStore()
          ..setString('mwb.v1.theme_id', def.id.storageKey)
          ..setString('mwb.v1.theme_mode', mode);
        await pumpMwbApp(tester, store);
        final ext = Theme.of(tester.element(find.byType(Scaffold).first)).extension<MwbTheme>()!;
        expect(ext.themeId, def.id);
        expect(ext.colors.isDark, mode == 'dark');
        expect(tester.takeException(), isNull, reason: '${def.id.label} $mode');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('small phone and tablet layouts render without overflow', (tester) async {
    for (final size in const [Size(320, 568), Size(820, 1180)]) {
      await pumpMwbApp(tester, onboardedStore(), size: size);
      for (final tab in ['Bible tab', 'Discover tab', 'Library tab', 'Profile tab', 'Home tab']) {
        await tester.tap(find.bySemanticsLabel(tab));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '$tab at $size');
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
