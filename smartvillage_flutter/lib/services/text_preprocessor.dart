/// Hausa text pre-processor.
///
/// The Murya Hausa voice was trained on clean, phonetically-spelled Hausa text.
/// Feeding it raw app strings (digits, hyphens, emoji, English brand names)
/// produces mangled pronunciation, so every string sent to [MuryaTtsEngine]
/// first passes through this pipeline.
///
/// Pipeline order (identical to `src/utils/textPreprocessor.ts` in the React
/// blueprint):
///
/// 1. [expandNumbers]      — digits 0-10 -> Hausa number words.
/// 2. [removeHyphens]      — `dogon-yaro` -> `dogon yaro`.
/// 3. [applyLoanwords]     — English/chemical words -> Hausa phonetics.
/// 4. [cleanupPunctuation] — strip emoji & symbols TTS cannot read.
///
/// Every stage is also exposed individually so the English fallback chunker
/// can reuse it without running the whole pipeline twice.
library;

class TextPreprocessor {
  const TextPreprocessor._();

  // ---------------------------------------------------------------------------
  // 1. Numbers
  // ---------------------------------------------------------------------------

  /// Hausa cardinal numbers 0-10.
  static const Map<int, String> hausaNumbers = <int, String>{
    0: 'sifili',
    1: 'ɗaya',
    2: 'biyu',
    3: 'uku',
    4: 'huɗu',
    5: 'biyar',
    6: 'shida',
    7: 'bakwai',
    8: 'takwas',
    9: 'tara',
    10: 'goma',
  };

  /// Single digit -> Hausa word (used for multi-digit expansion).
  static const Map<String, String> _digits = <String, String>{
    '0': 'sifili',
    '1': 'ɗaya',
    '2': 'biyu',
    '3': 'uku',
    '4': 'huɗu',
    '5': 'biyar',
    '6': 'shida',
    '7': 'bakwai',
    '8': 'takwas',
    '9': 'tara',
  };

  /// Converts digits to Hausa words.
  ///
  /// * `7` -> `bakwai`
  /// * `10` -> `goma`
  /// * `1 killo` -> `ɗaya killo`
  /// * `2026` -> `biyu sifili biyu shida` (multi-digit numbers are spelled
  ///   digit-by-digit because farmers read them as lists, e.g. plot numbers).
  static String expandNumbers(String input) {
    if (input.isEmpty) return input;
    return input.replaceAllMapped(RegExp(r'\d+(?:\.\d+)?'), (Match match) {
      final raw = match.group(0)!;
      // Decimals are read as "X digo Y".
      if (raw.contains('.')) {
        final parts = raw.split('.');
        final left = _spellInteger(parts.first);
        final right = _spellInteger(parts.last);
        return '$left digo $right';
      }
      return _spellInteger(raw);
    });
  }

  static String _spellInteger(String digits) {
    final value = int.tryParse(digits);
    if (value != null && value >= 0 && value <= 10) {
      return hausaNumbers[value]!;
    }
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final word = _digits[digits[i]];
      if (word == null) continue;
      if (i > 0) buffer.write(' ');
      buffer.write(word);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 2. Hyphens & diacritic artefacts
  // ---------------------------------------------------------------------------

  /// Replaces hyphen/en-dash/em-dash with a space: `dogon-yaro` -> `dogon yaro`.
  static String removeHyphens(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2212]'), ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  // ---------------------------------------------------------------------------
  // 3. English loanwords -> phonetic Hausa spelling
  // ---------------------------------------------------------------------------

  /// English / chemical / brand words mapped to the spelling the Hausa voice
  /// pronounces correctly. Longest phrases win (see [applyLoanwords]).
  static const Map<String, String> englishLoanwords = <String, String>{
    // --- agrochemicals & inputs -------------------------------------------
    'mancozeb': 'mankozeb',
    'maneb': 'maneb',
    'carbendazim': 'kabendazim',
    'azoxystrobin': 'azokisitrobin',
    'difenoconazole': 'difenokonazol',
    'imidacloprid': 'imidaklopirid',
    'emamectin': 'emamektin',
    'benzoate': 'benzoweet',
    'spinetoram': 'spinetoram',
    'chlorpyrifos': 'klorpiriifos',
    'cypermethrin': 'saipametrin',
    'lambdacyhalothrin': 'lamdasaialotrin',
    'glyphosate': 'glaifoseet',
    'paraquat': 'parakwat',
    'urea': 'uriya',
    'npk': 'en-pi-key',
    'n.p.k': 'en-pi-key',
    'sulphur': 'sulful',
    'sulfur': 'sulful',
    'copper': 'koba',
    'fungicide': 'fangaizaid',
    'herbicide': 'habisaid',
    'pesticide': 'pestisaid',
    'insecticide': 'insectisaid',
    'fertilizer': 'fatilaiza',
    'fertiliser': 'fatilaiza',
    'antibiotic': 'antibayotik',
    'paracetamol': 'parasetamol',
    'amoxicillin': 'amoksisilin',
    'ciprofloxacin': 'siprofloksasin',
    'azithromycin': 'azithromaisin',
    'ceftriaxone': 'seftriakson',
    'artemisinin': 'atemisinin',
    'coartem': 'koatem',
    'ors': 'o-ar-es',
    'rdt': 'a-di-ti',
    'vitamin': 'vitamin',
    'chlorine': 'klorin',
    'waterguard': 'wota-gad',
    'aquatabs': 'akwatabs',
    'sodis': 'sodis',

    // --- technology / abbreviations ---------------------------------------
    'ph': 'pi-eich',
    'gps': 'ji-pi-es',
    'sos': 'es-o-es',
    'sms': 'es-em-es',
    'api': 'e-pi-ai',
    'id': 'ai-di',
    'app': 'ap',
    'wifi': 'waifai',
    'online': 'onlain',
    'offline': 'oflain',
    'update': 'apdeet',
    'smartvillage': 'smart-villej',
    'onnx': 'o-en-en-ex',
    'tts': 'ti-ti-es',
    'ntu': 'en-ti-yu',
    'who': 'dabl-yu-eich-o',
    'nsdwq': 'en-es-di-dabl-yu-kyu',
    'pm': 'pi-em',
    'am': 'e-em',
    'kg': 'ki-ge',
    'ml': 'em-el',
    'cm': 'si-em',
    'mm': 'em-em',
    'km': 'ki-em',
    'litre': 'lita',
    'liter': 'lita',
    'temperature': 'tempecha',
    'hectare': 'hekta',
    'hectares': 'hektoci',
    'germination': 'jamineshon',
    'transplant': 'transplant',
    'nursery': 'neseri',
    'irrigation': 'irigeshon',
    'extension': 'ekstenshon',
    'worker': 'woka',
    'officer': 'ofisa',
    'veterinary': 'vetirineri',
    'vaccine': 'vaksin',
    'vaccination': 'vaksineshon',
    'quarantine': 'kworantin',
    'diarrhea': 'daiariya',
    'diarrhoea': 'daiariya',
    'pneumonia': 'nimoniya',
    'malaria': 'maleriya',
    'typhoid': 'taifod',
    'cholera': 'kolera',
    'measles': 'mizles',
    'meningitis': 'meninjaitis',
    'tetanus': 'tetanus',
    'scabies': 'skabiz',
    'anemia': 'animiya',
    'anaemia': 'animiya',
    'protein': 'proteen',
    'calcium': 'kalsiyum',
    'nitrogen': 'naitrojen',
    'phosphorus': 'fosforus',
    'potassium': 'potasiyum',
    'magnesium': 'magnisiyum',
    'bacteria': 'bakteeriya',
    'bacterial': 'bakteeriya',
    'virus': 'bairas',
    'viral': 'bairal',
    'fungal': 'fanga',
    'fungus': 'fangas',
    'mosaic': 'mozeek',
    'blight': 'blait',
    'rust': 'rast',
    'smut': 'smat',
    'ergot': 'egot',
    'thrips': 'tirips',
    'armyworm': 'amiwom',
    'whitefly': 'waitiflai',
    'leafhopper': 'lifhopa',
    'nematode': 'nematod',
    'aphid': 'afid',
    'mite': 'mait',
    'aphids': 'afids',
    'alternaria': 'alternariya',
    'fusarium': 'fusariyum',
    'xanthomonas': 'zantomona',
    'colletotrichum': 'koletotrikum',
    'spodoptera': 'spodoptera',
    'bemisia': 'bemisiya',
    'puccinia': 'puksiniya',
    'ustilago': 'ustilago',

    // --- crops & food ------------------------------------------------------
    'onion': 'aniyan',
    'onions': 'aniyan',
    'tomato': 'tumatir',
    'tomatoes': 'tumatir',
    'maize': 'mez',
    'corn': 'kon',
    'rice': 'rais',
    'wheat': 'weet',
    'soybean': 'soyabin',
    'soybeans': 'soyabin',
    'soya': 'soya',
    'groundnut': 'grawnnat',
    'peanut': 'piinat',
    'cassava': 'kasava',
    'yam': 'yam',
    'cocoyam': 'koko-yam',
    'potato': 'poteto',
    'pepper': 'pepa',
    'chili': 'chili',
    'chilli': 'chili',
    'cowpea': 'kaupi',
    'beans': 'biins',
    'sorghum': 'sogham',
    'millet': 'milet',
    'sesame': 'sesami',
    'ginger': 'jinja',
    'garlic': 'galik',
    'carrot': 'karot',
    'cabbage': 'kabej',
    'lettuce': 'letes',
    'okra': 'okra',
    'spinach': 'spinach',
    'pumpkin': 'pamkin',
    'mango': 'mango',
    'banana': 'banana',
    'orange': 'oranj',
    'lemon': 'lemon',
    'sugar': 'shuga',
    'salt': 'gishiri',
    'oil': 'mai',
    'flour': 'fulawa',
    'bread': 'burodi',
    'tea': 'shayi',
    'milk': 'madara',
    'meat': 'nama',
    'egg': 'kwai',
    'eggs': 'kwai',
    'chicken': 'chikin',
    'poultry': 'poletri',
    'goat': 'got',
    'sheep': 'ship',
    'cattle': 'katil',
    'cow': 'kau',
    'donkey': 'donki',
    'camel': 'kamel',
    'pig': 'pig',
    'duck': 'dak',
    'turkey': 'taki',
    'rabbit': 'rabit',
    'dog': 'dog',
    'cat': 'kat',

    // --- places / institutions --------------------------------------------
    'nigeria': 'Naijeriya',
    'kano': 'Kano',
    'kaduna': 'Kaduna',
    'katsina': 'Katsina',
    'sokoto': 'Sokoto',
    'bauchi': 'Bauchi',
    'borno': 'Borno',
    'yobe': 'Yobe',
    'zamfara': 'Zamfara',
    'jigawa': 'Jigawa',
    'kebbi': 'Kebbi',
    'nasarawa': 'Nasarawa',
    'abuja': 'Abuja',
    'iita': 'ai-i-ti-e',
    'nrcri': 'en-ar-si-ar-ai',
    'phc': 'pi-eich-si',
    'hospital': 'asibiti',
    'clinic': 'klinik',
    'dispensary': 'dispeseri',
    'market': 'kasuwa',
    'school': 'makaranta',
    'google': 'gugul',
    'maps': 'maps',
    'gmail': 'gimeel',
    'internet': 'intanet',
    'network': 'netwok',
    'phone': 'foon',
    'android': 'android',
    'flutter': 'flata',

    // --- common words that are read as English inside Hausa sentences -----
    'emergency': 'imajensi',
    'urgent': 'aji',
    'alert': 'alat',
    'test': 'tes',
    'record': 'rikod',
    'history': 'histri',
    'result': 'rizalt',
    'analysis': 'analisis',
    'assessment': 'asesment',
    'confidence': 'konfidens',
    'symptom': 'simptom',
    'symptoms': 'simptom',
    'diagnosis': 'daiyagnosis',
    'treatment': 'tritment',
    'prevention': 'privent',
    'organic': 'oganik',
    'alternative': 'altanatif',
    'weather': 'weda',
    'calendar': 'kalanda',
    'library': 'laburari',
    'profile': 'profail',
    'settings': 'setings',
    'language': 'harshe',
    'photo': 'foto',
    'camera': 'kamara',
    'gallery': 'galari',
    'map': 'taswira',
    'location': 'lokeshon',
    'latitude': 'latitut',
    'longitude': 'lonjitut',
    'accuracy': 'akyuresi',
    'video': 'vidiyo',
    'audio': 'odiyo',
    'download': 'daunlod',
    'battery': 'batiri',
    'charging': 'chajin',
    'percentage': 'pasenti',
    'percent': 'pasenti',
    'kilogram': 'kilogiram',
    'gram': 'giram',
    'meter': 'mita',
  };

  /// Replaces English loanwords with phonetic Hausa spellings.
  ///
  /// Matching is case-insensitive, word-boundary aware and greedy on longest
  /// phrases first so `n.p.k`, `poultry` and `soybeans` win over `pk`/`bean`.
  static String applyLoanwords(String input) {
    if (input.isEmpty) return input;

    final keys = englishLoanwords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    var output = input;
    for (final key in keys) {
      final escaped = RegExp.escape(key);
      // Word boundaries do not work around punctuation-only keys ("n.p.k").
      final pattern = RegExp(
        '(?<![a-zA-Z0-9])$escaped(?![a-zA-Z0-9])',
        caseSensitive: false,
      );
      output = output.replaceAll(pattern, englishLoanwords[key]!);
    }
    return output;
  }

  /// Words that were *not* resolvable by [applyLoanwords] and therefore still
  /// look like English (used by the TTS chunker as a second signal).
  static bool isKnownLoanword(String word) =>
      englishLoanwords.containsKey(word.toLowerCase());

  // ---------------------------------------------------------------------------
  // 4. Punctuation & symbol cleanup
  // ---------------------------------------------------------------------------

  /// Emoji, pictographs, flags, dingbats and other glyphs that the TTS engine
  /// either skips awkwardly or reads out as "unknown character".
  static final RegExp _emojiPattern = RegExp(
    '['
    '\u{1F000}-\u{1FAFF}' // emoticons, pictographs, transport, symbols
    '\u{1F1E6}-\u{1F1FF}' // regional indicators (flags)
    '\u{2600}-\u{27BF}' // misc symbols & dingbats
    '\u{2B00}-\u{2BFF}' // arrows / stars
    '\u{FE0F}\u{FE0E}' // variation selectors
    '\u{200D}' // zero-width joiner
    '\u{20E3}' // combining enclosing keycap
    '\u{2190}-\u{21FF}' // arrows
    '\u{25A0}-\u{25FF}' // geometric shapes
    '\u{2900}-\u{297F}'
    ']',
    unicode: true,
  );

  static final RegExp _bulletPattern =
      RegExp(r'[•▪▫◦●○◆◇■□➤➢✓✔✗✘※※]', unicode: true);
  static final RegExp _whitespacePattern = RegExp(r'[ \t]+');
  static final RegExp _newlineRuns = RegExp(r'\n{3,}');
  static final RegExp _spaceBeforePunctuation = RegExp(r'\s+([,.!?;:])');

  /// Strips emoji/symbols/markdown and normalises punctuation spacing.
  static String cleanupPunctuation(String input) {
    if (input.isEmpty) return input;

    var output = input
        // Spell out symbols that carry meaning before deleting the rest.
        .replaceAll(RegExp(r'\s*&\s*'), ' da ')
        .replaceAll(RegExp(r'\s*%\s*'), ' cikin dari ')
        .replaceAll(RegExp(r'\s*\+\s*'), ' da ')
        .replaceAll(RegExp(r'\s*=\s*'), ' daidai ')
        .replaceAllMapped(
          RegExp(r'(\d)\s*/\s*(\d)'),
          (m) => '${m[1]} cikin ${m[2]}',
        )
        .replaceAll('\u00b0C', ' digiri')
        .replaceAll('\u00b0', ' digiri ')
        .replaceAll('°', ' digiri ')
        .replaceAll(RegExp(r'[@#*_~^`|<>\[\]{}()\\/]'), ' ')
        .replaceAll(RegExp(r'["\u201c\u201d\u2018\u2019]'), ' ')
        // Keep sentence punctuation but collapse decorative runs ("!!!" -> "!").
        .replaceAllMapped(
          RegExp(r'[!?;:]{2,}'),
          (m) => (m[0] ?? '').substring(0, 1),
        )
        .replaceAll(RegExp(r'\.{2,}'), '.');

    output = output
        .replaceAll(_emojiPattern, ' ')
        .replaceAll(_bulletPattern, ' ');

    output = output
        .replaceAll(_whitespacePattern, ' ')
        .replaceAllMapped(_spaceBeforePunctuation, (m) => m[1] ?? '')
        .replaceAll(_newlineRuns, '\n\n')
        .trim();

    // Neutralise stacked punctuation left behind (" , ." -> ",").
    output = output.replaceAllMapped(
      RegExp(r'([,.!?;:])(\s*[,.!?;:])+'),
      (m) => m[1] ?? '',
    );

    return output;
  }

  // ---------------------------------------------------------------------------
  // Full pipeline
  // ---------------------------------------------------------------------------

  /// Runs the complete Hausa normalisation pipeline.
  ///
  /// ```dart
  /// TextPreprocessor.normalize('7 mancozeb sprays on onion - dogon-yaro ⚠️');
  /// // => 'bakwai mankozeb sprays on aniyan dogon yaro'
  /// ```
  static String normalize(String input) {
    if (input.isEmpty) return input;
    var output = input;
    output = expandNumbers(output);
    output = removeHyphens(output);
    output = applyLoanwords(output);
    output = cleanupPunctuation(output);
    return output;
  }

  /// Splits text into sentences (used for chunked playback and for the
  /// "speak one sentence at a time" mode that keeps the UI responsive).
  static List<String> splitSentences(String input) {
    final cleaned = input.replaceAll('\r', ' ');
    final parts = cleaned.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    return parts
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Convenience: normalise then split, dropping empty sentences.
  static List<String> normalizeIntoSentences(String input) =>
      splitSentences(normalize(input));
}
