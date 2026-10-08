package com.wificonnect.app

import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.QuestionMark
import androidx.compose.material.icons.rounded.Badge
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeTopAppBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.ui.res.stringResource
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
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
import androidx.compose.ui.unit.em
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.draw.drawWithContent

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
    speedSummary: String? = null,
    onOpenSpeedTest: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
) {
    val context = LocalContext.current
    val view = LocalView.current

    // Only buzz when the state changes, not again when the screen is rebuilt
    // (turning the phone, a dark-mode or language change).
    var lastState by rememberSaveable { mutableStateOf(state.javaClass.name) }
    LaunchedEffect(state) {
        if (state.javaClass.name == lastState) return@LaunchedEffect
        lastState = state.javaClass.name
        val feedback = when {
            state is ConnectionState.Connected && Build.VERSION.SDK_INT >= 30 -> HapticFeedbackConstants.CONFIRM
            state is ConnectionState.Failed && Build.VERSION.SDK_INT >= 30 -> HapticFeedbackConstants.REJECT
            else -> null
        }
        feedback?.let { view.performHapticFeedback(it) }
    }

    val tint by animateColorAsState(state.tint(MaterialTheme.colorScheme.primary), tween(600), label = "tint")
    val background = MaterialTheme.colorScheme.background

    // The big title shrinks into the bar when the page scrolls (small phones, large text).
    val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior()
    Scaffold(
        containerColor = Color.Transparent,
        // With a transparent container Material can't pick a text colour, so set it explicitly.
        contentColor = MaterialTheme.colorScheme.onBackground,
        modifier = Modifier
            .drawBehind { drawRect(background) }
            .nestedScroll(scrollBehavior.nestedScrollConnection),
        topBar = {
            // Scrolled: a solid glass-like bar that fades softly into the content below, rather than
            // ending in a hard edge (Apple's design guidance, via the apple-design skill).
            val scrolled = scrollBehavior.state.collapsedFraction
            val barColor = MaterialTheme.colorScheme.background
            LargeTopAppBar(
                modifier = Modifier.drawWithContent {
                    drawContent()
                    if (scrolled > 0f) {
                        val fade = 12.dp.toPx()
                        drawRect(
                            Brush.verticalGradient(
                                listOf(Color.Black.copy(alpha = 0.06f * scrolled), Color.Transparent),
                                startY = size.height, endY = size.height + fade,
                            ),
                            topLeft = Offset(0f, size.height),
                            size = Size(size.width, fade),
                        )
                    }
                },
                // Big type a little heavier and tighter.
                title = { Text(stringResource(R.string.main_title), fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.02).em) },
                navigationIcon = {
                    IconButton(onClick = onOpenHelp) {
                        // A solid circle with a ? inside, so help is easy to spot.
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primary),
                        ) {
                            Icon(
                                Icons.Rounded.QuestionMark,
                                contentDescription = stringResource(R.string.history_help),
                                tint = Color.White,
                                modifier = Modifier.size(18.dp),
                            )
                        }
                    }
                },
                actions = {
                    AppearanceMenu(appearance, onAppearanceChange)
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Rounded.Settings, contentDescription = stringResource(R.string.settings_title), tint = MaterialTheme.colorScheme.primary)
                    }
                },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = Color.Transparent,
                    scrolledContainerColor = barColor.copy(alpha = 0.94f),
                ),
                scrollBehavior = scrollBehavior,
            )
        },
    ) { padding ->
        // Scrolls only when it doesn't fit (small phones, split screen, large text); otherwise
        // the spacers spread it over the screen as before.
        BoxWithConstraints(Modifier.fillMaxSize().padding(padding)) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .heightIn(min = maxHeight)
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.weight(1f))

            // The big circle is the button: Connect, or Disconnect once connected.
            val connected = hasCredentials && state is ConnectionState.Connected
            val hint = when {
                !hasCredentials -> stringResource(R.string.button_add_student_id)
                state == ConnectionState.Working -> null
                connected -> stringResource(R.string.hint_tap_disconnect)
                state is ConnectionState.Failed -> stringResource(R.string.hint_tap_try_again)
                else -> stringResource(R.string.hint_tap_connect)
            }
            StatusBadge(
                state, tint,
                enabled = state != ConnectionState.Working,
                description = hint ?: title(state, hasCredentials),
                // Disconnect, or try disconnecting again after it failed.
                onClick = if (connected || (state as? ConnectionState.Failed)?.signingOut == true) onSignOut else onConnect,
            )

            Text(
                text = hint ?: " ",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                // Green and orange are too light to read on the pale pill in light mode; darken them.
                color = if (MaterialTheme.colorScheme.background.luminance() > 0.5f) lerp(tint, Color.Black, 0.35f) else tint,
                modifier = Modifier
                    .padding(top = 6.dp)
                    .alpha(if (hint == null) 0f else 1f)
                    // Rounded rather than a full circle, so wrapped words aren't cut at the ends.
                    .clip(RoundedCornerShape(20.dp))
                    .background(tint.copy(alpha = 0.12f))
                    .padding(horizontal = 14.dp, vertical = 6.dp),
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(14.dp))
            Text(
                text = title(state, hasCredentials),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.02).em,
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
                shape = RoundedCornerShape(26.dp),
                // Solid white (dark gray in dark mode).
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column {
                    val settings = PortalSettings.load(context)
                    DetailRow(Icons.Rounded.Wifi, Blue, stringResource(R.string.row_network), settings.wifiName.ifEmpty { stringResource(R.string.not_set) })
                    RowDivider()
                    DetailRow(
                        Icons.Rounded.Badge, Indigo, stringResource(R.string.row_student_id),
                        Credentials.studentId(context).ifEmpty { stringResource(R.string.not_set) },
                    )
                    RowDivider()
                    DetailRow(
                        Icons.Rounded.Bolt, Green, stringResource(R.string.row_auto_sign_in),
                        stringResource(if (settings.autoLogin) R.string.on else R.string.off),
                        onClick = onOpenSettings,
                    )
                    RowDivider()
                    DetailRow(
                        Icons.Rounded.Speed, Orange, stringResource(R.string.speed_title),
                        speedSummary ?: stringResource(R.string.speed_test),
                        onClick = onOpenSpeedTest,
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
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
            Icon(appearance.icon, contentDescription = stringResource(R.string.appearance), tint = MaterialTheme.colorScheme.primary)
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            shape = RoundedCornerShape(20.dp),
            containerColor = MaterialTheme.colorScheme.surfaceContainerHighest,
        ) {
            Appearance.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(stringResource(option.title)) },
                    leadingIcon = {
                        if (option == appearance) Icon(Icons.Rounded.Check, contentDescription = stringResource(R.string.selected))
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
private fun StatusBadge(
    state: ConnectionState,
    tint: Color,
    enabled: Boolean,
    description: String,
    onClick: () -> Unit,
) {
    // Still when animations are off: a slow loop like this bothers people sensitive to motion.
    val reduceMotion = rememberReduceMotion()
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

    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val press by animateFloatAsState(if (pressed) 0.92f else 1f, spring(), label = "press")

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .scale(press)
            .clip(CircleShape)
            .clickable(
                interactionSource = interaction,
                indication = null,
                enabled = enabled,
                role = Role.Button,
                onClickLabel = description,
                onClick = onClick,
            )
            .semantics { contentDescription = description },
    ) {
        Box(
            Modifier
                .size(188.dp)
                .scale(if (reduceMotion) 1f else breathing)
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
                    .alpha(if (state == ConnectionState.Working && !reduceMotion) pulse else 1f),
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
                .clip(RoundedCornerShape(9.dp))
                .background(Brush.verticalGradient(listOf(lighten(color), color))),
        ) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(14.dp))
        Text(title, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(8.dp))
        // Shares the row with the title instead of taking a fixed width, so neither is squeezed
        // out; right-aligned like the iPhone.
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f),
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


@Composable
private fun title(state: ConnectionState, hasCredentials: Boolean) = stringResource(
    when (state) {
        ConnectionState.Idle -> if (hasCredentials) R.string.status_ready else R.string.status_welcome
        ConnectionState.Working -> R.string.status_signing_in
        is ConnectionState.Connected -> R.string.status_connected
        is ConnectionState.Failed -> if (state.signingOut) R.string.status_sign_out_failed else R.string.status_failed
        ConnectionState.SignedOut -> R.string.status_signed_out
    }
)

@Composable
private fun subtitle(state: ConnectionState, hasCredentials: Boolean) = when (state) {
    ConnectionState.Idle -> stringResource(if (hasCredentials) R.string.status_ready_detail else R.string.status_welcome_detail)
    ConnectionState.Working -> stringResource(R.string.status_signing_in_detail)
    is ConnectionState.Connected -> state.message
    is ConnectionState.Failed -> state.message
    ConnectionState.SignedOut -> stringResource(R.string.status_signed_out_detail)
}
