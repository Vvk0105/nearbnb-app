# Building the iPhone app without a Mac (Codemagic)

Codemagic builds the app on a cloud Mac and sends it to TestFlight. The repo is already prepared: `codemagic.yaml`,
bundle id `com.nearbnb.app`, the push-notification entitlement, and iPhone Firebase settings read from build variables.

> Not yet built: nobody has run an iPhone build of this app. Expect to fix a few things on the first runs.

## A. Apple (once)

1. **Apple Developer Program** (developer.apple.com/programs): US$99 a year. An organisation account needs a D-U-N-S number and takes longer than an individual one.
2. **Bundle ID**: developer.apple.com -> Certificates, IDs & Profiles -> Identifiers -> + -> App IDs -> App.
   Description `NearBnB`, explicit Bundle ID `com.nearbnb.app`, tick **Push Notifications**, Register.
3. **App in App Store Connect**: appstoreconnect.apple.com -> Apps -> + -> New App. Platform iOS, name `NearBnB`, primary language, bundle id `com.nearbnb.app`, any SKU (for example `nearbnb-ios`), full access.
4. **App Store Connect API key** (lets Codemagic sign and upload): App Store Connect -> Users and Access -> Integrations -> App Store Connect API -> Team Keys -> +.
   Name `Codemagic`, access **App Manager**. Download the `.p8` file (**only once**) and note the **Key ID** and the **Issuer ID** at the top of the page.
5. **APNs key** (lets Firebase send pushes to iPhones): developer.apple.com -> Certificates, IDs & Profiles -> Keys -> +.
   Name `NearBnB push`, tick **Apple Push Notifications service (APNs)**, Continue, Register, download the `.p8` file (**only once**) and note its **Key ID**.
6. Your **Team ID**: developer.apple.com -> Membership details.

Keep all `.p8` files and IDs private. Never put them in git or in chat.

## B. Firebase (once)

1. console.firebase.google.com -> project `nearbnb-dcf77` -> Project settings (gear) -> General -> Your apps -> **Add app -> iOS**.
2. Apple bundle ID `com.nearbnb.app`, nickname `NearBnB iOS`, Register app.
3. Download `GoogleService-Info.plist`. Do **not** add it to the repo. Open it in a text editor and copy four values: `API_KEY`, `GOOGLE_APP_ID`, `GCM_SENDER_ID`, `PROJECT_ID`.
4. Click Next through the remaining steps (SDK, initialisation) without changing anything, then Continue to console.
5. Project settings -> **Cloud Messaging** tab -> Apple app configuration -> **APNs authentication key** -> Upload.
   Choose the APNs `.p8` file from step A5, enter its Key ID and your Team ID.

## C. Codemagic (once)

1. codemagic.io -> sign up with GitHub -> **Add application** -> pick the `nearbnb-app` repo -> project type **Flutter App**, then choose to configure with **codemagic.yaml**.
2. **Teams -> Integrations -> App Store Connect -> Connect.** Name it exactly `codemagic`, enter the Issuer ID and Key ID, upload the `.p8` from step A4.
3. In the app's **Environment variables**, create a group named `firebase_ios` with four variables, each marked **Secure**:
   `IOS_FIREBASE_API_KEY`, `IOS_FIREBASE_APP_ID`, `IOS_FIREBASE_SENDER_ID`, `IOS_FIREBASE_PROJECT_ID` (the four values from step B3).
4. Code signing: Codemagic creates the distribution certificate and App Store profile itself through the API, but it needs a private key to make the certificate.
   Make one once in Git Bash: `ssh-keygen -t rsa -b 2048 -m PEM -f ~/codemagic_ios_distribution_key -q -N ""`.
   Open the file `codemagic_ios_distribution_key` (no extension, in your home folder) in Notepad, copy **everything** including the `-----BEGIN` and `-----END` lines, and add it as a **Secure** variable named
   `CERTIFICATE_PRIVATE_KEY` in the `firebase_ios` group. Keep the file safe: it is needed for every later build, and never put it in git.

## D. Build and test

1. Codemagic -> your app -> **Start new build** -> branch `main`, workflow **iOS to TestFlight** -> Start.
2. The first build takes about 15-25 minutes. When it succeeds the build is uploaded to TestFlight by itself.
3. App Store Connect -> your app -> **TestFlight**. Apple processes the build (10-30 minutes), then add **internal testers** (people with a role in your App Store Connect team) and give the build to them.
4. Testers install Apple's **TestFlight** app on their iPhone, accept the invite, and install NearBnB.
5. Each new build needs a higher build number. The workflow uses Codemagic's own counter (`$BUILD_NUMBER`), which always goes up.

## E. App Store release (later)

App Store Connect -> App Store tab: screenshots (6.9-inch and 6.5-inch iPhone sizes), description, privacy policy URL `https://nearbnb.com/legal/privacy`,
App Privacy answers (the same as the Google Play data safety answers), age rating, contact details, a **test account** for Apple's reviewers, then **Submit for review**.
Apple also requires in-app account deletion, which the app has (Profile -> Delete account).
