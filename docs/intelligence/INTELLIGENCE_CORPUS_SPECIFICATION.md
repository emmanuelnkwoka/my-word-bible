# Scripture Intelligence Corpus: Specification (Stage C, v1.0.0)

This document describes the local GODSAID intelligence corpus inside MY WORD BIBLE: what is stored, how it is loaded, and which rules it must obey. Counts are in `INTELLIGENCE_COVERAGE_REPORT.md`; sources are in `INTELLIGENCE_DATA_PROVENANCE.md`.

## 1. Principles

1. **References, never verse text.** Records point at canonical references (`"PSA 23:1"`, `"LAM 3:22-23"`, USFM book ids). One record serves KJV, WEB and any future translation. The strict decoder rejects unknown fields such as `kjv` or `verseText`.
2. **Canonical Scripture is read-only.** The corpus never writes to or alters `assets/bible/*`.
3. **Editorial text is typed as editorial.** Prayers, blessings and declarations extend `EditorialContent`, where `isScripture` is always `false`. Each carries a `displayLabel` (for example "Prayer — assembled from Scripture, not Scripture text") that must be shown with it.
4. **Context first.** Speaker, author and original audience are separate fields and are never merged.
5. **No approval in the corpus.** Personalisation eligibility has no "approved" value. Approval exists only in MWB rulesets, recorded by a human reviewer.
6. **Provenance and review on every record.**
7. **Offline only.** Bundled assets are read once, on first use. There are no network calls, no database and no AI.

## 2. Files (`assets/intel/`)

Every file has `schemaVersion: 1` and `corpusVersion: "1.0.0"`.

| File | Key | Record type (Dart) |
|---|---|---|
| `manifest.json` | — | `IntelManifest`: versions, canonical version (`KJV`), expected count per file, rejected seed records |
| `contexts.json` | `contexts` | `IntelContext` |
| `situations.json` | `situations` | `LifeSituation` |
| `promises.json` | `promises` | `IntelPromise` |
| `blessings.json` | `blessings` | `Blessing` (editorial) |
| `prayers.json` | `prayers` | `IntelPrayer` (editorial) |
| `declarations.json` | `declarations` | `Declaration` (editorial) |
| `commands.json` | `commands` | `IntelCommand` |
| `identity_themes.json` | `identityThemes` | `IdentityTheme` |
| `worship_themes.json` | `worshipThemes` | `WorshipTheme` |
| `relationships.json` | `relationships` | `ScriptureRelationship` |
| `journeys.json` | `journeys` | `Journey` / `JourneyStep` |
| `taxonomy.json` | `terms`, `links` | `TaxonomyTerm`, `TaxonomyLink` |

The manifest count for each file must match its contents, or loading fails.

## 3. Common fields

```json
"provenance": { "origin": "demoSeed | newlyCurated | historicalExport",
                "seedId": "pr-peace-1", "seedLine": 1268, "basis": "…", "changes": ["…"] },
"review":     { "status": "pendingEditorialReview | editoriallyReviewed | needsRevision",
                "flags": ["…"], "reviewer": null, "reviewedOn": null }
```

- `demoSeed` and `historicalExport` records must name their `seedId`; `newlyCurated` records must state their `basis`.
- `editoriallyReviewed` requires both `reviewer` and `reviewedOn`.
- Ids are globally unique across all record types and taxonomy terms.

## 4. Record types

| Type | Required content | Notes |
|---|---|---|
| **Context** | `reference`; `voice` (god / jesus / inspiredHuman); `speaker`; `author`; `originalAudience`; `addressee` (specificIndividual, representative, collective, god, general, testimony, narrative, unspecified); `literaryForm`; `classification`; `isConditional` + `conditionNote`; `personalisation.{eligibility, risk, note}`; `contextNote`; `keywords` | `historicalContext` and `literaryContext` exist but are empty in v1 (see the coverage report). Id = `ctx-<BOOK>-<c>-<v>`. |
| **Life situation** | `name`, `description`, `references`, `promiseIds`, `prayerIds`, `declarationIds`, `journeyIds` | Links to promises and declarations come from **shared supporting Scripture**; prayers and journeys link because they name the situation. Nothing is linked by word similarity. |
| **Promise** | `title`, `references`, `category`, `originalAudience`, `scope` (corporate / individualHistorical / general), `conditions[]`, `contextNote`, `receptionGuidance` | Every promise reference must have a context. |
| **Blessing** | `title`, `category`, `text`, `references`, `groundingNote` | Editorial |
| **Prayer** | `title`, `situationId`, `text`, `references` (≥ 2) | Editorial, addressed to God, never attributed to God |
| **Declaration** | `title`, `category`, `text` (third person, `{name}`), `firstPersonText`, `references`, `groundingNote` | `personalised(name)` substitutes the name. With no usable name it returns `firstPersonText`; a name is never invented. |
| **Command** | `title`, `references`, `commandType` (directImperative / exhortation / invitation), `addressedTo`, `relatedPromiseIds`, `contextNote` | Separate from promises. A command may point to a related promise. |
| **Identity theme** | `title`, `references`, `holder` (who it describes), `note` | Not an unconditional promise |
| **Worship theme** | `title`, `references`, `worshipKind` (praise / thanksgiving / trust) | |
| **Relationship** | `from`, `to`, `type` (theme, explanation, quotation, supporting, promise, contextual), `bidirectional`, `explanation` | Navigable from both ends when `bidirectional` |
| **Journey** | `title`, `description`, `situationId`, ordered `steps[]` (`order`, `type`, `note`, `reference` for verse steps or `targetId` otherwise) | Step types: situation, verse, promise, identity, worship, command, prayer, declaration, blessing |
| **Taxonomy** | `terms[]` (`id`, `label`, `kind`); `links[]` (`termId`, `objectType`, `objectId`) | Controlled theme vocabulary |

## 5. Code

| File | Responsibility |
|---|---|
| `lib/data/models/intelligence.dart` | Enums, record classes, strict decoder (`IntelDecoder`, `IntelFormatException`) |
| `lib/data/repositories/intelligence_repository.dart` | `IntelligenceRepository` interface; `AssetIntelligenceRepository` (loads once, caches, parses in an isolate, never caches a failure); `IntelligenceCorpus` indexes (`byId`, `typed`, `contextsFor`, `relationshipsFor`, `journeysForSituation`, `recordsCiting`, `termsFor`, `searchEntries`); `parseIntelligenceCorpus`; `referencesOverlap` |
| `lib/features/intelligence/domain/intelligence_validator.dart` | `CanonicalScripture` (a translation's text, for checks); `IntelligenceValidator` → `IntelValidationReport` with `IntelIssue(code, severity, objectId, message)` |
| `lib/features/intelligence/application/intelligence_providers.dart` | `intelligenceCorpusProvider`; `passageIntelligenceProvider(reference)` → context, relationships and citing records |
| `lib/app/app_providers.dart` | `intelligenceRepositoryProvider` |

### Repository queries

| Query | Description |
|---|---|
| `contextFor(ref)` | Most specific context covering any verse of `ref`, including verses inside a range |
| `situations()`, `situation(id)` | All life situations, or one by id |
| `promises()`, `blessings()`, `prayers()`, `declarations()` | All records of that type |
| `commands()`, `identityThemes()`, `worshipThemes()` | All records of that type |
| `relationshipsFor(ref)` | Relationships touching `ref`, returned as `RelationshipView` (other end, direction) |
| `journeys()`, `journeysForSituation(id)` | All journeys, or those starting from one situation |
| `searchEntries()` | Search metadata (title, subtitle, keywords, references, editorial body) for future Search V2 |
| `corpus()` | The full corpus, with the helpers above |

Failures surface as `UnknownFailure`. Messages name the file, record and field, for example `prayers.json › py-fear: "references" must be a list of strings`.

## 6. Validation rules

`IntelligenceValidator` checks references against KJV, the canonical version. It reports WEB omissions and versification gaps as warnings.

| # | Rule | Issue code(s) | Severity |
|---|---|---|---|
| 1 | Every reference resolves to existing verses (no whole chapters, known book, valid range) | `unresolvedReference`, `wholeChapterReference`, `omittedInTranslation` | error; warning for other translations |
| 2 | Every referenced id exists and has the right type; rejected seeds have live replacements | `unknownTarget` | error |
| 3 | No duplicate ids (records and taxonomy terms) | `duplicateId` | error |
| 4 | No orphans: every record cites Scripture, every term is linked, journeys have ≥ 2 steps | `orphan` | error |
| 5 | Prayers cite ≥ 2 references | `prayerNeedsTwoReferences` | error |
| 6 | Declarations contain no gendered pronouns for the reader (lower-case *he/him/his/she/her…* anywhere; *She/Her* capitalised). They use `{name}` only in `text`, never in `firstPersonText`. No other placeholders, including the demo's `⟦F⟧`/`⟦N⟧`. Placeholders appear nowhere else in the corpus. | `genderedPronoun`, `placeholderMisuse` | error |
| 7 | Relationships have a type and an explanation (≥ 20 characters) and do not link a verse to itself | `missingExplanation` | error |
| 8 | Journey steps resolve to the right record type; order is 1…n; every step has a note | `journeyStepUnresolved`, `journeyOrder` | error |
| 9 | Contexts name speaker, author and audience. Unrecorded addressee is a warning. Personalisation risk is not below the minimum for voice, addressee and conditionality. | `contextIncomplete`, `riskUnderstated` | error / warning |
| 10 | Conditional contexts state the condition; promises on conditional contexts list conditions | `conditionMissing` | error |
| 11 | A promise on a collective passage has corporate scope; a promise to a specific person is not "general"; declarations and blessings on collective passages carry a `groundingNote`; identity themes name their holder; every promise reference has a context | `corporateAsIndividual`, `missingContext` | error |
| 12 | Editorial text is not a copy of a cited verse; no verse text is stored (enforced by the strict decoder) | `scriptureCopiedAsEditorial` | error |
| 13 | Nothing is marked reviewed without a reviewer and date; "approved" is not a valid eligibility (decoder); provenance names its source | `approvalNotRecorded`, `provenanceIncomplete` | error |
| 14 | Editorial content carries a non-Scripture label | `editorialLabelMissing` | error |
| — | Situation links agree with the prayers and journeys that name the situation | `linkInconsistent` | warning |

Capitalised *He/Him/His* is accepted in declarations as a reverent reference to God. Lower-case forms are always rejected, because the demo used them for the reader.

## 7. Performance

- **Size:** the corpus is 13 files, about 251 KB on disk. `contexts.json` is the largest at 128 KB, because it carries every audience and note.
- **Loading:** files load on first use only. App start-up does not read them, because no screen uses the corpus yet. Parsing runs in a background isolate (`compute`).
- **Measured cost (test VM, desktop JIT):** about 213 ms for the first load and parse; repeated calls return the cached corpus in 0 ms; validating all 283 records and 467 references takes about 93 ms. No device measurement has been made.

## 8. Changing the corpus

1. Edit the JSON, keeping ids stable and recording the change in `provenance.changes`.
2. Update the manifest count if records were added or removed.
3. Run `flutter test test/intel`. The shipped-corpus test fails on any validation error.
4. Changing `review.status` to `editoriallyReviewed` requires a real reviewer name and date.
