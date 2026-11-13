// Converts the public-domain World English Bible (eBible.org "engwebp" verse-per-line edition,
// https://ebible.org/Scriptures/engwebp_vpl.zip) into MWB's compact asset format.
// The verse text is copied exactly; nothing is reworded.
//
// Usage: node tool/build_web_asset.js <engwebp_vpl.txt> assets/bible/web.json
const fs = require('fs');

// eBible VPL (BibleWorks) abbreviations, in canonical order, mapped to MWB's USFM ids.
const order = [
  ['GEN', 'GEN', 'Genesis'], ['EXO', 'EXO', 'Exodus'], ['LEV', 'LEV', 'Leviticus'], ['NUM', 'NUM', 'Numbers'],
  ['DEU', 'DEU', 'Deuteronomy'], ['JOS', 'JOS', 'Joshua'], ['JDG', 'JDG', 'Judges'], ['RUT', 'RUT', 'Ruth'],
  ['1SA', '1SA', '1 Samuel'], ['2SA', '2SA', '2 Samuel'], ['1KI', '1KI', '1 Kings'], ['2KI', '2KI', '2 Kings'],
  ['1CH', '1CH', '1 Chronicles'], ['2CH', '2CH', '2 Chronicles'], ['EZR', 'EZR', 'Ezra'], ['NEH', 'NEH', 'Nehemiah'],
  ['EST', 'EST', 'Esther'], ['JOB', 'JOB', 'Job'], ['PSA', 'PSA', 'Psalms'], ['PRO', 'PRO', 'Proverbs'],
  ['ECC', 'ECC', 'Ecclesiastes'], ['SOL', 'SNG', 'Song of Solomon'], ['ISA', 'ISA', 'Isaiah'], ['JER', 'JER', 'Jeremiah'],
  ['LAM', 'LAM', 'Lamentations'], ['EZE', 'EZK', 'Ezekiel'], ['DAN', 'DAN', 'Daniel'], ['HOS', 'HOS', 'Hosea'],
  ['JOE', 'JOL', 'Joel'], ['AMO', 'AMO', 'Amos'], ['OBA', 'OBA', 'Obadiah'], ['JON', 'JON', 'Jonah'],
  ['MIC', 'MIC', 'Micah'], ['NAH', 'NAM', 'Nahum'], ['HAB', 'HAB', 'Habakkuk'], ['ZEP', 'ZEP', 'Zephaniah'],
  ['HAG', 'HAG', 'Haggai'], ['ZEC', 'ZEC', 'Zechariah'], ['MAL', 'MAL', 'Malachi'],
  ['MAT', 'MAT', 'Matthew'], ['MAR', 'MRK', 'Mark'], ['LUK', 'LUK', 'Luke'], ['JOH', 'JHN', 'John'],
  ['ACT', 'ACT', 'Acts'], ['ROM', 'ROM', 'Romans'], ['1CO', '1CO', '1 Corinthians'], ['2CO', '2CO', '2 Corinthians'],
  ['GAL', 'GAL', 'Galatians'], ['EPH', 'EPH', 'Ephesians'], ['PHI', 'PHP', 'Philippians'], ['COL', 'COL', 'Colossians'],
  ['1TH', '1TH', '1 Thessalonians'], ['2TH', '2TH', '2 Thessalonians'], ['1TI', '1TI', '1 Timothy'],
  ['2TI', '2TI', '2 Timothy'], ['TIT', 'TIT', 'Titus'], ['PHM', 'PHM', 'Philemon'], ['HEB', 'HEB', 'Hebrews'],
  ['JAM', 'JAS', 'James'], ['1PE', '1PE', '1 Peter'], ['2PE', '2PE', '2 Peter'], ['1JO', '1JN', '1 John'],
  ['2JO', '2JN', '2 John'], ['3JO', '3JN', '3 John'], ['JUD', 'JUD', 'Jude'], ['REV', 'REV', 'Revelation'],
];
const byAbbr = new Map(order.map(([abbr, id, name], i) => [abbr, { id, name, index: i }]));

const lines = fs.readFileSync(process.argv[2], 'utf8').replace(/^﻿/, '').split(/\r?\n/).filter((l) => l.trim());
const books = order.map(([, id, name], i) => ({ id, name, testament: i < 39 ? 'OT' : 'NT', chapters: [] }));
const problems = [];
// Verses the WEB does not include (it footnotes them). Kept as empty strings so verse numbers stay aligned.
const omitted = [];

for (const line of lines) {
  const m = /^(\S+) (\d+):(\d+) (.*)$/.exec(line);
  if (!m) { problems.push(`unparsed line: ${line.slice(0, 60)}`); continue; }
  const book = byAbbr.get(m[1]);
  if (!book) { problems.push(`unknown book ${m[1]}`); continue; }
  const c = Number(m[2]);
  const v = Number(m[3]);
  const chapters = books[book.index].chapters;
  while (chapters.length < c) chapters.push([]);
  const verses = chapters[c - 1];
  if (v <= verses.length) problems.push(`${book.id} ${c}:${v} duplicated or out of order`);
  while (verses.length < v - 1) {
    omitted.push(`${book.id} ${c}:${verses.length + 1}`);
    verses.push('');
  }
  // The source lists verses the WEB omits with empty text (e.g. LUK 17:36).
  if (m[4].trim() === '') omitted.push(`${book.id} ${c}:${v}`);
  verses[v - 1] = m[4].trim() === '' ? '' : m[4];
}

books.forEach((b) => b.chapters.forEach((ch, ci) => {
  if (ch.length === 0) problems.push(`${b.id} ${ci + 1} has no verses`);
  ch.forEach((t, vi) => {
    if (!t && !omitted.includes(`${b.id} ${ci + 1}:${vi + 1}`)) problems.push(`${b.id} ${ci + 1}:${vi + 1} is empty`);
  });
}));
if (books.some((b) => b.chapters.length === 0)) problems.push('a book has no chapters');
if (problems.length) {
  console.error(problems.join('\n'));
  process.exit(1);
}

const out = { id: 'WEB', name: 'World English Bible', license: 'Public domain', source: 'eBible.org engwebp', omittedVerses: omitted, books };
fs.writeFileSync(process.argv[3], JSON.stringify(out));
const total = books.reduce((n, b) => n + b.chapters.reduce((m, ch) => m + ch.length, 0), 0);
console.log(`wrote ${process.argv[3]}: ${books.length} books, ${books.reduce((n, b) => n + b.chapters.length, 0)} chapters, ${total} verse slots, omitted: ${omitted.join(', ') || 'none'}`);
