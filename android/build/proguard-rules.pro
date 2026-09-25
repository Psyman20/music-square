# ==============================================================================
# Godot Engine ProGuard / R8 Rules
# ==============================================================================

# Keep the main application class and its entry points
-keep class com.godot.game.** { *; }

# Keep all Godot engine core classes, interfaces, and methods (called via JNI)
-keep class org.godotengine.godot.** { *; }
-dontwarn org.godotengine.godot.**

# Keep all Godot plugins and their exposed methods/signals
-keep class * extends org.godotengine.godot.plugin.GodotPlugin { *; }
-keepclassmembers class * extends org.godotengine.godot.plugin.GodotPlugin {
    public *;
}

# Keep any class with native methods (critical for C++/JNI bindings)
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep Godot JNI / reflection callbacks
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot *;
}

# ==============================================================================
# Google Mobile Ads / AdMob SDK
# ==============================================================================
-keep public class com.google.android.gms.ads.** {
    public *;
}
-keep public class com.google.ads.** {
    public *;
}
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**

# AdMob Mediation Adapters
-keep class com.google.ads.mediation.** { *; }
-keep class com.google.android.gms.ads.mediation.** { *; }

# ==============================================================================
# AndroidX & Kotlin
# ==============================================================================
-dontwarn androidx.**
-dontwarn kotlin.**
-dontwarn org.jetbrains.annotations.**

# Keep line numbers and source file names for readable stack traces in crash logs
-keepattributes SourceFile,LineNumberTable,Signature,InnerClasses,EnclosingMethod,Deprecated
