package com.wificonnect.app

import java.net.URL

/**
 * Sangfor access controllers (UTAR's utarwifi): login pages under `/ac_portal/`. The page is drawn
 * by JavaScript and signs in with a background request instead of a form, with the password
 * scrambled with RC4 using the current time as the key.
 */
object SangforPortal {
    fun isSangfor(url: URL): Boolean = url.path.lowercase().startsWith("/ac_portal/")

    /** Where the page sends the sign-in (and sign-out) request: `/ac_portal/login.php` on the same host. */
    fun loginUrl(portal: URL): URL = URL(portal.protocol, portal.host, portal.port, "/ac_portal/login.php")

    /** The sign-in request's fields. Newer controllers expect the password scrambled, older ones plain. */
    fun signInFields(studentId: String, password: String, scrambled: Boolean, now: Long = System.currentTimeMillis()): List<FormField> {
        val tag = now.toString()
        return listOf(
            FormField("opr", "pwdLogin"),
            FormField("userName", studentId),
            FormField("pwd", if (scrambled) rc4Hex(password, tag) else password),
            FormField("auth_tag", tag),
            FormField("rememberPwd", "0"),
        )
    }

    val signOutFields = listOf(FormField("opr", "logout"))

    private val SUCCESS = Regex("""["']?success["']?\s*:\s*["']?true""", RegexOption.IGNORE_CASE)
    private val MESSAGE = Regex("""["']?msg["']?\s*:\s*["']([^"']*)["']""")

    /** Reads the controller's answer, e.g. `{"success":true,"msg":"logon success"}`, quoted or not. */
    fun answer(body: String): Pair<Boolean, String?> =
        SUCCESS.containsMatchIn(body) to MESSAGE.find(body)?.groupValues?.get(1)?.trim()?.takeIf { it.isNotEmpty() }

    /** RC4 of [text] with [key], as lowercase hex, the same as the login page's JavaScript. */
    fun rc4Hex(text: String, key: String): String {
        val k = key.toByteArray(Charsets.UTF_8)
        if (k.isEmpty()) return ""
        val s = IntArray(256) { it }
        var j = 0
        for (i in 0 until 256) {
            j = (j + s[i] + (k[i % k.size].toInt() and 0xff)) and 255
            val t = s[i]; s[i] = s[j]; s[j] = t
        }
        var i = 0
        j = 0
        val out = StringBuilder()
        for (b in text.toByteArray(Charsets.UTF_8)) {
            i = (i + 1) and 255
            j = (j + s[i]) and 255
            val t = s[i]; s[i] = s[j]; s[j] = t
            out.append("%02x".format((b.toInt() and 0xff) xor s[(s[i] + s[j]) and 255]))
        }
        return out.toString()
    }
}
