inzone-flutter-app/functions/index.js
```
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function: incrementPopularity
 * Triggered when a new selection document is created under a character.
 * Increments the 'popularity' field of the character document.
 *
 * Firestore structure:
 * - characters/{characterId}/selections/{selectionId}
 * - characters/{characterId} (document with 'popularity' field)
 */
exports.incrementPopularity = functions.firestore
  .document('characters/{characterId}/selections/{selectionId}')
  .onCreate(async (snap, context) => {
    const characterId = context.params.characterId;
    const characterRef = admin.firestore().collection('characters').doc(characterId);

    try {
      await characterRef.update({
        popularity: admin.firestore.FieldValue.increment(1)
      });
      console.log(`Popularity incremented for character: ${characterId}`);
    } catch (error) {
      console.error(`Failed to increment popularity for character: ${characterId}`, error);
    }
  });
