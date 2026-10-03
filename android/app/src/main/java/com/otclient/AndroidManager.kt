package com.otclient

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.app.DownloadManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import androidx.core.view.isVisible
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

class AndroidManager(
    private val context: Context,
    private val editText: FakeEditText,
    private val previewContainer: View,
    private val previewText: TextView,
    private val pasteButton: ImageButton,
    private val copyButton: ImageButton,
    private val loadingOverlay: View,
) {
    private val handler = Handler(Looper.getMainLooper())
    private var isImeVisible = false
    private var shouldShowPreview = false
    private var pendingPreviewText: String = ""
    private var imeHeight: Int = 0
    private data class ApkUpdateRequest(val url: String, val sha256: String, val versionCode: Long)
    private var pendingApkUpdate: ApkUpdateRequest? = null
    private var waitingForInstallPermission = false
    private var apkDownloadId: Long? = null
    private var apkDownloadReceiver: BroadcastReceiver? = null

    // Widget position from C++ (in game pixels, maps 1:1 to screen pixels)
    private var widgetX: Int = -1
    private var widgetY: Int = -1
    private var widgetW: Int = -1
    private var widgetH: Int = -1

    init {
        pasteButton.setOnClickListener {
            val clipText = getClipboardText()
            if (clipText.isNotEmpty() && editText.visibility == View.VISIBLE) {
                try {
                    editText.ic.commitText(clipText, 1)
                } catch (_: Exception) { }
            }
        }

        copyButton.setOnClickListener {
            if (editText.visibility == View.VISIBLE) {
                try {
                    val text = pendingPreviewText
                    if (text.isNotEmpty()) {
                        setClipboardText(text)
                    }
                } catch (_: Exception) { }
            }
        }
    }

    /*
     * Methods called from JNI
     */

    fun showSoftKeyboard() {
        handler.post {
            editText.visibility = View.VISIBLE
            editText.requestFocus()
            val imm = editText.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(editText, 0)
        }
    }

    fun hideSoftKeyboard() {
        handler.post {
            editText.visibility = View.INVISIBLE
            val imm = editText.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(editText.windowToken, 0)
            hidePreviewInternal(clearText = false)
        }
    }

    fun showInputPreview(text: String, widgetX: Int, widgetY: Int, widgetW: Int, widgetH: Int) {
        handler.post {
            pendingPreviewText = text
            this.widgetX = widgetX
            this.widgetY = widgetY
            this.widgetW = widgetW
            this.widgetH = widgetH
            shouldShowPreview = true
            if (isImeVisible) showPreviewInternal()
        }
    }

    fun updateInputPreview(text: String) {
        handler.post {
            pendingPreviewText = text
            if (shouldShowPreview && isImeVisible) showPreviewInternal(animate = false)
        }
    }

    fun hideInputPreview() {
        handler.post {
            shouldShowPreview = false
            pendingPreviewText = ""
            widgetX = -1
            widgetY = -1
            widgetW = -1
            widgetH = -1
            hidePreviewInternal(clearText = true)
        }
    }

    fun onImeVisibilityChanged(visible: Boolean, imeHeight: Int) {
        handler.post {
            isImeVisible = visible
            this.imeHeight = imeHeight
            if (visible) {
                if (shouldShowPreview) showPreviewInternal()
            } else {
                hidePreviewInternal(clearText = false)
            }
        }
    }

    fun getDisplayDensity(): Float = context.resources.displayMetrics.density

    fun getClipboardText(): String {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip ?: return ""
        if (clip.itemCount == 0) return ""
        return clip.getItemAt(0).coerceToText(context).toString()
    }

    fun setClipboardText(text: String) {
        handler.post {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText("OTClient", text))
            // Refresh paste button visibility after clipboard change
            pasteButton.visibility = View.VISIBLE
        }
    }

    /**
     * Removes the branded first-run overlay only after the native client has
     * loaded its resources and executed init.lua. JNI may call this from the
     * game thread, so the visual change is always posted to Android's UI thread.
     */
    fun hideLoadingScreen() {
        handler.post {
            loadingOverlay.animate()
                .alpha(0f)
                .setDuration(250L)
                .withEndAction { loadingOverlay.visibility = View.GONE }
                .start()
        }
    }

    /** Returns the installed package version without depending on Lua build metadata. */
    fun getAppVersionCode(): Long {
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
        return PackageInfoCompat.getLongVersionCode(packageInfo)
    }

    /**
     * Starts an APK update requested by the Lua updater. Only HTTPS downloads,
     * strictly newer versions and SHA-256 protected packages are accepted.
     */
    fun requestApkUpdate(url: String, sha256: String, versionCode: Long) {
        handler.post {
            if (!url.startsWith("https://", ignoreCase = true) ||
                !sha256.matches(Regex("^[a-fA-F0-9]{64}$")) ||
                versionCode <= getAppVersionCode()) {
                showUpdaterMessage("Atualização de aplicativo inválida.")
                return@post
            }

            pendingApkUpdate = ApkUpdateRequest(url, sha256.lowercase(), versionCode)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !context.packageManager.canRequestPackageInstalls()) {
                waitingForInstallPermission = true
                val settingsIntent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(settingsIntent)
                return@post
            }
            startApkDownload()
        }
    }

    /** Continues an update after the user returns from Android's permission page. */
    fun resumePendingApkUpdate() {
        if (!waitingForInstallPermission || pendingApkUpdate == null) return
        waitingForInstallPermission = false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()) {
            startApkDownload()
        } else {
            pendingApkUpdate = null
            showUpdaterMessage("Permissão para instalar a atualização não concedida.")
        }
    }

    /** Releases the dynamically registered receiver when the activity closes. */
    fun shutdownApkUpdater() {
        unregisterApkReceiver()
    }

    external fun nativeInit()
    external fun nativeSetAudioEnabled(enabled: Boolean)

    private fun startApkDownload() {
        val requestData = pendingApkUpdate ?: return
        if (apkDownloadId != null) return

        val updateDirectory = File(
            context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
            "updates"
        )
        if (!updateDirectory.exists() && !updateDirectory.mkdirs()) {
            showUpdaterMessage("Não foi possível preparar a pasta da atualização.")
            pendingApkUpdate = null
            return
        }
        val apkFile = File(updateDirectory, "Crystal-update-${requestData.versionCode}.apk")
        if (apkFile.exists()) apkFile.delete()

        registerApkReceiver(apkFile)
        val downloadRequest = DownloadManager.Request(Uri.parse(requestData.url))
            .setTitle("Atualização do Crystal")
            .setDescription("Baixando a nova versão do aplicativo")
            .setMimeType(APK_MIME_TYPE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationUri(Uri.fromFile(apkFile))

        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        apkDownloadId = manager.enqueue(downloadRequest)
        showUpdaterMessage("Download da atualização iniciado.")
    }

    private fun registerApkReceiver(apkFile: File) {
        unregisterApkReceiver()
        apkDownloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(receiverContext: Context, intent: Intent) {
                val completedId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                if (completedId != apkDownloadId) return
                val requestData = pendingApkUpdate ?: return
                val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                val cursor = manager.query(DownloadManager.Query().setFilterById(completedId))
                val succeeded = cursor.use {
                    it.moveToFirst() &&
                        it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)) == DownloadManager.STATUS_SUCCESSFUL
                }
                apkDownloadId = null
                unregisterApkReceiver()

                if (!succeeded || !validateDownloadedApk(apkFile, requestData)) {
                    apkFile.delete()
                    pendingApkUpdate = null
                    showUpdaterMessage("Falha ao validar a atualização baixada.")
                    return
                }
                pendingApkUpdate = null
                openPackageInstaller(apkFile)
            }
        }
        ContextCompat.registerReceiver(
            context,
            apkDownloadReceiver,
            IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
            ContextCompat.RECEIVER_EXPORTED
        )
    }

    private fun unregisterApkReceiver() {
        val receiver = apkDownloadReceiver ?: return
        try {
            context.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was already detached by Android.
        }
        apkDownloadReceiver = null
    }

    private fun validateDownloadedApk(apkFile: File, requestData: ApkUpdateRequest): Boolean {
        if (!apkFile.isFile || calculateSha256(apkFile) != requestData.sha256) return false
        val packageInfo = context.packageManager.getPackageArchiveInfo(apkFile.absolutePath, 0) ?: return false
        return packageInfo.packageName == context.packageName &&
            PackageInfoCompat.getLongVersionCode(packageInfo) == requestData.versionCode &&
            requestData.versionCode > getAppVersionCode()
    }

    private fun calculateSha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count <= 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun openPackageInstaller(apkFile: File) {
        val apkUri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            apkFile
        )
        val installIntent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(apkUri, APK_MIME_TYPE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(installIntent)
    }

    private fun showUpdaterMessage(message: String) {
        handler.post { Toast.makeText(context, message, Toast.LENGTH_LONG).show() }
    }

    private fun showPreviewInternal(animate: Boolean = true) {
        previewContainer.animate().cancel()

        // Update text and visibility
        val hasText = pendingPreviewText.isNotEmpty()
        previewText.text = pendingPreviewText
        previewText.visibility = if (hasText) View.VISIBLE else View.GONE

        // Show/hide copy based on content
        copyButton.visibility = if (hasText) View.VISIBLE else View.GONE

        // Show/hide paste based on clipboard content
        val hasClip = getClipboardText().isNotEmpty()
        pasteButton.visibility = if (hasClip) View.VISIBLE else View.GONE

        if (!previewContainer.isVisible) {
            previewContainer.alpha = if (animate) 0f else 1f
            previewContainer.isVisible = true
        }

        // Position after making visible so measurement works
        previewContainer.post { positionNearWidget() }

        if (animate && previewContainer.alpha < 1f) {
            previewContainer.animate()
                .alpha(1f)
                .setDuration(120L)
                .start()
        }
    }

    private fun positionNearWidget() {
        previewContainer.measure(
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
        )
        val toolbarW = previewContainer.measuredWidth.coerceAtLeast(1)
        val toolbarH = previewContainer.measuredHeight.coerceAtLeast(1)

        val parent = previewContainer.parent as? View ?: return
        val screenW = parent.width
        val screenH = parent.height
        if (screenH <= 0) return

        val gap = (6 * context.resources.displayMetrics.density).toInt()
        val keyboardTop = screenH - imeHeight

        // TODO: Smart positioning — use widgetX/widgetY/widgetW/widgetH (already passed from C++)
        // to position the toolbar near the focused input field. Try all directions:
        // 1. Above the widget  2. Below the widget  3. Left  4. Right
        // Fall back to above-keyboard only if none fit without overlapping the input.
        // Currently: always above keyboard (simple, predictable, never overlaps).
        val targetY = (keyboardTop - toolbarH - gap).coerceIn(0, screenH - toolbarH)
        val targetX = ((screenW - toolbarW) / 2).coerceAtLeast(0)

        val params = previewContainer.layoutParams as? FrameLayout.LayoutParams ?: return
        params.topMargin = targetY
        params.marginStart = targetX
        previewContainer.layoutParams = params
    }

    private fun hidePreviewInternal(animate: Boolean = true, clearText: Boolean) {
        previewContainer.animate().cancel()
        if (!previewContainer.isVisible) {
            if (clearText) previewText.text = ""
            return
        }

        val cleanup = {
            previewContainer.isVisible = false
            previewContainer.alpha = 1f
            if (clearText) previewText.text = ""
            // Reset position so it doesn't stick in a corner
            val params = previewContainer.layoutParams as? FrameLayout.LayoutParams
            if (params != null) {
                params.topMargin = 0
                params.marginStart = 0
                previewContainer.layoutParams = params
            }
        }

        if (animate) {
            previewContainer.animate()
                .alpha(0f)
                .setDuration(120L)
                .withEndAction(cleanup)
                .start()
        } else {
            cleanup()
        }
    }

    private companion object {
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
