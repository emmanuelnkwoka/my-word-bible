import 'package:flutter/foundation.dart';

/// A Christian teacher, minister, ministry or contributor.
@immutable
class Creator {
  const Creator({
    required this.id,
    required this.displayName,
    required this.role,
    required this.bio,
    required this.topicIds,
    this.location,
    this.followerCount = 0,
    this.contentCount = 0,
    this.isVerified = false,
    this.isSample = true,
  });

  final String id;
  final String displayName;

  /// e.g. "Bible teacher", "Pastor", "Worship ministry".
  final String role;
  final String bio;
  final List<String> topicIds;
  final String? location;
  final int followerCount;
  final int contentCount;

  /// Reserved for a future verification process; always false for samples.
  final bool isVerified;
  final bool isSample;

  String get initials {
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && p[0].toUpperCase() != p[0].toLowerCase())
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}
