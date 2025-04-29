import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

// Screens
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
import 'package:inzone/screen/settings/content_select_screen.dart';
import 'package:inzone/screen/settings/subscription_purchase.dart';
import 'package:inzone/screen/settings/referral_screen.dart';

// Models
import 'package:inzone/data/group_data.dart';

// Routes
import 'package:inzone/router/routes.dart';

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final User? user = FirebaseAuth.instance.currentUser;
      final bool isLoggedIn = user != null;
      final bool isGoingToSplash = state.matchedLocation == Routes.splash;

      if (isGoingToSplash) {
        return null;
      }

      if (!isLoggedIn && !state.matchedLocation.contains('/auth/')) {
        return Routes.login;
      }

      if (isLoggedIn && state.matchedLocation.contains('/auth/')) {
        return Routes.home;
      }

      return null;
    },
    routes: [
      // 🚀 Auth and splash routes
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
        parentNavigatorKey: AppRouter.rootNavigatorKey,
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: auth.ProfileScreen(email: email),
          );
        },
      ),

      GoRoute(
        path: Routes.interests,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return InterestSelectionScreen(email: email);
        },
      ),

      // 🚀 Shell for Main App
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return RootApp(child: child);
        },
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.groups,
            builder: (context, state) => const GroupsExploreScreen(),
          ),
          GoRoute(
            path: Routes.chats,
            builder: (context, state) => const AllChatsScreen(),
          ),
          GoRoute(
            path: Routes.profile_tab,
            builder: (context, state) => const UserProfileScreen(),
          ),
        ],
      ),

      // 🚀 Others (Root level)
      GoRoute(
        path: Routes.post,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const PostScreen(),
        ),
      ),
      GoRoute(
        path: Routes.aiProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          return ProfileScreen(uid: username, isAI: true);
        },
      ),
      GoRoute(
        path: Routes.regularProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final uid = state.pathParameters['uid'] ?? '';
          return ProfileScreen(uid: uid);
        },
      ),
      GoRoute(
        path: Routes.groupChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final group = state.extra as GroupData;
          return GroupChatScreen(group: group);
        },
      ),
      GoRoute(
        path: Routes.chat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userData = state.extra as ChatUser;
          return ChatScreen(userData: userData);
        },
      ),
      GoRoute(
        path: Routes.contentSelection,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ContentSelectionSettingsScreen(),
      ),
      GoRoute(
        path: Routes.subscription,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const SubscriptionScreen(),
        ),
      ),
      GoRoute(
        path: Routes.referral,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
    ],
  );
}
