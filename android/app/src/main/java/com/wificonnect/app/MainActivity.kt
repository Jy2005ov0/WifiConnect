package com.wificonnect.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.res.stringResource
import androidx.activity.ComponentActivity
import androidx.fragment.app.FragmentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts.RequestPermission
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.DisposableEffect
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

class MainActivity : FragmentActivity() {
    /** A classmate's setup from a wificonnect://setup link, waiting for confirmation. */
    private val incomingSetup = mutableStateOf<SharedSetup?>(null)

    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLanguage.wrap(newBase))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        SharedSetup.fromUrl(intent.dataString)?.let { incomingSetup.value = it }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) incomingSetup.value = SharedSetup.fromUrl(intent?.dataString)
        enableEdgeToEdge()
        AutoLogin.sync(this)

        val demo = if (BuildConfig.DEBUG) Demo.from(intent, this) else null
        val testAction = if (BuildConfig.DEBUG) intent.getStringExtra("testAction") else null
        if (BuildConfig.DEBUG) applyTestExtras()

        setContent {
            val context = LocalContext.current
            var appearance by remember { mutableStateOf(Appearance.load(context)) }
            val dark = appearance.isDark(isSystemInDarkTheme())

            // Match the status and navigation bar icons to the chosen appearance.
            DisposableEffect(dark) {
                val style = SystemBarStyle.auto(android.graphics.Color.TRANSPARENT, android.graphics.Color.TRANSPARENT) { dark }
                enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
                onDispose { }
            }

            val changeAppearance: (Appearance) -> Unit = {
                appearance = it
                it.save(context)
            }

            WifiConnectTheme(dark = dark) {
                val model: ConnectionViewModel = viewModel()
                val speedTest: SpeedTestViewModel = viewModel()
                var hasCredentials by remember { mutableStateOf(Credentials.isConfigured(context)) }
                var showSettings by rememberSaveable { mutableStateOf(demo?.showSettings ?: !hasCredentials) }
                var showHistory by rememberSaveable { mutableStateOf(demo?.showHistory ?: false) }
                var showShare by rememberSaveable { mutableStateOf(demo?.showShare ?: false) }
                var showSpeed by rememberSaveable { mutableStateOf(demo?.showSpeed ?: false) }
                LaunchedEffect(Unit) { if (demo?.speedResult == true) speedTest.showDemoResult() }

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
                    if (testAction == "signOut") {
                        model.signOut()
                    } else if (demo == null && hasCredentials && !showSettings) {
                        model.connect(automatic = true)
                    }
                    onPauseOrDispose { }
                }

                incomingSetup.value?.let { setup ->
                    AlertDialog(
                        onDismissRequest = { incomingSetup.value = null },
                        title = { Text(stringResource(R.string.import_title)) },
                        text = {
                            Text(
                                stringResource(
                                    R.string.import_message,
                                    setup.wifiName,
                                    stringResource(if (setup.useCustomPortal) R.string.login_mode_manual else R.string.login_mode_auto),
                                )
                            )
                        },
                        confirmButton = {
                            TextButton(onClick = {
                                setup.apply(context)
                                incomingSetup.value = null
                            }) { Text(stringResource(R.string.import_use)) }
                        },
                        dismissButton = {
                            TextButton(onClick = { incomingSetup.value = null }) { Text(stringResource(R.string.cancel)) }
                        },
                    )
                }

                AnimatedContent(
                    targetState = when {
                        showSpeed -> 4
                        showSettings && showShare -> 3
                        showSettings && showHistory -> 2
                        showSettings -> 1
                        else -> 0
                    },
                    transitionSpec = { fadeIn() togetherWith fadeOut() },
                    label = "screen",
                ) { screen ->
                    if (screen == 4) {
                        SpeedTestScreen(speedTest, onBack = { showSpeed = false })
                    } else if (screen == 3) {
                        ShareSetupScreen(
                            onBack = { showShare = false },
                            onImport = { incomingSetup.value = it },
                        )
                    } else if (screen == 2) {
                        HistoryScreen(onBack = { showHistory = false })
                    } else if (screen == 1) {
                        SettingsScreen(
                            appearance = appearance,
                            onAppearanceChange = changeAppearance,
                            onLanguageChange = { AppLanguage.set(this@MainActivity, it) },
                            onOpenHistory = { showHistory = true },
                            onOpenShare = { showShare = true },
                            onDone = {
                                hasCredentials = Credentials.isConfigured(context)
                                showSettings = false
                                if (PortalSettings.load(context).autoLogin) askForNotifications()
                            },
                        )
                    } else {
                        MainScreen(
                            state = model.state,
                            hasCredentials = hasCredentials,
                            onConnect = { if (hasCredentials) model.connect() else showSettings = true },
                            onOpenSettings = {
                                // Ask for a fingerprint first when the app lock is on.
                                if (hasCredentials && PortalSettings.load(context).requireUnlock) {
                                    AppLock.authenticate(this@MainActivity, getString(R.string.lock_open_settings)) { ok ->
                                        if (ok) showSettings = true
                                    }
                                } else {
                                    showSettings = true
                                }
                            },
                            appearance = appearance,
                            onAppearanceChange = changeAppearance,
                            onSignOut = { model.signOut() },
                            speedSummary = speedTest.summary,
                            onOpenSpeedTest = { showSpeed = true },
                        )
                    }
                }
            }
        }
    }
}

/** Debug-only launch extras used by the end-to-end test: a mock login page and a test account. */
private fun ComponentActivity.applyTestExtras() {
    intent.getStringExtra("testProbeUrl")?.let { PortalLogin.probeUrl = java.net.URL(it) }
    intent.getStringExtra("testStudentId")?.let { Credentials.setStudentId(this, it) }
    intent.getStringExtra("testPassword")?.let { Credentials.setPassword(this, it) }
}

/** Debug-only launch extras used to take the README screenshots. */
private class Demo(
    val state: ConnectionState?,
    val showSettings: Boolean,
    val showHistory: Boolean,
    val showShare: Boolean,
    val showSpeed: Boolean,
    val speedResult: Boolean,
) {
    companion object {
        fun from(intent: android.content.Intent, context: android.content.Context): Demo? {
            val stateName = intent.getStringExtra("demoState") ?: return null
            intent.getStringExtra("demoStudentId")?.let {
                Credentials.setStudentId(context, it)
                Credentials.setPassword(context, "password")
            }
            val state = when (stateName) {
                "working" -> ConnectionState.Working
                "connected" -> ConnectionState.Connected(context.getString(R.string.result_signed_in))
                "failed" -> ConnectionState.Failed(LoginError.StillOffline.describe(context))
                else -> ConnectionState.Idle
            }
            val screen = intent.getStringExtra("demoScreen")
            if (screen == "history") History.seedDemo(context)
            return Demo(
                state,
                showSettings = screen in setOf("settings", "history", "share"),
                showHistory = screen == "history",
                showShare = screen == "share",
                showSpeed = screen == "speed",
                speedResult = intent.hasExtra("demoSpeed") || screen == "speed",
            )
        }
    }
}
