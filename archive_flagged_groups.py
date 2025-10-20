import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Initialize Firestore
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Load audit report
df = pd.read_csv("group_audit_report.csv")

# Archive groups flagged as duplicate, inactive, or low_engagement
for _, row in df.iterrows():
    if row.get("flags"):
        group_id = row["id"]
        group_ref = db.collection("groupChats").document(group_id)
        try:
            group_ref.update({"archived": True})
            print(f"Archived group: {row['name']} ({group_id}) - Flags: {row['flags']}")
        except Exception as e:
            print(f"Failed to archive group: {row['name']} ({group_id}) - Error: {e}")

print("Archiving complete.")
