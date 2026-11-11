/// Canonical book metadata independent of any translation.
///
/// IDs follow the widely used USFM/OSIS three-character convention so that
/// references stay stable across translations and future backend data.
enum Testament { oldTestament, newTestament }

class CanonBook {
  const CanonBook(this.id, this.name, this.testament, this.chapterCount, [this.aliases = const []]);

  final String id;
  final String name;
  final Testament testament;
  final int chapterCount;
  final List<String> aliases;

  bool get isOld => testament == Testament.oldTestament;
}

abstract final class BibleCanon {
  static const _ot = Testament.oldTestament;
  static const _nt = Testament.newTestament;

  static const books = <CanonBook>[
    CanonBook('GEN', 'Genesis', _ot, 50, ['gen', 'gn', 'ge']),
    CanonBook('EXO', 'Exodus', _ot, 40, ['exo', 'ex', 'exod']),
    CanonBook('LEV', 'Leviticus', _ot, 27, ['lev', 'lv', 'le']),
    CanonBook('NUM', 'Numbers', _ot, 36, ['num', 'nm', 'nu']),
    CanonBook('DEU', 'Deuteronomy', _ot, 34, ['deu', 'deut', 'dt']),
    CanonBook('JOS', 'Joshua', _ot, 24, ['josh', 'jos', 'jsh']),
    CanonBook('JDG', 'Judges', _ot, 21, ['judg', 'jdg', 'jg']),
    CanonBook('RUT', 'Ruth', _ot, 4, ['ruth', 'rut', 'ru']),
    CanonBook('1SA', '1 Samuel', _ot, 31, ['1sam', '1sa', 'isamuel', 'firstsamuel']),
    CanonBook('2SA', '2 Samuel', _ot, 24, ['2sam', '2sa', 'iisamuel', 'secondsamuel']),
    CanonBook('1KI', '1 Kings', _ot, 22, ['1kgs', '1ki', 'ikings', 'firstkings']),
    CanonBook('2KI', '2 Kings', _ot, 25, ['2kgs', '2ki', 'iikings', 'secondkings']),
    CanonBook('1CH', '1 Chronicles', _ot, 29, ['1chr', '1ch', 'firstchronicles']),
    CanonBook('2CH', '2 Chronicles', _ot, 36, ['2chr', '2ch', 'secondchronicles']),
    CanonBook('EZR', 'Ezra', _ot, 10, ['ezra', 'ezr']),
    CanonBook('NEH', 'Nehemiah', _ot, 13, ['neh', 'ne']),
    CanonBook('EST', 'Esther', _ot, 10, ['esth', 'est', 'es']),
    CanonBook('JOB', 'Job', _ot, 42, ['job', 'jb']),
    CanonBook('PSA', 'Psalms', _ot, 150, ['psalm', 'ps', 'psa', 'pss', 'psalms']),
    CanonBook('PRO', 'Proverbs', _ot, 31, ['prov', 'pro', 'prv', 'pr']),
    CanonBook('ECC', 'Ecclesiastes', _ot, 12, ['eccl', 'ecc', 'ec', 'qoh']),
    CanonBook('SNG', 'Song of Solomon', _ot, 8, ['song', 'sos', 'sng', 'songofsongs', 'canticles']),
    CanonBook('ISA', 'Isaiah', _ot, 66, ['isa', 'is']),
    CanonBook('JER', 'Jeremiah', _ot, 52, ['jer', 'je', 'jr']),
    CanonBook('LAM', 'Lamentations', _ot, 5, ['lam', 'la']),
    CanonBook('EZK', 'Ezekiel', _ot, 48, ['ezek', 'eze', 'ezk']),
    CanonBook('DAN', 'Daniel', _ot, 12, ['dan', 'da', 'dn']),
    CanonBook('HOS', 'Hosea', _ot, 14, ['hos', 'ho']),
    CanonBook('JOL', 'Joel', _ot, 3, ['joel', 'jl', 'jol']),
    CanonBook('AMO', 'Amos', _ot, 9, ['amos', 'am', 'amo']),
    CanonBook('OBA', 'Obadiah', _ot, 1, ['obad', 'ob', 'oba']),
    CanonBook('JON', 'Jonah', _ot, 4, ['jonah', 'jnh', 'jon']),
    CanonBook('MIC', 'Micah', _ot, 7, ['mic', 'mc']),
    CanonBook('NAM', 'Nahum', _ot, 3, ['nah', 'na', 'nam']),
    CanonBook('HAB', 'Habakkuk', _ot, 3, ['hab', 'hb']),
    CanonBook('ZEP', 'Zephaniah', _ot, 3, ['zeph', 'zep', 'zp']),
    CanonBook('HAG', 'Haggai', _ot, 2, ['hag', 'hg']),
    CanonBook('ZEC', 'Zechariah', _ot, 14, ['zech', 'zec', 'zc']),
    CanonBook('MAL', 'Malachi', _ot, 4, ['mal', 'ml']),
    CanonBook('MAT', 'Matthew', _nt, 28, ['matt', 'mat', 'mt']),
    CanonBook('MRK', 'Mark', _nt, 16, ['mark', 'mrk', 'mk', 'mr']),
    CanonBook('LUK', 'Luke', _nt, 24, ['luke', 'luk', 'lk']),
    CanonBook('JHN', 'John', _nt, 21, ['john', 'jhn', 'jn']),
    CanonBook('ACT', 'Acts', _nt, 28, ['acts', 'act', 'ac']),
    CanonBook('ROM', 'Romans', _nt, 16, ['rom', 'ro', 'rm']),
    CanonBook('1CO', '1 Corinthians', _nt, 16, ['1cor', '1co', 'firstcorinthians']),
    CanonBook('2CO', '2 Corinthians', _nt, 13, ['2cor', '2co', 'secondcorinthians']),
    CanonBook('GAL', 'Galatians', _nt, 6, ['gal', 'ga']),
    CanonBook('EPH', 'Ephesians', _nt, 6, ['eph', 'ephes']),
    CanonBook('PHP', 'Philippians', _nt, 4, ['phil', 'php', 'pp']),
    CanonBook('COL', 'Colossians', _nt, 4, ['col']),
    CanonBook('1TH', '1 Thessalonians', _nt, 5, ['1thess', '1th', 'firstthessalonians']),
    CanonBook('2TH', '2 Thessalonians', _nt, 3, ['2thess', '2th', 'secondthessalonians']),
    CanonBook('1TI', '1 Timothy', _nt, 6, ['1tim', '1ti', 'firsttimothy']),
    CanonBook('2TI', '2 Timothy', _nt, 4, ['2tim', '2ti', 'secondtimothy']),
    CanonBook('TIT', 'Titus', _nt, 3, ['titus', 'tit']),
    CanonBook('PHM', 'Philemon', _nt, 1, ['philem', 'phm', 'phlm']),
    CanonBook('HEB', 'Hebrews', _nt, 13, ['heb']),
    CanonBook('JAS', 'James', _nt, 5, ['jas', 'jm']),
    CanonBook('1PE', '1 Peter', _nt, 5, ['1pet', '1pe', '1pt', 'firstpeter']),
    CanonBook('2PE', '2 Peter', _nt, 3, ['2pet', '2pe', '2pt', 'secondpeter']),
    CanonBook('1JN', '1 John', _nt, 5, ['1john', '1jn', '1jo', 'firstjohn']),
    CanonBook('2JN', '2 John', _nt, 1, ['2john', '2jn', '2jo', 'secondjohn']),
    CanonBook('3JN', '3 John', _nt, 1, ['3john', '3jn', '3jo', 'thirdjohn']),
    CanonBook('JUD', 'Jude', _nt, 1, ['jude', 'jud', 'jd']),
    CanonBook('REV', 'Revelation', _nt, 22, ['rev', 're', 'revelations', 'apocalypse']),
  ];

  static final Map<String, CanonBook> _byId = {for (final b in books) b.id: b};

  static final Map<String, CanonBook> _byAlias = () {
    final map = <String, CanonBook>{};
    for (final b in books) {
      map[_normalise(b.name)] = b;
      map[b.id.toLowerCase()] = b;
      for (final a in b.aliases) {
        map[_normalise(a)] = b;
      }
    }
    return map;
  }();

  static CanonBook? byId(String id) => _byId[id.toUpperCase()];

  static CanonBook bookOrThrow(String id) => byId(id) ?? (throw ArgumentError.value(id, 'id', 'Unknown book'));

  static int indexOf(String id) => books.indexWhere((b) => b.id == id);

  static List<CanonBook> get oldTestament => books.where((b) => b.isOld).toList();
  static List<CanonBook> get newTestament => books.where((b) => !b.isOld).toList();

  static String _normalise(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s.]'), '');

  /// Resolves a user-typed book name ("1 cor", "psalm", "Jn").
  /// Falls back to a unique prefix match of at least three characters.
  static CanonBook? matchBook(String input) {
    final key = _normalise(input);
    if (key.isEmpty) return null;
    final exact = _byAlias[key];
    if (exact != null) return exact;
    if (key.length < 3) return null;
    final candidates = books.where((b) => _normalise(b.name).startsWith(key)).toList();
    return candidates.length == 1 ? candidates.first : null;
  }
}
