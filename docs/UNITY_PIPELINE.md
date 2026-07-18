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

## AnyRPG (curated compile-in game) — integrated 2026-07

The first full game with its own C#: the AnyRPG engine (MIT) is **compiled into
the UnityFramework** (code can't stream — IL2CPP + App Store 2.5.2); only its
scenes stream as Addressables. Doc: `unityGames/anyrpg-features-demo`,
`sceneName = Assets/Scenes/FeaturesDemoGame/FeaturesDemoGame.unity` — a boot
scene carrying the FeaturesDemoGameManager prefab, whose name matches the
variant's `initializationScene` so AnyRPG auto-runs init → Main Menu → starting
zone. Its internal scene loads go through `AddressableSceneBridge` (conversion
lives in the AnyRPG source, gated by the `INZONE_ADDRESSABLES` define; addresses
derive as `Assets/Scenes/{SceneFile}/{SceneFile}.unity`).

Mobile adaptation (2026-07-18, device-verified): touch→mouse shim in AnyRPG's
InputManager (tap-to-move/-target, drag-orbit, pinch-zoom; tap on an
interactable also runs the walk-up-and-interact flow), click-to-move defaulted
on via the FeaturesDemoGameManager prefab override, runtime phone-UI scaling +
safe-area via the hub's `AnyRpgMobileUIScaler` (scene-gated to AnyRPG — other
games are never touched), and OOM hardening: per-texture iOS ASTC overrides +
1024 cap and audio streaming via `AnyRpgIosAssetOptimizer`, HDR/SSAO off +
shadows 512@30m + mipmap streaming in the Mobile High tier, and
`Resources.UnloadUnusedAssets` on zone transitions + `Application.lowMemory`.
Class-name gotcha fixed the same day: AnyRPG's string-based
`ScriptableObject.CreateInstance("Ability")` broke when Night Swarm's `Ability`
class joined the shared assembly — curated-game class names must not shadow
names AnyRPG creates by string (see Food.cs, now the typed generic).

Headless entries in the Unity project (`Assets/Editor/`):
- `InzoneAddressablesBuild.BuildContent` — Addressables content build (bundles + remote catalog)
- `AnyRPGHubSetup.ConfigureBatch` — boot scene + AnyRPG Addressables groups (idempotent)
- `AnyRpgIosAssetOptimizer.OptimizeBatch` — iOS texture/audio memory overrides (idempotent)
- `InzoneIOSExport.ExportBatch` — iOS export to `…/inzone/unity_ios_build_anyrpg`
  (then `UNITY_BUILD_DIR=<that> ./scripts/build_unity_framework.sh`)

Register/update the Firestore doc after a content upload:
`node scripts/register_anyrpg.mjs <entryBundleFile> <bytes> [catalogFile]`.

## Night Swarm (curated compile-in game) — integrated 2026-07

The second compile-in game: VampireSurvivorsClone (MIT, Matthias Broske),
renamed **Night Swarm** (暗夜狂潮) — "Vampire Survivors" is Poncle's trademark.
2D survivor-roguelite, touch-native. Source clone with the integration edits:
`/Users/yxydw/Documents/inzone/VampireSurvivorsClone`; imported under
`Assets/NightSwarm/` in the Unity project (TMP essentials, Adaptive
Performance, and the editor-only Character Set Generation scene excluded).

- Doc: `unityGames/night-swarm`,
  `sceneName = Assets/NightSwarm/Scenes/Game/Main Menu.unity`.
- Scene transitions go through `InzoneSceneGateway` (in the game's Scripts;
  gated by `INZONE_ADDRESSABLES` like AnyRPG's bridge). Both scenes sit in ONE
  PackTogether remote group so their shared bundle never unloads mid-game —
  the static `CrossSceneData.CharacterBlueprint` carried across the
  menu→level transition survives (AnyRPG bundle-lifetime lesson).
- Uses com.unity.localization (en/zh/zh-Hant): locale/table assets are
  Addressables entries mirrored by `NightSwarmHubSetup` (labels `Locale`,
  `Locale-{code}`, `Preload`); the game's LocalizationSettings is the
  project-wide active one. LiberationSans SDF lives in the shared
  `SharedFonts_Remote` group.
- Host settings adopted: layers 14/15/16/27/28 (game's 6–10 remapped in all
  YAML incl. LayerMask bitmasks), sorting layers Background/Foreground
  (verbatim uniqueIDs), `activeInputHandler = Both` (game uses legacy
  StandaloneInputModule + Input.mousePosition in its touch joystick).
- Licensing: see `Assets/NightSwarm/THIRD-PARTY-NOTICES.md`. Pre-commercial
  gates: EmojiOne in host TMP defaults (separate task), and confirm the
  author's rights to the internship-era code (Gamania) before commercial ship.

Headless entry (`Assets/Editor/NightSwarmHubSetup.cs`):
`NightSwarmHubSetup.ConfigureBatch` — group + localization entries (idempotent).

Register/update the Firestore doc after a content upload:
`node scripts/register_unity_game.mjs night-swarm --title "Night Swarm" ...`
(generic successor to register_anyrpg.mjs).

Content-only games (no custom C#) do NOT need any of this — they publish
self-serve through the dev portal (inzone-games repo, `/api/unity-publish`)
built with the inzone Unity Game Kit template.
