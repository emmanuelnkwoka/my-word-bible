// Imports reviewer decisions returned in the review_decisions_template.csv
// format (or the "Review decisions" sheet saved as CSV).
//
//   node tool/import_review_decisions.js <decisions.csv> [--dry-run]
//
// Each row is matched to its EXACT proposal id and proposal version in
// exports/personalisation-review/review_records.json (regenerate that file
// first so versions are current). Rows are refused, and reported, when:
//   - the proposal id does not exist,
//   - the version is not the proposal's current version,
//   - the decision is unknown,
//   - approve / correct / reopen has no reviewer name, or no date,
//   - reject / flag / reopen has no reason in comments,
//   - correct has neither corrected_text nor corrected_title,
//   - correct (Mode A) does not contain {name}.
// Accepted rows are appended to assets/mwb/reviews/<edition>.decisions.json.
// Nothing else is touched: no other proposal, no canonical text, no ruleset.
// An approval imported here still renders only if the proposal passes the
// app's automated validation at that version.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const file = process.argv[2];
const dryRun = process.argv.includes('--dry-run');
if (!file) {
  console.error('Usage: node tool/import_review_decisions.js <decisions.csv> [--dry-run]');
  process.exit(2);
}

function parseCsv(text) {
  const rows = [];
  let row = [], cell = '', q = false;
  text = text.replace(/^﻿/, '');
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; } else if (ch === '"') q = false; else cell += ch;
    } else if (ch === '"') q = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(cell); rows.push(row); row = []; cell = '';
    } else cell += ch;
  }
  if (cell.length || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

const records = JSON.parse(fs.readFileSync(path.join(root, 'exports/personalisation-review/review_records.json'), 'utf8'));
const current = new Map();
for (const e of records.editions) for (const p of e.proposals) current.set(p.id, p);

const [header, ...rows] = parseCsv(fs.readFileSync(file, 'utf8'));
const col = (name) => header.indexOf(name);
for (const need of ['proposal_id', 'proposal_version', 'decision', 'reviewer', 'decision_date']) {
  if (col(need) < 0) { console.error(`Missing column: ${need}`); process.exit(2); }
}
const ACTIONS = { approve: 'approved', reject: 'rejected', correct: 'corrected', comment: 'comment', flag: 'flagged', reopen: 'reopened' };

const accepted = {}; const refused = [];
rows.forEach((r, i) => {
  const get = (k) => (col(k) >= 0 ? (r[col(k)] || '').trim() : '');
  const decision = get('decision').toLowerCase();
  if (!decision) return; // untouched row
  const id = get('proposal_id');
  const line = i + 2;
  const p = current.get(id);
  const refuse = (why) => refused.push(`row ${line} (${id || 'no id'}): ${why}`);
  if (!p) return refuse('unknown proposal id');
  const version = Number(get('proposal_version'));
  if (version !== p.proposalVersion) return refuse(`version ${version} is not the current version ${p.proposalVersion}`);
  const action = ACTIONS[decision];
  if (!action) return refuse(`unknown decision "${decision}"`);
  const reviewer = get('reviewer');
  const date = get('decision_date');
  const comments = get('comments');
  if (['approved', 'corrected', 'reopened'].includes(action) && !reviewer) return refuse('a reviewer name is required');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return refuse('decision_date must be YYYY-MM-DD');
  if (['rejected', 'flagged', 'reopened'].includes(action) && !comments) return refuse('a reason is required in comments');
  const correctedText = get('corrected_text');
  const correctedTitle = get('corrected_title');
  if (action === 'corrected') {
    if (!correctedText && !correctedTitle) return refuse('corrected_text or corrected_title is required');
    if (correctedText && p.mode === 'nameInText' && !correctedText.includes('{name}')) return refuse('corrected_text must contain {name}');
  }
  if (action === 'approved' && p.automated !== 'Passed') return refuse('this version fails automated validation and cannot be approved');
  const rec = {
    action,
    at: `${date}T00:00:00.000`,
    ruleVersion: action === 'corrected' ? version + 1 : version,
    ...(reviewer ? { reviewer } : {}),
    ...(get('reviewer_role') ? { reviewerRole: get('reviewer_role') } : {}),
    ...(comments ? { comments } : {}),
    ...(action === 'rejected' ? { rejectionReason: comments } : {}),
    ...(action === 'corrected' && correctedText ? { correctedText } : {}),
    ...(action === 'corrected' && correctedTitle ? { correctedTitle } : {}),
  };
  ((accepted[p.edition] ??= {})[id] ??= []).push(rec);
});

for (const [edition, byId] of Object.entries(accepted)) {
  const target = path.join(root, `assets/mwb/reviews/${edition.toLowerCase()}.decisions.json`);
  const doc = JSON.parse(fs.readFileSync(target, 'utf8'));
  let added = 0;
  for (const [id, recs] of Object.entries(byId)) {
    const list = (doc.decisions[id] ??= []);
    for (const rec of recs) {
      if (list.some((x) => JSON.stringify(x) === JSON.stringify(rec))) continue; // idempotent
      list.push(rec);
      added++;
    }
  }
  console.log(`${edition}: ${added} decision(s) ${dryRun ? 'would be' : ''} added`);
  if (!dryRun) fs.writeFileSync(target, JSON.stringify(doc, null, 2) + '\n');
}
if (refused.length) {
  console.log(`Refused ${refused.length} row(s):`);
  for (const r of refused) console.log('  ' + r);
}
