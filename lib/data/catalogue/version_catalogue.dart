import 'package:flutter/foundation.dart';

import '../models/bible.dart';

// ── Licence records ─────────────────────────────────────────────────────

const _kjvLicence = VersionLicence(
  copyrightHolder:
      'Public domain. In the United Kingdom, rights in the Authorized Version are vested in the Crown '
      'and administered by Cambridge University Press under Letters Patent.',
  type: LicenceType.publicDomain,
  status: LicensingStatus.notRequired,
  offlineStorage: PermissionState.notRequired,
  distribution: PermissionState.notRequired,
  derivativeWorks: PermissionState.notRequired,
  attribution: 'Identify the text as the King James Version (KJV).',
  quotationRestrictions: 'None outside the United Kingdom.',
  notes: 'Distribution within the United Kingdom should be confirmed against the Crown rights before UK launch.',
);

const _kjvMwbLicence = VersionLicence(
  copyrightHolder: 'Source text: King James Version (public domain). Personalisation rules: MY WORD BIBLE.',
  type: LicenceType.derivedEdition,
  status: LicensingStatus.notRequired,
  offlineStorage: PermissionState.notRequired,
  distribution: PermissionState.notRequired,
  derivativeWorks: PermissionState.notRequired,
  attribution: 'Label as "KJV-MWB — a personalised rendering of the King James Version".',
  quotationRestrictions:
      'Shared text must say it is a personalised rendering, and the original KJV must remain available.',
  notes: 'Subject to the same United Kingdom Crown-rights caveat as the KJV.',
);

const _webLicence = VersionLicence(
  copyrightHolder: 'Public domain. "World English Bible" is a trademark of eBible.org.',
  type: LicenceType.publicDomain,
  status: LicensingStatus.notRequired,
  offlineStorage: PermissionState.notRequired,
  distribution: PermissionState.notRequired,
  derivativeWorks: PermissionState.notRequired,
  attribution: 'Identify the text as the World English Bible (WEB).',
  quotationRestrictions: 'None.',
  notes:
      'Source: eBible.org engwebp (66-book edition, verse-per-line text). eBible.org asks that changed text not be '
      'called the World English Bible.',
);

const _webMwbLicence = VersionLicence(
  copyrightHolder: 'Source text: World English Bible (public domain). Personalisation rules: MY WORD BIBLE.',
  type: LicenceType.derivedEdition,
  status: LicensingStatus.notRequired,
  offlineStorage: PermissionState.notRequired,
  distribution: PermissionState.notRequired,
  derivativeWorks: PermissionState.notRequired,
  attribution:
      'Label as "WEB-MWB — a personalised rendering derived from the World English Bible". Personalised text '
      'must never be presented as the World English Bible itself.',
  quotationRestrictions:
      'Shared text must say it is a personalised rendering, and the unchanged WEB must remain available.',
  notes: 'Respects the eBible.org trademark condition: changed text is not called the World English Bible.',
);

VersionLicence _publisherLicence(String holder) => VersionLicence(
  copyrightHolder: holder,
  type: LicenceType.publisherLicence,
  status: LicensingStatus.notObtained,
  offlineStorage: PermissionState.notGranted,
  distribution: PermissionState.notGranted,
  derivativeWorks: PermissionState.notGranted,
  attribution: 'Publisher-specified copyright notice. To be confirmed in a licence agreement.',
  quotationRestrictions:
      'Publisher gratis-use limits apply to quotation. App distribution requires a licence agreement.',
  notes: 'Text must not be bundled or distributed until a licence is recorded.',
);

VersionLicence _derivedFromPublisher(String holder) => VersionLicence(
  copyrightHolder: holder,
  type: LicenceType.derivedEdition,
  status: LicensingStatus.notObtained,
  offlineStorage: PermissionState.notGranted,
  distribution: PermissionState.notGranted,
  derivativeWorks: PermissionState.notGranted,
  attribution: 'To be agreed with the publisher.',
  quotationRestrictions: 'To be agreed with the publisher.',
  notes:
      'A personalised edition is a derivative work. It requires explicit publisher permission, separate from any '
      'licence to display the translation.',
);

const _nkjvHolder = 'Thomas Nelson (HarperCollins Christian Publishing)';
const _nivHolder = 'Biblica, Inc.';
const _nltHolder = 'Tyndale House Foundation';

/// Every Bible version the app knows about. Listing a version here does not
/// make it available: [BibleVersionInfo.status] and its licence decide that.
final List<BibleVersionInfo> bibleVersionCatalogue = List.unmodifiable([
  const BibleVersionInfo(
    id: 'KJV',
    abbreviation: 'KJV',
    name: 'King James Version',
    status: BibleVersionStatus.installed,
    note: 'Complete text installed on this device. Public domain.',
    licence: _kjvLicence,
  ),
  const BibleVersionInfo(
    id: 'KJV-MWB',
    abbreviation: 'KJV-MWB',
    name: 'King James Version — My Word Bible edition',
    status: BibleVersionStatus.installed,
    note:
        'Personalised edition of the KJV. Approved personal passages appear in it; every other verse reads '
        'exactly as the KJV while passages await theological review.',
    kind: BibleVersionKind.personalised,
    sourceVersionId: 'KJV',
    licence: _kjvMwbLicence,
    personalisation: PersonalisationAvailability.available,
    reviewPolicy: ReviewPolicy.approvedRulesOnly,
  ),
  const BibleVersionInfo(
    id: 'WEB',
    abbreviation: 'WEB',
    name: 'World English Bible',
    status: BibleVersionStatus.installed,
    note: 'Complete text installed on this device. Public domain.',
    licence: _webLicence,
  ),
  const BibleVersionInfo(
    id: 'WEB-MWB',
    abbreviation: 'WEB-MWB',
    name: 'My Word Bible edition — derived from the World English Bible',
    status: BibleVersionStatus.installed,
    note:
        'Personalised edition derived from the WEB. Approved personal passages appear in it; every other verse '
        'reads exactly as the WEB while passages await theological review.',
    kind: BibleVersionKind.personalised,
    sourceVersionId: 'WEB',
    licence: _webMwbLicence,
    personalisation: PersonalisationAvailability.available,
    reviewPolicy: ReviewPolicy.approvedRulesOnly,
  ),
  BibleVersionInfo(
    id: 'NKJV',
    abbreviation: 'NKJV',
    name: 'New King James Version',
    status: BibleVersionStatus.requiresLicense,
    note: 'Requires a publisher licence. Not available yet.',
    licence: _publisherLicence(_nkjvHolder),
  ),
  BibleVersionInfo(
    id: 'NKJV-MWB',
    abbreviation: 'NKJV-MWB',
    name: 'New King James Version — My Word Bible edition',
    status: BibleVersionStatus.requiresLicense,
    note: 'Requires the publisher’s permission for a personalised edition.',
    kind: BibleVersionKind.personalised,
    sourceVersionId: 'NKJV',
    licence: _derivedFromPublisher(_nkjvHolder),
    personalisation: PersonalisationAvailability.blockedByLicence,
    reviewPolicy: ReviewPolicy.approvedRulesOnly,
  ),
  BibleVersionInfo(
    id: 'NIV',
    abbreviation: 'NIV',
    name: 'New International Version',
    status: BibleVersionStatus.requiresLicense,
    note: 'Requires a publisher licence. Not available yet.',
    licence: _publisherLicence(_nivHolder),
  ),
  BibleVersionInfo(
    id: 'NIV-MWB',
    abbreviation: 'NIV-MWB',
    name: 'New International Version — My Word Bible edition',
    status: BibleVersionStatus.requiresLicense,
    note: 'Requires the publisher’s permission for a personalised edition.',
    kind: BibleVersionKind.personalised,
    sourceVersionId: 'NIV',
    licence: _derivedFromPublisher(_nivHolder),
    personalisation: PersonalisationAvailability.blockedByLicence,
    reviewPolicy: ReviewPolicy.approvedRulesOnly,
  ),
  BibleVersionInfo(
    id: 'NLT',
    abbreviation: 'NLT',
    name: 'New Living Translation',
    status: BibleVersionStatus.requiresLicense,
    note: 'Requires a publisher licence. Not available yet.',
    licence: _publisherLicence(_nltHolder),
  ),
  BibleVersionInfo(
    id: 'NLT-MWB',
    abbreviation: 'NLT-MWB',
    name: 'New Living Translation — My Word Bible edition',
    status: BibleVersionStatus.requiresLicense,
    note: 'Requires the publisher’s permission for a personalised edition.',
    kind: BibleVersionKind.personalised,
    sourceVersionId: 'NLT',
    licence: _derivedFromPublisher(_nltHolder),
    personalisation: PersonalisationAvailability.blockedByLicence,
    reviewPolicy: ReviewPolicy.approvedRulesOnly,
  ),
]);

/// An original translation and the personalised editions derived from it.
@immutable
class VersionFamily {
  const VersionFamily(this.original, this.editions);
  final BibleVersionInfo original;
  final List<BibleVersionInfo> editions;
}

/// Lookup helpers and integrity rules over the catalogue.
class VersionCatalogue {
  VersionCatalogue(List<BibleVersionInfo> versions) : versions = List.unmodifiable(versions);

  final List<BibleVersionInfo> versions;

  BibleVersionInfo? byId(String id) {
    for (final v in versions) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// The original translation a version is read from (itself for originals).
  BibleVersionInfo? sourceOf(String id) {
    final v = byId(id);
    if (v == null) return null;
    return v.isPersonalised ? byId(v.sourceVersionId!) : v;
  }

  List<BibleVersionInfo> editionsOf(String originalId) =>
      versions.where((v) => v.isPersonalised && v.sourceVersionId == originalId).toList();

  /// Originals in catalogue order, each followed by its MWB editions.
  List<VersionFamily> get families => [
    for (final v in versions.where((v) => !v.isPersonalised)) VersionFamily(v, editionsOf(v.id)),
  ];

  /// May this version be selected for reading right now? Requires technical
  /// support **and** legal permission (plus derivative permission for MWB).
  bool isSelectable(BibleVersionInfo v) {
    if (!v.isInstalled) return false;
    final licence = v.licence;
    if (licence != null && !licence.permitsDistribution) return false;
    if (!v.isPersonalised) return true;
    final source = sourceOf(v.id);
    final sourceLicence = source?.licence;
    return source != null &&
        isSelectable(source) &&
        (licence?.derivativeWorks.allows ?? false) &&
        (sourceLicence?.derivativeWorks.allows ?? false) &&
        v.personalisation == PersonalisationAvailability.available;
  }

  /// Structural problems in the catalogue. Empty when consistent.
  List<String> integrityIssues() {
    final issues = <String>[];
    final ids = <String>{};
    for (final v in versions) {
      if (!ids.add(v.id)) issues.add('${v.id}: duplicate id');
      if (v.isPersonalised) {
        final source = v.sourceVersionId == null ? null : byId(v.sourceVersionId!);
        if (source == null) issues.add('${v.id}: source version missing');
        if (source != null && source.isPersonalised) issues.add('${v.id}: source must be an original translation');
        if (v.reviewPolicy != ReviewPolicy.approvedRulesOnly) issues.add('${v.id}: must publish approved rules only');
        if (v.personalisation == PersonalisationAvailability.available &&
            !(v.licence?.derivativeWorks.allows ?? false)) {
          issues.add('${v.id}: personalisation available without derivative-work permission');
        }
      } else {
        if (v.sourceVersionId != null) issues.add('${v.id}: original must not have a source');
        if (v.personalisation != PersonalisationAvailability.notApplicable) {
          issues.add('${v.id}: originals are never personalised');
        }
      }
      if (v.isInstalled && !(v.licence?.permitsDistribution ?? false)) {
        issues.add('${v.id}: installed without distribution permission');
      }
    }
    return issues;
  }
}
