package app.rosid.rosid

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import java.io.BufferedInputStream
import java.io.ByteArrayInputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.GZIPInputStream

/**
 * Integration A: Hidden Android WebView running Mozilla's Bergamot WebAssembly
 * translator (`bn -> en`) strictly from local Flutter assets.
 *
 * Every network request is intercepted by [shouldInterceptRequest]: only
 * requests under `https://rosid.local/translation/` are served from app assets
 * (with on-the-fly gunzip of bundled `.gz` model blobs). Every other URL
 * receives HTTP 403. Requires zero Android network permissions (`INTERNET` is
 * absent from manifest).
 */
class OfflineBergamotTranslator(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var pageReady = false
    private val pendingBeforePageLoad = mutableListOf<Runnable>()
    private val pendingCallbacks = ConcurrentHashMap<String, MethodChannel.Result>()
    private val nextId = AtomicInteger(1)

    fun warmUp(result: MethodChannel.Result) {
        mainHandler.post {
            val reqId = "req_${nextId.getAndIncrement()}"
            pendingCallbacks[reqId] = result
            ensureWebViewLoaded {
                webView?.evaluateJavascript("window.rosidWarmUp('$reqId');", null)
            }
        }
    }

    fun translateBatch(lines: List<String>, result: MethodChannel.Result) {
        if (lines.isEmpty()) {
            result.success(emptyList<String>())
            return
        }
        mainHandler.post {
            val reqId = "req_${nextId.getAndIncrement()}"
            pendingCallbacks[reqId] = result
            val jsonArg = JSONArray(lines).toString()
            val escaped = jsonArg
                .replace("\\", "\\\\")
                .replace("'", "\\'")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\u2028", "\\u2028")
                .replace("\u2029", "\\u2029")
            ensureWebViewLoaded {
                webView?.evaluateJavascript(
                    "window.rosidTranslateBatch('$reqId', '$escaped');",
                    null,
                )
            }
        }
    }

    fun release() {
        mainHandler.post {
            pageReady = false
            pendingBeforePageLoad.clear()
            for ((_, cb) in pendingCallbacks) {
                cb.error("RELEASED", "Translation engine released", null)
            }
            pendingCallbacks.clear()
            webView?.apply {
                stopLoading()
                removeJavascriptInterface("RosidBridge")
                destroy()
            }
            webView = null
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun ensureWebViewLoaded(onReady: () -> Unit) {
        if (webView != null && pageReady) {
            onReady()
            return
        }
        pendingBeforePageLoad.add(Runnable(onReady))
        if (webView != null) {
            return
        }

        val wv = WebView(context.applicationContext)
        wv.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = false
            databaseEnabled = false
            allowFileAccess = false
            allowContentAccess = false
            blockNetworkLoads = false // Required so shouldInterceptRequest runs for rosid.local
        }
        wv.addJavascriptInterface(JsBridge(), "RosidBridge")
        wv.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?,
            ): WebResourceResponse? {
                val uri: Uri = request?.url ?: return forbiddenResponse()
                if (uri.scheme != "https" || uri.host != "rosid.local") {
                    return forbiddenResponse()
                }
                val path = uri.path ?: return forbiddenResponse()
                if (!path.startsWith("/translation/")) {
                    return forbiddenResponse()
                }
                val fileName = path.removePrefix("/translation/")
                if (fileName.contains("..") || fileName.contains("/")) {
                    return forbiddenResponse()
                }
                return serveAsset(fileName)
            }
        }
        webView = wv
        wv.loadUrl("https://rosid.local/translation/index.html")
    }

    private fun serveAsset(fileName: String): WebResourceResponse {
        val assetBase = "flutter_assets/assets/models/translation/"
        val headers = mapOf(
            "Access-Control-Allow-Origin" to "https://rosid.local",
            "Cache-Control" to "no-store",
        )
        return try {
            when (fileName) {
                "index.html" -> WebResourceResponse(
                    "text/html",
                    "utf-8",
                    200,
                    "OK",
                    headers,
                    context.assets.open("${assetBase}index.html"),
                )
                "bergamot-translator.js" -> WebResourceResponse(
                    "application/javascript",
                    "utf-8",
                    200,
                    "OK",
                    headers,
                    context.assets.open("${assetBase}bergamot-translator.js"),
                )
                "bergamot-translator.wasm" -> WebResourceResponse(
                    "application/wasm",
                    null,
                    200,
                    "OK",
                    headers,
                    BufferedInputStream(
                        GZIPInputStream(
                            context.assets.open("${assetBase}bergamot-translator.wasm.gz"),
                        ),
                        65536,
                    ),
                )
                "model.bnen.intgemm.alphas.bin",
                "lex.50.50.bnen.s2t.bin",
                "vocab.bnen.spm",
                -> WebResourceResponse(
                    "application/octet-stream",
                    null,
                    200,
                    "OK",
                    headers,
                    BufferedInputStream(
                        GZIPInputStream(
                            context.assets.open("${assetBase}${fileName}.gz"),
                        ),
                        65536,
                    ),
                )
                else -> forbiddenResponse()
            }
        } catch (e: Exception) {
            WebResourceResponse(
                "text/plain",
                "utf-8",
                404,
                "Not Found",
                headers,
                ByteArrayInputStream("Asset not found: $fileName".toByteArray()),
            )
        }
    }

    private fun forbiddenResponse(): WebResourceResponse =
        WebResourceResponse(
            "text/plain",
            "utf-8",
            403,
            "Offline Only",
            emptyMap(),
            ByteArrayInputStream("Offline only".toByteArray()),
        )

    private inner class JsBridge {
        @JavascriptInterface
        fun onEnginePageLoaded() {
            mainHandler.post {
                pageReady = true
                val queued = pendingBeforePageLoad.toList()
                pendingBeforePageLoad.clear()
                for (task in queued) {
                    task.run()
                }
            }
        }

        @JavascriptInterface
        fun onResult(reqId: String, jsonResult: String) {
            mainHandler.post {
                val cb = pendingCallbacks.remove(reqId) ?: return@post
                try {
                    val trimmed = jsonResult.trim()
                    if (trimmed.startsWith("[")) {
                        val arr = JSONArray(trimmed)
                        val out = ArrayList<String>(arr.length())
                        for (i in 0 until arr.length()) {
                            out.add(arr.optString(i, ""))
                        }
                        cb.success(out)
                    } else {
                        cb.success(true)
                    }
                } catch (e: Exception) {
                    cb.error("PARSE_ERROR", e.message, null)
                }
            }
        }

        @JavascriptInterface
        fun onError(reqId: String, message: String) {
            mainHandler.post {
                val cb = pendingCallbacks.remove(reqId) ?: return@post
                cb.error("BERGAMOT_ERROR", message, null)
            }
        }
    }
}
