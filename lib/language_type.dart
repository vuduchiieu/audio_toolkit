enum LanguageType {
  vi,
  en,
  ja,
  ko,
  zh,
  fr,
  de,
  es,
  it,
  ru,
  th,
}

extension LanguageTypeExt on LanguageType {
  String get value {
    switch (this) {
      case LanguageType.vi:
        return "vi-VN";
      case LanguageType.en:
        return "en-US";
      case LanguageType.ja:
        return "ja-JP";
      case LanguageType.ko:
        return "ko-KR";
      case LanguageType.zh:
        return "zh-CN";
      case LanguageType.fr:
        return "fr-FR";
      case LanguageType.de:
        return "de-DE";
      case LanguageType.es:
        return "es-ES";
      case LanguageType.it:
        return "it-IT";
      case LanguageType.ru:
        return "ru-RU";
      case LanguageType.th:
        return "th-TH";
    }
  }
}
