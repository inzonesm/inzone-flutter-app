// Run with: node scripts/seed_unity_games.js
// Seeds the Firestore `unityGames` collection with the 4 demo scenes.

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "service-account-key.json"));

initializeApp({
  credential: cert(serviceAccount),
  projectId: "inzone-f93e4",
});

const db = getFirestore();
const bucketBase =
  "https://firebasestorage.googleapis.com/v0/b/inzone-unity-bundles/o/iOS%2F";

const games = [
  {
    title: "Cockpit",
    description: "Step into a futuristic cockpit and take the controls.",
    thumbnailUrl: "",
    bannerUrl: "",
    bundleUrl: `${bucketBase}cockpit_scenes_all_311c705347b3b64485e21d4f8eea801b.bundle?alt=media`,
    sceneName: "Cockpit",
    category: "Simulation",
    sizeMb: 27,
    version: "1.0",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    title: "Garden",
    description: "Explore a beautiful virtual garden oasis.",
    thumbnailUrl: "",
    bannerUrl: "",
    bundleUrl: `${bucketBase}garden_scenes_all_73b5d808a0d9856894a2bcf1b326c1cd.bundle?alt=media`,
    sceneName: "Garden",
    category: "Exploration",
    sizeMb: 151,
    version: "1.0",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    title: "Oasis",
    description: "Discover a serene desert oasis environment.",
    thumbnailUrl: "",
    bannerUrl: "",
    bundleUrl: `${bucketBase}oasis_scenes_all_ec94f2a9797c76d033ea60ddc6b1910a.bundle?alt=media`,
    sceneName: "Oasis",
    category: "Exploration",
    sizeMb: 268,
    version: "1.0",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    title: "Terminal",
    description: "Navigate through a sci-fi space terminal.",
    thumbnailUrl: "",
    bannerUrl: "",
    bundleUrl: `${bucketBase}terminal_scenes_all_7141bd93d81e4bd10b5febf072670823.bundle?alt=media`,
    sceneName: "Terminal",
    category: "Simulation",
    sizeMb: 67,
    version: "1.0",
    isActive: true,
    createdAt: FieldValue.serverTimestamp(),
  },
];

async function seed() {
  const collection = db.collection("unityGames");

  for (const game of games) {
    const doc = await collection.add(game);
    console.log(`Created: ${game.title} -> ${doc.id}`);
  }

  console.log(`\nDone! ${games.length} games seeded.`);
  process.exit(0);
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
