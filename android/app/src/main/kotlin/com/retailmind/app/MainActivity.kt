package com.retailmind.app

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Base64
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CREATIVE_STUDIO_CHANNEL =
            "com.retailmind.app/creative_studio"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CREATIVE_STUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    try {
                        startActivity(
                            Intent(this, CreativeStudioActivity::class.java)
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "CREATIVE_STUDIO_OPEN_FAILED",
                            error.message ?: "Could not open Creative Studio.",
                            null
                        )
                    }
                }
                "save_poster" -> {
                    try {
                        val encoded = call.argument<String>("base64")
                            ?: throw IllegalArgumentException("Poster image data is missing.")
                        val requestedName = call.argument<String>("fileName")
                            ?: "retail_mind_ad.png"
                        if (encoded.isBlank() || encoded.length > (MAX_POSTER_BYTES * 4 / 3 + 1024)) {
                            throw IllegalArgumentException("Poster image is empty or too large.")
                        }
                        val bytes = Base64.decode(encoded, Base64.DEFAULT)
                        if (bytes.isEmpty() || bytes.size > MAX_POSTER_BYTES) {
                            throw IllegalArgumentException("Poster must be smaller than 40 MB.")
                        }
                        val fileName = savePosterToDownloads(requestedName, bytes)
                        result.success(
                            mapOf(
                                "success" to true,
                                "fileName" to fileName,
                                "location" to "Downloads/Retail Mind"
                            )
                        )
                    } catch (error: Exception) {
                        result.error(
                            "POSTER_SAVE_FAILED",
                            error.message ?: "Could not save the poster.",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePosterToDownloads(requestedName: String, bytes: ByteArray): String {
        val safeBaseName = requestedName
            .substringBeforeLast('.', requestedName)
            .replace(Regex("[^A-Za-z0-9_-]"), "_")
            .trim('_')
            .take(72)
            .ifBlank { "retail_mind_ad" }
        val fileName = "$safeBaseName.png"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/Retail Mind"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values
            ) ?: throw IllegalStateException("Android could not create the download file.")

            try {
                val output = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("Android could not open the download file.")
                output.use { it.write(bytes) }
                val completed = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                contentResolver.update(uri, completed, null, null)
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            return fileName
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST
            )
            throw IllegalStateException("Allow storage access, then tap Save PNG to Downloads again.")
        }

        @Suppress("DEPRECATION")
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        val folder = File(downloads, "Retail Mind")
        if (!folder.exists() && !folder.mkdirs()) {
            throw IllegalStateException("Could not create the Downloads/Retail Mind folder.")
        }
        File(folder, fileName).writeBytes(bytes)
        return fileName
    }

    companion object {
        private const val MAX_POSTER_BYTES = 40 * 1024 * 1024
        private const val STORAGE_PERMISSION_REQUEST = 7403
    }
}
