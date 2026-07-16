// Registers (or updates) the AnyRPG FeaturesDemo doc in the `unityGames`
// collection. Run AFTER the Addressables content build is uploaded:
//   node scripts/register_anyrpg.mjs <entryBundleFile> <entryBundleSizeBytes> [catalogFile]
//
// sceneName is the boot scene's Addressable address (created by AnyRPGHubSetup
// in the Unity project) — AnyRPG bootstraps itself from there (init -> main
// menu -> starting zone), so the hub only ever launches this one address.
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const [bundleFile, bundleSizeBytes, catalogFile = 'catalog_0.1.bin'] = process.argv.slice(2);
if (!bundleFile || !bundleSizeBytes) {
  console.error('usage: node scripts/register_anyrpg.mjs <entryBundleFile> <bytes> [catalogFile]');
  process.exit(1);
}

const sa = JSON.parse(readFileSync(new URL('./service-account-key.json', import.meta.url), 'utf8'));
initializeApp({ credential: cert(sa), projectId: 'inzone-f93e4' });
const db = getFirestore();

const doc = {
  title: 'AnyRPG: Features Demo',
  description:
    'A full open-source RPG — quests, combat, dialog, and inventory. Built on the AnyRPG engine (MIT).',
  category: 'RPG',
  thumbnailUrl: '',
  bannerUrl: '',
  sceneName: 'Assets/Scenes/FeaturesDemoGame/FeaturesDemoGame.unity',
  bundleFile,
  bundleSizeBytes: Number(bundleSizeBytes),
  catalogFile,
  sizeMb: Math.max(1, Math.round(Number(bundleSizeBytes) / 1e6)),
  version: '1.0',
  isActive: true,
};

const ref = db.collection('unityGames').doc('anyrpg-features-demo');
const existing = await ref.get();
await ref.set(
  { ...doc, ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp() }) },
  { merge: true },
);
console.log(`${existing.exists ? 'Updated' : 'Created'} unityGames/anyrpg-features-demo`);
console.log(`  sceneName : ${doc.sceneName}`);
console.log(`  bundleFile: ${doc.bundleFile} (${doc.sizeMb} MB)`);
console.log(`  catalog   : ${doc.catalogFile}`);
process.exit(0);
