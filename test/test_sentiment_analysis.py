#!/usr/bin/env python3
"""
Test script for the enhanced sentiment analysis system
"""

import requests
import json

def test_sentiment_analysis():
    """Test the enhanced sentiment analysis endpoint"""
    
    # Test URL - update this to match your deployment
    url = "https://inzoneapi-912424781531.us-central1.run.app/api/sentiment-analysis"
    
    test_cases = [
        {
            "name": "Normal positive text",
            "data": {
                "text": "I love this amazing community! Great vibes everyone!"
            },
            "expected_blocked": False
        },
        {
            "name": "Inappropriate text",
            "data": {
                "text": "I hate everyone and want to cause harm"
            },
            "expected_blocked": True
        },
        {
            "name": "Text with potential slang",
            "data": {
                "text": "That's so sick and crazy awesome!"
            },
            "expected_blocked": False
        },
        {
            "name": "Mixed content with images",
            "data": {
                "text": "Check out this cool picture!",
                "image_urls": ["https://example.com/image.jpg"]
            },
            "expected_blocked": False
        }
    ]
    
    print("🧪 Testing Enhanced Sentiment Analysis System")
    print("=" * 50)
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"\n{i}. Testing: {test_case['name']}")
        print(f"   Input: {test_case['data']}")
        
        try:
            response = requests.post(url, json=test_case['data'], timeout=30)
            
            if response.status_code == 200:
                result = response.json()
                
                if result.get('success'):
                    data = result.get('data', {})
                    overall_assessment = data.get('overall_assessment', {})
                    is_blocked = overall_assessment.get('inappropriate_content_detected', False)
                    
                    print(f"   ✅ Status: {'BLOCKED' if is_blocked else 'ALLOWED'}")
                    print(f"   📊 Confidence: {overall_assessment.get('confidence_score', 'N/A')}")
                    
                    if 'text_analysis' in data:
                        text_analysis = data['text_analysis']
                        print(f"   💭 Sentiment: {text_analysis.get('OverallSentiment', 'N/A')}")
                    
                    if 'urban_dictionary_check' in data:
                        urban_check = data['urban_dictionary_check']
                        if urban_check.get('has_negative_slang'):
                            print(f"   🚨 Flagged slang: {urban_check.get('flagged_terms', [])}")
                    
                    # Validate expectation
                    if is_blocked == test_case['expected_blocked']:
                        print(f"   ✅ Result matches expectation")
                    else:
                        print(f"   ❌ Expected {'BLOCKED' if test_case['expected_blocked'] else 'ALLOWED'}, got {'BLOCKED' if is_blocked else 'ALLOWED'}")
                
                else:
                    print(f"   ❌ API Error: {result.get('error', 'Unknown error')}")
                    
            else:
                print(f"   ❌ HTTP Error: {response.status_code}")
                print(f"   Response: {response.text}")
                
        except requests.exceptions.RequestException as e:
            print(f"   ❌ Connection Error: {e}")
        except Exception as e:
            print(f"   ❌ Unexpected Error: {e}")
    
    print("\n" + "=" * 50)
    print("🏁 Testing completed!")

def test_urban_dictionary_service():
    """Test the Urban Dictionary service separately"""
    print("\n🔍 Testing Urban Dictionary Service")
    print("-" * 30)
    
    # This would test the Urban Dictionary API directly
    try:
        test_url = "https://api.urbandictionary.com/v0/define"
        response = requests.get(test_url, params={"term": "test"}, timeout=5)
        
        if response.status_code == 200:
            print("✅ Urban Dictionary API is accessible")
        else:
            print(f"❌ Urban Dictionary API error: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Urban Dictionary connection error: {e}")

if __name__ == "__main__":
    test_sentiment_analysis()
    test_urban_dictionary_service()
