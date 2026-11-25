#!/usr/bin/env python3
"""Installs the plugin from a checkout into a clean CODEX_HOME and asserts that Codex lists Alynki's
sessionStart and subagentStart hooks (alynki/alynki#3682). A manifest check cannot see what Codex loads:
0.33.0 passed one and Codex loaded no hooks (alynki/alynki#3668). Usage: check-codex-hooks.py [checkout]
Needs the codex CLI on PATH; signs in to nothing and calls no server."""
import json
import os
import re
import subprocess
import sys
import tempfile


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as cwd:
    env = dict(os.environ, CODEX_HOME=home)

    def codex(*args):
        r = subprocess.run(["codex", *args], env=env, capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            fail("codex %s exited %d: %s" % (" ".join(args), r.returncode, (r.stderr or r.stdout).strip()))
        return r.stdout

    added = codex("plugin", "marketplace", "add", root)
    m = re.search(r"Added marketplace `([^`]+)`", added)
    if not m:
        fail("codex named no marketplace for %s: %s" % (root, added.strip()))
    codex("plugin", "add", "alynki@" + m.group(1))

    srv = subprocess.Popen(["codex", "app-server"], env=env, cwd=cwd, stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

    def send(msg):
        srv.stdin.write(json.dumps(msg) + "\n")
        srv.stdin.flush()

    def reply(want):
        for line in srv.stdout:
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if msg.get("id") == want:
                return msg
        fail("codex app-server closed before answering request %d" % want)

    try:
        send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"clientInfo": {"name": "check-codex-hooks", "version": "0"}}})
        reply(1)
        send({"jsonrpc": "2.0", "method": "initialized"})
        send({"jsonrpc": "2.0", "id": 2, "method": "hooks/list", "params": {}})
        listed = reply(2)
    finally:
        srv.stdin.close()
        srv.kill()
        srv.wait()

    if "result" not in listed:
        fail("hooks/list failed: %s" % json.dumps(listed))
    hooks, problems = [], []
    for entry in listed["result"].get("data", []):
        hooks += [h for h in entry.get("hooks", []) if h.get("pluginId", "").startswith("alynki@")]
        problems += entry.get("warnings", []) + entry.get("errors", [])
    events = sorted(h.get("eventName") for h in hooks)
    print("Codex %s lists for the alynki plugin: %s" % (subprocess.run(["codex", "--version"], capture_output=True, text=True).stdout.strip(), events or "no hooks"))
    if problems:
        fail("hooks/list reported warnings or errors: %s" % json.dumps(problems))
    if events != ["sessionStart", "subagentStart"]:
        fail("expected exactly sessionStart and subagentStart from the alynki plugin")
    for h in hooks:
        if "session-start.sh codex " not in h.get("command", ""):
            fail("%s does not run session-start.sh codex: %s" % (h["eventName"], h.get("command")))
    print("PASS: a clean Codex home lists sessionStart and subagentStart from the alynki plugin")
