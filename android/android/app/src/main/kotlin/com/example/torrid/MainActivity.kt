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
                if (call.method != "shareFile" && call.method != "shareFiles") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val entries = if (call.method == "shareFile") {
                        listOf(mapOf("path" to call.argument<String>("path"), "mimeType" to call.argument<String>("mimeType")))
                    } else {
                        requireNotNull(call.argument<List<Map<String, String?>>>("files"))
                    }
                    require(entries.isNotEmpty())
                    val root = File(cacheDir, "media_share").canonicalFile
                    val files = entries.map { entry ->
                        val file = File(requireNotNull(entry["path"])).canonicalFile
                        require(file.isFile && file.length() > 0 && file.path.startsWith(root.path + File.separator))
                        file
                    }
                    val uris = ArrayList(files.map { FileProvider.getUriForFile(this, "$packageName.media_share", it) })
                    val types = entries.mapIndexed { index, entry ->
                        entry["mimeType"]?.takeIf { it.isNotBlank() }
                            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(files[index].extension.lowercase())
                            ?: "application/octet-stream"
                    }.toSet()
                    val families = types.map { it.substringBefore('/') }.toSet()
                    val mime = if (types.size == 1) types.first()
                        else if (families.size == 1) "${families.first()}/*" else "*/*"
                    val intent = Intent(if (uris.size == 1) Intent.ACTION_SEND else Intent.ACTION_SEND_MULTIPLE).apply {
                        type = mime
                        if (uris.size == 1) putExtra(Intent.EXTRA_STREAM, uris.first())
                        else putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                        clipData = ClipData.newUri(contentResolver, files.first().name, uris.first()).also { clip ->
                            uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
                        }
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
