package com.fastshare.fastshare

import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fastshare/wifi_lock").setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    acquireMulticastLock()
                    result.success(true)
                }
                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fastshare/device_info").setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceModel" -> result.success(Build.MODEL)
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.fastshare/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val title = call.argument<String>("title") ?: "瞬息"
                    val body = call.argument<String>("body") ?: "Running in background"
                    val intent = ForegroundService.createIntent(this@MainActivity, title, body)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopForegroundService" -> {
                    val intent = ForegroundService.stopIntent(this@MainActivity)
                    startService(intent)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "瞬息"
                    val body = call.argument<String>("body") ?: ""
                    val progress = call.argument<Int>("progress")
                    val progressMax = call.argument<Int>("progressMax")
                    val intent = ForegroundService.updateIntent(
                        this@MainActivity, title, body, progress, progressMax
                    )
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun acquireMulticastLock() {
        if (multicastLock == null) {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as? WifiManager
            if (wifiManager != null) {
                multicastLock = wifiManager.createMulticastLock("FastShare")
                multicastLock?.setReferenceCounted(false)
            }
        }
        try {
            multicastLock?.acquire()
        } catch (_: Exception) {}

        // Also acquire a partial wake lock to keep CPU running for transfers
        if (wakeLock == null) {
            val powerManager = applicationContext.getSystemService(POWER_SERVICE) as? PowerManager
            if (powerManager != null) {
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "FastShare::Transfer"
                )
                wakeLock?.setReferenceCounted(false)
            }
        }
    }

    private fun releaseMulticastLock() {
        try {
            multicastLock?.release()
        } catch (_: Exception) {}
        try {
            wakeLock?.release()
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }
}
