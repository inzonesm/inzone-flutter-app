"""
Script to automate DALL-E (OpenAI) image generation and Firebase upload
for AI character profile images.

Requirements:
- openai
- firebase-admin
- requests

Install dependencies:
    pip install openai firebase-admin requests

Configuration:
- Set your OpenAI API key, Firebase service account path, and storage bucket below.
- Set the character name and prompt for image generation.

Usage:
    python generate_and_upload_ai_character_image.py
"""

import openai
import requests
import firebase_admin
from firebase_admin import credentials, storage, firestore
import os

# === CONFIGURATION ===
OPENAI_API_KEY = "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"  # <-- Your OpenAI API key here
FIREBASE_CREDENTIALS_PATH = "inzone-flutter-app/z-inzoneapi/ai_image_automation/serviceAccountKey.json"  # <-- Path to your Firebase service account JSON
FIREBASE_STORAGE_BUCKET = (
    "inzone-f93e4.appspot.com"  # <-- Your Firebase Storage bucket name
)
CHARACTER_NAME = "explorer"  # <-- Character name
PROMPT = "A futuristic explorer in a sleek spacesuit, standing on an alien planet, digital art, high resolution, square format"


def generate_image(prompt, filename):
    """Generate an image using OpenAI's DALL-E and save it locally."""
    openai.api_key = OPENAI_API_KEY
    print(f"Generating image for prompt: {prompt}")
    response = openai.images.generate(
        model="dall-e-3", prompt=prompt, n=1, size="1024x1024"
    )
    image_url = response.data[0].url
    img_data = requests.get(image_url).content
    with open(filename, "wb") as handler:
        handler.write(img_data)
    print(f"Image saved as {filename}")
    return filename


def upload_to_firebase(local_path, storage_path):
    """Upload image to Firebase Storage and return the public URL."""
    print(f"Uploading {local_path} to Firebase Storage at {storage_path}...")
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_STORAGE_BUCKET})
    bucket = storage.bucket()
    blob = bucket.blob(storage_path)
    blob.upload_from_filename(local_path)
    blob.make_public()
    print(f"Image uploaded. Public URL: {blob.public_url}")
    return blob.public_url


def update_firestore(character_id, image_url):
    """Update Firestore document for the character with the new image URL in popularCharacters."""
    print(f"Updating Firestore for character '{character_id}' in popularCharacters...")
    db = firestore.client()
    doc_ref = db.collection("popularCharacters").document(character_id)
    doc_ref.update({"profile_picture_url": image_url})
    print(f"Firestore updated for '{character_id}'.")


def main():
    local_filename = f"{CHARACTER_NAME}.png"
    storage_path = f"ai_characters/{local_filename}"

    # 1. Generate image
    generate_image(PROMPT, local_filename)

    # 2. Upload to Firebase Storage
    firebase_image_url = upload_to_firebase(local_filename, storage_path)

    # 3. Update Firestore
    update_firestore(CHARACTER_NAME, firebase_image_url)

    # 4. Clean up local file
    os.remove(local_filename)
    print("Local image file removed.")

    print(
        f"Done! '{CHARACTER_NAME}' profile image generated, uploaded, and Firestore updated."
    )


if __name__ == "__main__":
    main()
