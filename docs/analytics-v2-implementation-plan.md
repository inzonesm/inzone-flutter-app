# Analytics v2 Implementation Plan

## Goal

Create a single, testable analytics architecture for InZone that unifies event capture, user identity, deep-link handling, community game session tracking, and purchase attribution without changing production behavior during this planning phase.

## Current architecture

### App startup and initialization
- [lib/main.dart](lib/main.dart) initializes Firebase, Firebase Analytics, AppsFlyer, RevenueCat/Purchases, remote config, notifications, and the app shell.
- [lib/root_app.dart](lib/root_app.dart) hosts deep-link handling, app navigation, and the community-game/open-minigame flows.
- [lib/router/app_router.dart](lib/router/app_router.dart) intercepts deep-link URIs and redirects them to valid in-app routes.

### Analytics-related services
- [lib/services/appsflyer_service.dart](lib/services/appsflyer_service.dart) is the largest analytics hub. It initializes the AppsFlyer SDK, handles attribution/deep-link payloads, stores pending deep-link state, logs many app events, and sets customer user IDs.
- [lib/services/analytics_service.dart](lib/services/analytics_service.dart) is a thin Firebase Analytics wrapper for a small number of character events.
- [lib/services/inzone_database.dart](lib/services/inzone_database.dart) exposes a generic event logging helper that proxies into AppsFlyer.
- [lib/services/comment_analytics.dart](lib/services/comment_analytics.dart) wraps comment-related events through AppsFlyer.
- [lib/services/game_session_analytics.dart](lib/services/game_session_analytics.dart) is a thin bridge to community game session writes.
- [lib/services/reward_ad_service.dart](lib/services/reward_ad_service.dart) uses Firebase Analytics for ad impression logging.
- [lib/services/notification_service.dart](lib/services/notification_service.dart) and [lib/services/notification_event_service.dart](lib/services/notification_event_service.dart) emit notification lifecycle events through AppsFlyer.

### Current analytics integrations by feature area
- Content and social events are emitted from [lib/components/cards/post_card.dart](lib/components/cards/post_card.dart), [lib/components/cards/repost_card.dart](lib/components/cards/repost_card.dart), [lib/components/video/video_widget.dart](lib/components/video/video_widget.dart), [lib/screen/chat/chat_screen.dart](lib/screen/chat/chat_screen.dart), [lib/screen/chat/group_chat_screen.dart](lib/screen/chat/group_chat_screen.dart), [lib/screen/common/characters_screen.dart](lib/screen/common/characters_screen.dart), [lib/screen/common/home_screen.dart](lib/screen/common/home_screen.dart), and [lib/screen/common/search_explore_screen.dart](lib/screen/common/search_explore_screen.dart).
- Community-game engagement and comments are handled by [lib/screen/common/community_game_screen.dart](lib/screen/common/community_game_screen.dart), [lib/components/social_overlay/game_comments_service.dart](lib/components/social_overlay/game_comments_service.dart), [lib/components/social_overlay/social_actions_service.dart](lib/components/social_overlay/social_actions_service.dart), and [lib/components/social_overlay/social_bridge.dart](lib/components/social_overlay/social_bridge.dart).
- Purchases are routed through [lib/services/monetization_service.dart](lib/services/monetization_service.dart), with UI entry points in [lib/components/cards/tip_screen.dart](lib/components/cards/tip_screen.dart), [lib/screen/chat/group_chat_screen.dart](lib/screen/chat/group_chat_screen.dart), [lib/screen/explore/groups_explore_screen.dart](lib/screen/explore/groups_explore_screen.dart), and [lib/screen/settings/settings_screen.dart](lib/screen/settings/settings_screen.dart).

## Problems with the current analytics setup

1. No single source of truth
   - Event emission is spread across multiple services and screens.
   - Some events are sent to AppsFlyer, some to Firebase Analytics, and some to both indirectly.

2. Event contracts are inconsistent
   - Event names, payload keys, and user-context enrichment vary by caller.
   - There is no shared validation layer for required fields.

3. Deep-link logic is coupled to analytics and navigation
   - Deep-link handling is split between AppsFlyer callbacks, app_links, GoRouter redirects, and RootApp listeners.
   - Cold-start handling is implemented with ad-hoc streams and pending-state flags, which is difficult to reason about and test.

4. Community game sessions are not part of a unified event model
   - Sessions are written to Firestore in [lib/services/community_game_service.dart](lib/services/community_game_service.dart) and recorded from [lib/screen/common/community_game_screen.dart](lib/screen/common/community_game_screen.dart), but they are not coordinated with app-wide analytics events.

5. Purchase flow is not modeled as analytics lifecycle
   - Purchases are processed by [lib/services/monetization_service.dart](lib/services/monetization_service.dart), but there is no standardized purchase-start/purchase-success/purchase-failed event pipeline.

6. Guest identity is partially implemented
   - [lib/components/social_overlay/game_comments_service.dart](lib/components/social_overlay/game_comments_service.dart) has a per-install guest identity model, but that identity is not consistently integrated into broader analytics context or session tracking.

## Recommended architecture

### 1. Introduce a unified analytics facade
Create a single canonical event interface, for example an AnalyticsFacade service that accepts normalized events such as:
- app_open
- screen_view
- deep_link_received
- community_game_session_started
- community_game_session_ended
- purchase_started
- purchase_completed
- purchase_failed
- guest_identity_resolved

The facade should be responsible for:
- validating event names and payloads
- attaching consistent user/device/context fields
- routing the same event to the correct transport(s)
- maintaining a standardized schema for future dashboards and QA

### 2. Separate transport adapters from domain logic
Keep transport-specific code isolated:
- AppsFlyer adapter for attribution and marketing events
- Firebase Analytics adapter for Firebase-native reporting and user properties
- Firestore/session adapter for game-session and engagement data

The screens and services should call the facade, not the SDKs directly.

### 3. Standardize identity and context
Use one identity context object that contains:
- Firebase user id when available
- guest id when not signed in
- device/app info
- referral/source information
- current feature context (community game, purchase, notification, chat, etc.)

This should be initialized in [lib/main.dart](lib/main.dart) and updated as auth state and deep-link attribution change.

### 4. Consolidate deep-link handling
Move deep-link coordination into one place so warm starts, cold starts, AppsFlyer callbacks, and app_links all feed the same canonical handler.

### 5. Make community game sessions first-class analytics events
Community game session writes in [lib/services/community_game_service.dart](lib/services/community_game_service.dart) should be treated as a core analytics workflow and emitted through the same normalized event system as the rest of the app.

## Every file that must change

### Core analytics infrastructure
- [lib/services/appsflyer_service.dart](lib/services/appsflyer_service.dart)
- [lib/services/analytics_service.dart](lib/services/analytics_service.dart)
- [lib/services/inzone_database.dart](lib/services/inzone_database.dart)
- [lib/services/comment_analytics.dart](lib/services/comment_analytics.dart)
- [lib/services/game_session_analytics.dart](lib/services/game_session_analytics.dart)
- [lib/services/community_game_service.dart](lib/services/community_game_service.dart)
- [lib/services/monetization_service.dart](lib/services/monetization_service.dart)
- [lib/services/reward_ad_service.dart](lib/services/reward_ad_service.dart)

### Initialization and navigation
- [lib/main.dart](lib/main.dart)
- [lib/root_app.dart](lib/root_app.dart)
- [lib/router/app_router.dart](lib/router/app_router.dart)

### Community game and social engagement
- [lib/screen/common/community_game_screen.dart](lib/screen/common/community_game_screen.dart)
- [lib/components/social_overlay/game_comments_service.dart](lib/components/social_overlay/game_comments_service.dart)
- [lib/components/social_overlay/social_actions_service.dart](lib/components/social_overlay/social_actions_service.dart)
- [lib/components/social_overlay/social_bridge.dart](lib/components/social_overlay/social_bridge.dart)

### Content and user journey events
- [lib/screen/common/home_screen.dart](lib/screen/common/home_screen.dart)
- [lib/screen/common/search_explore_screen.dart](lib/screen/common/search_explore_screen.dart)
- [lib/screen/chat/chat_screen.dart](lib/screen/chat/chat_screen.dart)
- [lib/screen/chat/group_chat_screen.dart](lib/screen/chat/group_chat_screen.dart)
- [lib/screen/common/characters_screen.dart](lib/screen/common/characters_screen.dart)
- [lib/components/video/video_widget.dart](lib/components/video/video_widget.dart)
- [lib/components/cards/post_card.dart](lib/components/cards/post_card.dart)
- [lib/components/cards/repost_card.dart](lib/components/cards/repost_card.dart)

### Notification and purchase entry points
- [lib/services/notification_service.dart](lib/services/notification_service.dart)
- [lib/services/notification_event_service.dart](lib/services/notification_event_service.dart)
- [lib/components/cards/tip_screen.dart](lib/components/cards/tip_screen.dart)
- [lib/screen/explore/groups_explore_screen.dart](lib/screen/explore/groups_explore_screen.dart)
- [lib/screen/settings/settings_screen.dart](lib/screen/settings/settings_screen.dart)

## Exact responsibilities of each file

### [lib/services/appsflyer_service.dart](lib/services/appsflyer_service.dart)
- Become the AppsFlyer transport adapter only.
- Own SDK initialization and attribution/deep-link payload parsing.
- Normalize incoming payloads into canonical analytics events.
- No longer contain screen-specific event logic.

### [lib/services/analytics_service.dart](lib/services/analytics_service.dart)
- Become the Firebase Analytics adapter for canonical events.
- Manage Firebase user properties and consent-related state.
- Expose a stable API for the unified facade.

### [lib/services/inzone_database.dart](lib/services/inzone_database.dart)
- Preserve the existing API surface for callers that use the database wrapper.
- Route those calls through the new facade instead of directly calling AppsFlyer.

### [lib/services/comment_analytics.dart](lib/services/comment_analytics.dart)
- Convert comment interaction events into the new canonical schema.
- Ensure comment events include identity context and payload validation.

### [lib/services/game_session_analytics.dart](lib/services/game_session_analytics.dart)
- Remain the bridge to community-game session lifecycle, but emit normalized session events.
- Coordinate with the facade so session lifecycle is visible in the unified analytics pipeline.

### [lib/services/community_game_service.dart](lib/services/community_game_service.dart)
- Keep Firestore writes for community game sessions.
- Ensure session documents include the fields needed for both analytics and product reporting.
- Add any missing metadata needed for the new event schema.

### [lib/services/monetization_service.dart](lib/services/monetization_service.dart)
- Emit standardized purchase lifecycle events before, during, and after the backend purchase calls.
- Preserve the current receipt verification flow.

### [lib/services/reward_ad_service.dart](lib/services/reward_ad_service.dart)
- Continue logging ad impressions through Firebase Analytics.
- Route through the unified facade where possible to avoid duplicate event wiring.

### [lib/main.dart](lib/main.dart)
- Initialize the new analytics facade and its transports.
- Set app-level identity context, user properties, and startup timing context.
- Keep startup initialization non-blocking so the app continues to load.

### [lib/root_app.dart](lib/root_app.dart)
- Own the app-shell deep-link coordinator.
- Receive canonical deep-link events and route them to the correct screen while preserving current UX.

### [lib/router/app_router.dart](lib/router/app_router.dart)
- Intercept external deep-link URIs and hand them to the unified deep-link coordinator.
- Ensure redirects remain safe and do not break app navigation.

### [lib/screen/common/community_game_screen.dart](lib/screen/common/community_game_screen.dart)
- Start/end the community-game session lifecycle using the new facade.
- Preserve current gameplay behavior while adding standardized session events.

### [lib/components/social_overlay/game_comments_service.dart](lib/components/social_overlay/game_comments_service.dart)
- Preserve the existing guest identity model.
- Ensure guest/registered identity is included in the analytics context for comments and replies.

## Order of implementation

1. Define the canonical event schema and event inventory
   - Document required fields, event names, and allowed values.
   - Decide which events are emitted to AppsFlyer, Firebase Analytics, Firestore, or multiple destinations.

2. Introduce the unified analytics facade and transport adapters
   - Create the facade API and initial adapter implementations.
   - Keep current call sites unchanged while wiring the facade behind the existing services.

3. Migrate identity and startup context
   - Attach authentication state, guest identity, app version, and attribution context.
   - Ensure user properties and first-session initialization work before feature events are emitted.

4. Migrate deep-link handling and community game session tracking
   - Centralize deep-link routing and unify the warm/cold-start logic.
   - Connect community game session start/end events to the same event pipeline.

5. Migrate purchase and ad events
   - Add purchase lifecycle telemetry without breaking receipt verification.
   - Keep RevenueCat and backend purchase flow intact.

6. Migrate remaining feature events
   - Repoint content/social/notification events to the new facade while preserving event names for existing dashboards during the transition.

7. Add regression tests and dashboard validation
   - Validate event routing, payload shape, guest identity, and deep-link behavior.
   - Monitor for duplicate events during rollout.

## Risks

- Duplicate event emission during the migration window could inflate dashboards.
- Deep-link behavior can change if the old stream-based logic is replaced too aggressively.
- Purchase flows are sensitive to timing and may need careful sequencing around receipt completion and backend verification.
- Guest identity changes could affect comment-thread expectations or analytics correlation if not handled carefully.
- Firebase and AppsFlyer network availability and privacy restrictions can cause partial failures that should not break the app.

## Backwards compatibility

- Preserve the existing event names for the first rollout phase where possible.
- Support event aliasing so existing dashboards continue to work while the new schema is introduced.
- Keep current deep-link URIs and community-game Firestore document shapes intact.
- Make the new facade backward-compatible with existing callers by routing through existing service wrappers first.
- Use feature flags or environment flags to disable the new transport layer if a rollout issue appears.

## Testing strategy

### Unit tests
- Validate canonical event schema mapping.
- Ensure payloads include the expected identity and context fields.
- Verify that legacy event names are still emitted during the transition window.

### Widget and screen tests
- Verify community game session start/end events from [lib/screen/common/community_game_screen.dart](lib/screen/common/community_game_screen.dart).
- Confirm that deep-link navigation still opens the expected screens after refactoring.

### Integration tests
- Exercise cold-start and warm-start deep-link handling with both AppsFlyer-style payloads and app_links URIs.
- Confirm that Firestore session writes happen as expected for open/closed sessions.
- Verify purchase lifecycle telemetry from the monetization layer without relying on network-side backend behavior.

### QA checklist
- Duplicate event count stays flat after enabling the new facade.
- Community game sessions appear in Firestore with the expected lifecycle fields.
- Deep links still open the intended game or route on both cold and warm starts.
- Guest and signed-in users emit the expected identity context.

## Scope for this first step

This document covers the architecture and implementation plan only. No production code will be changed in this step. The implementation work will begin only after this plan is reviewed and approved.
