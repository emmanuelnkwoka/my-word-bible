import '../../../data/models/scripture_reference.dart';

/// Local validation for community contributions.
abstract final class UploadValidation {
  static const maxTopics = 3;
  static const maxReferences = 5;

  static String? title(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Add a title.';
    if (s.length < 5) return 'Titles need at least 5 characters.';
    if (s.length > 80) return 'Use 80 characters or fewer.';
    return null;
  }

  static String? description(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Add a short description.';
    if (s.length < 20) return 'Describe the message in at least 20 characters.';
    if (s.length > 600) return 'Use 600 characters or fewer.';
    return null;
  }

  static String? attribution(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Tell us who delivered this message.';
    if (s.length < 2) return 'Enter the speaker or ministry name.';
    if (s.length > 60) return 'Use 60 characters or fewer.';
    return null;
  }

  static String? topics(Set<String> ids) {
    if (ids.isEmpty) return 'Choose at least one topic.';
    if (ids.length > maxTopics) return 'Choose up to $maxTopics topics.';
    return null;
  }

  static String? references(List<ScriptureReference> refs) =>
      refs.isEmpty ? 'Add at least one Scripture reference.' : null;

  /// Parses a typed reference. Returns (reference, error).
  static (ScriptureReference?, String?) parseReference(String input, List<ScriptureReference> existing) {
    final s = input.trim();
    if (s.isEmpty) return (null, 'Type a reference such as John 3:16.');
    final ref = ScriptureReference.tryParse(s);
    if (ref == null) return (null, 'That doesn’t look like a Bible reference.');
    if (existing.contains(ref)) return (null, 'That reference is already added.');
    if (existing.length >= maxReferences) return (null, 'Add up to $maxReferences references.');
    return (ref, null);
  }

  static String? rights(bool confirmed) =>
      confirmed ? null : 'Please confirm you have permission to share this material.';
}
