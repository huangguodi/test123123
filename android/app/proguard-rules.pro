# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Aggressive Obfuscation (激进混淆)
-repackageclasses 'o' # 将所有类重打包到 'o' 包下
-allowaccessmodification # 允许修改访问修饰符以优化
-dontskipnonpubliclibraryclasses # 处理非公开库类
-dontskipnonpubliclibraryclassmembers

# Optimization (优化)
-optimizationpasses 5
-dontusemixedcaseclassnames # 混淆后类名不使用大小写混合（Windows下更安全）
-verbose

# Keep Native Methods (保留 Native 方法，否则 JNI 调用会挂)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Custom Application & MainActivity
-keep class com.example.address.** { *; }

# Third Party Libraries Rules

# Dio
-keep class dio.** { *; }
-dontwarn dio.**

# Hive
-keep class hive.** { *; }
-dontwarn hive.**

# Retrofit / OkHttp (If used internally by Dio)
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-keepattributes Signature
-keepattributes Exceptions

# Flutter Plugins (通用规则，防止反射失效)
-keep public class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrant
-keep public class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler

# Coroutines (Kotlin)
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Enum (枚举)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Serialization
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Remove Log calls (R8/ProGuard 层面的移除日志，双重保险)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Google Play Core (Split Install / Deferred Components)
# Fix for "Missing class com.google.android.play.core.splitinstall" errors
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
