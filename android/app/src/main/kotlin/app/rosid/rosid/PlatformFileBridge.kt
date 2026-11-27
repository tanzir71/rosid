package app.rosid.rosid

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Zero-permission Android Storage Access Framework (ACTION_CREATE_DOCUMENT)
 * and Android PrintManager bridge for M6 Export.
 */
class PlatformFileBridge(private val activity: Activity) {
    companion object {
        const val REQ_CREATE_DOCUMENT = 9412
        const val REQ_OPEN_DOCUMENT = 9413
    }

    private var pendingSourcePath: String? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPickResult: MethodChannel.Result? = null

    fun saveFile(
        sourcePath: String,
        suggestedName: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        val src = File(sourcePath)
        if (!src.exists()) {
            result.error("MISSING_FILE", "Export source file not found", null)
            return
        }
        pendingSourcePath = sourcePath
        pendingResult = result

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, suggestedName)
        }
        try {
            activity.startActivityForResult(intent, REQ_CREATE_DOCUMENT)
        } catch (e: Exception) {
            pendingSourcePath = null
            pendingResult = null
            result.error("SAF_UNAVAILABLE", e.message, null)
        }
    }

    fun pickFile(result: MethodChannel.Result) {
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        try {
            activity.startActivityForResult(intent, REQ_OPEN_DOCUMENT)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("SAF_UNAVAILABLE", e.message, null)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQ_OPEN_DOCUMENT) {
            val cb = pendingPickResult
            pendingPickResult = null
            if (cb == null) return true
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                cb.success(null)
                return true
            }
            val uri: Uri = data.data!!
            try {
                val displayName = queryDisplayName(uri) ?: "backup.rosidbackup"
                val safeName = displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val target = File(activity.cacheDir, "rosid_pick_${System.currentTimeMillis()}_$safeName")
                activity.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(target).use { out ->
                        input.copyTo(out)
                    }
                } ?: throw IllegalStateException("Could not open selected file")
                cb.success(target.absolutePath)
            } catch (e: Exception) {
                cb.error("PICK_FAILED", e.message, null)
            }
            return true
        }
        if (requestCode != REQ_CREATE_DOCUMENT) return false
        val cb = pendingResult
        val srcPath = pendingSourcePath
        pendingResult = null
        pendingSourcePath = null
        if (cb == null) return true

        if (resultCode != Activity.RESULT_OK || data?.data == null || srcPath == null) {
            cb.success(mapOf("saved" to false))
            return true
        }

        val targetUri: Uri = data.data!!
        try {
            activity.contentResolver.openOutputStream(targetUri, "w")?.use { out ->
                FileInputStream(File(srcPath)).use { input ->
                    input.copyTo(out)
                }
            } ?: throw IllegalStateException("Could not open destination stream")
            val displayName = queryDisplayName(targetUri) ?: File(srcPath).name
            cb.success(
                mapOf(
                    "saved" to true,
                    "uri" to targetUri.toString(),
                    "displayName" to displayName,
                ),
            )
        } catch (e: Exception) {
            cb.error("SAVE_FAILED", e.message, null)
        }
        return true
    }

    fun printPdf(filePath: String, jobName: String, result: MethodChannel.Result) {
        val file = File(filePath)
        if (!file.exists()) {
            result.success(false)
            return
        }
        val printManager = activity.getSystemService(Context.PRINT_SERVICE) as? PrintManager
        if (printManager == null) {
            result.success(false)
            return
        }
        val adapter = object : PrintDocumentAdapter() {
            override fun onLayout(
                oldAttributes: PrintAttributes?,
                newAttributes: PrintAttributes,
                cancellationSignal: CancellationSignal?,
                callback: LayoutResultCallback,
                extras: Bundle?,
            ) {
                if (cancellationSignal?.isCanceled == true) {
                    callback.onLayoutCancelled()
                    return
                }
                val info = PrintDocumentInfo.Builder(jobName)
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .setPageCount(PrintDocumentInfo.PAGE_COUNT_UNKNOWN)
                    .build()
                callback.onLayoutFinished(info, true)
            }

            override fun onWrite(
                pages: Array<out PageRange>?,
                destination: ParcelFileDescriptor,
                cancellationSignal: CancellationSignal?,
                callback: WriteResultCallback,
            ) {
                try {
                    FileInputStream(file).use { input ->
                        FileOutputStream(destination.fileDescriptor).use { out ->
                            input.copyTo(out)
                        }
                    }
                    callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                } catch (e: Exception) {
                    callback.onWriteFailed(e.message)
                }
            }
        }
        printManager.print(jobName, adapter, PrintAttributes.Builder().build())
        result.success(true)
    }

    fun openFolder(uriString: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                if (uriString.isNotBlank()) {
                    setDataAndType(Uri.parse(uriString), "*/*")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    setDataAndType(
                        Uri.parse("content://com.android.externalstorage.documents/root/primary"),
                        "vnd.android.document/root",
                    )
                }
            }
            if (intent.resolveActivity(activity.packageManager) != null) {
                activity.startActivity(intent)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (_: Exception) {
            result.success(false)
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return cursor.getString(0)
                }
            }
        return null
    }
}
