# iOS App Privacy Documentation

This document provides the information needed for Apple App Store Privacy Nutrition Label disclosures when using the Simula Ad SDK.

## Overview

The Simula Ad SDK is a contextual advertising SDK that displays native ads within mobile applications. This document outlines the data collection practices to help publishers complete their App Store Privacy Nutrition Label.

## Data Collection Summary

### Data Types Collected

#### 1. Device ID (Session ID)
- **Type**: Device ID
- **Linked to User**: No
- **Used for Tracking**: No
- **Purpose**: App Functionality
- **Description**: A temporary session identifier generated server-side to enable ad delivery within a single app session. This is essential for the SDK to function and is not used to track users across apps or websites.

#### 2. Location (City-level)
- **Type**: Location
- **Linked to User**: No
- **Used for Tracking**: No
- **Purpose**: Advertising or Marketing
- **Description**: Approximate city-level location derived from IP address. Used for geo-targeted ad delivery (e.g., showing ads relevant to user's region). Not precise location data.

#### 3. User ID (Primary User ID)
- **Type**: User ID
- **Linked to User**: Yes
- **Used for Tracking**: No
- **Purpose**: Advertising or Marketing
- **Collection**: Optional, only when privacy consent is granted
- **Description**: Publisher-provided user identifier (e.g., Chai user ID). Used for cross-device ad targeting and frequency capping when user is logged in. Only collected when `hasPrivacyConsent` is `true`.

#### 4. Email Address
- **Type**: Email Address
- **Linked to User**: Yes
- **Used for Tracking**: No
- **Purpose**: Advertising or Marketing
- **Collection**: Optional, only when privacy consent is granted
- **Description**: User email address provided via `NativeContext`. Used for ad targeting and personalization. Only collected when `hasPrivacyConsent` is `true` and email is provided in context.

#### 5. Device ID (IDFA)
- **Type**: Device ID
- **Linked to User**: Yes
- **Used for Tracking**: Yes
- **Purpose**: Advertising or Marketing
- **Collection**: Optional, only when ATT (App Tracking Transparency) is authorized
- **Description**: Apple's Identifier for Advertisers (IDFA). Used for device-level ad targeting and attribution. Only collected when:
  - Platform is iOS
  - User has authorized tracking via ATT prompt
  - ATT status is `authorized`

## Data Not Collected

The SDK does **NOT** collect:
- Precise location (GPS coordinates)
- Contacts
- Photos or videos
- Audio data
- Health and fitness data
- Payment information
- Sensitive information
- Device fingerprinting (when ATT is denied)

## Privacy Controls

### Privacy Consent
- Publishers can control PII collection via `hasPrivacyConsent` parameter
- When `false`: Suppresses collection of `primaryUserID`, `userEmail`, and `userProfile`
- When `true`: Allows collection of PII (with user consent)

### ATT (App Tracking Transparency)
- SDK reads ATT authorization status (does not show prompt)
- Publisher app (Chai) owns the ATT prompt
- IDFA only collected when ATT is `authorized`
- No device fingerprinting when ATT is `denied`

## Data Usage

### How Data is Used
1. **Ad Delivery**: Session ID and geo data are essential for serving ads
2. **Ad Targeting**: User ID, email, and IDFA improve ad relevance
3. **Frequency Capping**: Prevents showing too many ads to the same user
4. **Attribution**: IDFA used for measuring ad effectiveness

### Data Sharing
- Data is sent to Simula's ad servers for ad delivery
- No data is shared with third-party advertisers (ads are served directly by Simula)
- Data is not sold to third parties

## Data Retention

- **Session Data**: Retained for the duration of the session (temporary)
- **User Data**: Retained for up to 90 days for ad targeting purposes
- **Analytics Data**: Aggregated and anonymized data may be retained longer for analytics

## User Rights

Users can:
- Opt out of PII collection by setting `hasPrivacyConsent` to `false`
- Deny ATT permission to prevent IDFA collection
- Request data deletion (contact publisher or Simula support)

## App Store Privacy Nutrition Label

### Required Disclosures

When completing your App Store Privacy Nutrition Label, include the following based on your usage:

#### If using with privacy consent enabled:
- ✅ Collects: User ID, Email Address
- ✅ Collects: Device ID (IDFA) - if ATT authorized
- ✅ Collects: Location (approximate)
- ✅ Collects: Device ID (session)

#### If using without privacy consent:
- ✅ Collects: Location (approximate)
- ✅ Collects: Device ID (session)
- ❌ Does NOT collect: User ID, Email, IDFA

### Tracking Disclosure

**Does your app use data to track users?**
- **Answer**: Depends on ATT authorization
  - If ATT authorized: Yes (IDFA used for tracking)
  - If ATT denied: No (no tracking identifiers used)

**Does your app share data with third parties for tracking?**
- **Answer**: No (data is only used by Simula for ad delivery, not shared with third parties)

## Implementation Notes

### For Publishers

1. **Privacy Consent**: Integrate with your existing consent management system
   ```dart
   SimulaProvider(
     apiKey: 'your-api-key',
     hasPrivacyConsent: userHasConsented, // From your consent flow
     primaryUserID: userId, // Only sent if consent granted
   )
   ```

2. **ATT Prompt**: Show ATT prompt in your app before initializing SDK
   ```swift
   // In your iOS app
   ATTrackingManager.requestTrackingAuthorization { status in
     // SDK will automatically read this status
   }
   ```

3. **Privacy Policy**: Update your privacy policy to include:
   - Data collected by Simula SDK
   - How data is used
   - User rights and controls

## Compliance

- ✅ Complies with Apple App Store guidelines
- ✅ Respects ATT framework requirements
- ✅ No fingerprinting when ATT denied
- ✅ GDPR/CCPA compliant (when used with proper consent)

## Support

For questions about privacy or data collection:
- Email: privacy@simula.ad
- Documentation: https://docs.simula.ad/privacy

---

**Last Updated**: January 2026
**SDK Version**: 1.0.0
