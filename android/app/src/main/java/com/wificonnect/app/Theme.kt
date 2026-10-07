package com.wificonnect.app

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Same clean palette as the iPhone app: grouped grey background, white cards, system blue.
private val Light = lightColorScheme(
    primary = Color(0xFF007AFF),
    onPrimary = Color.White,
    background = Color(0xFFF2F2F7),
    onBackground = Color(0xFF000000),
    surface = Color(0xFFF2F2F7),
    onSurface = Color(0xFF000000),
    surfaceContainer = Color.White,
    surfaceContainerHigh = Color.White,
    surfaceContainerHighest = Color.White,
    onSurfaceVariant = Color(0xFF6E6E73),
    outlineVariant = Color(0xFFE5E5EA),
)

private val Dark = darkColorScheme(
    primary = Color(0xFF0A84FF),
    onPrimary = Color.White,
    background = Color(0xFF000000),
    onBackground = Color.White,
    surface = Color(0xFF000000),
    onSurface = Color.White,
    surfaceContainer = Color(0xFF1C1C1E),
    surfaceContainerHigh = Color(0xFF1C1C1E),
    surfaceContainerHighest = Color(0xFF2C2C2E),
    onSurfaceVariant = Color(0xFF98989F),
    outlineVariant = Color(0xFF38383A),
)

val Blue = Color(0xFF007AFF)
val Indigo = Color(0xFF5856D6)
val Green = Color(0xFF34C759)
val Orange = Color(0xFFFF9500)

/** Switching between light and dark fades every colour across, like iOS does. */
@Composable
fun WifiConnectTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val target = if (dark) Dark else Light
    val scheme = target.copy(
        primary = animated(target.primary),
        onPrimary = animated(target.onPrimary),
        secondaryContainer = animated(target.secondaryContainer),
        onSecondaryContainer = animated(target.onSecondaryContainer),
        background = animated(target.background),
        onBackground = animated(target.onBackground),
        surface = animated(target.surface),
        onSurface = animated(target.onSurface),
        surfaceContainer = animated(target.surfaceContainer),
        surfaceContainerHigh = animated(target.surfaceContainerHigh),
        surfaceContainerHighest = animated(target.surfaceContainerHighest),
        onSurfaceVariant = animated(target.onSurfaceVariant),
        outline = animated(target.outline),
        outlineVariant = animated(target.outlineVariant),
    )
    MaterialTheme(colorScheme = scheme, content = content)
}

@Composable
private fun animated(color: Color): Color =
    animateColorAsState(color, animationSpec = tween(durationMillis = 450), label = "theme").value
