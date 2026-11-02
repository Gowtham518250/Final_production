// =============================================================================
// indic_number_repair.dart
//
// Repairs spoken numbers in speech-to-text output BEFORE they reach the billing
// AI. Telugu recognisers often spell numbers by sound, not by the dictionary:
//
//     "ఇండు కిలో"          (2 kilo)      -> "2 కిలో"
//     "ఆరవే రూపాయలు"       (60 rupees)   -> "60 రూపాయలు"
//     "రేణు ఉందలు"          (200)         -> "200"
//     "ఆయ్దు ఉందలు"         (500)         -> "500"
//
// Without this the AI sees unknown words where the price should be and either
// guesses or leaves the price at 0.
//
// Safety rules (a wrong price on a bill is worse than a missing one):
//   * Canonical spellings are never touched. Only non-canonical tokens are
//     "repaired", and only when the surrounding words prove a number belongs
//     there: next to a hundred/thousand scale word, a price word, or a unit.
//   * A fuzzy match must be close AND clearly better than the runner-up.
//   * Ordinary words (products, units, connectors) are never converted.
//   * Every repair is reported so the app can tell the shopkeeper to verify.
//
// Pure Dart. Telugu is implemented; add another language by adding a
// `_Lexicon` and an entry in `_lexicons`.
// =============================================================================

class NumberRepair {
  const NumberRepair(this.heard, this.value);

  /// The words as the recogniser produced them.
  final String heard;

  /// The number they were read as.
  final int value;
}

class NumberRepairResult {
  const NumberRepairResult(this.text, this.repairs);
  final String text;
  final List<NumberRepair> repairs;
}

class IndicNumberRepair {
  IndicNumberRepair._();

  /// Repairs [transcript] for [languageCode] (`te-IN`, `te`, ...). Languages
  /// without a lexicon are returned unchanged.
  static NumberRepairResult repair(String transcript, String languageCode) {
    final lexicon = _lexicons[languageCode.toLowerCase().split(RegExp(r'[-_]')).first];
    if (lexicon == null || transcript.trim().isEmpty) {
      return NumberRepairResult(transcript, const []);
    }
    return _repairWith(lexicon, transcript);
  }

  static NumberRepairResult _repairWith(_Lexicon lex, String transcript) {
    final tokens = transcript.trim().split(RegExp(r'\s+'));
    final out = <String>[];
    final repairs = <NumberRepair>[];
    var i = 0;

    while (i < tokens.length) {
      final tok = _clean(tokens[i]);
      final next = i + 1 < tokens.length ? _clean(tokens[i + 1]) : null;
      final afterNext = i + 2 < tokens.length ? _clean(tokens[i + 2]) : null;

      // ── Pattern A: <number> <hundred|thousand scale> [<remainder 1..99>]
      if (next != null && !lex.protected.contains(tok)) {
        final scale = lex.matchScale(next, previousIsNumber: true);
        if (scale != null) {
          final base = lex.matchSmallNumber(tok, allowFuzzy: true);
          if (base != null && base.value >= 1 && base.value <= 99) {
            var value = base.value * scale.value;
            var consumed = 2;
            if (afterNext != null) {
              // Optional remainder, exact spellings only: "రెండు వందలు యాభై".
              final remainder = lex.matchSmallNumber(afterNext, allowFuzzy: false);
              if (remainder != null &&
                  remainder.exact &&
                  remainder.value >= 1 &&
                  remainder.value < scale.value) {
                value += remainder.value;
                consumed = 3;
              }
            }
            final heard = tokens.sublist(i, i + consumed).join(' ');
            // Canonical phrases are rewritten to digits silently; only a
            // phrase that needed fuzzy repair is reported for verification.
            if (!(base.exact && scale.exact)) {
              repairs.add(NumberRepair(heard, value));
            }
            out.add('$value');
            i += consumed;
            continue;
          }
        }
      }

      // ── Pattern B: <నూట> <remainder>  (Telugu "hundred-and": నూట యాభై = 150)
      if (lex.hundredAnd.contains(tok) && next != null) {
        final remainder = lex.matchSmallNumber(next, allowFuzzy: false);
        if (remainder != null &&
            remainder.exact &&
            remainder.value >= 1 &&
            remainder.value < 100) {
          final value = 100 + remainder.value;
          out.add('$value'); // canonical spelling: no verification note needed
          i += 2;
          continue;
        }
      }

      // ── Pattern C: a single non-canonical number word, only where the next
      //    word is a price word or a unit ("ఆరవే రూపాయలు", "ఇండు కిలో").
      if (next != null &&
          !lex.protected.contains(tok) &&
          lex.numberExact(tok) == null &&
          (lex.priceWords.contains(next) || lex.unitWords.contains(next))) {
        final isPrice = lex.priceWords.contains(next);
        final match = lex.matchSmallNumber(
          tok,
          allowFuzzy: true,
          allowTens: isPrice,
          fuzzyOnly: true,
        );
        if (match != null) {
          repairs.add(NumberRepair(tokens[i], match.value));
          out.add('${match.value}');
          i += 1;
          continue;
        }
      }

      out.add(tokens[i]);
      i++;
    }

    return NumberRepairResult(out.join(' '), repairs);
  }

  static String _clean(String token) => token
      .replaceAll(RegExp(r'^[\s,.;:!?"\u201c\u201d()]+|[\s,.;:!?"\u201c\u201d()]+$'), '')
      .toLowerCase();

  static final Map<String, _Lexicon> _lexicons = {'te': _teluguLexicon};
}

// =============================================================================
// Lexicon
// =============================================================================

class _SmallMatch {
  const _SmallMatch(this.value, {required this.exact});
  final int value;
  final bool exact;
}

class _ScaleMatch {
  const _ScaleMatch(this.value, {required this.exact});
  final int value;
  final bool exact;
}

class _Lexicon {
  _Lexicon({
    required this.ones,
    required this.tens,
    required this.scales,
    required this.hundredAnd,
    required this.priceWords,
    required this.unitWords,
    required this.protected,
    required this.skeleton,
  }) {
    _onesSkeletons = {
      for (final e in ones.entries)
        if (e.value >= 2) e.key: skeleton(e.key),
    };
    _tensSkeletons = {for (final e in tens.entries) e.key: skeleton(e.key)};
    _scaleSkeletons = {for (final e in scales.entries) e.key: skeleton(e.key)};
  }

  final Map<String, int> ones; // 1..9 (+ variants)
  final Map<String, int> tens; // 10..90
  final Map<String, int> scales; // వంద(లు)=100, వేలు=1000
  final Set<String> hundredAnd; // నూట
  final Set<String> priceWords;
  final Set<String> unitWords;
  final Set<String> protected; // never converted
  final String Function(String) skeleton;

  late final Map<String, String> _onesSkeletons;
  late final Map<String, String> _tensSkeletons;
  late final Map<String, String> _scaleSkeletons;

  /// Exact (canonical) value of a number word, or null.
  int? numberExact(String token) => ones[token] ?? tens[token];

  _ScaleMatch? matchScale(String token, {required bool previousIsNumber}) {
    final exact = scales[token];
    if (exact != null) return _ScaleMatch(exact, exact: true);
    if (!previousIsNumber || protected.contains(token)) return null;
    final best = _best(skeleton(token), _scaleSkeletons, maxDistance: 0.5);
    return best == null ? null : _ScaleMatch(scales[best]!, exact: false);
  }

  /// Exact match first; fuzzy only when [allowFuzzy]. [fuzzyOnly] skips the
  /// exact lookup (callers already know the token is non-canonical).
  _SmallMatch? matchSmallNumber(
    String token, {
    required bool allowFuzzy,
    bool allowTens = true,
    bool fuzzyOnly = false,
  }) {
    if (!fuzzyOnly) {
      final exact = ones[token] ?? tens[token];
      if (exact != null) return _SmallMatch(exact, exact: true);
    }
    if (!allowFuzzy || protected.contains(token) || token.runes.length < 2) {
      return null;
    }
    final sk = skeleton(token);
    final pool = <String, String>{
      ..._onesSkeletons,
      if (allowTens) ..._tensSkeletons,
    };
    final best = _best(sk, pool, maxDistance: 0.5);
    if (best == null) return null;
    final value = ones[best] ?? tens[best];
    return value == null ? null : _SmallMatch(value, exact: false);
  }

  /// Best candidate within [maxDistance] that is also clearly better than the
  /// nearest candidate with a DIFFERENT value (spelling variants of the same
  /// number are not competitors). Returns null when it would be a guess.
  String? _best(
    String sk,
    Map<String, String> candidates, {
    required double maxDistance,
  }) {
    int? valueOf(String key) => ones[key] ?? tens[key] ?? scales[key];

    final scored = candidates.entries
        .map((e) => (key: e.key, value: valueOf(e.key), dist: _distance(sk, e.value)))
        .toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));
    if (scored.isEmpty) return null;

    final best = scored.first;
    if (best.dist > maxDistance) return null;
    final rival = scored.where((c) => c.value != best.value).firstOrNull;
    if (rival != null && rival.dist - best.dist < 0.4) return null;
    return best.key;
  }
}

// =============================================================================
// Telugu data
// =============================================================================

final _Lexicon _teluguLexicon = _Lexicon(
  ones: const {
    'ఒకటి': 1,
    'ఒక్కటి': 1,
    'రెండు': 2,
    'మూడు': 3,
    'నాలుగు': 4,
    'ఐదు': 5,
    'అయిదు': 5,
    'ఆరు': 6,
    'ఏడు': 7,
    'ఎనిమిది': 8,
    'తొమ్మిది': 9,
  },
  tens: const {
    'పది': 10,
    'ఇరవై': 20,
    'ముప్పై': 30,
    'నలభై': 40,
    'యాభై': 50,
    'అరవై': 60,
    'డెబ్బై': 70,
    'ఎనభై': 80,
    'తొంభై': 90,
  },
  scales: const {
    'వంద': 100,
    'వందలు': 100,
    'వందల': 100,
    'వేలు': 1000,
    'వేల': 1000,
    'వెయ్యి': 1000,
  },
  hundredAnd: const {'నూట'},
  priceWords: const {
    'రూపాయలు',
    'రూపాయల',
    'రూపాయి',
    'రూపాయ',
    'రూ',
    'రూ.',
    'ధర',
    'ఖరీదు',
  },
  unitWords: const {
    'కిలో',
    'కిలోలు',
    'కిలోల',
    'గ్రాములు',
    'గ్రాము',
    'లీటర్',
    'లీటరు',
    'లీటర్లు',
    'ప్యాకెట్',
    'ప్యాకెట్లు',
    'పీస్',
    'పీసులు',
    'ముక్క',
    'ముక్కలు',
    'డజను',
    'సీసా',
    'సీసాలు',
  },
  // Words that look number-ish by sound but are everyday vocabulary.
  protected: const {
    'ఒక',
    'మరియు',
    'నూనె',
    'నూనే',
    'బియ్యం',
    'పాలు',
    'ఉప్పు',
    'పంచదార',
    'పంచేదారా',
    'చికెన్',
    'చికన్',
    'మటన్',
    'బిరియాని',
    'బిర్యానీ',
    'కిలో',
    'ధర',
    'ఖరీదు',
    'రూపాయలు',
    'రూ',
    'వంద',
    'వందలు',
    'వేలు',
  },
  skeleton: _teluguSkeleton,
);

// =============================================================================
// Sound skeleton + weighted distance
// =============================================================================

/// Reduces a Telugu word to a rough "how it sounds" key so that recogniser
/// spellings of one number collapse to the same key:
/// retroflex/dental and aspirated pairs merge, vowel signs drop, the
/// anusvara counts as a nasal, and a leading vowel survives as a marker.
String _teluguSkeleton(String word) {
  const merge = <int, String>{
    0x0C23: 'న', // ణ
    0x0C33: 'ల', // ళ
    0x0C31: 'ర', // ఱ
    0x0C16: 'క', // ఖ
    0x0C18: 'క', // ఘ
    0x0C1B: 'చ', // ఛ
    0x0C1D: 'జ', // ఝ
    0x0C20: 'త', // ఠ
    0x0C1F: 'త', // ట
    0x0C22: 'ద', // ఢ
    0x0C21: 'ద', // డ
    0x0C25: 'త', // థ
    0x0C27: 'ద', // ధ
    0x0C2D: 'బ', // భ
    0x0C2B: 'ప', // ఫ
    0x0C36: 'స', // శ
    0x0C37: 'స', // ష
    0x0C19: 'న', // ఙ
    0x0C1E: 'న', // ఞ
    0x0C34: 'ల', // ఴ
  };

  final buf = StringBuffer();
  var first = true;
  for (final r in word.runes) {
    // Independent vowels.
    if (r >= 0x0C05 && r <= 0x0C14) {
      if (first) {
        // Leading vowel survives as a coarse class marker.
        if (r == 0x0C05 || r == 0x0C06) {
          buf.write('A');
        } else if (r == 0x0C07 || r == 0x0C08) {
          buf.write('I');
        } else if (r == 0x0C09 || r == 0x0C0A) {
          buf.write('U');
        } else if (r == 0x0C0E || r == 0x0C0F) {
          buf.write('E');
        } else if (r == 0x0C12 || r == 0x0C13) {
          buf.write('O');
        } else if (r == 0x0C10) {
          buf.write('Aయ'); // ఐ = a + y
        } else if (r == 0x0C14) {
          buf.write('Aవ'); // ఔ = a + v
        }
      } else {
        if (r == 0x0C10) buf.write('య');
        if (r == 0x0C14) buf.write('వ');
      }
      first = false;
      continue;
    }
    first = false;
    // Vowel signs, virama, candrabindu, visarga.
    if (r >= 0x0C3E && r <= 0x0C4C) {
      if (r == 0x0C48) buf.write('య'); // ై
      if (r == 0x0C4C) buf.write('వ'); // ౌ
      continue;
    }
    if (r == 0x0C4D || r == 0x0C55 || r == 0x0C56 || r == 0x0C03) continue;
    if (r == 0x0C02 || r == 0x0C01) {
      buf.write('న'); // anusvara/candrabindu -> nasal
      continue;
    }
    if (r == 0x200C || r == 0x200D) continue; // joiners
    if (r >= 0x0C15 && r <= 0x0C39) {
      buf.write(merge[r] ?? String.fromCharCode(r));
      continue;
    }
    // Digits/Latin: keep as is so they never match a number word.
    buf.writeCharCode(r);
  }
  // Recognisers often collapse a nasal+stop cluster (ండ, ంద, ంబ...) into a
  // single nasal (రెండు -> "రేణు"), so compare with the cluster collapsed.
  return buf.toString().replaceAll(RegExp('న[కగచజతదపబ]'), 'న');
}

const _vowelMarkers = {'A', 'I', 'U', 'E', 'O'};

double _insDelCost(String c) {
  if (_vowelMarkers.contains(c) || c == 'య') return 0.5;
  return 1.0;
}

double _subCost(String a, String b, int position) {
  if (a == b) return 0.0;
  final av = _vowelMarkers.contains(a);
  final bv = _vowelMarkers.contains(b);
  if (av && bv) return 0.5; // vowel class vs vowel class
  if ((av != bv) && position == 0) return 0.5; // recogniser swapped initial
  return 1.0;
}

/// Weighted edit distance between two skeletons. Cheap edits are the ones
/// recognisers actually make: vowel class changes, a dropped/added glide
/// (య) and a swapped initial sound.
double _distance(String a, String b) {
  final x = a.split('');
  final y = b.split('');
  final dp = List.generate(
    x.length + 1,
    (_) => List<double>.filled(y.length + 1, 0),
  );
  for (var i = 1; i <= x.length; i++) {
    dp[i][0] = dp[i - 1][0] + _insDelCost(x[i - 1]);
  }
  for (var j = 1; j <= y.length; j++) {
    dp[0][j] = dp[0][j - 1] + _insDelCost(y[j - 1]);
  }
  for (var i = 1; i <= x.length; i++) {
    for (var j = 1; j <= y.length; j++) {
      final sub = dp[i - 1][j - 1] + _subCost(x[i - 1], y[j - 1], i - 1);
      final del = dp[i - 1][j] + _insDelCost(x[i - 1]);
      final ins = dp[i][j - 1] + _insDelCost(y[j - 1]);
      dp[i][j] = [sub, del, ins].reduce((m, v) => v < m ? v : m);
    }
  }
  return dp[x.length][y.length];
}
