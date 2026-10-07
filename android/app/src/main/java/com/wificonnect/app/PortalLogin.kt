package com.wificonnect.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

enum class LoginOutcome { ALREADY_ONLINE, LOGGED_IN }

sealed class LoginError(message: String) : Exception(message) {
    object MissingCredentials : LoginError("Add your student ID and password in Settings first.")
    object NotOnWiFi : LoginError("Couldn't reach the Wi-Fi. Make sure you're connected to your school's network.")
    object FormNotFound :
        LoginError("Couldn't find a login form on your school's page. Set the login page manually in Settings.")
    object InvalidUrl : LoginError("The custom login URL in Settings isn't valid.")
    class Network(detail: String) : LoginError("The login page didn't respond: $detail")
    object StillOffline : LoginError("Signed in, but there's still no internet. Check your student ID and password.")
}

/**
 * Detects the campus captive portal and signs in to it.
 *
 * All requests go through [network] (the Wi-Fi), because Android keeps using mobile data
 * for everything else until the Wi-Fi login is done.
 */
class PortalLogin(private val network: Network) {
    data class Page(val url: URL, val html: String, val status: Int)

    sealed interface ProbeResult {
        object Online : ProbeResult
        data class Portal(val page: Page) : ProbeResult
    }

    /** Cookies by domain, so the portal's session survives from the login page to the form submission. */
    private val cookies = mutableMapOf<String, MutableMap<String, String>>()

    suspend fun logIn(studentId: String, password: String, settings: PortalSettings): LoginOutcome =
        withContext(Dispatchers.IO) {
            if (studentId.isEmpty() || password.isEmpty()) throw LoginError.MissingCredentials

            val result = try {
                probe()
            } catch (e: IOException) {
                throw LoginError.NotOnWiFi
            }
            val page = (result as? ProbeResult.Portal)?.page ?: return@withContext LoginOutcome.ALREADY_ONLINE

            val submission = if (settings.useCustomPortal) {
                val url = runCatching { URL(settings.loginUrl.trim()) }.getOrNull()
                    ?.takeIf { it.host.isNotEmpty() } ?: throw LoginError.InvalidUrl
                val fields = settings.parsedExtraFields() +
                    FormField(settings.usernameField, studentId) +
                    FormField(settings.passwordField, password)
                FormSubmission(url, settings.method, fields)
            } else {
                HtmlForm.loginForm(page.html, page.url)?.submission(studentId, password)
                    ?: throw LoginError.FormNotFound
            }

            try {
                submit(submission, referer = page.url)
            } catch (e: IOException) {
                throw LoginError.Network(e.message ?: "no response")
            }

            // Give the network a moment to let us through, then confirm.
            repeat(4) { attempt ->
                if (attempt > 0) delay(1_500)
                if (runCatching { probe() }.getOrNull() == ProbeResult.Online) return@withContext LoginOutcome.LOGGED_IN
            }
            throw LoginError.StillOffline
        }

    /** Finds the login form on the current network, for filling in the manual settings. Null when already online. */
    suspend fun detectForm(): HtmlForm? = withContext(Dispatchers.IO) {
        val result = try {
            probe()
        } catch (e: IOException) {
            throw LoginError.NotOnWiFi
        }
        val page = (result as? ProbeResult.Portal)?.page ?: return@withContext null
        HtmlForm.loginForm(page.html, page.url) ?: throw LoginError.FormNotFound
    }

    private fun probe(): ProbeResult {
        var page = request(probeUrl)
        if (page.status == 204 && page.url.host == probeUrl.host) return ProbeResult.Online
        // Some portals bounce through a page or two of meta/JavaScript redirects.
        repeat(3) {
            if (HtmlForm.loginForm(page.html, page.url) != null) return ProbeResult.Portal(page)
            val next = HtmlForm.clientRedirect(page.html, page.url) ?: return ProbeResult.Portal(page)
            page = request(next)
        }
        return ProbeResult.Portal(page)
    }

    private fun submit(submission: FormSubmission, referer: URL) {
        val body = submission.fields.joinToString("&") { "${encode(it.name)}=${encode(it.value)}" }
        if (submission.method.equals("GET", ignoreCase = true)) {
            val base = submission.url.toString()
            val separator = if (submission.url.query.isNullOrEmpty()) "?" else "&"
            request(URL(base + separator + body), referer = referer)
        } else {
            request(submission.url, method = "POST", body = body, referer = referer)
        }
    }

    /** Fetches [url], following redirects (including http ↔ https, which HttpURLConnection won't). */
    private fun request(url: URL, method: String = "GET", body: String? = null, referer: URL? = null): Page {
        var current = url
        var currentMethod = method
        var currentBody = body

        for (hop in 0 until MAX_REDIRECTS) {
            val conn = network.openConnection(current) as HttpURLConnection
            try {
                conn.instanceFollowRedirects = false
                conn.connectTimeout = TIMEOUT_MS
                conn.readTimeout = TIMEOUT_MS
                conn.useCaches = false
                conn.requestMethod = currentMethod
                conn.setRequestProperty("User-Agent", USER_AGENT)
                referer?.let { conn.setRequestProperty("Referer", it.toString()) }
                cookieHeader(current)?.let { conn.setRequestProperty("Cookie", it) }

                val payload = currentBody
                if (payload != null) {
                    conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                    conn.outputStream.use { it.write(payload.toByteArray()) }
                }

                val status = conn.responseCode
                storeCookies(current, conn.headerFields)

                val location = conn.getHeaderField("Location")
                if (status in 300..399 && location != null) {
                    current = HtmlForm.resolve(current, location) ?: throw IOException("Bad redirect")
                    if (status != 307 && status != 308) {
                        currentMethod = "GET"
                        currentBody = null
                    }
                    continue
                }

                val stream = if (status >= 400) conn.errorStream else conn.inputStream
                val html = stream?.use { it.readBytes().toString(Charsets.UTF_8) }.orEmpty()
                return Page(current, html, status)
            } finally {
                conn.disconnect()
            }
        }
        throw IOException("Too many redirects")
    }

    private fun storeCookies(url: URL, headers: Map<String?, List<String>>) {
        val setCookies = headers.entries
            .filter { it.key.equals("Set-Cookie", ignoreCase = true) }
            .flatMap { it.value }
        for (header in setCookies) {
            val parts = header.split(";").map { it.trim() }
            val pair = parts.first().split("=", limit = 2)
            if (pair.size != 2 || pair[0].isEmpty()) continue
            val domain = parts.drop(1)
                .firstOrNull { it.startsWith("domain=", ignoreCase = true) }
                ?.substringAfter("=")?.trimStart('.')?.lowercase()
                ?: url.host.lowercase()
            cookies.getOrPut(domain) { mutableMapOf() }[pair[0]] = pair[1]
        }
    }

    private fun cookieHeader(url: URL): String? {
        val host = url.host.lowercase()
        val matching = cookies
            .filterKeys { host == it || host.endsWith(".$it") }
            .values.flatMap { it.entries }
        return if (matching.isEmpty()) null else matching.joinToString("; ") { "${it.key}=${it.value}" }
    }

    companion object {
        /** The page Android itself uses to detect Wi-Fi login screens. Returns 204 when online. */
        private val DEFAULT_PROBE_URL = URL("http://connectivitycheck.gstatic.com/generate_204")

        /** Debug builds let the end-to-end test point this at a mock login page. */
        var probeUrl: URL = DEFAULT_PROBE_URL
        private const val MAX_REDIRECTS = 8
        private const val TIMEOUT_MS = 10_000
        private const val USER_AGENT =
            "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36"

        private fun encode(s: String): String = URLEncoder.encode(s, "UTF-8")

        /** The current Wi-Fi network, even when Android is still routing everything else over mobile data. */
        @Suppress("DEPRECATION")
        fun wifiNetwork(context: Context): Network? {
            val cm = context.getSystemService(ConnectivityManager::class.java)
            return cm.allNetworks.firstOrNull {
                cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
        }

        /** Signs in on the Wi-Fi network, then asks Android to re-check it so the "Sign in" notice goes away. */
        suspend fun logIn(context: Context, network: Network? = wifiNetwork(context)): LoginOutcome {
            val wifi = network ?: throw LoginError.NotOnWiFi
            val outcome = PortalLogin(wifi).logIn(
                Credentials.studentId(context),
                Credentials.password(context),
                PortalSettings.load(context),
            )
            if (outcome == LoginOutcome.LOGGED_IN) {
                context.getSystemService(ConnectivityManager::class.java).reportNetworkConnectivity(wifi, true)
            }
            return outcome
        }
    }
}
