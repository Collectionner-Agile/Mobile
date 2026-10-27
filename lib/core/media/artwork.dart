/// Same rules as the web (`src/lib/site.ts` resolveCollectibleImage): records
/// that only carry a flat SVG placeholder get the curated illustration for
/// their object, else for their category. Real photos are never replaced.
library;

const _byName = <(String, String)>[
  (r'zelda|ocarina', '/assets/collectibles/records/zelda-adventure-set.webp'),
  (r'star destroyer|75252|lego', '/assets/collectibles/records/star-destroyer-model.webp'),
  (r'charizard|shadowless|trading card', '/assets/collectibles/records/fire-dragon-card.webp'),
  (r'seiko|6139|pogue|chronograph', '/assets/collectibles/records/vintage-yellow-chronograph.webp'),
  (r'super mario|mario 64|platform adventure', '/assets/collectibles/records/platform-adventure-set.webp'),
  (r'game boy|gameboy|pikachu', '/assets/collectibles/records/yellow-handheld-set.webp'),
];

const _generatedCategoryArt =
    r'/assets/collectibles/(games/retro-console|figures/space-explorer|cards/original-fantasy-card|watches/mechanical-watch)\.webp$';

String categoryArtwork(String? category) {
  final value = (category ?? '').toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(value);
  if (has(r'videojuego|game|gaming|consol|cartucho|retro')) return '/assets/collectibles/games/retro-console.webp';
  if (has(r'lego|figura|figure|space|sci.?fi')) return '/assets/collectibles/figures/space-explorer.webp';
  if (has(r'carta|card|tcg|pokemon|magic|yu.?gi.?oh')) return '/assets/collectibles/cards/original-fantasy-card.webp';
  if (has(r'reloj|watch|horolog|cron[oó]grafo')) return '/assets/collectibles/watches/mechanical-watch.webp';
  return '/assets/editorial/archival-instrument.webp';
}

bool _isPlaceholder(String? url) =>
    url == null ||
    url.trim().isEmpty ||
    url.startsWith('/assets/placeholders/') ||
    RegExp(r'/assets/collectibles/.*\.svg$', caseSensitive: false).hasMatch(url);

bool _isGeneratedArt(String url) => RegExp(_generatedCategoryArt, caseSensitive: false).hasMatch(url);

/// Best image to show for an object.
String artworkFor({required String name, String? category, String? url}) {
  if (!_isPlaceholder(url) && !_isGeneratedArt(url!)) return url;
  for (final (pattern, art) in _byName) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(name)) return art;
  }
  // Generic art must at least match the object's own category (a watch never
  // shows the console illustration).
  if (category != null && category.trim().isNotEmpty) return categoryArtwork(category);
  return _isPlaceholder(url) ? categoryArtwork(category) : url!;
}

/// Real photos only; the curated artwork stands in when there are none.
List<String> galleryFor({required String name, String? category, required List<String> urls}) {
  final real = urls.where((url) => !_isPlaceholder(url) && !_isGeneratedArt(url)).toList();
  return real.isEmpty ? [artworkFor(name: name, category: category, url: null)] : real;
}
