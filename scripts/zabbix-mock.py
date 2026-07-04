#!/usr/bin/env python3
"""Mock d'API Zabbix 7.0 (JSON-RPC) pour le dev d'auspex.

Sert `problem.get` et `trigger.get` sur http://127.0.0.1:<port>/api_jsonrpc.php, sans
serveur Zabbix réel. Les `clock` sont calculés dynamiquement (âges réalistes dans l'UI).

Usage :
    python3 scripts/zabbix-mock.py [port] [scenario]
    port     : défaut 8384
    scenario : ok (défaut) | empty | unauthorized | error
               (aussi lisible via $AUSPEX_MOCK_SCENARIO)

Pointe le plugin sur : http://127.0.0.1:<port>/api_jsonrpc.php (HTTP, pas de TLS).
Zabbix renvoyant tous les scalaires en chaînes, le mock fait pareil — ça exerce la
normalisation de la couche modèle.
"""
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Scénario : (host, trigger, severity, age_seconds, acknowledged, suppressed) par triggerid.
SCENARIO = [
    # eventid, triggerid, host,      trigger,                            sev, age,     ack, supp
    ("e1", "t101", "db01", "Disk space critical (/var 96%)", 5, 240, False, False),
    ("e2", "t102", "web01", "High CPU load (load 12.4)", 4, 720, False, False),
    ("e3", "t103", "web02", "High CPU load (load 9.1)", 4, 720, True, False),
    ("e4", "t104", "app01", "Service nginx down", 3, 3600, False, True),
    ("e5", "t105", "fw01", "Interface eth1 high traffic", 2, 10800, False, False),
    ("e6", "t106", "switch3", "Port flapping detected", 2, 21600, True, False),
    ("e7", "t107", "mail01", "Certificate expires in 7 days", 1, 172800, False, False),
    ("e8", "t108", "sensor7", "Unclassified event", 0, 432000, False, False),
]


def problems(severities):
    now = int(time.time())
    out = []
    for eventid, triggerid, _host, name, sev, age, ack, supp in SCENARIO:
        if severities and sev not in severities:
            continue
        out.append({
            "eventid": eventid,
            "objectid": triggerid,
            "name": name,
            "severity": str(sev),
            "clock": str(now - age),
            "r_eventid": "0",
            "acknowledged": "1" if ack else "0",
            "suppressed": "1" if supp else "0",
        })
    return out


def triggers(triggerids):
    wanted = set(triggerids or [])
    out = []
    for i, (_e, triggerid, host, *_rest) in enumerate(SCENARIO):
        if triggerid in wanted:
            out.append({
                "triggerid": triggerid,
                "hosts": [{"hostid": str(10000 + i), "name": host}],
            })
    return out


def make_handler(scenario):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):  # log compact sur stderr
            sys.stderr.write("zabbix-mock: " + (fmt % args) + "\n")

        def _send(self, obj, code=200):
            body = json.dumps(obj).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length) if length else b"{}"
            try:
                req = json.loads(raw)
            except ValueError:
                self._send({"jsonrpc": "2.0", "error": {"code": -32700, "message": "Parse error."}, "id": None})
                return
            rid = req.get("id", 1)
            method = req.get("method", "")
            params = req.get("params", {}) or {}
            sys.stderr.write("zabbix-mock: <- %s (scenario=%s)\n" % (method, scenario))

            if scenario == "unauthorized":
                self._send({"jsonrpc": "2.0", "error": {"code": -32602, "message": "Not authorised.", "data": "Session terminated, re-login, please."}, "id": rid})
                return
            if scenario == "error":
                self._send({"jsonrpc": "2.0", "error": {"code": -32500, "message": "Application error.", "data": "mock: scenario=error"}, "id": rid})
                return

            if method == "problem.get":
                data = [] if scenario == "empty" else problems(params.get("severities"))
                self._send({"jsonrpc": "2.0", "result": data, "id": rid})
            elif method == "trigger.get":
                self._send({"jsonrpc": "2.0", "result": triggers(params.get("triggerids")), "id": rid})
            else:
                self._send({"jsonrpc": "2.0", "error": {"code": -32601, "message": "Method not found: " + method}, "id": rid})

    return Handler


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8384
    scenario = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("AUSPEX_MOCK_SCENARIO", "ok")
    server = ThreadingHTTPServer(("127.0.0.1", port), make_handler(scenario))
    print("zabbix-mock : http://127.0.0.1:%d/api_jsonrpc.php  (scenario=%s)" % (port, scenario))
    print("  → règle l'URL du plugin sur cette adresse (HTTP). Ctrl-C pour arrêter.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nzabbix-mock : arrêt.")


if __name__ == "__main__":
    main()
