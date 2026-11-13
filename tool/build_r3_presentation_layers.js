#!/usr/bin/env node
// Builds the app's offline presentation-layer assets from the approved,
// immutable r3 editorial package:
//
//   docs/personalization/review-package/2026.11-revised-r3/MWB_REVISED_REVIEW_PACKAGE_r3/
//
// Usage:  node tool/build_r3_presentation_layers.js
//
// The package files are only read, never modified. Every input is verified
// against the SHA-256 fingerprints in MWB_REVISED_REVIEW_MANIFEST.json and
// cross-checked before anything is written. Output:
//
//   assets/mwb/presentation/kjv-mwb.layers.json
//   assets/mwb/presentation/web-mwb.layers.json
//
// Layer content is copied verbatim. Layers whose publication_disposition does
// not permit production display (requires_human_ratification,
// unresolved_withhold) are recorded WITHOUT their content, so a withheld
// layer cannot be displayed by any code path.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { parseCsv } = require('./r3_csv');

const ROOT = path.resolve(__dirname, '..');
const PKG = path.join(
  ROOT,
  'docs/personalization/review-package/2026.11-revised-r3/MWB_REVISED_REVIEW_PACKAGE_r3',
);
const OUT = path.join(ROOT, 'assets/mwb/presentation');
const DISPLAYABLE = 'editorial_eligible';
const PLACEHOLDER = /^(\{name\}|\[Name\]), /;

function fail(msg) {
  console.error(`r3 import FAILED: ${msg}`);
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(path.join(PKG, 'MWB_REVISED_REVIEW_MANIFEST.json'), 'utf8'));
if (manifest.packageVersion !== '2026.11-revised-r3') fail(`unexpected package ${manifest.packageVersion}`);

function readVerified(name) {
  const buf = fs.readFileSync(path.join(PKG, name));
  const sha = crypto.createHash('sha256').update(buf).digest('hex');
  const expected = manifest.output_fingerprints[name];
  if (!expected) fail(`${name} has no fingerprint in the manifest`);
  if (sha !== expected) fail(`${name} fingerprint ${sha} does not match manifest ${expected}`);
  return { rows: parseCsv(buf.toString('utf8')), sha };
}

function bibleIndex(file) {
  const bible = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets/bible', file), 'utf8'));
  const m = new Map();
  for (const b of bible.books) b.chapters.forEach((c, ci) => c.forEach((t, vi) => m.set(`${b.id}.${ci + 1}.${vi + 1}`, t)));
  return m;
}

const editions = [
  { edition: 'KJV-MWB', source: 'KJV', short: 'KJV', bible: 'kjv.json', out: 'kjv-mwb.layers.json' },
  { edition: 'WEB-MWB', source: 'WEB', short: 'WEB', bible: 'web.json', out: 'web-mwb.layers.json' },
];

const emptyAudit = readVerified('MWB_WEB_EMPTY_RECORD_AUDIT.csv').rows;
const titleAudit = readVerified('MWB_TITLE_FAITHFULNESS_AUDIT.csv').rows;

fs.mkdirSync(OUT, { recursive: true });
for (const e of editions) {
  const pres = readVerified(`MWB_COMPLETE_PRESENTATIONS_${e.short}.csv`);
  const layersCsv = readVerified(`MWB_LAYER_MAPPING_${e.short}.csv`);
  const receptions = readVerified(`MWB_COMPLETE_PERSONAL_RECEPTIONS_${e.short}.csv`);
  const canon = bibleIndex(e.bible);

  // 1. Canonical text: every r3 verse equals the app's bundled verse.
  const presByKey = new Map();
  for (const p of pres.rows) {
    if (p.edition !== e.edition) fail(`${p.verse_key}: edition ${p.edition}`);
    if (canon.get(p.verse_key) !== p.original_text) fail(`${e.short} ${p.verse_key}: canonical text differs from app asset`);
    presByKey.set(p.verse_key, p);
  }
  if (presByKey.size !== canon.size) fail(`${e.short}: ${presByKey.size} r3 verses vs ${canon.size} app verses`);

  // 2. Layers: unique ids, valid keys, consistent identity fields.
  const ids = new Set();
  const out = [];
  for (const l of layersCsv.rows) {
    if (ids.has(l.layer_id)) fail(`duplicate layer ${l.layer_id}`);
    ids.add(l.layer_id);
    if (l.edition !== e.edition) fail(`${l.layer_id}: edition ${l.edition}`);
    if (`${l.book_id}.${l.chapter}.${l.verse}` !== l.verse_key) fail(`${l.layer_id}: key/identity mismatch`);
    const suffix = { personalTitle: 'title', personalReception: 'reception', directPersonalisation: 'direct' }[l.layer_type];
    if (!suffix) fail(`${l.layer_id}: unknown layer_type ${l.layer_type}`);
    if (l.layer_id !== `${e.edition}:${l.verse_key}:${suffix}`) fail(`${l.layer_id}: id does not follow the specification`);
    const p = presByKey.get(l.verse_key);
    if (!p) fail(`${l.layer_id}: verse not in canonical index`);
    if (p.original_text === '') fail(`${l.layer_id}: layer on a non-renderable verse`);
    const displayable = l.publication_disposition === DISPLAYABLE;
    if (displayable) {
      if (l.layer_type === 'directPersonalisation') fail(`${l.layer_id}: name-in-text marked displayable`);
      if (!PLACEHOLDER.test(l.content)) fail(`${l.layer_id}: content lacks a leading name placeholder`);
      if ((l.content.match(/\{name\}|\[Name\]/g) || []).length !== 1) fail(`${l.layer_id}: more than one placeholder`);
    }
    out.push({
      id: l.layer_id,
      key: l.verse_key,
      type: l.layer_type,
      disposition: l.publication_disposition,
      decision: l.decision_status,
      proposal: l.source_proposal_id,
      proposalVersion: Number(l.source_proposal_version),
      // Withheld layers are recorded without their wording.
      content: displayable ? l.content : null,
    });
  }

  // 3. Receptions: the reception file and the layer file agree exactly.
  for (const r of receptions.rows) {
    const l = layersCsv.rows.find((x) => x.layer_id === r.layer_id);
    if (!l || l.layer_type !== 'personalReception') fail(`reception ${r.layer_id} has no reception layer`);
    if (l.content !== r.personal_reception_text) fail(`reception ${r.layer_id} wording differs from its layer`);
    if (presByKey.get(r.verse_key).original_text !== r.canonical_original) fail(`reception ${r.layer_id} canonical text differs`);
  }
  const receptionLayers = layersCsv.rows.filter((l) => l.layer_type === 'personalReception');
  if (receptionLayers.length !== receptions.rows.length) fail(`${e.short}: reception count mismatch`);

  // 4. The per-verse flags agree with the displayable layers.
  const shown = (key, type) => out.some((l) => l.key === key && l.type === type && l.content !== null);
  for (const p of pres.rows) {
    if ((p.has_personal_title === 'yes') !== shown(p.verse_key, 'personalTitle')) fail(`${p.verse_key}: title flag mismatch`);
    if ((p.has_personal_reception === 'yes') !== shown(p.verse_key, 'personalReception')) fail(`${p.verse_key}: reception flag mismatch`);
  }

  // 5. Withheld titles are exactly the title-faithfulness audit for this edition.
  const withheld = out.filter((l) => l.type === 'personalTitle' && l.disposition === 'unresolved_withhold').map((l) => l.key).sort();
  const audited = titleAudit.filter((a) => a.edition === e.edition).map((a) => a.verse_key).sort();
  if (JSON.stringify(withheld) !== JSON.stringify(audited)) fail(`${e.short}: withheld titles differ from the faithfulness audit`);

  const nonRenderable = pres.rows.filter((p) => p.original_text === '').map((p) => p.verse_key);
  if (e.short === 'WEB') {
    const audit = emptyAudit.map((a) => `${a.book_id}.${a.chapter}.${a.verse}`).sort();
    if (JSON.stringify([...nonRenderable].sort()) !== JSON.stringify(audit)) fail('WEB empty records differ from the audit');
  }

  const count = (t, d) => out.filter((l) => l.type === t && (!d || l.disposition === d)).length;
  const asset = {
    format: 1,
    package: manifest.packageVersion,
    catalogueVersion: manifest.catalogueVersion,
    edition: e.edition,
    sourceVersionId: e.source,
    generated: manifest.generated,
    sourceFingerprints: {
      layers: layersCsv.sha,
      receptions: receptions.sha,
      presentations: pres.sha,
    },
    counts: {
      verses: pres.rows.length,
      layers: out.length,
      displayableTitles: count('personalTitle', DISPLAYABLE),
      displayableReceptions: count('personalReception', DISPLAYABLE),
      withheldTitles: count('personalTitle', 'unresolved_withhold'),
      withheldDirect: count('directPersonalisation', 'requires_human_ratification'),
      nonRenderableVerses: nonRenderable.length,
    },
    nonRenderable,
    layers: out,
  };
  fs.writeFileSync(path.join(OUT, e.out), JSON.stringify(asset, null, 1) + '\n');
  console.log(`${e.edition}: ${JSON.stringify(asset.counts)}`);
}
console.log('r3 presentation layers written to assets/mwb/presentation/');
