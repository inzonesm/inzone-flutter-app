#!/usr/bin/env python3
"""
Script to fix comment IDs in postComments collection
Assigns proper IDs to comments that don't have them and fixes parentCommentId references
"""

import os
import sys
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, firestore
import time
import random

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

def generate_comment_id():
    """Generate a proper comment ID using the same logic as the frontend"""
    timestamp = int(time.time() * 1000)
    microsecond_component = random.randint(1000, 1999)
    return f"{timestamp}{microsecond_component}"

def fix_comment_ids(db, target_post_id=None):
    """Fix comment IDs in all or specific postComments documents"""
    print("🔍 Scanning postComments collection for ID issues...")
    
    collection_ref = db.collection('postComments')
    
    if target_post_id:
        # Fix specific document only
        docs = [collection_ref.document(target_post_id).get()]
        print(f"🎯 Targeting specific document: {target_post_id}")
    else:
        # Fix all documents
        docs = collection_ref.stream()
    
    total_docs = 0
    updated_docs = 0
    total_comments_fixed = 0
    
    for doc in docs:
        if not doc.exists:
            if target_post_id:
                print(f"❌ Document {target_post_id} does not exist")
            continue
            
        total_docs += 1
        doc_data = doc.to_dict()
        comments = doc_data.get('comments', [])
        
        if not comments:
            continue
        
        comments_updated = False
        comments_fixed_in_doc = 0
        
        # First pass: Assign IDs to comments that don't have them
        for i, comment in enumerate(comments):
            comment_id = comment.get('id')
            
            # Check if comment needs an ID
            if not comment_id or comment_id == '' or comment_id is None:
                new_id = generate_comment_id()
                comment['id'] = new_id
                comments_updated = True
                comments_fixed_in_doc += 1
                total_comments_fixed += 1
                print(f"  📝 Assigned ID {new_id} to comment at index {i}")
                
                # Small delay to ensure unique IDs
                time.sleep(0.001)
        
        # Second pass: Fix parentCommentId references that might be timestamps or invalid
        for comment in comments:
            parent_id = comment.get('parentCommentId')
            is_reply = comment.get('isReply', False)
            
            if is_reply and parent_id:
                # Check if parentCommentId is actually a valid comment ID
                parent_found = False
                for potential_parent in comments:
                    if potential_parent.get('id') == parent_id:
                        parent_found = True
                        break
                
                if not parent_found:
                    # Try to find the parent by timestamp or other means
                    print(f"  ⚠️ Reply with ID {comment.get('id')} has invalid parentCommentId: {parent_id}")
                    
                    # If parentCommentId looks like a timestamp, try to find the matching comment
                    if parent_id.isdigit() and len(parent_id) >= 13:
                        # Look for a comment with matching timestamp
                        for potential_parent in comments:
                            parent_timestamp = potential_parent.get('timestamp', '')
                            if parent_timestamp and parent_id in parent_timestamp:
                                comment['parentCommentId'] = potential_parent.get('id')
                                comments_updated = True
                                print(f"  ✅ Fixed parentCommentId for reply {comment.get('id')}: {parent_id} -> {potential_parent.get('id')}")
                                break
                        else:
                            # If we can't find a matching parent, remove the parentCommentId
                            comment['parentCommentId'] = None
                            comment['isReply'] = False
                            comments_updated = True
                            print(f"  🔧 Removed invalid parentCommentId for comment {comment.get('id')}")
        
        # Update the document if any comments were fixed
        if comments_updated:
            try:
                doc.reference.update({'comments': comments})
                updated_docs += 1
                print(f"✅ Updated document {doc.id} - Fixed {comments_fixed_in_doc} comment IDs")
            except Exception as e:
                print(f"❌ Error updating document {doc.id}: {e}")
    
    print(f"\n📊 Summary:")
    print(f"   Total documents scanned: {total_docs}")
    print(f"   Documents updated: {updated_docs}")
    print(f"   Comments fixed: {total_comments_fixed}")

def scan_for_id_issues(db, target_post_id=None):
    """Scan for comment ID issues without fixing"""
    print("🔍 Scanning for comment ID issues...")
    
    collection_ref = db.collection('postComments')
    
    if target_post_id:
        docs = [collection_ref.document(target_post_id).get()]
        print(f"🎯 Scanning specific document: {target_post_id}")
    else:
        docs = collection_ref.stream()
    
    total_docs = 0
    docs_with_issues = 0
    total_bad_ids = 0
    total_bad_parent_refs = 0
    
    for doc in docs:
        if not doc.exists:
            if target_post_id:
                print(f"❌ Document {target_post_id} does not exist")
            continue
            
        total_docs += 1
        doc_data = doc.to_dict()
        comments = doc_data.get('comments', [])
        
        if not comments:
            continue
        
        bad_ids_in_doc = 0
        bad_parent_refs_in_doc = 0
        
        # Check for missing IDs
        for i, comment in enumerate(comments):
            comment_id = comment.get('id')
            
            if not comment_id or comment_id == '' or comment_id is None:
                bad_ids_in_doc += 1
                total_bad_ids += 1
                print(f"  🚨 Comment at index {i} in doc {doc.id} has no ID")
        
        # Check for invalid parentCommentId references
        for comment in comments:
            parent_id = comment.get('parentCommentId')
            is_reply = comment.get('isReply', False)
            
            if is_reply and parent_id:
                # Check if parentCommentId is actually a valid comment ID
                parent_found = False
                for potential_parent in comments:
                    if potential_parent.get('id') == parent_id:
                        parent_found = True
                        break
                
                if not parent_found:
                    bad_parent_refs_in_doc += 1
                    total_bad_parent_refs += 1
                    print(f"  🚨 Reply {comment.get('id', 'NO_ID')} in doc {doc.id} has invalid parentCommentId: {parent_id}")
        
        if bad_ids_in_doc > 0 or bad_parent_refs_in_doc > 0:
            docs_with_issues += 1
            print(f"  📄 Document {doc.id} has {bad_ids_in_doc} missing IDs and {bad_parent_refs_in_doc} bad parent refs")
    
    print(f"\n📊 Scan Results:")
    print(f"   Total documents: {total_docs}")
    print(f"   Documents with issues: {docs_with_issues}")
    print(f"   Total missing comment IDs: {total_bad_ids}")
    print(f"   Total bad parent references: {total_bad_parent_refs}")
    
    return (total_bad_ids > 0 or total_bad_parent_refs > 0)

def main():
    """Main function"""
    print("🔧 Comment ID Fix Tool")
    print("=" * 50)
    
    # Check if user wants to target a specific document
    target_post_id = input("Enter specific post ID to fix (or press Enter for all): ").strip()
    if not target_post_id:
        target_post_id = None
    
    # Setup Firebase
    db = setup_firebase()
    
    # First scan for issues
    has_issues = scan_for_id_issues(db, target_post_id)
    
    if not has_issues:
        print("✅ No comment ID issues found!")
        return
    
    # Ask for confirmation
    print("\n" + "=" * 50)
    response = input("Do you want to fix these comment ID issues? (y/N): ").strip().lower()
    
    if response == 'y' or response == 'yes':
        print("\n🔧 Starting comment ID fixes...")
        fix_comment_ids(db, target_post_id)
        print("\n✅ Comment ID fix completed!")
    else:
        print("❌ Operation cancelled.")

if __name__ == "__main__":
    main()
