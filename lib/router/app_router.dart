import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:inzone/router/auth_notifier.dart';
import 'package:inzone/root_app.dart';
import 'package:inzone/screen/ai_character/ai_char_select_screen.dart';
import 'package:inzone/screen/auth/introduction_screen.dart';
import 'package:inzone/screen/auth/signin_login_screen.dart';
import 'package:inzone/screen/auth/profile_screen.dart' as auth;
import 'package:inzone/screen/auth/interesting_select_screen.dart';
import 'package:inzone/screen/common/home_screen.dart';
import 'package:inzone/screen/common/notificationScreen.dart';
import 'package:inzone/screen/common/search_explore_screen.dart';
import 'package:inzone/screen/common/characters_screen.dart';
import 'package:inzone/screen/explore/groups_explore_screen.dart';
import 'package:inzone/screen/chat/all_chats_screen.dart';
import 'package:inzone/screen/profile/user_profile_screen.dart';
import 'package:inzone/screen/profile/profile_screen.dart';
import 'package:inzone/screen/profile/edit_profile_screen.dart';
import 'package:inzone/screen/profile/edit_field_screen.dart';
import 'package:inzone/screen/profile/followers_following_screen.dart';
import 'package:inzone/screen/post/post_screen.dart';
import 'package:inzone/screen/post/edit_post_screen.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:inzone/screen/chat/group_chat_screen.dart';
import 'package:inzone/screen/chat/chat_screen.dart';
import 'package:inzone/screen/chat/human_chat_screen.dart';
import 'package:inzone/screen/chat/post_chat_screen.dart';
import 'package:inzone/screen/settings/content_select_screen.dart';
import 'package:inzone/screen/settings/referral_screen.dart';
import 'package:inzone/screen/settings/settings_screen.dart';
import 'package:inzone/screen/notifications/notification_center_screen.dart';
import 'package:inzone/screen/notifications/notification_settings_screen.dart';
import 'package:inzone/screen/3d_model/3d_model_prompt_screen.dart';
import 'package:inzone/screen/3d_model/3d_model_select_screen.dart';
import 'package:inzone/screen/3d_model/3d_model_intro.dart';
import 'package:inzone/screen/settings/unity_webview_screen.dart';
import 'package:inzone/components/cards/tip_screen.dart';
import 'package:inzone/screen/chat/voice_screen.dart';

// Onboarding screens
import 'package:inzone/screen/onboarding/onboardinScreen.dart';
// Force update screen
import 'package:inzone/screen/auth/force_update_screen.dart';

// Models
import 'package:inzone/data/group_data.dart';

// Routes
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/terms/policy.dart';
import 'package:inzone/screen/terms/terms.dart';

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

  static void setInitialRoute(String route) {
    router.go(route);
  }

  static final GoRouter router = GoRouter(
    initialLocation: Routes.home,
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    // Add custom codec to handle Map<String, Object> extras
    extraCodec: const MapExtraCodec(),
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoading = authNotifier.isLoading;
      final bool isLoggedIn = authNotifier.isLoggedIn;
      final bool isProfileCompleted = authNotifier.isProfileCompleted;

      final bool isProfileScreen = state.matchedLocation == Routes.profile ||
          state.matchedLocation.startsWith('/auth/profile');
      final bool isInterestsScreen =
          state.matchedLocation == Routes.interests ||
              state.matchedLocation.startsWith('/auth/interests');
      final bool isAuthScreen = state.matchedLocation.contains('/auth/');

      final bool isOnboardingScreen =
          state.matchedLocation.startsWith('/onboarding');

      print("GoRouter redirect - Current location: ${state.matchedLocation}");
      print("GoRouter redirect - Profile completed: $isProfileCompleted");
      print("GoRouter redirect - Auth screen: $isAuthScreen");
      print("GoRouter redirect - Onboarding screen: $isOnboardingScreen");

      if (isLoading) {
        print("GoRouter redirect - Still loading, no redirect");
        return null;
      }

      // Onboarding screen should only be accessible when not logged in
      if (isOnboardingScreen) {
        if (isLoggedIn) {
          print(
              "GoRouter redirect - User is logged in, redirecting from onboarding to home");
          return Routes.home;
        } else {
          print(
              "GoRouter redirect - User not logged in, allowing access to onboarding");
          return null;
        }
      }

      // Not logged in but trying to access non-auth screens
      if (!isLoggedIn && !isAuthScreen) {
        print("GoRouter redirect - Not logged in, redirecting to onboarding");
        return Routes.onboarding;
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

      // If profile is completed and user is on auth screens that aren't needed anymore.
      // With completion now gated strictly on `createdAt` (set only at the end of
      // the interests screen), a mid-setup user is never "completed", so this no
      // longer bounces anyone off the profile/interests screens.
      if (isLoggedIn && isProfileCompleted && isAuthScreen) {
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
      // 🚀 Force Update route (should be first to bypass all redirects)
      GoRoute(
        path: Routes.forceUpdate,
        builder: (context, state) => const ForceUpdateScreen(),
      ),

      // 🚀 Onboarding route
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardPage(),
      ),

      // 🚀 Auth and splash routes
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => Container(),
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
          return NoTransitionPage(
            key: state.pageKey,
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
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
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
          GoRoute(
            path: Routes.searchExplore,
            builder: (context, state) {
              return const SearchExploreScreen();
            },
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, state) {
              return const NotificationScreen();
            },
          ),
          GoRoute(
            path: Routes.characters,
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: CharactersScreen(),
              );
            },
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
        path: Routes.editPost,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final post = state.extra as InZonePost;
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: EditPostScreen(post: post),
          );
        },
      ),

      /* --------- 3d Model Routes --------- */
      GoRoute(
        path: Routes.create3dModelIntro,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const ModelIntroScreen(),
        ),
      ),
      GoRoute(
        path: Routes.create3dModel,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          // Check if we should use a fade transition
          final Map<String, dynamic>? extra =
              state.extra as Map<String, dynamic>?;
          final bool useFadeTransition =
              extra != null && extra['transition'] == 'fade';

          return useFadeTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: const ModelPromptScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                )
              : CupertinoPage(
                  key: state.pageKey,
                  fullscreenDialog: true,
                  child: const ModelPromptScreen(),
                );
        },
      ),
      GoRoute(
        path: Routes.create3dModelSelect,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>;
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: Model3DSelectScreen(
              prompt: extra['prompt'] as String,
              name: extra['name'] as String,
            ),
          );
        },
      ),
      /* ---------- ai char routes ---------- */
      // GoRoute(
      //   path: Routes.createAICharacter,
      //   parentNavigatorKey: rootNavigatorKey,
      //   pageBuilder: (context, state) => CupertinoPage(
      //     key: state.pageKey,
      //     fullscreenDialog: true,
      //     child: const AICharacterPromptScreen(),
      //   ),
      // ),

      GoRoute(
        path: Routes.createAICharacterSelect,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final Map<String, dynamic>? extra =
              state.extra as Map<String, dynamic>?;

          // Provide default values if extra is null
          final String name = extra?['name'] as String? ?? "AI Character";
          final String prompt = extra?['prompt'] as String? ?? "";
          final String profilePictureUrl =
              extra?['profilePictureUrl'] as String? ?? "";
          final String characterId = extra?['characterId'] as String? ?? "";

          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: AICharacterSelectionScreen(
              name: name,
              prompt: prompt,
              profilePictureUrl: profilePictureUrl,
              characterId: characterId,
            ),
          );
        },
      ),

      /* --------- Profile and Edit Routes --------- */
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
          // Pass the entire GoRouterState to access query parameters
          return ProfileScreen(uid: uid, routerState: state);
        },
      ),
      GoRoute(
        path: Routes.followersFollowing,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final startWithFollowers = state.extra as bool? ?? true;
          return FollowersFollowingScreen(
            userId: userId,
            startWithFollowers: startWithFollowers,
          );
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
                showRandomCharacters: true,
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

            // Check if this is a serialized ChatUser (has name, email fields but no conversationId)
            if (params.containsKey('name') &&
                params.containsKey('email') &&
                !params.containsKey('conversationId') &&
                !params.containsKey('otherUserId')) {
              // Create ChatUser from the map
              return ChatScreen(
                  userData: ChatUser(
                name: params['name'] as String?,
                email: params['email'] as String?,
                chatId: params['chatId'] as String?,
                profilePictureURL: params['profilePictureURL'] as String?,
                lastMessage: params['lastMessage'] as String?,
                isHuman: params['isHuman'] as bool? ?? false,
                isGroupChat: params['isGroupChat'] as bool? ?? false,
              ));
            }

            // Regular human chat
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
        routes: [
          GoRoute(
            path: 'voice',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, String>?;
              final avatarUrl = extra?['avatarUrl'] ?? '';
              final avatarId = extra?['avatarId'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: VoiceScreen(avatarUrl: avatarUrl, avatarId: avatarId),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                opaque: false,
                transitionDuration: const Duration(milliseconds: 300),
              );
            },
          ),
        ],
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
            initialText: extra['initialText'] as String?,
            minigameLink: extra['minigameLink'] as String?,
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

      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),

      GoRoute(
        path: Routes.notificationCenter,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationCenterScreen(),
      ),

      GoRoute(
        path: Routes.notificationSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      GoRoute(
        path: Routes.tipScreen,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TipScreen(
          recipient: {
            'id': FirebaseAuth.instance.currentUser?.uid ?? '',
            'name': 'User',
            'username': 'user',
            'profilePicture': '',
          },
        ),
      ),

      GoRoute(
        path: Routes.privacyPolicy,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: const PolicyScreen(),
          );
        },
      ),

      GoRoute(
        path: Routes.termsConditions,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: const TermsScreen(),
          );
        },
      ),

      GoRoute(
        path: Routes.unityWebGame,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: const UnityWebviewScreen(),
          );
        },
      ),

      // 🚀 Onboarding Routes
      GoRoute(
        path: Routes.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          return CupertinoPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: const OnboardPage(),
          );
        },
      ),
    ],
  );
}
