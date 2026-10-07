package com.wificonnect.app

import android.content.Context
import androidx.annotation.StringRes
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
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager

enum class LoginOutcome { ALREADY_ONLINE, LOGGED_IN }

/** What started a sign-in, for the history. */
enum class SignInTrigger { APP, AUTOMATIC, TILE, WIDGET, BACKGROUND }

sealed class LoginError(@StringRes private val messageRes: Int, private val detail: String? = null) : Exception() {
    object MissingCredentials : LoginError(R.string.error_missing_credentials)
    object NotOnWiFi : LoginError(R.string.error_not_on_wifi)
    object FormNotFound : LoginError(R.string.error_form_not_found)
    object InvalidUrl : LoginError(R.string.error_invalid_url)
    class Network(detail: String) : LoginError(R.string.error_network, detail)
    object StillOffline : LoginError(R.string.error_still_offline)
    object NoSignOutLink : LoginError(R.string.error_no_sign_out_link)
    object StillSignedIn : LoginError(R.string.error_still_signed_in)

    /** The message in the phone's language. */
    fun describe(context: Context): String =
        if (detail != null) context.getString(messageRes, detail) else context.getString(messageRes)
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

    /** What happened during the last sign-in, for the history. */
    val trace = LoginTrace()

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
            trace.portalUrl = page.url

            val submission = if (settings.useCustomPortal) {
                // A path like "/login" is resolved against this building's login page, so one
                // setting works across blocks whose portals live at different addresses.
                val url = settings.loginUrl.trim().takeIf { it.isNotEmpty() }
                    ?.let { HtmlForm.resolve(page.url, it) }
                    ?.takeIf { it.host.isNotEmpty() } ?: throw LoginError.InvalidUrl
                val extra = settings.parsedExtraFields()
                val overridden = extra.map { it.name }.toSet() + settings.usernameField + settings.passwordField
                // Hidden one-time tokens change every visit, so take fresh ones from the page when it has a form.
                val hidden = HtmlForm.loginForm(page.html, page.url)?.inputs.orEmpty()
                    .filter { it.type == "hidden" && it.name !in overridden }
                    .map { FormField(it.name, it.value) }
                val fields = hidden + extra +
                    FormField(settings.usernameField, studentId) +
                    FormField(settings.passwordField, password)
                FormSubmission(url, settings.method, fields)
            } else {
                HtmlForm.loginForm(page.html, page.url)?.submission(studentId, password)
                    ?: throw LoginError.FormNotFound
            }

            trace.formAction = submission.url
            trace.method = submission.method
            trace.fieldNames = submission.fields.map { it.name }

            try {
                val landing = submit(submission, referer = page.url)
                trace.signOutUrl = HtmlForm.signOutLink(landing.html, landing.url)
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

    /** True when this network is showing a login page, i.e. you've been signed out. */
    suspend fun needsSignIn(): Boolean = withContext(Dispatchers.IO) {
        runCatching { probe() is ProbeResult.Portal }.getOrDefault(false)
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

    /** Opens the sign-out link, then checks the login page is back. */
    suspend fun signOut(url: URL) = withContext(Dispatchers.IO) {
        try {
            request(url)
        } catch (e: IOException) {
            throw LoginError.Network(e.message ?: "no response")
        }
        repeat(3) { attempt ->
            if (attempt > 0) delay(1_000)
            if (needsSignIn()) return@withContext
        }
        throw LoginError.StillSignedIn
    }

    /** Sends the form and returns the page it led to. */
    private fun submit(submission: FormSubmission, referer: URL): Page {
        val body = submission.fields.joinToString("&") { "${encode(it.name)}=${encode(it.value)}" }
        if (submission.method.equals("GET", ignoreCase = true)) {
            val base = submission.url.toString()
            val separator = if (submission.url.query.isNullOrEmpty()) "?" else "&"
            return request(URL(base + separator + body), referer = referer)
        }
        return request(submission.url, method = "POST", body = body, referer = referer)
    }

    /** Fetches [url], following redirects (including http ↔ https, which HttpURLConnection won't). */
    private fun request(url: URL, method: String = "GET", body: String? = null, referer: URL? = null): Page {
        var current = url
        var currentMethod = method
        var currentBody = body

        for (hop in 0 until MAX_REDIRECTS) {
            val conn = network.openConnection(current) as HttpURLConnection
            if (conn is HttpsURLConnection && isPrivateAddress(current.host)) trustPortalCertificate(conn)
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

        /** 10.0.0.0/8, 172.16.0.0/12 and 192.168.0.0/16. */
        fun isPrivateAddress(host: String): Boolean {
            val parts = host.split('.').map { it.toIntOrNull() ?: return false }
            if (parts.size != 4 || parts.any { it !in 0..255 }) return false
            return parts[0] == 10 ||
                (parts[0] == 172 && parts[1] in 16..31) ||
                (parts[0] == 192 && parts[1] == 168)
        }

        /**
         * Campus login pages in each building often sit on a bare private IP address with a
         * certificate that can't match it. Accept those, and only those: other sites are checked as usual.
         */
        @Suppress("CustomX509TrustManager", "TrustAllX509TrustManager")
        private fun trustPortalCertificate(conn: HttpsURLConnection) {
            val trustAll = object : X509TrustManager {
                override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) = Unit
                override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) = Unit
                override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
            }
            val context = SSLContext.getInstance("TLS").apply { init(null, arrayOf(trustAll), SecureRandom()) }
            conn.sslSocketFactory = context.socketFactory
            conn.hostnameVerifier = javax.net.ssl.HostnameVerifier { _, _ -> true }
        }

        /** The current Wi-Fi network, even when Android is still routing everything else over mobile data. */
        @Suppress("DEPRECATION")
        fun wifiNetwork(context: Context): Network? {
            val cm = context.getSystemService(ConnectivityManager::class.java)
            return cm.allNetworks.firstOrNull {
                cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
        }

        /**
         * Signs in on the Wi-Fi network, then asks Android to re-check it so the "Sign in" notice goes away.
         * Every attempt is recorded for the widget, the tile and the history.
         */
        suspend fun logIn(
            context: Context,
            network: Network? = wifiNetwork(context),
            trigger: SignInTrigger = SignInTrigger.APP,
        ): LoginOutcome {
            val started = System.currentTimeMillis()
            var login: PortalLogin? = null

            fun record(result: HistoryEntry.Result, message: String?) {
                val trace = login?.trace
                History.add(
                    context,
                    HistoryEntry(
                        time = started,
                        trigger = trigger,
                        result = result,
                        message = message,
                        portal = History.describe(trace?.portalUrl),
                        formAction = History.describe(trace?.formAction),
                        method = trace?.method,
                        fields = trace?.fieldNames.orEmpty(),
                        durationMs = System.currentTimeMillis() - started,
                    ),
                )
            }

            try {
                val wifi = network ?: throw LoginError.NotOnWiFi
                val outcome = PortalLogin(wifi).also { login = it }.logIn(
                    Credentials.studentId(context),
                    Credentials.password(context),
                    PortalSettings.load(context),
                )
                if (outcome == LoginOutcome.LOGGED_IN) {
                    context.getSystemService(ConnectivityManager::class.java).reportNetworkConnectivity(wifi, true)
                    rememberSignOutLink(context, login?.trace)
                }
                record(
                    if (outcome == LoginOutcome.LOGGED_IN) HistoryEntry.Result.SIGNED_IN else HistoryEntry.Result.ALREADY_ONLINE,
                    null,
                )
                SignInStatus.save(
                    context,
                    if (outcome == LoginOutcome.LOGGED_IN) SignInStatus.Kind.SIGNED_IN else SignInStatus.Kind.ALREADY_ONLINE,
                    "",
                )
                return outcome
            } catch (e: LoginError) {
                record(HistoryEntry.Result.FAILED, e.describe(context))
                SignInStatus.save(context, SignInStatus.Kind.FAILED, e.describe(context))
                throw e
            }
        }

        private fun portalPrefs(context: Context) = context.getSharedPreferences("portal", Context.MODE_PRIVATE)

        private fun rememberSignOutLink(context: Context, trace: LoginTrace?) {
            val edit = portalPrefs(context).edit()
            trace?.portalUrl?.let { edit.putString("lastPortal", it.toString()) }
            trace?.signOutUrl?.let { edit.putString("signOut", it.toString()) }
            edit.apply()
        }

        /** Signs out using the link found after signing in, or the one set in Settings. */
        suspend fun signOut(context: Context) {
            val started = System.currentTimeMillis()
            try {
                val prefs = portalPrefs(context)
                val custom = PortalSettings.load(context).signOutUrl.trim()
                val base = prefs.getString("lastPortal", null)?.let { runCatching { URL(it) }.getOrNull() }
                val url = when {
                    custom.isNotEmpty() && base != null -> HtmlForm.resolve(base, custom)
                    custom.isNotEmpty() -> runCatching { URL(custom) }.getOrNull()
                    else -> prefs.getString("signOut", null)?.let { runCatching { URL(it) }.getOrNull() }
                } ?: throw LoginError.NoSignOutLink
                val wifi = wifiNetwork(context) ?: throw LoginError.NotOnWiFi
                PortalLogin(wifi).signOut(url)
                History.add(
                    context,
                    HistoryEntry(started, SignInTrigger.APP, HistoryEntry.Result.SIGNED_OUT,
                        durationMs = System.currentTimeMillis() - started),
                )
                SignInStatus.save(context, SignInStatus.Kind.SIGNED_OUT, "")
            } catch (e: LoginError) {
                History.add(
                    context,
                    HistoryEntry(started, SignInTrigger.APP, HistoryEntry.Result.FAILED, message = e.describe(context),
                        durationMs = System.currentTimeMillis() - started),
                )
                throw e
            }
        }
    }
}
