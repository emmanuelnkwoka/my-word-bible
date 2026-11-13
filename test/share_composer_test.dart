import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/features/share/scripture_image_composer.dart';
import 'package:my_word_bible/features/share/scripture_share_sheet.dart';

import 'helpers/test_app.dart';

final _style = ShareStyle.fromPalette(MwbThemes.byId(MwbThemeId.classicGold).paletteFor(Brightness.light));

String _words(Iterable<ShareVerse> vs) => vs.map((v) => v.text).join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

void main() {
  test('a single short verse fits one centred page', () {
    const s = ShareScripture(
      verses: [ShareVerse(35, [ShareSpan('Jesus wept.')])],
      reference: 'John 11:35',
      translation: 'KJV',
    );
    expect(ScriptureImageComposer.layoutFor(s), ShareLayout.centred);
    for (final f in ShareFormat.values) {
      expect(ScriptureImageComposer.plan(s, f, _style), hasLength(1), reason: f.name);
    }
  });

  test('a whole chapter is paginated and every word is kept, in order', () async {
    final verses = await sharedTestBible.chapter('KJV', 'PSA', 119);
    final s = shareScriptureFromVerses(verses: verses, reference: 'Psalm 119', translation: 'KJV');
    for (final f in ShareFormat.values) {
      final pages = ScriptureImageComposer.plan(s, f, _style);
      expect(pages.length, greaterThan(5), reason: f.name);
      expect(_words(pages.expand((p) => p.verses)), _words(s.verses), reason: f.name);
    }
  });

  test('a verse longer than a page is split by words, never truncated', () {
    final long = List.filled(40, 'And God saw every thing that he had made, and, behold, it was very good.').join(' ');
    final s = ShareScripture(
      verses: [ShareVerse(31, [ShareSpan(long)])],
      reference: 'Genesis 1:31',
      translation: 'KJV',
    );
    final pages = ScriptureImageComposer.plan(s, ShareFormat.square, _style);
    expect(pages.length, greaterThan(1));
    expect(_words(pages.expand((p) => p.verses)), _words(s.verses));
  });

  test('the name in an approved rendering keeps its marking across a page split', () {
    final s = ShareScripture(
      verses: [
        for (var i = 1; i <= 30; i++)
          ShareVerse(i, const [ShareSpan('My son, '), ShareSpan('Ada Obi', isName: true), ShareSpan(', forget not my law.')]),
      ],
      reference: 'Proverbs 3',
      translation: 'KJV-MWB',
      numbered: true,
    );
    final pages = ScriptureImageComposer.plan(s, ShareFormat.portrait, _style);
    final names = pages.expand((p) => p.verses).expand((v) => v.spans).where((sp) => sp.isName).length;
    expect(names, 30);
  });

  testWidgets('pages render to PNG at the format size', (tester) async {
    await tester.runAsync(() async {
      const s = ShareScripture(
        verses: [ShareVerse(13, [ShareSpan('Now the God of hope fill you with all joy and peace in believing.')])],
        reference: 'Romans 15:13',
        translation: 'KJV',
        title: 'Ada, abound in hope',
        preview: true,
      );
      final pages = await const ScriptureImageComposer().compose(s, ShareFormat.story, _style);
      expect(pages.single.width, 1080);
      expect(pages.single.height, 1920);
      expect(pages.single.png.sublist(0, 4), Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
    });
  });
}
