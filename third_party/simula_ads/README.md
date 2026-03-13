# Simula Ad SDK for Flutter

## Overview

The Simula Ad SDK enables Flutter developers to monetize conversational AI applications with contextually relevant, non-intrusive ads. The SDK provides native ad placements and sponsored mini-games that integrate naturally with chat interfaces.

### Key Features

- **Contextual Targeting** - AI-powered ad matching based on conversation content
- **Native Ad Slots** - Flexible ad placements that blend with your UI
- **Mini-Games** - Sponsored interactive experiences for AI characters

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  simula_ads: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## Quick Start

### 1. Provider Setup

Wrap your application with `SimulaProvider` to initialize the SDK:

```dart
@override
Widget build(BuildContext context) {
  return SimulaProvider(
    apiKey: 'SIMULA_xxx',
    child: YourAppWidget(),
    primaryUserID: 'xxxxx', // Optional: User ID for better ad targeting
    hasPrivacyConsent: true, // Optional: Privacy consent flag
    devMode: false, // Optional: Enable dev mode for testing
  );
}
```

### 2. Component Integration

Add components where you want ads or games to appear:

**Native Ads:**
```dart
NativeAdSlot(
  slot: 'feed',
  position: index,
  context: NativeContext(
    searchTerm: 'cute anime waifu',
    tags: ['anime', 'cute'],
  ),
  width: double.infinity,
  onImpression: (ad) => print('Impression: ${ad.id}'),
  onError: (error) => print('Error: $error'),
)
```

**Mini-Games:**
```dart
MiniGameMenu(
  isOpen: menuOpen,
  onClose: () => setState(() => menuOpen = false),
  charName: 'Luna',
  charID: 'luna-123',
  charImage: 'https://cdn.example.com/avatars/luna.png',
)
```

---

## Documentation

For complete API reference, integration guides, and examples:

**[View Full Documentation](https://simula-ad.notion.site/Simula-x-Chai-Native-Ads-Mini-Game-SDK-2efaf70f6f0d80a7930cc80d9f6aeda1?source=copy_link/)**

---

## Support

- **Website:** [simula.ad](https://simula.ad)
- **Email:** [admin@simula.ad](mailto:admin@simula.ad)

---

## License

MIT
