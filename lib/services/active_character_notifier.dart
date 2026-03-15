import 'package:flutter/foundation.dart';

/// Tracks the AI character that is currently being chatted with.
/// RootApp listens to this to display the correct character in MiniGameMenu.
class ActiveCharacterNotifier extends ChangeNotifier {
  String _charName = 'InZone';
  String _charID = 'inzone-default';
  String? _charImage;
  String? _charDesc;

  /// Whether a real character (not the default InZone placeholder) is active.
  bool _hasActiveCharacter = false;

  String get charName => _charName;
  String get charID => _charID;
  String? get charImage => _charImage;
  String? get charDesc => _charDesc;
  bool get hasActiveCharacter => _hasActiveCharacter;

  /// Call when a user opens a chat with an AI character.
  void setActiveCharacter({
    required String charName,
    required String charID,
    String? charImage,
    String? charDesc,
  }) {
    _charName = charName;
    _charID = charID;
    _charImage = charImage;
    _charDesc = charDesc;
    _hasActiveCharacter = true;
    notifyListeners();
  }

  /// Call when the user leaves the chat screen.
  void clearActiveCharacter() {
    _charName = 'InZone';
    _charID = 'inzone-default';
    _charImage = null;
    _charDesc = null;
    _hasActiveCharacter = false;
    notifyListeners();
  }
}
