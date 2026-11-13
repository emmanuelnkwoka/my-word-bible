import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/theme/mwb_themes.dart';
import 'package:my_word_bible/data/models/bible.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/features/share/export/card_export.dart';
import 'package:my_word_bible/features/share/scripture_image_composer.dart';
import 'package:my_word_bible/features/share/scripture_share_sheet.dart';
import 'package:my_word_bible/features/share/studio/card_design.dart';
import 'package:my_word_bible/features/share/studio/card_studio_renderer.dart';

import '../helpers/test_app.dart';

final _classic = ShareStyle.fromPalette(MwbThemes.byId(MwbThemeId.classicGold).paletteFor(Brightness.light));

String _words(Iterable<ShareVerse> vs) =>
    vs.map((v) => v.text).join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

const _romans = ShareScripture(
  verses: [
    ShareVerse(13, [
      ShareSpan(
        'Now the God of hope fill you with all joy and peace in believing, that ye may abound in hope, '
        'through the power of the Holy Ghost.',
      ),
    ]),
  ],
  reference: 'Romans 15:13',
  translation: 'KJV',
);

void main() {
  group('Existing quick share is preserved', () {
    test('quick-share formats and sizes are unchanged; Landscape is added for the Studio only', () {
      expect(ShareFormat.quick, [ShareFormat.portrait, ShareFormat.square, ShareFormat.story]);
      expect([for (final f in ShareFormat.quick) (f.width, f.height)], [(1080, 1350), (1080, 1080), (1080, 1920)]);
      expect((ShareFormat.landscape.width, ShareFormat.landscape.height), (1920, 1080));
    });

    test('Classic in the Studio is the quick-share composition exactly', () {
      for (final f in ShareFormat.quick) {
        final studio = CardStudioRenderer.plan(_romans, CardDesign(template: CardTemplate.classic, format: f), classicStyle: _classic);
        final quick = ScriptureImageComposer.plan(_romans, f, _classic);
        expect(studio.map((p) => p.page.fontSize), quick.map((p) => p.fontSize), reason: f.name);
      }
    });

    testWidgets('Classic renders byte-identical PNGs to quick share', (tester) async {
      await tester.runAsync(() async {
        final quick = await const ScriptureImageComposer().compose(_romans, ShareFormat.portrait, _classic);
        final studio = await const CardStudioRenderer().compose(
          _romans,
          const CardDesign(template: CardTemplate.classic),
          classicStyle: _classic,
        );
        expect(studio.single.png, quick.single.png);
      });
    });
  });

  group('Templates', () {
    test('there are eight premium designs plus Classic, each with colourways', () {
      final premium = CardTemplate.values.where((t) => !t.isClassic).toList();
      expect(premium, hasLength(8));
      for (final t in premium) {
        expect(t.colorways.length, greaterThanOrEqualTo(3), reason: t.id);
      }
      expect(CardTemplate.values.map((t) => t.id).toSet(), hasLength(CardTemplate.values.length));
    });

    test('every colourway offers only readable ink and its default ink is readable', () {
      for (final t in CardTemplate.values.where((t) => !t.isClassic)) {
        for (var i = 0; i < t.colorways.length; i++) {
          final d = CardDesign(template: t, colorway: i);
          expect(d.inkOptions, isNotEmpty, reason: '${t.id}/$i');
          expect(contrastRatio(d.effectiveInk, d.palette.textBackdrop), greaterThanOrEqualTo(minCardContrast), reason: '${t.id}/$i');
          for (final ink in d.inkOptions) {
            expect(contrastRatio(ink, d.palette.textBackdrop), greaterThanOrEqualTo(minCardContrast));
          }
        }
      }
    });

    test('an unreadable chosen colour falls back to the colourway ink', () {
      final d = const CardDesign(template: CardTemplate.ivoryGold).copyWith(ink: const Color(0xFFFFFFFF));
      expect(d.effectiveInk, d.palette.ink);
    });

    test('the remembered look never stores the personal note or name', () {
      final d = const CardDesign(template: CardTemplate.navy, colorway: 2, format: ShareFormat.story)
          .copyWith(message: 'Praying for you', senderName: 'Grace');
      final json = d.toJson();
      expect(json.toString(), isNot(contains('Praying')));
      expect(json.toString(), isNot(contains('Grace')));
      final back = CardDesign.fromJson(json);
      expect((back.template, back.colorway, back.format), (CardTemplate.navy, 2, ShareFormat.story));
    });
  });

  group('Completeness and layout', () {
    test('a whole chapter keeps every word, in order, for every design and size', () async {
      final verses = await sharedTestBible.chapter('KJV', 'PSA', 119);
      final s = shareScriptureFromVerses(verses: verses, reference: 'Psalm 119', translation: 'KJV', sourceVersionId: 'KJV');
      for (final t in CardTemplate.values.where((t) => !t.isClassic)) {
        for (final f in ShareFormat.values) {
          final d = CardDesign(template: t, format: f, message: 'For you', senderName: 'Grace');
          final pages = CardStudioRenderer.plan(s, d);
          expect(pages.length, greaterThan(3), reason: '${t.id}/${f.name}');
          expect(_words(pages.expand((p) => p.page.verses)), _words(s.verses), reason: '${t.id}/${f.name}');
          for (final p in pages) {
            expect(p.fits, isTrue, reason: 'overflow in ${t.id}/${f.name}');
          }
        }
      }
    });

    test('larger text still fits by adding pages, never by cutting', () async {
      final verses = await sharedTestBible.chapter('KJV', 'ROM', 8);
      final s = shareScriptureFromVerses(verses: verses, reference: 'Romans 8', translation: 'KJV');
      final normal = CardStudioRenderer.plan(s, const CardDesign(template: CardTemplate.vibrant));
      final large = CardStudioRenderer.plan(s, const CardDesign(template: CardTemplate.vibrant, textScale: 1.15));
      expect(large.length, greaterThanOrEqualTo(normal.length));
      expect(_words(large.expand((p) => p.page.verses)), _words(s.verses));
      expect(large.every((p) => p.fits), isTrue);
    });

    test('a single short verse is one page in every design and size', () {
      for (final t in CardTemplate.values) {
        for (final f in ShareFormat.values) {
          expect(CardStudioRenderer.plan(_romans, CardDesign(template: t, format: f), classicStyle: _classic), hasLength(1));
        }
      }
    });

    test('a verse longer than a page is split by words, not truncated', () {
      final long = List.filled(50, 'And God saw every thing that he had made, and, behold, it was very good.').join(' ');
      final s = ShareScripture(verses: [ShareVerse(31, [ShareSpan(long)])], reference: 'Genesis 1:31', translation: 'KJV');
      final pages = CardStudioRenderer.plan(s, const CardDesign(template: CardTemplate.editorial, format: ShareFormat.square));
      expect(pages.length, greaterThan(1));
      expect(_words(pages.expand((p) => p.page.verses)), _words(s.verses));
    });

    test('translation integrity: the drawn text is exactly the given Scripture', () async {
      final verses = await sharedTestBible.chapter('WEB', 'JHN', 3);
      final s = shareScriptureFromVerses(verses: verses.sublist(15, 18), reference: 'John 3:16–18', translation: 'WEB');
      final pages = CardStudioRenderer.plan(s, const CardDesign(template: CardTemplate.minimal));
      final drawn = pages.expand((p) => p.page.verses).map((v) => v.text).join();
      expect(drawn.replaceAll(RegExp(r'\s'), ''), verses.sublist(15, 18).map((v) => v.text).join().replaceAll(RegExp(r'\s'), ''));
    });
  });

  group('Rendering and export (offline)', () {
    testWidgets('every design renders at the exact size for every format', (tester) async {
      await tester.runAsync(() async {
        for (final t in CardTemplate.values) {
          for (final f in ShareFormat.values) {
            final pages = await const CardStudioRenderer().compose(_romans, CardDesign(template: t, format: f), classicStyle: _classic);
            final png = pages.single.png;
            expect(png.sublist(0, 4), Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
            expect(CardEncoder.dimensions(png), (width: f.width, height: f.height), reason: '${t.id}/${f.name}');
          }
        }
      });
    });

    testWidgets('designs do not look alike', (tester) async {
      await tester.runAsync(() async {
        final outputs = <String>{};
        for (final t in CardTemplate.values.where((t) => !t.isClassic)) {
          final p = await const CardStudioRenderer().compose(_romans, CardDesign(template: t), classicStyle: _classic);
          outputs.add(p.single.png.length.toString() + p.single.png.sublist(200, 260).join(','));
        }
        expect(outputs, hasLength(8));
      });
    });

    testWidgets('PNG and JPG export keep the full size; JPG quality changes the file', (tester) async {
      await tester.runAsync(() async {
        final page = (await const CardStudioRenderer().compose(
          _romans,
          const CardDesign(template: CardTemplate.cinematic, format: ShareFormat.story),
          classicStyle: _classic,
        )).single;
        final png = await CardEncoder.encode(page.png, CardFileType.png);
        expect(png, page.png, reason: 'PNG export is the previewed image');
        final jpg = await CardEncoder.encode(page.png, CardFileType.jpg, quality: 92);
        final small = await CardEncoder.encode(page.png, CardFileType.jpg, quality: 60);
        expect(jpg.sublist(0, 3), Uint8List.fromList([0xFF, 0xD8, 0xFF]));
        expect(CardEncoder.dimensions(jpg), (width: 1080, height: 1920));
        expect(small.length, lessThan(jpg.length));
      });
    });

    test('file names are descriptive and paginated', () {
      expect(CardEncoder.fileName('Romans 15:13', CardFileType.jpg), 'my-word-bible-romans-15-13.jpg');
      expect(CardEncoder.fileName('Psalm 119', CardFileType.png, index: 1, count: 7), 'my-word-bible-psalm-119-2-of-7.png');
    });

    test('destinations pick the right size', () {
      expect(ShareDestination.whatsappStatus.format, ShareFormat.story);
      expect(ShareDestination.instagramStory.format, ShareFormat.story);
      expect(ShareDestination.facebookStory.format, ShareFormat.story);
      expect(ShareDestination.instagramPost.format, ShareFormat.portrait);
      expect(ShareDestination.instagramSquare.format, ShareFormat.square);
      expect(ShareDestination.whatsappStatus.app!.packages, containsAll(['com.whatsapp', 'com.whatsapp.w4b']));
      expect(ShareApp.instagram.acceptsCaption, isFalse);
      expect(ShareApp.whatsapp.acceptsCaption, isTrue);
    });
  });

  group('Canonical sources for sharing', () {
    test('selected verses collapse into references', () {
      Verse v(int n) => Verse(bookId: 'ROM', chapter: 15, number: n, text: 'x');
      expect(referencesOf([v(13), v(14), v(16)]).map((r) => r.label), ['Romans 15:13–14', 'Romans 15:16']);
    });

    test('a review preview is never resolvable for direct sharing', () {
      const s = ShareScripture(
        verses: [ShareVerse(1, [ShareSpan('x')])],
        reference: 'x',
        translation: 'KJV',
        sourceVersionId: 'KJV',
        sources: [ScriptureReference(bookId: 'ROM', chapter: 1, verseStart: 1)],
        preview: true,
      );
      expect(s.isResolvable, isFalse);
    });
  });
}
