import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Text shared for a passage: Scripture, reference and translation, then an
/// optional editorial line kept visibly separate.
@immutable
class SharePayload {
  const SharePayload({required this.text, required this.subject});
  final String text;
  final String subject;

  factory SharePayload.scripture({
    required String scripture,
    required String reference,
    required String translation,
    String? heading,
  }) {
    final head = heading == null ? '' : '$heading\n\n';
    return SharePayload(
      subject: '$reference ($translation)',
      text: '$head“$scripture”\n— $reference ($translation)\n\nShared from My Word Bible',
    );
  }
}

enum ShareOutcome { shared, dismissed, unavailable }

/// Native sharing boundary (Android share sheet). Tests replace it.
abstract interface class ShareService {
  Future<ShareOutcome> shareText(SharePayload payload);
  Future<ShareOutcome> shareImage(Uint8List png, {required String fileName, required SharePayload payload});

  /// Shares several images at once (a paginated passage) through the native
  /// share sheet. The images are generated on the device.
  Future<ShareOutcome> shareImages(
    List<Uint8List> pngs, {
    required List<String> fileNames,
    required SharePayload payload,
  });
}

class NativeShareService implements ShareService {
  const NativeShareService();

  /// PNG by default; JPG when the Card Studio exports JPG files.
  static String _mimeFor(String fileName) {
    final n = fileName.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') ? 'image/jpeg' : 'image/png';
  }

  static ShareOutcome _map(ShareResult r) => switch (r.status) {
    ShareResultStatus.success => ShareOutcome.shared,
    ShareResultStatus.dismissed => ShareOutcome.dismissed,
    ShareResultStatus.unavailable => ShareOutcome.unavailable,
  };

  @override
  Future<ShareOutcome> shareText(SharePayload payload) async => _map(
    await SharePlus.instance.share(ShareParams(text: payload.text, subject: payload.subject, title: payload.subject)),
  );

  @override
  Future<ShareOutcome> shareImage(Uint8List png, {required String fileName, required SharePayload payload}) async =>
      _map(
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(png, mimeType: _mimeFor(fileName), name: fileName)],
            fileNameOverrides: [fileName],
            subject: payload.subject,
            title: payload.subject,
          ),
        ),
      );

  @override
  Future<ShareOutcome> shareImages(
    List<Uint8List> pngs, {
    required List<String> fileNames,
    required SharePayload payload,
  }) async => _map(
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (var i = 0; i < pngs.length; i++) XFile.fromData(pngs[i], mimeType: _mimeFor(fileNames[i]), name: fileNames[i]),
        ],
        fileNameOverrides: fileNames,
        subject: payload.subject,
        title: payload.subject,
      ),
    ),
  );
}
