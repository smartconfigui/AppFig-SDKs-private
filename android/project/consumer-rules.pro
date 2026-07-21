# AppFig Android SDK - consumer ProGuard/R8 rules
#
# These rules are packaged into the published .aar (via consumerProguardFiles in
# build.gradle) and are automatically applied to any app that depends on this SDK
# and enables code shrinking/obfuscation (minifyEnabled true).
#
# Without them, R8 has no way of knowing that the SDK's Gson model classes (used
# for config-fetch, event caching, and schema caching via reflection) must keep
# their field names and constructors intact. R8's default optimizations (renaming,
# inlining, class merging) can turn a perfectly normal Kotlin data class into
# something Gson's reflective TypeAdapterFactory can no longer instantiate, which
# surfaces at runtime as:
#   "Abstract classes can't be instantiated! Register an InstanceCreator or a
#    TypeAdapter for this type. Class name: <obfuscated>"
#
# Keep every class in the SDK's package intact (names, fields, constructors) so
# Gson reflection continues to work after R8 processes the consuming app.
-keep class com.appfig.sdk.** { *; }
-keepclassmembers class com.appfig.sdk.** { *; }

# Standard Gson rules (defensive - Gson ships its own consumer rules, but some
# older resolutions / shrinker configs don't always pick those up transitively).
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
