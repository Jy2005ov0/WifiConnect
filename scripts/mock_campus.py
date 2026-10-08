#!/usr/bin/env python3
"""A mock campus with several buildings, each with its own login page address and style.

Like UTAR, every block has its own Wi-Fi login page at its own IP address, and the
pages don't all work the same way. Until you sign in, the connectivity checks Apple
and Android use (/hotspot-detect.html and /generate_204, on the probe port) send you
to the login page of the building you're in:

  A  302 redirect, then a JavaScript redirect to the login page. Session cookie,
     one-time token, "I agree" checkbox. POST to an absolute path.
  B  511 Network Authentication Required with a meta refresh. The form posts to an
     absolute http:// URL and has a <select> that must keep its selected option.
  C  The building's gateway redirects to a central login server on another address.
     The form posts to a relative action; the logout link points back at that server.
  D  A GET form with a relative action and a hidden token.
  E  location.replace() to the login page, which has a search form before the login
     form, a required checkbox and a CSRF token; the action is "./j_security_check".

Walking into another building logs you out of the Wi-Fi, as on campus. After signing
in, each building's page has a link that signs you out again.

Addresses: each building listens on its own port (probe port + 1 to + 5, the central
login server on + 9). The address each one is reached at can be set with
CAMPUS_HOSTS, e.g. "A=127.0.0.2,B=127.0.0.3,AUTH=127.0.0.7"; the default is 127.0.0.1.

Test endpoints on the probe port: GET /status (JSON), POST /reset, POST /move?to=C.

Usage: mock_campus.py [probe port, default 9000]   (student ID 2201234, password utar-test)
"""
import html
import json
import os
import secrets
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, quote, urlparse

STUDENT_ID = "2201234"
PASSWORD = "utar-test"
BUILDINGS = ["A", "B", "C", "D", "E"]

PORTS = {}
HOSTS = {}
state = {}
lock = threading.Lock()


def reset():
    state.clear()
    state.update(authorized=False, building="A", attempts=[], signed_out=0, tokens={}, sessions={})


def base(name):
    return f"http://{HOSTS[name]}:{PORTS[name]}"


class Campus(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("mock-campus[%s]: %s %s\n" % (self.server.name, self.command, self.path))

    # ---- helpers ----

    def send(self, status, body=b"", content_type="text/html", headers=None):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def redirect(self, location, status=302):
        self.send(status, headers={"Location": location})

    def cookies(self):
        jar = {}
        for part in self.headers.get("Cookie", "").split(";"):
            if "=" in part:
                key, value = part.strip().split("=", 1)
                jar[key] = value
        return jar

    def query(self):
        return {k: v[0] for k, v in parse_qs(urlparse(self.path).query).items()}

    def body_form(self):
        length = int(self.headers.get("Content-Length", 0))
        return {k: v[0] for k, v in parse_qs(self.rfile.read(length).decode()).items()}

    def new_session(self, name):
        token = secrets.token_hex(8)
        session = secrets.token_hex(8)
        state["tokens"][name] = token
        state["sessions"][name] = session
        return token, session

    def check(self, name, form, user_key, pass_key, cookie, extra=None):
        """Records the attempt and returns the problems, if any."""
        problems = []
        if cookie and self.cookies().get(cookie) != state["sessions"].get(name):
            problems.append("missing session cookie")
        for key, expected in (extra or {}).items():
            if form.get(key) != expected:
                problems.append(f"{key} should be {expected!r}, got {form.get(key)!r}")
        if form.get(user_key) != STUDENT_ID or form.get(pass_key) != PASSWORD:
            problems.append("wrong student ID or password")
        if state["building"] != name and name != "AUTH":
            problems.append(f"signed in at building {name} while in building {state['building']}")
        state["attempts"].append({
            "building": state["building"], "server": name, "fields": sorted(form), "problems": problems,
        })
        if not problems:
            state["authorized"] = True
        return problems

    def sign_out(self):
        state["authorized"] = False
        state["signed_out"] += 1
        return self.send(200, "<html><body><p>You have been signed out of utarwifi.</p></body></html>")

    def failed(self, problems):
        return self.send(200, "<html><body><p>Login failed: %s</p></body></html>" % html.escape("; ".join(problems)))

    # ---- requests ----

    def do_GET(self):
        with lock:
            return getattr(self, "get_" + self.server.name)(urlparse(self.path).path)

    def do_POST(self):
        with lock:
            return getattr(self, "post_" + self.server.name)(urlparse(self.path).path)

    # The connectivity checks, and the endpoints the tests use.
    def get_PROBE(self, path):
        if path in ("/hotspot-detect.html", "/generate_204"):
            if state["authorized"]:
                if path == "/generate_204":
                    return self.send(204)
                return self.send(200, "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>")
            building = state["building"]
            target = base(building)
            if building == "A":
                return self.redirect(f"{target}/portal?ssid=utarwifi")
            if building == "B":
                page = f'<html><head><meta http-equiv="refresh" content="0; url={target}/auth/login.php?mac=02:00:00:00:00:01"></head>' \
                       "<body>Network authentication required.</body></html>"
                return self.send(511, page)
            if building == "C":
                return self.redirect(f"{target}/?orig=" + quote("http://captive.apple.com/hotspot-detect.html", safe=""))
            if building == "D":
                return self.redirect(f"{target}/index.php?redir=" + quote("http://www.utar.edu.my/", safe=""), 307)
            if building == "E":
                return self.send(200, "<html><head><script type=\"text/javascript\">\n"
                                      f"  location.replace('{target}/hotspot/login.html?dst=http%3A%2F%2Fwww.utar.edu.my');\n"
                                      "</script></head><body>Redirecting...</body></html>")
        if path == "/status":
            visible = {k: v for k, v in state.items() if k not in ("tokens", "sessions")}
            return self.send(200, json.dumps(visible), "application/json")
        return self.send(404, "not found")

    def post_PROBE(self, path):
        if path == "/reset":
            reset()
            return self.send(200, "ok", "text/plain")
        if path == "/move":
            to = self.query().get("to", "A")
            if to not in BUILDINGS:
                return self.send(400, "unknown building", "text/plain")
            # A new building's access point: you have to sign in again.
            state.update(building=to, authorized=False)
            return self.send(200, "ok", "text/plain")
        return self.send(404, "not found")

    # Building A: JS redirect, cookie, token, checkbox, absolute-path action.
    def get_A(self, path):
        if path == "/portal":
            return self.send(200, '<html><body><p>Redirecting...</p>'
                                  '<script>window.location.href = "/login.html?ssid=utarwifi";</script></body></html>')
        if path == "/login.html":
            token, session = self.new_session("A")
            return self.send(200, f"""<html><head><title>UTAR WiFi - Block A</title></head><body>
                <form name="login" action="/cgi-bin/login" method="post">
                  <input type="hidden" name="token" value="{token}">
                  <label>Student ID <input type="text" name="username"></label>
                  <label>Password <input type="password" name="password"></label>
                  <label><input type="checkbox" name="agree" value="yes"> I agree to the terms of use</label>
                  <input type="submit" value="Log In">
                </form></body></html>""", headers={"Set-Cookie": f"SESSION_A={session}; Path=/"})
        if path == "/success":
            return self.send(200, '<html><body><h1>Block A: you are online</h1><a href="/logout">Log out</a></body></html>')
        if path == "/logout":
            return self.sign_out()
        return self.send(404, "not found")

    def post_A(self, path):
        if path == "/cgi-bin/login":
            form = self.body_form()
            problems = self.check("A", form, "username", "password", "SESSION_A",
                                  {"token": state["tokens"].get("A"), "agree": "yes"})
            return self.failed(problems) if problems else self.redirect("/success")
        return self.send(404, "not found")

    # Building B: 511 + meta refresh, absolute http:// action, <select>.
    def get_B(self, path):
        if path == "/auth/login.php":
            mac = html.escape(self.query().get("mac", ""))
            return self.send(200, f"""<html><head><title>UTAR WiFi - Block B</title></head><body>
                <form method="POST" action="{base('B')}/auth/check.php">
                  <input type="hidden" name="mac" value="{mac}">
                  <input type="text" name="user_id" placeholder="Student ID">
                  <input type="password" name="user_pwd" placeholder="Password">
                  <select name="domain">
                    <option value="staff">Staff</option>
                    <option value="student" selected>Student</option>
                  </select>
                  <button type="submit">Sign in</button>
                </form></body></html>""")
        if path == "/auth/logout.php":
            return self.sign_out()
        return self.send(404, "not found")

    def post_B(self, path):
        if path == "/auth/check.php":
            form = self.body_form()
            problems = self.check("B", form, "user_id", "user_pwd", None,
                                  {"mac": "02:00:00:00:00:01", "domain": "student"})
            if problems:
                return self.failed(problems)
            return self.send(200, '<html><body><p>Block B: signed in.</p><a href="/auth/logout.php">Sign out</a></body></html>')
        return self.send(404, "not found")

    # Building C: the gateway sends you to a central login server on another address.
    def get_C(self, path):
        if path == "/":
            return self.redirect(f"{base('AUTH')}/login?ap=C&url=" + quote("http://www.utar.edu.my/", safe=""))
        if path == "/welcome":
            return self.send(200, f'<html><body><p>Block C: welcome.</p><a href="{base("AUTH")}/logout?ap=C">Logout</a></body></html>')
        return self.send(404, "not found")

    def get_AUTH(self, path):
        if path == "/login":
            ap = html.escape(self.query().get("ap", ""))
            token, session = self.new_session("AUTH")
            return self.send(200, f"""<html><head><title>UTAR Central Login</title></head><body>
                <form method="post" action="login">
                  <input type="hidden" name="ap" value="{ap}">
                  <input type="hidden" name="nonce" value="{token}">
                  Username <input name="username">
                  Password <input type="password" name="password">
                  <input type="submit" name="submit" value="Login">
                </form></body></html>""", headers={"Set-Cookie": f"AUTHSESSION={session}; Path=/"})
        if path == "/logout":
            return self.sign_out()
        return self.send(404, "not found")

    def post_AUTH(self, path):
        if path == "/login":
            form = self.body_form()
            problems = self.check("AUTH", form, "username", "password", "AUTHSESSION",
                                  {"ap": "C", "nonce": state["tokens"].get("AUTH")})
            if state["building"] != "C":
                problems.append("central login used outside building C")
            if problems:
                return self.failed(problems)
            return self.redirect(f"{base('C')}/welcome?ok=1")
        return self.send(404, "not found")

    # Building D: GET form, relative action, hidden token.
    def get_D(self, path):
        if path == "/index.php":
            token, _ = self.new_session("D")
            return self.send(200, f"""<html><head><title>UTAR WiFi - Block D</title></head><body>
                <form method="get" action="login.php">
                  <input type="hidden" name="magic" value="{token}">
                  <input type="text" name="username">
                  <input type="password" name="password">
                  <input type="submit" value="Continue">
                </form></body></html>""")
        if path == "/login.php":
            problems = self.check("D", self.query(), "username", "password", None, {"magic": state["tokens"].get("D")})
            if problems:
                return self.failed(problems)
            return self.send(200, '<html><body><p>Block D: online.</p><a href="logout.php">Log out</a></body></html>')
        if path == "/logout.php":
            return self.sign_out()
        return self.send(404, "not found")

    # Building E: location.replace, a search form first, required checkbox, CSRF, "./" action.
    def get_E(self, path):
        if path == "/hotspot/login.html":
            token, session = self.new_session("E")
            return self.send(200, f"""<html><head><title>UTAR WiFi - Block E</title></head><body>
                <form action="/search" method="get"><input type="text" name="q"><input type="submit" value="Search"></form>
                <form id="loginForm" action="./j_security_check" method="post">
                  <input type="hidden" name="csrf" value="{token}">
                  <input type="text" name="j_username" autocomplete="username">
                  <input type="password" name="j_password" autocomplete="current-password">
                  <input type="checkbox" name="accept" value="1" required> Accept the acceptable use policy
                  <input type="submit" value="Sign in">
                </form></body></html>""", headers={"Set-Cookie": f"JSESSIONID={session}; Path=/hotspot"})
        if path == "/hotspot/status":
            return self.send(200, '<html><body><p>Block E: connected.</p><a href="/hotspot/logout">Disconnect</a></body></html>')
        if path == "/hotspot/logout":
            return self.sign_out()
        return self.send(404, "not found")

    def post_E(self, path):
        if path == "/hotspot/j_security_check":
            form = self.body_form()
            problems = self.check("E", form, "j_username", "j_password", "JSESSIONID",
                                  {"csrf": state["tokens"].get("E"), "accept": "1"})
            return self.failed(problems) if problems else self.redirect("/hotspot/status")
        return self.send(404, "not found")


def serve(name, port):
    server = ThreadingHTTPServer(("0.0.0.0", port), Campus)
    server.name = name
    threading.Thread(target=server.serve_forever, daemon=True).start()


if __name__ == "__main__":
    probe = int(sys.argv[1]) if len(sys.argv) > 1 else 9000
    PORTS.update({name: probe + 1 + i for i, name in enumerate(BUILDINGS)}, AUTH=probe + 9)
    HOSTS.update({name: "127.0.0.1" for name in PORTS})
    for item in filter(None, os.environ.get("CAMPUS_HOSTS", "").split(",")):
        name, host = item.split("=", 1)
        HOSTS[name.strip()] = host.strip()
    reset()
    for name, port in PORTS.items():
        serve(name, port)
    print("Mock campus: probe on port %d; %s" % (
        probe, ", ".join(f"{n} at {HOSTS[n]}:{PORTS[n]}" for n in PORTS)), flush=True)
    server = ThreadingHTTPServer(("0.0.0.0", probe), Campus)
    server.name = "PROBE"
    server.serve_forever()
