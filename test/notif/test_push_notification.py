import requests
import json

# Test the new /api/notifications/send-push endpoint
def test_push_notification():
    # Replace with a real user ID that has FCM tokens
    test_user_id = "YOUR_TEST_USER_ID"  # Update this with an actual user ID
    
    url = "https://inzoneapi-912424781531.us-central1.run.app/api/notifications/send-push"
    
    payload = {
        "userId": test_user_id,
        "title": "Test Push Notification",
        "body": "This is a test message from the new push notification endpoint!",
        "data": {
            "type": "test",
            "timestamp": "2024-01-20T10:00:00Z"
        }
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        print(f"🔄 Sending test push notification to user: {test_user_id}")
        response = requests.post(url, json=payload, headers=headers)
        
        print(f"📡 Response Status: {response.status_code}")
        print(f"📱 Response Body: {response.text}")
        
        if response.status_code == 200:
            print("✅ Push notification sent successfully!")
        else:
            print(f"❌ Failed to send push notification: {response.text}")
            
    except Exception as e:
        print(f"❌ Error testing push notification: {e}")

if __name__ == "__main__":
    print("🧪 Testing Push Notification Endpoint")
    print("📝 Make sure to update test_user_id with a real user ID that has FCM tokens")
    test_push_notification()
