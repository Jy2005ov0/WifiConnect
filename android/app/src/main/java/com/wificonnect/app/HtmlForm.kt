package com.wificonnect.app

import java.net.URL

data class FormField(val name: String, val value: String)

/** A request that submits a login form. */
data class FormSubmission(val url: URL, val method: String, val fields: List<FormField>)

/** A small, forgiving HTML scanner that finds the login form on a captive portal page. */
data class HtmlForm(
    val action: URL,
    val method: String,
    val inputs: List<Input>,
    /** The page the form was found on. */
    val pageUrl: URL,
) {
    data class Input(val name: String, val type: String, val value: String, val checked: Boolean)

    val passwordField: String?
        get() = inputs.firstOrNull { it.type == "password" }?.name

    val usernameField: String?
        get() {
            val candidates = inputs.filter { it.type in TEXT_TYPES }
            for (hint in USERNAME_HINTS) {
                candidates.firstOrNull { it.name.lowercase().contains(hint) }?.let { return it.name }
            }
            return candidates.firstOrNull()?.name
        }

    /** Fills in the student ID and password, keeping hidden fields the portal expects. */
    fun submission(username: String, password: String): FormSubmission? {
        val passwordName = passwordField ?: return null
        val usernameName = usernameField
        val fields = mutableListOf<FormField>()
        var addedSubmit = false

        for (input in inputs) {
            when (input.type) {
                "password" ->
                    fields += FormField(input.name, if (input.name == passwordName) password else input.value)
                // Usually "I agree to the terms" or "remember me": tick it.
                "checkbox" -> fields += FormField(input.name, input.value.ifEmpty { "on" })
                "radio" -> if (input.checked) fields += FormField(input.name, input.value)
                "submit", "image" -> if (!addedSubmit) {
                    fields += FormField(input.name, input.value)
                    addedSubmit = true
                }
                "button", "reset", "file" -> Unit
                else -> fields += FormField(input.name, if (input.name == usernameName) username else input.value)
            }
        }
        return FormSubmission(action, method, fields)
    }

    companion object {
        private val TEXT_TYPES = setOf("text", "email", "tel", "number", "")
        private val USERNAME_HINTS =
            listOf("user", "login", "account", "student", "matric", "uid", "email", "id", "name")

        private val OPTIONS = setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)
        private val FORM = Regex("""<form\b([^>]*)>(.*?)</form\s*>""", OPTIONS)
        private val INPUT = Regex("""<input\b([^>]*)>""", OPTIONS)
        private val META = Regex("""<meta\b([^>]*)>""", OPTIONS)
        private val META_URL = Regex("""url\s*=\s*['"]?([^'"]+)""", OPTIONS)
        private val JS_REDIRECTS = listOf(
            Regex("""location\.replace\(\s*['"]([^'"]+)['"]""", OPTIONS),
            Regex("""location(?:\.href)?\s*=\s*['"]([^'"]+)['"]""", OPTIONS),
        )
        private val ATTRIBUTE =
            Regex("""([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?""", OPTIONS)
        private val COMMENT = Regex("""<!--.*?-->""", RegexOption.DOT_MATCHES_ALL)
        private val NUMERIC_ENTITY = Regex("""&#(x?)([0-9a-fA-F]+);""", RegexOption.IGNORE_CASE)
        private val NAMED_ENTITIES = listOf(
            "&quot;" to "\"", "&apos;" to "'", "&lt;" to "<", "&gt;" to ">", "&nbsp;" to " ", "&amp;" to "&",
        )

        /** The first form on the page that has a password box. */
        fun loginForm(html: String, baseUrl: URL): HtmlForm? {
            val clean = COMMENT.replace(html, "")
            for (match in FORM.findAll(clean)) {
                val attrs = attributes(match.groupValues[1])
                val inputs = parseInputs(match.groupValues[2])
                if (inputs.none { it.type == "password" }) continue

                val actionString = attrs["action"]?.let(::decodeEntities)?.trim().orEmpty()
                val action = if (actionString.isEmpty()) baseUrl else resolve(baseUrl, actionString) ?: baseUrl
                val method = if (attrs["method"].equals("post", ignoreCase = true)) "POST" else "GET"
                return HtmlForm(action, method, inputs, baseUrl)
            }
            return null
        }

        /** Follows `<meta http-equiv="refresh">` and simple JavaScript redirects that portals use. */
        fun clientRedirect(html: String, baseUrl: URL): URL? {
            val clean = COMMENT.replace(html, "")
            var target: String? = null

            for (match in META.findAll(clean)) {
                val attrs = attributes(match.groupValues[1])
                val content = attrs["content"] ?: continue
                if (!attrs["http-equiv"].equals("refresh", ignoreCase = true)) continue
                META_URL.find(decodeEntities(content))?.let {
                    target = it.groupValues[1]
                }
                if (target != null) break
            }

            if (target == null) {
                target = JS_REDIRECTS.firstNotNullOfOrNull { it.find(clean)?.groupValues?.get(1) }
            }

            val trimmed = target?.trim().orEmpty()
            return if (trimmed.isEmpty()) null else resolve(baseUrl, trimmed)
        }

        private fun parseInputs(html: String): List<Input> =
            INPUT.findAll(html).mapNotNull { match ->
                val attrs = attributes(match.groupValues[1])
                val name = attrs["name"]?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                Input(
                    name = decodeEntities(name),
                    type = (attrs["type"] ?: "text").lowercase(),
                    value = decodeEntities(attrs["value"].orEmpty()),
                    checked = "checked" in attrs,
                )
            }.toList()

        fun attributes(tagBody: String): Map<String, String> {
            val result = linkedMapOf<String, String>()
            for (match in ATTRIBUTE.findAll(tagBody)) {
                val key = match.groupValues[1].lowercase()
                if (key in result) continue
                result[key] = match.groups[2]?.value ?: match.groups[3]?.value ?: match.groups[4]?.value ?: ""
            }
            return result
        }

        fun decodeEntities(s: String): String {
            if ('&' !in s) return s
            var out = NUMERIC_ENTITY.replace(s) { match ->
                val radix = if (match.groupValues[1].isNotEmpty()) 16 else 10
                val code = match.groupValues[2].toIntOrNull(radix)
                if (code != null && Character.isValidCodePoint(code)) String(Character.toChars(code)) else match.value
            }
            for ((entity, char) in NAMED_ENTITIES) out = out.replace(entity, char)
            return out
        }

        fun resolve(base: URL, relative: String): URL? = runCatching { URL(base, relative) }.getOrNull()
    }
}
