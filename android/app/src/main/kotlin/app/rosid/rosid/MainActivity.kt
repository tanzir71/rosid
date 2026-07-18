package app.rosid.rosid

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val latinRecognizerDelegate =
        lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }
    private val latinRecognizer by latinRecognizerDelegate

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL)
            .setMethodCallHandler(::handleOcrCall)
    }

    private fun handleOcrCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != RECOGNIZE_LATIN) {
            result.notImplemented()
            return
        }

        val imagePath = call.argument<String>("path")
        if (imagePath.isNullOrBlank()) {
            result.error("invalid_argument", "A non-empty image path is required.", null)
            return
        }

        val inputImage =
            try {
                InputImage.fromFilePath(this, Uri.fromFile(File(imagePath)))
            } catch (error: Exception) {
                result.error("invalid_image", "Unable to read the OCR image.", error.toString())
                return
            }

        latinRecognizer
            .process(inputImage)
            .addOnSuccessListener { recognized ->
                val lines =
                    recognized.textBlocks.flatMap { block ->
                        if (block.lines.isEmpty()) {
                            val bounds = block.boundingBox
                            listOf(
                                mapOf(
                                    "text" to block.text,
                                    "left" to (bounds?.left?.toDouble() ?: 0.0),
                                    "top" to (bounds?.top?.toDouble() ?: 0.0),
                                    "right" to (bounds?.right?.toDouble() ?: 0.0),
                                    "bottom" to (bounds?.bottom?.toDouble() ?: 0.0),
                                    "confidence" to null,
                                ),
                            )
                        } else {
                            block.lines.map { line ->
                                val bounds = line.boundingBox
                                mapOf(
                                    "text" to line.text,
                                    "left" to (bounds?.left?.toDouble() ?: 0.0),
                                    "top" to (bounds?.top?.toDouble() ?: 0.0),
                                    "right" to (bounds?.right?.toDouble() ?: 0.0),
                                    "bottom" to (bounds?.bottom?.toDouble() ?: 0.0),
                                    "confidence" to line.confidence?.toDouble(),
                                )
                            }
                        }
                    }
                result.success(lines)
            }.addOnFailureListener { error ->
                result.error("ocr_failed", "Android Latin OCR failed.", error.toString())
            }
    }

    override fun onDestroy() {
        if (latinRecognizerDelegate.isInitialized()) {
            latinRecognizer.close()
        }
        super.onDestroy()
    }

    companion object {
        private const val OCR_CHANNEL = "app.rosid.rosid/ocr"
        private const val RECOGNIZE_LATIN = "recognizeLatin"
    }
}
