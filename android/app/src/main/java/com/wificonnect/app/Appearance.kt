package com.wificonnect.app

import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BrightnessMedium
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.LightMode
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.core.content.edit

/** The app's light/dark setting. [SYSTEM] follows the phone's own setting. */
enum class Appearance(@StringRes val title: Int, val icon: ImageVector) {
    SYSTEM(R.string.appearance_system, Icons.Rounded.BrightnessMedium),
    LIGHT(R.string.appearance_light, Icons.Rounded.LightMode),
    DARK(R.string.appearance_dark, Icons.Rounded.DarkMode);

    fun isDark(systemDark: Boolean) = when (this) {
        SYSTEM -> systemDark
        LIGHT -> false
        DARK -> true
    }

    fun save(context: Context) {
        prefs(context).edit { putString(KEY, name) }
    }

    companion object {
        private const val KEY = "appearance"

        private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

        fun load(context: Context): Appearance =
            prefs(context).getString(KEY, null)?.let { runCatching { valueOf(it) }.getOrNull() } ?: SYSTEM
    }
}
