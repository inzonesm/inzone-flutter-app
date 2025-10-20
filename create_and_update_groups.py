import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase Admin
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# Example group definitions (diverse topics, categories, images, and descriptions)
groups_to_create = [
    {
        "name": "Tech & AI",
        "groupChatCategory": "technology",
        "description": "Explore the future with fellow techies and AI enthusiasts!",
        "imageUrl": "https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Music Lounge",
        "groupChatCategory": "entertainment",
        "description": "Share your favorite tunes and discover new artists.",
        "imageUrl": "https://images.unsplash.com/photo-1465101046530-73398c7f28ca?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Book Worms",
        "groupChatCategory": "literature",
        "description": "Dive into stories and swap book recommendations!",
        "imageUrl": "https://images.unsplash.com/photo-1512820790803-83ca734da794?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Anime Fans",
        "groupChatCategory": "entertainment",
        "description": "Discuss your favorite anime and manga with fellow fans!",
        "imageUrl": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Sports Central",
        "groupChatCategory": "sports",
        "description": "Chat about the latest games, scores, and sports news!",
        "imageUrl": "https://images.unsplash.com/photo-1517649763962-0c623066013b?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Gamers Hub",
        "groupChatCategory": "gaming",
        "description": "Connect with fellow gamers, share tips, and team up!",
        "imageUrl": "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Study Zone",
        "groupChatCategory": "education",
        "description": "Collaborate, share resources, and ace your exams together.",
        "imageUrl": "https://images.unsplash.com/photo-1464983953574-0892a716854b?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Wellness & Mindfulness",
        "groupChatCategory": "wellness",
        "description": "Share tips for a healthy mind and body, and support each other.",
        "imageUrl": "https://images.unsplash.com/photo-1504198453319-5ce911bafcde?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Creative Writing Club",
        "groupChatCategory": "literature",
        "description": "Share your stories, poems, and writing prompts!",
        "imageUrl": "https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Movie Buffs",
        "groupChatCategory": "entertainment",
        "description": "Discuss the latest releases and all-time classics.",
        "imageUrl": "https://images.unsplash.com/photo-1465101178521-c1a4c8a0f8d9?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Trending Topics",
        "groupChatCategory": "news",
        "description": "Stay updated and debate the hottest topics of the day.",
        "imageUrl": "https://images.unsplash.com/photo-1465101046530-73398c7f28ca?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Fashion & Style",
        "groupChatCategory": "lifestyle",
        "description": "Share your looks, get style tips, and talk trends.",
        "imageUrl": "https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Career Talks",
        "groupChatCategory": "career",
        "description": "Network, share advice, and grow your professional skills.",
        "imageUrl": "https://images.unsplash.com/photo-1503676382389-4809596d5290?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
    {
        "name": "Science & Curiosity",
        "groupChatCategory": "science",
        "description": "Ask questions, share discoveries, and fuel your curiosity.",
        "imageUrl": "https://images.unsplash.com/photo-1465101178521-c1a4c8a0f8d9?auto=format&fit=crop&w=400&q=80",
        "groupChatStatus": "active",
        "groupChatType": "public",
        "participants": [],
        "createdAt": datetime.utcnow(),
        "updatedAt": datetime.utcnow(),
    },
]

for group in groups_to_create:
    # Check if group already exists by name
    existing = db.collection("groupChats").where("name", "==", group["name"]).get()
    if existing:
        # Update existing group
        doc_ref = db.collection("groupChats").document(existing[0].id)
        doc_ref.update(group)
        print(f"Updated group: {group['name']}")
    else:
        # Create new group
        doc_ref = db.collection("groupChats").document()
        doc_ref.set(group)
        print(f"Created group: {group['name']}")

print("Group creation/update complete.")
