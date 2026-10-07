#!/usr/bin/env python3
"""A mock campus Wi-Fi login page (captive portal) for end-to-end testing.

Behaves like a typical portal:
  * Until you sign in, the connectivity checks Apple and Android use
    (/hotspot-detect.html and /generate_204) redirect to the portal.
  * The portal bounces through a JavaScript redirect to the login page.
  * The login page sets a session cookie and has a hidden one-time token,
    an "I agree" checkbox, and student ID / password fields.
  * A correct sign-in unlocks the connectivity checks.

Like a real campus, each building has its own login page address: building A's
portal is on [port], building B's on [port + 1]. POST /move?to=B makes the
connectivity checks send you to building B instead.

Endpoints for the test itself: GET /status (JSON), POST /reset and POST /move.

Usage: mock_portal.py [port]   (student ID 2201234, password utar-test)
"""
import json
import secrets
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

STUDENT_ID = "2201234"
PASSWORD = "utar-test"

state = {"authorized": False, "attempts": [], "token": None, "session": None, "building": "A"}
PORTS = {}


class Portal(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("mock-portal: %s %s\n" % (self.command, self.path))

    def send(self, status, body=b"", content_type="text/html", headers=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def cookies(self):
        jar = {}
        for part in self.headers.get("Cookie", "").split(";"):
            if "=" in part:
                key, value = part.strip().split("=", 1)
                jar[key] = value
        return jar

    def do_GET(self):
        path = urlparse(self.path).path

        if path in ("/hotspot-detect.html", "/generate_204"):
            if state["authorized"]:
                if path == "/generate_204":
                    return self.send(204)
                return self.send(200, b"<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>")
            # Send you to the login page of the building you're in, by its own address.
            host = self.headers.get("Host", "127.0.0.1").rsplit(":", 1)[0]
            port = PORTS[state["building"]]
            return self.send(302, headers={"Location": f"http://{host}:{port}/portal?ssid=utarwifi"})

        if path == "/portal":
            return self.send(200, b"""<html><head><title>utarwifi</title></head><body>
                <p>Redirecting to the login page...</p>
                <script>window.location.href = "/login.html?ssid=utarwifi";</script>
                </body></html>""")

        if path == "/login.html":
            state["token"] = secrets.token_hex(8)
            state["session"] = secrets.token_hex(8)
            page = f"""<html><head><title>UTAR WiFi Login</title></head><body>
                <!-- <form><input type="password" name="old_password"></form> -->
                <h1>utarwifi</h1>
                <form name="login" action="/cgi-bin/login" method="post">
                  <input type="hidden" name="token" value="{state['token']}">
                  <input type="hidden" name="redirect_url" value="http://www.utar.edu.my/?a=1&amp;b=2">
                  <label>Student ID <input type="text" name="username"></label>
                  <label>Password <input type="password" name="password"></label>
                  <label><input type="checkbox" name="agree" value="yes"> I agree to the terms of use</label>
                  <input type="submit" name="login" value="Log In">
                </form></body></html>"""
            return self.send(200, page.encode(), headers={"Set-Cookie": f"PORTALSESSION={state['session']}; Path=/"})

        if path == "/status":
            return self.send(200, json.dumps(state).encode(), "application/json")

        return self.send(404, b"not found")

    def do_POST(self):
        path = urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        form = {k: v[0] for k, v in parse_qs(self.rfile.read(length).decode()).items()}

        if path == "/reset":
            state.update(authorized=False, attempts=[], token=None, session=None, building="A")
            return self.send(200, b"ok", "text/plain")

        if path == "/move":
            state["building"] = parse_qs(urlparse(self.path).query).get("to", ["A"])[0]
            return self.send(200, b"ok", "text/plain")

        if path == "/cgi-bin/login":
            problems = []
            if self.cookies().get("PORTALSESSION") != state["session"]:
                problems.append("missing session cookie")
            if form.get("token") != state["token"]:
                problems.append("bad token")
            if form.get("agree") != "yes":
                problems.append("terms not accepted")
            if form.get("username") != STUDENT_ID or form.get("password") != PASSWORD:
                problems.append("wrong student ID or password")

            state["attempts"].append({
                "port": self.server.server_address[1],
                "fields": sorted(form),
                "username": form.get("username"),
                "problems": problems,
            })
            if problems:
                return self.send(200, b"<html><body>Login failed. <a href='/login.html'>Try again</a></body></html>")
            state["authorized"] = True
            return self.send(302, headers={"Location": "/success"})

        return self.send(404, b"not found")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    PORTS.update(A=port, B=port + 1)
    building_b = ThreadingHTTPServer(("0.0.0.0", port + 1), Portal)
    threading.Thread(target=building_b.serve_forever, daemon=True).start()
    print(f"Mock portal: building A on port {port}, building B on port {port + 1}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Portal).serve_forever()
