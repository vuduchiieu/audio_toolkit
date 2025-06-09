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

  String get displayName {
    switch (this) {
      case LanguageType.vi:
        return "Tiếng Việt";
      case LanguageType.en:
        return "English";
      case LanguageType.ja:
        return "日本語 (Nhật)";
      case LanguageType.ko:
        return "한국어 (Hàn)";
      case LanguageType.zh:
        return "中文 (Trung)";
      case LanguageType.fr:
        return "Français (Pháp)";
      case LanguageType.de:
        return "Deutsch (Đức)";
      case LanguageType.es:
        return "Español (Tây Ban Nha)";
      case LanguageType.it:
        return "Italiano (Ý)";
      case LanguageType.ru:
        return "Русский (Nga)";
      case LanguageType.th:
        return "ภาษาไทย (Thái)";
    }
  }
}
