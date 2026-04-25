# Supabase / Ktor
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.smartfinance.**$$serializer { *; }
-keepclassmembers class com.smartfinance.** {
    *** Companion;
}
-keepclasseswithmembers class com.smartfinance.** {
    kotlinx.serialization.KSerializer serializer(...);
}
