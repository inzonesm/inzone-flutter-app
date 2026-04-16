// Run with: node scripts/update_bundle_fields.js
// Updates existing Firestore `unityGames` docs with bundleFile and bundleSizeBytes fields.

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const path = require("path");

const serviceAccount = require(path.join(__dirname, "service-account-key.json"));

initializeApp({
  credential: cert(serviceAccount),
  projectId: "inzone-f93e4",
});

const db = getFirestore();

// Maps game title → { bundleFile, bundleSizeBytes }
// These match what's currently uploaded in the GCS bucket.
const bundleData = {
  Cockpit: {
    bundleFile: "cockpitscene_scenes_all_ae7162b306bcc4f32286508fe0f32bf8.bundle",
    bundleSizeBytes: 28158726,
  },
  Garden: {
    bundleFile: "gardenscene_scenes_all_17d729f98543b5d2e7211ce917fd74a0.bundle",
    bundleSizeBytes: 158669778,
  },
  Oasis: {
    bundleFile: "oasisscene_scenes_all_da1631bcfcfc7930a5cb20c32f9d400e.bundle",
    bundleSizeBytes: 281274541,
  },
  Terminal: {
    bundleFile: "terminalscene_scenes_all_065ab8d85aa95e7d4f5f2880017a9057.bundle",
    bundleSizeBytes: 70504058,
  },
};

async function update() {
  const snapshot = await db.collection("unityGames").get();
  let updated = 0;

  for (const doc of snapshot.docs) {
    const title = doc.data().title;
    const data = bundleData[title];
    if (data) {
      await doc.ref.update(data);
      console.log(`Updated: ${title} (${doc.id}) → ${data.bundleFile}`);
      updated++;
    } else {
      console.log(`Skipped: ${title} (${doc.id}) — no bundle data`);
    }
  }

  console.log(`\nDone! ${updated} docs updated.`);
  process.exit(0);
}

update().catch((err) => {
  console.error(err);
  process.exit(1);
});
