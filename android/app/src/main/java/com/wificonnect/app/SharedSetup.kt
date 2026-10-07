package com.wificonnect.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.util.Base64
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import org.json.JSONObject

/** The settings a classmate needs: Wi-Fi name and login page details. Never the student ID or password. */
data class SharedSetup(
    val wifiName: String,
    val useCustomPortal: Boolean,
    val loginUrl: String,
    val method: String,
    val usernameField: String,
    val passwordField: String,
    val extraFields: String,
    val signOutUrl: String,
) {
    /** wificonnect://setup?d=<base64url JSON>, the same format as the iPhone app. */
    fun toUrl(): String {
        val json = JSONObject().apply {
            put("v", 1)
            put("wifiName", wifiName)
            put("useCustomPortal", useCustomPortal)
            put("loginURL", loginUrl)
            put("method", method)
            put("usernameField", usernameField)
            put("passwordField", passwordField)
            put("extraFields", extraFields)
            put("signOutURL", signOutUrl)
        }
        val encoded = Base64.encodeToString(
            json.toString().toByteArray(), Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        return "wificonnect://setup?d=$encoded"
    }

    fun apply(context: Context) {
        PortalSettings.load(context).copy(
            wifiName = wifiName,
            useCustomPortal = useCustomPortal,
            loginUrl = loginUrl,
            method = method,
            usernameField = usernameField,
            passwordField = passwordField,
            extraFields = extraFields,
            signOutUrl = signOutUrl,
        ).save(context)
    }

    fun qrCode(size: Int = 768): Bitmap {
        val hints = mapOf(EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M, EncodeHintType.MARGIN to 1)
        val matrix = QRCodeWriter().encode(toUrl(), BarcodeFormat.QR_CODE, size, size, hints)
        val pixels = IntArray(size * size) { i -> if (matrix[i % size, i / size]) Color.BLACK else Color.WHITE }
        return Bitmap.createBitmap(pixels, size, size, Bitmap.Config.ARGB_8888)
    }

    companion object {
        fun current(context: Context): SharedSetup {
            val s = PortalSettings.load(context)
            return SharedSetup(
                s.wifiName, s.useCustomPortal, s.loginUrl, s.method,
                s.usernameField, s.passwordField, s.extraFields, s.signOutUrl,
            )
        }

        fun fromUrl(text: String?): SharedSetup? {
            val uri = text?.trim()?.let { runCatching { Uri.parse(it) }.getOrNull() } ?: return null
            if (uri.scheme != "wificonnect" || uri.host != "setup") return null
            val encoded = uri.getQueryParameter("d") ?: return null
            return runCatching {
                val json = JSONObject(String(Base64.decode(encoded, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)))
                SharedSetup(
                    wifiName = json.optString("wifiName", PortalSettings.DEFAULT_WIFI_NAME),
                    useCustomPortal = json.optBoolean("useCustomPortal"),
                    loginUrl = json.optString("loginURL"),
                    method = json.optString("method", "POST"),
                    usernameField = json.optString("usernameField", "username"),
                    passwordField = json.optString("passwordField", "password"),
                    extraFields = json.optString("extraFields"),
                    signOutUrl = json.optString("signOutURL"),
                )
            }.getOrNull()
        }
    }
}
