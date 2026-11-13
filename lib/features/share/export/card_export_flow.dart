import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/widgets/sheets.dart';
import '../scripture_image_composer.dart';
import '../scripture_share_sheet.dart';
import '../share_service.dart';
import 'card_export.dart';

/// Saving and sending rendered cards, shared by the quick-share sheet and
/// the Card Studio. Feedback is honest: "saved" only after the gallery or
/// file accepted the image; "opened" means the other app opened and the
/// user still decides whether to post.
abstract final class CardExportFlow {
  /// Saves every page (a long passage may be several images).
  static Future<ExportResult> save(
    BuildContext context,
    WidgetRef ref, {
    required List<ShareImagePage> pages,
    required ShareScripture scripture,
    CardFileType type = CardFileType.png,
    int quality = CardEncoder.defaultJpgQuality,
    bool chooseLocation = false,
  }) async {
    final export = ref.read(cardExportServiceProvider);
    var last = const ExportResult(ExportStatus.failed);
    var saved = 0;
    for (final p in pages) {
      final bytes = await CardEncoder.encode(p.png, type, quality: quality);
      final name = CardEncoder.fileName(scripture.reference, type, index: p.index, count: p.count);
      last = chooseLocation
          ? await export.saveToLocation(bytes, fileName: name, mimeType: type.mimeType)
          : await export.saveToGallery(bytes, fileName: name, mimeType: type.mimeType);
      if (last.status != ExportStatus.saved) break;
      saved++;
    }
    if (!context.mounted) return last;
    switch (last.status) {
      case ExportStatus.saved:
        final where = chooseLocation ? 'the chosen folder' : 'Photos · Pictures/My Word Bible';
        showMwbSnack(context, saved == 1 ? 'Saved ${type.label} to $where' : 'Saved $saved ${type.label} images to $where');
      case ExportStatus.cancelled:
        showMwbSnack(context, saved == 0 ? 'Not saved' : 'Saved $saved of ${pages.length}; the rest were cancelled');
      case ExportStatus.permissionNeeded:
        showMwbSnack(context, 'Allow storage access, then tap Save again.');
      case ExportStatus.unsupported:
        // Fallback: the system share sheet offers "Save image" on iOS and
        // file managers on other platforms.
        await _shareSheet(context, ref, pages, scripture, type: type, quality: quality, withText: false);
      case ExportStatus.notInstalled || ExportStatus.opened || ExportStatus.failed:
        showMwbSnack(context, 'The image could not be saved${last.detail == null ? '' : ' (${last.detail})'}.');
    }
    return last;
  }

  /// Sends the card to the app behind [destination], or the share sheet.
  /// When the app drops captions (Instagram, Facebook) the caption is copied
  /// to the clipboard so the user can paste it.
  static Future<ExportResult> send(
    BuildContext context,
    WidgetRef ref, {
    required List<ShareImagePage> pages,
    required ShareScripture scripture,
    required ShareDestination destination,
    CardFileType type = CardFileType.png,
    int quality = CardEncoder.defaultJpgQuality,
    bool withText = true,
    String? extraText,
  }) async {
    final caption = _caption(scripture, extraText);
    final app = destination.app;
    if (app == null) {
      return _shareSheet(context, ref, pages, scripture, type: type, quality: quality, withText: withText, extraText: extraText);
    }
    final export = ref.read(cardExportServiceProvider);
    final installed = await export.installedPackages(app.packages);
    final available = app.packages.where(installed.contains).toList();
    var package = available.firstOrNull ?? '';
    // e.g. WhatsApp and WhatsApp Business both installed: only the user knows
    // which one they use (one may not even be registered), so ask.
    if (available.length > 1 && context.mounted) {
      final chosen = await showMwbSheet<String>(
        context,
        title: 'Which ${app.label}?',
        builder: (ctx) => Column(
          children: [
            for (final p in available)
              ListTile(
                key: Key('export.app.$p'),
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(ShareApp.variantLabel(p)),
                onTap: () => Navigator.of(ctx).pop(p),
              ),
          ],
        ),
      );
      if (chosen == null) return const ExportResult(ExportStatus.cancelled);
      package = chosen;
    }
    if (package.isEmpty) {
      if (context.mounted) {
        showMwbSnack(context, '${app.label} isn’t installed here. Choose another app.');
        return _shareSheet(context, ref, pages, scripture, type: type, quality: quality, withText: withText, extraText: extraText);
      }
      return const ExportResult(ExportStatus.notInstalled);
    }
    final files = [for (final p in pages) await CardEncoder.encode(p.png, type, quality: quality)];
    final names = [for (final p in pages) CardEncoder.fileName(scripture.reference, type, index: p.index, count: p.count)];
    final sendText = withText && app.acceptsCaption ? caption : null;
    if (withText && !app.acceptsCaption) await Clipboard.setData(ClipboardData(text: caption));
    final result = await export.shareToApp(package, files, fileNames: names, mimeType: type.mimeType, text: sendText);
    if (!context.mounted) return result;
    switch (result.status) {
      case ExportStatus.opened:
        final copied = withText && !app.acceptsCaption ? ' Caption copied.' : '';
        showMwbSnack(context, 'Opened ${app.label}. ${destination.hint}$copied');
      case ExportStatus.unsupported:
        return _shareSheet(context, ref, pages, scripture, type: type, quality: quality, withText: withText, extraText: extraText);
      default:
        showMwbSnack(context, '${app.label} could not be opened. Try “Other apps”.');
    }
    return result;
  }

  static String _caption(ShareScripture s, String? extra) {
    final base = sharePayloadFor(s).text;
    final e = extra?.trim();
    return e == null || e.isEmpty ? base : '$e\n\n$base';
  }

  /// The existing native share sheet (unchanged service), with JPG support.
  static Future<ExportResult> _shareSheet(
    BuildContext context,
    WidgetRef ref,
    List<ShareImagePage> pages,
    ShareScripture scripture, {
    required CardFileType type,
    required int quality,
    required bool withText,
    String? extraText,
  }) async {
    try {
      final files = [for (final p in pages) await CardEncoder.encode(p.png, type, quality: quality)];
      final payload = sharePayloadFor(scripture);
      final outcome = await ref.read(shareServiceProvider).shareImages(
        files,
        fileNames: [for (final p in pages) CardEncoder.fileName(scripture.reference, type, index: p.index, count: p.count)],
        payload: withText
            ? SharePayload(subject: payload.subject, text: _caption(scripture, extraText))
            : SharePayload(subject: payload.subject, text: ''),
      );
      if (outcome == ShareOutcome.unavailable && context.mounted) {
        showMwbSnack(context, 'Sharing is not available on this device.');
      }
      return ExportResult(outcome == ShareOutcome.unavailable ? ExportStatus.unsupported : ExportStatus.opened);
    } catch (_) {
      if (context.mounted) showMwbSnack(context, 'The images could not be shared. Please try again.');
      return const ExportResult(ExportStatus.failed);
    }
  }
}
