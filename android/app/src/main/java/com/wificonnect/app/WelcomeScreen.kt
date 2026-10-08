package com.wificonnect.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import androidx.compose.ui.platform.LocalConfiguration
import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.border
import java.util.Locale
import java.util.Date
import java.util.Calendar
import java.text.SimpleDateFormat
import kotlinx.coroutines.delay
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.LaunchedEffect
import android.text.format.DateFormat
import android.os.Build
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.compose.LifecycleResumeEffect

/** The first page when the app opens: the time and a welcome. Swipe it up, like a lock screen. */
@Composable
fun WelcomeScreen(onFinish: () -> Unit) {
    val scope = rememberCoroutineScope()
    val offset = remember { Animatable(0f) }
    val swipeLabel = stringResource(R.string.welcome_swipe)
    val activity = LocalContext.current as? Activity
    BackHandler { activity?.finish() }

    val reduceMotion = rememberReduceMotion()

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val height = with(LocalDensity.current) { maxHeight.toPx() }
        // Slides the page away, carrying on at the speed of the finger that flicked it.
        fun finish(velocity: Float = 0f) = scope.launch {
            if (!reduceMotion) offset.animateTo(-height, spring(dampingRatio = 1f, stiffness = 300f), initialVelocity = velocity)
            onFinish()
        }

        Box(
            Modifier
                .fillMaxSize()
                // Before graphicsLayer: the finger is tracked on the screen, not on the moving page.
                .pointerInput(height) {
                    val velocity = VelocityTracker()
                    // Where the finger has taken the page, before any stretch is applied.
                    var pulled = 0f
                    detectVerticalDragGestures(
                        onDragStart = {
                            velocity.resetTracking()
                            // Grab it where it is, even mid-animation.
                            pulled = offset.value.coerceAtMost(0f)
                        },
                        onVerticalDrag = { change, amount ->
                            change.consume()
                            velocity.addPosition(change.uptimeMillis, change.position)
                            pulled += amount
                            // Up follows the finger 1:1. Down stretches less the further you pull,
                            // instead of stopping dead.
                            val y = if (pulled < 0f) pulled else rubberBand(pulled, height)
                            scope.launch { offset.snapTo(y) }
                        },
                        onDragEnd = {
                            val v = velocity.calculateVelocity().y
                            // Decide by where the flick is heading, not just where the finger let go.
                            val projected = offset.value + project(v)
                            if (v < 300f && (projected < -height * 0.3f || offset.value < -height * 0.2f)) {
                                finish(v)
                            } else {
                                // A little bounce, because a flick put momentum into it.
                                scope.launch {
                                    offset.animateTo(0f, spring(dampingRatio = if (reduceMotion) 1f else 0.8f, stiffness = 500f), initialVelocity = v)
                                }
                            }
                        },
                    )
                }
                .graphicsLayer {
                    translationY = offset.value
                    alpha = 1f - (-offset.value / height).coerceIn(0f, 1f) * 0.6f
                }
                // Frosted glass: the app shows through, blurred, behind the welcome. Android 11 and
                // older can't blur, so there it's nearly solid instead of showing the app sharply.
                .background(MaterialTheme.colorScheme.background.copy(alpha = if (Build.VERSION.SDK_INT >= 31) 0.78f else 0.96f))
                .semantics {
                    customActions = listOf(CustomAccessibilityAction(swipeLabel) { onFinish(); true })
                }
                .safeDrawingPadding()
                .padding(horizontal = 32.dp),
        ) {
            // The welcome fills the space above the hint, so a big clock or large text can't overlap it.
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxSize()) {
            // Design A, with the time where the logo was.
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                Clock()
                Spacer(Modifier.height(20.dp))
                Text(
                    stringResource(R.string.status_welcome),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    stringResource(R.string.welcome_detail),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            val bounceAnimation by rememberInfiniteTransition(label = "hint").animateFloat(
                initialValue = 2f,
                targetValue = -6f,
                animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
                label = "bounce",
            )
            val bounce = if (reduceMotion) 0f else bounceAnimation
            // A see-through glass pill, like the handle on a lock screen.
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .padding(bottom = 20.dp)
                    .graphicsLayer { translationY = bounce.dp.toPx() }
                    // Rounded rather than a full circle, so wrapped words (Tamil) aren't cut at the ends.
                    .clip(RoundedCornerShape(24.dp))
                    .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.55f))
                    .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(24.dp))
                    .clickable(remember { MutableInteractionSource() }, indication = null) { finish() }
                    .padding(horizontal = 22.dp, vertical = 12.dp),
            ) {
                Icon(
                    Icons.Rounded.KeyboardArrowUp,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(22.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    swipeLabel,
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            }
        }
    }
}

/** The date and a big clock, like the Lock Screen. Updates every minute. */
@Composable
private fun Clock(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var now by remember { mutableStateOf(clockTime()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(60_000 - System.currentTimeMillis() % 60_000)
            now = clockTime()
        }
    }
    // The timer above stops while the phone sleeps, so catch up when you come back to the app.
    LifecycleResumeEffect(Unit) {
        now = clockTime()
        onPauseOrDispose { }
    }
    // The app's own language, which may differ from the phone's.
    val locale = LocalConfiguration.current.locales[0] ?: Locale.getDefault()
    val date = SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, "EEEEdMMMM"), locale).format(now)
    val time = SimpleDateFormat(if (DateFormat.is24HourFormat(context)) "H:mm" else "h:mm", locale).format(now)

    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = modifier) {
        Text(
            date,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        // Sized in dp, not sp: with a larger font setting the clock would no longer fit on one line.
        val density = LocalDensity.current
        Text(
            time,
            fontSize = with(density) { 88.dp.toSp() },
            lineHeight = with(density) { 96.dp.toSp() },
            fontWeight = FontWeight.Bold,
            // Big type reads better a little tighter.
            letterSpacing = (-0.02).em,
            maxLines = 1,
            softWrap = false,
        )
    }
}

/** The README screenshots show 9:41, like Apple's. */
private fun clockTime(): Date {
    val now = Calendar.getInstance()
    if (BuildConfig.DEBUG && demoClock) {
        now.set(Calendar.HOUR_OF_DAY, 9)
        now.set(Calendar.MINUTE, 41)
    }
    return now.time
}

/** Set by the screenshot demo so the clock reads 9:41. */
internal var demoClock = false

/** How far the page follows when pulled past its resting place: less and less, never a hard stop. */
private fun rubberBand(overshoot: Float, dimension: Float, constant: Float = 0.55f): Float =
    overshoot * dimension * constant / (dimension + constant * kotlin.math.abs(overshoot))

/** Where a flick would carry the page, like a scroll slowing down (Apple's deceleration rate). */
private fun project(velocity: Float, decelerationRate: Float = 0.998f): Float =
    velocity / 1000f * decelerationRate / (1f - decelerationRate)
