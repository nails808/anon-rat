# Production R8 / ProGuard — shrink, obfuscate, optimize
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.embedding.**

# Keep MethodChannel host entry points (names referenced from Dart)
-keep class com.anon.privacy.MainActivity { *; }
-keepclassmembers class com.anon.privacy.MainActivity {
    public <methods>;
}

# Plugin registrants
-keep class ** implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class ** implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# Play Core / optional
-dontwarn com.google.android.play.core.**

# Obfuscate everything else aggressively
-repackageclasses 'o'
-allowaccessmodification
-optimizationpasses 5
-overloadaggressively

# Strip log noise
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
