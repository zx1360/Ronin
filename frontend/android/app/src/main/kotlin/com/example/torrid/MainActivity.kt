package com.example.torrid

import io.flutter.embedding.android.FlutterActivity
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.HostnameVerifier

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // 自签证书场景: 跳过主机名验证 (证书 SAN 为空,
        // 且服务端 IP 在校园网环境下会变化, 无法固定)
        HttpsURLConnection.setDefaultHostnameVerifier(
            HostnameVerifier { _, _ -> true }
        )
        super.onCreate(savedInstanceState)
    }
}
