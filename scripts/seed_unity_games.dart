/// Run with: dart run scripts/seed_unity_games.dart
///
/// Seeds the Firestore `unityGames` collection with the 4 demo scenes.
/// Requires the Firebase CLI to be authenticated.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:inzone/config/firebase_options.dart';

const _bucketBase =
    'https://firebasestorage.googleapis.com/v0/b/inzone-unity-bundles/o/iOS%2F';

const _games = [
  {
    'title': 'Cockpit',
    'description': 'Step into a futuristic cockpit and take the controls.',
    'thumbnailUrl': '', // Add thumbnail URL later
    'bannerUrl': '', // Add banner URL later
    'bundleUrl':
        '${_bucketBase}cockpit_scenes_all_311c705347b3b64485e21d4f8eea801b.bundle?alt=media',
    'sceneName': 'Cockpit',
    'category': 'Simulation',
    'sizeMb': 27,
    'version': '1.0',
    'isActive': true,
  },
  {
    'title': 'Garden',
    'description': 'Explore a beautiful virtual garden oasis.',
    'thumbnailUrl': '',
    'bannerUrl': '',
    'bundleUrl':
        '${_bucketBase}garden_scenes_all_73b5d808a0d9856894a2bcf1b326c1cd.bundle?alt=media',
    'sceneName': 'Garden',
    'category': 'Exploration',
    'sizeMb': 151,
    'version': '1.0',
    'isActive': true,
  },
  {
    'title': 'Oasis',
    'description': 'Discover a serene desert oasis environment.',
    'thumbnailUrl': '',
    'bannerUrl': '',
    'bundleUrl':
        '${_bucketBase}oasis_scenes_all_ec94f2a9797c76d033ea60ddc6b1910a.bundle?alt=media',
    'sceneName': 'Oasis',
    'category': 'Exploration',
    'sizeMb': 268,
    'version': '1.0',
    'isActive': true,
  },
  {
    'title': 'Terminal',
    'description': 'Navigate through a sci-fi space terminal.',
    'thumbnailUrl': '',
    'bannerUrl': '',
    'bundleUrl':
        '${_bucketBase}terminal_scenes_all_7141bd93d81e4bd10b5febf072670823.bundle?alt=media',
    'sceneName': 'Terminal',
    'category': 'Simulation',
    'sizeMb': 67,
    'version': '1.0',
    'isActive': true,
  },
];

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final collection = firestore.collection('unityGames');

  for (final game in _games) {
    final doc = await collection.add({
      ...game,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('Created: ${game['title']} -> ${doc.id}');
  }

  print('\nDone! ${_games.length} games seeded.');
}
