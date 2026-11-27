package app.rosid.rosid

import android.content.Intent
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var translator: OfflineBergamotTranslator? = null
    private var fileBridge: PlatformFileBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tts = TextToSpeech(this) { status ->
            ttsReady = (status == TextToSpeech.SUCCESS)
        }
        translator = OfflineBergamotTranslator(this)
        fileBridge = PlatformFileBridge(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.rosid.rosid/tts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBanglaAvailable" -> {
                        val engine = tts
                        if (!ttsReady || engine == null) {
                            result.success(false)
                        } else {
                            val avail = engine.isLanguageAvailable(Locale("bn", "BD"))
                            result.success(
                                avail == TextToSpeech.LANG_AVAILABLE ||
                                    avail == TextToSpeech.LANG_COUNTRY_AVAILABLE ||
                                    avail == TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE
                            )
                        }
                    }
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val localeTag = call.argument<String>("locale") ?: "bn-BD"
                        val engine = tts
                        if (ttsReady && engine != null && text.isNotBlank()) {
                            engine.language = Locale.forLanguageTag(localeTag)
                            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "rosid-tts")
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.rosid.rosid/translate")
            .setMethodCallHandler { call, result ->
                val engine = translator
                if (engine == null) {
                    result.error("UNAVAILABLE", "Translator not initialized", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "warmUp" -> engine.warmUp(result)
                    "translateBatch" -> {
                        val lines = call.argument<List<String>>("lines") ?: emptyList()
                        engine.translateBatch(lines, result)
                    }
                    "release" -> {
                        engine.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.rosid.rosid/files")
            .setMethodCallHandler { call, result ->
                val bridge = fileBridge
                if (bridge == null) {
                    result.error("UNAVAILABLE", "File bridge not initialized", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "saveFile" -> {
                        val sourcePath = call.argument<String>("sourcePath") ?: ""
                        val suggestedName = call.argument<String>("suggestedName") ?: "export.pdf"
                        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                        bridge.saveFile(sourcePath, suggestedName, mimeType, result)
                    }
                    "printPdf" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val jobName = call.argument<String>("jobName") ?: "Rosid Document"
                        bridge.printPdf(filePath, jobName, result)
                    }
                    "openFolder" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        bridge.openFolder(uri, result)
                    }
                    "pickFile" -> {
                        bridge.pickFile(result)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.rosid.rosid/security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (fileBridge?.handleActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        translator?.release()
        translator = null
        fileBridge = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
