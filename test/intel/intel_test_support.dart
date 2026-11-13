import 'dart:convert';
import 'dart:io';

import 'package:my_word_bible/data/repositories/intelligence_repository.dart';
import 'package:my_word_bible/features/intelligence/domain/intelligence_validator.dart';

import '../helpers/test_app.dart';

const intelDir = 'assets/intel';
const intelFiles = ['manifest.json', ...AssetIntelligenceRepository.dataFiles];

/// The shipped corpus files, read from disk (file name → text).
Map<String, String> shippedRaw() => {for (final f in intelFiles) f: File('$intelDir/$f').readAsStringSync()};

IntelligenceCorpus shippedCorpus() => parseIntelligenceCorpus(shippedRaw());

/// A copy of the shipped corpus with [file] changed by [edit].
Map<String, String> mutated(String file, void Function(Map<String, dynamic> json) edit) {
  final raw = shippedRaw();
  final json = jsonDecode(raw[file]!) as Map<String, dynamic>;
  edit(json);
  raw[file] = jsonEncode(json);
  return raw;
}

/// Finds the record with [id] in a decoded corpus file.
Map<String, dynamic> recordIn(Map<String, dynamic> json, String key, String id) =>
    (json[key] as List).cast<Map<String, dynamic>>().singleWhere((r) => r['id'] == id);

CanonicalScripture? _kjv;
CanonicalScripture? _web;

Future<CanonicalScripture> kjvText() async => _kjv ??= await CanonicalScripture.load(sharedTestBible, 'KJV');
Future<CanonicalScripture> webText() async => _web ??= await CanonicalScripture.load(sharedTestBible, 'WEB');

Future<IntelligenceValidator> validator() async =>
    IntelligenceValidator(canonical: await kjvText(), others: [await webText()]);

/// Validates a corpus built from [raw].
Future<IntelValidationReport> validateRaw(Map<String, String> raw) async =>
    (await validator()).validate(parseIntelligenceCorpus(raw));
