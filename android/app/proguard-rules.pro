# ML Kit Text Recognition ProGuard Rules
# Keep all ML Kit text recognition classes to prevent R8 from removing them

# Keep Chinese text recognition
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**

# Keep Devanagari text recognition
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Keep Japanese text recognition
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-dontwarn com.google.mlkit.vision.text.japanese.**

# Keep Korean text recognition
-keep class com.google.mlkit.vision.text.korean.** { *; }
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep all ML Kit text recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.** { *; }

# Keep ML Kit commons
-keep class com.google.mlkit.common.** { *; }

# Camera package
-keep class androidx.camera.** { *; }

