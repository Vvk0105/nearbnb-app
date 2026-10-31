# Release builds shrink the code (R8). Stripe's Flutter plugin refers to an optional Stripe feature the app does not use
# (adding cards to Google Wallet, "push provisioning"), whose classes are not in the app. Tell R8 that is fine.
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
