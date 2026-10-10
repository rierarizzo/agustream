/// One subtitle track an addon offers (the `subtitles` resource).
///
/// Besides `id`/`url`/`lang` from the Stremio protocol, richer addons (e.g.
/// AIOStreams/OpenSubtitles) also send `title` (the release name), `lang_code`,
/// `ai_translated` and `from_trusted`.
class Subtitle {
  const Subtitle({
    required this.id,
    required this.url,
    this.lang,
    this.title,
    this.langCode,
    this.aiTranslated = false,
    this.fromTrusted = false,
    this.addonName,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      lang: json['lang'] as String?,
      title: json['title'] as String?,
      langCode: json['lang_code'] as String?,
      aiTranslated: json['ai_translated'] == true,
      fromTrusted: json['from_trusted'] == true,
    );
  }

  final String id;

  /// URL of the subtitle file.
  final String url;

  /// Language as the addon labels it; may be a code (`spa`) or free text.
  final String? lang;

  /// Release/file name the subtitle matches, when the addon sends one.
  final String? title;

  /// ISO language code, when the addon sends one.
  final String? langCode;

  /// Whether the subtitle was machine-translated.
  final bool aiTranslated;

  /// Whether the addon trusts the uploader.
  final bool fromTrusted;

  /// Addon that offered this subtitle (set when aggregating).
  final String? addonName;

  /// Human-readable language name, when the code is recognized.
  String? get languageName {
    final code = (langCode ?? lang)?.trim().toLowerCase();
    if (code == null || code.isEmpty) return null;
    return _languages[code] ?? _languages[code.split('-').first];
  }

  /// Copy with the [addonName] set (used by the aggregating repository).
  Subtitle withAddon(String? name) => Subtitle(
    id: id,
    url: url,
    lang: lang,
    title: title,
    langCode: langCode,
    aiTranslated: aiTranslated,
    fromTrusted: fromTrusted,
    addonName: name,
  );

  static const Map<String, String> _languages = {
    'en': 'English',
    'eng': 'English',
    'es': 'Spanish',
    'spa': 'Spanish',
    'fr': 'French',
    'fre': 'French',
    'fra': 'French',
    'de': 'German',
    'ger': 'German',
    'deu': 'German',
    'it': 'Italian',
    'ita': 'Italian',
    'pt': 'Portuguese',
    'por': 'Portuguese',
    'pt-br': 'Portuguese (Brazil)',
    'ru': 'Russian',
    'rus': 'Russian',
    'ja': 'Japanese',
    'jpn': 'Japanese',
    'ko': 'Korean',
    'kor': 'Korean',
    'zh': 'Chinese',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'ar': 'Arabic',
    'ara': 'Arabic',
    'hi': 'Hindi',
    'hin': 'Hindi',
    'nl': 'Dutch',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'pl': 'Polish',
    'pol': 'Polish',
    'tr': 'Turkish',
    'tur': 'Turkish',
    'sv': 'Swedish',
    'swe': 'Swedish',
    'no': 'Norwegian',
    'nor': 'Norwegian',
    'da': 'Danish',
    'dan': 'Danish',
    'fi': 'Finnish',
    'fin': 'Finnish',
    'cs': 'Czech',
    'cze': 'Czech',
    'ces': 'Czech',
    'el': 'Greek',
    'gre': 'Greek',
    'ell': 'Greek',
    'he': 'Hebrew',
    'heb': 'Hebrew',
    'uk': 'Ukrainian',
    'ukr': 'Ukrainian',
    'ro': 'Romanian',
    'ron': 'Romanian',
    'hu': 'Hungarian',
    'hun': 'Hungarian',
    'th': 'Thai',
    'tha': 'Thai',
    'vi': 'Vietnamese',
    'vie': 'Vietnamese',
    'id': 'Indonesian',
    'ind': 'Indonesian',
    'fa': 'Persian',
    'per': 'Persian',
    'fas': 'Persian',
    'ms': 'Malay',
    'may': 'Malay',
    'msa': 'Malay',
    'bg': 'Bulgarian',
    'bul': 'Bulgarian',
    'hr': 'Croatian',
    'hrv': 'Croatian',
    'sr': 'Serbian',
    'srp': 'Serbian',
    'sk': 'Slovak',
    'slo': 'Slovak',
    'slk': 'Slovak',
    'sl': 'Slovenian',
    'slv': 'Slovenian',
    'et': 'Estonian',
    'est': 'Estonian',
    'lv': 'Latvian',
    'lav': 'Latvian',
    'lt': 'Lithuanian',
    'lit': 'Lithuanian',
  };
}
