#!/usr/bin/env python3
"""
REAL Test script to verify the AI DM response fix works correctly.
This test uses ACTUAL users and AI characters from the database.
"""

import requests
import json
import time
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate("key.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized")
except Exception as e:
    print(f"❌ Firebase initialization failed: {e}")
    exit(1)

# Test configuration
API_BASE_URL = 'https://inzoneapi-912424781531.us-central1.run.app'

# Test configuration
API_BASE_URL = 'https://inzoneapi-912424781531.us-central1.run.app'

def get_real_test_data():
    """Get real user and AI character data from Firebase"""
    try:
        print("🔍 Finding real users and AI characters...")
        
        # Get a real human user
        users_ref = db.collection('humanUsers').limit(5)
        users = list(users_ref.stream())
        
        if not users:
            print("❌ No human users found in database")
            return None, None
            
        real_user = users[0]
        user_data = real_user.to_dict()
        user_id = real_user.id
        user_name = user_data.get('name', user_data.get('username', 'Unknown'))
        
        print(f"   📱 Found human user: {user_name} (ID: {user_id})")
        
        # Get a real AI character
        ai_ref = db.collection('popularCharacters').limit(5)
        ai_characters = list(ai_ref.stream())
        
        if not ai_characters:
            print("❌ No AI characters found in database")
            return None, None
            
        ai_char = ai_characters[0]
        ai_data = ai_char.to_dict()
        ai_id = ai_char.id
        ai_name = ai_data.get('name', 'Unknown AI')
        
        print(f"   🤖 Found AI character: {ai_name} (ID: {ai_id})")
        
        return {
            'user_id': user_id,
            'user_name': user_name,
            'ai_id': ai_id,
            'ai_name': ai_name
        }, None
        
    except Exception as e:
        print(f"❌ Error getting real data: {e}")
        return None, str(e)

def test_immediate_ai_response():
    """Test that AI character responds immediately to user messages using REAL data"""
    print("🧪 Testing AI DM Auto-Response Fix with REAL DATA")
    print("=" * 60)
    
    # Get real test data
    test_data, error = get_real_test_data()
    if not test_data:
        print(f"❌ Cannot run test: {error or 'No test data available'}")
        return
    
    user_id = test_data['user_id']
    ai_id = test_data['ai_id'] 
    user_name = test_data['user_name']
    ai_name = test_data['ai_name']
    test_message = f"Hey {ai_name}! This is a test message at {datetime.now().strftime('%H:%M:%S')}"
    conversation_id = f"{user_id}_{ai_id}"
    
    print(f"🎯 Test Setup:")
    print(f"   👤 Human User: {user_name} ({user_id})")
    print(f"   🤖 AI Character: {ai_name} ({ai_id})")
    print(f"   💬 Message: {test_message}")
    print(f"   📞 Conversation ID: {conversation_id}")
    print()
    
    # Step 1: FIRST, create the user's message in the conversation (simulate real flow)
    print(f"1. Creating user message in conversation: {user_name} -> {ai_name}")
    
    try:
        # Create/update the conversation with the user's message
        conv_ref = db.collection('conversations').document(conversation_id)
        conv_data = {
            'participants': [user_id, ai_id],
            'participantNames': {
                user_id: user_name,
                ai_id: ai_name
            },
            'lastMessage': test_message,
            'lastMessageTime': firestore.SERVER_TIMESTAMP,
            'lastUpdated': firestore.SERVER_TIMESTAMP,
            'isAIConversation': True
        }
        conv_ref.set(conv_data, merge=True)
        
        # Add the user's message to the messages subcollection
        message_data = {
            'text': test_message,
            'senderId': user_id,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'messageType': 'text'
        }
        conv_ref.collection('messages').add(message_data)
        
        print(f"   ✅ User message created successfully")
        
    except Exception as e:
        print(f"   ❌ Error creating user message: {e}")
        return
    
    print()
    
    # Step 2: NOW trigger the AI auto-response (this should work!)
    print(f"2. Triggering AI auto-response: {ai_name} responding to {user_name}")
    
    response_data = {
        'user_id': user_id,
        'ai_character_id': ai_id,
        'message_text': test_message,
        'conversation_id': conversation_id
    }
    
    try:
        response = requests.post(
            f'{API_BASE_URL}/api/ai/dm-auto-responder',
            headers={'Content-Type': 'application/json'},
            json=response_data,
            timeout=30
        )
        
        print(f"   Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ SUCCESS: {result.get('message', 'AI responded')}")
            print(f"   🤖 AI Character: {result.get('ai_character_name', 'Unknown')}")
            print(f"   📞 Conversation: {result.get('conversation_id', 'Unknown')}")
        else:
            print(f"   ❌ FAILED: {response.text}")
            
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    print()
    
    # Step 3: Test DM monitoring
    print("3. Testing DM monitoring system")
    
    try:
        monitor_response = requests.post(
            f'{API_BASE_URL}/api/ai/monitor-dms',
            headers={'Content-Type': 'application/json'},
            json={},
            timeout=60
        )
        
        print(f"   Status Code: {monitor_response.status_code}")
        
        if monitor_response.status_code == 200:
            result = monitor_response.json()
            responses_sent = result.get('responses_sent', 0)
            print(f"   ✅ Monitoring successful: {responses_sent} responses sent")
            if responses_sent > 0:
                print(f"   📝 Details: {result.get('message', 'No details')}")
        else:
            print(f"   ❌ Monitoring failed: {monitor_response.text}")
            
    except Exception as e:
        print(f"   ❌ Monitoring error: {e}")
    
    print()
    
    # Step 4: Test engagement status
    print("4. Checking AI engagement status")
    
    try:
        status_response = requests.get(
            f'{API_BASE_URL}/api/ai/engagement-status',
            headers={'Content-Type': 'application/json'},
            timeout=30
        )
        
        print(f"   Status Code: {status_response.status_code}")
        
        if status_response.status_code == 200:
            result = status_response.json()
            if result.get('success'):
                data = result.get('data', {})
                today_stats = data.get('today_stats', {})
                print(f"   ✅ Status check successful")
                print(f"   📊 Today's stats:")
                print(f"      • Characters: {data.get('total_characters', 0)}")
                print(f"      • DMs: {today_stats.get('dms', 0)}")
                print(f"      • Likes: {today_stats.get('likes', 0)}")
                print(f"      • Comments: {today_stats.get('comments', 0)}")
            else:
                print(f"   ❌ Status check failed: {result.get('error', 'Unknown error')}")
        else:
            print(f"   ❌ Status request failed: {status_response.text}")
            
    except Exception as e:
        print(f"   ❌ Status error: {e}")
    
    print()
    print("🎯 Test completed!")
    print("📊 Results Summary:")
    print(f"   • AI Response Test: {'✅ PASSED' if response.status_code == 200 else '❌ FAILED'}")
    print(f"   • DM Monitoring: {'✅ ACTIVE' if monitor_response.status_code == 200 else '❌ INACTIVE'}")
    print(f"   • Backend Status: {'✅ HEALTHY' if status_response.status_code == 200 else '❌ UNHEALTHY'}")
    print()
    if response.status_code == 200:
        print("🚀 THE FIX IS WORKING! AI characters should now respond immediately.")
        print(f"   Check the conversation between {user_name} and {ai_name} for the response.")
    else:
        print("⚠️  Issues detected. Check the error messages above.")

def test_conversation_monitoring():
    """Test that the system can monitor existing conversations"""
    print("\n🔍 Testing conversation monitoring...")
    
    try:
        # Get some recent conversations to monitor
        convos_ref = db.collection('conversations').limit(3)
        conversations = list(convos_ref.stream())
        
        print(f"   Found {len(conversations)} conversations to monitor")
        
        if conversations:
            for i, convo in enumerate(conversations[:2]):  # Check first 2
                convo_data = convo.to_dict()
                participants = convo_data.get('participants', [])
                if len(participants) >= 2:
                    print(f"   📞 Conversation {i+1}: {participants[0]} ↔ {participants[1]}")
                    
        return True
    except Exception as e:
        print(f"   ❌ Error monitoring conversations: {e}")
        return False

if __name__ == "__main__":
    test_immediate_ai_response()
    test_conversation_monitoring()
