import 'dart:typed_data';

import 'package:my_word_bible/core/storage/key_value_store.dart';
import 'package:my_word_bible/data/models/social.dart';
import 'package:my_word_bible/data/repositories/social_repositories.dart';
import 'package:my_word_bible/features/share/export/card_export.dart';

import '../helpers/test_app.dart';

/// Records exports instead of touching the gallery or other apps.
class FakeCardExportService implements CardExportService {
  FakeCardExportService({this.installed = const {'com.whatsapp.w4b', 'org.telegram.messenger'}, this.supported = true});

  final Set<String> installed;
  final bool supported;
  final saved = <({String fileName, String mimeType, Uint8List bytes, bool location})>[];
  final shared = <({String package, List<String> fileNames, String mimeType, String? text})>[];

  @override
  Future<Set<String>> installedPackages(Iterable<String> packages) async =>
      supported ? packages.where(installed.contains).toSet() : {};

  @override
  Future<ExportResult> saveToGallery(Uint8List bytes, {required String fileName, required String mimeType}) async {
    if (!supported) return const ExportResult(ExportStatus.unsupported);
    saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes, location: false));
    return ExportResult(ExportStatus.saved, location: 'Pictures/My Word Bible/$fileName');
  }

  @override
  Future<ExportResult> saveToLocation(Uint8List bytes, {required String fileName, required String mimeType}) async {
    if (!supported) return const ExportResult(ExportStatus.unsupported);
    saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes, location: true));
    return ExportResult(ExportStatus.saved, location: fileName);
  }

  @override
  Future<ExportResult> shareToApp(
    String package,
    List<Uint8List> files, {
    required List<String> fileNames,
    required String mimeType,
    String? text,
  }) async {
    if (!installed.contains(package)) return const ExportResult(ExportStatus.notInstalled);
    shared.add((package: package, fileNames: fileNames, mimeType: mimeType, text: text));
    return ExportResult(ExportStatus.opened, location: package);
  }
}

/// A fully wired on-device social stack over [store].
({
  LocalScriptureShareRepository shares,
  DemoUserDirectory directory,
  LocalSafetyRepository safety,
  LocalFollowRepository follows,
  LocalNotificationRepository notes,
}) socialStack(KeyValueStore store) {
  final directory = DemoUserDirectory(store);
  final safety = LocalSafetyRepository(store);
  return (
    shares: LocalScriptureShareRepository(
      store: store,
      bible: sharedTestBible,
      directory: directory,
      safety: safety,
      clock: () => fixedNow,
    ),
    directory: directory,
    safety: safety,
    follows: LocalFollowRepository(store, safety),
    notes: LocalNotificationRepository(store, clock: () => fixedNow),
  );
}

const me = SocialIdentity(userId: 'mwb_local_me', username: 'grace.reader', displayName: 'Grace Reader');
