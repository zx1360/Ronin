package ax.puzzled.torrid

import android.content.ClipData
import android.content.Intent
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.cert.CertificateFactory
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.HostnameVerifier

class MainActivity : FlutterActivity() {
    companion object {
        private val platformHostnameVerifier = HttpsURLConnection.getDefaultHostnameVerifier()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "torrid/public_media")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveFile") {
                    PublicMediaStore.save(applicationContext, call, result)
                } else {
                    result.notImplemented()
                }
            }
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
        val trustedCertificate = resources.openRawResource(R.raw.server).use {
            CertificateFactory.getInstance("X.509").generateCertificate(it).encoded
        }
        HttpsURLConnection.setDefaultHostnameVerifier(
            HostnameVerifier { host, session ->
                platformHostnameVerifier.verify(host, session) || runCatching {
                    session.peerCertificates.first().encoded.contentEquals(trustedCertificate)
                }.getOrDefault(false)
            }
        )
        super.onCreate(savedInstanceState)
    }
}
