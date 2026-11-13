// Builds assets/daily/candidates.json and assets/daily/schedule.json from the
// Stage C intelligence corpus (assets/intel). Deterministic: the same corpus
// always produces the same schedule.
//
//   node tool/build_daily_schedule.js [--force]
//
// Candidates are Scripture passages that already have a curated context in
// the corpus. No passage is invented. With fewer than 365 suitable passages,
// passages recur on a fixed cycle; every recurrence is recorded.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const out = path.join(root, 'assets/daily');
const force = process.argv.includes('--force');
if (fs.existsSync(path.join(out, 'schedule.json')) && !force) throw new Error('assets/daily exists; pass --force to rebuild');
fs.mkdirSync(out, { recursive: true });

const read = (f) => JSON.parse(fs.readFileSync(path.join(root, 'assets/intel', f), 'utf8'));
const contexts = read('contexts.json').contexts;
const promises = read('promises.json').promises;
const identity = read('identity_themes.json').identityThemes;
const worship = read('worship_themes.json').worshipThemes;
const commands = read('commands.json').commands;
const situations = read('situations.json').situations;
const corpusVersion = read('manifest.json').corpusVersion;

const SCHEMA = 1;
const SCHEDULE_VERSION = '2026.1';
const CATEGORIES = ['Hope', 'Peace', 'Strength', 'Courage', 'Provision', 'Comfort', 'Wisdom', 'Healing', 'Rest', 'Gratitude',
  'Identity', 'Protection', 'Guidance', 'Purpose', 'Faith', 'Family'];
const LEAP_REFERENCE = 'REV 21:5';

// Daily Word entries from the MWB HTML demonstration (lines 1487-1542):
// [demo id, reference, category, theme, title, demo line].
const DEMO = [
  ['dw01', 'LAM 3:22-23', 'Hope', 'New mercies', 'New every morning', 1488], ['dw02', 'ISA 26:3', 'Peace', 'Perfect peace', 'A stayed mind', 1489],
  ['dw03', 'EXO 14:14', 'Strength', 'He fights', 'Hold your peace', 1490], ['dw04', 'DEU 31:6', 'Courage', 'Go with courage', 'He goes with you', 1491],
  ['dw05', 'PHP 4:19', 'Provision', 'Every need', 'Need, supplied', 1492], ['dw06', 'PSA 34:18', 'Comfort', 'Near to the broken', 'Nigh to the brokenhearted', 1493],
  ['dw07', 'JAS 1:5', 'Wisdom', 'Ask for wisdom', 'Ask liberally', 1494], ['dw08', 'EXO 15:26', 'Healing', 'The healer', 'The LORD thy healer', 1495],
  ['dw09', 'MAT 11:28', 'Rest', 'Come and rest', 'Come unto Me', 1496], ['dw10', 'JAS 1:17', 'Gratitude', 'Every good gift', 'From above', 1497],
  ['dw11', 'PSA 139:14', 'Identity', 'Made wonderful', 'Fearfully made', 1498], ['dw12', 'PSA 91:11', 'Protection', 'Angels watch', 'Charge over thee', 1499],
  ['dw13', 'PSA 32:8', 'Guidance', 'Taught of God', 'I will instruct thee', 1500], ['dw14', 'PHP 1:6', 'Purpose', 'He finishes', 'What He began', 1501],
  ['dw15', 'HEB 11:1', 'Faith', 'Defined', 'What faith is', 1502], ['dw16', 'ISA 54:13', 'Family', 'Taught children', 'Children taught of the LORD', 1503],
  ['dw17', 'ROM 15:13', 'Hope', 'The God of hope', 'Abound in hope', 1504], ['dw18', 'JHN 14:27', 'Peace', 'His own peace', 'My peace I give', 1505],
  ['dw19', '2CO 12:9', 'Strength', 'Grace enough', 'Sufficient for thee', 1506], ['dw20', 'JOS 1:9', 'Courage', 'Commanded courage', 'Be strong', 1507],
  ['dw21', 'MAT 6:33', 'Provision', 'First the kingdom', 'Seek first', 1508], ['dw22', 'PSA 147:3', 'Comfort', 'He binds', 'He healeth the broken', 1509],
  ['dw23', 'PRO 3:5-6', 'Wisdom', 'Trust over sight', 'Directed paths', 1510], ['dw24', 'JER 30:17', 'Healing', 'Restored health', 'I will heal thee', 1511],
  ['dw25', 'MAT 6:34', 'Rest', 'Today only', 'Grace for today', 1512], ['dw26', '1CO 15:57', 'Gratitude', 'Victory', 'Thanks be to God', 1513],
  ['dw27', 'EPH 2:10', 'Identity', 'His workmanship', 'Crafted, not accidental', 1514], ['dw28', 'ISA 54:17', 'Protection', 'No weapon', 'Formed but failing', 1515],
  ['dw29', 'ISA 30:21', 'Guidance', 'This is the way', 'A word behind thee', 1516], ['dw30', 'GAL 6:9', 'Purpose', 'Due season', 'Reap in time', 1517],
  ['dw31', 'MRK 9:23', 'Faith', 'Possible to belief', 'If thou canst believe', 1518], ['dw32', 'JOS 24:15', 'Family', 'Household choice', 'Me and my house', 1519],
  ['dw33', 'PRO 23:18', 'Hope', 'Expectation holds', 'Not cut off', 1520], ['dw34', 'PSA 46:10', 'Peace', 'Be still', 'Know that I am God', 1521],
  ['dw35', 'ISA 41:13', 'Strength', 'Held', 'Thy right hand held', 1522], ['dw36', '2TI 1:7', 'Courage', 'No fear-spirit', 'Power, love, sound mind', 1523],
  ['dw37', '2CO 9:8', 'Provision', 'All sufficiency', 'Grace abounds', 1524], ['dw38', 'JHN 6:37', 'Comfort', 'Not cast out', 'In no wise cast out', 1525],
  ['dw39', 'PSA 119:105', 'Wisdom', 'Lamp and light', 'Thy word lights the path', 1526], ['dw40', 'PSA 103:3', 'Healing', 'Who healeth', 'He healeth diseases', 1527],
  ['dw41', 'EXO 33:14', 'Rest', 'Presence and rest', 'My presence shall go', 1528], ['dw42', 'PSA 16:11', 'Gratitude', 'Fullness of joy', 'Joy in His presence', 1529],
  ['dw43', 'ISA 43:1', 'Identity', 'Called by name', 'Thou art mine', 1530], ['dw44', 'PSA 46:1', 'Protection', 'Refuge', 'A very present help', 1531],
  ['dw45', 'PRO 16:3', 'Guidance', 'Commit the works', 'Established', 1532], ['dw46', 'ROM 8:28', 'Purpose', 'Working together', 'For good', 1533],
  ['dw47', 'MAT 19:26', 'Faith', 'All things possible', 'With God', 1534], ['dw48', 'ACT 16:31', 'Family', 'Believe, and thy house', 'Thy house', 1535],
  ['dwa1', 'PHP 4:7', 'Peace', 'Guarded', 'Peace that keeps', 1537], ['dwa2', 'PSA 56:3', 'Courage', 'Afraid', 'What time I am afraid', 1538],
  ['dwa3', 'PSA 42:11', 'Comfort', 'Downcast', 'Hope thou in God', 1539], ['dwa4', 'JHN 16:33', 'Courage', 'Good cheer', 'I have overcome', 1540],
  ['dwa5', 'ROM 8:1', 'Purpose', 'No condemnation', 'Now, no condemnation', 1541], ['dwa6', 'JER 29:11', 'Hope', 'Character of God', 'Thoughts of peace', 1542],
];
const demoByRef = Object.fromEntries(DEMO.map((d) => [d[1], d]));
const demoTitleChanges = { 'ISA 54:13': 'Demo title "Peace for your children" changed: Isaiah 54:13 was spoken to Zion, not to an individual parent.' };

// Passages kept out of the daily pool, with the reason.
const EXCLUDED = {
  'MAL 3:10': 'Covenant charge to post-exilic Judah; often misapplied as a prosperity transaction (demo note).',
  'DEU 8:18': 'Covenant context for Israel; flagged in Stage C as liable to be read as a promise of wealth.',
  'PRO 10:22': 'Liable to be read as a promise of riches without its wisdom context; held back pending editorial review.',
  [LEAP_REFERENCE]: 'Reserved for February 29 (historical design decision).',
};

// Categories for passages not in the demo Daily Word list, by curated
// association (situations that cite them, or their wording).
const SITUATION_CATEGORY = {
  'sit-fear': 'Courage', 'sit-anxiety': 'Peace', 'sit-loneliness': 'Comfort', 'sit-rejection': 'Identity', 'sit-grief': 'Comfort',
  'sit-marriage': 'Family', 'sit-parenting': 'Family', 'sit-children': 'Family', 'sit-family': 'Family', 'sit-friendship': 'Family',
  'sit-career': 'Purpose', 'sit-business': 'Purpose', 'sit-financial-pressure': 'Provision', 'sit-failure': 'Hope', 'sit-success': 'Purpose',
  'sit-waiting': 'Strength', 'sit-decisions': 'Guidance', 'sit-confusion': 'Guidance', 'sit-purpose': 'Purpose', 'sit-identity': 'Identity',
  'sit-temptation': 'Strength', 'sit-sin': 'Faith', 'sit-forgiveness': 'Peace', 'sit-healing': 'Healing', 'sit-rest': 'Rest', 'sit-sleep': 'Rest',
  'sit-protection': 'Protection', 'sit-travel': 'Protection', 'sit-exams': 'Wisdom', 'sit-leadership': 'Courage', 'sit-ministry': 'Purpose',
  'sit-evangelism': 'Purpose', 'sit-hope-future': 'Hope', 'sit-gratitude': 'Gratitude', 'sit-worship': 'Gratitude',
};
const PROMISE_CATEGORY = { Future: 'Hope', Restoration: 'Healing', "God's presence": 'Comfort', Salvation: 'Faith' };
const OVERRIDE = {
  'GEN 1:3': ['Purpose', 'God speaks light into darkness at creation.'],
  'GEN 1:27': ['Identity', 'Humanity made in the image of God.'],
  'GEN 28:15': ['Protection', "God's word to Jacob at Bethel: \"I am with thee\"."],
  'EXO 3:14': ['Faith', 'God reveals His name to Moses.'],
  'EXO 20:3': ['Faith', 'The first commandment given at Sinai.'],
  'NUM 6:25': ['Peace', 'Part of the priestly blessing given through Aaron.'],
  'PSA 23:6': ['Hope', 'Goodness and mercy for all the days of life.'],
  'PSA 37:4': ['Gratitude', 'Delight in the LORD.'],
  'PSA 55:22': ['Peace', 'Casting a burden on the LORD.'],
  'PSA 91:1': ['Protection', 'Dwelling in the secret place of the Most High.'],
  'PRO 18:10': ['Protection', 'The name of the LORD as a strong tower.'],
  'ISA 43:2': ['Comfort', 'God with His people through waters and fire.'],
  'ISA 53:5': ['Healing', 'The suffering Servant wounded for transgressions.'],
  'EZK 36:26': ['Hope', 'The promise of a new heart to Israel.'],
  'MAT 3:17': ['Faith', "The Father's word at Jesus' baptism."],
  'MAT 7:7': ['Faith', 'Ask, seek, knock.'],
  'MRK 16:15': ['Purpose', 'The commission to preach the gospel.'],
  'LUK 6:38': ['Gratitude', 'Jesus on giving.'],
  'JHN 3:16': ['Faith', "God's love in giving His Son."],
  'JHN 8:12': ['Guidance', 'Jesus, the light of the world.'],
  'JHN 10:10': ['Hope', 'Jesus came that they might have life.'],
  'JHN 10:28': ['Protection', "None shall pluck them out of Jesus' hand."],
  'JHN 11:25': ['Hope', 'Jesus, the resurrection and the life.'],
  'JHN 14:1': ['Peace', 'Let not your heart be troubled.'],
  'JHN 14:6': ['Faith', 'Jesus, the way, the truth and the life.'],
  'JHN 15:11': ['Gratitude', "Jesus' joy remaining in His disciples."],
  'ACT 1:8': ['Purpose', 'Power to be witnesses.'],
  'ROM 5:1': ['Peace', 'Peace with God through justification by faith.'],
  'ROM 6:23': ['Faith', 'The gift of God is eternal life.'],
  'ROM 8:31': ['Courage', 'If God be for us.'],
  'ROM 8:37': ['Strength', 'More than conquerors.'],
  'ROM 10:9': ['Faith', 'Confessing and believing unto salvation.'],
  'EPH 2:8': ['Faith', 'Saved by grace through faith.'],
  'EPH 3:20': ['Gratitude', 'Doxology to Him who is able.'],
  'COL 3:23': ['Purpose', 'Working heartily as to the Lord.'],
  '2TH 3:3': ['Protection', 'The Lord is faithful to stablish and keep.'],
  'HEB 4:16': ['Faith', 'Coming boldly to the throne of grace.'],
  'HEB 13:5': ['Comfort', '"I will never leave thee, nor forsake thee."'],
  '1PE 5:7': ['Peace', 'Casting all care upon Him.'],
  '1JN 1:9': ['Peace', 'Confession and cleansing.'],
  '1JN 4:18': ['Courage', 'Perfect love casteth out fear.'],
  'REV 21:4': ['Hope', 'No more death, sorrow or crying.'],
  'MAT 5:14': ['Identity', 'Ye are the light of the world.'],
  'MAT 28:20': ['Comfort', 'I am with you alway.'],
  'PSA 23:1': ['Provision', 'The LORD is my shepherd.'],
  'PSA 23:4': ['Comfort', 'Thou art with me.'],
  'PSA 30:5': ['Comfort', 'Joy cometh in the morning.'],
  'PSA 34:7': ['Protection', 'The angel of the LORD encampeth.'],
  'PSA 121:7': ['Protection', 'The LORD shall preserve thee.'],
  'PSA 121:8': ['Protection', 'Thy going out and coming in.'],
  'PSA 127:3': ['Family', 'Children, an heritage of the LORD.'],
  'PRO 22:6': ['Family', 'Train up a child.'],
  'NUM 6:24': ['Protection', 'The LORD bless thee, and keep thee.'],
  'NUM 6:26': ['Peace', 'The LORD give thee peace.'],
  'ISA 40:31': ['Strength', 'They that wait upon the LORD.'],
  'ISA 41:10': ['Courage', 'Fear thou not; for I am with thee.'],
  'PHP 4:6': ['Peace', 'In every thing by prayer.'],
  'PHP 4:13': ['Strength', 'I can do all things through Christ.'],
  '1CO 10:13': ['Strength', 'A way to escape.'],
  'JHN 6:37': ['Comfort', 'In no wise cast out.'],
  'JOS 24:15': ['Family', 'As for me and my house.'],
  'REV 21:5': ['Hope', 'I make all things new.'],
};

const titleFrom = {};
for (const p of promises) titleFrom[p.references[0]] ??= p.title;
for (const x of [...identity, ...worship, ...commands]) for (const r of x.references) titleFrom[r] ??= x.title;

const situationsCiting = (r) => situations.filter((s) => s.references.includes(r));
const promiseFor = (r) => promises.find((p) => p.references.includes(r));

const candidates = [];
const excluded = [];
for (const c of contexts) {
  const r = c.reference;
  if (EXCLUDED[r] && r !== LEAP_REFERENCE) { excluded.push({ reference: r, reason: EXCLUDED[r] }); continue; }
  const demo = demoByRef[r];
  const basis = [];
  let category, title, theme, origin;
  if (r === LEAP_REFERENCE) {
    category = 'Hope'; theme = 'All things new'; title = 'All things new';
    origin = { origin: 'demoSeed', seedId: 'dwleap', seedLine: 1544, changes: ['Demo category "Restoration" mapped to Hope (Restoration is not one of the 16 Daily Word categories).'] };
    basis.push('Reserved leap-day Daily Word in the GODSAID design (February 29).');
  } else if (demo) {
    [, , category, theme, title] = demo;
    origin = { origin: 'demoSeed', seedId: demo[0], seedLine: demo[5], changes: demoTitleChanges[r] ? [demoTitleChanges[r]] : [] };
    basis.push(`Listed in the GODSAID demo Daily Word corpus under ${category}.`);
  } else {
    const p = promiseFor(r);
    const o = OVERRIDE[r];
    if (o) { category = o[0]; theme = o[1]; basis.push(`Curated for ${category}: ${o[1]}`); }
    else if (p) { category = PROMISE_CATEGORY[p.category] || p.category; theme = p.title; basis.push(`Promise "${p.title}" (${p.category}).`); }
    else {
      const s = situationsCiting(r)[0];
      if (s) { category = SITUATION_CATEGORY[s.id]; theme = s.name; basis.push(`Cited by the life situation "${s.name}".`); }
    }
    title = titleFrom[r] || null;
    origin = { origin: 'newlyCurated', basis: `Stage D: passage with a curated Stage C context (${c.id}); category assigned by curation.`, changes: [] };
  }
  if (!CATEGORIES.includes(category)) throw new Error(`No valid category for ${r}: ${category}`);
  const sits = situationsCiting(r).map((s) => s.name);
  if (sits.length) basis.push(`Cited by life situation(s): ${sits.join(', ')}.`);
  candidates.push({
    id: 'dwc-' + r.replace(/[ :]/g, '-'), reference: r, contextId: c.id, category, theme: theme || category, title,
    rationale: basis.join(' '),
    leapReserved: r === LEAP_REFERENCE,
    provenance: origin,
    review: { status: 'pendingEditorialReview', flags: c.review.flags || [] },
  });
}
must(candidates.some((c) => c.leapReserved), 'leap candidate missing');
function must(c, m) { if (!c) throw new Error(m); }

// ── Annual sequence ─────────────────────────────────────────────────────
// Greedy interleave: always take from the category with the most remaining
// passages that is not the previous category. Ties follow CATEGORIES order;
// within a category, canonical corpus order.
const pool = candidates.filter((c) => !c.leapReserved);
const byCat = Object.fromEntries(CATEGORIES.map((k) => [k, pool.filter((c) => c.category === k)]));
const seq = [];
let prev = null;
while (seq.length < pool.length) {
  const options = CATEGORIES.filter((k) => byCat[k].length && k !== prev);
  must(options.length, 'interleave stalled');
  options.sort((a, b) => byCat[b].length - byCat[a].length || CATEGORIES.indexOf(a) - CATEGORIES.indexOf(b));
  const k = options[0];
  seq.push(byCat[k].shift());
  prev = k;
}
// The cycle wraps (day N+1 follows day N); keep its seam diverse too.
for (let i = 0; seq[seq.length - 1].category === seq[0].category && i < seq.length; i++) seq.push(seq.shift());

const MONTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
const days = [];
let day = 0;
const uses = {};
MONTHS.forEach((n, m) => {
  for (let d = 1; d <= n; d++) {
    const c = seq[day % seq.length];
    uses[c.id] = (uses[c.id] || 0) + 1;
    days.push({ day: day + 1, date: `${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`, candidateId: c.id, occurrence: uses[c.id] });
    day++;
  }
});
const leap = candidates.find((c) => c.leapReserved);
const schedule = {
  schemaVersion: SCHEMA, scheduleVersion: SCHEDULE_VERSION, corpusVersion,
  cycleLength: seq.length,
  note: `Passages recur every ${seq.length} days because the verified pool has ${seq.length} passages; "occurrence" records each recurrence within the year.`,
  days, leapDay: { date: '02-29', candidateId: leap.id },
};
for (let i = 1; i < days.length; i++) {
  const a = candidates.find((c) => c.id === days[i - 1].candidateId), b = candidates.find((c) => c.id === days[i].candidateId);
  must(a.category !== b.category, `consecutive category ${a.category} on ${days[i].date}`);
}
const cand = { schemaVersion: SCHEMA, scheduleVersion: SCHEDULE_VERSION, corpusVersion, categories: CATEGORIES, excluded, candidates };
fs.writeFileSync(path.join(out, 'candidates.json'), JSON.stringify(cand, null, 1) + '\n');
fs.writeFileSync(path.join(out, 'schedule.json'), JSON.stringify(schedule, null, 1) + '\n');
const counts = Object.fromEntries(CATEGORIES.map((k) => [k, pool.filter((c) => c.category === k).length]));
console.log(`candidates ${candidates.length} (pool ${pool.length} + leap 1), excluded ${excluded.length}, cycle ${seq.length}`);
console.log('per category', JSON.stringify(counts));
console.log('max uses', Math.max(...Object.values(uses)), 'min uses', Math.min(...Object.values(uses)));
console.log('demo seeds', candidates.filter((c) => c.provenance.origin === 'demoSeed').length);
