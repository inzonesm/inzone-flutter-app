#!/usr/bin/env python3
"""
Verification script to check that all humanUsers have proper UID fields
Uses the same Firebase setup as the main app
"""

import logging
import os
from firebase_admin import credentials, initialize_app, firestore

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def initialize_firebase():
    """Initialize Firebase using the same setup as the main app"""
    try:
        credential_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "key.json")
        if not os.path.isabs(credential_path):
            # If relative path, make it relative to this script's directory
            script_dir = os.path.dirname(os.path.abspath(__file__))
            credential_path = os.path.join(script_dir, credential_path)

        if not os.path.exists(credential_path):
            logger.error(f"Firebase credential file not found at: {credential_path}")
            return None

        cred = credentials.Certificate(credential_path)
        app = initialize_app(cred, name='verify_uid_app')
        
        # Initialize Firestore client
        db = firestore.client(app=app)
        return db
        
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None

def verify_all_users_have_uid():
    """
    Verify that all humanUsers documents have a proper 'uid' field that matches their document ID.
    """
    try:
        # Initialize Firebase
        db = initialize_firebase()
        if not db:
            raise Exception("Failed to initialize Firebase")
        
        logger.info("🔍 Verifying all humanUsers have proper UID fields...")
        
        # Get all documents from humanUsers collection
        users_ref = db.collection('humanUsers')
        docs = users_ref.stream()
        
        total_count = 0
        missing_uid_count = 0
        mismatched_uid_count = 0
        proper_uid_count = 0
        
        missing_uids = []
        mismatched_uids = []
        
        for doc in docs:
            total_count += 1
            doc_data = doc.to_dict()
            doc_id = doc.id
            uid_field = doc_data.get('uid')
            
            if 'uid' not in doc_data or uid_field is None or uid_field == '':
                missing_uid_count += 1
                missing_uids.append(doc_id)
                logger.warning(f"❌ User {doc_id} missing UID field")
                
            elif uid_field != doc_id:
                mismatched_uid_count += 1
                mismatched_uids.append({'doc_id': doc_id, 'uid_field': uid_field})
                logger.warning(f"⚠️ User {doc_id} has mismatched UID: {uid_field}")
                
            else:
                proper_uid_count += 1
                if total_count <= 5:  # Show first 5 for debugging
                    logger.info(f"✅ User {doc_id} has correct UID")
        
        # Summary
        logger.info("=" * 60)
        logger.info("📊 VERIFICATION RESULTS:")
        logger.info(f"   Total users: {total_count}")
        logger.info(f"   ✅ Proper UID: {proper_uid_count}")
        logger.info(f"   ❌ Missing UID: {missing_uid_count}")
        logger.info(f"   ⚠️ Mismatched UID: {mismatched_uid_count}")
        logger.info("=" * 60)
        
        if missing_uid_count > 0:
            logger.warning("Users missing UID:")
            for user_id in missing_uids[:10]:  # Show first 10
                logger.warning(f"  - {user_id}")
            if len(missing_uids) > 10:
                logger.warning(f"  ... and {len(missing_uids) - 10} more")
        
        if mismatched_uid_count > 0:
            logger.warning("Users with mismatched UID:")
            for mismatch in mismatched_uids[:10]:  # Show first 10
                logger.warning(f"  - {mismatch['doc_id']} (has: {mismatch['uid_field']})")
            if len(mismatched_uids) > 10:
                logger.warning(f"  ... and {len(mismatched_uids) - 10} more")
        
        success = missing_uid_count == 0 and mismatched_uid_count == 0
        
        if success:
            logger.info("🎉 All humanUsers have proper UID fields!")
        else:
            logger.error("💥 Some users have UID field issues!")
        
        return {
            'total': total_count,
            'proper': proper_uid_count,
            'missing': missing_uid_count,
            'mismatched': mismatched_uid_count,
            'success': success,
            'missing_list': missing_uids,
            'mismatched_list': mismatched_uids
        }
        
    except Exception as e:
        logger.error(f"❌ Error during verification: {e}")
        raise e

if __name__ == "__main__":
    try:
        results = verify_all_users_have_uid()
        exit(0 if results['success'] else 1)
    except Exception as e:
        logger.error(f"💥 Verification failed: {e}")
        exit(1)
