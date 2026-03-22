# ProGuard / R8 rules for Fikr release builds

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Gson / JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# gRPC (used by Firestore)
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# In-App Purchase
-keep class com.android.vending.billing.** { *; }
