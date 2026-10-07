package com.wificonnect.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.net.URL

class HtmlFormTest {
    private val base = URL("http://portal.example.edu/login.html?ap=1")

    private val portal = """
        <html><body>
        <!-- <form><input type="password" name="old"></form> -->
        <form id="search" action="/search"><input type="text" name="q"></form>
        <form name="login" action="/cgi-bin/login?x=1&amp;y=2" METHOD='post'>
          <input type="hidden" name="token" value="abc&amp;123">
          <input type=text name="user_id" placeholder="Student ID">
          <input type="password" name="pwd" />
          <input type="checkbox" name="agree">
          <input type="radio" name="lang" value="en" checked>
          <input type="radio" name="lang" value="ms">
          <input type="submit" name="btn" value="Log In">
          <input type="submit" name="cancel" value="Cancel">
        </form>
        </body></html>
    """.trimIndent()

    @Test
    fun findsTheFormWithAPasswordBox() {
        val form = HtmlForm.loginForm(portal, base)
        assertNotNull(form)
        form!!
        assertEquals("http://portal.example.edu/cgi-bin/login?x=1&y=2", form.action.toString())
        assertEquals("POST", form.method)
        assertEquals("user_id", form.usernameField)
        assertEquals("pwd", form.passwordField)
    }

    @Test
    fun fillsCredentialsAndKeepsHiddenFields() {
        val submission = HtmlForm.loginForm(portal, base)!!.submission("2201234", "s3cret")!!
        val fields = submission.fields.associate { it.name to it.value }
        assertEquals(
            mapOf(
                "token" to "abc&123",
                "user_id" to "2201234",
                "pwd" to "s3cret",
                "agree" to "on",
                "lang" to "en",
                "btn" to "Log In",
            ),
            fields,
        )
    }

    @Test
    fun noFormWithoutPasswordBox() {
        assertNull(HtmlForm.loginForm("<form><input name='q'></form>", base))
    }

    @Test
    fun emptyActionPostsBackToThePage() {
        val form = HtmlForm.loginForm("<form method=post><input name=u><input type=password name=p></form>", base)!!
        assertEquals(base.toString(), form.action.toString())
    }

    @Test
    fun followsMetaRefresh() {
        val html = """<meta http-equiv="refresh" content="0; URL='https://login.example.edu/portal?ssid=utarwifi'">"""
        assertEquals("https://login.example.edu/portal?ssid=utarwifi", HtmlForm.clientRedirect(html, base)?.toString())
    }

    @Test
    fun followsJavaScriptRedirect() {
        val html = """<script>window.location.href = "/login.html?token=xyz";</script>"""
        assertEquals("http://portal.example.edu/login.html?token=xyz", HtmlForm.clientRedirect(html, base)?.toString())
    }

    @Test
    fun decodesEntitiesOnce() {
        assertEquals("<&lt;>\"A", HtmlForm.decodeEntities("&lt;&amp;lt;&gt;&quot;&#65;"))
    }
}
