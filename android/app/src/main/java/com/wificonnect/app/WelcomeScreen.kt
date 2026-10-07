package com.wificonnect.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

/** The first page when the app opens. Swipe it up, like a lock screen, to get to the app. */
@Composable
fun WelcomeScreen(onFinish: () -> Unit) {
    val scope = rememberCoroutineScope()
    val offset = remember { Animatable(0f) }
    val swipeLabel = stringResource(R.string.welcome_swipe)

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val height = with(LocalDensity.current) { maxHeight.toPx() }
        fun finish() = scope.launch {
            offset.animateTo(-height, spring(stiffness = 300f))
            onFinish()
        }

        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer {
                    translationY = offset.value
                    alpha = 1f - (-offset.value / height).coerceIn(0f, 1f) * 0.6f
                }
                .background(MaterialTheme.colorScheme.background)
                .pointerInput(height) {
                    val velocity = VelocityTracker()
                    detectVerticalDragGestures(
                        onDragStart = { velocity.resetTracking() },
                        onVerticalDrag = { change, amount ->
                            change.consume()
                            velocity.addPosition(change.uptimeMillis, change.position)
                            scope.launch { offset.snapTo((offset.value + amount).coerceAtMost(0f)) }
                        },
                        onDragEnd = {
                            val flung = velocity.calculateVelocity().y < -1500f
                            if (flung || -offset.value > height * 0.2f) {
                                finish()
                            } else {
                                scope.launch { offset.animateTo(0f, spring()) }
                            }
                        },
                    )
                }
                .semantics {
                    customActions = listOf(CustomAccessibilityAction(swipeLabel) { onFinish(); true })
                }
                .safeDrawingPadding()
                .padding(horizontal = 32.dp),
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.align(Alignment.Center),
            ) {
                AppLogo()
                Spacer(Modifier.height(28.dp))
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

            val bounce by rememberInfiniteTransition(label = "hint").animateFloat(
                initialValue = 2f,
                targetValue = -6f,
                animationSpec = infiniteRepeatable(tween(900), RepeatMode.Reverse),
                label = "bounce",
            )
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 20.dp)
                    .clickable(remember { MutableInteractionSource() }, indication = null) { finish() },
            ) {
                Icon(
                    Icons.Rounded.KeyboardArrowUp,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .size(32.dp)
                        .graphicsLayer { translationY = bounce.dp.toPx() },
                )
                Text(
                    swipeLabel,
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/** The app icon, drawn from its two adaptive-icon layers. */
@Composable
private fun AppLogo() {
    val size = 112.dp
    val layer = size * 108 / 72 // Adaptive icon layers are 108dp with a 72dp visible area.
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .shadow(18.dp, RoundedCornerShape(26.dp))
            .size(size)
            .clip(RoundedCornerShape(26.dp)),
    ) {
        Image(painterResource(R.drawable.ic_launcher_background), contentDescription = null, modifier = Modifier.requiredSize(layer))
        Image(painterResource(R.drawable.ic_launcher_foreground), contentDescription = null, modifier = Modifier.requiredSize(layer))
    }
}
