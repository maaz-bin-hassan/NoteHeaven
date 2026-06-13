# Flutter / engine ------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Plugins used by NoteHeaven (channel-based; kept defensively) -----------------
-keep class com.tekartik.sqflite.** { *; }
-keep class com.llfbandit.record.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.fluttercommunity.** { *; }

# General ----------------------------------------------------------------------
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn javax.annotation.**
