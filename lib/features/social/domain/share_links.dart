import 'package:flutter/foundation.dart';

import '../../../data/models/social.dart';
import '../../../data/repositories/social_repositories.dart';

/// Builds and parses shared-Scripture links.
///
/// Web form: `https://mywordbible.com/s/{shareId}` (needs the web service and
/// domain association before it opens anything; see MWB_DEEP_LINK_SPEC.md).
/// App form: `mywordbible://app/s/{shareId}` (works today on Android).
abstract final class ShareLinkCodec {
  static const host = 'mywordbible.com';
  static const appScheme = 'mywordbible';

  static Uri webUrl(String shareId) => Uri.https(host, '/s/$shareId');
  static Uri appUrl(String shareId) => Uri(scheme: appScheme, host: 'app', path: '/s/$shareId');

  /// In-app route for a share.
  static String routePath(String shareId) => '/s/$shareId';

  /// The share id in a web link, app link or route path; null for anything
  /// else (other hosts, malformed ids, extra path segments).
  static String? parse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final h = uri.host.toLowerCase();
    final okOrigin = switch (scheme) {
      'https' => h == host || h == 'www.$host',
      appScheme => h == 'app',
      '' => h.isEmpty,
      _ => false,
    };
    if (!okOrigin) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length != 2 || segs.first != 's') return null;
    final id = segs[1];
    return shareIdPattern.hasMatch(id) ? id : null;
  }

}

enum ShareLinkOutcome { opened, notOnDevice, forbidden, invalid }

@immutable
class ShareResolution {
  const ShareResolution(this.outcome, [this.share]);
  final ShareLinkOutcome outcome;
  final ScriptureShare? share;
}

/// Resolves a share id for the current user, enforcing privacy: a private
/// share opens only for its sender or recipient.
class ShareLinkResolver {
  const ShareLinkResolver(this._shares, {required this.currentUserId});
  final ScriptureShareRepository _shares;
  final String currentUserId;

  ShareResolution resolve(String shareId) {
    if (!shareIdPattern.hasMatch(shareId)) return const ShareResolution(ShareLinkOutcome.invalid);
    final share = _shares.byId(shareId);
    // Without the sharing service, only shares already on this device resolve.
    if (share == null) return const ShareResolution(ShareLinkOutcome.notOnDevice);
    if (!share.canBeOpenedBy(currentUserId)) return const ShareResolution(ShareLinkOutcome.forbidden);
    return ShareResolution(ShareLinkOutcome.opened, share);
  }
}

/// What a public link preview (web page, chat unfurl) may show. It never
/// contains the personal message, the recipient or the care intent.
@immutable
class PublicShareMetadata {
  const PublicShareMetadata({
    required this.title,
    required this.description,
    required this.reference,
    required this.translation,
    required this.senderName,
    required this.url,
  });

  factory PublicShareMetadata.of(ScriptureShare share) {
    final text = share.text;
    return PublicShareMetadata(
      title: '${share.referenceLabel} (${share.translationId})',
      description: text.length <= 180 ? text : '${text.substring(0, 177).trimRight()}…',
      reference: share.referenceLabel,
      translation: share.translationId,
      senderName: share.senderName,
      url: ShareLinkCodec.webUrl(share.id).toString(),
    );
  }

  final String title;
  final String description;
  final String reference;
  final String translation;
  final String senderName;
  final String url;

  Map<String, String> toOpenGraph() => {
    'og:title': title,
    'og:description': description,
    'og:url': url,
    'og:site_name': 'My Word Bible',
    'mwb:sender': senderName,
  };
}
