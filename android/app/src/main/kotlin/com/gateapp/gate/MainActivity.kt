package com.gateapp.gate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.VpnService

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.gate.app/vpn"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val proxyPort = call.argument<Int>("proxyPort") ?: 0
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        startActivityForResult(intent, 100)
                        result.success(false)
                    } else {
                        val vpnIntent = Intent(this, GateVpnService::class.java)
                        vpnIntent.putExtra("proxyPort", proxyPort)
                        startService(vpnIntent)
                        result.success(true)
                    }
                }
                "stopVpn" -> {
                    stopService(Intent(this, GateVpnService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
