package com.wificonnect.app

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/** A Quick Settings tile: tap it to sign in without opening the app. */
class WifiTileService : TileService() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var working = false

    override fun onStartListening() {
        render()
    }

    override fun onClick() {
        if (working) return
        if (!Credentials.isConfigured(this)) {
            openApp()
            return
        }
        working = true
        render()
        scope.launch {
            runCatching { PortalLogin.logIn(applicationContext, trigger = SignInTrigger.TILE) }
            working = false
            render()
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    private fun render() {
        val tile = qsTile ?: return
        val last = SignInStatus.load(this)
        val (state, subtitle, icon) = when {
            working -> Triple(Tile.STATE_ACTIVE, getString(R.string.tile_signing_in), R.drawable.ic_status_wifi)
            last == null -> Triple(Tile.STATE_INACTIVE, getString(R.string.tile_tap_to_sign_in), R.drawable.ic_status_wifi)
            last.kind == SignInStatus.Kind.FAILED || last.kind == SignInStatus.Kind.SIGNED_OUT ->
                Triple(Tile.STATE_INACTIVE, getString(R.string.tile_tap_to_retry), R.drawable.ic_status_wifi_off)
            else -> Triple(Tile.STATE_ACTIVE, getString(R.string.tile_signed_in_at, last.timeText(this)), R.drawable.ic_status_check)
        }
        tile.label = getString(R.string.tile_label)
        tile.state = state
        tile.icon = Icon.createWithResource(this, icon)
        if (Build.VERSION.SDK_INT >= 29) tile.subtitle = subtitle
        tile.updateTile()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
