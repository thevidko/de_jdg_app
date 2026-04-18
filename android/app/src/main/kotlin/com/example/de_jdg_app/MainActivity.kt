package com.example.de_jdg_app

import android.content.Context
import android.net.wifi.WifiManager
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
                else -> result.notImplemented()
            }
        }
    }
}
