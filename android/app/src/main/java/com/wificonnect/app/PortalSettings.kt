package com.wificonnect.app

import android.content.Context
import androidx.core.content.edit

/** How to reach the school's login page. By default the page is detected automatically. */
data class PortalSettings(
    val autoLogin: Boolean = true,
    val useCustomPortal: Boolean = false,
    val loginUrl: String = "",
    val method: String = "POST",
    val usernameField: String = "username",
    val passwordField: String = "password",
    /** Extra `name=value` pairs, one per line. */
    val extraFields: String = "",
) {
    fun parsedExtraFields(): List<FormField> =
        extraFields.split('\n', '&').mapNotNull { line ->
            val name = line.substringBefore('=').trim()
            if (name.isEmpty()) null else FormField(name, if ('=' in line) line.substringAfter('=').trim() else "")
        }

    fun save(context: Context) {
        prefs(context).edit {
            putBoolean("autoLogin", autoLogin)
            putBoolean("useCustomPortal", useCustomPortal)
            putString("loginUrl", loginUrl)
            putString("method", method)
            putString("usernameField", usernameField)
            putString("passwordField", passwordField)
            putString("extraFields", extraFields)
        }
    }

    companion object {
        private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

        fun load(context: Context): PortalSettings {
            val p = prefs(context)
            val d = PortalSettings()
            return PortalSettings(
                autoLogin = p.getBoolean("autoLogin", d.autoLogin),
                useCustomPortal = p.getBoolean("useCustomPortal", d.useCustomPortal),
                loginUrl = p.getString("loginUrl", d.loginUrl) ?: d.loginUrl,
                method = p.getString("method", d.method) ?: d.method,
                usernameField = p.getString("usernameField", d.usernameField) ?: d.usernameField,
                passwordField = p.getString("passwordField", d.passwordField) ?: d.passwordField,
                extraFields = p.getString("extraFields", d.extraFields) ?: d.extraFields,
            )
        }
    }
}
