# Stripe SDK Proguard Rules
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.stripe.android.**
-keep class com.stripe.android.** { *; }

# Agora RTC Engine Rules
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# General Flutter & Kotlin Rules
-dontwarn io.flutter.**
