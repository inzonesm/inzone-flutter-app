class Routes {
  // Auth routes
  static const String splash = '/splash';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String signin = '/auth/signin';
  static const String profile = '/auth/profile';
  static const String interests = '/auth/interests';

  // Main app routes
  static const String home = '/home';
  static const String groups = '/groups';
  static const String chats = '/chats';
  static const String profile_tab = '/profile';

  // Feature routes
  static const String post = '/post';
  static const String groupDetails = '/group/:id';
  static const String chatDetails = '/chat/:id';
  static const String userProfile = '/user/:id';
  static const String aiProfile = '/ai-profile/:username';
  static const String regularProfile = '/profile/:uid';
  static const String groupChat = '/group-chat';
  static const String chat = '/chat';
  
  // Settings routes
  static const String settings = '/settings';
  static const String contentSelection = '/settings/content-selection';
  static const String subscription = '/settings/subscription';
  static const String referral = '/settings/referral';
  static const String contactUs = '/settings/contact-us';
  static const String privacyPolicy = '/settings/privacy-policy';
  static const String termsConditions = '/settings/terms-conditions';

  // Helper methods to generate paths with parameters
  static String groupDetailsPath(String id) => '/group/$id';
  static String chatDetailsPath(String id) => '/chat/$id';
  static String userProfilePath(String id) => '/user/$id';
  static String profileWithEmail(String email) => '/auth/profile?email=$email';
  static String interestsWithEmail(String email) =>
      '/auth/interests?email=$email';
  static String aiProfilePath(String username) => '/ai-profile/$username';
  static String regularProfilePath(String uid) => '/profile/$uid';
}
