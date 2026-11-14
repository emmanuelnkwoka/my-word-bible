import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/data/models/personal_rhythm.dart';
import 'package:my_word_bible/data/models/scripture_reference.dart';
import 'package:my_word_bible/features/fellowship/application/journal_export.dart';

void main() {
  final at = DateTime.utc(2026, 11, 10, 7, 30);
  final entries = [
    JournalEntry(
      id: 'b1d2c3e4-0000-4000-8000-000000000001',
      createdAt: at,
      updatedAt: at,
      title: 'Peace',
      body: 'Line one\nLine two',
      source: PersonalOrigin.reader,
      reference: const ScriptureReference(bookId: 'JHN', chapter: 14, verseStart: 27),
      versionId: 'KJV',
    ),
    JournalEntry(
      id: 'b1d2c3e4-0000-4000-8000-000000000002',
      createdAt: at,
      updatedAt: at,
      title: '',
      body: 'Unlinked "quoted" words',
      source: PersonalOrigin.independent,
    ),
  ];
  const exporter = JournalExporter();

  test('plain text: every reflection, its reference and a clear label; no verse text', () {
    final t = exporter.text(entries, exportedAt: at);
    expect(t, contains('2 reflections'));
    expect(t, contains('These are your own words, not Scripture. This file is not encrypted.'));
    expect(t, contains('On John 14:27 (KJV)'));
    expect(t, contains('Line one\nLine two'));
    expect(t, contains('Unlinked "quoted" words'));
    expect(t, isNot(contains('Peace I leave with you')), reason: 'no Scripture text is copied');
  });

  test('JSON: versioned, complete and lossless', () {
    final j = jsonDecode(exporter.json(entries, exportedAt: at)) as Map<String, dynamic>;
    expect(j['format'], 'mwb.reflections');
    expect(j['version'], 1);
    final list = (j['entries'] as List).cast<Map<String, dynamic>>();
    expect(list, hasLength(2));
    expect(list.first['id'], entries.first.id);
    expect(list.first['body'], 'Line one\nLine two');
    expect(list.first['reference'], {
      'book': 'JHN',
      'chapter': 14,
      'verseStart': 27,
      'verseEnd': null,
      'label': 'John 14:27',
      'translation': 'KJV',
    });
    expect(list.last.containsKey('reference'), isFalse);
    expect(list.last['body'], 'Unlinked "quoted" words');
  });

  test('files are UTF-8 with dated names and correct types', () {
    final bytes = exporter.build(entries, JournalExportFormat.text, exportedAt: at);
    expect(utf8.decode(bytes), exporter.text(entries, exportedAt: at));
    expect(
      exporter.fileName(DateTime(2026, 11, 10), JournalExportFormat.text),
      'my-word-bible-reflections-2026-11-10.txt',
    );
    expect(JournalExportFormat.json.mimeType, 'application/json');
    expect(JournalExportFormat.text.mimeType, 'text/plain');
  });
}
