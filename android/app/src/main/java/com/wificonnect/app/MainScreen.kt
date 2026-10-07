package com.wificonnect.app

import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(
    state: ConnectionState,
    hasCredentials: Boolean,
    onConnect: () -> Unit,
    onOpenSettings: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val autoLogin = PortalSettings.load(context).autoLogin

    LaunchedEffect(state) {
        val feedback = when {
            state is ConnectionState.Connected && Build.VERSION.SDK_INT >= 30 -> HapticFeedbackConstants.CONFIRM
            state is ConnectionState.Failed && Build.VERSION.SDK_INT >= 30 -> HapticFeedbackConstants.REJECT
            else -> null
        }
        feedback?.let { view.performHapticFeedback(it) }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            LargeTopAppBar(
                title = { Text("Campus Wi-Fi", fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Rounded.Settings, contentDescription = "Settings", tint = MaterialTheme.colorScheme.primary)
                    }
                },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    scrolledContainerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            StatusBadge(state)

            Spacer(Modifier.height(28.dp))
            Text(
                text = title(state, hasCredentials),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = subtitle(state, hasCredentials),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 8.dp),
            )

            Spacer(Modifier.weight(1f))

            Button(
                onClick = onConnect,
                enabled = state != ConnectionState.Working,
                shape = CircleShape,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
            ) {
                Text(
                    text = when {
                        !hasCredentials -> "Add Student ID"
                        state is ConnectionState.Failed -> "Try Again"
                        else -> "Connect"
                    },
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
                modifier = Modifier.padding(top = 14.dp, bottom = 20.dp),
            ) {
                Icon(
                    Icons.Rounded.Bolt,
                    contentDescription = null,
                    tint = if (autoLogin) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    text = if (autoLogin) "Signs in automatically when you join" else "Automatic sign-in is off",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun StatusBadge(state: ConnectionState) {
    val tint by animateColorAsState(
        targetValue = when (state) {
            is ConnectionState.Connected -> Green
            is ConnectionState.Failed -> Orange
            else -> MaterialTheme.colorScheme.primary
        },
        label = "tint",
    )
    val pulse by rememberInfiniteTransition(label = "pulse").animateFloat(
        initialValue = 1f,
        targetValue = 0.3f,
        animationSpec = infiniteRepeatable(tween(700), RepeatMode.Reverse),
        label = "pulse",
    )

    Box(contentAlignment = Alignment.Center) {
        Circle(168, tint.copy(alpha = 0.12f))
        Circle(124, tint.copy(alpha = 0.18f))
        AnimatedContent(
            targetState = when (state) {
                is ConnectionState.Connected -> Icons.Rounded.Check
                is ConnectionState.Failed -> Icons.Rounded.WifiOff
                else -> Icons.Rounded.Wifi
            },
            transitionSpec = { (fadeIn() + scaleIn(initialScale = 0.6f)) togetherWith fadeOut() },
            label = "icon",
        ) { icon ->
            Icon(
                icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier
                    .size(60.dp)
                    .alpha(if (state == ConnectionState.Working) pulse else 1f),
            )
        }
    }
}

@Composable
private fun Circle(size: Int, color: Color) {
    Box(
        Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(color)
    )
}

private fun title(state: ConnectionState, hasCredentials: Boolean) = when (state) {
    ConnectionState.Idle -> if (hasCredentials) "Ready" else "Welcome"
    ConnectionState.Working -> "Signing In…"
    is ConnectionState.Connected -> "Connected"
    is ConnectionState.Failed -> "Couldn't Sign In"
}

private fun subtitle(state: ConnectionState, hasCredentials: Boolean) = when (state) {
    ConnectionState.Idle ->
        if (hasCredentials) "Join your school's Wi-Fi, then tap Connect."
        else "Add your student ID and password to get started."
    ConnectionState.Working -> "Talking to your school's login page."
    is ConnectionState.Connected -> state.message
    is ConnectionState.Failed -> state.message
}
