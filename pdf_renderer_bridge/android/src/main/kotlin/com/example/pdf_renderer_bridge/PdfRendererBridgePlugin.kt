package com.example.pdf_renderer_bridge

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.atomic.AtomicInteger

/** PdfRendererBridgePlugin */
class PdfRendererBridgePlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private val nextDocumentId = AtomicInteger(1)
    private val documents = mutableMapOf<Int, OpenDocument>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        binding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "pdf_renderer_bridge")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        try {
            when (call.method) {
                "openDocument" -> openDocument(call, result)
                "getPageInfo" -> getPageInfo(call, result)
                "renderPage" -> renderPage(call, result)
                "closeDocument" -> closeDocument(call, result)
                else -> result.notImplemented()
            }
        } catch (exception: Throwable) {
            result.error(
                "pdf_renderer_error",
                exception.message,
                null,
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        documents.values.toList().forEach(::closeDocument)
        documents.clear()
        channel.setMethodCallHandler(null)
    }

    private fun openDocument(call: MethodCall, result: Result) {
        val arguments = call.arguments as? Map<*, *>
            ?: throw IllegalArgumentException("openDocument requires a map of arguments.")
        val sourceType = arguments["sourceType"] as? String
            ?: throw IllegalArgumentException("sourceType is required.")

        val file = when (sourceType) {
            "file" -> {
                val path = arguments["path"] as? String
                    ?: throw IllegalArgumentException("path is required for file source.")
                File(path)
            }
            "bytes" -> {
                val bytes = arguments["bytes"] as? ByteArray
                    ?: throw IllegalArgumentException("bytes are required for bytes source.")
                createTempPdf(bytes)
            }
            else -> throw IllegalArgumentException("Unsupported sourceType: $sourceType")
        }

        if (!file.exists()) {
            throw IOException("PDF file does not exist: ${file.absolutePath}")
        }

        val parcelFileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(parcelFileDescriptor)
        val documentId = nextDocumentId.getAndIncrement()
        val tempFile = if (sourceType == "bytes") file else null
        documents[documentId] = OpenDocument(
            renderer = renderer,
            descriptor = parcelFileDescriptor,
            tempFile = tempFile,
        )

        result.success(
            mapOf(
                "documentId" to documentId,
                "pageCount" to renderer.pageCount,
            ),
        )
    }

    private fun getPageInfo(call: MethodCall, result: Result) {
        val arguments = call.arguments as? Map<*, *>
            ?: throw IllegalArgumentException("getPageInfo requires a map of arguments.")
        val documentId = (arguments["documentId"] as? Number)?.toInt()
            ?: throw IllegalArgumentException("documentId is required.")
        val pageIndex = (arguments["pageIndex"] as? Number)?.toInt()
            ?: throw IllegalArgumentException("pageIndex is required.")

        val document = requireDocument(documentId)
        document.renderer.openPage(pageIndex).use { page ->
            result.success(
                mapOf(
                    "documentId" to documentId,
                    "pageIndex" to pageIndex,
                    "width" to page.width.toDouble(),
                    "height" to page.height.toDouble(),
                ),
            )
        }
    }

    private fun renderPage(call: MethodCall, result: Result) {
        val arguments = call.arguments as? Map<*, *>
            ?: throw IllegalArgumentException("renderPage requires a map of arguments.")
        val documentId = (arguments["documentId"] as? Number)?.toInt()
            ?: throw IllegalArgumentException("documentId is required.")
        val pageIndex = (arguments["pageIndex"] as? Number)?.toInt()
            ?: throw IllegalArgumentException("pageIndex is required.")
        val scale = (arguments["scale"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("scale is required.")
        val backgroundColor = (arguments["backgroundColor"] as? Number)?.toInt()
            ?: Color.WHITE

        require(scale > 0f) { "scale must be greater than zero." }

        val document = requireDocument(documentId)
        document.renderer.openPage(pageIndex).use { page ->
            val width = (page.width * scale).toInt().coerceAtLeast(1)
            val height = (page.height * scale).toInt().coerceAtLeast(1)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.drawColor(backgroundColor)
            val matrix = android.graphics.Matrix().apply {
                postScale(scale, scale)
            }
            page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            bitmap.recycle()

            result.success(
                mapOf(
                    "documentId" to documentId,
                    "pageIndex" to pageIndex,
                    "width" to width,
                    "height" to height,
                    "pngBytes" to stream.toByteArray(),
                ),
            )
        }
    }

    private fun closeDocument(call: MethodCall, result: Result) {
        val arguments = call.arguments as? Map<*, *>
            ?: throw IllegalArgumentException("closeDocument requires a map of arguments.")
        val documentId = (arguments["documentId"] as? Number)?.toInt()
            ?: throw IllegalArgumentException("documentId is required.")
        documents.remove(documentId)?.let(::closeDocument)
        result.success(null)
    }

    private fun requireDocument(documentId: Int): OpenDocument {
        return documents[documentId]
            ?: throw IllegalStateException("Unknown documentId: $documentId")
    }

    private fun createTempPdf(bytes: ByteArray): File {
        val file = File.createTempFile("pdf_renderer_bridge_", ".pdf", binding.applicationContext.cacheDir)
        FileOutputStream(file).use { output ->
            output.write(bytes)
            output.flush()
        }
        return file
    }

    private fun closeDocument(document: OpenDocument) {
        document.renderer.close()
        document.descriptor.close()
        document.tempFile?.delete()
    }
}

private data class OpenDocument(
    val renderer: PdfRenderer,
    val descriptor: ParcelFileDescriptor,
    val tempFile: File?,
)

private inline fun <T : AutoCloseable?, R> T.use(block: (T) -> R): R {
    try {
        return block(this)
    } finally {
        this?.close()
    }
}
