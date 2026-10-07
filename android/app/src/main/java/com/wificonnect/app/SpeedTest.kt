package com.wificonnect.app

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/** A quick connection check over the Wi-Fi: best of three round trips, then a 10 MB download. */
object SpeedTest {
    /** Debug-only: a result to show in the README screenshots. */
    var demoResult: String? = null

    data class Result(val pingMs: Long, val mbps: Double) {
        fun summary(context: Context): String {
            val speed = if (mbps >= 10) String.format(Locale.getDefault(), "%.0f", mbps)
            else String.format(Locale.getDefault(), "%.1f", mbps)
            return context.getString(R.string.speed_result, pingMs, speed)
        }
    }

    private val PING_URL = URL("https://speed.cloudflare.com/__down?bytes=0")
    private val DOWNLOAD_URL = URL("https://speed.cloudflare.com/__down?bytes=10000000")

    suspend fun run(context: Context): Result = withContext(Dispatchers.IO) {
        // Measure the Wi-Fi, not mobile data.
        val wifi = PortalLogin.wifiNetwork(context) ?: throw IOException("Not on Wi-Fi")

        fun fetch(url: URL): Long {
            val conn = wifi.openConnection(url) as HttpURLConnection
            try {
                conn.connectTimeout = 10_000
                conn.readTimeout = 10_000
                conn.useCaches = false
                var total = 0L
                conn.inputStream.use { input ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        total += read
                    }
                }
                return total
            } finally {
                conn.disconnect()
            }
        }

        // The first request also sets up the connection, so keep the fastest of three.
        var best = Long.MAX_VALUE
        repeat(3) {
            val start = System.nanoTime()
            fetch(PING_URL)
            best = minOf(best, System.nanoTime() - start)
        }

        val start = System.nanoTime()
        val bytes = fetch(DOWNLOAD_URL)
        val seconds = maxOf((System.nanoTime() - start) / 1e9, 0.001)
        Result(pingMs = best / 1_000_000, mbps = bytes * 8 / seconds / 1_000_000)
    }
}
