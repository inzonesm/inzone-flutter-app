import openai
import requests
import firebase_admin
from firebase_admin import credentials, storage

# --- CONFIGURATION ---
OPENAI_API_KEY = "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"  # <-- Replace with your OpenAI API key
FIREBASE_CREDENTIALS_PATH = (
    "key.json"  # <-- Replace with your Firebase service account key path
)
FIREBASE_STORAGE_BUCKET = (
    "your-bucket.appspot.com"  # <-- Replace with your Firebase Storage bucket name
)

character_names = [
    "Sophia Carter",
    "Liam Nguyen",
    "Ava Patel",
    "Noah Kim",
    "Mia Rossi",
    "Lucas Smith",
    "Emma Lee",
    "Oliver Brown",
    "Isabella Garcia",
    "Ethan Chen",
]

# --- SETUP ---
openai.api_key = OPENAI_API_KEY
cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_STORAGE_BUCKET})
bucket = storage.bucket()


def generate_image(prompt, filename):
    """Generate an image using DALL·E and save locally."""
    print(f"Generating image for: {prompt}")
    response = openai.images.generate(
        model="dall-e-3", prompt=prompt, n=1, size="1024x1024"
    )
    image_url = response.data[0].url
    img_data = requests.get(image_url).content
    with open(filename, "wb") as handler:
        handler.write(img_data)
    print(f"Image saved locally as {filename}")
    return filename


def upload_to_firebase(local_path, storage_path):
    """Upload file to Firebase Storage."""
    blob = bucket.blob(storage_path)
    blob.upload_from_filename(local_path)
    blob.make_public()
    print(f"Uploaded to Firebase Storage: {blob.public_url}")
    return blob.public_url


def main():
    for name in character_names:
        prompt = f"Realistic portrait of {name}, high quality, 1024x1024"
        filename = f"{name.replace(' ', '_')}.png"
        storage_path = f"character_profiles/{filename}"

        # Generate image
        generate_image(prompt, filename)

        # Upload to Firebase Storage
        upload_to_firebase(filename, storage_path)


if __name__ == "__main__":
    main()
