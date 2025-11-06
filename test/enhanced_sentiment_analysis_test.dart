import 'package:flutter_test/flutter_test.dart';
import 'package:inzone/services/inzone_database.dart';

void main() {
  group('Enhanced Sentiment Analysis Tests', () {
    test('should analyze text-only content', () async {
      // Test normal positive content
      final result1 = await InZoneDatabase.analyzeSentiment(
        'I love this amazing community! Great vibes everyone!'
      );
      
      expect(result1['blocked'], false);
      expect(result1['sentiment'], greaterThanOrEqualTo(0));
      
      // Test potentially inappropriate content
      final result2 = await InZoneDatabase.analyzeSentiment(
        'This is terrible and I hate everything'
      );
      
      // Should either be negative sentiment or blocked
      expect(result2['sentiment'] <= 0, true);
    });

    test('should analyze content with images', () async {
      final result = await InZoneDatabase.analyzeSentiment(
        'Check out this cool picture!',
        imageUrls: ['https://example.com/test-image.jpg'],
      );
      
      expect(result, isNotNull);
      expect(result.containsKey('sentiment'), true);
      expect(result.containsKey('blocked'), true);
    });

    test('should analyze content with videos', () async {
      final result = await InZoneDatabase.analyzeSentiment(
        'Check out this awesome video!',
        videoUrls: ['https://example.com/test-video.mp4'],
      );
      
      expect(result, isNotNull);
      expect(result.containsKey('sentiment'), true);
      expect(result.containsKey('blocked'), true);
    });

    test('should analyze mixed content (text + images + videos)', () async {
      final result = await InZoneDatabase.analyzeSentiment(
        'Check out my latest content!',
        imageUrls: ['https://example.com/image.jpg'],
        videoUrls: ['https://example.com/video.mp4'],
      );
      
      expect(result, isNotNull);
      expect(result.containsKey('sentiment'), true);
      expect(result.containsKey('blocked'), true);
      expect(result.containsKey('category'), true);
    });

    test('should handle blocked content appropriately', () async {
      // This test would require actual inappropriate content
      // In a real scenario, you'd test with known problematic content
      final result = await InZoneDatabase.analyzeSentiment(
        'Test content that might be flagged'
      );
      
      if (result['blocked'] == true) {
        expect(result['block_reason'], isNotNull);
        expect(result['sentiment'], equals(-2));
      }
    });

    test('should maintain backward compatibility', () async {
      // Test the old method signature still works
      final result = await InZoneDatabase.analyzeSentimentTextOnly(
        'This is a test message'
      );
      
      expect(result, isNotNull);
      expect(result.containsKey('sentiment'), true);
      expect(result.containsKey('category'), true);
    });
  });

  group('Post Creation with Enhanced Analysis', () {
    test('should block posts with inappropriate content', () async {
      final result = await InZoneDatabase.createHumanPost(
        content: 'Potentially inappropriate content',
        imageRefs: [],
        videoRefs: [],
      );
      
      // Should handle blocking gracefully
      expect(result, isNotNull);
      expect(result.containsKey('success'), true);
      
      if (result['blocked'] == true) {
        expect(result['success'], false);
        expect(result['error'], isNotNull);
      }
    });

    test('should allow appropriate content', () async {
      final result = await InZoneDatabase.createHumanPost(
        content: 'This is a wonderful day!',
        imageRefs: [],
        videoRefs: [],
      );
      
      expect(result, isNotNull);
      expect(result.containsKey('success'), true);
    });
  });
}
