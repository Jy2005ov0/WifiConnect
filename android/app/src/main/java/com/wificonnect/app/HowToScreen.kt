package com.wificonnect.app

import android.content.Intent
import android.view.HapticFeedbackConstants
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.HelpOutline
import androidx.compose.material.icons.rounded.Badge
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

private class GuideStep(
    val icon: ImageVector,
    val color: Color,
    val title: String,
    val text: String,
    val button: String? = null,
    val action: (() -> Unit)? = null,
    val done: Boolean = false,
)

/** The ? button's guide: how to use the app, one step at a time. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HowToScreen(hasCredentials: Boolean, onBack: () -> Unit, onOpenSettings: () -> Unit) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current
    val view = LocalView.current
    val wifiName = PortalSettings.load(context).wifiName.ifEmpty { "utarwifi" }

    val steps = listOf(
        GuideStep(Icons.Rounded.Badge, Indigo, stringResource(R.string.guide_account_title),
            stringResource(R.string.guide_account_text),
            stringResource(R.string.guide_open_settings), onOpenSettings, done = hasCredentials),
        GuideStep(Icons.Rounded.Wifi, Blue, stringResource(R.string.guide_join_title),
            stringResource(R.string.guide_join_text, wifiName),
            stringResource(R.string.guide_open_wifi), {
                context.startActivity(Intent(android.provider.Settings.ACTION_WIFI_SETTINGS))
            }),
        GuideStep(Icons.Rounded.TouchApp, Blue, stringResource(R.string.guide_tap_title),
            stringResource(R.string.guide_tap_text)),
        GuideStep(Icons.Rounded.CheckCircle, Green, stringResource(R.string.guide_online_title),
            stringResource(R.string.guide_online_text)),
        GuideStep(Icons.Rounded.Bolt, Orange, stringResource(R.string.guide_auto_title),
            stringResource(R.string.guide_auto_text_android, wifiName)),
        GuideStep(Icons.AutoMirrored.Rounded.HelpOutline, Color(0xFFFF2D55), stringResource(R.string.guide_help_title),
            stringResource(R.string.guide_help_text)),
    )

    val pager = rememberPagerState { steps.size }
    val scope = rememberCoroutineScope()
    val isLast = pager.currentPage == steps.size - 1
    // A tick when you land on another step: not when the guide opens, nor halfway through a swipe.
    var lastPage by remember { mutableStateOf(pager.settledPage) }
    LaunchedEffect(pager.settledPage) {
        if (pager.settledPage != lastPage) view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        lastPage = pager.settledPage
    }
    // The back gesture goes to the previous step first, like the Back button.
    BackHandler(enabled = pager.currentPage > 0) {
        scope.launch { pager.animateScrollToPage(pager.currentPage - 1) }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.guide_title), fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    // Close, not Back: the Back button at the bottom goes to the previous step.
                    IconButton(onClick = onBack) {
                        Icon(Icons.Rounded.Close, contentDescription = stringResource(R.string.close))
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Transparent),
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            HorizontalPager(state = pager, modifier = Modifier.weight(1f)) { page ->
                StepPage(steps[page], page + 1, steps.size)
            }

            // Where you are: a dot per step, the current one longer.
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                modifier = Modifier.fillMaxWidth().padding(bottom = 18.dp),
            ) {
                repeat(steps.size) { i ->
                    val width by animateDpAsState(if (i == pager.currentPage) 22.dp else 8.dp, label = "dot")
                    Box(
                        Modifier
                            .size(width, 8.dp)
                            .clip(CircleShape)
                            .background(
                                if (i == pager.currentPage) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.outlineVariant
                            )
                    )
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 16.dp),
            ) {
                if (pager.currentPage > 0) {
                    OutlinedButton(
                        onClick = { scope.launch { pager.animateScrollToPage(pager.currentPage - 1) } },
                        modifier = Modifier.weight(1f).heightIn(min = 50.dp),
                        // Room for long words (Malay, Tamil) at large text sizes.
                        contentPadding = PaddingValues(horizontal = 8.dp),
                    ) { Text(stringResource(R.string.back), textAlign = TextAlign.Center) }
                }
                Button(
                    onClick = {
                        if (isLast) onBack() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
                    },
                    modifier = Modifier.weight(1f).heightIn(min = 50.dp),
                    contentPadding = PaddingValues(horizontal = 8.dp),
                ) {
                    Text(
                        stringResource(if (isLast) R.string.guide_got_it else R.string.guide_next),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        }
    }
}

@Composable
private fun StepPage(step: GuideStep, number: Int, total: Int) {
    val doneLabel = stringResource(R.string.guide_completed)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 28.dp),
    ) {
        Spacer(Modifier.height(24.dp))
        Text(
            stringResource(R.string.guide_step, number, total),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(24.dp))
        Box(contentAlignment = Alignment.BottomEnd) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(Brush.verticalGradient(listOf(step.color.copy(alpha = 0.8f), step.color))),
            ) {
                Icon(step.icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(44.dp))
            }
            if (step.done) {
                Icon(
                    Icons.Rounded.CheckCircle,
                    contentDescription = doneLabel,
                    tint = Green,
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                        .semantics { contentDescription = doneLabel },
                )
            }
        }
        Spacer(Modifier.height(24.dp))
        Text(
            step.title,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            step.text,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        if (step.button != null && step.action != null) {
            Spacer(Modifier.height(20.dp))
            FilledTonalButton(onClick = step.action) { Text(step.button, textAlign = TextAlign.Center) }
        }
        Spacer(Modifier.height(24.dp))
    }
}
