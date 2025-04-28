import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/root_app.dart';
import 'package:inzone/screen/auth/splash_screen.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/screen/auth/signin_login_screen.dart';
import 'package:inzone/screen/auth/profile_screen.dart' as auth;
import 'package:inzone/screen/auth/interesting_select_screen.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/profile/user_profile_screen.dart';
import 'package:inzone/screen/profile/profile_screen.dart';
import 'package:inzone/screen/post/post_screen.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/data/group_data.dart';
import 'package:inzone/router/routes.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final User? user = FirebaseAuth.instance.currentUser;
      final bool isLoggedIn = user != null;
      final bool isGoingToSplash = state.matchedLocation == Routes.splash;

      // Allow access to splash screen
      if (isGoingToSplash) {
        return null;
      }

      // If user is not logged in and not on login route, redirect to login
      if (!isLoggedIn && !state.matchedLocation.contains('/auth/')) {
        return Routes.login;
      }

      // User is logged in and trying to access login/register, redirect to home
      if (isLoggedIn && state.matchedLocation.contains('/auth/')) {
        return Routes.home;
      }

      // Allow the requested page to load
      return null;
    },
    routes: [
      // Splash and Auth routes
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: Routes.login,
        builder: (context, state) => const IntroductionScreen(),
      ),

      GoRoute(
        path: Routes.signin,
        builder: (context, state) => const SignInLoginScreen(),
      ),

      GoRoute(
        path: Routes.profile,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return auth.ProfileScreen(email: email);
        },
      ),

      GoRoute(
        path: Routes.interests,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return InterestSelectionScreen(email: email);
        },
      ),

      // Main app shell route
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return RootApp(child: child);
        },
        routes: [
          // Home tab
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),

          // Groups tab
          GoRoute(
            path: Routes.groups,
            builder: (context, state) => const GroupsExploreScreen(),
          ),

          // Chats tab
          GoRoute(
            path: Routes.chats,
            builder: (context, state) => const AllChatsScreen(),
          ),

          // Profile tab
          GoRoute(
            path: Routes.profile_tab,
            builder: (context, state) => const UserProfileScreen(),
          ),
        ],
      ),

      // Post screen - accessed from FAB
      GoRoute(
        path: Routes.post,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PostScreen(),
      ),

      // AI Profile route
      GoRoute(
        path: Routes.aiProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return ProfileScreen(uid: username, isAI: true);
        },
      ),

      // Human profile route
      GoRoute(
        path: Routes.regularProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final uid = state.pathParameters['uid'] ?? '';
          return ProfileScreen(uid: uid);
        },
      ),

      // Group chat route
      GoRoute(
        path: Routes.groupChat,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final group = state.extra as GroupData;
          return GroupChatScreen(group: group);
        },
      ),

      // Direct chat route
      GoRoute(
        path: Routes.chat,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userData = state.extra as ChatUser;
          return ChatScreen(userData: userData);
        },
      ),
    ],
  );
}
