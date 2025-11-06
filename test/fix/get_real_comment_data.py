import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Firebase
if not firebase_admin._apps:
    cred_path = os.path.join('z-inzoneapi', 'key.json')
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Get the specific document
doc_id = 'post_LWiwzqmG0TNXxXyMAxifkVe1wXc2_1756243676332'
doc = db.collection('postComments').document(doc_id).get()

if doc.exists:
    data = doc.to_dict()
    comments = data.get('comments', [])
    print(f'Document has {len(comments)} comments')
    
    # Find comments and replies
    regular_comments = []
    replies = []
    
    for i, comment in enumerate(comments):
        print(f'Comment {i}:')
        print(f'  ID: {comment.get("id", "NO_ID")}')
        print(f'  Author: {comment.get("author", "NO_AUTHOR")}')
        print(f'  UserID: {comment.get("userId", "NO_USER_ID")}')
        print(f'  IsReply: {comment.get("isReply", False)}')
        print(f'  ParentCommentId: {comment.get("parentCommentId", "NO_PARENT")}')
        text = comment.get('text', 'NO_TEXT')
        if len(text) > 50:
            text = text[:50] + '...'
        print(f'  Text: {text}')
        print()
        
        if comment.get('isReply', False):
            replies.append(comment)
        else:
            regular_comments.append(comment)
    
    print(f'\nSummary:')
    print(f'Total comments: {len(comments)}')
    print(f'Regular comments: {len(regular_comments)}')
    print(f'Replies: {len(replies)}')
    
    # Suggest test data
    if replies:
        reply = replies[0]
        print(f'\nTest data for notification endpoint:')
        print(f'  postId: {doc_id}')
        print(f'  replierId: {reply.get("userId", "UNKNOWN")}')
        print(f'  parentCommentId: {reply.get("parentCommentId", "UNKNOWN")}')
        
else:
    print('Document not found')
