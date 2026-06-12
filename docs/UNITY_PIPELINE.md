# Unity Game Hub Pipeline

How Unity games are built, delivered, and played inside the inzone app.

## Architecture

One Unity runtime is embedded in the app (Unity as a Library). Every game is a
**scene** in the single Unity project, packaged as an **Addressables** content
pack and hosted on GCS. The app downloads content, not code.

```
Unity project (…/inzone/Unity/My project, editor 6000.3.x)
  └─ Addressables build  →  ServerData/iOS/*.bundle + catalog_*.bin
        └─ scripts/upload_addressables.sh  →  gs://inzone-unity-bundles/iOS
              └─ scripts/update_catalog_field.js  →  Firestore unityGames.catalogFile

Flutter app
  ├─ UnityGameHubScreen (lib/screen/game_hub/) — grid UI from Firestore `unityGames`
  ├─ GameHubService — downloads bundles via dio → Application Support/unity_bundles/
  └─ UnityBridge (lib/services/unity_bridge.dart) — MethodChannel `com.inzone/unity`
        ├─ iOS: ios/Runner/UnityBridge.swift → embedded UnityFramework.framework
        └─ Android: UnityBridge.kt → UnityPlayerActivity (android/unityLibrary export)

Unity runtime
  └─ AddressableSceneLoader (Assets/Scripts/) — receives JSON
     {sceneName, catalogUrl, bundlesDir} via UnitySendMessage, loads the remote
     catalog, redirects bundle URLs to local files in bundlesDir when present,
     then loads the scene. Back button → pause + hand control back to Flutter.
```

## Firestore schema (`unityGames` collection)

| Field | Meaning |
|---|---|
| `title`, `description`, `category`, `thumbnailUrl`, `bannerUrl` | hub UI |
| `sceneName` | Addressable scene key (full asset path) |
| `bundleFile` | bundle filename in the GCS bucket (downloaded by the hub) |
| `bundleSizeBytes`, `sizeMb` | display + storage accounting |
| `catalogFile` | Addressables remote catalog filename (set by upload script) |
| `version` | bump to surface "Update" badge |
| `isActive` | hide/show in hub |

## Release a new/updated game (iOS)

1. In Unity: make the scene Addressable, group set to the Remote profile
   (Remote.LoadPath = `https://storage.googleapis.com/inzone-unity-bundles/iOS`).
2. Addressables → Build → New Build → Default Build Script.
3. `./scripts/upload_addressables.sh` — rsyncs ServerData/iOS to GCS and updates
   `catalogFile` on every game doc (needs `scripts/service-account-key.json`).
4. Update the game's Firestore doc (`bundleFile`, `version`, …) — see
   `scripts/seed_unity_games.js` / `update_bundle_fields.js`.

Only when **engine/code** changes (Unity version bump, new C# in the base
project, plugins): re-export iOS (Build Settings → iOS → Build into
`…/inzone/unity_ios_build`), then `./scripts/build_unity_framework.sh` to
rebuild `ios/UnityFramework.framework` (gitignored — each machine builds it).

## Android status

The bridge code is in place but **no Android export exists yet**. Gradle only
wires Unity in when `android/unityLibrary` is present (settings.gradle +
app/build.gradle are conditional; `UnityPlayerActivity.kt` lives in
`android/app/unity-src/`, compiled only with the export). Until then,
`openUnity` on Android returns `UNITY_NOT_AVAILABLE`. To enable: Unity →
Build Settings → Android → Export Project → `android/unityLibrary`, and do an
Addressables build for Android (ServerData/Android + `Android/` bucket path).

## Known limitations

- **First-launch handshake is a fixed 2.5s delay** before sending LoadScene
  (the AddressableSceneLoader GameObject must exist). A proper ready-handshake
  (Unity → native message, then send the pending payload) would remove the race.
- **`bundleFile` covers a single bundle per game.** Shared-group dependency
  bundles still stream from GCS on first load (then cached by Unity). Listing
  all dependency bundle files per game in Firestore would make installs fully
  offline.
- **iOS close = pause + hide**, not unload — Unity memory stays resident after
  the first game launch (UnityFramework unload is unreliable; standard UaaL
  trade-off).
- The C# local-bundle redirect requires the **Unity export to be rebuilt** once
  (AddressableSceneLoader.cs changed) before downloaded bundles are picked up;
  until then games simply stream from GCS as before.
