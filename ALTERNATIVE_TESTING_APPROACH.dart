// Alternative implementation: Test specific posts only
// Replace the _isPostOwner() method with this version if you want to test only specific posts

bool _isPostOwner() {
  // DEBUG MODE: Allow editing specific posts for testing
  // TODO: Remove this debug section before production release
  
  // List of post IDs you want to test edit/delete on
  const List<String> debugPostIds = [
    'post_id_1_here',
    'post_id_2_here',
    // Add more post IDs as needed
  ];
  
  // List of usernames whose posts you want to test
  const List<String> debugUsernames = [
    'test_user_1',
    'test_user_2',
    // Add more usernames as needed
  ];
  
  // Check if this is a debug-allowed post
  if (debugPostIds.contains(widget.post.id) || 
      debugUsernames.contains(widget.post.userName)) {
    return true;
  }
  
  // Original ownership logic for your own posts
  return _isActualOwner();
}