package com.wificonnect.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Signs in automatically: Android wakes [CaptivePortalReceiver] whenever a Wi-Fi network
 * with a login page appears, even when the app isn't open.
 */
object AutoLogin {
    private const val CHANNEL_ID = "login"
    private const val NOTIFICATION_ID = 1

    fun sync(context: Context) {
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val intent = callbackIntent(context)
        runCatching { cm.unregisterNetworkCallback(intent) }
        if (PortalSettings.load(context).autoLogin) {
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
                .build()
            cm.registerNetworkCallback(request, intent)
        }
    }

    private fun callbackIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, CaptivePortalReceiver::class.java),
            // Mutable so Android can attach the network that appeared.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    suspend fun run(context: Context, network: Network?) {
        if (!Credentials.isConfigured(context)) return
        val message = try {
            when (PortalLogin.logIn(context, network ?: PortalLogin.wifiNetwork(context))) {
                LoginOutcome.LOGGED_IN -> "Signed in to campus Wi-Fi."
                LoginOutcome.ALREADY_ONLINE -> return
            }
        } catch (e: LoginError) {
            e.message ?: "Couldn't sign in."
        }
        notify(context, message)
    }

    private fun notify(context: Context, message: String) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Wi-Fi sign-in", NotificationManager.IMPORTANCE_LOW)
        )
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(context.getString(R.string.app_name))
            .setContentText(message)
            .setContentIntent(open)
            .setAutoCancel(true)
            .setTimeoutAfter(60_000)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
    }
}

class CaptivePortalReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val network = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK, Network::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK)
        }
        val pending = goAsync()
        val appContext = context.applicationContext
        CoroutineScope(Dispatchers.IO).launch {
            try {
                AutoLogin.run(appContext, network)
            } finally {
                pending.finish()
            }
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AutoLogin.sync(context)
    }
}
