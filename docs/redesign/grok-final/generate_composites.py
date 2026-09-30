#!/usr/bin/env python3
"""Guard springboard / lock composites — full-phone OS context."""
from pathlib import Path
import json

ROOT = Path("/workspace/elite-redesign/final")
HTML_DIR = ROOT / "html" / "composites"
PNG_DIR = ROOT / "composites"
HTML_DIR.mkdir(parents=True, exist_ok=True)
PNG_DIR.mkdir(parents=True, exist_ok=True)

ICON = "../../icon/icon-1024.png"
CSS = f"""<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Poppins:wght@500;600;700&display=swap" rel="stylesheet"/>
<link rel="stylesheet" href="../../shared/guard.css"/>
<link rel="stylesheet" href="../../shared/premium.css"/>
<link rel="stylesheet" href="../../shared/composites.css"/>"""

def wrap(title, body, w=428, h=926):
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><title>{title}</title>
{CSS}
<style>html,body{{margin:0;padding:0;background:#000;width:{w}px;height:{h}px;overflow:hidden}}</style>
</head><body>
<div class="capture" style="width:{w}px;height:{h}px">{body}</div>
</body></html>"""

def mini_ring(color, off, track):
    return f'''<svg viewBox="0 0 56 56" width="52" height="52" style="transform:rotate(-90deg)">
      <circle cx="28" cy="28" r="22" fill="none" stroke="{track}" stroke-width="4"/>
      <circle cx="28" cy="28" r="22" fill="none" stroke="{color}" stroke-width="4"
        stroke-linecap="round" stroke-dasharray="138" stroke-dashoffset="{off}"/></svg>'''

def sbar(t="08:51"):
    return f'''<div class="comp-sbar"><span>{t}</span><div class="right"><span>●●●</span><span>5G</span><span>🔋</span></div></div>'''

def apps_grid(include_guard=True):
    items = [
        ("guard", None, "Guard"),
        ("mt5", "MT5", "MT5"),
        ("mail", "✉", "Mail"),
        ("cal", "1", "Calendar"),
        ("notes", "✎", "Notes"),
        ("photos", "▣", "Photos"),
        ("safari", "◎", "Safari"),
        ("msg", "💬", "Messages"),
    ]
    parts = []
    for kind, glyph, label in items:
        if kind == "guard":
            parts.append(
                f'<div class="comp-app guard"><div class="ico"><img src="{ICON}" alt="Guard"/></div>'
                f'<div class="lbl">{label}</div></div>'
            )
        else:
            parts.append(
                f'<div class="comp-app"><div class="ico {kind}">{glyph}</div><div class="lbl">{label}</div></div>'
            )
    return f'<div class="comp-apps">{"".join(parts)}</div>'

def dock():
    return '''<div class="comp-dock">
  <div class="ico phone">☎</div>
  <div class="ico safari">◎</div>
  <div class="ico msg">💬</div>
  <div class="ico music">♪</div>
</div>'''

def la_board(phase, label, count, sub, detail, color, track, off):
    return f'''<div class="comp-la {phase}">
  <div class="top">
    <div class="app"><img src="{ICON}" alt=""/> Guard</div>
    <div class="phase">{label}</div>
  </div>
  <div class="main">
    <div>{mini_ring(color, off, track)}</div>
    <div>
      <div class="count">{count}</div>
      <div class="sub">{sub}</div>
      <div class="detail">{detail}</div>
    </div>
  </div>
</div>'''

def banner(title, body, time="now", pos="lock-pos"):
    return f'''<div class="comp-banner {pos}">
  <div class="top"><img src="{ICON}" alt=""/><div class="appn">GUARD</div><div class="when">{time}</div></div>
  <div class="title">{title}</div>
  <div class="body">{body}</div>
</div>'''

# --- scenarios ---

def home_quiet():
    return f'''
<div class="comp-phone">
  <div class="comp-wallpaper"></div>
  <div class="comp-island"></div>
  {sbar("09:12")}
  {apps_grid()}
  <div class="comp-home-hint">Quiet day · no Live Activity</div>
  {dock()}
  <div class="comp-chrome"></div>
</div>'''

def home_island(kind="soon"):
    if kind == "soon":
        island = '<div class="comp-island live-soon"><span class="il">SOON</span><span class="ir">04:12</span></div>'
        t, peek = "08:51", banner("Gold cover in 5 min", "EUR CPI. Close or hold. Cover starts at 8:55.", "now", "home-pos")
        # banner peek optional — include subtle
        peek = banner("Gold cover in 5 min", "EUR CPI. Close or hold. Cover starts at 8:55.", "now", "home-pos")
    else:
        island = '<div class="comp-island live-on"><span class="il">ON</span><span class="ir">08:30</span></div>'
        t, peek = "08:56", ""
    return f'''
<div class="comp-phone">
  <div class="comp-wallpaper"></div>
  {island}
  {sbar(t)}
  {peek}
  {apps_grid()}
  {dock()}
  <div class="comp-chrome"></div>
</div>'''

def lock_phase(key):
    configs = {
        "hour": ("sky", "IN 1 HOUR", "59:12", "Gold · EUR CPI · cover at 8:55",
                 "High · Cover 8:55–9:05 · F 2.4%", "#5BC8F5", "rgba(91,200,245,0.18)", 20, "08:00"),
        "soon": ("amber", "OPENS SOON", "04:12", "Gold · EUR CPI · until cover starts",
                 "High · Cover 8:55–9:05 · F 2.4%", "#F5A524", "rgba(245,165,36,0.18)", 38, "08:51"),
        "on": ("red", "COVER ON", "08:30", "Gold · EUR CPI · until 9:05",
               "High · Stay out · look ok", "#E5484D", "rgba(229,72,77,0.18)", 70, "08:56"),
        "clear": ("sky", "ALL CLEAR", "Clear", "You're clear · trade at your pace",
                  "Cover ended · Trade at your own pace", "#5BC8F5", "rgba(91,200,245,0.18)", 0, "09:06"),
    }
    phase, label, count, sub, detail, color, track, off, clock = configs[key]
    return f'''
<div class="comp-phone">
  <div class="comp-wallpaper lock-wp"></div>
  <div class="comp-island"></div>
  {sbar(clock)}
  <div class="comp-lock-clock"><div class="t">{clock}</div><div class="d">Tuesday 1 October</div></div>
  {la_board(phase, label, count, sub, detail, color, track, off)}
  <div class="comp-lock-hint">Swipe up to unlock</div>
  <div class="comp-chrome"></div>
</div>'''

def lock_banner_60():
    return f'''
<div class="comp-phone">
  <div class="comp-wallpaper lock-wp"></div>
  <div class="comp-island"></div>
  {sbar("07:55")}
  <div class="comp-lock-clock"><div class="t">07:55</div><div class="d">Tuesday 1 October</div></div>
  {la_board("sky", "IN 1 HOUR", "59:12", "Gold · EUR CPI · cover at 8:55",
            "High · Cover 8:55–9:05", "#5BC8F5", "rgba(91,200,245,0.18)", 20)}
  {banner("Gold cover in 60 min", "EUR CPI. Stay flat from 8:55 to 9:05.", "now", "lock-pos")}
  <div class="comp-lock-hint">Swipe up to unlock · banner + Live Activity</div>
  <div class="comp-chrome"></div>
</div>'''

def unlocked_banner_open():
    return f'''
<div class="comp-phone">
  <div class="comp-wallpaper"></div>
  <div class="comp-island live-on"><span class="il">ON</span><span class="ir">08:30</span></div>
  {sbar("08:56")}
  {banner("Cover is on · gold", "EUR CPI. Stay out until 9:05.", "now", "home-pos")}
  {apps_grid()}
  {dock()}
  <div class="comp-chrome"></div>
</div>'''

def overlay_mt5():
    return f'''
<div class="comp-phone">
  <div class="comp-mt5">
    <div class="bar"><span>MetaTrader 5</span><span style="color:#5BC8F5">XAUUSD</span></div>
    <div class="chart">
      <svg viewBox="0 0 360 180" preserveAspectRatio="none">
        <polyline fill="none" stroke="#5BC8F5" stroke-width="2.5"
          points="0,120 40,110 80,130 120,90 160,100 200,70 240,85 280,50 320,60 360,40"/>
        <polyline fill="none" stroke="rgba(91,200,245,0.2)" stroke-width="8"
          points="0,120 40,110 80,130 120,90 160,100 200,70 240,85 280,50 320,60 360,40"/>
      </svg>
    </div>
    <div class="rows">
      <div class="row"><span>XAUUSD</span><span class="up">2,348.20</span></div>
      <div class="row"><span>EURUSD</span><span class="up">1.0842</span></div>
      <div class="row"><span>GBPUSD</span><span style="color:#E5484D;font-weight:600">1.2610</span></div>
    </div>
  </div>
  <div class="comp-island"></div>
  {sbar("08:56")}
  <div class="comp-overlay">
    <div class="comp-shield-card">
      <img class="logo" src="{ICON}" alt="Guard"/>
      <h2>Stay out of your trading app</h2>
      <p>Gold · EUR CPI until 9:05. We never touch your trades.</p>
      <div class="btns">
        <button class="bp">Stay out</button>
        <button class="bs">Hold to look only</button>
      </div>
    </div>
  </div>
  <div class="comp-caption">Cover overlay over trading app · not Springboard · glow only inside Guard UI</div>
  <div class="comp-chrome"></div>
</div>'''

screens = {
    "composites/home-quiet": ("Home quiet", home_quiet()),
    "composites/home-island-soon": ("Home island soon", home_island("soon")),
    "composites/home-island-on": ("Home island on", home_island("on")),
    "composites/lock-hour": ("Lock hour", lock_phase("hour")),
    "composites/lock-soon": ("Lock soon", lock_phase("soon")),
    "composites/lock-on": ("Lock on", lock_phase("on")),
    "composites/lock-clear": ("Lock clear", lock_phase("clear")),
    "composites/lock-banner-60": ("Lock banner 60", lock_banner_60()),
    "composites/unlocked-banner-open": ("Unlocked banner open", unlocked_banner_open()),
    "composites/overlay-mt5": ("Overlay MT5", overlay_mt5()),
}

manifest_extra = []
for key, (title, body) in screens.items():
    name = key.split("/", 1)[1]
    html_path = HTML_DIR / f"{name}.html"
    png_path = PNG_DIR / f"{name}.png"
    html = wrap(title, body)
    html_path.write_text(html, encoding="utf-8")
    manifest_extra.append({
        "html": str(html_path),
        "png": str(png_path),
        "w": 428, "h": 926, "key": key,
    })
    print(f"wrote {html_path.name}")

# merge into main manifest
main_manifest_path = ROOT / "html" / "manifest.json"
main = json.loads(main_manifest_path.read_text()) if main_manifest_path.exists() else []
# drop old composites keys
main = [m for m in main if not m["key"].startswith("composites/")]
main.extend(manifest_extra)
main_manifest_path.write_text(json.dumps(main, indent=2), encoding="utf-8")
print(f"manifest now {len(main)} items ({len(manifest_extra)} composites)")
