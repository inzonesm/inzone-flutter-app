# Privacy & Compliance Implementation Plan

## Overview
This document outlines the implementation plan for privacy and compliance features in the Simula Ad SDK for Flutter, ensuring compliance with GDPR, COPPA, iOS App Tracking Transparency (ATT), Apple App Store, and Google Play Store requirements.

---

## Current Data Collection Analysis

### Data Currently Collected

#### Client-Side (Flutter SDK):
- **Session ID** - Generated server-side, essential for ad delivery
- **Primary User ID (ppid)** - Optional, provided by Chai app for cross-device tracking
- **Native Context** - Includes:
  - `userEmail` - Optional email address
  - `userProfile` - Optional user profile data
  - `tags`, `searchTerm`, `category`, `title`, `description` - Contextual signals
  - `customContext` - Additional contextual data

#### Server-Side (API):
- **IP Address** - From `x-forwarded-for` header (for geo-targeting)
- **User Agent** - For device/OS detection
- **Cookies** - `simula_uid` cookie (if not present, creates one)
- **Geo Data** - Derived from IP (city, state, country, postal code, metro code)
- **Device Data** - Derived from User Agent (device type, OS, make, model, browser)

### Data That Should Be Gated by Privacy Consent
- ❌ `primaryUserID` (ppid)
- ❌ `userEmail`
- ❌ `userProfile`
- ✅ Session ID (essential for ad delivery)
- ✅ Contextual tags/categories (contextual targeting, not PII)
- ✅ IP address & geo data (essential for ad delivery, but should be documented)

### Data Related to ATT (iOS Only)
- **IDFA (Identifier for Advertisers)** - Currently not collected, but will be needed when ATT is authorized
- **Device fingerprinting** - Currently not implemented, but must be explicitly avoided when ATT denied

---

## Phase 1: Privacy Consent & Opt-Out (Minimum Required)

### 1.1 Flutter SDK Changes

#### A. Add Privacy State Management
**File**: `lib/src/models/types.dart`
- Add `PrivacyConsent` enum or class to track consent state
- Track both `hasPrivacyConsent` and `attAuthorizationStatus` (iOS only)

**File**: `lib/src/widgets/simula_provider.dart`
- Add `hasPrivacyConsent` parameter (default: `true` for backward compatibility)
- Store consent state in `SimulaNotifier`
- Add `setPrivacyConsent(bool)` method to `SimulaNotifier` for mid-session updates

#### B. Gate Data Collection Based on Consent
**File**: `lib/src/api/api_client.dart`
- Modify `createSession()` to conditionally include `ppid` parameter only when `hasPrivacyConsent == true`
- Modify `fetchAd()` to conditionally include `userEmail` and `userProfile` in `NativeContext` only when `hasPrivacyConsent == true`

**File**: `lib/src/widgets/native_ad_slot.dart` (and other widgets using NativeContext)
- Ensure `userEmail` and `userProfile` are only included when consent is granted

#### Implementation Steps:
1. ✅ Add `hasPrivacyConsent` boolean to `SimulaProvider` widget
2. ✅ Store consent state in `SimulaNotifier`
3. ✅ Add `setPrivacyConsent(bool)` method to `SimulaNotifier`
4. ✅ Gate `primaryUserID` in `createSession()` based on consent
5. ✅ Gate `userEmail` and `userProfile` in `NativeContext` based on consent
6. ✅ Update all widgets that create `NativeContext` to respect consent

### 1.2 Backend API Changes

#### A. Handle Missing ppid Gracefully
**File**: `project-any-sdk-api/src/app/routes/session.py`
- Currently doesn't extract `ppid` from query params - needs to be added
- Store `ppid` in session document only if provided (already optional)

#### B. Documentation
- Update API documentation to clarify that `ppid`, `userEmail`, `userProfile` are optional and should only be sent with consent

---

## Phase 2: ATT (iOS App Tracking Transparency)

### 2.1 Flutter SDK Changes

#### A. Add ATT Status Detection
**Dependencies**: Add `app_tracking_transparency` package (or use platform channels)
**File**: `lib/src/utils/att_status.dart` (new file)
- Create utility to read ATT authorization status
- Handle three states:
  - `notDetermined` - ATT prompt not shown yet
  - `authorized` - User consented to tracking
  - `denied` / `restricted` - User denied tracking

**Note**: Chai app owns the ATT prompt, SDK just reads the status.

#### B. Conditional IDFA Collection
**File**: `lib/src/api/api_client.dart`
- Only collect IDFA when:
  1. Platform is iOS
  2. ATT status is `authorized`
- Send IDFA as a header or parameter (e.g., `X-IDFA`) when available
- Use temporary session ID when IDFA unavailable (already handled by session ID)

#### C. No Fingerprinting When ATT Denied
**File**: `lib/src/api/api_client.dart`
- When ATT denied, explicitly avoid any device fingerprinting
- Only send contextual data (tags, categories) - no device identifiers

#### Implementation Steps:
1. ✅ Add `app_tracking_transparency` package dependency (or native platform channel)
2. ✅ Create `ATTStatus` enum/utility
3. ✅ Add `attAuthorizationStatus` to `SimulaProvider`
4. ✅ Read ATT status on iOS (with fallback for Android)
5. ✅ Conditionally include IDFA in API requests when authorized
6. ✅ Ensure no device fingerprinting when ATT denied

### 2.2 Backend API Changes

#### A. Accept IDFA Header
**File**: `project-any-sdk-api/src/app/routes/session.py`
- Accept `X-IDFA` or similar header
- Store in session document for ad targeting
- Only accept when ATT is authorized (frontend should gate this)

#### B. Fallback to Contextual Targeting
- When no IDFA available, use contextual signals (tags, categories, search terms)
- Geo-targeting still allowed (derived from IP, not device ID)

---

## Phase 3: App Store Compliance

### 3.1 iOS Privacy Manifest (`PrivacyInfo.xcprivacy`)

**File**: `simula-ad-sdk-flutter/ios/PrivacyInfo.xcprivacy` (new file)

**Required Declarations**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <!-- Session ID -->
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeDeviceID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <!-- Geo location (city-level from IP) -->
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeLocation</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <false/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAdvertisingOrMarketing</string>
            </array>
        </dict>
        <!-- Primary User ID (when provided with consent) -->
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeUserID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAdvertisingOrMarketing</string>
            </array>
        </dict>
        <!-- Email (when provided with consent) -->
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAdvertisingOrMarketing</string>
            </array>
        </dict>
        <!-- IDFA (only when ATT authorized) -->
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeDeviceID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <true/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAdvertisingOrMarketing</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Key Points**:
- `NSPrivacyTracking: false` - We don't do cross-app tracking
- Session ID marked as non-linked, non-tracking (essential for functionality)
- PII (email, userID) marked as linked, non-tracking
- IDFA marked as linked and tracking (only when ATT authorized)

### 3.2 iOS App Privacy Documentation

**File**: `simula-ad-sdk-flutter/IOS_APP_PRIVACY.md` (new file)

**Contents**:
- Data types collected by SDK
- Purposes for collection (ad targeting, ad delivery)
- Whether data is linked to user identity
- Whether data is used for tracking
- Third-party sharing (if any)
- Data retention policies
- User rights (opt-out, deletion)

### 3.3 Google Play Data Safety Documentation

**File**: `simula-ad-sdk-flutter/GOOGLE_PLAY_DATA_SAFETY.md` (new file)

**Contents**:
- Data types collected
- Data sharing practices (who receives data)
- Security practices (encryption in transit/at rest)
- Data deletion policies
- User rights and controls
- COPPA compliance (if app targets children)

---

## Phase 4: Additional Recommendations

### 4.1 Data Minimization
- Only collect data necessary for ad targeting/delivery
- Use hashed/encrypted identifiers when possible
- Implement data retention policies (delete old session data)

### 4.2 Transparency
- Provide clear documentation for publishers on what data is collected
- Include privacy policy links in SDK documentation
- Log consent changes for debugging/audit purposes

### 4.3 Testing
- Unit tests for consent gating logic
- Integration tests for ATT status handling
- Test consent withdrawal mid-session

### 4.4 Backward Compatibility
- Default `hasPrivacyConsent` to `true` initially (phase-in period)
- Provide clear migration guide for publishers
- Support both old and new API patterns during transition

---

## Implementation Priority

### Minimum Required (Phase 1 + Phase 3.1):
1. ✅ Privacy consent boolean in `SimulaProvider`
2. ✅ Gate `primaryUserID`, `userEmail`, `userProfile` based on consent
3. ✅ `PrivacyInfo.xcprivacy` manifest file
4. ✅ Basic privacy documentation

### Recommended (Phase 2):
5. ✅ ATT status detection and IDFA collection
6. ✅ No fingerprinting when ATT denied

### Nice to Have (Phase 3.2-3.3):
7. ✅ Detailed iOS App Privacy documentation
8. ✅ Google Play Data Safety documentation

---

## Deliverables Checklist

- [ ] Privacy consent API in Flutter SDK (`hasPrivacyConsent`, `setPrivacyConsent()`)
- [ ] Gated data collection (ppid, email, userProfile)
- [ ] ATT status detection utility
- [ ] IDFA collection when ATT authorized
- [ ] `PrivacyInfo.xcprivacy` manifest
- [ ] `IOS_APP_PRIVACY.md` documentation
- [ ] `GOOGLE_PLAY_DATA_SAFETY.md` documentation
- [ ] Updated SDK README with privacy usage examples
- [ ] Backend API support for optional ppid/IDFA
- [ ] Unit tests for consent gating
- [ ] Migration guide for publishers

---

## Open Questions / Considerations

1. **Backend ppid handling**: Currently `ppid` query param is sent but not extracted in backend session route. Need to verify if it's needed for targeting or just tracking.

2. **IDFA collection method**: Should IDFA be sent as header (`X-IDFA`) or query param? Header is more standard for identifiers.

3. **Android equivalent**: Android has similar consent mechanisms (Google Play Services consent API). Should we implement Android consent detection too?

4. **Data retention**: Should we document/implement data retention policies for session data, ad impressions, etc.?

5. **Opt-out persistence**: Should consent preferences be persisted locally (SharedPreferences) or just in-memory? Persistence recommended for better UX.

6. **Consent verification**: Should backend verify that ppid/email are only sent when consent is granted? Or rely on SDK compliance?
