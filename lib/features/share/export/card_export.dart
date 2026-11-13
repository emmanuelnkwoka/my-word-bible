import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../scripture_image_composer.dart';

/// Image file types offered for saving and sharing cards.
enum CardFileType {
  png('PNG', 'png', 'image/png', 'Sharpest text and graphics'),
  jpg('JPG', 'jpg', 'image/jpeg', 'Smaller file, easy to send');

  const CardFileType(this.label, this.extension, this.mimeType, this.description);
  final String label;
  final String extension;
  final String mimeType;
  final String description;
}

/// Encodes rendered cards. PNG bytes come straight from the renderer (the
/// preview shows the same bytes); JPG is re-encoded from them on a
/// background isolate. Both keep the full card size.
abstract final class CardEncoder {
  static const defaultJpgQuality = 92;

  static Future<Uint8List> encode(Uint8List png, CardFileType type, {int quality = defaultJpgQuality}) async {
    if (type == CardFileType.png) return png;
    return compute(_pngToJpg, (png, quality.clamp(40, 100)));
  }

  static Uint8List _pngToJpg((Uint8List, int) args) {
    final decoded = img.decodePng(args.$1);
    if (decoded == null) throw const FormatException('Card image could not be decoded');
    return img.encodeJpg(decoded, quality: args.$2, chroma: img.JpegChroma.yuv444);
  }

  /// Reads width and height from PNG or JPEG bytes (for checks and tests).
  static ({int width, int height})? dimensions(Uint8List bytes) {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null) return null;
    return (width: info.width, height: info.height);
  }

  static String fileName(String reference, CardFileType type, {int index = 0, int count = 1}) {
    final base = 'my-word-bible-${reference.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
    return count == 1 ? '$base.${type.extension}' : '$base-${index + 1}-of-$count.${type.extension}';
  }
}

/// Installed social apps that can receive a card directly.
enum ShareApp {
  whatsapp('WhatsApp', ['com.whatsapp', 'com.whatsapp.w4b'], acceptsCaption: true),
  instagram('Instagram', ['com.instagram.android'], acceptsCaption: false),
  facebook('Facebook', ['com.facebook.katana', 'com.facebook.lite'], acceptsCaption: false),
  telegram('Telegram', ['org.telegram.messenger', 'org.telegram.messenger.web', 'org.thunderdog.challegram'], acceptsCaption: true);

  const ShareApp(this.label, this.packages, {required this.acceptsCaption});
  final String label;

  /// Android package names, preferred first (e.g. WhatsApp, then WhatsApp Business).
  final List<String> packages;

  /// Whether the app keeps text sent with an image. Instagram and Facebook
  /// drop it, so the caption is copied to the clipboard instead.
  final bool acceptsCaption;

  static Set<String> get allPackages => {for (final a in values) ...a.packages};

  /// Human name of an installed variant.
  static String variantLabel(String package) => switch (package) {
    'com.whatsapp' => 'WhatsApp',
    'com.whatsapp.w4b' => 'WhatsApp Business',
    'com.instagram.android' => 'Instagram',
    'com.facebook.katana' => 'Facebook',
    'com.facebook.lite' => 'Facebook Lite',
    'org.telegram.messenger' => 'Telegram',
    'org.telegram.messenger.web' => 'Telegram (web version)',
    'org.thunderdog.challegram' => 'Telegram X',
    _ => package,
  };
}

/// Where the user intends to post. Picks the right card size and app.
enum ShareDestination {
  whatsappStatus(
    'WhatsApp Status',
    ShareFormat.story,
    ShareApp.whatsapp,
    'WhatsApp opens its share screen. Choose “My status” at the top to post it.',
  ),
  whatsappChat('WhatsApp chat', ShareFormat.portrait, ShareApp.whatsapp, 'Choose the chat in WhatsApp.'),
  instagramStory(
    'Instagram Story',
    ShareFormat.story,
    ShareApp.instagram,
    'Instagram asks where to post. Choose Story. Paste the caption if you want it.',
  ),
  instagramPost(
    'Instagram post',
    ShareFormat.portrait,
    ShareApp.instagram,
    'Instagram asks where to post. Choose Feed. Paste the caption if you want it.',
  ),
  instagramSquare('Instagram square', ShareFormat.square, ShareApp.instagram, 'Choose Feed in Instagram.'),
  facebookPost(
    'Facebook post',
    ShareFormat.portrait,
    ShareApp.facebook,
    'Facebook opens a new post. Paste the caption if you want it.',
  ),
  facebookStory(
    'Facebook Story',
    ShareFormat.story,
    ShareApp.facebook,
    'Facebook asks where to share. Choose Story if it is offered.',
  ),
  telegram('Telegram', ShareFormat.portrait, ShareApp.telegram, 'Choose the chat in Telegram.'),
  anyApp('Other apps', ShareFormat.portrait, null, 'Email, Messages and every other app on your phone.');

  const ShareDestination(this.label, this.format, this.app, this.hint);
  final String label;
  final ShareFormat format;
  final ShareApp? app;
  final String hint;
}

enum ExportStatus {
  /// Saved; [ExportResult.location] says where.
  saved,

  /// The target app was opened with the card. The user decides whether to post.
  opened,

  /// The user cancelled (e.g. the "Save as" picker).
  cancelled,
  notInstalled,
  permissionNeeded,

  /// Not available on this platform (falls back to the share sheet).
  unsupported,
  failed,
}

@immutable
class ExportResult {
  const ExportResult(this.status, {this.location, this.detail});
  final ExportStatus status;
  final String? location;
  final String? detail;

  bool get ok => status == ExportStatus.saved || status == ExportStatus.opened;
}

/// Device boundary for saving cards and handing them to a specific app.
/// Separate from [ShareService] (the existing native share sheet), which is
/// unchanged and remains the universal fallback.
abstract interface class CardExportService {
  /// Which of [packages] are installed (Android). Empty where unsupported.
  Future<Set<String>> installedPackages(Iterable<String> packages);

  /// Saves to the device gallery ("Pictures/My Word Bible" on Android).
  Future<ExportResult> saveToGallery(Uint8List bytes, {required String fileName, required String mimeType});

  /// Lets the user pick a folder and file name (Android Storage Access Framework).
  Future<ExportResult> saveToLocation(Uint8List bytes, {required String fileName, required String mimeType});

  /// Opens [package] with the images (and [text] if given).
  Future<ExportResult> shareToApp(
    String package,
    List<Uint8List> files, {
    required List<String> fileNames,
    required String mimeType,
    String? text,
  });
}

/// Android implementation over a small platform channel in MainActivity
/// (MediaStore, Storage Access Framework, FileProvider). Other platforms
/// report [ExportStatus.unsupported] and the UI falls back to the share sheet.
class PlatformCardExportService implements CardExportService {
  const PlatformCardExportService();

  static const _channel = MethodChannel('com.xpatsoft.mwb/card_export');

  static ExportResult _result(Object? raw) {
    if (raw is! Map) return const ExportResult(ExportStatus.failed);
    final status = ExportStatus.values.asNameMap()[raw['status']] ?? ExportStatus.failed;
    return ExportResult(status, location: raw['location'] as String?, detail: raw['detail'] as String?);
  }

  Future<ExportResult> _call(String method, Map<String, Object?> args) async {
    try {
      return _result(await _channel.invokeMethod<Object?>(method, args));
    } on MissingPluginException {
      return const ExportResult(ExportStatus.unsupported);
    } on PlatformException catch (e) {
      return ExportResult(ExportStatus.failed, detail: e.message);
    }
  }

  @override
  Future<Set<String>> installedPackages(Iterable<String> packages) async {
    try {
      final list = await _channel.invokeListMethod<String>('installedPackages', {'packages': packages.toList()});
      return {...?list};
    } on MissingPluginException {
      return {};
    } on PlatformException {
      return {};
    }
  }

  @override
  Future<ExportResult> saveToGallery(Uint8List bytes, {required String fileName, required String mimeType}) =>
      _call('saveToGallery', {'bytes': bytes, 'fileName': fileName, 'mimeType': mimeType});

  @override
  Future<ExportResult> saveToLocation(Uint8List bytes, {required String fileName, required String mimeType}) =>
      _call('saveToLocation', {'bytes': bytes, 'fileName': fileName, 'mimeType': mimeType});

  @override
  Future<ExportResult> shareToApp(
    String package,
    List<Uint8List> files, {
    required List<String> fileNames,
    required String mimeType,
    String? text,
  }) => _call('shareToApp', {
    'package': package,
    'files': files,
    'fileNames': fileNames,
    'mimeType': mimeType,
    'text': text,
  });
}
