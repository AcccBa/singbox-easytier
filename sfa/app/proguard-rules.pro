# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

-keep class com.itsaky.androidide.treesitter.** { *; }

# These compile-time stubs must retain their framework names so the boot
# classloader resolves Android's real hidden Binder interfaces at runtime.
-keep class android.content.IIntentReceiver { *; }
-keep class android.content.IIntentSender { *; }
-keep class android.content.IIntentSender$Stub { *; }

-dontwarn io.github.libxposed.annotation.**
-keep class io.nekohasekai.sfa.xposed.XposedInit { public *; }
-keep class io.nekohasekai.sfa.xposed.XposedLegacyInit { public *; }

# --- 内嵌 EasyTier 的 JNI 绑定层（本仓新增 2026-10-19）---
# 背景：libbox.aar 以 implementation(files("libs/libbox.aar")) 引入（app/build.gradle.kts:191-193），
#       这种扁平文件依赖不会合并 aar 自带的 consumer proguard.txt
#       （gomobile 在 cmd/gomobile/bind_androidapp.go 里写的 -keep class go.** { *; } 等）。
# 实测证据：线上 APK 的 classes.dex 里 Lgo/SeqProxy 0 命中，而源码 sfa/app/src/main/java/io/nekohasekai/sfa/bg/BoxService.kt:21
#       明确 import go.Seq ⇒ 绑定层被 R8 改名。现状能跑是因为 gomobile 的 JNI 走 jobject/GetObjectClass
#       而非硬编码 FindClass，属"侥幸能跑"，这里显式钉住，避免 AGP 升级后突然炸。
# 包名依据：sing-box/experimental/libbox/*.go 全为 `package libbox`（74 文件），gomobile 未用 -javapackage
#       ⇒ Java 包名即 Go 包名。需保的是绑定层 libbox.** 与运行时 go.**。
-keep class go.** { *; }
-keep class libbox.** { *; }
