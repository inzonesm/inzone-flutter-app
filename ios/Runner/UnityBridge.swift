import Foundation
import Flutter
import UnityFramework

/// Bridges Flutter ↔ Unity via a MethodChannel on iOS.
///
/// Uses Apple's UnityFramework (exported from Unity as an embedded framework)
/// to launch the Unity player inside the same process. The Unity view is
/// presented modally on top of the Flutter view controller.
class UnityBridge: NSObject {

    static let shared = UnityBridge()

    private static let channelName = "com.inzone/unity"
    private static let sceneLoaderGO = "AddressableSceneLoader"
    private static let sceneLoaderMethod = "LoadScene"

    private var channel: FlutterMethodChannel?
    private var unityFramework: UnityFramework?
    private weak var hostController: UIViewController?

    /// Scene the next launch should load (sent to Unity once it's ready).
    private var pendingSceneName: String?

    private override init() { super.init() }

    // MARK: - Registration

    func register(with controller: FlutterViewController) {
        hostController = controller
        channel = FlutterMethodChannel(
            name: Self.channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        // Listen for Unity's unload request (posted from NativeCallbacks.mm)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnityRequestUnload),
            name: NSNotification.Name("UnityRequestUnload"),
            object: nil
        )
    }

    // MARK: - Flutter → Native

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "openUnity":
            let args = call.arguments as? [String: Any]
            let sceneName = args?["sceneName"] as? String
            launchUnity(sceneName: sceneName, result: result)
        case "closeUnity":
            closeUnity(result: result)
        case "sendToUnity":
            guard let args = call.arguments as? [String: String],
                  let gameObject = args["gameObject"],
                  let methodName = args["methodName"],
                  let message = args["message"] else {
                result(FlutterError(code: "BAD_ARGS", message: "Missing arguments", details: nil))
                return
            }
            sendToUnity(gameObject: gameObject, method: methodName, message: message)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Unity lifecycle

    private func loadUnityFramework() -> UnityFramework? {
        let bundlePath = Bundle.main.bundlePath
        let frameworkPath = "\(bundlePath)/Frameworks/UnityFramework.framework"

        guard let bundle = Bundle(path: frameworkPath) else {
            print("[UnityBridge] UnityFramework.framework not found at \(frameworkPath)")
            return nil
        }

        if !bundle.isLoaded {
            bundle.load()
        }

        guard let ufClass = bundle.principalClass as? UnityFramework.Type else {
            print("[UnityBridge] Could not load UnityFramework principal class")
            return nil
        }

        let fw = ufClass.getInstance()
        fw?.setDataBundleId("com.unity3d.framework")
        fw?.register(self) // receive messages from Unity
        return fw
    }

    private func launchUnity(sceneName: String?, result: @escaping FlutterResult) {
        if unityFramework == nil {
            unityFramework = loadUnityFramework()
        }

        guard let fw = unityFramework else {
            result(FlutterError(
                code: "UNITY_LOAD_FAILED",
                message: "Could not load UnityFramework. Make sure it is embedded in the app.",
                details: nil
            ))
            return
        }

        pendingSceneName = sceneName

        // Run Unity on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let isFirstLaunch = (fw.appController() == nil)

            if isFirstLaunch {
                // First launch – Unity needs command-line args
                fw.runEmbedded(
                    withArgc: CommandLine.argc,
                    argv: CommandLine.unsafeArgv,
                    appLaunchOpts: nil
                )
            } else {
                // Resume from paused state (back button hides + pauses)
                fw.pause(false)
                if let unityWindow = fw.appController()?.window {
                    unityWindow.isHidden = false
                    unityWindow.makeKeyAndVisible()
                }
            }

            // Forward the requested scene name to AddressableSceneLoader.
            // First launch needs a delay so the GameObject exists; subsequent
            // launches can dispatch almost immediately.
            if let scene = self.pendingSceneName {
                let delay: Double = isFirstLaunch ? 2.5 : 0.1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    fw.sendMessageToGO(
                        withName: Self.sceneLoaderGO,
                        functionName: Self.sceneLoaderMethod,
                        message: scene
                    )
                    self?.pendingSceneName = nil
                }
            }

            self.channel?.invokeMethod("onUnityReady", arguments: nil)
            result(nil)
        }
    }

    private func closeUnity(result: @escaping FlutterResult) {
        guard let fw = unityFramework else {
            result(nil)
            return
        }

        fw.pause(true)
        if let unityWindow = fw.appController()?.window {
            unityWindow.isHidden = true
        }
        if let flutterWindow = hostController?.view.window {
            flutterWindow.makeKeyAndVisible()
        }

        channel?.invokeMethod("onUnityQuit", arguments: nil)
        result(nil)
    }

    private func sendToUnity(gameObject: String, method: String, message: String) {
        unityFramework?.sendMessageToGO(
            withName: gameObject,
            functionName: method,
            message: message
        )
    }

    /// Called when Unity posts the "UnityRequestUnload" notification
    /// (from NativeCallbacks.mm, triggered by the C# back button).
    /// Instead of unloadApplication() (which hangs), we hide Unity's
    /// window, pause the engine, and bring Flutter back to the foreground.
    @objc private func handleUnityRequestUnload(_ notification: Notification) {
        guard let fw = unityFramework else { return }

        DispatchQueue.main.async { [weak self] in
            // Pause Unity to save CPU/GPU
            fw.pause(true)

            // Hide Unity's window and show Flutter's
            if let unityWindow = fw.appController()?.window {
                unityWindow.isHidden = true
            }
            if let flutterWindow = self?.hostController?.view.window {
                flutterWindow.makeKeyAndVisible()
            }

            self?.channel?.invokeMethod("onUnityQuit", arguments: nil)
        }
    }
}

// MARK: - UnityFrameworkListener

extension UnityBridge: UnityFrameworkListener {
    func unityDidUnload(_ notification: Notification!) {
        unityFramework?.unregisterFrameworkListener(self)
        unityFramework = nil
        channel?.invokeMethod("onUnityQuit", arguments: nil)
    }

    func unityDidQuit(_ notification: Notification!) {
        unityFramework?.unregisterFrameworkListener(self)
        unityFramework = nil
        channel?.invokeMethod("onUnityQuit", arguments: nil)
    }
}
