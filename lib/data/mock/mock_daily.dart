import '../models/scripture_reference.dart';

/// Curated references for "Daily Scripture". Text is always loaded from the
/// installed translation; only the reference is curated here.
final List<ScriptureReference> dailyScriptureRefs = [
  'PSA 23:1',
  'ISA 41:10',
  'JHN 3:16',
  'PHP 4:13',
  'PRO 3:5-6',
  'JER 29:11',
  'ROM 8:28',
  'JOS 1:9',
  'PSA 46:1',
  'MAT 11:28',
  '2CO 5:17',
  'LAM 3:22-23',
  'ISA 40:31',
  'PSA 121:1-2',
  'ROM 15:13',
  'PSA 119:105',
  'GAL 2:20',
  'HEB 4:16',
  'PSA 34:8',
  'JHN 14:27',
  'COL 3:23',
].map(ScriptureReference.parseCompact).toList();

/// A promise of Scripture paired with a personal declaration.
///
/// The declaration is MWB's devotional response written in the first person;
/// it is displayed separately from, and never mixed into, the Scripture text.
class DailyPromise {
  const DailyPromise(this.reference, this.declaration);
  final ScriptureReference reference;
  final String declaration;
}

final List<DailyPromise> dailyPromises = [
  DailyPromise(
    ScriptureReference.parseCompact('ISA 41:10'),
    'Today I will not be dismayed. God is with me, strengthening me and holding me up.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('PHP 4:19'),
    'I trust God to supply what I need today, according to His riches in Christ Jesus.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('DEU 31:8'),
    'God goes before me today. I will not fear, and I will not be discouraged.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('PSA 32:8'),
    'I am listening for God’s guidance. He will teach me the way I should go.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('ISA 43:2'),
    'Whatever I pass through today, I do not pass through alone.',
  ),
  DailyPromise(ScriptureReference.parseCompact('MAT 28:20'), 'Christ is with me always, in every hour of this day.'),
  DailyPromise(
    ScriptureReference.parseCompact('2CO 12:9'),
    'His grace is sufficient for me. In my weakness, His strength is made perfect.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('JAS 1:5'),
    'I will ask God for wisdom today, and I trust Him to give it generously.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('PSA 91:11'),
    'I rest in God’s care. He watches over me in all my ways.',
  ),
  DailyPromise(
    ScriptureReference.parseCompact('1JN 1:9'),
    'I bring my failings to God honestly, and I receive His forgiveness and cleansing.',
  ),
];

/// Deterministic daily selection so the same item shows all day.
int dayIndex(DateTime date, int length) {
  final start = DateTime(date.year);
  final day = date.difference(start).inDays;
  return (date.year * 7 + day) % length;
}
