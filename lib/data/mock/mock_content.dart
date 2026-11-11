import '../models/content.dart';
import '../models/scripture_reference.dart';

/// Sample media. The audio file is an original generated tone used as a
/// stand-in for message recordings; no sermon recordings are bundled.
const sampleAudioAsset = 'assets/audio/sample_reflection_tone.wav';

const _audioMedia = MediaSource(kind: MediaSourceKind.asset, uri: sampleAudioAsset, isSampleStandIn: true);

List<ScriptureReference> _r(List<String> refs) => refs.map(ScriptureReference.parseCompact).toList();

int _mmss(String s) {
  final p = s.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

ContentItem _audio(
  String id,
  String title,
  String description,
  String creator,
  List<String> topics,
  List<String> refs,
  String duration,
  String date, {
  int tone = 0,
  bool featured = false,
  String? sourceVideo,
  EngagementStats stats = const EngagementStats(views: 2400, saves: 310, shares: 85, amens: 640),
}) => ContentItem(
  id: id,
  type: ContentType.audio,
  title: title,
  description: description,
  creatorId: creator,
  topicIds: topics,
  scriptureRefs: _r(refs),
  durationSeconds: _mmss(duration),
  publishedAt: DateTime.parse(date),
  artwork: ContentArtwork(tone: tone, motif: ArtworkMotif.arcs),
  media: _audioMedia,
  isFeatured: featured,
  sourceContentId: sourceVideo,
  engagement: stats,
);

ContentItem _video(
  String id,
  String title,
  String description,
  String creator,
  List<String> topics,
  List<String> refs,
  String duration,
  String date, {
  int tone = 1,
  bool featured = false,
  EngagementStats stats = const EngagementStats(views: 5100, saves: 420, shares: 210, amens: 1180),
}) => ContentItem(
  id: id,
  type: ContentType.video,
  title: title,
  description: description,
  creatorId: creator,
  topicIds: topics,
  scriptureRefs: _r(refs),
  durationSeconds: _mmss(duration),
  publishedAt: DateTime.parse(date),
  artwork: ContentArtwork(tone: tone, motif: ArtworkMotif.rays),
  isFeatured: featured,
  engagement: stats,
);

ContentItem _article(
  String id,
  String title,
  String description,
  String creator,
  List<String> topics,
  List<String> refs,
  String date,
  String body, {
  int tone = 2,
  bool featured = false,
}) => ContentItem(
  id: id,
  type: ContentType.article,
  title: title,
  description: description,
  creatorId: creator,
  topicIds: topics,
  scriptureRefs: _r(refs),
  durationSeconds: (body.split(' ').length / 200 * 60).round(),
  publishedAt: DateTime.parse(date),
  artwork: ContentArtwork(tone: tone, motif: ArtworkMotif.lines),
  isFeatured: featured,
  body: body,
  engagement: const EngagementStats(views: 1800, saves: 290, shares: 120, amens: 410),
);

ContentItem _scripture(
  String id,
  String title,
  String description,
  List<String> topics,
  List<String> refs,
  String date, {
  int tone = 3,
}) => ContentItem(
  id: id,
  type: ContentType.scriptureReference,
  title: title,
  description: description,
  creatorId: 'mwb-editorial',
  topicIds: topics,
  scriptureRefs: _r(refs),
  publishedAt: DateTime.parse(date),
  artwork: ContentArtwork(tone: tone, motif: ArtworkMotif.grid),
  engagement: const EngagementStats(views: 3200, saves: 980, shares: 450, amens: 1500),
);

/// Illustrative sample content. Titles and descriptions are original
/// placeholder copy written for Foundation V1.
final List<ContentItem> mockContent = [
  // ── Fear ──────────────────────────────────────────────────────────────
  _audio(
    'a-fear-night',
    'When Fear Knocks at Night',
    'A pastoral message on bringing fear to God when the house is quiet and thoughts are loud, drawing on David’s confidence in Psalm 56.',
    'daniel-mensah',
    ['fear', 'trusting-god', 'anxiety'],
    ['PSA 56:3', 'ISA 41:10'],
    '32:10',
    '2026-11-02',
    tone: 0,
    featured: true,
    stats: const EngagementStats(views: 8400, saves: 1260, shares: 330, amens: 2900),
  ),
  _video(
    'v-fear-courage',
    'Courage for the Next Step',
    'A short excerpt on God’s command to Joshua to be strong and courageous, and what it means for decisions you are facing.',
    'grace-hall',
    ['fear', 'courage', 'faith'],
    ['JOS 1:9'],
    '2:45',
    '2026-10-28',
    tone: 1,
    featured: true,
  ),
  _article(
    'ar-fear-promises',
    'Five Promises for Anxious Days',
    'A short guide to five passages believers have returned to in seasons of fear and worry.',
    'mwb-editorial',
    ['fear', 'anxiety', 'trusting-god'],
    ['PHP 4:6-7', '1PE 5:7', 'ISA 41:10', 'PSA 23:4', 'JHN 14:27'],
    '2026-10-21',
    'Fear rarely announces itself politely. It arrives as a racing thought, a tight chest, a question about tomorrow that will not go away. Scripture does not pretend that fear is unreal, but it repeatedly places fear beside the presence of God.\n\n'
        'Begin with Philippians 4:6–7. Paul invites believers to bring everything to God in prayer, with thanksgiving, and describes a peace that guards the heart and mind.\n\n'
        'Read 1 Peter 5:7 slowly. The invitation is personal: the One who cares for you asks you to place your cares on Him.\n\n'
        'Isaiah 41:10 speaks to the fear of being alone. God promises His presence, His strength and His help.\n\n'
        'Psalm 23:4 does not promise that the valley will be avoided. It promises company within it.\n\n'
        'Finally, John 14:27 records Jesus giving His own peace to His disciples, a peace different from the world’s.\n\n'
        'Choose one of these passages today. Read it in the Bible tab, save it to your library, and return to it whenever fear knocks.',
    featured: true,
  ),
  _video(
    'v-fear-love',
    'Perfect Love and the End of Fear',
    'An excerpt exploring 1 John 4:18 and how God’s love changes the way we face punishment, failure and the future.',
    'samuel-reed',
    ['fear', 'love'],
    ['1JN 4:18'],
    '3:20',
    '2026-10-15',
    tone: 4,
  ),
  _audio(
    'a-fear-love-audio',
    'Perfect Love Casts Out Fear (Audio)',
    'The full audio of Samuel Reed’s message, extracted from the video excerpt, for listening on the move.',
    'samuel-reed',
    ['fear', 'love'],
    ['1JN 4:18', 'ROM 8:38-39'],
    '24:30',
    '2026-10-15',
    tone: 4,
    sourceVideo: 'v-fear-love',
  ),
  _scripture(
    's-fear-sound-mind',
    'A Spirit of Power, Love and a Sound Mind',
    'Paul’s encouragement to Timothy: fear is not the spirit God has given.',
    ['fear', 'courage'],
    ['2TI 1:7'],
    '2026-10-10',
  ),
  // ── Faith ─────────────────────────────────────────────────────────────
  _audio(
    'a-faith-hears',
    'Faith That Hears',
    'How faith grows through hearing the Word of God, and practical ways to make Scripture part of every day.',
    'grace-hall',
    ['faith', 'knowing-god', 'spiritual-growth'],
    ['ROM 10:17', 'HEB 11:1'],
    '28:00',
    '2026-11-05',
    tone: 2,
    featured: true,
  ),
  _video(
    'v-faith-monday',
    'What Faith Looks Like on Monday',
    'A brief message on living by faith at work, at home and in ordinary routines.',
    'living-water',
    ['faith', 'christian-living'],
    ['2CO 5:7', 'JAS 2:17'],
    '1:58',
    '2026-11-01',
    tone: 5,
  ),
  _article(
    'ar-faith-sight',
    'Walking by Faith, Not by Sight',
    'Reflections on 2 Corinthians 5:7 and Hebrews 11 for seasons when the outcome is unclear.',
    'samuel-reed',
    ['faith', 'trusting-god'],
    ['2CO 5:7', 'HEB 11:1', 'HEB 11:8'],
    '2026-10-24',
    'Hebrews 11 is sometimes called a hall of faith, yet many of the people it describes did not see the full outcome of what they believed. Abraham went out not knowing where he was going. Faith, in this chapter, is less about certainty of circumstances and more about confidence in God.\n\n'
        'Paul summarises the posture in 2 Corinthians 5:7: we walk by faith, not by sight. Walking implies movement. Faith is not waiting until every question is answered; it is taking the next obedient step while trusting the One who sees the whole road.\n\n'
        'Consider one area of your life where sight is limited right now. Read Hebrews 11 this week and notice how often the phrase “by faith” is followed by an action. Ask God for the next step, not the whole map.',
  ),
  // ── Prayer ────────────────────────────────────────────────────────────
  _audio(
    'a-prayer-lords',
    'Learning to Pray the Lord’s Prayer',
    'A guided teaching through each line of the prayer Jesus taught His disciples.',
    'ruth-adeyemi',
    ['prayer', 'knowing-god'],
    ['MAT 6:9-13'],
    '35:20',
    '2026-11-07',
    tone: 3,
    featured: true,
    stats: const EngagementStats(views: 6900, saves: 1410, shares: 260, amens: 2100),
  ),
  _video(
    'v-prayer-ceasing',
    'Praying Without Ceasing',
    'A short encouragement on turning ordinary moments into conversation with God.',
    'ruth-adeyemi',
    ['prayer', 'spiritual-growth'],
    ['1TH 5:16-18'],
    '2:30',
    '2026-10-30',
    tone: 3,
  ),
  _article(
    'ar-prayer-rhythm',
    'A Simple Rhythm for Daily Prayer',
    'A gentle structure for morning and evening prayer that fits into a busy day.',
    'mwb-editorial',
    ['prayer', 'christian-living'],
    ['PSA 5:3', 'MAT 6:6', 'PHP 4:6-7'],
    '2026-10-18',
    'Prayer does not need to be complicated to be real. Many believers find it helpful to begin with a simple rhythm and let it grow.\n\n'
        'Morning: read a short passage such as Psalm 5:3, thank God for one specific thing, and place the day before Him.\n\n'
        'Midday: pause for one minute. Following Jesus’ words in Matthew 6:6, find a quiet place, even if only for a moment, and speak to your Father honestly.\n\n'
        'Evening: review the day. Where did you notice God? What needs forgiveness? Bring your concerns to Him with thanksgiving, as Philippians 4:6–7 encourages.\n\n'
        'Consistency matters more than length. Start small, and let prayer become the place you return to.',
  ),
  // ── Fasting ───────────────────────────────────────────────────────────
  _audio(
    'a-fast-chosen',
    'The Fast That God Chooses',
    'A message on Isaiah 58: fasting that leads to justice, generosity and renewed closeness to God.',
    'daniel-mensah',
    ['fasting', 'christian-living'],
    ['ISA 58:6-8'],
    '30:45',
    '2026-10-26',
    tone: 1,
  ),
  _article(
    'ar-fast-prepare',
    'Preparing Your Heart for a Fast',
    'Practical and spiritual preparation for a season of fasting, with a note on health.',
    'ruth-adeyemi',
    ['fasting', 'prayer'],
    ['MAT 6:16-18', 'JOL 2:12'],
    '2026-10-12',
    'Jesus spoke about fasting as an expected part of devotion, saying “when ye fast” in Matthew 6:16–18, and He taught that it should be done before the Father rather than for the approval of others.\n\n'
        'Before you begin, decide on a purpose. Joel 2:12 calls God’s people to return to Him with all their heart. A fast is a season of returning: setting aside something ordinary to give focused attention to God.\n\n'
        'Plan the practical details. Choose what you will set aside and for how long. Replace that time with prayer and Scripture reading.\n\n'
        'A note on health: if you are pregnant, managing a medical condition or taking medication, speak with a qualified health professional before fasting from food. Many believers fast from media, entertainment or specific foods instead.',
  ),
  // ── Favour ────────────────────────────────────────────────────────────
  _video(
    'v-favour-growing',
    'Growing in Favour',
    'An excerpt on Luke 2:52 and growing in wisdom and favour with God and people.',
    'living-water',
    ['favour', 'wisdom', 'purpose'],
    ['LUK 2:52'],
    '2:10',
    '2026-10-20',
    tone: 0,
  ),
  _audio(
    'a-favour-shield',
    'The Shield of Favour',
    'Teaching from Psalm 5:12 on God’s favour surrounding the righteous.',
    'grace-hall',
    ['favour', 'faith'],
    ['PSA 5:12', 'NUM 6:24-26'],
    '26:15',
    '2026-10-08',
    tone: 2,
  ),
  // ── Wealth & money ────────────────────────────────────────────────────
  _audio(
    'a-money-little',
    'Faithful in Little',
    'A message on faithfulness with money as a reflection of a faithful heart.',
    'samuel-reed',
    ['money', 'wealth', 'christian-living'],
    ['LUK 16:10-11'],
    '29:40',
    '2026-10-29',
    tone: 5,
  ),
  _video(
    'v-money-content',
    'Contentment and Money',
    'A short excerpt on Hebrews 13:5 and finding contentment in God’s presence.',
    'daniel-mensah',
    ['money', 'trusting-god'],
    ['HEB 13:5'],
    '2:55',
    '2026-10-17',
    tone: 2,
  ),
  _article(
    'ar-wealth-stewardship',
    'Stewardship: Wealth with Purpose',
    'What Scripture teaches about the source and purpose of wealth.',
    'mwb-editorial',
    ['wealth', 'money', 'purpose'],
    ['DEU 8:18', '1TI 6:17-19', 'MAT 6:19-21'],
    '2026-10-05',
    'Deuteronomy 8:18 reminds Israel that it is God who gives the power to get wealth. Scripture consistently treats resources as something received and entrusted, not simply earned and owned.\n\n'
        'In 1 Timothy 6:17–19, Paul gives instructions to those who are rich: do not be high-minded, do not trust in uncertain riches, but trust in God, be rich in good works and ready to share.\n\n'
        'Jesus, in Matthew 6:19–21, connects treasure and the heart. Where our treasure goes, our heart follows.\n\n'
        'Stewardship asks a simple question of every resource: what is this for? Consider one financial decision this week and bring it before God in prayer.',
  ),
  // ── Wisdom ────────────────────────────────────────────────────────────
  _audio(
    'a-wisdom-ask',
    'Asking God for Wisdom',
    'Teaching from James 1:5 on the generosity of God toward those who ask for wisdom.',
    'grace-hall',
    ['wisdom', 'prayer', 'leadership'],
    ['JAS 1:5', 'PRO 2:6'],
    '22:05',
    '2026-11-03',
    tone: 4,
  ),
  _scripture(
    's-wisdom-beginning',
    'The Beginning of Wisdom',
    'Proverbs places wisdom’s starting point in the fear of the LORD.',
    ['wisdom', 'knowing-god'],
    ['PRO 9:10', 'PRO 4:7'],
    '2026-09-30',
    tone: 0,
  ),
  // ── Love & forgiveness ────────────────────────────────────────────────
  _video(
    'v-love-patient',
    'Love Is Patient',
    'A reflective reading and short message on 1 Corinthians 13.',
    'selah-studio',
    ['love', 'family', 'christian-living'],
    ['1CO 13:4-7'],
    '3:05',
    '2026-11-04',
    tone: 6,
    featured: true,
  ),
  _audio(
    'a-love-separate',
    'Nothing Can Separate Us',
    'A quiet reflection on Romans 8 and the security of God’s love.',
    'selah-studio',
    ['love', 'fear', 'knowing-god'],
    ['ROM 8:38-39'],
    '12:30',
    '2026-10-22',
    tone: 6,
  ),
  _audio(
    'a-forgive-forgiven',
    'Forgiving as We Have Been Forgiven',
    'A pastoral message on Ephesians 4:32 and the costly, freeing work of forgiveness.',
    'daniel-mensah',
    ['forgiveness', 'love', 'family'],
    ['EPH 4:32', 'COL 3:13'],
    '31:00',
    '2026-10-11',
    tone: 3,
  ),
  _video(
    'v-forgive-east',
    'As Far as the East Is from the West',
    'A short reflection on Psalm 103:12 and the completeness of God’s forgiveness.',
    'selah-studio',
    ['forgiveness', 'knowing-god'],
    ['PSA 103:12', '1JN 1:9'],
    '2:20',
    '2026-09-27',
    tone: 5,
  ),
  // ── Knowing God & growth ──────────────────────────────────────────────
  _audio(
    'a-know-still',
    'Be Still and Know',
    'A guided reflection on Psalm 46:10 for moments of stillness before God.',
    'selah-studio',
    ['knowing-god', 'prayer', 'anxiety'],
    ['PSA 46:10'],
    '15:00',
    '2026-11-06',
    tone: 2,
  ),
  _article(
    'ar-know-word',
    'Knowing God Through His Word',
    'Why reading Scripture is central to knowing God, not only knowing about Him.',
    'samuel-reed',
    ['knowing-god', 'spiritual-growth'],
    ['JHN 17:3', 'JER 9:23-24'],
    '2026-10-02',
    'In John 17:3, Jesus describes eternal life in relational terms: to know the only true God and Jesus Christ whom He has sent. Knowing God is not a supplement to the Christian life; it is its heart.\n\n'
        'Jeremiah 9:23–24 sets this knowledge above wisdom, strength and riches. The one who boasts should boast that he understands and knows the LORD.\n\n'
        'Scripture is where God has chosen to reveal His character. As you read, ask three questions: What does this passage show me about God? What does it show me about people? How should I respond?\n\n'
        'Over time, these small encounters become a deep familiarity with the One who speaks through His Word.',
  ),
  _audio(
    'a-growth-rooted',
    'Rooted and Built Up',
    'Teaching from Colossians 2 on growing steadily in Christ.',
    'grace-hall',
    ['spiritual-growth', 'faith'],
    ['COL 2:6-7', '2PE 3:18'],
    '25:10',
    '2026-10-19',
    tone: 1,
  ),
  // ── Purpose ───────────────────────────────────────────────────────────
  _video(
    'v-purpose-works',
    'Created for Good Works',
    'An excerpt on Ephesians 2:10 and the purpose God has prepared for His people.',
    'grace-hall',
    ['purpose', 'christian-living'],
    ['EPH 2:10'],
    '2:40',
    '2026-11-08',
    tone: 0,
  ),
  _audio(
    'a-purpose-plans',
    'Plans of Peace',
    'A message on Jeremiah 29:11 read in its full context of exile and hope.',
    'living-water',
    ['purpose', 'trusting-god', 'fear'],
    ['JER 29:11', 'ROM 8:28'],
    '27:30',
    '2026-10-25',
    tone: 4,
  ),
  // ── Christian living ──────────────────────────────────────────────────
  _video(
    'v-living-sacrifice',
    'A Living Sacrifice',
    'A short message on Romans 12:1–2 and offering everyday life to God.',
    'daniel-mensah',
    ['christian-living', 'spiritual-growth'],
    ['ROM 12:1-2'],
    '2:50',
    '2026-10-14',
    tone: 3,
  ),
  _article(
    'ar-living-mercy',
    'Do Justly, Love Mercy, Walk Humbly',
    'Micah 6:8 as a compact summary of a faithful life.',
    'mwb-editorial',
    ['christian-living', 'leadership'],
    ['MIC 6:8', 'COL 3:17'],
    '2026-09-25',
    'Micah 6:8 answers a question many believers ask: what does the LORD require? The answer has three parts: to do justly, to love mercy, and to walk humbly with God.\n\n'
        'Doing justly concerns how we treat others in work, family and community. Loving mercy goes beyond fairness to kindness. Walking humbly keeps the whole life oriented toward God.\n\n'
        'Colossians 3:17 adds that whatever we do, in word or deed, can be done in the name of the Lord Jesus, giving thanks. Choose one of Micah’s three phrases and practise it intentionally this week.',
  ),
  // ── Family ────────────────────────────────────────────────────────────
  _audio(
    'a-family-house',
    'As for Me and My House',
    'A message on Joshua 24:15 and building a home that chooses to serve the LORD.',
    'living-water',
    ['family', 'christian-living'],
    ['JOS 24:15', 'PSA 127:1'],
    '33:00',
    '2026-10-09',
    tone: 5,
  ),
  _video(
    'v-family-children',
    'Training Children in the Way',
    'Practical encouragement for parents from Proverbs 22:6 and Ephesians 6.',
    'ruth-adeyemi',
    ['family'],
    ['PRO 22:6', 'EPH 6:4'],
    '2:35',
    '2026-09-29',
    tone: 2,
  ),
  // ── Leadership ────────────────────────────────────────────────────────
  _audio(
    'a-lead-servant',
    'Servant Leadership',
    'Teaching from Mark 10 on greatness through service.',
    'samuel-reed',
    ['leadership', 'christian-living'],
    ['MRK 10:43-45'],
    '26:45',
    '2026-10-06',
    tone: 0,
  ),
  _video(
    'v-lead-humility',
    'Leading with Humility',
    'A short excerpt on Philippians 2:3–4 for those who lead at work, at church or at home.',
    'living-water',
    ['leadership', 'wisdom'],
    ['PHP 2:3-4'],
    '2:15',
    '2026-09-24',
    tone: 6,
  ),
];
