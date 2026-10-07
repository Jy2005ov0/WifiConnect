package com.wificonnect.app

import android.content.Context
import androidx.core.content.edit

/** How to reach the school's login page. By default the page is detected automatically. */
data class PortalSettings(
    /** The campus Wi-Fi name, shown on the main screen. */
    val wifiName: String = DEFAULT_WIFI_NAME,
    val autoLogin: Boolean = true,
    /** Check every 15 minutes and sign back in if the Wi-Fi logged you out. */
    val staySignedIn: Boolean = true,
    /** Notify when the app signs in on its own. */
    val notifyOnConnect: Boolean = true,
    /** Ask for a fingerprint or the screen lock before showing Settings. */
    val requireUnlock: Boolean = false,
    val useCustomPortal: Boolean = false,
    val loginUrl: String = "",
    val method: String = "POST",
    val usernameField: String = "username",
    val passwordField: String = "password",
    /** Extra `name=value` pairs, one per line. */
    val extraFields: String = "",
    /** Optional sign-out link; a path is resolved against the last login page. */
    val signOutUrl: String = "",
) {
    fun parsedExtraFields(): List<FormField> =
        extraFields.split('\n', '&').mapNotNull { line ->
            val name = line.substringBefore('=').trim()
            if (name.isEmpty()) null else FormField(name, if ('=' in line) line.substringAfter('=').trim() else "")
        }

    fun save(context: Context) {
        prefs(context).edit {
            putString("wifiName", wifiName)
            putBoolean("autoLogin", autoLogin)
            putBoolean("staySignedIn", staySignedIn)
            putBoolean("notifyOnConnect", notifyOnConnect)
            putBoolean("requireUnlock", requireUnlock)
            putBoolean("useCustomPortal", useCustomPortal)
            putString("loginUrl", loginUrl)
            putString("method", method)
            putString("usernameField", usernameField)
            putString("passwordField", passwordField)
            putString("extraFields", extraFields)
            putString("signOutUrl", signOutUrl)
        }
    }

    companion object {
        /** UTAR's campus Wi-Fi. */
        const val DEFAULT_WIFI_NAME = "utarwifi"

        private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

        fun load(context: Context): PortalSettings {
            val p = prefs(context)
            val d = PortalSettings()
            return PortalSettings(
                wifiName = p.getString("wifiName", d.wifiName) ?: d.wifiName,
                autoLogin = p.getBoolean("autoLogin", d.autoLogin),
                staySignedIn = p.getBoolean("staySignedIn", d.staySignedIn),
                notifyOnConnect = p.getBoolean("notifyOnConnect", d.notifyOnConnect),
                requireUnlock = p.getBoolean("requireUnlock", d.requireUnlock),
                useCustomPortal = p.getBoolean("useCustomPortal", d.useCustomPortal),
                loginUrl = p.getString("loginUrl", d.loginUrl) ?: d.loginUrl,
                method = p.getString("method", d.method) ?: d.method,
                usernameField = p.getString("usernameField", d.usernameField) ?: d.usernameField,
                passwordField = p.getString("passwordField", d.passwordField) ?: d.passwordField,
                extraFields = p.getString("extraFields", d.extraFields) ?: d.extraFields,
                signOutUrl = p.getString("signOutUrl", d.signOutUrl) ?: d.signOutUrl,
            )
        }
    }
}
