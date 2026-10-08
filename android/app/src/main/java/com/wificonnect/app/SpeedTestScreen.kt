package com.wificonnect.app

import androidx.compose.ui.platform.LocalDensity
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.heightIn
import androidx.compose.ui.text.style.TextOverflow
import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ArrowCircleDown
import androidx.compose.material.icons.rounded.ArrowCircleUp
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.em
import java.util.Locale
import androidx.compose.ui.draw.drawBehind
import kotlin.math.log10
import kotlin.math.min

/** The speed test page: a live gauge, then ping, jitter, download and upload results. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SpeedTestScreen(test: SpeedTestViewModel, onBack: () -> Unit) {
    val close = {
        test.stop()
        onBack()
    }
    BackHandler(onBack = close)
    val phase = test.phase

    val background = MaterialTheme.colorScheme.background
    val glow by animateColorAsState(
        when (phase) {
            SpeedTestViewModel.Phase.PING -> Color(0xFFFF9500)
            SpeedTestViewModel.Phase.UPLOAD -> Color(0xFFAF52DE)
            else -> Color(0xFF007AFF)
        },
        tween(600),
        label = "glow",
    )

    Scaffold(
        containerColor = Color.Transparent,
        contentColor = MaterialTheme.colorScheme.onBackground,
        // A soft glow in the stage's color, seen through the glass tiles.
        modifier = Modifier.drawBehind {
            drawRect(background)
            drawRect(
                Brush.radialGradient(
                    colors = listOf(glow.copy(alpha = 0.28f), Color.Transparent),
                    center = Offset(size.width / 2, size.height * 0.22f),
                    radius = size.width,
                )
            )
        },
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.speedtest_title), fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    IconButton(onClick = close) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
        ) {
            SpeedGauge(test)

            val p = SpeedTestViewModel.Phase.PING
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ResultTile(Icons.Rounded.ArrowCircleDown, Blue, R.string.speedtest_download,
                    test.download?.let(SpeedTestViewModel::format), "Mbps", phase == SpeedTestViewModel.Phase.DOWNLOAD,
                    Modifier.weight(1f))
                ResultTile(Icons.Rounded.ArrowCircleUp, Purple, R.string.speedtest_upload,
                    test.upload?.let(SpeedTestViewModel::format), "Mbps", phase == SpeedTestViewModel.Phase.UPLOAD,
                    Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ResultTile(Icons.Rounded.Timer, Orange, R.string.speedtest_ping,
                    test.ping?.let { String.format(Locale.getDefault(), "%.0f", it) }, "ms", phase == p,
                    Modifier.weight(1f))
                ResultTile(Icons.Rounded.GraphicEq, Pink, R.string.speedtest_jitter,
                    test.jitter?.let { String.format(Locale.getDefault(), "%.0f", it) }, "ms", phase == p,
                    Modifier.weight(1f))
            }

            if (phase == SpeedTestViewModel.Phase.FAILED) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Warning, contentDescription = null, tint = Orange, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.speedtest_failed), color = Orange, style = MaterialTheme.typography.bodyMedium)
                }
            }

            Button(
                onClick = { if (test.isRunning) test.stop() else test.start() },
                shape = CircleShape,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (test.isRunning) Color(0xFFFF3B30) else MaterialTheme.colorScheme.primary,
                    contentColor = Color.White,
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 54.dp),
            ) {
                Text(
                    stringResource(
                        when {
                            test.isRunning -> R.string.speedtest_stop
                            phase == SpeedTestViewModel.Phase.IDLE -> R.string.speedtest_start
                            else -> R.string.speedtest_again
                        }
                    ),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }

            Text(
                stringResource(R.string.speedtest_footer),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

private val Purple = Color(0xFFAF52DE)
private val Pink = Color(0xFFFF2D55)
private val Cyan = Color(0xFF32ADE6)
private val Yellow = Color(0xFFFFCC00)

/** A 270° gauge with the live speed in the middle (log scale up to 1 Gbps). */
@Composable
private fun SpeedGauge(test: SpeedTestViewModel) {
    val phase = test.phase
    val target = when (phase) {
        SpeedTestViewModel.Phase.PING -> test.progress
        SpeedTestViewModel.Phase.DOWNLOAD, SpeedTestViewModel.Phase.UPLOAD ->
            min(log10(1 + test.liveMbps) / log10(1001.0), 1.0).toFloat()
        SpeedTestViewModel.Phase.DONE -> 1f
        else -> 0f
    }
    val fill by animateFloatAsState(target, tween(300), label = "gauge")
    val (start, end) = when (phase) {
        SpeedTestViewModel.Phase.PING -> Yellow to Orange
        SpeedTestViewModel.Phase.UPLOAD -> Pink to Purple
        SpeedTestViewModel.Phase.FAILED -> Orange to Orange
        else -> Cyan to Blue
    }
    val accent by animateColorAsState(end, label = "accent")
    val track = MaterialTheme.colorScheme.outlineVariant

    val number = when (phase) {
        SpeedTestViewModel.Phase.PING -> test.ping?.let { String.format(Locale.getDefault(), "%.0f", it) } ?: "–"
        SpeedTestViewModel.Phase.DOWNLOAD, SpeedTestViewModel.Phase.UPLOAD -> SpeedTestViewModel.format(test.liveMbps)
        SpeedTestViewModel.Phase.DONE -> test.download?.let(SpeedTestViewModel::format) ?: "–"
        else -> "–"
    }
    val label = stringResource(
        when (phase) {
            SpeedTestViewModel.Phase.IDLE -> R.string.status_ready
            SpeedTestViewModel.Phase.PING -> R.string.speedtest_ping
            SpeedTestViewModel.Phase.UPLOAD -> R.string.speedtest_upload
            SpeedTestViewModel.Phase.FAILED -> R.string.speedtest_failed_title
            else -> R.string.speedtest_download
        }
    )

    Box(contentAlignment = Alignment.Center, modifier = Modifier.size(260.dp)) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = 18.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(track, 135f, 270f, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            if (fill > 0f) {
                // Rotate so the gradient runs along the arc from its start.
                rotate(135f) {
                    drawArc(
                        Brush.sweepGradient(0f to start, 0.75f to end, 1f to start),
                        0f, 270f * fill, false, Offset(inset, inset), arcSize,
                        style = Stroke(stroke, cap = StrokeCap.Round),
                    )
                }
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                label, color = accent, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.titleSmall,
                textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.widthIn(max = 190.dp),
            )
            // In dp, so a larger font setting can't push the number out of the ring.
            Text(number, fontSize = with(LocalDensity.current) { 60.dp.toSp() }, fontWeight = FontWeight.Bold, letterSpacing = (-0.02).em, maxLines = 1, softWrap = false)
            Text(
                if (phase == SpeedTestViewModel.Phase.PING) "ms" else "Mbps",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
private fun ResultTile(
    icon: ImageVector,
    color: Color,
    title: Int,
    value: String?,
    unit: String,
    active: Boolean,
    modifier: Modifier = Modifier,
) {
    Surface(
        shape = RoundedCornerShape(26.dp),
        // See-through glass over the glow behind the gauge.
        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.6f),
        border = if (active) BorderStroke(2.dp, color) else null,
        modifier = modifier,
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(stringResource(title), color = color, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodyMedium)
            }
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(value ?: "–", fontSize = 28.sp, fontWeight = FontWeight.Bold, maxLines = 1, softWrap = false)
                Spacer(Modifier.width(4.dp))
                Text(
                    unit,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    softWrap = false,
                    modifier = Modifier.padding(bottom = 4.dp),
                )
            }
        }
    }
}
