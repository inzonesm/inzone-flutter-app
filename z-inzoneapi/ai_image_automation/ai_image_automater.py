"""
Script to review and optionally regenerate profile images for 'popularCharacters' in Firestore.
- Fetches all documents from the 'popularCharacters' collection.
- Displays each character's name and current profile picture URL.
- Prompts the user to approve or regenerate the image.
- If approved, records the character in an approved list (stored in approved_characters.txt).
- If not approved, generates a new image via DALL·E and uploads it to Firebase Storage.
- Updates the Firestore document with the new image URL.

Requirements:
    pip install openai firebase-admin requests
"""

import openai
import requests
import json
import traceback
import firebase_admin
from firebase_admin import credentials, storage, firestore
import os
import webbrowser

# === CONFIGURATION ===
OPENAI_API_KEY = "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"
FIREBASE_CREDENTIALS_PATH = "key.json"
FIREBASE_STORAGE_BUCKET = "inzone-f93e4.appspot.com"

# === SETUP ===
openai.api_key = OPENAI_API_KEY
cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {"storageBucket": FIREBASE_STORAGE_BUCKET})
db = firestore.client()
bucket = storage.bucket()

APPROVED_FILE = "approved_characters.txt"


def load_approved_list():
    if not os.path.exists(APPROVED_FILE):
        return set()
    with open(APPROVED_FILE, "r", encoding="utf-8") as f:
        return set(line.strip() for line in f.readlines() if line.strip())


def save_approved_list(approved):
    with open(APPROVED_FILE, "w", encoding="utf-8") as f:
        for name in sorted(approved):
            f.write(name + "\n")


def generate_image(prompt, filename):
    """Generate an image using DALL·E."""
    print(f"\nGenerating new image for: {prompt}")
    try:
        response = openai.images.generate(
            model="dall-e-3",
            prompt=prompt,
            n=1,
            size="1024x1024"
        )
        image_url = response.data[0].url
        img_data = requests.get(image_url).content
        with open(filename, "wb") as handler:
            handler.write(img_data)
        print(f"Image saved locally as {filename}")
        return filename
    except Exception as e:
        # Try to build a helpful, actionable error message for OpenAI errors.
        # The OpenAI Python client raises subclasses of OpenAIError which may
        # include an `error` attribute or `response` with more details. We
        # attempt to extract structured information where available.
        details = []
        details.append(f"Exception type: {type(e).__name__}")
        # common attributes on OpenAI errors
        http_status = getattr(e, "http_status", None)
        if http_status:
            details.append(f"HTTP status: {http_status}")

        err_obj = getattr(e, "error", None)
        if err_obj:
            try:
                # If it's a dict-like error object
                if isinstance(err_obj, dict):
                    details.append(f"openai.error: {json.dumps(err_obj)}")
                    # Add specific code/message if present
                    code = err_obj.get("code") if isinstance(err_obj, dict) else None
                    message = err_obj.get("message") if isinstance(err_obj, dict) else None
                    if code:
                        details.append(f"error code: {code}")
                    if message:
                        details.append(f"error message: {message}")
                else:
                    details.append(f"openai.error: {str(err_obj)}")
            except Exception:
                details.append(f"Could not parse error object: {repr(err_obj)}")

        # Some OpenAI error objects embed a `.response` with body/text
        resp = getattr(e, "response", None)
        if resp:
            try:
                # Try to get a reasonable string representation
                body = getattr(resp, "body", None) or getattr(resp, "text", None) or str(resp)
                details.append(f"response: {body}")
            except Exception:
                details.append("Could not extract response body from exception.")

        # Fallback to the exception string and traceback
        details.append(f"raw exception: {str(e)}")
        details.append("Traceback:\n" + traceback.format_exc())

        # Build a user-facing message with guidance on next steps.
        user_msg_lines = [
            "Failed to generate image using the OpenAI Images API.",
            "The API returned an error. Common causes include exhausted billing limits, invalid API key, or malformed prompt/parameters.",
            "Helpful details (for debugging):",
        ]
        user_msg_lines.extend(["  " + line for line in details])
        user_msg_lines.extend([
            "\nSuggested next actions:",
            "  1) Verify your OpenAI API key is correct and has billing enabled.",
            "  2) Check your OpenAI billing & usage dashboard: https://platform.openai.com/account/usage and https://platform.openai.com/account/billing/summary",
            "  3) If you see a 'Billing hard limit' or similar in the dashboard, increase your limit or contact OpenAI support.",
            "  4) If you believe this is a false positive (you have credits), wait a few minutes and retry or contact OpenAI support with the error details below.",
            "\nIf you want to debug further, copy the details above and include them when contacting support."
        ])

        full_message = "\n".join(user_msg_lines)
        print(full_message)
        # Raise a RuntimeError with the informative message so callers can handle it.
        raise RuntimeError(full_message) from e


def upload_to_firebase(local_path, storage_path):
    """Upload file to Firebase Storage."""
    blob = bucket.blob(storage_path)
    blob.upload_from_filename(local_path)
    blob.make_public()
    print(f"Uploaded to Firebase Storage: {blob.public_url}")
    return blob.public_url


def update_firestore(doc_id, new_url):
    """Update Firestore with new image URL."""
    doc_ref = db.collection("popularCharacters").document(doc_id)
    doc_ref.update({"profile_picture_url": new_url})
    print(f"Firestore updated for {doc_id}.")


def review_character(doc):
    """Review and optionally regenerate image for one character."""
    data = doc.to_dict()
    name = data.get("name")
    url = data.get("profile_picture_url")

    print(f"\n=== Reviewing {name} ===")
    print(f"Current Image URL: {url}")

    # Open the image in browser for user to view
    try:
        webbrowser.open(url)
    except:
        print("Couldn't open browser automatically. Please view the URL manually.")

    choice = input("Approve this image? (y/n): ").strip().lower()
    if choice == "y":
        print(f"Approved {name}")
        return "approved"

    print(f"⚙️ Regenerating image for {name}...")
    custom_prompt = input(
        f"Enter a custom prompt for {name} (leave blank for default '{name} portrait'): "
    ).strip()
    final_prompt = custom_prompt if custom_prompt else f"Portrait of {name}, high quality digital art, 1024x1024"

    local_filename = f"{name.replace(' ', '_')}.png"
    storage_path = f"popularCharacters/{local_filename}"

    # Generate, upload, update Firestore
    try:
        generate_image(final_prompt, local_filename)
        new_url = upload_to_firebase(local_filename, storage_path)
        update_firestore(doc.id, new_url)
        os.remove(local_filename)
        print(f"New image generated and updated for {name}")
        return "regenerated"
    except RuntimeError as e:
        # A RuntimeError is raised by generate_image with helpful details.
        print("Error while generating image:\n", str(e))
        print("Skipping regeneration for this character. See messages above for next steps.")
        # Keep the character unapproved so it can be retried later.
        return "error"
    except Exception as e:
        # Catch-all to avoid crashing the entire run
        print(f"Unexpected error while regenerating image for {name}: {e}")
        return "error"

u
def main():
    print("Fetching all popularCharacters from Firestore...")
    docs = db.collection("popularCharacters").stream()

    approved_list = load_approved_list()
    print(f"Loaded {len(approved_list)} approved characters from cache.")

    for doc in docs:
        data = doc.to_dict()
        name = data.get("name", "[Unnamed Character]")

        # Skip if already approved
        if name in approved_list:
            print(f"Skipping {name} (already approved).")
            continue

        result = review_character(doc)

        if result == "approved":
            approved_list.add(name)
            save_approved_list(approved_list)

    print("\nAll characters processed.")
    save_approved_list(approved_list)
    print(f"Approved list saved to {APPROVED_FILE}.")


if __name__ == "__main__":
    main()
