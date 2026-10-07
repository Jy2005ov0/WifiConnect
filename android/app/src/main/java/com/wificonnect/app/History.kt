package com.wificonnect.app

import android.content.Context
import android.os.Build
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** What the app learned about the login page during one sign-in. Never holds the password. */
class LoginTrace {
    var portalUrl: URL? = null
    var formAction: URL? = null
    var method: String? = null
    var fieldNames: List<String> = emptyList()
}

data class HistoryEntry(
    val time: Long,
    val trigger: SignInTrigger,
    val result: Result,
    val message: String? = null,
    val portal: String? = null,
    val formAction: String? = null,
    val method: String? = null,
    val fields: List<String> = emptyList(),
    val durationMs: Long = 0,
) {
    enum class Result { SIGNED_IN, ALREADY_ONLINE, FAILED }

    fun toJson(): JSONObject = JSONObject().apply {
        put("time", time)
        put("trigger", trigger.name)
        put("result", result.name)
        message?.let { put("message", it) }
        portal?.let { put("portal", it) }
        formAction?.let { put("formAction", it) }
        method?.let { put("method", it) }
        put("fields", JSONArray(fields))
        put("durationMs", durationMs)
    }

    companion object {
        fun fromJson(json: JSONObject): HistoryEntry? = runCatching {
            HistoryEntry(
                time = json.getLong("time"),
                trigger = SignInTrigger.valueOf(json.getString("trigger")),
                result = Result.valueOf(json.getString("result")),
                message = json.optString("message").ifEmpty { null },
                portal = json.optString("portal").ifEmpty { null },
                formAction = json.optString("formAction").ifEmpty { null },
                method = json.optString("method").ifEmpty { null },
                fields = json.optJSONArray("fields")?.let { a -> List(a.length()) { a.getString(it) } }.orEmpty(),
                durationMs = json.optLong("durationMs"),
            )
        }.getOrNull()
    }
}

/** The last 50 sign-ins, newest first. */
object History {
    private const val LIMIT = 50

    private fun prefs(context: Context) = context.getSharedPreferences("history", Context.MODE_PRIVATE)

    fun load(context: Context): List<HistoryEntry> {
        val raw = prefs(context).getString("entries", null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            List(array.length()) { HistoryEntry.fromJson(array.getJSONObject(it)) }.filterNotNull()
        }.getOrDefault(emptyList())
    }

    fun save(context: Context, entries: List<HistoryEntry>) {
        val array = JSONArray()
        entries.take(LIMIT).forEach { array.put(it.toJson()) }
        prefs(context).edit { putString("entries", array.toString()) }
    }

    @Synchronized
    fun add(context: Context, entry: HistoryEntry) = save(context, listOf(entry) + load(context))

    fun clear(context: Context) = prefs(context).edit { remove("entries") }

    /** A login page address without its query string, which can hold session tokens. */
    fun describe(url: URL?): String? = url?.let { URL(it.protocol, it.host, it.port, it.path).toString() }

    /** Sample entries for the README screenshots. */
    fun seedDemo(context: Context) {
        val now = System.currentTimeMillis()
        save(
            context,
            listOf(
                HistoryEntry(now - 120_000, SignInTrigger.AUTOMATIC, HistoryEntry.Result.SIGNED_IN, portal = "http://10.1.0.1/login.html", durationMs = 1800),
                HistoryEntry(now - 3_700_000, SignInTrigger.BACKGROUND, HistoryEntry.Result.SIGNED_IN, portal = "http://10.2.0.1/login.html", durationMs = 2100),
                HistoryEntry(now - 7_400_000, SignInTrigger.TILE, HistoryEntry.Result.ALREADY_ONLINE, durationMs = 400),
                HistoryEntry(
                    now - 90_000_000, SignInTrigger.AUTOMATIC, HistoryEntry.Result.FAILED,
                    message = LoginError.StillOffline.message, portal = "http://10.1.0.1/login.html", durationMs = 6900,
                ),
            ),
        )
    }
}

/** A plain-text report to send when something goes wrong. Leaves out the password. */
object Diagnostics {
    fun report(context: Context): String {
        val settings = PortalSettings.load(context)
        val id = Credentials.studentId(context)
        val maskedId = when {
            id.length > 4 -> "${id.take(2)}•••${id.takeLast(2)}"
            id.isEmpty() -> "not set"
            else -> "set"
        }
        val version = runCatching {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        }.getOrNull() ?: "?"
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US)

        val lines = mutableListOf(
            "WiFi Connect diagnostics",
            "App: $version",
            "Device: ${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "",
            "Wi-Fi name: ${settings.wifiName}",
            "Student ID: $maskedId, password: ${if (Credentials.password(context).isEmpty()) "not set" else "set"}",
            "Sign in automatically: ${settings.autoLogin}, stay signed in: ${settings.staySignedIn}",
            "Login page: ${if (settings.useCustomPortal) "manual" else "automatic"}",
        )
        if (settings.useCustomPortal) {
            lines += listOf(
                "  URL: ${settings.loginUrl}",
                "  Method: ${settings.method}",
                "  Fields: ${settings.usernameField}, ${settings.passwordField}",
                "  Extra fields: ${settings.parsedExtraFields().joinToString { it.name }}",
            )
        }
        lines += listOf("", "Recent sign-ins:")
        val entries = History.load(context).take(20)
        if (entries.isEmpty()) lines += "  (none yet)"
        for (entry in entries) {
            lines += "- ${format.format(Date(entry.time))}  ${entry.result}  via ${entry.trigger}  ${"%.1f".format(Locale.US, entry.durationMs / 1000.0)}s"
            entry.message?.let { lines += "    $it" }
            entry.portal?.let { lines += "    page: $it" }
            entry.formAction?.let { lines += "    form: ${entry.method ?: "?"} $it" }
            if (entry.fields.isNotEmpty()) lines += "    fields: ${entry.fields.joinToString()}"
        }
        return lines.joinToString("\n")
    }
}
