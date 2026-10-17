#!/usr/bin/env python3
"""Local path-routing demonstration for Lab 05."""

import contextlib
import http.server
import threading
import urllib.request


@contextlib.contextmanager
def server(handler):
    instance = http.server.ThreadingHTTPServer(
        ("127.0.0.1", 0), handler
    )
    thread = threading.Thread(
        target=instance.serve_forever, daemon=True
    )
    thread.start()
    try:
        yield f"http://127.0.0.1:{instance.server_port}"
    finally:
        instance.shutdown()
        instance.server_close()
        thread.join()


class QuietHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, status, message):
        body = message.encode()
        self.send_response(status)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def backend(name):
    class Backend(QuietHandler):
        def do_GET(self):
            self.reply(200, name)
    return Backend


def routing():
    with server(backend("backend-A")) as a, \
         server(backend("backend-B")) as b:

        class Router(QuietHandler):
            def do_GET(self):
                target = a if self.path.startswith(
                    "/enrolment"
                ) else b

                with urllib.request.urlopen(
                    target, timeout=3
                ) as response:
                    self.reply(
                        response.status,
                        response.read().decode()
                    )

        with server(Router) as proxy:
            for path, expected in [
                ("/enrolment", "backend-A"),
                ("/results", "backend-B")
            ]:
                with urllib.request.urlopen(
                    proxy + path, timeout=3
                ) as response:
                    actual = response.read().decode()

                assert actual == expected
                print(f"{path} -> {actual} (HTTP 200)")

    print("Routing complete; all three HTTP servers closed.")


if __name__ == "__main__":
    routing()
