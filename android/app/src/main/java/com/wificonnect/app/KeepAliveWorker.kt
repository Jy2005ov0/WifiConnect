package com.wificonnect.app

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Stay signed in: every 15 minutes, check whether the campus Wi-Fi has logged you out
 * (it's showing its login page again) and sign back in.
 */
class KeepAliveWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val context = applicationContext
        if (!Credentials.isConfigured(context)) return Result.success()
        val wifi = PortalLogin.wifiNetwork(context) ?: return Result.success()
        if (PortalLogin(wifi).needsSignIn()) {
            AutoLogin.run(context, wifi, SignInTrigger.BACKGROUND)
        }
        return Result.success()
    }

    companion object {
        private const val NAME = "keep-alive"

        fun sync(context: Context, enabled: Boolean) {
            val work = WorkManager.getInstance(context)
            if (enabled) {
                work.enqueueUniquePeriodicWork(
                    NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    PeriodicWorkRequestBuilder<KeepAliveWorker>(15, TimeUnit.MINUTES).build(),
                )
            } else {
                work.cancelUniqueWork(NAME)
            }
        }
    }
}
