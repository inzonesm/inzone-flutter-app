// Run via upload_addressables.sh — reads CATALOG_FILE env var and updates
// the catalogFile field on every unityGames doc in Firestore.

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const path = require("path");

const catalogFile = process.env.CATALOG_FILE;
if (!catalogFile) {
  console.error("CATALOG_FILE env var not set. Use upload_addressables.sh.");
  process.exit(1);
}

const serviceAccount = require(path.join(__dirname, "service-account-key.json"));

initializeApp({
  credential: cert(serviceAccount),
  projectId: "inzone-f93e4",
});

const db = getFirestore();

async function update() {
  const snapshot = await db.collection("unityGames").get();
  for (const doc of snapshot.docs) {
    await doc.ref.update({ catalogFile });
    console.log(`Updated ${doc.data().title}: catalogFile = ${catalogFile}`);
  }
  console.log(`\nDone — ${snapshot.size} docs updated.`);
  process.exit(0);
}

update().catch((err) => {
  console.error(err);
  process.exit(1);
});
