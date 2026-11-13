// Builds the complete personalisation proposal catalogue for every canonical
// verse of each bundled public-domain translation (KJV and WEB).
//
//   node tool/build_personalisation_catalogue.js
//
// Output: assets/mwb/catalogue/<edition>.catalogue.json
//
// What this tool does, and does not do:
// - It CLASSIFIES every verse into one of seven classes, using the curated
//   Stage C passage contexts where they exist and transparent, rule-based
//   lexical analysis (book genre, speaker markers, pronoun person and number)
//   everywhere else. Every class carries a stated reason.
// - It PROPOSES renderings only in two conservative forms:
//     Mode A  the reader's name is INSERTED as a direct address (vocative),
//             set off by commas. No source word is removed, replaced or
//             re-cased; no pronoun is changed.
//     Mode B  the Scripture text is left exactly as written; the name appears
//             only in an editorial title.
// - It NEVER approves anything. Every proposal is "proposed". Automated
//   validation (Dart: PersonalisationValidator) and human theological review
//   are separate later steps.
// - It is deterministic: the same inputs always produce the same catalogue.
//
// The WEB does not distinguish singular and plural "you". For WEB verses the
// person and number of the address is taken from the KJV text of the same
// canonical verse (thou/thee = singular, ye/you = plural). This is recorded on
// each WEB proposal.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const CATALOGUE_VERSION = '2026.11-d1';
const GENERATOR_RULE_VERSION = 1;

const readJson = (p) => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8'));
const kjv = readJson('assets/bible/kjv.json');
const web = readJson('assets/bible/web.json');
const intel = readJson('assets/intel/contexts.json').contexts;
const candidates = readJson('assets/daily/candidates.json').candidates;
const promises = readJson('assets/intel/promises.json').promises;
const identity = readJson('assets/intel/identity_themes.json').identityThemes;
const commands = readJson('assets/intel/commands.json').commands;
const worship = readJson('assets/intel/worship_themes.json').worshipThemes;

// ── Classes and reasons ───────────────────────────────────────────────────

const CLASSES = [
  ['nameInText', 'Eligible for name insertion'],
  ['nameInTitle', 'Eligible for name-in-title treatment'],
  ['otherTransformation', 'Eligible for another explicitly defined transformation'],
  ['originalOnly', 'Original text only'],
  ['contextualReview', 'Requires further contextual review'],
  ['excluded', 'Excluded from personalisation'],
  ['pendingDecision', 'Pending editorial or theological decision'],
];
const C = Object.fromEntries(CLASSES.map(([code], i) => [code, i]));

const REASONS = [
  // Original text only
  ['omitted', 'originalOnly', 'Verse not in this translation', 'The verse is not part of this translation’s text (a versification or textual omission).'],
  ['genealogy', 'originalOnly', 'Genealogy, census or record', 'A list, genealogy, census or record. There is no addressee to name.'],
  ['narrativeRecord', 'originalOnly', 'Historical narrative', 'Narration of events with no direct address to the reader.'],
  ['lawRecord', 'originalOnly', 'Legal or ritual instruction', 'Torah legislation or ritual instruction with no personal address suitable for naming.'],
  ['exposition', 'originalOnly', 'Teaching without direct address', 'Teaching or exposition that does not address the reader directly.'],
  ['wisdomSaying', 'originalOnly', 'Third-person wisdom saying', 'A proverb or saying in the third person. There is no addressee to name.'],
  ['poetryNoAddress', 'originalOnly', 'Poetry without address', 'Poetry with no direct address to the reader or worshipper.'],
  ['propheticNoAddress', 'originalOnly', 'Prophecy without address', 'Prophetic material with no direct address suitable for naming.'],
  ['apocalyptic', 'originalOnly', 'Apocalyptic vision', 'Apocalyptic vision or narration (Revelation, Daniel).'],
  ['noPositiveApplication', 'originalOnly', 'Collective address, no personal application', 'Addressed to a group, but not a promise, blessing or encouragement that could be framed for the reader.'],
  // Excluded
  ['judgement', 'excluded', 'Judgement, curse or warning', 'Personalising would turn a judgement, curse or warning into a personal pronouncement over the reader.'],
  ['narrativeDialogue', 'excluded', 'Words to a character in a narrative', 'Spoken to a specific person within a historical narrative (for example Jesus to Martha, God to Abraham). Naming the reader would change the audience.'],
  ['addressedToGod', 'excluded', 'Addressed to God', 'Prayer or praise addressed to God. The “thou” is God, not the reader.'],
  ['firstPersonVoice', 'excluded', 'First-person voice', 'The speaker’s own first-person words (psalmist, apostle, prophet). Inserting the reader’s name would change who is speaking.'],
  ['jobDialogue', 'excluded', 'Dialogue of Job', 'Speech within the dialogues of Job. God rebukes the friends’ words (Job 42:7), so their address is not the Bible’s address to the reader.'],
  ['romanticDialogue', 'excluded', 'Song of Songs dialogue', 'Words between the lovers of the Song. A specific relationship that must not be re-addressed.'],
  ['rhetoricalInterlocutor', 'excluded', 'Rhetorical opponent', 'Address to an imagined opponent (“O man”, “thou that judgest”) in an argument.'],
  ['specificChurch', 'excluded', 'Message to a specific church', 'Words addressed to a specific church or its angel (Revelation 2–3).'],
  ['curatedNotEligible', 'excluded', 'Curated context: not eligible', 'The curated Stage C passage context records this verse as not eligible for personalisation.'],
  // Requires further contextual review
  ['divineSpeechCollective', 'contextualReview', 'Divine speech to a people', 'Direct divine speech to Israel, Zion or a people. Whether a personal name may be inserted into God’s speech to His people needs theological review (Isaiah 43:1 is the reference case).'],
  ['covenantAddress', 'contextualReview', 'Covenant address to Israel', 'Torah address to Israel as a covenant people (“thou” is Israel). Collective; needs theological review before any personal framing.'],
  ['specificIndividualLetter', 'contextualReview', 'Letter to a named individual', 'Written to a named person (Timothy, Titus, Philemon, Gaius, the elect lady). Personal address to the reader needs review.'],
  ['testimonyPositive', 'contextualReview', 'First-person testimony', 'A first-person testimony or confession (for example Philippians 4:13). Whether it may be framed for the reader needs review; the speaker must not change.'],
  ['ambiguousAddressee', 'contextualReview', 'Addressee unclear', 'The text alone does not show whether “thou” is God, the worshipper or someone else.'],
  ['ecclesiastesVoice', 'contextualReview', 'The Preacher’s address', 'Ecclesiastes includes the Preacher’s observations that are not all commands. Needs review before naming the reader.'],
  ['curatedReviewRequired', 'contextualReview', 'Curated context: review required', 'The curated Stage C passage context requires review before personalisation.'],
  ['genderSpecificInstruction', 'contextualReview', 'Instruction to a young man', 'Proverbs 2:16–19 and 5–7 instruct a young man about adultery and marriage. Naming a reader of any gender would change its sense; needs review.'],
  ['noInsertionPoint', 'contextualReview','No safe insertion point', 'The addressee may be eligible, but no grammatically safe insertion point was found automatically.'],
  // Eligible: name inside the Scripture (Mode A)
  ['existingVocative', 'nameInText', 'Existing form of address', 'The verse already addresses a representative learner (“My son,”). The name follows that address, set off by commas. No word changes.'],
  ['representativeWisdomAddress', 'nameInText', 'Wisdom address to the learner', 'Wisdom instruction addressed to a representative learner (“thou”, “thee”). The name is added as a direct address; no word changes.'],
  ['representativePsalmAddress', 'nameInText', 'Psalm addressed to the worshipper', 'The psalm addresses the worshipper (“thee”) and speaks of God in the third person. The name is added as a direct address; no word changes.'],
  // Eligible: name in the title (Mode B)
  ['collectiveEncouragement', 'nameInTitle', 'Encouragement to believers', 'A promise, blessing or encouragement to believers together. The text stays exactly as written; the name appears only in the title.'],
  ['collectiveWorship', 'nameInTitle', 'Corporate praise or confession', 'Corporate worship (“we”, “our”). The text stays exactly as written; the name appears only in the title.'],
  ['teachingOfJesus', 'nameInTitle', 'Teaching of Jesus', 'Jesus’ teaching to His disciples or the crowds. The text stays exactly as written; the name appears only in the title.'],
  // Hand-authored rules
  ['handAuthoredInsertion', 'nameInText', 'Hand-authored rule', 'A hand-authored Stage B rule that inserts the name.'],
  ['handAuthoredReplacement', 'otherTransformation', 'Hand-authored tracked replacement', 'A hand-authored rule using a tracked replacement (punctuation or minimal grammatical adjustment).'],
  ['handAuthoredPending', 'pendingDecision', 'Open question for the supervisor', 'A hand-authored rule with an explicit open question for the theological supervisor.'],
];
const R = Object.fromEntries(REASONS.map(([code], i) => [code, i]));

// ── Books (traditional attributions, recorded as such) ───────────────────

const NT_START = 39;
const BOOK = {
  GEN: ['Moses (traditional attribution)', 'narrative', 'Israel'], EXO: ['Moses (traditional attribution)', 'narrative', 'Israel'],
  LEV: ['Moses (traditional attribution)', 'law', 'Israel'], NUM: ['Moses (traditional attribution)', 'narrative', 'Israel'],
  DEU: ['Moses (traditional attribution)', 'covenant', 'Israel on the plains of Moab'],
  JOS: ['Joshua (traditional attribution)', 'narrative', 'Israel'], JDG: ['Unknown (traditionally Samuel)', 'narrative', 'Israel'],
  RUT: ['Unknown (traditionally Samuel)', 'narrative', 'Israel'], '1SA': ['Unknown (traditionally Samuel, Nathan and Gad)', 'narrative', 'Israel'],
  '2SA': ['Unknown (traditionally Nathan and Gad)', 'narrative', 'Israel'], '1KI': ['Unknown (traditionally Jeremiah)', 'narrative', 'Israel'],
  '2KI': ['Unknown (traditionally Jeremiah)', 'narrative', 'Israel'], '1CH': ['Ezra (traditional attribution)', 'narrative', 'Israel after the exile'],
  '2CH': ['Ezra (traditional attribution)', 'narrative', 'Israel after the exile'], EZR: ['Ezra (traditional attribution)', 'narrative', 'Returned exiles'],
  NEH: ['Nehemiah', 'narrative', 'Returned exiles'], EST: ['Unknown', 'narrative', 'The Jewish people'],
  JOB: ['Unknown', 'job', 'Unspecified (wisdom)'], PSA: ['David and others (per the superscriptions)', 'psalm', 'Israel in worship'],
  PRO: ['Solomon and others (Proverbs 1:1; 30:1; 31:1)', 'wisdom', 'A learner addressed as “my son” (representative)'],
  ECC: ['The Preacher (traditionally Solomon)', 'ecclesiastes', 'The congregation'], SNG: ['Solomon (traditional attribution)', 'song', 'The beloved'],
  ISA: ['Isaiah', 'prophecy', 'Judah and Jerusalem'], JER: ['Jeremiah', 'prophecy', 'Judah and Jerusalem'], LAM: ['Jeremiah (traditional attribution)', 'lament', 'Jerusalem in ruins'],
  EZK: ['Ezekiel', 'prophecy', 'The exiles of Israel'], DAN: ['Daniel', 'apocalyptic', 'The Jewish exiles'],
  HOS: ['Hosea', 'prophecy', 'Israel'], JOL: ['Joel', 'prophecy', 'Judah'], AMO: ['Amos', 'prophecy', 'Israel'], OBA: ['Obadiah', 'prophecy', 'Edom and Judah'],
  JON: ['Unknown (traditionally Jonah)', 'narrative', 'Israel'], MIC: ['Micah', 'prophecy', 'Israel and Judah'], NAM: ['Nahum', 'prophecy', 'Nineveh and Judah'],
  HAB: ['Habakkuk', 'prophecy', 'Judah'], ZEP: ['Zephaniah', 'prophecy', 'Judah'], HAG: ['Haggai', 'prophecy', 'Returned exiles'],
  ZEC: ['Zechariah', 'prophecy', 'Returned exiles'], MAL: ['Malachi', 'prophecy', 'Post-exilic Judah'],
  MAT: ['Matthew (traditional attribution)', 'gospel', 'Readers of the Gospel'], MRK: ['Mark (traditional attribution)', 'gospel', 'Readers of the Gospel'],
  LUK: ['Luke', 'gospel', 'Theophilus'], JHN: ['John (traditional attribution)', 'gospel', 'Readers of the Gospel'],
  ACT: ['Luke', 'narrative', 'Theophilus'], ROM: ['Paul', 'epistle', 'The church in Rome'], '1CO': ['Paul', 'epistle', 'The church of God at Corinth'],
  '2CO': ['Paul', 'epistle', 'The church of God at Corinth'], GAL: ['Paul', 'epistle', 'The churches of Galatia'], EPH: ['Paul', 'epistle', 'The saints at Ephesus'],
  PHP: ['Paul', 'epistle', 'The saints at Philippi'], COL: ['Paul', 'epistle', 'The saints at Colossae'], '1TH': ['Paul', 'epistle', 'The church of the Thessalonians'],
  '2TH': ['Paul', 'epistle', 'The church of the Thessalonians'], '1TI': ['Paul', 'personalLetter', 'Timothy'], '2TI': ['Paul', 'personalLetter', 'Timothy'],
  TIT: ['Paul', 'personalLetter', 'Titus'], PHM: ['Paul', 'personalLetter', 'Philemon and the church in his house'],
  HEB: ['Unknown', 'epistle', 'Hebrew believers'], JAS: ['James', 'epistle', 'The twelve tribes scattered abroad'],
  '1PE': ['Peter', 'epistle', 'Believers scattered in Asia Minor'], '2PE': ['Peter', 'epistle', 'Believers'],
  '1JN': ['John (traditional attribution)', 'epistle', 'Believers (“my little children”)'], '2JN': ['John (traditional attribution)', 'personalLetter', 'The elect lady and her children'],
  '3JN': ['John (traditional attribution)', 'personalLetter', 'Gaius'], JUD: ['Jude', 'epistle', 'Them that are called'],
  REV: ['John', 'apocalyptic', 'The seven churches in Asia'],
};
const FORM_LABEL = {
  narrative: 'Historical narrative', law: 'Torah legislation', covenant: 'Covenant address (Torah)', job: 'Wisdom dialogue (poetry)',
  psalm: 'Psalm (poetry)', wisdom: 'Wisdom instruction', ecclesiastes: 'Wisdom reflection', song: 'Love poetry', prophecy: 'Prophetic oracle',
  lament: 'Lament (poetry)', apocalyptic: 'Apocalyptic', gospel: 'Gospel', epistle: 'Letter', personalLetter: 'Personal letter',
};

// ── Lexical features (KJV is the number oracle) ──────────────────────────

const words = (s) => (s.match(/[A-Za-z’']+/g) || []).map((w) => w.toLowerCase());
const has = (ws, set) => ws.some((w) => set.has(w));
const SING2 = new Set(['thou', 'thee', 'thy', 'thine', 'thyself']);
const PLUR2 = new Set(['ye', 'you', 'your', 'yours', 'yourselves']);
const PLUR1 = new Set(['we', 'us', 'our', 'ours', 'ourselves']);
const SING1 = new Set(['i', 'me', 'my', 'mine', 'myself']);
const NEGATIVE = new Set(['woe', 'curse', 'cursed', 'curseth', 'wrath', 'destroy', 'destroyed', 'destroyeth', 'destruction', 'perish', 'perished',
  'punish', 'punished', 'vengeance', 'abomination', 'abominations', 'slay', 'slain', 'hell', 'damnation', 'plague', 'plagues', 'famine',
  'whore', 'whoredom', 'whoredoms', 'harlot', 'fornication', 'adulteress', 'desolate', 'desolation', 'smite', 'smitten', 'consume', 'consumed',
  'fury', 'indignation', 'scatter', 'cast', 'rebuke', 'condemn', 'condemned', 'condemnation', 'fool', 'fools', 'sluggard', 'wicked', 'evil',
  'enemies', 'enemy', 'adversaries', 'shame', 'mischief', 'wickedness', 'sword', 'pestilence', 'pit', 'dasheth', 'thief', 'die', 'death', 'rod', 'beatest', 'grave', 'snare', 'surety', 'drunkard', 'glutton', 'wine', 'bribe', 'lie', 'lying',
  'blasphemy', 'sin', 'sins', 'murderer', 'mourn', 'mourning', 'weep', 'affliction', 'vain', 'unrighteousness', 'trembling', 'dead', 'hateth', 'anger',
  'trouble', 'distress', 'afflicted', 'heaviness', 'judge', 'judged', 'flesh', 'lust', 'lusts', 'deceive', 'deceived']);
// Soft negatives only count when nothing positive is said (see isJudgement).
const SOFT = ['wicked', 'evil', 'cast', 'rebuke', 'fool', 'fools', 'sluggard', 'scatter', 'consume', 'consumed', 'desolate', 'enemies', 'enemy',
  'adversaries', 'shame', 'mischief', 'wickedness', 'sword', 'pestilence', 'pit', 'thief', 'die', 'death', 'rod', 'beatest', 'grave', 'snare', 'surety', 'drunkard', 'glutton', 'wine', 'bribe', 'lie', 'lying',
  'blasphemy', 'sin', 'sins', 'murderer', 'mourn', 'mourning', 'weep', 'affliction', 'vain', 'unrighteousness', 'trembling', 'dead', 'hateth', 'anger',
  'trouble', 'distress', 'afflicted', 'heaviness', 'judge', 'judged', 'flesh', 'lust', 'lusts', 'deceive', 'deceived'];
const STRONG_NEGATIVE = new Set([...NEGATIVE].filter((w) => !SOFT.includes(w)));
// Relationship or role terms: the verse speaks to someone in a specific relationship.
const RELATIONAL = /\b(wife|wives|husband|woman|women|harlot|whore|adulteress|daughter|damsel|maid|maiden|virgin|king|king’s|prince|queen|servant|handmaid|bride|bridegroom|thy son|thy sons|thy daughters)\b/i;
// A vocative to someone other than the reader.
const OTHER_VOCATIVE = /\bO (Israel|Jacob|Jerusalem|Zion|Egypt|daughter|city|mighty|house|king|earth|heavens|mountains|Babylon|Judah|Lebanon|Edom|Moab|Tyre|ye)\b|\bthou (earth|sea|daughter|city|son of)\b/;
// God named in the third person as the one who acts for the reader (Mode A in Psalms).
const GOD_ACTS_ON_THEE = /\b(the LORD|God|He|he|the most High|the Almighty)\s+(shall|will|is|hath|doth|hear|keep|bless|preserve|deliver|sustain|cover|give|be)\b[^.;:?!]*\b(thee|thy|thine)\b/;
const TURN_TO_THE_LORD = /^(Delight|Commit|Trust|Wait|Rest|Cast)\b[^.;:?!]*\b(in|on|upon|unto) the LORD\b/;
const POSITIVE = new Set(['hope', 'peace', 'joy', 'rejoice', 'rejoiceth', 'love', 'loved', 'loveth', 'grace', 'comfort', 'comforted', 'comforteth',
  'strength', 'strengthen', 'strengtheneth', 'strong', 'rest', 'faith', 'mercy', 'mercies', 'merciful', 'blessed', 'bless', 'blesseth', 'blessing',
  'keep', 'keepeth', 'kept', 'preserve', 'preserveth', 'help', 'helper', 'courage', 'salvation', 'save', 'saved', 'saveth', 'life', 'light', 'giveth',
  'wisdom', 'heal', 'healeth', 'healed', 'deliver', 'delivereth', 'delivered', 'refuge', 'trust', 'goodness', 'kindness', 'lovingkindness', 'faithful',
  'shepherd', 'guide', 'lead', 'leadeth', 'teach', 'forgive', 'forgiven', 'redeemed', 'redeemer', 'eternal', 'everlasting', 'praise', 'thanks',
  'thank', 'prosper', 'abound', 'gladness', 'glad', 'fear', 'afraid', 'beloved', 'gift', 'promise', 'promises', 'inheritance', 'glory', 'holy',
  'rejoicing', 'patience', 'wait', 'renew', 'shield', 'fortress', 'rock', 'safety', 'safely', 'quiet', 'still', 'abide', 'abideth', 'dwell',
  'sufficient', 'supply', 'riches', 'good', 'perfect', 'confidence', 'boldly', 'boldness', 'victory', 'overcome', 'overcometh', 'conquerors',
  'children', 'sons', 'adoption', 'chosen', 'called', 'workmanship', 'new', 'sound', 'mind', 'power', 'careth', 'compassion', 'compassions']);
const GENEALOGY = /\bbegat\b|\bthe sons of\b|\bwere the sons\b|\bthese are the (generations|names|families|sons)\b|\bthe children of \w+, (an hundred|two hundred|three hundred|four hundred|five hundred|six hundred|seven hundred|a thousand)|\bthousand and (\w+ )?hundred\b|\bwere numbered\b/i;
const DIALOGUE = /\b(said|saith|spake|answered|cried|called|commanded|asked|sware|charged)\s+(unto|to)\s+(him|her|them|his|the|Moses|Aaron|Joshua|David|Saul|Abraham|Abram|Jacob|Israel|Peter|Jesus|Mary|Martha|Elijah|Elisha|Samuel|Gideon|Ahab|Pharaoh|[A-Z]\w+)\b|\b(he|she|they|Jesus|God|the LORD) (said|answered|saith)\b|\banswered and said\b/;
const DIVINE = /\bsaith the LORD\b|\bthus saith\b|\bI am the LORD\b|\bI the LORD\b|\bthe LORD (said|spake|hath said|hath spoken)\b|\bthe word of the LORD came\b|\bsaith the Lord GOD\b|\bsaith God\b|\bI am God\b/;
const GOD_VOCATIVE = /\bO (LORD|Lord|God|my God|most High|thou|Holy One|Jehovah)\b|\bLORD, (thou|my|how|I|we)\b|\b(my|our) God\b.*\bthou\b|\bthou art (my|our|the|God|great|good|holy|fairer|exalted|my God)\b/;
const GOD_ATTRIBUTE = /\b(thy|thine) (name|mercy|mercies|lovingkindness|faithfulness|righteousness|truth|salvation|word|words|law|statutes|commandments|commandment|precepts|testimonies|judgments|ordinances|servant|servants|right hand|hand|face|glory|kingdom|works|wonders|holy|presence|tabernacle|house|altar|sanctuary|people|inheritance|anger|wrath|throne|ways|paths|counsel|saints|power|strength|majesty|praise|thoughts|wings)\b/i;
const THIRD_PERSON_GOD = /\b(the LORD|God|the Lord|the most High|the Almighty|he|him|his)\b/;
const MY_SON = /\b(O my son|my son),/i;

// Curated Stage C contexts (version-independent), by single verse.
const intelBy = new Map();
for (const c of intel) {
  const m = c.reference.match(/^(\w+) (\d+):(\d+)(?:-(\d+))?$/);
  if (!m) continue;
  for (let v = +m[3]; v <= +(m[4] || m[3]); v++) intelBy.set(`${m[1]} ${m[2]}:${v}`, c);
}

// Curated headings (editorial, not Scripture), by single verse.
const headingBy = new Map();
// Headings with first-person words would put a speaker's words into a title
// addressed to the reader, so they are never used for titles.
const FIRST_PERSON_TITLE = /\b(I|me|my|mine|myself|Me|My|Mine)\b/;
const addHeading = (ref, title, source) => {
  const m = (ref || '').match(/^(\w+) (\d+):(\d+)(?:-(\d+))?$/);
  if (!m || !title || FIRST_PERSON_TITLE.test(title)) return;
  for (let v = +m[3]; v <= +(m[4] || m[3]); v++) {
    const k = `${m[1]} ${m[2]}:${v}`;
    if (!headingBy.has(k)) headingBy.set(k, { title, source });
  }
};
for (const c of candidates) addHeading(c.reference, c.title, `Daily Word candidate ${c.id}`);
for (const p of promises) for (const r of p.references) addHeading(r, p.title, `Intelligence promise ${p.id}`);
for (const p of identity) for (const r of p.references) addHeading(r, p.title, `Identity theme ${p.id}`);
for (const p of commands) for (const r of p.references) addHeading(r, p.title, `Command ${p.id}`);
for (const p of worship) for (const r of p.references) addHeading(r, p.title, `Worship theme ${p.id}`);

const PROPER_START = /^(God|LORD|Lord|Jesus|Christ|I\b|Holy|Spirit|Israel|Jerusalem|Zion|The LORD|Father|Immanuel|Emmanuel)/;
const titleTemplate = (heading) => {
  const h = heading.trim();
  const body = PROPER_START.test(h) ? h : h.charAt(0).toLowerCase() + h.slice(1);
  return `{name}, ${body}`;
};

// ── Classification ────────────────────────────────────────────────────────

const isJudgement = (ws) => {
  const strong = ws.filter((w) => STRONG_NEGATIVE.has(w)).length;
  const pos = ws.filter((w) => POSITIVE.has(w)).length;
  const soft = ws.filter((w) => NEGATIVE.has(w)).length;
  return strong > 0 || (soft > 0 && pos === 0);
};
const isPositive = (ws) => ws.some((w) => POSITIVE.has(w));

// Mode B is offered only for a clear promise, blessing or encouragement: a
// strong positive word, no negative word at all, no rebuke or lament, and no
// conditional ("if ye…"), which is held for review instead.
const STRONG_POSITIVE = new Set(['hope', 'peace', 'joy', 'rejoice', 'love', 'loved', 'grace', 'comfort', 'comforted', 'strength', 'strengthen',
  'strengtheneth', 'rest', 'faith', 'mercy', 'mercies', 'merciful', 'blessed', 'blessing', 'salvation', 'keep', 'keepeth', 'preserve', 'help',
  'deliver', 'delivereth', 'refuge', 'everlasting', 'eternal', 'forgive', 'forgiven', 'redeemed', 'beloved', 'abound', 'gladness', 'careth',
  'sufficient', 'supply', 'victory', 'conquerors', 'workmanship', 'lovingkindness', 'goodness', 'heal', 'healeth', 'light', 'life', 'praise', 'thanks']);
const REBUKE = /\bhow long\b|\bye have\b.*\b(shamed|despised|robbed|forsaken|sinned)\b|\bwoe\b|\bhypocrites\b|\bO ye\b|\bgeneration of vipers\b|\bfools\b|\bunbelieving\b|\brepent\b/i;
const PRAISE_CALL = /\b(Praise ye|O praise|Sing unto|Sing ye|O give thanks|Give thanks|O taste and see|Make a joyful noise|Serve the LORD|Bless the LORD|Bless ye|O come|Come, let us)\b/;
const modeBEligible = (ws, text, allowFirstPerson = false) =>
  ws.some((w) => STRONG_POSITIVE.has(w)) && !ws.some((w) => NEGATIVE.has(w)) && !REBUKE.test(text) && !text.includes("?") &&
  (allowFirstPerson || !has(ws, SING1)) && !RELATIONAL.test(text) && !/\b[Ii]f (ye|we)\b|\bunless\b|\bexcept ye\b/.test(text);

/** Returns { reason, risk, speaker, addressee, notes[] } for a verse. */
function classify(bookId, bookIndex, chapter, verse, kjvText, neighbours = { prev: '', next: '' }) {
  const [author, form, audience] = BOOK[bookId];
  const ws = words(kjvText);
  const s2 = has(ws, SING2), p2 = has(ws, PLUR2), p1 = has(ws, PLUR1), s1 = has(ws, SING1);
  const ref = `${bookId} ${chapter}:${verse}`;
  const ctx = intelBy.get(ref);
  const out = (reason, extra = {}) => ({ reason, risk: 'medium', speaker: defaultSpeaker(form), addressee: audience, notes: [], ...extra });

  if (!kjvText) return out('omitted');
  if (GENEALOGY.test(kjvText)) return out('genealogy');

  // Curated context overrides heuristics for who is speaking to whom.
  if (ctx) {
    const sp = ctx.speaker;
    const aud = ctx.originalAudience;
    if (ctx.personalisation && ctx.personalisation.eligibility === 'notEligible') {
      return out('curatedNotEligible', { speaker: sp, addressee: aud, risk: ctx.personalisation.risk || 'high', notes: [ctx.personalisation.note || ''].filter(Boolean) });
    }
    if (ctx.addressee === 'god') return out('addressedToGod', { speaker: sp, addressee: aud, risk: 'high' });
    if (ctx.addressee === 'narrative' || ctx.classification === 'historicalNarrative') {
      return out(s2 || p2 ? 'narrativeDialogue' : 'narrativeRecord', { speaker: sp, addressee: aud, risk: 'high' });
    }
    if (ctx.addressee === 'specificIndividual') {
      return out(form === 'gospel' || form === 'narrative' ? 'narrativeDialogue' : 'specificIndividualLetter', { speaker: sp, addressee: aud, risk: 'high' });
    }
    if (ctx.addressee === 'testimony') return out(isPositive(ws) ? 'testimonyPositive' : 'firstPersonVoice', { speaker: sp, addressee: aud, risk: 'high' });
    if (ctx.voice === 'god' && ctx.addressee === 'collective') return out('divineSpeechCollective', { speaker: sp, addressee: aud, risk: 'critical' });
    if (ctx.addressee === 'collective') {
      if (isPositive(ws) && !isJudgement(ws)) {
        return out(ctx.voice === 'jesus' ? 'teachingOfJesus' : 'collectiveEncouragement', { speaker: sp, addressee: aud, risk: 'high' });
      }
      return out('noPositiveApplication', { speaker: sp, addressee: aud });
    }
    // representative / general: fall through to genre rules with curated speaker.
  }

  // Narrative-like genres decide inside the genre: "burnt offering" or a
  // dialogue is not a judgement oracle.
  const genreFirst = ['narrative', 'law', 'covenant', 'job', 'song', 'gospel', 'ecclesiastes'];
  if (!genreFirst.includes(form) && isJudgement(ws)) {
    return out('judgement', { risk: 'high' });
  }

  switch (form) {
    case 'narrative':
    case 'law':
      if (s2 || p2) {
        if (form === 'law' || (bookIndex <= 3 && !DIALOGUE.test(kjvText) && DIVINE.test(kjvText) === false && /\bthou shalt\b/.test(kjvText))) {
          return out(isPositive(ws) ? 'covenantAddress' : 'lawRecord', { risk: 'high', addressee: 'Israel' });
        }
        return out('narrativeDialogue', { risk: 'high', speaker: 'A character in the narrative', addressee: 'A person or group within the narrative' });
      }
      return out(form === 'law' ? 'lawRecord' : 'narrativeRecord');
    case 'covenant':
      if (s2 || p2) return out(isPositive(ws) ? 'covenantAddress' : 'lawRecord', { risk: 'high', speaker: 'Moses', addressee: 'Israel' });
      return out('lawRecord');
    case 'job':
      if (chapter <= 2 || chapter === 42) return out(s2 || p2 ? 'narrativeDialogue' : 'narrativeRecord', { risk: 'high' });
      if (s2 || p2 || s1) return out('jobDialogue', { risk: 'high', speaker: 'Job, his friends, Elihu or the LORD' });
      return out('poetryNoAddress');
    case 'song':
      return out(s2 || s1 || p2 ? 'romanticDialogue' : 'poetryNoAddress', { risk: 'high', speaker: 'The beloved or her lover', addressee: 'The lover or the beloved' });
    case 'psalm':
    case 'lament': {
      const speaker = form === 'psalm' ? 'The psalmist' : 'The poet of Lamentations';
      if (s2) {
        if (GOD_VOCATIVE.test(kjvText) || GOD_ATTRIBUTE.test(kjvText) || /\b[Tt]hou art\b|\b[Tt]hou,? (O )?(LORD|God|Lord)\b|\b(LORD|God|Lord) ?, ?thou\b/.test(kjvText)) {
          return out('addressedToGod', { risk: 'high', speaker, addressee: 'God' });
        }
        if (OTHER_VOCATIVE.test(kjvText) || OTHER_VOCATIVE.test(neighbours.prev) || OTHER_VOCATIVE.test(neighbours.next)) {
          return out('ambiguousAddressee', { risk: 'high', speaker, addressee: 'A named person, city or people (vocative in or beside the verse)' });
        }
        if (form === 'lament' || RELATIONAL.test(kjvText)) {
          return out('ambiguousAddressee', { risk: 'high', speaker, addressee: form === 'lament' ? 'Jerusalem, Zion or God' : 'A person in a specific role or relationship' });
        }
        if (s1) return out(THIRD_PERSON_GOD.test(kjvText) ? 'ambiguousAddressee' : 'addressedToGod', { risk: 'high', speaker });
        if (DIVINE.test(kjvText)) return out('divineSpeechCollective', { risk: 'critical', speaker: 'God (quoted in the psalm)' });
        const actsForThee = GOD_ACTS_ON_THEE.test(kjvText) || TURN_TO_THE_LORD.test(kjvText);
        if (actsForThee && isPositive(ws) && !has(ws, NEGATIVE)) {
          return out('representativePsalmAddress', { risk: 'medium', speaker, addressee: 'The worshipper (“thee”)' });
        }
        return out('ambiguousAddressee', { risk: 'high', speaker });
      }
      if (p2 || p1) {
        if (/\bO (LORD|God|Lord)\b|\bthou\b/.test(kjvText)) return out('addressedToGod', { risk: 'high', speaker });
        if (modeBEligible(ws, kjvText) && (p1 ? !s1 : PRAISE_CALL.test(kjvText))) return out(p1 ? 'collectiveWorship' : 'collectiveEncouragement', { risk: 'medium', speaker, addressee: 'The worshipping congregation' });
        return out('noPositiveApplication', { speaker });
      }
      if (s1) return out(isPositive(ws) ? 'testimonyPositive' : 'firstPersonVoice', { risk: 'high', speaker });
      return out('poetryNoAddress', { speaker });
    }
    case 'wisdom': {
      const lemuel = chapter === 31 && verse <= 9;
      if (lemuel && (s2 || MY_SON.test(kjvText))) return out('specificIndividualLetter', { risk: 'high', speaker: 'The mother of King Lemuel', addressee: 'King Lemuel (Proverbs 31:1)' });
      const core = chapter <= 9 || (chapter === 22 && verse >= 17) || chapter === 23 || (chapter === 24 && verse <= 34) || chapter === 27;
      const genderSpecific = chapter === 5 || chapter === 7 || (chapter === 6 && verse >= 20) || (chapter === 2 && verse >= 16 && verse <= 19);
      if (genderSpecific && (s2 || MY_SON.test(kjvText))) {
        return out('genderSpecificInstruction', { risk: 'high', speaker: 'The wise teacher', addressee: 'A young man warned about adultery or taught about marriage' });
      }
      if (chapter === 30 && (s2 || s1)) return out('ambiguousAddressee', { risk: 'high', speaker: 'Agur (Proverbs 30:1)', addressee: 'Ithiel and Ucal, or God in prayer (30:7–9)' });
      if (chapter === 31 && s2) return out('ambiguousAddressee', { risk: 'high', speaker: 'Lemuel’s mother / the poet', addressee: 'The woman of valour (31:29)' });
      if (/\bsaid unto me\b|\bsaith he\b|\bshalt thou say\b/.test(kjvText)) {
        return out('ambiguousAddressee', { risk: 'high', speaker: 'A speaker quoted within the instruction', addressee: 'Unclear (quoted speech)' });
      }
      if (s1 && s2 && /\b(LORD|God)\b/.test(kjvText)) return out('ambiguousAddressee', { risk: 'high', speaker: 'The wise teacher', addressee: 'Possibly God (prayer)' });
      if (RELATIONAL.test(kjvText) && (s2 || MY_SON.test(kjvText))) {
        return out('ambiguousAddressee', { risk: 'high', speaker: 'The wise teacher', addressee: 'A learner addressed within a specific relationship (wife, king, servant…)' });
      }
      if (MY_SON.test(kjvText)) return out('existingVocative', { risk: core ? 'low' : 'medium', speaker: 'The wise teacher (Proverbs 1:8)', addressee: 'A learner addressed as “my son” (representative)' });
      if (s2) return out('representativeWisdomAddress', { risk: core ? 'low' : 'medium', speaker: 'The wise teacher', addressee: 'A representative learner (“thou”)' });
      if (p2) return out(modeBEligible(ws, kjvText) ? 'collectiveEncouragement' : 'noPositiveApplication', { risk: 'medium', speaker: 'Wisdom personified or the teacher', addressee: 'The simple and all who will hear' });
      return out('wisdomSaying');
    }
    case 'ecclesiastes':
      if (s2 || MY_SON.test(kjvText)) return out('ecclesiastesVoice', { risk: 'high', speaker: 'The Preacher' });
      return out(s1 ? 'firstPersonVoice' : 'wisdomSaying', { speaker: 'The Preacher' });
    case 'prophecy':
      if (s2 || p2) {
        if (isPositive(ws)) return out('divineSpeechCollective', { risk: 'critical', speaker: 'God through the prophet', addressee: 'Israel, Judah, Zion or the nations' });
        return out('propheticNoAddress', { risk: 'high' });
      }
      return out(s1 && DIVINE.test(kjvText) ? 'propheticNoAddress' : 'propheticNoAddress');
    case 'apocalyptic':
      if (bookId === 'REV' && (chapter === 2 || chapter === 3) && (s2 || p2)) return out('specificChurch', { risk: 'high', addressee: 'A specific church in Asia' });
      if (bookId === 'DAN' && (s2 || p2)) return out('narrativeDialogue', { risk: 'high' });
      if (p2 && modeBEligible(ws, kjvText)) return out('collectiveEncouragement', { risk: 'high', addressee: 'The churches' });
      return out('apocalyptic');
    case 'gospel':
      if (s2) return out('narrativeDialogue', { risk: 'high', speaker: 'Jesus or another speaker', addressee: 'A specific person in the Gospel narrative' });
      if (p2 && !DIALOGUE.test(kjvText)) {
        if (modeBEligible(ws, kjvText, true)) return out('teachingOfJesus', { risk: 'high', speaker: 'Jesus (or the Gospel writer)', addressee: 'The disciples or the crowd' });
        return out('noPositiveApplication', { speaker: 'Jesus' });
      }
      if (p2) return out('narrativeDialogue', { risk: 'high' });
      return out('narrativeRecord');
    case 'epistle':
      if (s2) {
        if (/\bO man\b|\bthou that\b|\bwho art thou\b|\bthou fool\b|\bthou hast faith\b/.test(kjvText)) return out('rhetoricalInterlocutor', { risk: 'high', speaker: author });
        return out('ambiguousAddressee', { risk: 'high', speaker: author });
      }
      if (p2 || p1) {
        if (modeBEligible(ws, kjvText)) return out('collectiveEncouragement', { risk: p2 ? 'medium' : 'medium', speaker: author, addressee: audience });
        return out('noPositiveApplication', { speaker: author });
      }
      if (s1) return out(isPositive(ws) ? 'testimonyPositive' : 'firstPersonVoice', { risk: 'high', speaker: author });
      return out('exposition', { speaker: author });
    case 'personalLetter':
      if (s2) return out('specificIndividualLetter', { risk: 'high', speaker: author, addressee: audience });
      if ((p2 || p1) && modeBEligible(ws, kjvText)) return out('collectiveEncouragement', { risk: 'high', speaker: author, addressee: audience });
      if (s1) return out(isPositive(ws) ? 'testimonyPositive' : 'firstPersonVoice', { risk: 'high', speaker: author });
      return out('exposition', { speaker: author });
    default:
      return out('exposition');
  }
}

function defaultSpeaker(form) {
  return {
    narrative: 'The narrator', law: 'Moses (recording the LORD’s instruction)', covenant: 'Moses', job: 'Job, his friends, Elihu or the LORD',
    psalm: 'The psalmist', wisdom: 'The wise teacher', ecclesiastes: 'The Preacher', song: 'The beloved or her lover', prophecy: 'The prophet',
    lament: 'The poet of Lamentations', apocalyptic: 'The seer', gospel: 'The Gospel writer', epistle: 'The apostle', personalLetter: 'The apostle',
  }[form];
}

// ── Mode A insertion points ──────────────────────────────────────────────

function occurrenceOf(text, anchor, at) {
  let n = 0, i = text.indexOf(anchor);
  while (i >= 0) {
    n++;
    if (i === at) return n;
    i = text.indexOf(anchor, i + 1);
  }
  return null;
}

const SECOND_WEB = /\b(you|your|yourself)\b/;
const SECOND_KJV = /\b(thou|thee|thy|thine|thyself|Thou|Thy|Thine)\b/;

/**
 * Finds where a vocative name may be inserted without changing any word.
 * Returns { operation, anchor, occurrence, text, rationale } or null.
 */
function insertionFor(text, isKjv) {
  const son = text.match(MY_SON);
  if (son) {
    const at = son.index;
    const anchor = son[0];
    return {
      operation: 'insertNameAfterExistingAddress', anchor, occurrence: occurrenceOf(text, anchor, at), position: 'after', text: ' {name},',
      grammar: [`The name follows the existing address “${anchor.replace(/,$/, '')}” and is set off by commas.`, 'No word of the source is changed, removed or re-cased.'],
    };
  }
  const re = isKjv ? SECOND_KJV : SECOND_WEB;
  const m = text.match(re);
  if (!m) return null;
  const start = m.index;
  const after = text.slice(start);
  // The first clause-closing mark after the second-person word, skipping any
  // mark that introduces quoted speech (", Go" / ", “Go"): a name placed
  // there could be read as the name of the person being quoted.
  // A comma or colon followed by a capital or an opening quote introduces
  // quoted speech; then no insertion is proposed at all (the name could
  // land inside, or be read as part of, the quotation).
  const first = after.match(/[,;:.?!]/);
  let p = -1;
  if (first) {
    const rest = after.slice(first.index + 1).replace(/^\s+/, '');
    if (/[,:]/.test(first[0]) && /^[A-Z“‘"]/.test(rest)) return null;
    p = first.index;
  }
  let anchor, at;
  if (p < 0) {
    // No punctuation follows: append before nothing (end of verse).
    anchor = after;
    at = start;
  } else {
    anchor = after.slice(0, p).replace(/\s+$/, '');
    at = start;
  }
  // Keep anchors readable but unique enough; trim a trailing closing quote.
  if (/[”’)\]]$/.test(anchor)) return null;
  if (anchor.trim().length === 0) return null;
  const occurrence = occurrenceOf(text, anchor, at);
  if (occurrence == null) return null;
  const punct = p < 0 ? '' : after[p];
  return {
    operation: 'insertDirectAddress', anchor, occurrence, position: 'after', text: ', {name}',
    grammar: [
      punct
        ? `The name is a direct address set off by a comma before the existing “${punct}” that closes the clause beginning “${m[0]}”.`
        : `The name is a direct address added at the end of the clause beginning “${m[0]}”.`,
      'No word of the source is changed, removed or re-cased; no pronoun is replaced.',
    ],
  };
}

// ── Build ────────────────────────────────────────────────────────────────

function handRules(file) {
  const j = readJson(`assets/mwb/rulesets/${file}`);
  const by = new Map();
  for (const r of j.rules) {
    if (!by.has(r.reference)) by.set(r.reference, []);
    by.get(r.reference).push(r);
  }
  return by;
}

function build({ source, sourceVersionId, targetVersionId, prefix, rulesetFile, isKjv }) {
  const hand = handRules(rulesetFile);
  const books = [];
  const proposals = [];
  const kjvBooks = new Map(kjv.books.map((b) => [b.id, b]));
  source.books.forEach((book, bookIndex) => {
    const [author, form, audience] = BOOK[book.id];
    const kjvBook = kjvBooks.get(book.id);
    const chapters = [];
    book.chapters.forEach((verses, ci) => {
      const codes = [];
      verses.forEach((text, vi) => {
        const chapter = ci + 1, verse = vi + 1;
        const ref = `${book.id} ${chapter}:${verse}`;
        const kjvText = (kjvBook.chapters[ci] || [])[vi] || '';
        const handHere = hand.get(ref);
        if (handHere) {
          const open = handHere.filter((r) => !['rejected', 'retired'].includes(r.status));
          const pending = open.some((r) => r.reviewQuestion);
          const replaces = open.some((r) => r.edits.some((e) => e.position === 'replace'));
          const reason = pending ? 'handAuthoredPending' : replaces ? 'handAuthoredReplacement' : 'handAuthoredInsertion';
          const cls = REASONS[R[reason]][1];
          codes.push(C[cls] * 100 + R[reason]);
          return;
        }
        const effectiveText = text || '';
        const kjvChapter = kjvBook.chapters[ci] || [];
        let c = classify(book.id, bookIndex, chapter, verse, effectiveText ? kjvText : '', {
          prev: kjvChapter[vi - 1] || '',
          next: kjvChapter[vi + 1] || '',
        });
        if (!effectiveText) c = { ...c, reason: 'omitted' };
        let reason = c.reason;
        let cls = REASONS[R[reason]][1];
        let proposal = null;
        const ctx = intelBy.get(ref);
        const base = {
          id: `${prefix}.gen.${book.id}.${chapter}.${verse}`,
          ruleVersion: 1,
          proposalVersion: 1,
          generatorRuleVersion: GENERATOR_RULE_VERSION,
          reference: ref,
          sourceText: effectiveText,
          requiredFields: ['personalName'],
          status: 'proposed',
          reviews: [],
          classification: cls,
          reason,
          author: ctx ? ctx.author : author,
          speaker: c.speaker,
          audience: c.addressee,
          literaryForm: ctx ? ctx.literaryForm : FORM_LABEL[form],
          contextSource: ctx ? `Curated Stage C context ${ctx.id}` : 'Book-level metadata and lexical analysis (no curated context)',
          numberSource: isKjv ? 'KJV pronouns' : 'KJV pronouns of the same canonical verse (the WEB does not distinguish singular and plural “you”)',
          provenance: { origin: 'generated', generator: 'tool/build_personalisation_catalogue.js', catalogueVersion: CATALOGUE_VERSION },
        };
        if (cls === 'nameInText') {
          const ins = insertionFor(effectiveText, isKjv);
          if (!ins) {
            reason = 'noInsertionPoint';
            cls = 'contextualReview';
          } else {
            proposal = {
              ...base,
              presentationMode: 'nameInText',
              edits: [{ operation: ins.operation, anchor: ins.anchor, ...(ins.occurrence > 1 || effectiveText.split(ins.anchor).length > 2 ? { occurrence: ins.occurrence } : {}), position: ins.position, text: ins.text }],
              grammaticalConditions: ins.grammar,
              risk: c.risk,
              riskReasons: [REASONS[R[reason]][3]],
              rationale: REASONS[R[reason]][3],
              confidence: c.risk === 'low' ? 'Higher: representative address in wisdom instruction.' : 'Moderate: addressee inferred from genre and pronouns; confirm the addressee in context.',
              uncertainty: ctx ? '' : 'No curated passage context; author, speaker and audience come from book-level metadata.',
            };
          }
        } else if (cls === 'nameInTitle') {
          const heading = headingBy.get(ref);
          proposal = {
            ...base,
            presentationMode: 'nameInTitle',
            edits: [],
            title: heading ? titleTemplate(heading.title) : null,
            titleSource: heading ? heading.source : null,
            grammaticalConditions: ['The Scripture text is shown exactly as written. Only the editorial title carries the name.'],
            risk: c.risk,
            riskReasons: [REASONS[R[reason]][3]],
            rationale: REASONS[R[reason]][3],
            confidence: heading ? 'Title taken from a curated heading.' : 'An editorial title is still needed before this proposal can pass automated checks.',
            uncertainty: 'Collective audience: the title must not turn a collective promise into an individual guarantee.',
          };
          if (proposal) base.classification = cls;
        }
        if (proposal) {
          proposal.classification = cls;
          proposal.reason = reason;
          proposals.push(proposal);
        }
        codes.push(C[cls] * 100 + R[reason]);
      });
      chapters.push(codes);
    });
    books.push({ id: book.id, name: book.name, author, form: FORM_LABEL[form], audience, chapters });
  });
  return {
    schema: 1,
    catalogueVersion: CATALOGUE_VERSION,
    generatorRuleVersion: GENERATOR_RULE_VERSION,
    generator: 'tool/build_personalisation_catalogue.js',
    sourceVersionId,
    targetVersionId,
    note: 'Every verse is classified; proposals are NOT approved. Verse codes are class*100+reason (indexes into classes and reasons). Hand-authored rules live in assets/mwb/rulesets and take precedence for their verses.',
    classes: CLASSES.map(([code, label]) => ({ code, label })),
    reasons: REASONS.map(([code, cls, label, explanation]) => ({ code, class: cls, label, explanation })),
    books,
    proposals,
  };
}

const outDir = path.join(root, 'assets/mwb/catalogue');
fs.mkdirSync(outDir, { recursive: true });
for (const cfg of [
  { source: kjv, sourceVersionId: 'KJV', targetVersionId: 'KJV-MWB', prefix: 'kjv-mwb', rulesetFile: 'kjv-mwb.json', isKjv: true },
  { source: web, sourceVersionId: 'WEB', targetVersionId: 'WEB-MWB', prefix: 'web-mwb', rulesetFile: 'web-mwb.json', isKjv: false },
]) {
  const cat = build(cfg);
  const file = path.join(outDir, `${cfg.prefix}.catalogue.json`);
  fs.writeFileSync(file, JSON.stringify(cat) + '\n');
  const counts = {};
  let verses = 0;
  for (const b of cat.books) for (const ch of b.chapters) for (const code of ch) {
    verses++;
    const k = CLASSES[Math.floor(code / 100)][0];
    counts[k] = (counts[k] || 0) + 1;
  }
  const modes = {};
  for (const p of cat.proposals) modes[p.presentationMode] = (modes[p.presentationMode] || 0) + 1;
  console.log(`${cfg.targetVersionId}: ${verses} verses`, counts, 'proposals', modes, `${(fs.statSync(file).size / 1024).toFixed(0)} KB`);
}
