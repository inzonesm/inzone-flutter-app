import 'dart:async';
import 'package:flutter/services.dart';

/// Native bridge for launching the Unity game without flutter_unity_widget.
///
/// Uses a platform MethodChannel to start/stop the Unity player on each
/// platform (iOS UnityFramework, Android unityLibrary).
class UnityBridge {
  UnityBridge._();
  static final UnityBridge instance = UnityBridge._();

  static const MethodChannel _channel = MethodChannel('com.inzone/unity');

  bool _isUnityRunning = false;
  bool get isUnityRunning => _isUnityRunning;

  /// Callbacks from Unity → Flutter.
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  Stream<String> get onUnityMessage => _messageController.stream;

  /// Must be called once (e.g. in main.dart) so we can receive messages back
  /// from Unity.
  void init() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUnityMessage':
        final String message = call.arguments as String;
        _messageController.add(message);
        break;
      case 'onUnityReady':
        _isUnityRunning = true;
        break;
      case 'onUnityQuit':
        _isUnityRunning = false;
        break;
    }
  }

  /// Launch the Unity game as a full-screen native activity / view controller.
  ///
  /// Optional [projectId] and [sceneName] tell Unity which Addressable
  /// content pack to load. When omitted the default scene is used.
  Future<void> open({String? projectId, String? sceneName}) async {
    try {
      await _channel.invokeMethod('openUnity', {
        if (projectId != null) 'projectId': projectId,
        if (sceneName != null) 'sceneName': sceneName,
      });
      _isUnityRunning = true;
    } on PlatformException {
      _isUnityRunning = false;
      rethrow;
    }
  }

  /// Send a message to the running Unity instance.
  /// [gameObject] and [methodName] correspond to Unity's
  /// `UnitySendMessage(gameObject, methodName, message)`.
  Future<void> sendToUnity({
    required String gameObject,
    required String methodName,
    String message = '',
  }) async {
    await _channel.invokeMethod('sendToUnity', {
      'gameObject': gameObject,
      'methodName': methodName,
      'message': message,
    });
  }

  /// Ask Unity to quit / unload and return to Flutter.
  Future<void> close() async {
    try {
      await _channel.invokeMethod('closeUnity');
    } finally {
      _isUnityRunning = false;
    }
  }

  void dispose() {
    _messageController.close();
  }
}
