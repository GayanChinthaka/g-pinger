# Flutter engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Dart VM service / observatory (not needed in release, suppress warnings)
-dontwarn com.google.**

# shared_preferences
-keep class androidx.preference.** { *; }

# Keep Kotlin metadata so reflection works correctly
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod
