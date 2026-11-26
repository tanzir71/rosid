# Tesseract is reached through the Flutter plugin and native bindings.
-keep class com.googlecode.tesseract.android.** { *; }
-dontwarn com.googlecode.tesseract.android.**

# ONNX Runtime is invoked via JNI by flutter_onnxruntime.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Keep WebView @JavascriptInterface callbacks for offline Bergamot WASM bridge.
-keepattributes JavascriptInterface
-keepclassmembers class app.rosid.rosid.OfflineBergamotTranslator$JsBridge {
    @android.webkit.JavascriptInterface <methods>;
}
