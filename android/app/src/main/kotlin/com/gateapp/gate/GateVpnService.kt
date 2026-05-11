package com.gateapp.gate

import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.channels.SocketChannel
import kotlin.concurrent.thread

class GateVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var mainThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        val proxyPort = intent.getIntExtra("proxyPort", 0)
        startVpn(proxyPort)
        return START_STICKY
    }

    private fun startVpn(proxyPort: Int) {
        val builder = Builder()
            .setSession("Gate VPN")
            .addAddress("10.0.0.2", 24)
            .addDnsServer("8.8.8.8")
            .addRoute("0.0.0.0", 0)
            .setBlocking(true)

        vpnInterface = builder.establish() ?: return

        mainThread = thread {
            val inputStream = FileInputStream(vpnInterface!!.fileDescriptor)
            val outputStream = FileOutputStream(vpnInterface!!.fileDescriptor)
            val buffer = ByteArray(32768)

            while (!Thread.interrupted()) {
                try {
                    val length = inputStream.read(buffer)
                    if (length > 0) {
                        val channel = SocketChannel.open()
                        channel.connect(InetSocketAddress("127.0.0.1", proxyPort))
                        channel.write(java.nio.ByteBuffer.wrap(buffer, 0, length))
                        val responseBuffer = ByteArray(32768)
                        val responseLength = channel.read(java.nio.ByteBuffer.wrap(responseBuffer))
                        if (responseLength > 0) {
                            outputStream.write(responseBuffer, 0, responseLength)
                        }
                        channel.close()
                    }
                } catch (e: Exception) {
                    Log.e("GateVpn", "Error: ${e.message}")
                }
            }
        }
    }

    override fun onDestroy() {
        mainThread?.interrupt()
        vpnInterface?.close()
        super.onDestroy()
    }
}
