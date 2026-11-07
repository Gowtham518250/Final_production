package com.retailmind.app

import android.Manifest
import android.app.Dialog
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Message
import android.provider.MediaStore
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.webkit.ConsoleMessage
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.File
import java.util.Locale

class CreativeStudioActivity : ComponentActivity() {
    companion object {
        private const val TAG = "RetailMindCreative"
        private const val CREATIVE_STUDIO_URL =
            "https://retail-mind-hpx3.onrender.com/creative-studio?platform=android"
        private const val BACKEND_HOST = "retail-mind-hpx3.onrender.com"
        private const val STORAGE_PERMISSION_REQUEST = 7402
        private const val MAX_EXPORT_BYTES = 40 * 1024 * 1024
    }

    private lateinit var mainWebView: WebView
    private val popupWebViews = mutableListOf<WebView>()
    private var pendingFileChooser: ValueCallback<Array<Uri>>? = null

    private val imagePicker = registerForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        pendingFileChooser?.onReceiveValue(uri?.let { arrayOf(it) })
        pendingFileChooser = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = android.graphics.Color.rgb(17, 17, 40)
        window.navigationBarColor = android.graphics.Color.rgb(17, 17, 40)

        val root = FrameLayout(this)
        mainWebView = WebView(this)
        root.addView(
            mainWebView,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        setContentView(root)

        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    if (::mainWebView.isInitialized && mainWebView.canGoBack()) {
                        mainWebView.goBack()
                    } else {
                        finish()
                    }
                }
            }
        )

        configureMainWebView()
        mainWebView.addJavascriptInterface(SaveDesignBridge(this), "RetailMindBridge")
        mainWebView.loadUrl(CREATIVE_STUDIO_URL)
    }

    @Suppress("SetJavaScriptEnabled")
    private fun configureWebView(webView: WebView, primary: Boolean) {
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            cookieManager.setAcceptThirdPartyCookies(webView, true)
        }
        cookieManager.flush()

        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null)
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.textZoom = 100
        settings.javaScriptCanOpenWindowsAutomatically = true
        settings.setSupportMultipleWindows(true)
        settings.allowFileAccess = false
        settings.allowContentAccess = true
        settings.mediaPlaybackRequiresUserGesture = true

        // Adobe sign-in providers reject the default Android WebView marker.
        val originalUserAgent = settings.userAgentString ?: ""
        if (originalUserAgent.contains("; wv")) {
            settings.userAgentString = originalUserAgent
                .replace("; wv)", ")")
                .replace("; wv ", " ")
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(
                view: WebView?,
                url: String?,
                favicon: android.graphics.Bitmap?
            ) {
                Log.i(TAG, "Page loading: ${safeUrl(url)}")
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                Log.i(TAG, "Page loaded: ${safeUrl(url)}")
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                val url = request?.url
                val location = url?.let { "${it.scheme}://${it.host}${it.encodedPath}" } ?: "unknown URL"
                if (request?.isForMainFrame == true) {
                    Log.e(TAG, "Main-frame WebView error ${error?.errorCode}: ${error?.description}; url=$location")
                } else {
                    Log.w(TAG, "WebView resource error ${error?.errorCode}: ${error?.description}; url=$location")
                }
            }

            override fun onReceivedHttpError(
                view: WebView?,
                request: WebResourceRequest?,
                response: WebResourceResponse?
            ) {
                val url = request?.url
                val location = url?.let { "${it.scheme}://${it.host}${it.encodedPath}" } ?: "unknown URL"
                Log.w(TAG, "WebView HTTP ${response?.statusCode}: $location")
            }

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                val uri = request?.url ?: return true
                if (!primary) return false

                // Keep the trusted Retail Mind host in the primary WebView.
                // External sites are opened by the system browser; Adobe
                // authentication windows are handled separately below.
                if (uri.scheme == "https" && uri.host == BACKEND_HOST) return false
                return openExternal(uri)
            }

            @Suppress("DEPRECATION")
            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                val uri = runCatching { Uri.parse(url ?: "") }.getOrNull() ?: return true
                if (!primary) return false
                if (uri.scheme == "https" && uri.host == BACKEND_HOST) return false
                return openExternal(uri)
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                logConsoleMessage(consoleMessage)
                return true
            }

            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                if (!primary) return false
                return createAuthenticationPopup(resultMsg)
            }

            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                if (!primary) return false
                pendingFileChooser?.onReceiveValue(null)
                pendingFileChooser = filePathCallback
                return try {
                    imagePicker.launch("image/*")
                    true
                } catch (error: Exception) {
                    pendingFileChooser?.onReceiveValue(null)
                    pendingFileChooser = null
                    false
                }
            }
        }
    }

    private fun configureMainWebView() {
        configureWebView(mainWebView, primary = true)
    }

    private fun createAuthenticationPopup(resultMsg: Message?): Boolean {
        val popup = WebView(this)
        configureWebView(popup, primary = false)
        popupWebViews.add(popup)

        val dialog = Dialog(this)
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
        dialog.setContentView(popup)
        dialog.window?.setLayout(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        dialog.setOnDismissListener {
            popupWebViews.remove(popup)
            popup.stopLoading()
            popup.removeAllViews()
            popup.destroy()
        }

        popup.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                logConsoleMessage(consoleMessage)
                return true
            }

            override fun onCloseWindow(window: WebView?) {
                dialog.dismiss()
            }
        }

        val transport = resultMsg?.obj as? WebView.WebViewTransport
        if (transport == null) {
            popup.destroy()
            popupWebViews.remove(popup)
            return false
        }
        transport.webView = popup
        resultMsg?.sendToTarget()
        dialog.show()
        return true
    }

    private fun safeUrl(url: String?): String {
        if (url.isNullOrBlank()) return "unknown URL"
        val uri = Uri.parse(url)
        return "${uri.scheme}://${uri.host}${uri.encodedPath}"
    }

    private fun logConsoleMessage(consoleMessage: ConsoleMessage?) {
        if (consoleMessage == null) return
        val message =
            "${consoleMessage.message()} (${consoleMessage.sourceId()}:${consoleMessage.lineNumber()})"
        when (consoleMessage.messageLevel()) {
            ConsoleMessage.MessageLevel.ERROR -> Log.e(TAG, message)
            ConsoleMessage.MessageLevel.WARNING -> Log.w(TAG, message)
            else -> Log.d(TAG, message)
        }
    }

    private fun openExternal(uri: Uri): Boolean {
        return try {
            if (uri.scheme == "https" || uri.scheme == "mailto" || uri.scheme == "tel") {
                startActivity(Intent(Intent.ACTION_VIEW, uri))
            }
            true
        } catch (_: Exception) {
            true
        }
    }

    private inner class SaveDesignBridge(private val activity: CreativeStudioActivity) {
        @JavascriptInterface
        fun saveDesign(base64Data: String?, mimeType: String?, requestedName: String?): String {
            return try {
                val mime = (mimeType ?: "").lowercase(Locale.ROOT)
                val extension = when (mime) {
                    "image/png" -> "png"
                    "image/jpeg" -> "jpg"
                    "application/pdf" -> "pdf"
                    else -> throw IllegalArgumentException("Only PNG, JPEG and PDF exports are supported.")
                }

                val encoded = (base64Data ?: "").trim()
                if (encoded.isEmpty() || encoded.length > (MAX_EXPORT_BYTES * 4 / 3 + 1024)) {
                    throw IllegalArgumentException("The exported file is empty or too large.")
                }
                val bytes = Base64.decode(encoded, Base64.DEFAULT)
                if (bytes.isEmpty() || bytes.size > MAX_EXPORT_BYTES) {
                    throw IllegalArgumentException("The exported file must be smaller than 40 MB.")
                }

                val safeBaseName = (requestedName ?: "retail_mind_ad")
                    .substringBeforeLast('.', requestedName ?: "retail_mind_ad")
                    .replace(Regex("[^A-Za-z0-9_-]"), "_")
                    .trim('_')
                    .take(72)
                    .ifBlank { "retail_mind_ad" }
                val fileName = "$safeBaseName.$extension"
                val location = saveToDownloads(fileName, mime, bytes)

                JSONObject()
                    .put("success", true)
                    .put("fileName", fileName)
                    .put("location", location)
                    .toString()
            } catch (error: Exception) {
                JSONObject()
                    .put("success", false)
                    .put("message", error.message ?: "Could not save the exported file.")
                    .toString()
            }
        }
    }

    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
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
            return "Downloads/Retail Mind"
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            runOnUiThread {
                requestPermissions(
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                    STORAGE_PERMISSION_REQUEST
                )
            }
            throw IllegalStateException(
                "Allow storage access, then tap Save to phone again."
            )
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
        return "Downloads/Retail Mind"
    }

    override fun onDestroy() {
        if (::mainWebView.isInitialized) {
            mainWebView.stopLoading()
            mainWebView.removeJavascriptInterface("RetailMindBridge")
            mainWebView.removeAllViews()
            mainWebView.destroy()
        }
        popupWebViews.toList().forEach { popup ->
            runCatching {
                popup.stopLoading()
                popup.removeAllViews()
                popup.destroy()
            }
        }
        popupWebViews.clear()
        super.onDestroy()
    }
}
