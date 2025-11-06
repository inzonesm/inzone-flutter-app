#!/usr/bin/env python3

import requests
import json

# Test the purchase endpoint
def test_purchase_endpoint():
    url = "http://localhost:5000/wallet/purchase-incash"
    
    # Test data
    test_data = {
        "UserDocumentId": "LWiwzqmG0TNXxXyMAxifkVe1wXc2", 
        "PackageId": "InCashBasic2025",
        "Platform": "android",
        "ReceiptData": "test_receipt_data_123"
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(url, json=test_data, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
    except requests.exceptions.ConnectionError:
        print("Cannot connect to server. Make sure the Flask app is running on localhost:5000")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_purchase_endpoint()
