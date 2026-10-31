/// Splits pre-processed text into Hausa and English runs so the hybrid voice
/// pipeline can route each run to the right engine.
///
/// Why this exists: the Murya Hausa model reads Hausa beautifully but ruins
/// English brand/drug names; the Android device voice reads English cleanly but
/// has no Hausa phonology. So `"...fesa mancozeb a gonar albasa..."` becomes:
///
/// ```text
/// [Hausa]   "fesa mankozeb"      -> MuryaTtsEngine   (after loanword pass this
///                                 becomes Hausa phonetics anyway)
/// [English] "Emamectin benzoate" -> SystemTtsEngine
/// [Hausa]   "a gonar albasa"     -> MuryaTtsEngine
/// ```
library;

enum ChunkLanguage { hausa, english }

class TtsChunk {
  const TtsChunk({required this.text, required this.language});

  final String text;
  final ChunkLanguage language;

  bool get isHausa => language == ChunkLanguage.hausa;

  @override
  String toString() => '${language.name}: "$text"';
}

class TtsChunker {
  const TtsChunker._();

  /// High-frequency Hausa vocabulary. Anything in this list is *never* treated
  /// as English, so the chunker cannot accidentally hand a Hausa sentence to
  /// the English device voice.
  static const Set<String> hausaLexicon = <String>{
    // function words / particles
    'a', 'an', 'abin', 'abinda', 'abubuwa', 'ai', 'ajiya', 'akalla', 'akai',
    'akwai', 'alama', 'alamomi', 'alamar', 'amma', 'amfani', 'amfanin', 'ana',
    'anyi', 'asar', 'ashi', 'au', 'ayyuka', 'ba', 'baba', 'babu', 'bai',
    'baka', 'ban', 'bana', 'bari', 'bashi', 'bayan', 'bazai', 'biyu',
    'bokiti', 'ciki', 'cikin', 'ciwon', 'ciwo', 'cutar', 'cuta', 'cututtuka',
    'cututtukan', 'da', 'dabbobi', 'dabba', 'daga', 'dai', 'dakin', 'dama',
    'damina', 'datti', 'daya', 'digo', 'digiri', 'dole', 'don', 'duba',
    'dubawa', 'duka', 'duk', 'dumi', 'fari', 'farin', 'fata', 'feshe', 'fesa',
    'fito', 'fitar', 'gaba', 'gabaki', 'ganye', 'ganyen', 'gari', 'gaskiya',
    'gida', 'girbi', 'girbin', 'gishiri', 'gona', 'gonar', 'gonaki', 'gwada',
    'gwanin', 'habitacin', 'hada', 'haka', 'hannu', 'hanya', 'hanyar', 'har',
    'harshe', 'hatsari', 'hoto', 'hoton', 'huta', 'idan', 'ido', 'idona',
    'in', 'inka', 'iri', 'irin', 'iska', 'iya', 'iyali', 'jiki', 'jikin',
    'jini', 'ka', 'kada', 'kafin', 'kafa', 'kai', 'kama', 'kamu', 'kan',
    'kana', 'kanka', 'karin', 'kasa', 'kashi', 'kashe', 'kawai', 'kayanta',
    'kaza', 'kebewa', 'kila', 'kina', 'koda', 'koma', 'koren', 'kore', 'kowa',
    'kowane', 'ku', 'kuma', 'kumburi', 'kwana', 'kwanaki', 'kwaya',
    'kwayoyin', 'kwari', 'kyau', 'kyakkyawan', 'lafiya', 'lafiyar', 'laima',
    'laka', 'littafi', 'lokaci', 'lokacin', 'lura', 'ma', 'mabukaci',
    'maganin', 'magani', 'mai', 'maka', 'makonni', 'mako', 'mana', 'manoma',
    'manomi', 'masara', 'mataki', 'mata', 'matsala', 'matsalar', 'matsayi',
    'muna', 'mutane', 'mutum', 'na', 'nan', 'nawa', 'nemi', 'neman', 'ne',
    'ni', 'nisa', 'no', 'noma', 'noman', 'nomi', 'numfashi', 'nuna', 'ranar',
    'rana', 'rani', 'rashin', 'ruwa', 'ruwan', 'saboda', 'saida', 'sai',
    'sake', 'sakamakon', 'sannu', 'sanyi', 'sauran', 'saurara', 'saurari',
    'sauka', 'shafi', 'shanya', 'shayarwa', 'shi', 'shida', 'shirin', 'shuka',
    'shukar', 'shuke', 'shukeshuke', 'sosai', 'su', 'suka', 'suna', 'tace',
    'tafasa', 'tafi', 'tambaya', 'tambayi', 'tare', 'tarin', 'tashi', 'taso',
    'tattara', 'taya', 'ta', 'tabbatar', 'tambarin', 'tambura', 'tana',
    'tane', 'taswira', 'tayi', 'to', 'tsabta', 'tsafta', 'tsarin', 'tsire',
    'tsuntsaye', 'tumatir', 'tuna', 'tura', 'tushen', 'uku', 'wani', 'wanne',
    'wannan', 'wanda', 'wata', 'watanni', 'waya', 'wurin', 'wuri', 'wuya',
    'ya', 'yake', 'yana', 'yanayi', 'yanayin', 'yankin', 'yara', 'yawan',
    'yi', 'yin', 'yiyuwa', 'yau', 'zai', 'zaka', 'zama', 'zamu', 'zazzabi',
    'zuba', 'zuciya',
    // domain nouns used across the app
    'albasa', 'masarar', 'dawa', 'gero', 'shinkafa', 'wake', 'waken', 'rogo',
    'doya', 'alkama', 'tumaki', 'tunkiya', 'akuya', 'awaki', 'saniya',
    'shanu', 'rago', 'kaji', 'agwagwa', 'alade', 'jaki', 'rakumi', 'kwai',
    'kwakwalwa', 'nama', 'madara', 'nonon', 'tsutsa', 'tsutsotsi', 'kwarin',
    'gado', 'gadon', 'kunya', 'kwararo', 'taki', 'takoki', 'takin', 'toka',
    'kasar', 'yashi', 'sinadaran', 'sinadari', 'ph', 'pii', 'daci', 'tsami',
    'alkali', 'kwalba', 'kwalabe', 'renda', 'randa', 'jarka', 'rijiya',
    'rijiyar', 'kogi', 'korama', 'madatsar', 'hazo', 'hazonta', 'sama', 'sha',
    'bulala', 'magudanan', 'magudanar', 'kariya', 'rigakafi', 'jinya', 'kula',
    'kulawa', 'bincike', 'binciken', 'gargadi', 'sanarwa', 'sakon', 'sako',
    'taimako', 'taimakon', 'agaji', 'gaggawa', 'hadari', 'hadarin',
    'musamman', 'misali', 'domin', 'dalilin', 'wajibi', 'dace', 'dacewa',
    'inganci', 'ingantaccen', 'kyakkyawa', 'karami', 'babba', 'mafi', 'yawa',
    'kadan', 'tsaye', 'zaune', 'kwance', 'gudu', 'zafi', 'bushe', 'busasshen',
    'danye', 'danyen', 'sabo', 'tsohon', 'sabon', 'tsawon', 'gajere',
    // genitive / plural forms met in the app's own Hausa copy. These are
    // written as `_core` sees them: hyphens are stripped, so the reduplicated
    // `shuke-shuke` is stored as `shukeshuke`.
    'ambaliyar', 'batutuwan', 'bakteriyar', 'farfadiya', 'hannaye',
    'laburaren', 'likitancin', 'magungunan', 'matsakaici', 'muhimmanci',
    'shawarwarin', 'sinadarin', 'tashoshin', 'almakashin',
  };

  /// Signals that a word is very likely English (and therefore should be read
  /// by the device voice rather than Murya).
  ///
  /// Everything here is evidence *for* English; [looksEnglish] weighs it
  /// against the Hausa evidence below and only switches voice when the English
  /// side wins outright. A tie stays Hausa on purpose: Murya is the primary
  /// voice, so an unknown word is given to it unless the English evidence is
  /// clear.
  static final RegExp _englishSuffix = RegExp(
    r'(tion|sion|ment|ness|able|ible|ance|ence|ous|ity|ical|ing|ism|ist|ive|ary|ery|ide|ine|ase|ate|ose|ole|ol|al|ic)$',
    caseSensitive: false,
  );

  static final RegExp _englishDigraph = RegExp(
    r'(ck|ph|wh|gh|th|oo|ee|ea|ou|ow|ai|ay|kn|wr|gn|mb|tch)',
    caseSensitive: false,
  );

  /// Consonant pairs that are a *single* sound in Hausa orthography, so the
  /// three-consonant test below does not fire on words such as `lankwasa`.
  static final RegExp _hausaDigraph = RegExp(
    r'sh|ts|kw|gw|ky|gy|ƙw',
    caseSensitive: false,
  );

  /// Hausa syllables are CV, so a run of three consonants (after collapsing
  /// [_hausaDigraph]) is a strong sign of a foreign word: `streptomycin`,
  /// `chlorothalonil`, `pendimethalin`.
  static final RegExp _longConsonantRun = RegExp(r'[bcdfghjklmnpqrstvwxyz]{3,}');

  /// Hausa genitive/linker endings carried by ordinary nouns:
  /// `magungunan`, `ambaliyar`, `sinadarin`, `tashoshin`.
  static final RegExp _hausaLinker = RegExp(
    r'(ar|war|yar|an|nan|nin|nka|nki|nmu|nsu|nta|nku)$',
  );

  /// Verbal endings (`-na`, `-ka`, `-ta`…). Only trusted on short words: on a
  /// long token they are coincidental, and they would otherwise cancel the
  /// English evidence for `atrazine` (`-ne`) or `emamectin` (`-in`).
  static final RegExp _hausaVerbalEnding = RegExp(r'(na|ka|ki|mu|su|ta|ne|ce)$');

  /// Longest word for which [_hausaVerbalEnding] is treated as meaningful.
  static const int _verbalEndingMaxLength = 7;

  static final RegExp _hausaHook = RegExp(r'[ɓɗƙƴ]');
  static final RegExp _nonWord = RegExp(
    r"[^A-Za-zÀ-ÖØ-öø-ÿɓƁɗƊƙƘƴƳ'’]",
    unicode: true,
  );

  static String _core(String token) =>
      token.replaceAll(_nonWord, '').toLowerCase();

  /// Heuristic: does [word] need the English device voice?
  static bool looksEnglish(String word) {
    final core = _core(word);
    if (core.isEmpty) return false;
    if (hausaLexicon.contains(core)) return false;
    if (_hausaHook.hasMatch(core)) return false;
    if (core.length <= 2) return false;

    var english = 0;
    var hausa = 0;

    if (_englishSuffix.hasMatch(core)) english += 2;
    if (_englishDigraph.hasMatch(core)) english += 1;
    if (RegExp('[xvq]').hasMatch(core)) english += 2;
    // `p` is absent from native Hausa phonology (loanwords only).
    if (core.contains('p')) english += 1;
    // Long, unfamiliar tokens are far more likely to be drug/brand names.
    // This is what separates `emamectin` from `magungunan`: the second one is
    // reclaimed below by its Hausa linker ending.
    if (core.length >= 9) english += 2;
    if (core.endsWith('s') && core.length > 3) english += 1;
    if (word.contains('-')) english += 1;

    final flattened = core.replaceAll(_hausaDigraph, 'C');
    if (_longConsonantRun.hasMatch(flattened)) english += 2;

    // Hausa orthography never doubles a consonant inside a stem.
    if (RegExp(r'(bb|dd|ff|gg|kk|ll|mm|nn|pp|rr|ss|tt|zz)').hasMatch(core)) {
      hausa -= 1;
    }
    // Hausa words very often end in a vowel or in -n/-r/-k.
    if (RegExp(r'[aeiou]$').hasMatch(core)) hausa += 1;
    if (RegExp(r'(n|r|k)$').hasMatch(core)) hausa += 1;
    // Ina / ana / -ka / -ki style verbal endings, on short words only.
    if (core.length <= _verbalEndingMaxLength &&
        _hausaVerbalEnding.hasMatch(core)) {
      hausa += 1;
    }
    // Genitive linker: `magungunan`, `ambaliyar`, `sinadarin`.
    if (_hausaLinker.hasMatch(core)) hausa += 2;

    return english > hausa;
  }

  /// Splits [text] into consecutive same-language runs.
  ///
  /// Punctuation stays attached to the preceding word so the TTS engine keeps
  /// its natural pauses.
  static List<TtsChunk> split(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const <TtsChunk>[];

    final tokens = trimmed.split(RegExp(r'\s+'));
    final chunks = <TtsChunk>[];
    final buffer = StringBuffer();
    ChunkLanguage? current;

    void flush() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty && current != null) {
        chunks.add(TtsChunk(text: value, language: current!));
      }
      buffer.clear();
    }

    for (final token in tokens) {
      final core = _core(token);
      if (core.isEmpty) {
        // Pure punctuation/emoji leftovers stay with the current run.
        if (buffer.isNotEmpty) buffer.write(' $token');
        continue;
      }
      final language =
          looksEnglish(token) ? ChunkLanguage.english : ChunkLanguage.hausa;
      if (current == null) {
        current = language;
      } else if (language != current) {
        flush();
        current = language;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(token);
    }
    flush();

    return chunks;
  }

  /// Ratio of English words in [text] (0.0 = pure Hausa, 1.0 = pure English).
  static double englishRatio(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    var total = 0;
    var english = 0;
    for (final token in tokens) {
      if (_core(token).isEmpty) continue;
      total++;
      if (looksEnglish(token)) english++;
    }
    return total == 0 ? 0 : english / total;
  }

  /// Longest run handed to Murya in a single request.
  ///
  /// Measured on the shipped INT8 graph: ~3 ms per token on one x86 thread, and
  /// a low-end Cortex-A53 phone is roughly 4-8x slower, so ~250 characters is
  /// where a request starts to approach the 2 s budget. Splitting here keeps
  /// every request inside the budget *and* lets playback start sooner.
  static const int maxCharsPerRequest = 250;

  /// Splits a Hausa run into pieces of at most [maxChars] characters.
  ///
  /// Order of preference: sentence boundary, then clause (comma/semicolon),
  /// then a plain word wrap. Everything is greedy, so the number of requests
  /// stays as low as possible. Public so the tests can pin the behaviour.
  static List<TtsChunk> splitForSynthesis(
    TtsChunk chunk, {
    int maxChars = maxCharsPerRequest,
  }) {
    final text = chunk.text.trim();
    if (text.length <= maxChars) return <TtsChunk>[chunk];

    final pieces = <String>[];
    final buffer = StringBuffer();

    void flush() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) pieces.add(value);
      buffer.clear();
    }

    void add(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      if (value.length > maxChars) {
        flush();
        pieces.addAll(_wrapWords(value, maxChars));
        return;
      }
      if (buffer.length > 0 && buffer.length + 1 + value.length > maxChars) {
        flush();
      }
      if (buffer.length > 0) buffer.write(' ');
      buffer.write(value);
    }

    // `.allMatches` keeps the terminator attached to its sentence so the split
    // does not silently swallow question marks.
    for (final match in RegExp(r'[^.!?]+[.!?]*').allMatches(text)) {
      final sentence = (match.group(0) ?? '').trim();
      if (sentence.isEmpty) continue;
      if (sentence.length <= maxChars) {
        add(sentence);
      } else {
        for (final clause in sentence.split(RegExp(r'[,;:]'))) {
          add(clause);
        }
      }
    }
    flush();

    return pieces
        .map((piece) => TtsChunk(text: piece, language: chunk.language))
        .toList(growable: false);
  }

  /// Last-resort wrap: never exceed [maxChars] even without punctuation.
  static List<String> _wrapWords(String text, int maxChars) {
    final lines = <String>[];
    final line = StringBuffer();
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (line.length > 0 && line.length + 1 + word.length > maxChars) {
        lines.add(line.toString());
        line.clear();
      }
      if (line.length > 0) line.write(' ');
      line.write(word);
    }
    if (line.length > 0) lines.add(line.toString());
    return lines;
  }
}
