package com.wificonnect.app

import android.app.Application
import android.net.Network
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs
import kotlin.math.min

/**
 * A full connection test over the Wi-Fi, like a speed test app: ping and jitter,
 * then download and upload, each over several parallel connections for a few seconds.
 */
class SpeedTestViewModel(application: Application) : AndroidViewModel(application) {
    enum class Phase { IDLE, PING, DOWNLOAD, UPLOAD, DONE, FAILED }

    var phase by mutableStateOf(Phase.IDLE)
        private set
    /** The speed right now, for the gauge (Mbps). */
    var liveMbps by mutableStateOf(0.0)
        private set
    /** How far through the current stage (0…1). */
    var progress by mutableStateOf(0f)
        private set
    var ping by mutableStateOf<Double?>(null)
        private set
    var jitter by mutableStateOf<Double?>(null)
        private set
    var download by mutableStateOf<Double?>(null)
        private set
    var upload by mutableStateOf<Double?>(null)
        private set
    /** The last test failed because nothing came through (rather than no connection at all). */
    var noData by mutableStateOf(false)
        private set

    val isRunning: Boolean get() = phase == Phase.PING || phase == Phase.DOWNLOAD || phase == Phase.UPLOAD

    /** A short line for the main screen, e.g. "↓ 92 · ↑ 41 Mbps". */
    val summary: String?
        get() {
            val down = download ?: return null
            val up = upload ?: return null
            return if (phase == Phase.DONE) "↓ ${format(down)} · ↑ ${format(up)} Mbps" else null
        }

    private var job: Job? = null

    fun start() {
        job?.cancel()
        ping = null; jitter = null; download = null; upload = null
        liveMbps = 0.0; progress = 0f; noData = false
        job = viewModelScope.launch {
            try {
                val wifi = PortalLogin.wifiNetwork(getApplication()) ?: throw IOException("Not on Wi-Fi")
                phase = Phase.PING
                measurePing(wifi)
                phase = Phase.DOWNLOAD
                download = measureTransfer(wifi, upload = false)
                phase = Phase.UPLOAD
                upload = measureTransfer(wifi, upload = true)
                liveMbps = 0.0
                phase = Phase.DONE
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                liveMbps = 0.0
                noData = e is NoDataException
                phase = Phase.FAILED
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        if (isRunning) phase = Phase.IDLE
        liveMbps = 0.0
    }

    /** A finished result for the README screenshots. */
    fun showDemoResult() {
        ping = 18.0; jitter = 3.0; download = 92.4; upload = 41.7
        progress = 1f
        phase = Phase.DONE
    }

    /** Ten small requests: the median is the ping, the average change is the jitter. */
    private suspend fun measurePing(wifi: Network) {
        withContext(Dispatchers.IO) { fetch(wifi, PING_URL) } // Sets up the connection.
        val samples = mutableListOf<Double>()
        repeat(10) { i ->
            val start = System.nanoTime()
            withContext(Dispatchers.IO) { fetch(wifi, PING_URL) }
            samples += (System.nanoTime() - start) / 1e6
            progress = (i + 1) / 10f
            ping = samples.sorted()[samples.size / 2]
        }
        jitter = samples.zipWithNext { a, b -> abs(a - b) }.average()
    }

    /** Runs parallel transfers for a few seconds, updating the gauge, and returns the average Mbps. */
    private suspend fun measureTransfer(wifi: Network, upload: Boolean): Double {
        val bytes = AtomicLong(0)
        val failures = AtomicInteger(0)
        val running = AtomicBoolean(true)
        val workers = List(STREAMS) {
            viewModelScope.launch(Dispatchers.IO) {
                // Each transfer starts small and doubles. Many campus networks hold a download back
                // until all of it has arrived (to check it), so one huge download showed nothing.
                var size = FIRST_CHUNK
                while (running.get() && isActive) {
                    try {
                        if (upload) uploadOnce(wifi, bytes, running, size) else downloadOnce(wifi, bytes, running, size)
                        size = minOf(size * 2, LARGEST_CHUNK)
                    } catch (e: IOException) {
                        if (!running.get()) break
                        failures.incrementAndGet()
                        delay(200)
                    }
                }
            }
        }
        try {
            val start = System.nanoTime()
            var lastTime = start
            var lastBytes = 0L
            var warmTime = 0L
            var warmBytes = 0L
            while (true) {
                delay(250)
                val now = System.nanoTime()
                val total = bytes.get()
                val instant = (total - lastBytes) * 8 / ((now - lastTime) / 1e9) / 1e6
                liveMbps = if (liveMbps == 0.0) instant else liveMbps * 0.6 + instant * 0.4
                lastTime = now
                lastBytes = total
                val elapsed = (now - start) / 1e9
                progress = min(elapsed / STAGE_SECONDS, 1.0).toFloat()
                // The first second ramps up, so the average counts from then.
                if (warmTime == 0L && elapsed >= 1) {
                    warmTime = now
                    warmBytes = total
                }
                if (total == 0L && failures.get() >= STREAMS) throw IOException("Test server unreachable")
                if (elapsed >= STAGE_SECONDS) break
            }
            // Nothing at all came through: say so, rather than show 0.
            if (bytes.get() == 0L) throw NoDataException()
            if (warmTime == 0L || lastTime <= warmTime) return liveMbps
            return (lastBytes - warmBytes) * 8 / ((lastTime - warmTime) / 1e9) / 1e6
        } finally {
            running.set(false)
            workers.forEach { it.cancel() }
        }
    }

    companion object {
        private const val SERVER = "https://speed.cloudflare.com"
        private val PING_URL = URL("$SERVER/__down?bytes=0")
        private val UPLOAD_URL = URL("$SERVER/__up")
        private const val FIRST_CHUNK = 1_000_000
        private const val LARGEST_CHUNK = 25_000_000
        private const val STAGE_SECONDS = 8.0
        private const val STREAMS = 4

        fun format(mbps: Double): String =
            if (mbps >= 10) String.format(Locale.getDefault(), "%.0f", mbps)
            else String.format(Locale.getDefault(), "%.1f", mbps)

        private fun open(wifi: Network, url: URL): HttpURLConnection =
            (wifi.openConnection(url) as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 10_000
                useCaches = false
            }

        private fun fetch(wifi: Network, url: URL) {
            val conn = open(wifi, url)
            try {
                conn.inputStream.use { it.readBytes() }
            } finally {
                conn.disconnect()
            }
        }

        private fun downloadOnce(wifi: Network, bytes: AtomicLong, running: AtomicBoolean, size: Int) {
            val conn = open(wifi, URL("$SERVER/__down?bytes=$size"))
            try {
                // A refusal (like 403 or a network's block page) isn't test data.
                if (conn.responseCode !in 200..299) throw IOException("HTTP ${conn.responseCode}")
                conn.inputStream.use { input ->
                    val buffer = ByteArray(64 * 1024)
                    while (running.get()) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        bytes.addAndGet(read.toLong())
                    }
                }
            } finally {
                conn.disconnect()
            }
        }

        private fun uploadOnce(wifi: Network, bytes: AtomicLong, running: AtomicBoolean, size: Int) {
            val conn = open(wifi, UPLOAD_URL)
            try {
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.setFixedLengthStreamingMode(size)
                conn.setRequestProperty("Content-Type", "application/octet-stream")
                val chunk = ByteArray(64 * 1024)
                var sent = 0
                conn.outputStream.use { output ->
                    while (sent < size) {
                        if (!running.get()) return
                        val part = minOf(chunk.size, size - sent)
                        output.write(chunk, 0, part)
                        sent += part
                        bytes.addAndGet(part.toLong())
                    }
                }
                conn.responseCode
            } finally {
                conn.disconnect()
            }
        }
    }
}

/** Nothing came through during a transfer stage. */
private class NoDataException : IOException("No test data came through")
