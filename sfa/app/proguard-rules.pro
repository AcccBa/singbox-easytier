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
# 背景：aar 以 implementation(files("libs/libbox.aar")) 引入（app/build.gradle.kts:191-193）。
# 诚实校正（2026-10-19 实测）：加这两条规则之后，产物 sha256 与加之前**完全一致**
#       （342e0465de466952316de0cfe6fae023b228496b29b50b1a5ca3d46a9dabb1b0，两次不同 runner 同源码），
#       ⇒ 绑定类此前就被 R8 保留，aar 的 consumer 规则确实生效了。
#       早先那句"扁平依赖不合并 consumer 规则、绑定层被改名、侥幸能跑"是错的，错因是把"0 命中"当证据而
#       符号名两次都查错（先用了老包名 unified/infra，又漏了 go.Seq$Proxy 里的 $）。
# 结论：以下两条当前是**纯保险**——若哪天 AGP 不再合并 aar 的 consumer 规则，它们会接管；对产物无副作用。
# 包名依据：sing-box/experimental/libbox/*.go 全为 `package libbox`（74 文件），gomobile 未用 -javapackage
#       ⇒ Java 包名即 Go 包名。需保的是绑定层 libbox.** 与运行时 go.**。
-keep class go.** { *; }
-keep class libbox.** { *; }
