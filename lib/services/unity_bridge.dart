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
  /// [projectId] is the Firestore game ID (currently only used for logging on
  /// the native side). [sceneName] is the Addressable scene key. [catalogUrl]
  /// is the Addressables remote catalog URL (https://... or file://...) — if
  /// provided, Unity loads this catalog before loading the scene.
  /// [bundlesDir] is the local directory holding pre-downloaded bundle files;
  /// Unity's AddressableSceneLoader loads bundles from there instead of GCS
  /// when the file exists locally.
  Future<void> open({
    String? projectId,
    String? sceneName,
    String? catalogUrl,
    String? bundlesDir,
  }) async {
    try {
      await _channel.invokeMethod('openUnity', {
        if (projectId != null) 'projectId': projectId,
        if (sceneName != null) 'sceneName': sceneName,
        if (catalogUrl != null) 'catalogUrl': catalogUrl,
        if (bundlesDir != null) 'bundlesDir': bundlesDir,
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
