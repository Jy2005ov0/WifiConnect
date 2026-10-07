package com.wificonnect.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts.RequestPermission
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        AutoLogin.sync(this)

        val demo = if (BuildConfig.DEBUG) Demo.from(intent, this) else null

        setContent {
            WifiConnectTheme {
                val context = LocalContext.current
                val model: ConnectionViewModel = viewModel()
                var hasCredentials by remember { mutableStateOf(Credentials.isConfigured(context)) }
                var showSettings by rememberSaveable { mutableStateOf(demo?.showSettings ?: !hasCredentials) }

                // Lets automatic sign-in tell you when it has signed you in.
                val notificationPermission = rememberLauncherForActivityResult(RequestPermission()) { }
                fun askForNotifications() {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                }

                LaunchedEffect(Unit) { demo?.state?.let { model.state = it } }

                // Opening the app on campus signs you in straight away.
                LifecycleResumeEffect(Unit) {
                    if (demo == null && hasCredentials && !showSettings) model.connect(automatic = true)
                    onPauseOrDispose { }
                }

                AnimatedContent(
                    targetState = showSettings,
                    transitionSpec = { fadeIn() togetherWith fadeOut() },
                    label = "screen",
                ) { settings ->
                    if (settings) {
                        SettingsScreen(onDone = {
                            hasCredentials = Credentials.isConfigured(context)
                            showSettings = false
                            if (PortalSettings.load(context).autoLogin) askForNotifications()
                        })
                    } else {
                        MainScreen(
                            state = model.state,
                            hasCredentials = hasCredentials,
                            onConnect = { if (hasCredentials) model.connect() else showSettings = true },
                            onOpenSettings = { showSettings = true },
                        )
                    }
                }
            }
        }
    }
}

/** Debug-only launch extras used to take the README screenshots. */
private class Demo(val state: ConnectionState?, val showSettings: Boolean) {
    companion object {
        fun from(intent: android.content.Intent, context: android.content.Context): Demo? {
            val stateName = intent.getStringExtra("demoState") ?: return null
            intent.getStringExtra("demoStudentId")?.let {
                Credentials.setStudentId(context, it)
                Credentials.setPassword(context, "password")
            }
            val state = when (stateName) {
                "working" -> ConnectionState.Working
                "connected" -> ConnectionState.Connected("You're signed in and ready to go.")
                "failed" -> ConnectionState.Failed(LoginError.StillOffline.message.orEmpty())
                else -> ConnectionState.Idle
            }
            return Demo(state, intent.getStringExtra("demoScreen") == "settings")
        }
    }
}
