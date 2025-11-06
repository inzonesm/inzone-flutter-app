#!/usr/bin/env python3
import firebase_admin
from firebase_admin import credentials, firestore
import json
import os

# Initialize Firebase if not already done
try:
    app = firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('key.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Get the document with the specified ID
doc_id = '0Jr4DDa4uTRSZb51Ghus_LWiwzqmG0TNXxXyMAxifkVe1wXc2'
doc_ref = db.collection('conversations').document(doc_id)
doc = doc_ref.get()

if doc.exists:
    print('=== CONVERSATION DOCUMENT ===')
    conversation_data = doc.to_dict()
    print(json.dumps(conversation_data, indent=2, default=str))
    
    # Get messages subcollection
    print('\n=== MESSAGES (in chronological order) ===')
    messages_ref = doc_ref.collection('messages')
    messages = messages_ref.order_by('timestamp').stream()
    
    for i, msg in enumerate(messages):
        msg_data = msg.to_dict()
        timestamp = msg_data.get('timestamp', 'No timestamp')
        sender_id = msg_data.get('senderId', 'Unknown')
        sender_name = msg_data.get('senderName', 'Unknown')
        text = msg_data.get('text', '')
        is_ai = msg_data.get('isAIGenerated', False)
        is_read = msg_data.get('isRead', False)
        
        print(f'\n--- Message {i+1} ---')
        print(f'Timestamp: {timestamp}')
        print(f'Sender: {sender_name} ({sender_id})')
        print(f'AI Generated: {is_ai}')
        print(f'Text: {text}')
        print(f'Read: {is_read}')
        
else:
    print('Document not found!')
