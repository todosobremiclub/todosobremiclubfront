# ============================================================
# Reglas de ProGuard/R8 para TSMC (todosobremiclub_app)
#
# Se activó isMinifyEnabled = true en build.gradle.kts para que
# Play Console deje de marcar "Ofuscación" por debajo del umbral.
# Estas reglas evitan que R8 rompa librerías que usan reflexión.
# ============================================================

# --- Flutter (motor y plugins) ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase (firebase_core / firebase_messaging) ---
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# --- flutter_local_notifications ---
-keep class com.dexterous.** { *; }

# --- mobile_scanner (usa Google ML Kit para leer QR) ---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# --- image_picker / path_provider / url_launcher: no requieren reglas
# adicionales, pero se deja documentado por si alguna nueva versión
# empieza a usar reflexión.

# --- Mantener atributos usados por librerías con anotaciones/reflexión ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
