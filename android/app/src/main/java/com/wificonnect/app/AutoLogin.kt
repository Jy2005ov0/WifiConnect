package com.wificonnect.app

import androidx.work.workDataOf
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.ExistingWorkPolicy
import androidx.work.CoroutineWorker
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

/**
 * Signs in automatically: Android wakes [CaptivePortalReceiver] whenever a Wi-Fi network
 * with a login page appears, even when the app isn't open.
 */
object AutoLogin {
    private const val CHANNEL_ID = "sign-in"
    private const val NOTIFICATION_ID = 1

    fun sync(context: Context) {
        val settings = PortalSettings.load(context)
        val cm = context.getSystemService(ConnectivityManager::class.java)
        val intent = callbackIntent(context)
        runCatching { cm.unregisterNetworkCallback(intent) }
        if (settings.autoLogin) {
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)
                .build()
            cm.registerNetworkCallback(request, intent)
        }
        KeepAliveWorker.sync(context, settings.staySignedIn)
    }

    private fun callbackIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, CaptivePortalReceiver::class.java),
            // Mutable so Android can attach the network that appeared.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    suspend fun run(context: Context, network: Network?, trigger: SignInTrigger = SignInTrigger.AUTOMATIC) {
        if (!Credentials.isConfigured(context)) return
        // You chose Disconnect: don't sign straight back in on your behalf.
        if (trigger == SignInTrigger.AUTOMATIC && SignInStatus.load(context)?.kind == SignInStatus.Kind.SIGNED_OUT) return
        try {
            val outcome = PortalLogin.logIn(context, network ?: PortalLogin.wifiNetwork(context), trigger)
            if (outcome == LoginOutcome.LOGGED_IN) notifySignedIn(context)
        } catch (e: LoginError.OtherNetwork) {
            // Not the school Wi-Fi: nothing to do, and nothing to tell you.
        } catch (e: LoginError.NotSchoolPortal) {
            // Not the school Wi-Fi: nothing to do, and nothing to tell you.
        } catch (e: LoginError) {
            notify(context, context.getString(R.string.notify_failed_title), e.describe(context))
        }
    }

    /** "Connected to utarwifi": shown when the app signs you in on its own. */
    fun notifySignedIn(context: Context) {
        val network = PortalSettings.load(context).wifiName.ifEmpty { PortalSettings.DEFAULT_WIFI_NAME }
        notify(
            context,
            context.getString(R.string.notify_connected_title, network),
            context.getString(R.string.notify_connected_body),
        )
    }

    private fun notify(context: Context, title: String, message: String) {
        if (!PortalSettings.load(context).notifyOnConnect) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, context.getString(R.string.notify_channel), NotificationManager.IMPORTANCE_DEFAULT)
        )
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setTimeoutAfter(10 * 60_000)
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
        // Sign in as background work: a receiver gets only a few seconds, and a slow login page
        // can take longer than that.
        val request = OneTimeWorkRequestBuilder<AutoLoginWorker>()
            .setInputData(workDataOf(AutoLoginWorker.NETWORK to (network?.networkHandle ?: -1L)))
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(AutoLoginWorker.NAME, ExistingWorkPolicy.REPLACE, request)
    }
}

/** Signs in on the Wi-Fi that just showed a login page. */
class AutoLoginWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val handle = inputData.getLong(NETWORK, -1L)
        val network = if (handle >= 0) runCatching { Network.fromNetworkHandle(handle) }.getOrNull() else null
        AutoLogin.run(applicationContext, network)
        return Result.success()
    }

    companion object {
        const val NAME = "auto-login"
        const val NETWORK = "network"
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AutoLogin.sync(context)
    }
}
