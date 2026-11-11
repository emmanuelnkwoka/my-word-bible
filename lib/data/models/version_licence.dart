import 'package:flutter/foundation.dart';

/// Legal basis on which a Bible version may be used.
enum LicenceType {
  /// No copyright licence needed in most jurisdictions.
  publicDomain('Public domain'),

  /// Copyrighted translation that needs a publisher licence.
  publisherLicence('Publisher licence'),

  /// A personalised MWB edition derived from a source translation. Its
  /// legality follows the source licence plus any derivative-work permission.
  derivedEdition('Derived edition');

  const LicenceType(this.label);
  final String label;
}

/// Where the app stands in obtaining the licence for a version.
enum LicensingStatus {
  notRequired('No licence required'),
  notObtained('Licence not obtained'),
  obtained('Licence obtained');

  const LicensingStatus(this.label);
  final String label;
}

/// A single permission (offline storage, distribution, derivative works).
///
/// Technical support for a version is tracked separately from these legal
/// permissions: a version can be fully implemented and still not permitted.
enum PermissionState {
  /// Not needed (e.g. public domain).
  notRequired,

  /// Explicitly granted in a recorded licence.
  granted,

  /// Not granted. The capability must stay disabled.
  notGranted,

  /// Not yet established. Treated exactly like [notGranted].
  unknown;

  bool get allows => this == notRequired || this == granted;
}

/// Licensing record for one catalogue entry.
@immutable
class VersionLicence {
  const VersionLicence({
    required this.copyrightHolder,
    required this.type,
    required this.status,
    required this.offlineStorage,
    required this.distribution,
    required this.derivativeWorks,
    required this.attribution,
    required this.quotationRestrictions,
    this.notes = '',
  });

  final String copyrightHolder;
  final LicenceType type;
  final LicensingStatus status;

  /// May the full text be stored on the device?
  final PermissionState offlineStorage;

  /// May the text be distributed inside the app?
  final PermissionState distribution;

  /// May a personalised derivative (an MWB edition) be created and
  /// distributed? Permission to display a translation does **not** imply this.
  final PermissionState derivativeWorks;

  /// Attribution that must accompany the text wherever it is shown or shared.
  final String attribution;
  final String quotationRestrictions;
  final String notes;

  /// True when the text may legally be bundled and shown in the app.
  bool get permitsDistribution => offlineStorage.allows && distribution.allows;
}
