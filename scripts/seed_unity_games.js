// Run with: node scripts/seed_unity_games.js
// Seeds the Firestore `unityGames` collection with the 4 demo scenes.
//
// Kept aligned with the LIVE schema (verified 2026-07-06):
//   - sceneName MUST be the full Addressable scene address (the asset path),
//     e.g. "Assets/Scenes/Cockpit/CockpitScene.unity" — NOT a bare name. The
//     app passes it straight to Addressables.LoadSceneAsync.
//   - bundleFile is the content-hashed filename in gs://inzone-unity-bundles/iOS
//     (the app downloads `${bucketBase}/${bundleFile}`); bundleUrl is legacy/unused.
//   - catalogFile is the Addressables remote catalog in the same bucket folder.
//
// NOTE: seeding is idempotent by title — if a game doc with the same title
// exists, it is updated instead of duplicated.

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "service-account-key.json"));

initializeApp({
  credential: cert(serviceAccount),
  projectId: "inzone-f93e4",
});

const db = getFirestore();

const CATALOG_FILE = "catalog_0.1.bin";

const games = [
  {
    title: "Cockpit",
    description: "Step into a futuristic cockpit and take the controls.",
    thumbnailUrl: "",
    bannerUrl: "",
    sceneName: "Assets/Scenes/Cockpit/CockpitScene.unity",
    bundleFile: "cockpitscene_scenes_all_ae7162b306bcc4f32286508fe0f32bf8.bundle",
    bundleSizeBytes: 28158726,
    catalogFile: CATALOG_FILE,
    category: "Simulation",
    sizeMb: 27,
    version: "1.0",
    isActive: true,
  },
  {
    title: "Garden",
    description: "Explore a beautiful virtual garden oasis.",
    thumbnailUrl: "",
    bannerUrl: "",
    sceneName: "Assets/Scenes/Garden/GardenScene.unity",
    bundleFile: "gardenscene_scenes_all_17d729f98543b5d2e7211ce917fd74a0.bundle",
    bundleSizeBytes: 158669778,
    catalogFile: CATALOG_FILE,
    category: "Exploration",
    sizeMb: 151,
    version: "1.0",
    isActive: true,
  },
  {
    title: "Oasis",
    description: "Discover a serene desert oasis environment.",
    thumbnailUrl: "",
    bannerUrl: "",
    sceneName: "Assets/Scenes/Oasis/OasisScene.unity",
    bundleFile: "oasisscene_scenes_all_1b66f5d1e8fef0af0c2f8eddd83f7bde.bundle",
    bundleSizeBytes: 269816228,
    catalogFile: CATALOG_FILE,
    category: "Exploration",
    sizeMb: 258,
    version: "1.0",
    isActive: true,
  },
  {
    title: "Terminal",
    description: "Navigate through a sci-fi space terminal.",
    thumbnailUrl: "",
    bannerUrl: "",
    sceneName: "Assets/Scenes/Terminal/TerminalScene.unity",
    bundleFile: "terminalscene_scenes_all_065ab8d85aa95e7d4f5f2880017a9057.bundle",
    bundleSizeBytes: 70504058,
    catalogFile: CATALOG_FILE,
    category: "Simulation",
    sizeMb: 67,
    version: "1.0",
    isActive: true,
  },
];

async function seed() {
  const collection = db.collection("unityGames");

  for (const game of games) {
    // Idempotent by title: update the existing doc rather than duplicating.
    const existing = await collection.where("title", "==", game.title).limit(1).get();
    if (!existing.empty) {
      await existing.docs[0].ref.update(game);
      console.log(`Updated: ${game.title} -> ${existing.docs[0].id}`);
    } else {
      const doc = await collection.add({ ...game, createdAt: FieldValue.serverTimestamp() });
      console.log(`Created: ${game.title} -> ${doc.id}`);
    }
  }

  console.log(`\nDone! ${games.length} games seeded.`);
  process.exit(0);
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
