package app.rosid.rosid

import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var translator: OfflineBergamotTranslator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tts = TextToSpeech(this) { status ->
            ttsReady = (status == TextToSpeech.SUCCESS)
        }
        translator = OfflineBergamotTranslator(this)

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
    }

    override fun onDestroy() {
        translator?.release()
        translator = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
