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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Badge
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
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
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.res.stringResource
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
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
    appearance: Appearance,
    onAppearanceChange: (Appearance) -> Unit,
    onSignOut: () -> Unit = {},
) {
    val context = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    var speed by remember { mutableStateOf<String?>(null) }
    var testingSpeed by remember { mutableStateOf(false) }

    LaunchedEffect(state) {
        val feedback = when {
            state is ConnectionState.Connected && Build.VERSION.SDK_INT >= 30 -> HapticFeedbackConstants.CONFIRM
            state is ConnectionState.Failed && Build.VERSION.SDK_INT >= 30 -> HapticFeedbackConstants.REJECT
            else -> null
        }
        feedback?.let { view.performHapticFeedback(it) }
    }

    val tint by animateColorAsState(state.tint(MaterialTheme.colorScheme.primary), tween(600), label = "tint")
    val background = MaterialTheme.colorScheme.background

    Scaffold(
        containerColor = Color.Transparent,
        // With a transparent container Material can't pick a text colour, so set it explicitly.
        contentColor = MaterialTheme.colorScheme.onBackground,
        modifier = Modifier.drawBehind {
            drawRect(background)
            // A soft glow in the status color behind the badge.
            drawRect(
                Brush.radialGradient(
                    colors = listOf(tint.copy(alpha = 0.22f), Color.Transparent),
                    center = Offset(size.width / 2, size.height * 0.3f),
                    radius = size.width * 1.1f,
                )
            )
        },
        topBar = {
            LargeTopAppBar(
                title = { Text("Campus Wi-Fi", fontWeight = FontWeight.Bold) },
                actions = {
                    AppearanceMenu(appearance, onAppearanceChange)
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Rounded.Settings, contentDescription = "Settings", tint = MaterialTheme.colorScheme.primary)
                    }
                },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = Color.Transparent,
                    scrolledContainerColor = Color.Transparent,
                ),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            StatusBadge(state, tint)

            Spacer(Modifier.height(26.dp))
            Text(
                text = title(state, hasCredentials),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = subtitle(state, hasCredentials),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 12.dp),
            )

            Spacer(Modifier.weight(1f))

            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column {
                    val settings = PortalSettings.load(context)
                    DetailRow(Icons.Rounded.Wifi, Blue, "Network", settings.wifiName.ifEmpty { "Not Set" })
                    RowDivider()
                    DetailRow(
                        Icons.Rounded.Badge, Indigo, "Student ID",
                        Credentials.studentId(context).ifEmpty { "Not Set" },
                    )
                    RowDivider()
                    DetailRow(
                        Icons.Rounded.Bolt, Green, "Auto Sign-In",
                        if (settings.autoLogin) "On" else "Off",
                        onClick = onOpenSettings,
                    )
                    RowDivider()
                    DetailRow(
                        Icons.Rounded.Speed, Orange, stringResource(R.string.speed_title),
                        when {
                            testingSpeed -> stringResource(R.string.speed_testing)
                            speed != null -> speed.orEmpty()
                            else -> stringResource(R.string.speed_test)
                        },
                        onClick = if (testingSpeed) null else {
                            {
                                testingSpeed = true
                                scope.launch {
                                    speed = try {
                                        SpeedTest.run(context).summary(context)
                                    } catch (e: Exception) {
                                        context.getString(R.string.speed_unavailable)
                                    }
                                    testingSpeed = false
                                }
                            }
                        },
                    )
                }
            }

            Button(
                onClick = onConnect,
                enabled = state != ConnectionState.Working,
                shape = CircleShape,
                modifier = Modifier
                    .padding(top = 20.dp, bottom = if (state is ConnectionState.Connected) 0.dp else 16.dp)
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

            if (state is ConnectionState.Connected) {
                TextButton(onClick = onSignOut, modifier = Modifier.padding(bottom = 4.dp)) {
                    Text(stringResource(R.string.sign_out), color = Color(0xFFFF3B30), fontWeight = FontWeight.Medium)
                }
            }
        }
    }
}

/** A toolbar button that switches between System, Light and Dark. */
@Composable
private fun AppearanceMenu(appearance: Appearance, onChange: (Appearance) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(appearance.icon, contentDescription = "Appearance", tint = MaterialTheme.colorScheme.primary)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            shape = RoundedCornerShape(14.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
        ) {
            Appearance.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.title) },
                    leadingIcon = {
                        if (option == appearance) Icon(Icons.Rounded.Check, contentDescription = "Selected")
                        else Spacer(Modifier.size(24.dp))
                    },
                    trailingIcon = { Icon(option.icon, contentDescription = null) },
                    onClick = {
                        onChange(option)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun StatusBadge(state: ConnectionState, tint: Color) {
    val transition = rememberInfiniteTransition(label = "badge")
    val breathing by transition.animateFloat(
        initialValue = 0.96f,
        targetValue = 1.04f,
        animationSpec = infiniteRepeatable(tween(2000), RepeatMode.Reverse),
        label = "breathing",
    )
    val pulse by transition.animateFloat(
        initialValue = 1f,
        targetValue = 0.35f,
        animationSpec = infiniteRepeatable(tween(700), RepeatMode.Reverse),
        label = "pulse",
    )

    Box(contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(188.dp)
                .scale(breathing)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.10f))
        )
        Box(
            Modifier
                .size(148.dp)
                .clip(CircleShape)
                .background(tint.copy(alpha = 0.14f))
        )
        Box(
            Modifier
                .size(108.dp)
                .shadow(18.dp, CircleShape, ambientColor = tint, spotColor = tint)
                .clip(CircleShape)
                .background(Brush.verticalGradient(listOf(lighten(tint), tint)))
                // A gentle highlight so the disc reads like glass.
                .background(
                    Brush.verticalGradient(
                        0f to Color.White.copy(alpha = 0.28f),
                        0.5f to Color.Transparent,
                    )
                )
        )
        AnimatedContent(
            targetState = when (state) {
                is ConnectionState.Connected -> Icons.Rounded.Check
                is ConnectionState.Failed, ConnectionState.SignedOut -> Icons.Rounded.WifiOff
                else -> Icons.Rounded.Wifi
            },
            transitionSpec = { (fadeIn() + scaleIn(initialScale = 0.6f)) togetherWith fadeOut() },
            label = "icon",
        ) { icon ->
            Icon(
                icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier
                    .size(52.dp)
                    .alpha(if (state == ConnectionState.Working) pulse else 1f),
            )
        }
    }
}

@Composable
private fun DetailRow(
    icon: ImageVector,
    color: Color,
    title: String,
    value: String,
    onClick: (() -> Unit)? = null,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .heightIn(min = 52.dp)
            .padding(horizontal = 14.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(30.dp)
                .clip(RoundedCornerShape(7.dp))
                .background(Brush.verticalGradient(listOf(lighten(color), color))),
        ) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(14.dp))
        Text(title, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 180.dp),
        )
        if (onClick != null) {
            Icon(
                Icons.AutoMirrored.Rounded.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.outline,
                modifier = Modifier.padding(start = 4.dp).size(20.dp),
            )
        }
    }
}

@Composable
private fun RowDivider() {
    HorizontalDivider(Modifier.padding(start = 58.dp), color = MaterialTheme.colorScheme.outlineVariant)
}

private fun lighten(color: Color) = lerp(color, Color.White, 0.18f)

private fun ConnectionState.tint(primary: Color) = when (this) {
    is ConnectionState.Connected -> Green
    is ConnectionState.Failed -> Orange
    ConnectionState.SignedOut -> Color.Gray
    else -> primary
}


private fun title(state: ConnectionState, hasCredentials: Boolean) = when (state) {
    ConnectionState.Idle -> if (hasCredentials) "Ready" else "Welcome"
    ConnectionState.Working -> "Signing In…"
    is ConnectionState.Connected -> "Connected"
    is ConnectionState.Failed -> "Couldn't Sign In"
    ConnectionState.SignedOut -> "Signed Out"
}

private fun subtitle(state: ConnectionState, hasCredentials: Boolean) = when (state) {
    ConnectionState.Idle ->
        if (hasCredentials) "Join your school's Wi-Fi, then tap Connect."
        else "Add your student ID and password to get started."
    ConnectionState.Working -> "Talking to your school's login page."
    is ConnectionState.Connected -> state.message
    is ConnectionState.Failed -> state.message
    ConnectionState.SignedOut -> "You've signed out of the campus Wi-Fi."
}
