/// Default allowed origins for Simula ad content
const List<String> defaultAllowedOrigins = [
  // Simula production servers
  'https://simula.ad',
  'https://www.simula.ad',
  'https://cdn.simula.ad',
  'https://ads.simula.ad',
  // Google Cloud Run (production API)
  'https://simula-api-701226639755.us-central1.run.app',
  // Cloudflare tunnels (development/staging)
  'https://*.trycloudflare.com',
  // Common CDN origins for ad assets
  'https://cdn.jsdelivr.net',
  'https://unpkg.com',
  // local ngrok domains
  'https://*.ngrok-free.dev',
];

/// Special URL schemes that should be allowed
const List<String> allowedSpecialSchemes = [
  'about:',
  'data:',
  'blob:',
];

/// Extract origin from URL
String? extractOrigin(String url) {
  try {
    // Handle special schemes
    for (final scheme in allowedSpecialSchemes) {
      if (url.startsWith(scheme)) {
        return scheme;
      }
    }

    // Block javascript: URLs
    if (url.startsWith('javascript:')) {
      return null;
    }

    // Parse URL to extract origin
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}';
  } catch (e) {
    return null;
  }
}

/// Check if URL matches origin pattern (supports wildcards)
bool matchesOriginPattern(String url, String pattern) {
  final origin = extractOrigin(url);
  if (origin == null) return false;

  // Handle special schemes
  if (allowedSpecialSchemes.contains(pattern) && origin == pattern) {
    return true;
  }

  // Handle wildcard patterns
  if (pattern.contains('*')) {
    final regexPattern = pattern
        .replaceAllMapped(RegExp(r'[.+?^${}()|[\]\\]'), (m) => '\\${m.group(0)}')
        .replaceAll('*', '[^/]+');
    try {
      final regex = RegExp('^$regexPattern\$', caseSensitive: false);
      return regex.hasMatch(origin);
    } catch (e) {
      return false;
    }
  }

  // Exact match (case-insensitive)
  return origin.toLowerCase() == pattern.toLowerCase();
}

/// Check if a URL's origin is allowed
bool isOriginAllowed(String url, [List<String>? allowedOrigins]) {
  final origins = allowedOrigins ?? defaultAllowedOrigins;

  // Always allow special schemes
  for (final scheme in allowedSpecialSchemes) {
    if (url.startsWith(scheme)) {
      return true;
    }
  }

  // Block javascript: URLs
  if (url.startsWith('javascript:')) {
    return false;
  }

  // Check against allowed origins
  for (final pattern in origins) {
    if (matchesOriginPattern(url, pattern)) {
      return true;
    }
  }

  return false;
}
