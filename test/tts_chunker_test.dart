import 'package:flutter_test/flutter_test.dart';
import 'package:smartvillage/services/text_preprocessor.dart';
import 'package:smartvillage/services/tts/tts_chunker.dart';

void main() {
  group('language detection', () {
    test('Hausa lexicon words are never English', () {
      for (final word in <String>['gona', 'albasa', 'ruwa', 'lafiya', 'girbi']) {
        expect(TtsChunker.looksEnglish(word), isFalse, reason: word);
      }
    });

    test('hooked letters force Hausa', () {
      expect(TtsChunker.looksEnglish('ƙasa'), isFalse);
      expect(TtsChunker.looksEnglish('ɗan'), isFalse);
    });

    test('complex English words are detected', () {
      expect(TtsChunker.looksEnglish('emamectin'), isTrue);
      expect(TtsChunker.looksEnglish('mesothelioma'), isTrue);
      expect(TtsChunker.looksEnglish('Benzoate'), isTrue);
      expect(TtsChunker.looksEnglish('configuration'), isTrue);
    });
  });

  group('chunking', () {
    test('pure Hausa stays a single Hausa chunk', () {
      final chunks = TtsChunker.split('Fesa maganin a gonar albasa yau');
      expect(chunks.length, 1);
      expect(chunks.single.language, ChunkLanguage.hausa);
    });

    test('mixed text is split by language', () {
      final chunks = TtsChunker.split(
        'Fesa emamectin benzoate a gonar albasa',
      );
      expect(chunks.length, greaterThanOrEqualTo(2));
      expect(chunks.first.isHausa, isTrue);
      expect(
        chunks.any((chunk) => chunk.language == ChunkLanguage.english),
        isTrue,
      );
      expect(chunks.last.isHausa, isTrue);
    });

    test('empty input produces no chunks', () {
      expect(TtsChunker.split('   '), isEmpty);
    });

    test('englishRatio reflects the mixture', () {
      expect(TtsChunker.englishRatio('gona albasa ruwa'), 0.0);
      expect(
        TtsChunker.englishRatio('configuration implementation determination'),
        1.0,
      );
    });
  });

  group('pre-processor + chunker together (Hausa routing)', () {
    test('loanwords are already Hausa after normalisation', () {
      final normalized = TextPreprocessor.normalize('onion and tomato');
      final chunks = TtsChunker.split(normalized);
      expect(chunks.first.language, ChunkLanguage.hausa);
      expect(normalized.contains('aniyan'), isTrue);
      expect(normalized.contains('tumatir'), isTrue);
    });

    test('unknown brand names still route to the English voice', () {
      final normalized =
          TextPreprocessor.normalize('Fesa trifloxystrobin a gona');
      final chunks = TtsChunker.split(normalized);
      expect(
        chunks.any((chunk) => chunk.language == ChunkLanguage.english),
        isTrue,
      );
    });
  });

  group('synthesis splitting (keeps every request inside the 2 s budget)', () {
    String longSentence(int words) =>
        List<String>.filled(words, 'albasa').join(' ');

    test('short runs are passed through untouched', () {
      final chunk = TtsChunk(text: 'Fesa maganin a gonar.', language: ChunkLanguage.hausa);
      final parts = TtsChunker.splitForSynthesis(chunk);
      expect(parts.length, 1);
      expect(parts.single.text, chunk.text);
    });

    test('sentence boundaries are preferred', () {
      final sentence = '${longSentence(20)}. ';
      final chunk = TtsChunk(
        text: List<String>.filled(6, sentence).join(),
        language: ChunkLanguage.hausa,
      );
      final parts = TtsChunker.splitForSynthesis(chunk);
      expect(parts.length, greaterThan(1));
      for (final part in parts) {
        expect(part.text.length, lessThanOrEqualTo(TtsChunker.maxCharsPerRequest));
        expect(part.isHausa, isTrue);
        expect(part.text.endsWith('.'), isTrue);
      }
    });

    test('clauses are used when one sentence is too long', () {
      final chunk = TtsChunk(
        text: '${longSentence(30)}, ${longSentence(30)}, ${longSentence(30)}.',
        language: ChunkLanguage.hausa,
      );
      final parts = TtsChunker.splitForSynthesis(chunk);
      expect(parts.length, greaterThanOrEqualTo(2));
      for (final part in parts) {
        expect(part.text.length, lessThanOrEqualTo(TtsChunker.maxCharsPerRequest));
      }
    });

    test('unpunctuated text is word-wrapped, never mid-word', () {
      final chunk = TtsChunk(
        text: List<String>.filled(200, 'albasa').join(' '),
        language: ChunkLanguage.hausa,
      );
      final parts = TtsChunker.splitForSynthesis(chunk);
      expect(parts.length, greaterThan(1));
      final rebuilt = parts.map((p) => p.text).join(' ');
      expect(rebuilt.split(' ').where((w) => w.isNotEmpty).length, 200);
      for (final part in parts) {
        expect(part.text.length, lessThanOrEqualTo(TtsChunker.maxCharsPerRequest));
        expect(part.text.startsWith('albasa'), isTrue);
        expect(part.text.endsWith('albasa'), isTrue);
      }
    });

    test('English chunks keep their language tag when split', () {
      final chunk = TtsChunk(
        text: List<String>.filled(80, 'emamectin').join(' '),
        language: ChunkLanguage.english,
      );
      final parts = TtsChunker.splitForSynthesis(chunk);
      expect(parts.every((p) => !p.isHausa), isTrue);
    });

    test('nothing is lost: the words survive splitting', () {
      final chunk = TtsChunk(
        text: '${longSentence(40)}. ${longSentence(40)}.',
        language: ChunkLanguage.hausa,
      );
      final parts = TtsChunker.splitForSynthesis(chunk);
      final original = chunk.text.split(RegExp(r'[\s.,]+')).where((w) => w.isNotEmpty).length;
      final produced = parts
          .map((p) => p.text)
          .join(' ')
          .split(RegExp(r'[\s.,]+'))
          .where((w) => w.isNotEmpty)
          .length;
      expect(produced, original);
    });
  });
}
