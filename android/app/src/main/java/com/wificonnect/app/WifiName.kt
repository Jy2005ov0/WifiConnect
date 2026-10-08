package com.wificonnect.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Reads the name of the Wi-Fi you're on, so automatic sign-in only fills in your school's
 * login page. Android only shares the name with location access and Location turned on;
 * the app doesn't use or store your location.
 */
object WifiName {
    enum class Check { ON, NEEDS_PERMISSION, NEEDS_BACKGROUND, LOCATION_OFF }

    fun hasPermission(context: Context) =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /** Automatic sign-in runs in the background, where Android 10+ needs "Allow all the time". */
    fun hasBackgroundPermission(context: Context) =
        Build.VERSION.SDK_INT < 29 || ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

    fun check(context: Context): Check = when {
        !hasPermission(context) -> Check.NEEDS_PERMISSION
        !hasBackgroundPermission(context) -> Check.NEEDS_BACKGROUND
        context.getSystemService(LocationManager::class.java)?.isLocationEnabled == false -> Check.LOCATION_OFF
        else -> Check.ON
    }

    /** The Wi-Fi name, or null when Android won't share it. */
    @Suppress("DEPRECATION")
    fun current(context: Context, network: Network?): String? {
        if (!hasPermission(context)) return null
        val fromNetwork = if (Build.VERSION.SDK_INT >= 29 && network != null) {
            val cm = context.getSystemService(ConnectivityManager::class.java)
            (cm.getNetworkCapabilities(network)?.transportInfo as? WifiInfo)?.ssid
        } else null
        val fromWifi = context.applicationContext.getSystemService(WifiManager::class.java)?.connectionInfo?.ssid
        return clean(fromNetwork) ?: clean(fromWifi)
    }

    private fun clean(ssid: String?): String? =
        ssid?.removeSurrounding("\"")?.takeIf { it.isNotBlank() && it != "<unknown ssid>" }

    /** The Wi-Fi's name when it's clearly not your school's; null when it is, or when it can't be read. */
    fun otherNetwork(context: Context, network: Network?): String? {
        val school = PortalSettings.load(context).wifiName.trim()
        val name = current(context, network) ?: return null
        return name.takeIf { school.isNotEmpty() && !it.equals(school, ignoreCase = true) }
    }
}
