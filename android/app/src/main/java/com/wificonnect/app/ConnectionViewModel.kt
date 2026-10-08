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
    /** [signedInByApp]: the app signed you in, rather than you being online already. */
    data class Connected(val message: String, val signedInByApp: Boolean = false) : ConnectionState
    /** [signingOut]: it was signing out that failed, so the screen says "Couldn't Sign Out". */
    data class Failed(val message: String, val signingOut: Boolean = false) : ConnectionState
    object SignedOut : ConnectionState
}

class ConnectionViewModel(application: Application) : AndroidViewModel(application) {
    var state by mutableStateOf<ConnectionState>(ConnectionState.Idle)

    fun signOut() {
        if (state == ConnectionState.Working) return
        val wasSignedInByApp = (state as? ConnectionState.Connected)?.signedInByApp == true
        state = ConnectionState.Working
        viewModelScope.launch {
            state = try {
                PortalLogin.signOut(getApplication())
                ConnectionState.SignedOut
            } catch (e: LoginError) {
                // Already online without the app signing you in (e.g. at home) and no sign-out link is
                // known: there's nothing to sign out of, so just go back to Tap to Connect.
                val nothingToSignOut = !wasSignedInByApp && e is LoginError.NoSignOutLink
                if (nothingToSignOut) ConnectionState.Idle
                else ConnectionState.Failed(e.describe(getApplication()), signingOut = true)
            }
            if (BuildConfig.DEBUG) android.util.Log.i("WifiConnect", "Result: $state")
        }
    }

    /** @param automatic When the app signs in on its own (e.g. on launch), stay quiet if there's no Wi-Fi. */
    fun connect(automatic: Boolean = false) {
        if (state == ConnectionState.Working) return
        state = ConnectionState.Working
        viewModelScope.launch {
            state = try {
                when (PortalLogin.logIn(getApplication(), trigger = if (automatic) SignInTrigger.AUTOMATIC else SignInTrigger.APP)) {
                    LoginOutcome.ALREADY_ONLINE -> ConnectionState.Connected(getApplication<Application>().getString(R.string.result_already_online))
                    LoginOutcome.LOGGED_IN -> ConnectionState.Connected(
                        getApplication<Application>().getString(R.string.result_signed_in),
                        signedInByApp = true,
                    )
                }
            } catch (e: LoginError.OtherNetwork) {
                ConnectionState.Idle
            } catch (e: LoginError.NotSchoolPortal) {
                ConnectionState.Idle
            } catch (e: LoginError.NotOnWiFi) {
                if (automatic) ConnectionState.Idle else ConnectionState.Failed(e.describe(getApplication()))
            } catch (e: LoginError) {
                ConnectionState.Failed(e.describe(getApplication()))
            }
            // The end-to-end test reads this from logcat.
            if (BuildConfig.DEBUG) android.util.Log.i("WifiConnect", "Result: $state")
        }
    }
}
