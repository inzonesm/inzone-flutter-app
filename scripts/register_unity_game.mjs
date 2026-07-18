// Registers (or updates) a curated Unity game doc in the `unityGames`
// collection. Generic successor to register_anyrpg.mjs. Run AFTER the
// Addressables content build is uploaded:
//
//   node scripts/register_unity_game.mjs <docId> \
//     --title "Night Swarm" \
//     --scene "Assets/NightSwarm/Scenes/Game/Main Menu.unity" \
//     --bundle <entryBundleFile> --bytes <entryBundleSizeBytes> \
//     [--catalog catalog_0.1.bin] [--category Action] [--description "..."] \
//     [--version 1.0]
//
// sceneName is the entry scene's Addressable address (a full asset path for
// curated games) — the hub launches exactly this address.
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

const [docId, ...rest] = process.argv.slice(2);
const flags = {};
for (let i = 0; i < rest.length; i += 2) {
  if (!rest[i].startsWith('--') || rest[i + 1] === undefined) {
    console.error(`Bad argument pair: ${rest[i]} ${rest[i + 1] ?? ''}`);
    process.exit(1);
  }
  flags[rest[i].slice(2)] = rest[i + 1];
}

if (!docId || !flags.title || !flags.scene || !flags.bundle || !flags.bytes) {
  console.error(
    'usage: node scripts/register_unity_game.mjs <docId> --title T --scene S --bundle B --bytes N [--catalog C] [--category G] [--description D] [--version V]',
  );
  process.exit(1);
}

const sa = JSON.parse(readFileSync(new URL('./service-account-key.json', import.meta.url), 'utf8'));
initializeApp({ credential: cert(sa), projectId: 'inzone-f93e4' });
const db = getFirestore();

const bytes = Number(flags.bytes);
const doc = {
  title: flags.title,
  description: flags.description ?? '',
  category: flags.category ?? 'Arcade',
  thumbnailUrl: '',
  bannerUrl: '',
  sceneName: flags.scene,
  bundleFile: flags.bundle,
  bundleSizeBytes: bytes,
  catalogFile: flags.catalog ?? 'catalog_0.1.bin',
  sizeMb: Math.max(1, Math.round(bytes / 1e6)),
  version: flags.version ?? '1.0',
  isActive: true,
};

const ref = db.collection('unityGames').doc(docId);
const existing = await ref.get();
await ref.set(
  { ...doc, ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp() }) },
  { merge: true },
);
console.log(`${existing.exists ? 'Updated' : 'Created'} unityGames/${docId}`);
console.log(`  sceneName : ${doc.sceneName}`);
console.log(`  bundleFile: ${doc.bundleFile} (${doc.sizeMb} MB)`);
console.log(`  catalog   : ${doc.catalogFile}`);
process.exit(0);
