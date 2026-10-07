package com.wificonnect.app

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch

sealed interface ConnectionState {
    object Idle : ConnectionState
    object Working : ConnectionState
    data class Connected(val message: String) : ConnectionState
    data class Failed(val message: String) : ConnectionState
}

class ConnectionViewModel(application: Application) : AndroidViewModel(application) {
    var state by mutableStateOf<ConnectionState>(ConnectionState.Idle)

    /** @param automatic When the app signs in on its own (e.g. on launch), stay quiet if there's no Wi-Fi. */
    fun connect(automatic: Boolean = false) {
        if (state == ConnectionState.Working) return
        state = ConnectionState.Working
        viewModelScope.launch {
            state = try {
                when (PortalLogin.logIn(getApplication())) {
                    LoginOutcome.ALREADY_ONLINE -> ConnectionState.Connected("You're already online.")
                    LoginOutcome.LOGGED_IN -> ConnectionState.Connected("You're signed in and ready to go.")
                }
            } catch (e: LoginError.NotOnWiFi) {
                if (automatic) ConnectionState.Idle else ConnectionState.Failed(e.message.orEmpty())
            } catch (e: LoginError) {
                ConnectionState.Failed(e.message.orEmpty())
            }
        }
    }
}
