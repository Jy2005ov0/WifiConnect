package com.wificonnect.app

import android.app.Activity
import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import androidx.core.content.edit
import java.util.Locale

/** The app's own language, separate from the phone's. [SYSTEM] follows the phone. */
enum class AppLanguage(val tag: String, val nativeName: String) {
    SYSTEM("", ""),
    ENGLISH("en", "English"),
    MALAY("ms", "Bahasa Melayu"),
    CHINESE("zh", "简体中文"),
    JAPANESE("ja", "日本語"),
    TAMIL("ta", "தமிழ்");

    companion object {
        private const val KEY = "language"

        private fun prefs(context: Context) = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

        fun current(context: Context): AppLanguage {
            val tag = if (Build.VERSION.SDK_INT >= 33) {
                context.getSystemService(LocaleManager::class.java).applicationLocales.get(0)?.language
            } else {
                prefs(context).getString(KEY, null)
            }
            return entries.firstOrNull { it != SYSTEM && it.tag == tag } ?: SYSTEM
        }

        /** Switches the language. Android 13+ remembers it per app and restarts the screen itself. */
        fun set(activity: Activity, language: AppLanguage) {
            prefs(activity).edit { putString(KEY, language.tag.ifEmpty { null }) }
            if (Build.VERSION.SDK_INT >= 33) {
                activity.getSystemService(LocaleManager::class.java).applicationLocales =
                    LocaleList.forLanguageTags(language.tag)
            } else {
                activity.recreate()
            }
        }

        /** Before Android 13, the app applies its language to each screen itself. */
        fun wrap(base: Context): Context {
            if (Build.VERSION.SDK_INT >= 33) return base
            val tag = prefs(base).getString(KEY, null) ?: return base
            val config = Configuration(base.resources.configuration)
            config.setLocale(Locale.forLanguageTag(tag))
            return base.createConfigurationContext(config)
        }
    }
}
