package com.example.de_jdg_app

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "danceeval/multicast"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireLock" -> {
                    val wifi = applicationContext
                        .getSystemService(Context.WIFI_SERVICE) as WifiManager
                    multicastLock?.release()
                    multicastLock = wifi.createMulticastLock("danceeval_discovery")
                    multicastLock?.setReferenceCounted(false)
                    multicastLock?.acquire()
                    result.success(null)
                }
                "releaseLock" -> {
                    multicastLock?.release()
                    multicastLock = null
                    result.success(null)
                }
                "getWifiIp" -> {
                    // WifiManager.connectionInfo is deprecated from API 31 (Android 12).
                    // NetworkInterface.list() works correctly on 12+, so we only use
                    // the native fallback on Android 11 and below.
                    if (Build.VERSION.SDK_INT >= 31) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    try {
                        val wifi = applicationContext
                            .getSystemService(Context.WIFI_SERVICE) as WifiManager
                        @Suppress("DEPRECATION")
                        val ipInt = wifi.connectionInfo.ipAddress
                        if (ipInt == 0) {
                            result.success(null)
                        } else {
                            val ip = "%d.%d.%d.%d".format(
                                ipInt and 0xff,
                                (ipInt shr 8) and 0xff,
                                (ipInt shr 16) and 0xff,
                                (ipInt shr 24) and 0xff,
                            )
                            result.success(ip)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
