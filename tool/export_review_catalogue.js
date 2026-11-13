// Builds the supervisor review exports from the records written by
//   EXPORT_REVIEW_CATALOGUE=1 flutter test test/mwb/catalogue_export_test.dart
//
//   node tool/export_review_catalogue.js [--no-pdf]
//
// Output (exports/personalisation-review/):
//   MWB_Personalisation_Review_Catalogue.xlsx   workbook (7 + 1 sheets)
//   csv/*.csv                                   stable-ID CSVs
//   review_decisions_template.csv               the import format for decisions
//   printable/<edition>-review-catalogue.html   printable document (+ .pdf)
//
// No dependencies: the XLSX is written as Office Open XML in a ZIP built here.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { execFileSync } = require('child_process');

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'exports/personalisation-review');
const records = JSON.parse(fs.readFileSync(path.join(outDir, 'review_records.json'), 'utf8'));
const noPdf = process.argv.includes('--no-pdf');

// ── ZIP (deflate) ─────────────────────────────────────────────────────────
const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
function zip(files) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const [name, content] of files) {
    const data = Buffer.from(content, 'utf8');
    const comp = zlib.deflateRawSync(data, { level: 6 });
    const nameBuf = Buffer.from(name, 'utf8');
    const crc = crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x0800, 6); local.writeUInt16LE(8, 8);
    local.writeUInt16LE(0, 10); local.writeUInt16LE(0x5b21, 12); local.writeUInt32LE(crc, 14); local.writeUInt32LE(comp.length, 18);
    local.writeUInt32LE(data.length, 22); local.writeUInt16LE(nameBuf.length, 26); local.writeUInt16LE(0, 28);
    locals.push(local, nameBuf, comp);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0); central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6); central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(8, 10); central.writeUInt16LE(0, 12); central.writeUInt16LE(0x5b21, 14); central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(comp.length, 20); central.writeUInt32LE(data.length, 24); central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt16LE(0, 30); central.writeUInt16LE(0, 32); central.writeUInt16LE(0, 34); central.writeUInt16LE(0, 36);
    central.writeUInt32LE(0, 38); central.writeUInt32LE(offset, 42);
    centrals.push(central, nameBuf);
    offset += 30 + nameBuf.length + comp.length;
  }
  const cd = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(0, 4); end.writeUInt16LE(0, 6); end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10); end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16); end.writeUInt16LE(0, 20);
  return Buffer.concat([...locals, cd, end]);
}

// ── XLSX ──────────────────────────────────────────────────────────────────
const xml = (s) => String(s ?? '').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const colName = (i) => { let s = ''; i++; while (i > 0) { const m = (i - 1) % 26; s = String.fromCharCode(65 + m) + s; i = Math.floor((i - 1) / 26); } return s; };
function sheetXml({ columns, rows, widths }) {
  const out = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>',
    '<cols>', ...columns.map((_, i) => `<col min="${i + 1}" max="${i + 1}" width="${(widths && widths[i]) || 18}" customWidth="1"/>`), '</cols><sheetData>'];
  const cell = (v, r, c, style) => {
    const ref = `${colName(c)}${r}`;
    if (typeof v === 'number') return `<c r="${ref}" s="${style}"><v>${v}</v></c>`;
    return `<c r="${ref}" t="inlineStr" s="${style}"><is><t xml:space="preserve">${xml(v)}</t></is></c>`;
  };
  out.push(`<row r="1">${columns.map((h, c) => cell(h, 1, c, 1)).join('')}</row>`);
  rows.forEach((row, i) => out.push(`<row r="${i + 2}">${row.map((v, c) => cell(v, i + 2, c, 2)).join('')}</row>`));
  out.push('</sheetData>');
  if (rows.length) out.push(`<autoFilter ref="A1:${colName(columns.length - 1)}${rows.length + 1}"/>`);
  out.push('</worksheet>');
  return out.join('');
}
function workbook(sheets) {
  const files = [
    ['[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
      sheets.map((_, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('') + '</Types>'],
    ['_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'],
    ['xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
      sheets.map((s, i) => `<sheet name="${xml(s.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('') + '</sheets></workbook>'],
    ['xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
      sheets.map((_, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join('') +
      `<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`],
    ['xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="10"/><name val="Calibri"/></font><font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF7A5520"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="3"><xf/><xf fontId="1" fillId="2" applyFont="1" applyFill="1"><alignment vertical="top" wrapText="1"/></xf><xf applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs></styleSheet>'],
  ];
  sheets.forEach((s, i) => files.push([`xl/worksheets/sheet${i + 1}.xml`, sheetXml(s)]));
  return zip(files);
}

// ── CSV ───────────────────────────────────────────────────────────────────
const csvCell = (v) => { const s = String(v ?? ''); return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
const csv = (columns, rows) => '\ufeff' + [columns, ...rows].map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n';

// ── Data ──────────────────────────────────────────────────────────────────
const editions = records.editions;
const proposals = editions.flatMap((e) => e.proposals);
const reasonOf = (e, code) => e.reasons.find((r) => r.code === code);
const classLabel = (e, code) => e.classes.find((c) => c.code === code).label;
const STATUS_ORDER = ['proposed', 'automatedValidated', 'underReview', 'corrected', 'approved', 'rejected', 'retired'];

const PROPOSAL_COLUMNS = ['Proposal ID', 'Proposal version', 'Rule version', 'Edition', 'Translation', 'Book ID', 'Book', 'Chapter', 'Verse', 'Reference',
  'Original Scripture', 'Proposed personalised Scripture', 'Presentation mode', 'Proposed title', 'Title source', 'Transformation operations', 'Name placeholder',
  'Original author', 'Original speaker', 'Original audience', 'Context classification', 'Reason', 'Literary form', 'Context source', 'Eligibility rationale',
  'Grammar validation', 'Meaning preservation', 'Pronoun and person/number checks', 'Automated validation', 'Warnings', 'Risk', 'Confidence', 'Uncertainty',
  'Question for the reviewer', 'Source / provenance', 'Ruleset version', 'Status', 'Status label', 'Review history', 'Notes'];
const proposalRow = (p) => [p.id, p.proposalVersion, p.ruleVersion, p.edition, p.translation, p.bookId, p.book, p.chapter, p.verse, p.reference,
  p.original, p.proposed, p.modeLabel, p.title, p.titleSource, p.operations, p.placeholder, p.author, p.speaker, p.audience, p.classification, p.reason,
  p.literaryForm, p.contextSource, p.rationale, p.grammar, p.meaning, p.pronouns, p.automated, p.warnings, p.risk, p.confidence, p.uncertainty,
  p.reviewQuestion, p.provenance, p.ruleSetVersion, p.status, p.statusLabel, p.history, p.notes];

const verseRows = (filter) => editions.flatMap((e) => e.verses.filter(([, , , , cls]) => filter(cls)).map(([bookId, book, ch, v, cls, reason, text]) => {
  const r = reasonOf(e, reason);
  return [e.edition, e.translation, bookId, book, ch, v, `${book} ${ch}:${v}`, classLabel(e, cls), r.label, r.explanation, text];
}));
const VERSE_COLUMNS = ['Edition', 'Translation', 'Book ID', 'Book', 'Chapter', 'Verse', 'Reference', 'Classification', 'Reason', 'Explanation', 'Original Scripture'];

const flaggedProposals = proposals.filter((p) => p.automated === 'Failed' || p.risk === 'Critical' || p.reviewQuestion);
const FLAG_COLUMNS = ['Kind', 'Edition', 'Reference', 'Proposal ID', 'Classification / status', 'Why flagged', 'Original Scripture', 'Proposed'];
const flaggedRows = [
  ...flaggedProposals.map((p) => ['Proposal', p.edition, p.reference, p.id, p.statusLabel,
    [p.automated === 'Failed' ? `Automated validation failed: ${p.grammar}` : '', p.risk === 'Critical' ? 'Critical risk' : '', p.reviewQuestion].filter(Boolean).join(' | '),
    p.original, p.proposed]),
  ...verseRows((c) => c === 'contextualReview').map((r) => ['Verse', r[0], r[6], '', r[7], `${r[8]}: ${r[9]}`, r[10], '']),
];

const DECISION_COLUMNS = ['proposal_id', 'proposal_version', 'edition', 'reference', 'current_status', 'mode', 'original', 'proposed', 'proposed_title',
  'decision', 'corrected_text', 'corrected_title', 'reviewer', 'reviewer_role', 'decision_date', 'comments'];
const decisionRows = proposals.map((p) => [p.id, p.proposalVersion, p.edition, p.reference, p.status, p.mode, p.original, p.proposed, p.title,
  '', '', '', '', '', '', '']);

// Coverage
const coverageRows = [];
for (const e of editions) {
  const byClass = {};
  for (const v of e.verses) byClass[v[4]] = (byClass[v[4]] || 0) + 1;
  const ps = e.proposals;
  const count = (f) => ps.filter(f).length;
  const rows = [
    ['Total canonical verses processed', e.verses.length],
    ...e.classes.map((c) => [`Verses — ${c.label}`, byClass[c.code] || 0]),
    ['Proposed personalised renderings (all proposals)', ps.length],
    ['Name-in-text proposals (Mode A)', count((p) => p.mode === 'nameInText')],
    ['Name-in-title proposals (Mode B)', count((p) => p.mode === 'nameInTitle')],
    ['Name-in-title proposals still needing an editorial title', count((p) => p.mode === 'nameInTitle' && !p.title)],
    ['Original-only verses', byClass.originalOnly || 0],
    ['Excluded verses', byClass.excluded || 0],
    ['Flagged verses (requires contextual review)', byClass.contextualReview || 0],
    ['Flagged proposals (failed checks, critical risk or open question)', flaggedProposals.filter((p) => p.edition === e.edition).length],
    ['Proposals passing automated validation', count((p) => p.automated === 'Passed')],
    ['Proposals failing automated validation', count((p) => p.automated === 'Failed')],
    ...STATUS_ORDER.map((s) => [`Proposals with status ${s}`, count((p) => p.status === s)]),
    ['Pending proposals (awaiting a human decision)', count((p) => ['proposed', 'automatedValidated', 'underReview', 'corrected'].includes(p.status))],
    ['Approved proposals', count((p) => p.status === 'approved')],
    ['Rejected proposals', count((p) => p.status === 'rejected')],
    ['Corrected proposals', count((p) => p.status === 'corrected')],
  ];
  for (const [k, v] of rows) coverageRows.push([e.edition, e.translation, k, v]);
}

// ── Instructions ─────────────────────────────────────────────────────────
const INSTRUCTIONS = [
  ['Purpose', 'This workbook lists every proposed personalised rendering of Scripture in MY WORD BIBLE, and how every canonical verse of each translation was classified. Nothing in it is approved. A proposal is approved only when a named human reviewer records an approval for its current version.'],
  ['Translations covered', editions.map((e) => `${e.edition} (from the ${e.translation}, public domain), catalogue ${e.catalogueVersion}`).join('; ') + '. No other translation is covered: NKJV, NIV and NLT are not licensed for derivative works and are excluded from every count.'],
  ['Mode A — name in the Scripture', 'The reader’s name is inserted as a direct address set off by commas. No source word is removed, replaced or re-cased and no pronoun changes. [Name] shows where the name appears (full, first or preferred name, as the reader chooses).'],
  ['Mode B — name in the title', 'The Scripture is shown exactly as written. Only the editorial title carries the reader’s first (or preferred) name. Many Mode B proposals still need an editorial title; they cannot pass automated validation until one is supplied.'],
  ['Mode C — original', 'Every verse without an approved proposal is shown unchanged. The Daily Word then uses the title “Daily Word – MWB”.'],
  ['Automated validation', 'A technical check (anchors, exact recovery, punctuation, pronoun person/number, verb agreement, capitalisation, deleted words, gendered terms, vocabulary). Passing is NOT a theological approval.'],
  ['How to record a decision', 'Use the “Review decisions” sheet (or review_decisions_template.csv). Keep proposal_id and proposal_version exactly as given. In “decision” write one of: approve, reject, correct, comment, flag, reopen.'],
  ['approve', 'Requires reviewer name and date. Only possible for a proposal that passes automated validation at the given version.'],
  ['reject', 'Requires a reason in “comments”.'],
  ['correct', 'Requires reviewer name. Write the full corrected verse in corrected_text using {name} where the name goes (Mode A), and/or a corrected title in corrected_title (Mode B). A correction creates a new proposal version; it must then be approved separately.'],
  ['flag / comment', 'Flag an uncertain case (reason required) or leave a comment. Neither publishes anything.'],
  ['reopen', 'Reopens a decided proposal. Requires reviewer name and a reason.'],
  ['Returning decisions', 'Return the sheet or CSV. It is imported with tool/import_review_decisions.js, which matches each row to its exact proposal ID and version and never touches unrelated proposals. Rows for an out-of-date version are refused and reported.'],
  ['Sheets', '1 Review instructions · 2 Proposal catalogue · 3 Original vs personalised · 4 Excluded passages · 5 Flagged passages · 6 Review decisions · 7 Coverage statistics · 8 All verses (classification of every canonical verse).'],
];

// ── Write ────────────────────────────────────────────────────────────────
fs.mkdirSync(path.join(outDir, 'csv'), { recursive: true });
fs.mkdirSync(path.join(outDir, 'printable'), { recursive: true });

const sortP = [...proposals].sort((a, b) => a.edition.localeCompare(b.edition) || 0);
const sheets = [
  { name: 'Review instructions', columns: ['Topic', 'Guidance'], rows: INSTRUCTIONS, widths: [26, 140] },
  { name: 'Proposal catalogue', columns: PROPOSAL_COLUMNS, rows: sortP.map(proposalRow), widths: [30, 9, 9, 10, 8, 7, 14, 7, 6, 16, 60, 60, 22, 30, 24, 40, 24, 24, 24, 30, 24, 24, 18, 24, 50, 50, 30, 30, 10, 40, 9, 30, 30, 50, 40, 8, 16, 22, 30, 30] },
  { name: 'Original vs personalised', columns: ['Proposal ID', 'Version', 'Edition', 'Reference', 'Mode', 'Original Scripture', 'Proposed personalised Scripture', 'Proposed title', 'Status'],
    rows: sortP.map((p) => [p.id, p.proposalVersion, p.edition, p.reference, p.modeLabel, p.original, p.proposed, p.title, p.statusLabel]), widths: [30, 8, 10, 16, 22, 70, 70, 30, 18] },
  { name: 'Excluded passages', columns: VERSE_COLUMNS, rows: verseRows((c) => c === 'excluded'), widths: [10, 8, 7, 14, 7, 6, 16, 24, 28, 60, 70] },
  { name: 'Flagged passages', columns: FLAG_COLUMNS, rows: flaggedRows, widths: [9, 10, 16, 30, 24, 70, 70, 70] },
  { name: 'Review decisions', columns: DECISION_COLUMNS, rows: decisionRows, widths: [30, 9, 10, 16, 16, 12, 60, 60, 30, 12, 50, 30, 20, 20, 14, 40] },
  { name: 'Coverage statistics', columns: ['Edition', 'Translation', 'Measure', 'Count'], rows: coverageRows, widths: [12, 10, 60, 10] },
  { name: 'All verses', columns: VERSE_COLUMNS, rows: verseRows(() => true), widths: [10, 8, 7, 14, 7, 6, 16, 24, 28, 60, 70] },
];
const xlsxPath = path.join(outDir, 'MWB_Personalisation_Review_Catalogue.xlsx');
fs.writeFileSync(xlsxPath, workbook(sheets));

const csvs = {
  'proposals.csv': [PROPOSAL_COLUMNS, sortP.map(proposalRow)],
  'original_vs_personalised.csv': [sheets[2].columns, sheets[2].rows],
  'excluded_passages.csv': [VERSE_COLUMNS, sheets[3].rows],
  'flagged_passages.csv': [FLAG_COLUMNS, flaggedRows],
  'coverage_statistics.csv': [sheets[6].columns, coverageRows],
};
for (const e of editions) csvs[`all_verses_${e.translation.toLowerCase()}.csv`] = [VERSE_COLUMNS, verseRows(() => true).filter((r) => r[0] === e.edition)];
for (const [name, [cols, rows]] of Object.entries(csvs)) fs.writeFileSync(path.join(outDir, 'csv', name), csv(cols, rows));
fs.writeFileSync(path.join(outDir, 'review_decisions_template.csv'), csv(DECISION_COLUMNS, decisionRows));

// ── Printable document ───────────────────────────────────────────────────
const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const mark = (s) => esc(s).replace(/\[Name\]/g, '<b class="name">[Name]</b>');
for (const e of editions) {
  const ps = e.proposals;
  const books = [...new Set(e.verses.map((v) => v[0]))];
  const cov = coverageRows.filter((r) => r[0] === e.edition);
  const parts = [`<!doctype html><html><head><meta charset="utf-8"><title>${e.edition} personalisation review catalogue</title><style>
  @page { size: A4; margin: 16mm 14mm; }
  body { font: 10pt/1.45 Georgia, 'Times New Roman', serif; color: #2b1d12; }
  h1 { font-size: 22pt; margin: 0 0 4pt; } h2 { font-size: 15pt; border-bottom: 1.5pt solid #b88a35; padding-bottom: 3pt; margin-top: 18pt; break-after: avoid; }
  h3 { font-size: 12pt; color: #7a5520; margin: 12pt 0 4pt; break-after: avoid; }
  .meta, td, th, .small { font-family: Arial, Helvetica, sans-serif; font-size: 8.5pt; }
  table { border-collapse: collapse; width: 100%; } th, td { border: 0.5pt solid #d9cbb3; padding: 3pt 5pt; vertical-align: top; text-align: left; }
  th { background: #f4ead8; }
  .card { border: 0.75pt solid #d9cbb3; border-radius: 4pt; padding: 7pt 9pt; margin: 6pt 0; break-inside: avoid; }
  .cols { display: grid; grid-template-columns: 1fr 1fr; gap: 8pt; } .label { font: 600 7.5pt Arial; letter-spacing: .6pt; text-transform: uppercase; color: #7a5520; }
  .fail { color: #9b2c22; } .pass { color: #3d6b3a; } .name { color: #9a6a12; }
  .decide { border-top: 0.5pt dashed #b9a98d; margin-top: 6pt; padding-top: 4pt; font: 8.5pt Arial; color: #6c5a44; }
  .box { display: inline-block; width: 9pt; height: 9pt; border: 0.75pt solid #6c5a44; margin: 0 3pt -1pt 8pt; }
  .cover { break-after: page; }
</style></head><body>`];
  parts.push(`<section class="cover"><h1>${esc(e.edition)} — Personalised Scripture Review Catalogue</h1>
  <p class="meta">Source translation: ${esc(e.translation)} (public domain). Catalogue ${esc(e.catalogueVersion)}, generator rule v${e.generatorRuleVersion}. Generated from exports/personalisation-review/review_records.json.</p>
  <p><b>Nothing in this document is approved.</b> “Automated checks passed” is a technical result, not a theological approval. Approval is recorded only with the reviewer’s name and date, for the exact proposal version.</p>
  <h2>How to review</h2><table>${INSTRUCTIONS.map(([k, v]) => `<tr><th style="width:24%">${esc(k)}</th><td>${esc(v)}</td></tr>`).join('')}</table>
  <h2>Coverage</h2><table>${cov.map((r) => `<tr><td>${esc(r[2])}</td><td style="width:16%;text-align:right">${r[3]}</td></tr>`).join('')}</table></section>`);
  parts.push('<h2>Proposals by book, chapter and verse</h2>');
  for (const b of books) {
    const bp = ps.filter((p) => p.bookId === b).sort((x, y) => x.chapter - y.chapter || x.verse - y.verse || x.id.localeCompare(y.id));
    if (!bp.length) continue;
    parts.push(`<h3>${esc(bp[0].book)} — ${bp.length} proposal${bp.length === 1 ? '' : 's'}</h3>`);
    for (const p of bp) {
      parts.push(`<div class="card"><div class="meta"><b>${esc(p.reference)}</b> · ${esc(p.modeLabel)} · <code>${esc(p.id)}</code> v${p.proposalVersion} · ${esc(p.statusLabel)} · Risk ${esc(p.risk)}</div>
      <div class="cols"><div><div class="label">Original ${esc(p.translation)}</div>${esc(p.original)}</div><div><div class="label">Proposed</div>${p.title ? `<i>Title: ${mark(p.title)}</i><br>` : (p.mode === 'nameInTitle' ? '<i class="fail">Title: still needed</i><br>' : '')}${mark(p.proposed)}</div></div>
      <div class="small"><b>Author</b> ${esc(p.author)} · <b>Speaker</b> ${esc(p.speaker)} · <b>Audience</b> ${esc(p.audience)}<br>
      <b>Classification</b> ${esc(p.classification)} — ${esc(p.reason)}. ${esc(p.rationale)}<br>
      <b>Operations</b> ${esc(p.operations || 'none (Scripture unchanged)')}<br>
      <b>Automated</b> <span class="${p.automated === 'Passed' ? 'pass' : 'fail'}">${esc(p.automated)}</span> · <b>Meaning</b> ${esc(p.meaning)} · <b>Pronouns</b> ${esc(p.pronouns)}${p.warnings ? `<br><b>Warnings</b> ${esc(p.warnings)}` : ''}
      ${p.reviewQuestion ? `<br><b>Question</b> ${esc(p.reviewQuestion)}` : ''}${p.uncertainty ? `<br><b>Uncertainty</b> ${esc(p.uncertainty)}` : ''}<br><b>Provenance</b> ${esc(p.provenance)}</div>
      <div class="decide">Decision:<span class="box"></span>approve<span class="box"></span>reject<span class="box"></span>correct<span class="box"></span>flag &nbsp; Reviewer ____________ Date ________ Comments ______________________</div></div>`);
    }
  }
  parts.push('<h2>Excluded and flagged verses (summary by book)</h2><table><tr><th>Book</th><th>Excluded</th><th>Requires contextual review</th><th>Original only</th><th>Main reasons</th></tr>');
  for (const b of books) {
    const vs = e.verses.filter((v) => v[0] === b);
    const n = (c) => vs.filter((v) => v[4] === c).length;
    const reasons = {};
    for (const v of vs.filter((x) => x[4] === 'excluded' || x[4] === 'contextualReview')) reasons[v[5]] = (reasons[v[5]] || 0) + 1;
    const top = Object.entries(reasons).sort((a, b2) => b2[1] - a[1]).slice(0, 3).map(([k, c]) => `${reasonOf(e, k).label} (${c})`).join('; ');
    parts.push(`<tr><td>${esc(vs[0][1])}</td><td>${n('excluded')}</td><td>${n('contextualReview')}</td><td>${n('originalOnly')}</td><td>${esc(top)}</td></tr>`);
  }
  parts.push('</table><p class="small">Every excluded and flagged verse is listed individually, with its reason and the original text, in the workbook (sheets 4, 5 and 8) and in csv/excluded_passages.csv and csv/flagged_passages.csv.</p></body></html>');
  const htmlPath = path.join(outDir, 'printable', `${e.edition.toLowerCase()}-review-catalogue.html`);
  fs.writeFileSync(htmlPath, parts.join('\n'));
  if (!noPdf) {
    const edge = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe'].find((p) => fs.existsSync(p));
    if (edge) {
      const pdf = htmlPath.replace(/\.html$/, '.pdf');
      try {
        execFileSync(edge, ['--headless=new', '--disable-gpu', '--no-pdf-header-footer', `--print-to-pdf=${pdf}`, 'file:///' + htmlPath.replace(/\\/g, '/')], { stdio: 'ignore', timeout: 300000 });
      } catch (err) {
        console.warn(`PDF not produced for ${e.edition}: ${err.message}`);
      }
    } else {
      console.warn('Microsoft Edge not found; printable HTML written without PDF.');
    }
  }
}

for (const r of coverageRows) console.log(r.join(' | '));
for (const f of fs.readdirSync(outDir, { recursive: true })) {
  const p = path.join(outDir, f);
  if (fs.statSync(p).isFile()) console.log(`${(fs.statSync(p).size / 1024).toFixed(0).padStart(8)} KB  ${f}`);
}
