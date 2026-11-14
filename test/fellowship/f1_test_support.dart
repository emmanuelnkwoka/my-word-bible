import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_word_bible/features/fellowship/application/journal_export.dart';
import 'package:my_word_bible/features/share/share_service.dart';

/// A fresh temporary directory, removed after the test.
String tempDir() {
  final d = Directory.systemTemp.createTempSync('mwb_f1_');
  addTearDown(() {
    if (d.existsSync()) d.deleteSync(recursive: true);
  });
  return d.path.replaceAll('\\', '/');
}

/// True if [needle] (UTF-8) occurs anywhere in [haystack].
bool containsBytes(Uint8List haystack, String needle) {
  final n = needle.codeUnits;
  outer:
  for (var i = 0; i + n.length <= haystack.length; i++) {
    for (var j = 0; j < n.length; j++) {
      if (haystack[i + j] != n[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Records exports instead of opening the system share sheet.
class FakeJournalExportService implements JournalExportService {
  final files = <({Uint8List bytes, String fileName, String mimeType})>[];

  @override
  Future<ShareOutcome> shareFile(Uint8List bytes, {required String fileName, required String mimeType}) async {
    files.add((bytes: bytes, fileName: fileName, mimeType: mimeType));
    return ShareOutcome.shared;
  }
}

/// A private reflection sentence that must never appear outside the store.
const secretSentence = 'Lord, I confess my fear about the hospital results tomorrow';
