import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from datetime import datetime, timedelta

# Initialize Firestore
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Parameters
INACTIVE_DAYS = 30
LOW_MEMBER_THRESHOLD = 5


def fetch_groups():
    groups_ref = db.collection("groupChats")
    docs = groups_ref.stream()
    groups = []
    for doc in docs:
        data = doc.to_dict()
        # Get member count from participants array
        member_count = len(data.get("participants", []))
        # Get last message date from messages array
        last_message_date = ""
        messages = data.get("messages", [])
        timestamps = []
        for m in messages:
            ts = m.get("timestamp")
            # Only use Firestore timestamp objects
            if hasattr(ts, "timestamp"):
                timestamps.append(ts)
            elif isinstance(ts, datetime):
                timestamps.append(ts)
            # Optionally, parse string timestamps if you know the format
        if timestamps:
            latest_timestamp = max(timestamps)
            last_message_date = str(latest_timestamp)
        else:
            last_message_date = str(data.get("updatedAt", ""))
        groups.append(
            {
                "id": doc.id,
                "name": data.get("name", ""),
                "category": data.get("groupChatCategory", ""),
                "member_count": member_count,
                "last_message_date": last_message_date,
            }
        )
    return groups


def audit_groups(groups):
    seen_names = set()
    report = []
    today = datetime.utcnow()
    for group in groups:
        flags = []
        # Duplicate check
        if group["name"].lower() in seen_names:
            flags.append("duplicate")
        else:
            seen_names.add(group["name"].lower())
        # Inactive check
        try:
            last_msg = datetime.strptime(
                group["last_message_date"], "%Y-%m-%dT%H:%M:%S"
            )
            if last_msg < today - timedelta(days=INACTIVE_DAYS):
                flags.append("inactive")
        except Exception:
            flags.append("no_last_message_date")
        # Low engagement check
        if group["member_count"] < LOW_MEMBER_THRESHOLD:
            flags.append("low_engagement")
        report.append(
            {
                "id": group["id"],
                "name": group["name"],
                "category": group["category"],
                "member_count": group["member_count"],
                "last_message_date": group["last_message_date"],
                "flags": ",".join(flags),
            }
        )
    return report


def save_report(report):
    df = pd.DataFrame(report)
    df.to_csv("group_audit_report.csv", index=False)
    print("Audit report saved to group_audit_report.csv")


if __name__ == "__main__":
    groups = fetch_groups()
    print("Fetched groups:", groups)  # Debug print to show fetched data
    report = audit_groups(groups)
    save_report(report)
