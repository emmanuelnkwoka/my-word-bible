import 'dart:io';

import 'package:my_word_bible/data/models/user_profile.dart';

/// The authoritative, immutable r3 package (read directly by these tests,
/// independently of the generated app asset).
const r3Dir =
    'docs/personalization/review-package/2026.11-revised-r3/MWB_REVISED_REVIEW_PACKAGE_r3';

final _cache = <String, List<Map<String, String>>>{};

/// RFC 4180 rows of an r3 CSV, as header → value maps.
List<Map<String, String>> r3Csv(String name) => _cache.putIfAbsent(name, () {
  var text = File('$r3Dir/$name').readAsStringSync();
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      row.add(field.toString().replaceAll('\r', ''));
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  final header = rows.removeAt(0);
  return [
    for (final r in rows)
      if (r.length == header.length) {for (var i = 0; i < header.length; i++) header[i]: r[i]},
  ];
});

List<Map<String, String>> r3Layers(String edition) => r3Csv('MWB_LAYER_MAPPING_${edition.split('-').first}.csv');

UserProfile profile({
  String first = 'Grace',
  String last = 'Okafor',
  String preferred = '',
  NamePreference pref = NamePreference.fullName,
}) => UserProfile(
  firstName: first,
  lastName: last,
  preferredName: preferred,
  gender: GenderPreference.preferNotToSay,
  namePreference: pref,
);
