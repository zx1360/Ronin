package ax.puzzled.torrid

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

object PublicMediaStore {
    fun save(context: Context, call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("storage_permission_required", "需要存储权限以导出媒体", null)
            return
        }
        Thread {
            val saved = runCatching { write(context, call) }
            Handler(Looper.getMainLooper()).post {
                saved.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("export_failed", it.localizedMessage, null) },
                )
            }
        }.start()
    }

    private fun write(context: Context, call: MethodCall): Map<String, String> {
        val source = File(requireNotNull(call.argument<String>("path"))).canonicalFile
        val roots = listOfNotNull(context.filesDir, context.cacheDir, context.getExternalFilesDir(null))
        require(source.isFile && source.length() > 0 && roots.any {
            source.path.startsWith(it.canonicalPath + File.separator)
        }) { "媒体源文件无效" }
        val name = requireNotNull(call.argument<String>("fileName"))
        require(name.isNotBlank() && name != "." && name != ".." &&
            name.none { it == '/' || it == '\\' || it == '\u0000' }) { "文件名无效" }
        val subDir = requireNotNull(call.argument<String>("subDir"))
        require(subDir in setOf("comic", "gallery", "api", "bing")) { "导出目录无效" }
        val mime = call.argument<String>("mimeType")?.takeIf { it.isNotBlank() }
            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(File(name).extension.lowercase())
        require(mime != null && (mime.startsWith("image/") || mime.startsWith("video/"))) {
            "不支持的媒体类型"
        }
        val topDirectory = if (mime.startsWith("video/")) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
        val relativeDirectory = "$topDirectory/torrid/$subDir"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return writeLegacy(context, source, name, subDir, topDirectory, mime)
        }
        val collection = if (mime.startsWith("video/")) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativeDirectory)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = checkNotNull(resolver.insert(collection, values)) { "无法创建系统媒体记录" }
        try {
            checkNotNull(resolver.openOutputStream(uri, "w")).use { output ->
                source.inputStream().use { it.copyTo(output) }
            }
            check(resolver.update(uri, ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }, null, null) == 1) { "发布媒体失败" }
            val displayName = resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else name
            } ?: name
            return mapOf("uri" to uri.toString(), "location" to "$relativeDirectory/$displayName")
        } catch (error: Exception) {
            runCatching { resolver.delete(uri, null, null) }
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun writeLegacy(
        context: Context,
        source: File,
        name: String,
        subDir: String,
        topDirectory: String,
        mime: String,
    ): Map<String, String> {
        val directory = File(Environment.getExternalStoragePublicDirectory(topDirectory), "torrid/$subDir")
        check(directory.isDirectory || directory.mkdirs()) { "无法创建导出目录" }
        var target = File(directory, name)
        if (target.exists()) {
            target = File(directory, "${target.nameWithoutExtension}_${UUID.randomUUID()}.${target.extension}")
        }
        check(target.createNewFile()) { "无法创建导出文件" }
        try {
            source.inputStream().use { input -> target.outputStream().use { input.copyTo(it) } }
            MediaScannerConnection.scanFile(context, arrayOf(target.path), arrayOf(mime), null)
            return mapOf("uri" to Uri.fromFile(target).toString(), "location" to target.path)
        } catch (error: Exception) {
            target.delete()
            throw error
        }
    }
}
