inzone-flutter-app/lib/services/analytics_service.dart
```
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  /// Logs when a character is selected by the user.
  static Future<void> logCharacterSelected({
    required String characterId,
    required String characterName,
    int? popularity,
  }) async {
    await analytics.logEvent(
      name: 'character_selected',
      parameters: {
        'character_id': characterId,
        'character_name': characterName,
        if (popularity != null) 'popularity': popularity,
      },
    );
  }

  /// Logs when a character is viewed by the user.
  static Future<void> logCharacterViewed({
    required String characterId,
    required String characterName,
    int? popularity,
  }) async {
    await analytics.logEvent(
      name: 'character_viewed',
      parameters: {
        'character_id': characterId,
        'character_name': characterName,
        if (popularity != null) 'popularity': popularity,
      },
    );
  }
}
