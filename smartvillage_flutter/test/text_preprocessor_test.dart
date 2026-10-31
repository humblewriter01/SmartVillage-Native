import 'package:flutter_test/flutter_test.dart';
import 'package:smartvillage/services/text_preprocessor.dart';

void main() {
  group('Hausa number expansion', () {
    test('spells 0-10 as Hausa words', () {
      expect(TextPreprocessor.expandNumbers('7'), 'bakwai');
      expect(TextPreprocessor.expandNumbers('0'), 'sifili');
      expect(TextPreprocessor.expandNumbers('10'), 'goma');
      expect(TextPreprocessor.expandNumbers('3'), 'uku');
    });

    test('keeps surrounding words', () {
      expect(
        TextPreprocessor.expandNumbers('Fesa 2 a gonar'),
        'Fesa biyu a gonar',
      );
    });

    test('spells long numbers digit by digit', () {
      expect(TextPreprocessor.expandNumbers('2026'), 'biyu sifili biyu shida');
    });

    test('reads decimals with "digo"', () {
      expect(TextPreprocessor.expandNumbers('6.5'), 'shida digo biyar');
    });
  });

  group('Hyphen removal', () {
    test('replaces hyphens with spaces', () {
      expect(
        TextPreprocessor.removeHyphens('dogon-yaro'),
        'dogon yaro',
      );
      expect(
        TextPreprocessor.removeHyphens('gizo-gizo da kaza-kaza'),
        'gizo gizo da kaza kaza',
      );
    });

    test('handles en/em dashes', () {
      expect(
        TextPreprocessor.removeHyphens('albasa–tumatir—masara'),
        'albasa tumatir masara',
      );
    });
  });

  group('English loanword phonetics', () {
    test('maps the required core vocabulary', () {
      expect(TextPreprocessor.applyLoanwords('mancozeb'), 'mankozeb');
      expect(TextPreprocessor.applyLoanwords('ph'), 'pi-eich');
      expect(TextPreprocessor.applyLoanwords('gps'), 'ji-pi-es');
      expect(TextPreprocessor.applyLoanwords('sos'), 'es-o-es');
      expect(TextPreprocessor.applyLoanwords('onion'), 'aniyan');
      expect(TextPreprocessor.applyLoanwords('tomato'), 'tumatir');
      expect(TextPreprocessor.applyLoanwords('maize'), 'mez');
    });

    test('is case-insensitive and word-boundary aware', () {
      expect(TextPreprocessor.applyLoanwords('Onion'), 'aniyan');
      expect(
        TextPreprocessor.applyLoanwords('onions in the gona'),
        'aniyan in the gona',
      );
      // Must not corrupt words that merely contain the key.
      expect(
        TextPreprocessor.applyLoanwords('phony'),
        'phony',
      );
    });
  });

  group('Punctuation cleanup', () {
    test('strips emoji the TTS engine cannot read', () {
      final cleaned = TextPreprocessor.cleanupPunctuation('Ruwa mai kyau ✅💧⚠️');
      expect(cleaned.contains('✅'), isFalse);
      expect(cleaned.contains('💧'), isFalse);
      expect(cleaned.contains('Ruwa mai kyau'), isTrue);
    });

    test('spells out & and %', () {
      expect(TextPreprocessor.cleanupPunctuation('Ruwa & ƙasa'), 'Ruwa da ƙasa');
      expect(
        TextPreprocessor.cleanupPunctuation('50% na girbi'),
        '50 cikin dari na girbi',
      );
    });

    test('keeps Hausa hooked letters intact', () {
      const text = 'ƙasa ɗaya ɓera ƴaƴa';
      expect(TextPreprocessor.cleanupPunctuation(text), text);
    });

    test('collapses repeated punctuation', () {
      expect(TextPreprocessor.cleanupPunctuation('Sannu!!!'), 'Sannu!');
      expect(TextPreprocessor.cleanupPunctuation('Sannu,,, .'), 'Sannu,');
    });
  });

  group('Full pipeline', () {
    test('normalize applies every stage in order', () {
      final result = TextPreprocessor.normalize(
        '7 mancozeb sprays on onion - dogon-yaro ⚠️',
      );
      expect(result.contains('bakwai'), isTrue);
      expect(result.contains('mankozeb'), isTrue);
      expect(result.contains('aniyan'), isTrue);
      expect(result.contains('dogon yaro'), isTrue);
      expect(result.contains('⚠'), isFalse);
      expect(result.contains('-'), isFalse);
    });

    test('normalize keeps sentences speakable', () {
      final result = TextPreprocessor.normalize(
        'Fesa maganin a gonar. Idan ruwa ya yi yawa, dakatar!',
      );
      expect(result, contains('.'));
      expect(TextPreprocessor.splitSentences(result).length, 2);
    });

    test('does not drop text when nothing needs changing', () {
      const plain = 'Albasa tana da lafiya a gonar mu';
      expect(TextPreprocessor.normalize(plain), plain);
    });
  });
}
