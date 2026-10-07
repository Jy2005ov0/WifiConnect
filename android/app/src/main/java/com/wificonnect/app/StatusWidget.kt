package com.wificonnect.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Home Screen widget: shows the last sign-in and has a Sign In button. */
class StatusWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, views(context)) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_SIGN_IN) return
        updateAll(context, working = true)
        val pending = goAsync()
        val appContext = context.applicationContext
        CoroutineScope(Dispatchers.IO).launch {
            try {
                runCatching { PortalLogin.logIn(appContext, trigger = SignInTrigger.WIDGET) }
            } finally {
                updateAll(appContext)
                pending.finish()
            }
        }
    }

    companion object {
        private const val ACTION_SIGN_IN = "com.wificonnect.app.action.SIGN_IN"

        fun updateAll(context: Context, working: Boolean = false) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, StatusWidget::class.java))
            if (ids.isEmpty()) return
            val views = views(context, working)
            ids.forEach { manager.updateAppWidget(it, views) }
        }

        private fun views(context: Context, working: Boolean = false): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_status)
            val last = SignInStatus.load(context)
            val configured = Credentials.isConfigured(context)

            data class Look(val title: String, val detail: String, val icon: Int, val circle: Int)
            val look = when {
                !configured -> Look(
                    context.getString(R.string.widget_set_up), context.getString(R.string.widget_set_up_detail),
                    R.drawable.ic_status_wifi, R.drawable.widget_circle_blue,
                )
                working -> Look(
                    context.getString(R.string.status_signing_in), context.getString(R.string.status_signing_in_detail),
                    R.drawable.ic_status_wifi, R.drawable.widget_circle_blue,
                )
                last == null -> Look(
                    context.getString(R.string.status_ready), context.getString(R.string.widget_tap_to_sign_in),
                    R.drawable.ic_status_wifi, R.drawable.widget_circle_blue,
                )
                last.kind == SignInStatus.Kind.SIGNED_OUT -> Look(
                    context.getString(R.string.status_signed_out), context.getString(R.string.widget_tap_to_sign_in),
                    R.drawable.ic_status_wifi_off, R.drawable.widget_circle_blue,
                )
                last.kind == SignInStatus.Kind.FAILED -> Look(
                    context.getString(R.string.status_failed), last.message,
                    R.drawable.ic_status_wifi_off, R.drawable.widget_circle_orange,
                )
                else -> Look(
                    context.getString(R.string.status_connected),
                    context.getString(R.string.widget_signed_in_at, last.timeText(context)),
                    R.drawable.ic_status_check, R.drawable.widget_circle_green,
                )
            }
            views.setTextViewText(R.id.widget_title, look.title)
            views.setTextViewText(R.id.widget_detail, look.detail)
            views.setImageViewResource(R.id.widget_icon, look.icon)
            views.setInt(R.id.widget_icon, "setBackgroundResource", look.circle)

            val openApp = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
            )
            val signIn = if (configured) {
                PendingIntent.getBroadcast(
                    context, 1,
                    Intent(context, StatusWidget::class.java).setAction(ACTION_SIGN_IN),
                    PendingIntent.FLAG_IMMUTABLE,
                )
            } else {
                openApp
            }
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            views.setOnClickPendingIntent(R.id.widget_button, signIn)
            return views
        }
    }
}
