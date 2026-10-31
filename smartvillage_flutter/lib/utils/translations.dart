import '../data/translations_data.dart';

/// The two supported interface languages.
enum AppLanguage {
  english('en', 'English', '🇬🇧'),
  hausa('ha', 'Hausa', '🇳🇬');

  const AppLanguage(this.code, this.label, this.flag);

  final String code;
  final String label;
  final String flag;

  bool get isHausa => this == AppLanguage.hausa;

  /// Locale passed to the platform TTS engine / voice pipeline.
  String get ttsLocale => isHausa ? 'ha-NG' : 'en-NG';

  static AppLanguage fromCode(String? code) =>
      code == 'ha' ? AppLanguage.hausa : AppLanguage.english;
}

/// Bilingual string lookup — the Flutter port of `t(locale, key)` from
/// `src/utils/translations.ts`.
///
/// Falls back to English and finally to the key itself, exactly like the
/// React helper, so a missing translation can never crash a screen.
class Translations {
  const Translations._();

  static String t(AppLanguage language, String key) {
    final table = appTranslations[language.code] ?? appTranslations['en']!;
    final value = table[key];
    if (value != null && value.isNotEmpty) return value;
    final english = appTranslations['en']?[key];
    if (english != null && english.isNotEmpty) return english;
    return key;
  }

  /// Picks the correct half of a bilingual pair.
  static String pick(AppLanguage language, String en, String ha) =>
      language.isHausa ? ha : en;

  static bool hasKey(String key) =>
      appTranslations['en']?.containsKey(key) ?? false;
}
