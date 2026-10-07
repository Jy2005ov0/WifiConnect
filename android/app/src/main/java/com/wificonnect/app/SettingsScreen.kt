package com.wificonnect.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.fragment.app.FragmentActivity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    appearance: Appearance,
    onAppearanceChange: (Appearance) -> Unit,
    onOpenHistory: () -> Unit,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var studentId by remember { mutableStateOf(Credentials.studentId(context)) }
    var password by remember { mutableStateOf(Credentials.password(context)) }
    var showPassword by remember { mutableStateOf(false) }
    var settings by remember { mutableStateOf(PortalSettings.load(context)) }
    var detecting by remember { mutableStateOf(false) }
    var detectMessage by remember { mutableStateOf<String?>(null) }

    fun save() {
        Credentials.setStudentId(context, studentId.trim())
        Credentials.setPassword(context, password)
        settings.save(context)
        AutoLogin.sync(context)
    }

    fun saveAndClose() {
        save()
        onDone()
    }

    BackHandler { saveAndClose() }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Settings", fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = ::saveAndClose) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    TextButton(onClick = ::saveAndClose) {
                        Text("Done", fontWeight = FontWeight.SemiBold)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
        ) {
            Section(
                header = "Account",
                footer = "Encrypted on this phone and only sent to your school's login page.",
            ) {
                PlainField(studentId, { studentId = it }, "Student ID")
                Divider()
                PlainField(
                    value = password,
                    onValueChange = { password = it },
                    placeholder = "Password",
                    keyboardType = KeyboardType.Password,
                    visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                    trailing = {
                        IconButton(onClick = { showPassword = !showPassword }) {
                            Icon(
                                if (showPassword) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                contentDescription = if (showPassword) "Hide password" else "Show password",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    },
                )
            }

            Section(
                header = "School Wi-Fi",
                footer = "The Wi-Fi name you join on campus.",
            ) {
                PlainField(settings.wifiName, { settings = settings.copy(wifiName = it) }, "Network Name")
            }

            Section(
                header = "Automatic Sign-In",
                footer = "Signs in by itself whenever your phone joins a Wi-Fi network with a login page, even when the app is closed. " +
                    stringResource(R.string.setting_stay_signed_in_footer),
            ) {
                SwitchRow("Sign In Automatically", settings.autoLogin) { settings = settings.copy(autoLogin = it) }
                Divider()
                SwitchRow(stringResource(R.string.setting_stay_signed_in), settings.staySignedIn) {
                    settings = settings.copy(staySignedIn = it)
                }
                Divider()
                SwitchRow(stringResource(R.string.setting_notify), settings.notifyOnConnect) {
                    settings = settings.copy(notifyOnConnect = it)
                }
            }

            val activity = context as? FragmentActivity
            Section(header = stringResource(R.string.lock_section), footer = stringResource(R.string.lock_footer)) {
                SwitchRow(stringResource(R.string.lock_title), settings.requireUnlock) { enabled ->
                    // Turning the lock on or off needs the same unlock.
                    val confirm = context.getString(R.string.lock_confirm)
                    if (activity == null) {
                        settings = settings.copy(requireUnlock = enabled)
                    } else {
                        AppLock.authenticate(activity, confirm) { ok ->
                            if (ok) settings = settings.copy(requireUnlock = enabled)
                        }
                    }
                }
            }

            Section(header = stringResource(R.string.history_help), footer = null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            save()
                            onOpenHistory()
                        }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                ) {
                    Text(stringResource(R.string.history_title), modifier = Modifier.weight(1f))
                    Icon(
                        Icons.AutoMirrored.Rounded.KeyboardArrowRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.outline,
                    )
                }
            }

            Section(header = "Appearance", footer = null, card = false) {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    Appearance.entries.forEachIndexed { index, option ->
                        SegmentedButton(
                            selected = appearance == option,
                            onClick = { onAppearanceChange(option) },
                            shape = SegmentedButtonDefaults.itemShape(index, Appearance.entries.size),
                            icon = {},
                        ) { Icon(option.icon, contentDescription = option.title, modifier = Modifier.size(20.dp)) }
                    }
                }
            }

            Section(
                header = "Login Page",
                footer = detectMessage
                    ?: "The login page is found automatically, even when each building uses a different address. If that doesn't work, join the school Wi-Fi and tap Detect Login Page, or fill it in manually. Enter just the path, like /login, so it works in every building.",
            ) {
                SwitchRow("Set Login Page Manually", settings.useCustomPortal) {
                    settings = settings.copy(useCustomPortal = it)
                }
                if (settings.useCustomPortal) {
                    Divider()
                    LabeledField("URL or Path", settings.loginUrl, "/login", KeyboardType.Uri) {
                        settings = settings.copy(loginUrl = it)
                    }
                    Divider()
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    ) {
                        Text("Method", modifier = Modifier.weight(1f))
                        SingleChoiceSegmentedButtonRow {
                            listOf("POST", "GET").forEachIndexed { index, method ->
                                SegmentedButton(
                                    selected = settings.method == method,
                                    onClick = { settings = settings.copy(method = method) },
                                    shape = SegmentedButtonDefaults.itemShape(index, 2),
                                    icon = {},
                                ) { Text(method) }
                            }
                        }
                    }
                    Divider()
                    LabeledField("ID Field", settings.usernameField, "username") {
                        settings = settings.copy(usernameField = it)
                    }
                    Divider()
                    LabeledField("Password Field", settings.passwordField, "password") {
                        settings = settings.copy(passwordField = it)
                    }
                    Divider()
                    LabeledField("Sign-Out URL", settings.signOutUrl, "/logout", KeyboardType.Uri) {
                        settings = settings.copy(signOutUrl = it)
                    }
                    Divider()
                    PlainField(
                        value = settings.extraFields,
                        onValueChange = { settings = settings.copy(extraFields = it) },
                        placeholder = "Extra fields, one name=value per line",
                        singleLine = false,
                        monospace = true,
                    )
                }
                Divider()
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    TextButton(
                        enabled = !detecting,
                        onClick = {
                            detecting = true
                            scope.launch {
                                detectMessage = try {
                                    val wifi = PortalLogin.wifiNetwork(context) ?: throw LoginError.NotOnWiFi
                                    val form = PortalLogin(wifi).detectForm()
                                    if (form == null) {
                                        "You're already online, so there's no login page to detect. Try again right after joining the school Wi-Fi."
                                    } else {
                                        // Save a path rather than this building's address, so it also works in other blocks.
                                        val url = form.action
                                        val loginUrl = if (url.host == form.pageUrl.host) {
                                            url.path.ifEmpty { "/" } + (url.query?.let { "?$it" } ?: "")
                                        } else {
                                            url.toString()
                                        }
                                        settings = settings.copy(
                                            loginUrl = loginUrl,
                                            method = form.method,
                                            usernameField = form.usernameField ?: settings.usernameField,
                                            passwordField = form.passwordField ?: settings.passwordField,
                                        )
                                        if (settings.useCustomPortal) {
                                            "Found the login page at ${url.host}. The details above have been updated."
                                        } else {
                                            "Found the login page at ${url.host}. Automatic sign-in works here and in other buildings, so there's nothing to set up."
                                        }
                                    }
                                } catch (e: LoginError) {
                                    e.message
                                }
                                detecting = false
                            }
                        },
                        modifier = Modifier.padding(horizontal = 4.dp),
                    ) { Text("Detect Login Page") }
                    Spacer(Modifier.weight(1f))
                    if (detecting) {
                        CircularProgressIndicator(
                            strokeWidth = 2.dp,
                            modifier = Modifier
                                .padding(end = 16.dp)
                                .size(18.dp),
                        )
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

/** A grouped, rounded section like iOS Settings. */
@Composable
internal fun Section(
    header: String,
    footer: String?,
    card: Boolean = true,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(Modifier.padding(top = 20.dp)) {
        Text(
            header.uppercase(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 16.dp, bottom = 6.dp),
        )
        if (card) {
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(verticalArrangement = Arrangement.Center, content = content)
            }
        } else {
            Column(content = content)
        }
        if (footer != null) {
            Text(
                footer,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 6.dp),
            )
        }
    }
}

@Composable
internal fun Divider() {
    HorizontalDivider(Modifier.padding(start = 16.dp), color = MaterialTheme.colorScheme.outlineVariant)
}

@Composable
private fun SwitchRow(title: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(start = 16.dp, end = 12.dp, top = 6.dp, bottom = 6.dp),
    ) {
        Text(title, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun LabeledField(
    label: String,
    value: String,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    onValueChange: (String) -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(start = 16.dp)) {
        Text(label)
        PlainField(
            value = value,
            onValueChange = onValueChange,
            placeholder = placeholder,
            keyboardType = keyboardType,
            alignEnd = true,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun PlainField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier.fillMaxWidth(),
    keyboardType: KeyboardType = KeyboardType.Text,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    singleLine: Boolean = true,
    monospace: Boolean = false,
    alignEnd: Boolean = false,
    trailing: (@Composable () -> Unit)? = null,
) {
    val style = MaterialTheme.typography.bodyLarge.let {
        var s = it
        if (monospace) s = s.copy(fontFamily = FontFamily.Monospace)
        if (alignEnd) s = s.copy(textAlign = androidx.compose.ui.text.style.TextAlign.End)
        s
    }
    TextField(
        value = value,
        onValueChange = onValueChange,
        placeholder = {
            Text(
                placeholder,
                style = style,
                modifier = if (alignEnd) Modifier.fillMaxWidth() else Modifier,
            )
        },
        textStyle = style,
        singleLine = singleLine,
        minLines = if (singleLine) 1 else 2,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType, autoCorrectEnabled = false),
        visualTransformation = visualTransformation,
        trailingIcon = trailing,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Color.Transparent,
            unfocusedContainerColor = Color.Transparent,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
        ),
        modifier = modifier,
    )
}
