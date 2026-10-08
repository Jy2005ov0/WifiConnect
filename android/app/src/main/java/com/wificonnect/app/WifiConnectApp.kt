package com.wificonnect.app

import android.app.Application
import android.content.Context

/** Applies the in-app language to the whole app (notifications, widget, tile), not just the screens. */
class WifiConnectApp : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(AppLanguage.wrap(base))
    }
}
