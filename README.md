# Kashout

A loot box rewards app for iOS. Users open loot boxes to earn points and redeem them for real gift cards.

## Features

- **Loot Boxes** - Open boxes to earn random points (50% common, 2% legendary)
- **Daily Bonus** - Claim bonus points every 24 hours
- **Rewarded Ads** - Watch ads for extra points
- **Gift Card Redemption** - Redeem points for Amazon, Apple, Visa, and more
- **Pro Subscription** - $4.99/mo for 2x daily bonus and faster cooldowns
- **State Restrictions** - Blocks users in states with loot box regulations

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- CocoaPods or Swift Package Manager

## Project Setup

### 1. Create Xcode Project

1. Open Xcode and create a new iOS App project
2. Set Product Name to "Kashout"
3. Select SwiftUI for Interface
4. Copy the `Kashout/` folder contents into your project

### 2. Add Dependencies

#### Using Swift Package Manager (Recommended)

Add these packages in Xcode (File > Add Package Dependencies):

```
https://github.com/firebase/firebase-ios-sdk
https://github.com/googleads/swift-package-manager-google-mobile-ads
```

Select these Firebase libraries:
- FirebaseAuth
- FirebaseFirestore

#### Using CocoaPods

Create a `Podfile`:

```ruby
platform :ios, '16.0'
use_frameworks!

target 'Kashout' do
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Google-Mobile-Ads-SDK'
end
```

Run `pod install` and open the `.xcworkspace` file.

### 3. Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named "Kashout"
3. Add an iOS app with your bundle ID
4. Download `GoogleService-Info.plist` and add it to your Xcode project
5. Enable **Email/Password Authentication** in Firebase Console > Authentication > Sign-in method
6. Create **Firestore Database** in Firebase Console > Firestore Database
   - Start in production mode
   - Choose a region close to your users

#### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Redemptions - users can create and read their own
    match /redemptions/{docId} {
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // Loot box history - users can create and read their own
    match /lootBoxHistory/{docId} {
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

### 4. AdMob Setup

1. Go to [AdMob Console](https://admob.google.com)
2. Create a new app for iOS
3. Create a **Rewarded** ad unit
4. Copy your ad unit ID
5. Update `Constants.swift`:

```swift
static let productionRewardedAdUnitID = "ca-app-pub-XXXX/YYYY"
```

6. Add your AdMob App ID to `Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXX~YYYY</string>
```

### 5. App Store Connect Setup (Subscriptions)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create a new app
3. Go to Subscriptions and create a subscription group
4. Add products:
   - `com.kashout.pro.monthly` - Monthly at $4.99
   - `com.kashout.pro.yearly` - Yearly at $39.99 (optional)
5. Fill in subscription metadata and localization

### 6. Update Configuration

Edit `Kashout/Config/Constants.swift`:

```swift
// Update these values:
static let productionRewardedAdUnitID = "your-admob-unit-id"
static let proMonthlyProductID = "your.bundle.id.pro.monthly"
static let proYearlyProductID = "your.bundle.id.pro.yearly"
static let supportEmail = "your-support@email.com"
static let privacyPolicyURL = "https://yoursite.com/privacy"
static let termsOfServiceURL = "https://yoursite.com/terms"
```

## Project Structure

```
Kashout/
├── KashoutApp.swift          # App entry point
├── Config/
│   └── Constants.swift       # App configuration
├── Models/
│   ├── User.swift            # User and redemption models
│   └── LootBox.swift         # Loot box logic and odds
├── ViewModels/
│   ├── AuthViewModel.swift   # Authentication logic
│   └── LootBoxViewModel.swift # Points and redemption logic
├── Views/
│   ├── OnboardingView.swift  # Sign up/sign in
│   ├── HomeView.swift        # Main screen
│   ├── LootBoxRevealView.swift # Box opening animation
│   ├── RewardsView.swift     # Gift card redemption
│   ├── SubscriptionView.swift # Pro upgrade
│   └── SettingsView.swift    # Account settings
└── Services/
    ├── AdManager.swift       # AdMob integration
    └── StoreManager.swift    # StoreKit 2 subscriptions
```

## Loot Box Odds

| Rarity    | Points Range | Probability |
|-----------|--------------|-------------|
| Common    | 1-50         | 50%         |
| Uncommon  | 51-150       | 30%         |
| Rare      | 151-500      | 15%         |
| Epic      | 501-1000     | 3%          |
| Legendary | 1001-5000    | 2%          |

## Redemption Tiers

| Points  | Gift Card Value |
|---------|-----------------|
| 10,000  | $5              |
| 20,000  | $10             |
| 50,000  | $25             |

## Restricted States

The app blocks users in these states due to loot box regulations:
- Arkansas (AR)
- Louisiana (LA)
- Montana (MT)
- South Carolina (SC)
- South Dakota (SD)
- Tennessee (TN)

## Testing

### Test Ads
The app automatically uses test ad unit IDs in DEBUG builds.

### Test Subscriptions
Use a Sandbox Apple ID to test subscriptions without real charges.

### Simulator Notes
- AdMob ads may not load in simulator
- StoreKit testing requires StoreKit Configuration file or device

## App Store Submission

Before submitting:

1. **Odds Disclosure** - Required by App Store for apps with randomized rewards
2. **Privacy Policy** - Required URL in App Store Connect
3. **Terms of Service** - Recommended for paid features
4. **Age Rating** - May need 17+ due to simulated gambling
5. **In-App Purchases** - Submit subscription products for review

## Support

For questions or issues, contact: support@kashout.app

## License

Proprietary - All rights reserved
