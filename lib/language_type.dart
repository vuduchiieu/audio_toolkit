enum LanguageType {
  en,
  vi,
  jp,
  kr,
  zh,
  fr,
  es,
  de,
  ru,
  it,
  pt,
  th,
  hi,
  id,
  ms,
  nl,
  sv,
  pl,
  ro,
  tr,
  uk,
  ar,
  fa,
  he,
  ur,
  bn,
  ta,
  te,
  ml,
  kn,
  cs,
  sk,
  hu,
  el,
  fi,
  da,
  no,
  sr,
  hr,
  bg,
  sl,
  et,
  lv,
  lt,
}

extension LanguageTypeExt on LanguageType {
  String get value {
    switch (this) {
      case LanguageType.en:
        return "en-US";
      case LanguageType.vi:
        return "vi-VN";
      case LanguageType.jp:
        return "ja-JP";
      case LanguageType.kr:
        return "ko-KR";
      case LanguageType.zh:
        return "zh-CN";
      case LanguageType.fr:
        return "fr-FR";
      case LanguageType.es:
        return "es-ES";
      case LanguageType.de:
        return "de-DE";
      case LanguageType.ru:
        return "ru-RU";
      case LanguageType.it:
        return "it-IT";
      case LanguageType.pt:
        return "pt-PT";
      case LanguageType.th:
        return "th-TH";
      case LanguageType.hi:
        return "hi-IN";
      case LanguageType.id:
        return "id-ID";
      case LanguageType.ms:
        return "ms-MY";
      case LanguageType.nl:
        return "nl-NL";
      case LanguageType.sv:
        return "sv-SE";
      case LanguageType.pl:
        return "pl-PL";
      case LanguageType.ro:
        return "ro-RO";
      case LanguageType.tr:
        return "tr-TR";
      case LanguageType.uk:
        return "uk-UA";
      case LanguageType.ar:
        return "ar-SA";
      case LanguageType.fa:
        return "fa-IR";
      case LanguageType.he:
        return "he-IL";
      case LanguageType.ur:
        return "ur-PK";
      case LanguageType.bn:
        return "bn-BD";
      case LanguageType.ta:
        return "ta-IN";
      case LanguageType.te:
        return "te-IN";
      case LanguageType.ml:
        return "ml-IN";
      case LanguageType.kn:
        return "kn-IN";
      case LanguageType.cs:
        return "cs-CZ";
      case LanguageType.sk:
        return "sk-SK";
      case LanguageType.hu:
        return "hu-HU";
      case LanguageType.el:
        return "el-GR";
      case LanguageType.fi:
        return "fi-FI";
      case LanguageType.da:
        return "da-DK";
      case LanguageType.no:
        return "no-NO";
      case LanguageType.sr:
        return "sr-RS";
      case LanguageType.hr:
        return "hr-HR";
      case LanguageType.bg:
        return "bg-BG";
      case LanguageType.sl:
        return "sl-SI";
      case LanguageType.et:
        return "et-EE";
      case LanguageType.lv:
        return "lv-LV";
      case LanguageType.lt:
        return "lt-LT";
    }
  }

  String get shortCode => value.split('-').first;

  static LanguageType fromShortCode(String code) {
    return LanguageType.values.firstWhere(
      (lang) => lang.shortCode == code.toLowerCase(),
      orElse: () => LanguageType.vi,
    );
  }

  String get displayName {
    switch (this) {
      case LanguageType.en:
        return "English";
      case LanguageType.vi:
        return "Tiếng Việt";
      case LanguageType.jp:
        return "日本語";
      case LanguageType.kr:
        return "한국어";
      case LanguageType.zh:
        return "中文";
      case LanguageType.fr:
        return "Français";
      case LanguageType.es:
        return "Español";
      case LanguageType.de:
        return "Deutsch";
      case LanguageType.ru:
        return "Русский";
      case LanguageType.it:
        return "Italiano";
      case LanguageType.pt:
        return "Português";
      case LanguageType.th:
        return "ไทย";
      case LanguageType.hi:
        return "हिन्दी";
      case LanguageType.id:
        return "Bahasa Indonesia";
      case LanguageType.ms:
        return "Bahasa Melayu";
      case LanguageType.nl:
        return "Nederlands";
      case LanguageType.sv:
        return "Svenska";
      case LanguageType.pl:
        return "Polski";
      case LanguageType.ro:
        return "Română";
      case LanguageType.tr:
        return "Türkçe";
      case LanguageType.uk:
        return "Українська";
      case LanguageType.ar:
        return "العربية";
      case LanguageType.fa:
        return "فارسی";
      case LanguageType.he:
        return "עברית";
      case LanguageType.ur:
        return "اردو";
      case LanguageType.bn:
        return "বাংলা";
      case LanguageType.ta:
        return "தமிழ்";
      case LanguageType.te:
        return "తెలుగు";
      case LanguageType.ml:
        return "മലയാളം";
      case LanguageType.kn:
        return "ಕನ್ನಡ";
      case LanguageType.cs:
        return "Čeština";
      case LanguageType.sk:
        return "Slovenčina";
      case LanguageType.hu:
        return "Magyar";
      case LanguageType.el:
        return "Ελληνικά";
      case LanguageType.fi:
        return "Suomi";
      case LanguageType.da:
        return "Dansk";
      case LanguageType.no:
        return "Norsk";
      case LanguageType.sr:
        return "Српски";
      case LanguageType.hr:
        return "Hrvatski";
      case LanguageType.bg:
        return "Български";
      case LanguageType.sl:
        return "Slovenščina";
      case LanguageType.et:
        return "Eesti";
      case LanguageType.lv:
        return "Latviešu";
      case LanguageType.lt:
        return "Lietuvių";
    }
  }
}
