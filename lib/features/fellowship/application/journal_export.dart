import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../../data/models/personal_rhythm.dart';
import '../../share/share_service.dart';

/// Export formats for personal reflections.
enum JournalExportFormat {
  text('Plain text (.txt)', 'txt', 'text/plain'),
  json('Structured data (.json)', 'json', 'application/json');

  const JournalExportFormat(this.label, this.extension, this.mimeType);
  final String label;
  final String extension;
  final String mimeType;
}

/// Builds an export. References are written as labels and ids with their
/// translation; no Scripture text is copied, so a reflection can never be
/// mistaken for Scripture.
class JournalExporter {
  const JournalExporter();

  static const formatId = 'mwb.reflections';
  static const formatVersion = 1;

  String fileName(DateTime at, JournalExportFormat f) =>
      'my-word-bible-reflections-${at.year}-${_two(at.month)}-${_two(at.day)}.${f.extension}';

  Uint8List build(List<JournalEntry> entries, JournalExportFormat format, {required DateTime exportedAt}) =>
      Uint8List.fromList(
        utf8.encode(switch (format) {
          JournalExportFormat.text => text(entries, exportedAt: exportedAt),
          JournalExportFormat.json => json(entries, exportedAt: exportedAt),
        }),
      );

  String text(List<JournalEntry> entries, {required DateTime exportedAt}) {
    final b = StringBuffer()
      ..writeln('My Word Bible: personal reflections')
      ..writeln(
        'Exported ${_date(exportedAt)} · ${entries.length} ${entries.length == 1 ? 'reflection' : 'reflections'}',
      )
      ..writeln('These are your own words, not Scripture. This file is not encrypted.')
      ..writeln();
    for (final e in entries) {
      b
        ..writeln('────────────────────────')
        ..writeln(_date(e.createdAt.toLocal()));
      if (e.title.isNotEmpty) b.writeln(e.title);
      if (e.reference != null) b.writeln('On ${e.reference!.label} (${e.versionId})');
      b
        ..writeln()
        ..writeln(e.body)
        ..writeln();
    }
    return b.toString();
  }

  String json(List<JournalEntry> entries, {required DateTime exportedAt}) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': formatId,
        'version': formatVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'note': 'Personal reflections, not Scripture. References identify passages; no verse text is included.',
        'entries': [
          for (final e in entries)
            {
              'id': e.id,
              'createdAt': e.createdAt.toUtc().toIso8601String(),
              'updatedAt': e.updatedAt.toUtc().toIso8601String(),
              'title': e.title,
              'body': e.body,
              'source': e.source.name,
              if (e.reference != null)
                'reference': {
                  'book': e.reference!.bookId,
                  'chapter': e.reference!.chapter,
                  'verseStart': e.reference!.verseStart,
                  'verseEnd': e.reference!.verseEnd,
                  'label': e.reference!.label,
                  'translation': e.versionId,
                },
              if (e.dailyWordDate != null) 'dailyWordDate': e.dailyWordDate,
            },
        ],
      });

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// Hands an export file to the system share sheet, where the user chooses
/// where it goes (Files, Drive, email…). Nothing is sent automatically.
abstract interface class JournalExportService {
  Future<ShareOutcome> shareFile(Uint8List bytes, {required String fileName, required String mimeType});
}

class NativeJournalExportService implements JournalExportService {
  const NativeJournalExportService();

  @override
  Future<ShareOutcome> shareFile(Uint8List bytes, {required String fileName, required String mimeType}) async {
    final r = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: 'My Word Bible reflections',
        title: 'My Word Bible reflections',
      ),
    );
    return switch (r.status) {
      ShareResultStatus.success => ShareOutcome.shared,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }
}
