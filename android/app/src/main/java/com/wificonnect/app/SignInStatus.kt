package com.wificonnect.app

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.TileService
import android.text.format.DateFormat
import androidx.core.content.edit
import java.util.Date

/** The result of the last sign-in, shown by the widget and the Quick Settings tile. */
object SignInStatus {
    enum class Kind { SIGNED_IN, ALREADY_ONLINE, FAILED, SIGNED_OUT }

    data class Last(val kind: Kind, val message: String, val time: Long) {
        fun timeText(context: Context): String = DateFormat.getTimeFormat(context).format(Date(time))
    }

    private fun prefs(context: Context) = context.getSharedPreferences("status", Context.MODE_PRIVATE)

    fun save(context: Context, kind: Kind, message: String) {
        prefs(context).edit {
            putString("kind", kind.name)
            putString("message", message)
            putLong("time", System.currentTimeMillis())
        }
        refreshSurfaces(context)
    }

    fun load(context: Context): Last? {
        val p = prefs(context)
        val kind = p.getString("kind", null)?.let { runCatching { Kind.valueOf(it) }.getOrNull() } ?: return null
        return Last(kind, p.getString("message", "").orEmpty(), p.getLong("time", 0))
    }

    /** Redraws the widget and asks the tile to refresh. */
    fun refreshSurfaces(context: Context) {
        StatusWidget.updateAll(context)
        runCatching { TileService.requestListeningState(context, ComponentName(context, WifiTileService::class.java)) }
    }
}
