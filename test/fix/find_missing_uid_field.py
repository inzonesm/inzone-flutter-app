#!/usr/bin/env python3
"""
Script to find and fix documents that don't have the 'uid' field AT ALL (not empty, but missing entirely)
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
            script_dir = os.path.dirname(os.path.abspath(__file__))
            credential_path = os.path.join(script_dir, credential_path)

        if not os.path.exists(credential_path):
            logger.error(f"Firebase credential file not found at: {credential_path}")
            return None

        cred = credentials.Certificate(credential_path)
        app = initialize_app(cred, name='fix_uid_app')
        db = firestore.client(app=app)
        return db
        
    except Exception as e:
        logger.error(f"Failed to initialize Firebase: {e}")
        return None

def find_and_fix_missing_uid_field():
    """
    Find documents that don't have the 'uid' field at all and add it
    """
    try:
        db = initialize_firebase()
        if not db:
            raise Exception("Failed to initialize Firebase")
        
        logger.info("🔍 Looking for humanUsers documents WITHOUT the 'uid' field...")
        
        users_ref = db.collection('humanUsers')
        docs = users_ref.stream()
        
        total_count = 0
        missing_uid_field = 0
        updated_count = 0
        errors = []
        
        for doc in docs:
            total_count += 1
            doc_data = doc.to_dict()
            doc_id = doc.id
            
            # Check ONLY if 'uid' field is missing entirely
            if 'uid' not in doc_data:
                missing_uid_field += 1
                logger.info(f"❌ Document {doc_id} is missing 'uid' field entirely")
                
                try:
                    # Add the uid field
                    users_ref.document(doc_id).update({
                        'uid': doc_id
                    })
                    updated_count += 1
                    logger.info(f"✅ Added 'uid' field to document {doc_id}")
                    
                except Exception as e:
                    error_msg = f"Failed to update {doc_id}: {e}"
                    logger.error(error_msg)
                    errors.append(error_msg)
            else:
                # Document has uid field (regardless of its value)
                uid_value = doc_data.get('uid')
                if total_count <= 3:  # Show first few for debugging
                    logger.info(f"✅ Document {doc_id} has 'uid' field: {uid_value}")
        
        logger.info("=" * 60)
        logger.info("📊 RESULTS:")
        logger.info(f"   Total documents: {total_count}")
        logger.info(f"   Missing 'uid' field: {missing_uid_field}")
        logger.info(f"   Successfully updated: {updated_count}")
        logger.info(f"   Errors: {len(errors)}")
        logger.info("=" * 60)
        
        if errors:
            for error in errors:
                logger.error(f"❌ {error}")
        
        return {
            'total': total_count,
            'missing_uid_field': missing_uid_field,
            'updated': updated_count,
            'errors': errors
        }
        
    except Exception as e:
        logger.error(f"❌ Error: {e}")
        raise e

if __name__ == "__main__":
    try:
        results = find_and_fix_missing_uid_field()
        if results['missing_uid_field'] == 0:
            logger.info("🎉 All documents already have the 'uid' field!")
        else:
            logger.info(f"🎉 Fixed {results['updated']} out of {results['missing_uid_field']} documents missing 'uid' field")
    except Exception as e:
        logger.error(f"💥 Script failed: {e}")
        exit(1)
