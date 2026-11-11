import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/core/errors/app_failure.dart';
import 'package:my_word_bible/data/mock/mock_content.dart';
import 'package:my_word_bible/data/mock/mock_creators.dart';
import 'package:my_word_bible/data/mock/mock_daily.dart';
import 'package:my_word_bible/data/mock/mock_topics.dart';
import 'package:my_word_bible/data/models/bible_canon.dart';
import 'package:my_word_bible/data/models/content.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/data/repositories/content_repository.dart';

import 'helpers/test_app.dart';

void main() {
  final bible = sharedTestBible;

  group('AssetBibleRepository (KJV)', () {
    test('contains the full canon', () async {
      final books = await bible.books('KJV');
      expect(books, hasLength(66));
      expect(books.where((b) => b.isOld), hasLength(39));
      for (final b in books) {
        expect(BibleCanon.byId(b.id)!.chapterCount, b.chapterCount, reason: b.id);
      }
    });

    test('returns exact canonical text', () async {
      final p = await bible.passage('KJV', ScriptureReference.parseCompact('JHN 3:16'));
      expect(
        p.text,
        'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him '
        'should not perish, but have everlasting life.',
      );
      final psalm = await bible.chapter('KJV', 'PSA', 23);
      expect(psalm, hasLength(6));
      expect(psalm.first.text, 'The LORD is my shepherd; I shall not want.');
    });

    test('ranges and errors', () async {
      final range = await bible.passage('KJV', ScriptureReference.parseCompact('PHP 4:6-7'));
      expect(range.verses.map((v) => v.number), [6, 7]);
      await expectLater(
        bible.passage('KJV', const ScriptureReference(bookId: 'JHN', chapter: 3, verseStart: 99)),
        throwsA(isA<NotFoundFailure>()),
      );
      await expectLater(bible.chapter('KJV', 'JHN', 22), throwsA(isA<NotFoundFailure>()));
      await expectLater(bible.books('NIV'), throwsA(isA<FeatureUnavailableFailure>()));
    });

    test('word search requires all words', () async {
      final hits = await bible.search('KJV', 'fear not', limit: 500);
      expect(hits, isNotEmpty);
      for (final h in hits) {
        final lower = h.verse.text.toLowerCase();
        expect(lower.contains('fear') && lower.contains('not'), isTrue);
      }
    });
  });

  group('Sample data integrity', () {
    Future<void> expectResolves(ScriptureReference r) async {
      final p = await bible.passage('KJV', r);
      expect(p.verses, isNotEmpty, reason: r.label);
    }

    test('every Scripture reference in sample data exists in the KJV text', () async {
      final refs = <ScriptureReference>{
        for (final t in mockTopics) ...t.keyScriptures,
        for (final c in mockContent) ...c.scriptureRefs,
        ...dailyScriptureRefs,
        for (final p in dailyPromises) p.reference,
      };
      for (final r in refs) {
        await expectResolves(r);
      }
    });

    test('content references valid creators and topics, with unique ids', () {
      final creatorIds = mockCreators.map((c) => c.id).toSet();
      final topicIds = mockTopics.map((t) => t.id).toSet();
      expect(mockContent.map((c) => c.id).toSet(), hasLength(mockContent.length));
      for (final c in mockContent) {
        expect(creatorIds, contains(c.creatorId), reason: c.id);
        for (final t in c.topicIds) {
          expect(topicIds, contains(t), reason: '${c.id} → $t');
        }
        if (c.sourceContentId != null) {
          expect(mockContent.any((x) => x.id == c.sourceContentId && x.type == ContentType.video), isTrue);
        }
      }
      for (final t in mockTopics) {
        for (final r in t.relatedTopicIds) {
          expect(topicIds, contains(r), reason: '${t.id} → $r');
        }
      }
      expect(primaryTopicIds, hasLength(16));
      expect(topicIds.containsAll(primaryTopicIds), isTrue);
    });

    test('sample media is disclosed as a stand-in', () {
      for (final c in mockContent.where((c) => c.type == ContentType.audio)) {
        expect(c.media.isPlayable, isTrue);
        expect(c.media.isSampleStandIn, isTrue);
      }
      for (final c in mockContent) {
        expect(c.isSample, isTrue);
      }
    });
  });

  group('MockContentRepository', () {
    final repo = MockContentRepository(latency: Duration.zero);

    test('topic content for Fear spans audio, video, article and Scripture', () async {
      final items = await repo.byTopic('fear');
      final types = items.map((i) => i.type).toSet();
      expect(types, containsAll(ContentType.values));
    });

    test('lookups and not-found errors', () async {
      expect((await repo.contentById('a-fear-night')).title, 'When Fear Knocks at Night');
      await expectLater(repo.contentById('missing'), throwsA(isA<NotFoundFailure>()));
      await expectLater(repo.topicById('missing'), throwsA(isA<NotFoundFailure>()));
      await expectLater(repo.creatorById('missing'), throwsA(isA<NotFoundFailure>()));
    });

    test('featured, recent and creator lists', () async {
      final featured = await repo.featured();
      expect(featured.every((c) => c.isFeatured), isTrue);
      final recent = await repo.recent(limit: 5);
      expect(recent, hasLength(5));
      for (var i = 1; i < recent.length; i++) {
        expect(
          recent[i - 1].publishedAt.isAfter(recent[i].publishedAt) ||
              recent[i - 1].publishedAt == recent[i].publishedAt,
          isTrue,
        );
      }
      final byCreator = await repo.byCreator('ruth-adeyemi');
      expect(byCreator.every((c) => c.creatorId == 'ruth-adeyemi'), isTrue);
    });

    test('recommendations favour the user’s topics and respect type', () async {
      final recs = await repo.recommended(topicIds: {'family'}, types: {ContentType.audio}, limit: 3);
      expect(recs.every((c) => c.type == ContentType.audio), isTrue);
      expect(recs.first.topicIds, contains('family'));
    });

    test('hidden moderation states are not served', () async {
      final hidden = ContentItem(
        id: 'hidden',
        type: ContentType.video,
        title: 'Pending item',
        description: 'Awaiting review',
        creatorId: 'grace-hall',
        topicIds: const ['faith'],
        publishedAt: DateTime(2026),
        moderationStatus: ModerationStatus.pendingReview,
      );
      final r = MockContentRepository(latency: Duration.zero, content: [...mockContent, hidden]);
      expect((await r.allContent()).any((c) => c.id == 'hidden'), isFalse);
      expect((await r.byTopic('faith')).any((c) => c.id == 'hidden'), isFalse);
    });

    test('remote repository reports unavailability instead of guessing', () async {
      final remote = RemoteContentRepository(throwingApiClient());
      await expectLater(remote.allContent(), throwsA(isA<FeatureUnavailableFailure>()));
    });
  });
}
