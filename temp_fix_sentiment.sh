#!/bin/bash
# Quick fix for sentiment analysis - temporarily disable strict moderation

echo "🔧 Applying temporary sentiment analysis fix..."

# Backup the current file
cp lib/services/inzone_database.dart lib/services/inzone_database.dart.backup

# Replace the sentiment analysis to always return neutral
sed -i '' 's/return {$/return {\
        print("TEMP FIX: Forcing neutral sentiment");\
        return {\
          "sentiment": 0,\
          "category": "Entertainment",\
          "blocked": false,\
          "fallback": true,\
        };\
      }\
      \/\/ Original fallback code:\
      return {/g' lib/services/inzone_database.dart

echo "✅ Temporary fix applied!"
echo "📱 Now restart your Flutter app (hot restart: 'R' in terminal)"
echo ""
echo "To revert this change later:"
echo "mv lib/services/inzone_database.dart.backup lib/services/inzone_database.dart"