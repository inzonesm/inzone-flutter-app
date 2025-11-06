#!/usr/bin/env python3
"""
Simple script to test the UID fix endpoint
"""

import requests
import json

def test_uid_fix_endpoint():
    try:
        url = "http://127.0.0.1:5000/api/admin/fix-missing-uid"
        headers = {"Content-Type": "application/json"}
        
        print("🚀 Testing UID fix endpoint...")
        print(f"URL: {url}")
        
        response = requests.post(url, headers=headers)
        
        print(f"📊 Status Code: {response.status_code}")
        print(f"📄 Response:")
        print(json.dumps(response.json(), indent=2))
        
    except Exception as e:
        print(f"❌ Error testing endpoint: {e}")

if __name__ == "__main__":
    test_uid_fix_endpoint()
