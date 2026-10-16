package ax.puzzled.torrid

import android.content.ClipData
import android.content.Intent
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.HostnameVerifier

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "torrid/media_share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                    val root = File(cacheDir, "media_share").canonicalFile
                    require(file.isFile && file.path.startsWith(root.path + File.separator))
                    val uri = FileProvider.getUriForFile(this, "$packageName.media_share", file)
                    val mime = call.argument<String>("mimeType")?.takeIf { it.isNotBlank() }
                        ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
                        ?: "application/octet-stream"
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newUri(contentResolver, file.name, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(intent, "分享"))
                    result.success(null)
                } catch (error: Exception) {
                    result.error("share_failed", error.localizedMessage, null)
                }
            }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // 自签证书场景: 跳过主机名验证 (证书 SAN 为空,
        // 且服务端 IP 在校园网环境下会变化, 无法固定)
        HttpsURLConnection.setDefaultHostnameVerifier(
            HostnameVerifier { _, _ -> true }
        )
        super.onCreate(savedInstanceState)
    }
}
