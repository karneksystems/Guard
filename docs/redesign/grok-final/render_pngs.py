#!/usr/bin/env python3
"""Render HTML boards → PNG via headless Chrome."""
import json, subprocess, time, sys
from pathlib import Path

MANIFEST = Path("/workspace/elite-redesign/final/html/manifest.json")
ROOT = Path("/workspace/elite-redesign/final")
PORT = 8765

# Key screens for this pass; pass --all for everything
KEY = {
    "phone/today", "phone/today-light", "phone/tomorrows-news", "phone/tomorrows-news-light",
    "phone/home-busy-dark", "phone/home-busy-light", "phone/home-clear-dark", "phone/home-clear-light",
    "phone/gate-amber", "phone/gate-red", "phone/gate-hard-block", "phone/edge-glow-detail",
    "phone/setup-1", "phone/setup-2", "phone/setup-3",
    "phone/notif-60", "phone/notif-15", "phone/notif-5", "phone/notif-1",
    "phone/notif-open", "phone/notif-clear", "phone/notif-tomorrow",
    "phone/log", "phone/paywall", "phone/settings",
    "phone/lock-sky-hour", "phone/lock-amber-5min", "phone/lock-red-open", "phone/lock-sky-clear",
    "phone/di-compact", "phone/di-expanded", "phone/shield-mock", "phone/android-fsi",
    "tablet/home", "desktop/home",
    "composites/home-quiet", "composites/home-island-soon", "composites/home-island-on",
    "composites/lock-hour", "composites/lock-soon", "composites/lock-on", "composites/lock-clear",
    "composites/lock-banner-60", "composites/unlocked-banner-open", "composites/overlay-mt5",
}

def main():
    do_all = "--all" in sys.argv
    items = json.loads(MANIFEST.read_text())
    if not do_all:
        items = [m for m in items if m["key"] in KEY]
    # start server
    srv = subprocess.Popen(
        ["python3", "-m", "http.server", str(PORT), "--bind", "127.0.0.1"],
        cwd=str(ROOT), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    time.sleep(0.4)
    try:
        for m in items:
            rel = Path(m["html"]).relative_to(ROOT).as_posix()
            url = f"http://127.0.0.1:{PORT}/{rel}"
            out = m["png"]
            Path(out).parent.mkdir(parents=True, exist_ok=True)
            cmd = [
                "google-chrome", "--headless=new", "--disable-gpu",
                "--hide-scrollbars", "--force-device-scale-factor=1",
                "--default-background-color=000000",
                f"--window-size={m['w']},{m['h']}",
                f"--screenshot={out}",
                url,
            ]
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            ok = Path(out).exists() and Path(out).stat().st_size > 1000
            print(f"{'OK' if ok else 'FAIL'} {m['key']} ({Path(out).stat().st_size if Path(out).exists() else 0}b)")
            if not ok:
                print(r.stderr[-400:] if r.stderr else "no stderr")
    finally:
        srv.terminate()
        srv.wait(timeout=5)

if __name__ == "__main__":
    main()
