import 'package:flutter/foundation.dart';

import '../../../data/models/user_profile.dart';

/// Result of resolving the name an MWB edition may use.
enum NameStatus {
  /// The preferred form was available.
  resolved,

  /// The preferred form was incomplete (e.g. no surname), so the first name
  /// was used. Nothing is invented.
  fellBackToFirstName,

  /// The reader chose no name insertion.
  insertionOff,

  /// No usable name in the profile.
  missing,

  /// The stored name contains characters that are not safe to place inside
  /// a Scripture rendering.
  invalid,
}

@immutable
class NameResolution {
  const NameResolution(this.status, [this.name]);

  const NameResolution.off() : this(NameStatus.insertionOff);

  final NameStatus status;

  /// The name to insert; null when no name may be inserted.
  final String? name;

  bool get canInsert => name != null;
}

/// Turns profile data and the reader's [NamePreference] into the name used by
/// MWB renderings. Gender is never read.
abstract final class PersonalNameResolver {
  static const maxLength = 60;

  /// Letters (any script), combining marks, spaces, hyphens, apostrophes and
  /// full stops. Anything else could smuggle words or symbols into Scripture.
  static final _allowed = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M}'’.\- ]*$", unicode: true);

  static String _clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  static NameResolution resolve(UserProfile? profile) {
    if (profile == null) return const NameResolution(NameStatus.missing);
    final first = _clean(profile.firstName);
    final last = _clean(profile.lastName);
    final preferred = _clean(profile.preferredName);

    String? candidate;
    var status = NameStatus.resolved;
    switch (profile.namePreference) {
      case NamePreference.none:
        return const NameResolution.off();
      case NamePreference.fullName:
        if (first.isNotEmpty && last.isNotEmpty) {
          candidate = '$first $last';
        } else if (first.isNotEmpty) {
          candidate = first;
          status = NameStatus.fellBackToFirstName;
        }
      case NamePreference.firstName:
        if (first.isNotEmpty) candidate = first;
      case NamePreference.preferredName:
        if (preferred.isNotEmpty) {
          candidate = preferred;
        } else if (first.isNotEmpty) {
          candidate = first;
          status = NameStatus.fellBackToFirstName;
        }
    }
    if (candidate == null) return const NameResolution(NameStatus.missing);
    if (candidate.length > maxLength || !_allowed.hasMatch(candidate)) return const NameResolution(NameStatus.invalid);
    return NameResolution(status, candidate);
  }
}
