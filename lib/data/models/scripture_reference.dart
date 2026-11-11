import 'package:flutter/foundation.dart';

import 'bible_canon.dart';

/// A translation-independent pointer to Scripture: a chapter, verse or range.
@immutable
class ScriptureReference implements Comparable<ScriptureReference> {
  const ScriptureReference({required this.bookId, required this.chapter, this.verseStart, this.verseEnd});

  final String bookId;
  final int chapter;
  final int? verseStart;
  final int? verseEnd;

  bool get isWholeChapter => verseStart == null;

  CanonBook get book => BibleCanon.bookOrThrow(bookId);

  /// "John 3:16", "Philippians 4:6–7", "Psalms 23".
  String get label {
    final name = book.name == 'Psalms' && verseStart != null ? 'Psalm' : book.name;
    if (verseStart == null) return '$name $chapter';
    if (verseEnd == null || verseEnd == verseStart) return '$name $chapter:$verseStart';
    return '$name $chapter:$verseStart–$verseEnd';
  }

  /// Stable key for storage and equality ("JHN.3.16-16").
  String get key => '$bookId.$chapter.${verseStart ?? 0}-${verseEnd ?? verseStart ?? 0}';

  ScriptureReference get chapterOnly => ScriptureReference(bookId: bookId, chapter: chapter);

  bool containsVerse(int verse) {
    if (verseStart == null) return true;
    return verse >= verseStart! && verse <= (verseEnd ?? verseStart!);
  }

  Map<String, dynamic> toJson() => {
    'b': bookId,
    'c': chapter,
    if (verseStart != null) 'vs': verseStart,
    if (verseEnd != null) 've': verseEnd,
  };

  factory ScriptureReference.fromJson(Map<String, dynamic> json) => ScriptureReference(
    bookId: json['b'] as String,
    chapter: json['c'] as int,
    verseStart: json['vs'] as int?,
    verseEnd: json['ve'] as int?,
  );

  /// Compact literal form used in sample data: "ISA 41:10", "PHP 4:6-7", "PSA 23".
  factory ScriptureReference.parseCompact(String s) {
    final m = RegExp(r'^([1-3A-Z]{3})\s+(\d+)(?::(\d+)(?:-(\d+))?)?$').firstMatch(s.trim());
    if (m == null) throw FormatException('Invalid compact reference', s);
    return ScriptureReference(
      bookId: m.group(1)!,
      chapter: int.parse(m.group(2)!),
      verseStart: m.group(3) == null ? null : int.parse(m.group(3)!),
      verseEnd: m.group(4) == null ? null : int.parse(m.group(4)!),
    );
  }

  /// Parses user input like "John 3:16", "1 cor 13", "ps 23:1-4".
  /// Returns null if the text is not a recognisable reference.
  static ScriptureReference? tryParse(String input) {
    final m = RegExp(r'^\s*([1-3]?\s*[A-Za-z][A-Za-z .]*?)\s*(\d+)(?:\s*[:.]\s*(\d+)(?:\s*[-–]\s*(\d+))?)?\s*$')
        .firstMatch(input);
    if (m == null) return null;
    final book = BibleCanon.matchBook(m.group(1)!);
    if (book == null) return null;
    final chapter = int.parse(m.group(2)!);
    if (chapter < 1 || chapter > book.chapterCount) return null;
    final vs = m.group(3) == null ? null : int.parse(m.group(3)!);
    final ve = m.group(4) == null ? null : int.parse(m.group(4)!);
    if (vs != null && vs < 1) return null;
    if (vs != null && ve != null && ve < vs) return null;
    return ScriptureReference(bookId: book.id, chapter: chapter, verseStart: vs, verseEnd: ve);
  }

  @override
  int compareTo(ScriptureReference other) {
    final b = BibleCanon.indexOf(bookId).compareTo(BibleCanon.indexOf(other.bookId));
    if (b != 0) return b;
    final c = chapter.compareTo(other.chapter);
    if (c != 0) return c;
    return (verseStart ?? 0).compareTo(other.verseStart ?? 0);
  }

  @override
  bool operator ==(Object other) => other is ScriptureReference && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => label;
}
