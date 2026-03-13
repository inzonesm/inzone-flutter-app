# Google Play Data Safety Documentation

This document provides the information needed for Google Play Data Safety section disclosures when using the Simula Ad SDK.

## Overview

The Simula Ad SDK is a contextual advertising SDK that displays native ads within mobile applications. This document outlines the data collection, sharing, and security practices to help publishers complete their Google Play Data Safety form.

## Data Collection

### Data Types Collected

#### 1. Device or Other IDs
- **Type**: Device ID (Session ID)
- **Purpose**: App functionality, Analytics, Advertising or marketing
- **Collection**: Required for SDK functionality
- **Description**: Temporary session identifier generated server-side to enable ad delivery within a single app session. Not used to track users across apps or websites.

#### 2. Approximate Location
- **Type**: Approximate location (city-level)
- **Purpose**: Advertising or marketing
- **Collection**: Automatic (derived from IP address)
- **Description**: City-level location derived from IP address for geo-targeted ad delivery. Not precise GPS location.

#### 3. Personal Identifiers
- **Type**: User ID, Email address
- **Purpose**: Advertising or marketing
- **Collection**: Optional, only when privacy consent is granted
- **Description**: 
  - **User ID**: Publisher-provided user identifier (e.g., Chai user ID) for cross-device targeting
  - **Email**: User email address provided via `NativeContext` for ad personalization
  - Only collected when `hasPrivacyConsent` is `true`

### Data Not Collected

The SDK does **NOT** collect:
- Precise location (GPS coordinates)
- Contacts
- Photos or videos
- Audio data
- Health and fitness data
- Financial information
- Phone number
- Name
- Device fingerprinting data

## Data Sharing

### Is Data Shared?

**Answer**: Yes, data is shared with Simula's ad servers for ad delivery.

### Who is Data Shared With?

- **Simula Ad Servers**: Data is sent to Simula's servers for ad delivery and targeting
- **Third-Party Advertisers**: No, data is not shared with third-party advertisers
- **Data Brokers**: No, data is not sold or shared with data brokers

### Purpose of Sharing

- Ad delivery and serving
- Ad targeting and personalization
- Ad performance measurement
- Frequency capping

## Data Security

### Encryption

- **Data in Transit**: All data transmitted to Simula servers uses HTTPS/TLS encryption
- **Data at Rest**: Data stored on Simula servers is encrypted

### Data Handling

- Data is stored securely on Simula's servers
- Access is restricted to authorized personnel only
- Regular security audits and compliance checks

## Data Deletion

### User Data Deletion

Users can request data deletion by:
1. Contacting the publisher app support
2. Contacting Simula support at privacy@simula.ad
3. Data will be deleted within 30 days of request

### Automatic Deletion

- **Session Data**: Deleted after session ends (temporary)
- **User Data**: Retained for up to 90 days, then automatically deleted
- **Analytics Data**: Aggregated and anonymized data may be retained longer

## Privacy Controls

### User Controls

Publishers can implement privacy controls:

1. **Privacy Consent**: Control PII collection via `hasPrivacyConsent`
   ```dart
   SimulaProvider(
     apiKey: 'your-api-key',
     hasPrivacyConsent: userHasConsented, // User's consent choice
   )
   ```

2. **Opt-Out**: Users can opt out by setting consent to `false`
   ```dart
   notifier.setPrivacyConsent(false); // Withdraw consent
   ```

### SDK Privacy Features

- Respects user privacy consent
- Only collects PII when consent is granted
- No device fingerprinting
- Contextual targeting available without PII

## Google Play Data Safety Form

### Required Answers

#### Data Collection

**Does your app collect or share any of the required user data types?**
- **Answer**: Yes

**Which data types does your app collect?**
- ✅ Device or other IDs
- ✅ Approximate location
- ✅ Personal identifiers (User ID, Email) - Optional, only with consent

**Is this data collection optional or required?**
- **Device ID (Session)**: Required (for app functionality)
- **Location**: Required (for ad delivery)
- **User ID/Email**: Optional (only if user consents)

**Why is this data collected?**
- App functionality (session ID)
- Advertising or marketing (location, user ID, email)

#### Data Sharing

**Does your app share user data with third parties?**
- **Answer**: Yes (with Simula ad servers)

**Who is user data shared with?**
- Simula Ad Servers (for ad delivery)

**Why is user data shared?**
- Advertising or marketing
- Analytics

**Is data shared for advertising purposes?**
- **Answer**: Yes

#### Data Security

**How do you protect user data?**
- Encryption in transit (HTTPS/TLS)
- Encryption at rest
- Secure server infrastructure
- Access controls

#### Data Deletion

**Can users request that you delete their data?**
- **Answer**: Yes
- Users can contact publisher or Simula support
- Data deleted within 30 days

## Families Policy Compliance

### If Your App Targets Children

If your app is designed for children (under 13/16 depending on region):

1. **Do NOT collect PII**: Set `hasPrivacyConsent` to `false`
   ```dart
   SimulaProvider(
     apiKey: 'your-api-key',
     hasPrivacyConsent: false, // Required for children
   )
   ```

2. **Disclose in Data Safety**: Clearly state that no PII is collected for children

3. **COPPA Compliance**: Ensure compliance with COPPA (US) and similar regulations

## Regional Compliance

### GDPR (European Union)

- ✅ Privacy consent required for PII collection
- ✅ User rights (access, deletion, portability)
- ✅ Data processing agreements available

### CCPA (California)

- ✅ Privacy consent controls
- ✅ Opt-out mechanisms
- ✅ Data deletion rights

### Other Regions

- Follows best practices for privacy compliance
- Respects local privacy regulations

## Implementation Checklist

For publishers completing Google Play Data Safety form:

- [ ] Review data collection practices
- [ ] Determine if PII collection is enabled
- [ ] Complete Data Safety form with accurate information
- [ ] Update privacy policy to reflect SDK data practices
- [ ] Implement privacy consent controls
- [ ] Test opt-out functionality
- [ ] Document data retention policies

## Example Data Safety Disclosures

### Minimal Collection (No PII)
```
Data Collected:
- Device ID (session): Required for app functionality
- Approximate location: Required for ad delivery

Data Shared:
- With Simula ad servers for ad delivery

No personal identifiers collected.
```

### With PII Collection
```
Data Collected:
- Device ID (session): Required for app functionality
- Approximate location: Required for ad delivery
- User ID: Optional, for ad targeting (with consent)
- Email: Optional, for ad targeting (with consent)

Data Shared:
- With Simula ad servers for ad delivery and targeting

Users can opt out of personal identifier collection.
```

## Support

For questions about data safety or privacy:
- Email: privacy@simula.ad
- Documentation: https://docs.simula.ad/privacy
- Support: support@simula.ad

---

**Last Updated**: January 2026
**SDK Version**: 1.0.0
