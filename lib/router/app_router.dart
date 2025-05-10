import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inzone/router/auth_notifier.dart';

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
import 'package:inzone/screen/profile/edit_profile_screen.dart';
import 'package:inzone/screen/profile/edit_field_screen.dart';
import 'package:inzone/screen/post/post_screen.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/screen/chat/human_chat_screen.dart';
import 'package:inzone/screen/chat/post_chat_screen.dart';
import 'package:inzone/screen/settings/content_select_screen.dart';
import 'package:inzone/screen/settings/subscription_purchase.dart';
import 'package:inzone/screen/settings/referral_screen.dart';

// Models
import 'package:inzone/data/group_data.dart';

// Routes
import 'package:inzone/router/routes.dart';

/// A custom codec that can handle Map<String, Object> extras
class MapExtraCodec extends Codec<Object?, Object?> {
  const MapExtraCodec();

  @override
  Converter<Object?, Object?> get decoder => const _MapExtraDecoder();

  @override
  Converter<Object?, Object?> get encoder => const _MapExtraEncoder();
}

class _MapExtraDecoder extends Converter<Object?, Object?> {
  const _MapExtraDecoder();

  @override
  Object? convert(Object? input) {
    if (input == null) return null;

    // If input is already a Map<String, dynamic>, just return it
    if (input is Map<String, dynamic>) {
      return input;
    }

    return input;
  }
}

class _MapExtraEncoder extends Converter<Object?, Object?> {
  const _MapExtraEncoder();

  @override
  Object? convert(Object? input) {
    if (input == null) return null;

    // Return input as is, GoRouter will handle serialization
    return input;
  }
}

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final authNotifier = AuthNotifier();

  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    // Add custom codec to handle Map<String, Object> extras
    extraCodec: const MapExtraCodec(),
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoading = authNotifier.isLoading;
      final bool isLoggedIn = authNotifier.isLoggedIn;
      final bool isProfileCompleted = authNotifier.isProfileCompleted;

      final bool isGoingToSplash = state.matchedLocation == Routes.splash;
      final bool isProfileScreen = state.matchedLocation == Routes.profile ||
          state.matchedLocation.startsWith('/auth/profile');
      final bool isInterestsScreen =
          state.matchedLocation == Routes.interests ||
              state.matchedLocation.startsWith('/auth/interests');
      final bool isAuthScreen = state.matchedLocation.contains('/auth/');

      print("GoRouter redirect - Current location: ${state.matchedLocation}");
      print("GoRouter redirect - Profile completed: $isProfileCompleted");
      print("GoRouter redirect - Auth screen: $isAuthScreen");

      // Don't redirect while still loading
      if (isLoading) {
        print("GoRouter redirect - Still loading, no redirect");
        return null;
      }

      if (isGoingToSplash) {
        print("GoRouter redirect - Going to splash, no redirect");
        return null;
      }

      // Not logged in but trying to access non-auth screens
      if (!isLoggedIn && !isAuthScreen) {
        print("GoRouter redirect - Not logged in, redirecting to login");
        return Routes.login;
      }

      // Check profile completion status - this should take priority
      if (isLoggedIn && !isProfileCompleted) {
        // If user is going to profile or interests screens, allow it
        if (isProfileScreen || isInterestsScreen) {
          print(
              "GoRouter redirect - Incomplete profile but already on profile/interests screen, no redirect");
          return null;
        }

        // Otherwise redirect to profile setup
        print(
            "GoRouter redirect - Incomplete profile, redirecting to profile setup");
        final user = FirebaseAuth.instance.currentUser;
        return Routes.profileWithEmail(user?.email ?? "");
      }

      // If profile is completed and user is on auth screens that aren't needed anymore
      if (isLoggedIn &&
          isProfileCompleted &&
          isAuthScreen &&
          !isGoingToSplash) {
        print(
            "GoRouter redirect - Profile completed but on auth screen, redirecting to home");
        return Routes.home;
      }

      print("GoRouter redirect - No redirect needed");
      return null;
    },

    // Handle redirects
    redirectLimit: 5,
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
        path: Routes.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final Map<String, dynamic>? extra =
              state.extra as Map<String, dynamic>?;
          if (extra == null) {
            throw Exception('Extra data is missing for this route.');
          }
          return EditProfileScreen(
            userId: extra['userId'] as String,
            initialName: extra['initialName'] as String,
            initialUsername: extra['initialUsername'] as String,
            initialBio: extra['initialBio'] as String,
          );
        },
      ),
      GoRoute(
        path: Routes.editField,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>;
          final String fieldTypeStr =
              state.pathParameters['fieldType'] ?? 'name';

          // Convert string to enum
          FieldType fieldType;
          switch (fieldTypeStr) {
            case 'username':
              fieldType = FieldType.username;
              break;
            case 'bio':
              fieldType = FieldType.bio;
              break;
            case 'name':
            default:
              fieldType = FieldType.name;
              break;
          }

          return EditFieldScreen(
            userId: extra['userId'] as String,
            initialValue: extra['initialValue'] as String,
            fieldType: fieldType,
          );
        },
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
        name: 'groupChat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final group = state.extra as GroupData?;
          if (group == null) {
            return GroupChatScreen(
              group: GroupData(
                id: 'group_chat_default',
                name: 'Group Chat',
                description: '',
                memberCount: 0,
                messageCount: 0,
                avatars: [],
                isMember: true,
              ),
            );
          }
          return GroupChatScreen(group: group);
        },
      ),
      GoRoute(
        path: Routes.chat,
        name: 'chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // Check if extra is ChatUser or Map
          if (state.extra is ChatUser) {
            final userData = state.extra as ChatUser;
            return ChatScreen(userData: userData);
          } else if (state.extra is Map<String, dynamic>) {
            final Map<String, dynamic> params =
                state.extra as Map<String, dynamic>;
            return HumanChatScreen(
              conversationId: params['conversationId'] as String,
              otherUserName: params['otherUserName'] as String,
              otherUserId: params['otherUserId'] as String,
            );
          }

          // Fallback in case of unexpected type
          throw Exception(
              'Unexpected extra type for chat route: ${state.extra.runtimeType}');
        },
      ),
      GoRoute(
        path: Routes.postChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>;
          return PostChatScreen(
            name: extra['name'] as String,
            profileImageURL: extra['profileImageURL'] as String,
            chat: extra['chat'] as String,
            avatarID: extra['avatarID'] as String,
          );
        },
      ),
      GoRoute(
        path: Routes.contentSelection,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ContentSelectionSettingsScreen(),
      ),
      // GoRoute(
      //   path: Routes.subscription,
      //   parentNavigatorKey: rootNavigatorKey,
      //   pageBuilder: (context, state) => CupertinoPage(
      //     key: state.pageKey,
      //     fullscreenDialog: true,
      //     child: const SubscriptionScreen(),
      //   ),
      // ),
      GoRoute(
        path: Routes.referral,
        name: 'referral',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const CupertinoPage(
          fullscreenDialog: true,
          child: ReferralScreen(),
        ),
      ),

      // GoRoute(
      //   path: Routes.referral,
      //   parentNavigatorKey: rootNavigatorKey,
      //   builder: (context, state) => const ReferralScreen(),
      // ),
    ],
  );
}
