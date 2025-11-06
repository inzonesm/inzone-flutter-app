#!/usr/bin/env python3
"""
Script to fix humanUsers documents that are missing the 'uid' field.
This script will set the 'uid' field to be the same as the document ID.
"""

import logging
import os
from google.cloud import firestore

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def fix_missing_uid_fields():
    """
    Find all humanUsers documents without a 'uid' field and set it to their document ID.
    """
    try:
        # Initialize Firestore client
        db = firestore.Client()
        
        logger.info("Starting to fix missing UID fields in humanUsers collection...")
        
        # Get all documents from humanUsers collection
        users_ref = db.collection('humanUsers')
        docs = users_ref.stream()
        
        updated_count = 0
        total_count = 0
        
        for doc in docs:
            total_count += 1
            doc_data = doc.to_dict()
            doc_id = doc.id
            
            # Check if the document is missing the 'uid' field or if it's None
            if 'uid' not in doc_data or doc_data['uid'] is None or doc_data['uid'] == '':
                logger.info(f"Found user without UID: {doc_id}")
                
                # Update the document to set uid = document_id
                try:
                    users_ref.document(doc_id).update({
                        'uid': doc_id
                    })
                    updated_count += 1
                    logger.info(f"✅ Updated user {doc_id} - set uid to {doc_id}")
                    
                except Exception as e:
                    logger.error(f"❌ Failed to update user {doc_id}: {e}")
            else:
                logger.debug(f"User {doc_id} already has UID: {doc_data.get('uid')}")
        
        logger.info(f"🎉 Process completed!")
        logger.info(f"📊 Total users processed: {total_count}")
        logger.info(f"🔧 Users updated: {updated_count}")
        logger.info(f"✅ Users already had UID: {total_count - updated_count}")
        
        return {
            'total_processed': total_count,
            'updated': updated_count,
            'already_had_uid': total_count - updated_count
        }
        
    except Exception as e:
        logger.error(f"❌ Error during UID fix process: {e}")
        raise e

def verify_uid_fix():
    """
    Verify that all humanUsers documents now have a proper uid field.
    """
    try:
        db = firestore.Client()
        users_ref = db.collection('humanUsers')
        docs = users_ref.stream()
        
        missing_uid_count = 0
        total_count = 0
        
        logger.info("🔍 Verifying UID fields...")
        
        for doc in docs:
            total_count += 1
            doc_data = doc.to_dict()
            doc_id = doc.id
            
            if 'uid' not in doc_data or doc_data['uid'] is None or doc_data['uid'] == '':
                missing_uid_count += 1
                logger.warning(f"❌ User {doc_id} still missing UID!")
            elif doc_data['uid'] != doc_id:
                logger.warning(f"⚠️ User {doc_id} has mismatched UID: {doc_data['uid']}")
        
        logger.info(f"📊 Verification completed:")
        logger.info(f"   Total users: {total_count}")
        logger.info(f"   Missing UID: {missing_uid_count}")
        logger.info(f"   With proper UID: {total_count - missing_uid_count}")
        
        return missing_uid_count == 0
        
    except Exception as e:
        logger.error(f"❌ Error during verification: {e}")
        return False

if __name__ == "__main__":
    try:
        # Check if we're in the right environment
        logger.info("🚀 Starting UID fix script...")
        
        # Fix missing UIDs
        results = fix_missing_uid_fields()
        
        # Verify the fix
        if verify_uid_fix():
            logger.info("✅ All humanUsers now have proper UID fields!")
        else:
            logger.warning("⚠️ Some users may still be missing UID fields. Please check the logs.")
            
    except Exception as e:
        logger.error(f"💥 Script failed: {e}")
        exit(1)
