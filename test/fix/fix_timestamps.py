#!/usr/bin/env python3
"""
Script to fix timestamp formats in postComments collection
Converts timestamps from millisecond format (like "1756427143002") 
to ISO 8601 format (like "2025-08-14T22:46:27.850000Z")
"""

import os
import sys
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore
import re

def setup_firebase():
    """Initialize Firebase admin SDK"""
    try:
        # Initialize Firebase if not already done
        if not firebase_admin._apps:
            credential_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "key.json")
            if not os.path.isabs(credential_path):
                credential_path = os.path.join(os.path.dirname(__file__), "z-inzoneapi", credential_path)
            
            cred = credentials.Certificate(credential_path)
            firebase_admin.initialize_app(cred)
        
        return firestore.client()
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
        sys.exit(1)

def is_millisecond_timestamp(timestamp_str):
    """Check if timestamp is in millisecond format (like "1756427143002")"""
    if not isinstance(timestamp_str, str):
        return False
    
    # Check if it's all digits and looks like a millisecond timestamp
    if re.match(r'^\d{13}$', timestamp_str):
        try:
            # Try to convert to see if it's a valid timestamp
            timestamp_ms = int(timestamp_str)
            # Check if it's in a reasonable range (after 2020 and before 2100)
            if 1577836800000 <= timestamp_ms <= 4102444800000:  # 2020-01-01 to 2100-01-01
                return True
        except (ValueError, OverflowError):
            pass
    
    return False

def convert_millisecond_to_iso(timestamp_str):
    """Convert millisecond timestamp to ISO format"""
    try:
        timestamp_ms = int(timestamp_str)
        dt = datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc)
        return dt.isoformat()
    except Exception as e:
        print(f"Error converting timestamp {timestamp_str}: {e}")
        return None

def fix_comment_timestamps(db):
    """Fix timestamps in all comments in postComments collection"""
    print("🔍 Scanning postComments collection for timestamp issues...")
    
    collection_ref = db.collection('postComments')
    docs = collection_ref.stream()
    
    total_docs = 0
    updated_docs = 0
    total_comments_fixed = 0
    
    for doc in docs:
        total_docs += 1
        doc_data = doc.to_dict()
        comments = doc_data.get('comments', [])
        
        if not comments:
            continue
        
        comments_updated = False
        comments_fixed_in_doc = 0
        
        for comment in comments:
            timestamp = comment.get('timestamp')
            
            if timestamp and is_millisecond_timestamp(timestamp):
                new_timestamp = convert_millisecond_to_iso(timestamp)
                if new_timestamp:
                    old_timestamp = timestamp
                    comment['timestamp'] = new_timestamp
                    comments_updated = True
                    comments_fixed_in_doc += 1
                    total_comments_fixed += 1
                    print(f"  📝 Fixed timestamp: {old_timestamp} → {new_timestamp}")
        
        # Update the document if any comments were fixed
        if comments_updated:
            try:
                doc.reference.update({'comments': comments})
                updated_docs += 1
                print(f"✅ Updated document {doc.id} - Fixed {comments_fixed_in_doc} comment timestamps")
            except Exception as e:
                print(f"❌ Error updating document {doc.id}: {e}")
    
    print(f"\n📊 Summary:")
    print(f"   Total documents scanned: {total_docs}")
    print(f"   Documents updated: {updated_docs}")
    print(f"   Comments fixed: {total_comments_fixed}")

def scan_for_issues(db):
    """Scan for timestamp format issues without fixing"""
    print("🔍 Scanning for timestamp format issues...")
    
    collection_ref = db.collection('postComments')
    docs = collection_ref.stream()
    
    total_docs = 0
    docs_with_issues = 0
    total_bad_timestamps = 0
    
    for doc in docs:
        total_docs += 1
        doc_data = doc.to_dict()
        comments = doc_data.get('comments', [])
        
        if not comments:
            continue
        
        bad_timestamps_in_doc = 0
        
        for comment in comments:
            timestamp = comment.get('timestamp')
            
            if timestamp and is_millisecond_timestamp(timestamp):
                bad_timestamps_in_doc += 1
                total_bad_timestamps += 1
                print(f"  🚨 Found bad timestamp in doc {doc.id}: {timestamp}")
        
        if bad_timestamps_in_doc > 0:
            docs_with_issues += 1
            print(f"  📄 Document {doc.id} has {bad_timestamps_in_doc} bad timestamps")
    
    print(f"\n📊 Scan Results:")
    print(f"   Total documents: {total_docs}")
    print(f"   Documents with issues: {docs_with_issues}")
    print(f"   Total bad timestamps: {total_bad_timestamps}")
    
    return total_bad_timestamps > 0

def main():
    """Main function"""
    print("🔧 Timestamp Format Fix Tool")
    print("=" * 50)
    
    # Setup Firebase
    db = setup_firebase()
    
    # First scan for issues
    has_issues = scan_for_issues(db)
    
    if not has_issues:
        print("✅ No timestamp issues found!")
        return
    
    # Ask for confirmation
    print("\n" + "=" * 50)
    response = input("Do you want to fix these timestamps? (y/N): ").strip().lower()
    
    if response == 'y' or response == 'yes':
        print("\n🔧 Starting timestamp fixes...")
        fix_comment_timestamps(db)
        print("\n✅ Timestamp fix completed!")
    else:
        print("❌ Operation cancelled.")

if __name__ == "__main__":
    main()
