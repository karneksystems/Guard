#!/usr/bin/env python3
"""Guard final screens · B Precision Field + C glow · overhauled IA/copy."""
from pathlib import Path
import json, re

OUT = Path("/workspace/elite-redesign/final/html")
OUT.mkdir(parents=True, exist_ok=True)
CSS = "../shared/guard.css"
FONTS = """<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Poppins:wght@500;600;700&display=swap" rel="stylesheet"/>"""

def wrap(title, body, w=428, h=926, capture_class="capture"):
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><title>{title}</title>
{FONTS}<link rel="stylesheet" href="{CSS}"/><link rel="stylesheet" href="../shared/premium.css"/>
<style>html,body{{margin:0;padding:0;background:#000;width:{w}px;height:{h}px;overflow:hidden}}</style>
</head><body>
<div class="{capture_class}" style="width:{w}px;height:{h}px">{body}</div>
</body></html>"""

def notch(): return '<div class="notch"></div>'
def sbar(t="08:51", theme="dark"):
    return f'<div class="status-bar {theme}"><span>{t}</span><span>●●● 5G 🔋</span></div>'

NAV_ICONS = {
    "Home": '''<svg class="nav-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 10.5 L12 4 l8 6.5 V20 a1 1 0 0 1 -1 1 h-4.5 V14 h-5 v7 H5 a1 1 0 0 1 -1 -1 z"/></svg>''',
    "Today": '''<svg class="nav-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10 h17 M8 3.5 v3.5 M16 3.5 v3.5"/><circle cx="8.5" cy="14.5" r="1.1" fill="currentColor" stroke="none"/><circle cx="12" cy="14.5" r="1.1" fill="currentColor" stroke="none"/><circle cx="15.5" cy="14.5" r="1.1" fill="currentColor" stroke="none"/></svg>''',
    "Log": '''<svg class="nav-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8 4.5 h9.5 a2 2 0 0 1 2 2 V19.5 a2 2 0 0 1 -2 2 H8 a2 2 0 0 1 -2 -2 V6.5 a2 2 0 0 1 2 -2 z"/><path d="M9.5 9.5 h7 M9.5 13 h7 M9.5 16.5 h4.5"/><path d="M6 7.5 H4.5 a1.5 1.5 0 0 0 0 3 H6 M6 13.5 H4.5 a1.5 1.5 0 0 0 0 3 H6"/></svg>''',
    "Settings": '''<svg class="nav-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M12 3.5 v2.2 M12 18.3 v2.2 M3.5 12 h2.2 M18.3 12 h2.2 M5.8 5.8 l1.55 1.55 M16.65 16.65 l1.55 1.55 M18.2 5.8 l-1.55 1.55 M7.35 16.65 l-1.55 1.55"/></svg>''',
}

def nav(active="Home"):
    parts = []
    for name in ("Home", "Today", "Log", "Settings"):
        cls = "nav-item active" if name == active else "nav-item"
        parts.append(f'<div class="{cls}"><div class="ico">{NAV_ICONS[name]}</div>{name}</div>')
    return f'<div class="nav">{"".join(parts)}</div>'


def impact_bars(level="high"):
    return f'<span class="impact-bars {level}"><span class="bar"></span><span class="bar"></span><span class="bar"></span></span>'

FLAG_MAP = {
    "EUR": "eu", "USD": "us", "GBP": "gb", "JPY": "jp", "CAD": "ca",
    "AUD": "au", "CHF": "ch", "CNY": "cn", "CNH": "cn",
}
# emoji → code fallbacks for any leftover callers
FLAG_EMOJI = {"🇪🇺": "EUR", "🇺🇸": "USD", "🇬🇧": "GBP", "🇯🇵": "JPY", "🇨🇦": "CAD", "🇦🇺": "AUD", "🇨🇭": "CHF", "🇨🇳": "CNY"}

def flag_img(code_or_emoji, code=None):
    """Return <img> for a currency code or legacy emoji flag."""
    if code is None:
        # single-arg: treat as currency code
        ccy = FLAG_EMOJI.get(code_or_emoji, code_or_emoji)
    else:
        ccy = code
    slug = FLAG_MAP.get(ccy, "us")
    return f'<img class="flag-img" src="../shared/flags/{slug}.svg" alt="{ccy}" width="18" height="12"/>'

def ccy_badge(flag, code):
    # flag may be emoji (legacy) or ignored when code is set
    return f'<div class="cal-ccy">{flag_img(flag, code)}<span class="code">{code}</span></div>'

def filter_chips(low=2, mid=3, high=3, selected=("high",)):
    """Multi-select chips. Default selected: High only. Show counts."""
    chips = []
    for key, label, n in (("low", "Low", low), ("mid", "Mid", mid), ("high", "High", high)):
        on = " on" if key in selected else ""
        chips.append(
            f'<div class="filter-chip {key}{on}"><span class="swatch"></span>{label} <span class="count">{n}</span></div>'
        )
    return f'<div class="filter-chips">{"".join(chips)}</div>'

def cal_row(time, flag, code, title, window, level="high", eta=None, eta_cls="later",
           actual="—", forecast=None, previous=None, soon=False):
    """Myfxbook-weight row: flag/ccy, impact bars, cover window, A/F/P micro stats."""
    bars = impact_bars(level)
    eta_html = f'<div class="cal-eta {eta_cls}">{eta}</div>' if eta else ""
    soon_cls = " soon-row" if soon else ""
    stats = ""
    if forecast is not None or previous is not None:
        f = forecast if forecast is not None else "—"
        prev = previous if previous is not None else "—"
        stats = (
            f'<div class="cal-stats">'
            f'<span class="act">A <b>{actual}</b></span>'
            f'<span>F <b>{f}</b></span>'
            f'<span>P <b>{prev}</b></span>'
            f'</div>'
        )
    return (
        f'<div class="cal-row{soon_cls}">'
        f'<div class="cal-time">{time}</div>'
        f'{ccy_badge(flag, code)}'
        f'<div class="cal-main">'
        f'<div class="cal-title">{title}</div>'
        f'<div class="cal-sub">{bars}<span>{window}</span></div>'
        f'{stats}'
        f'</div>'
        f'<div class="cal-meta">'
        f'<div class="cal-impact-label {level}">{level.upper()}</div>'
        f'{eta_html}'
        f'</div>'
        f'</div>'
    )

def ring_svg(color="#F5A524", dash=100, track="rgba(245,165,36,0.12)"):
    return f'''<svg viewBox="0 0 132 132">
      <circle cx="66" cy="66" r="58" fill="none" stroke="{track}" stroke-width="6"/>
      <circle cx="66" cy="66" r="58" fill="none" stroke="{color}" stroke-width="6"
        stroke-linecap="round" stroke-dasharray="364" stroke-dashoffset="{dash}"/></svg>'''

def gate_arc(color="#F5A524", offset=172, track="rgba(245,165,36,0.1)"):
    return f'''<svg viewBox="0 0 240 240">
      <circle cx="120" cy="120" r="100" fill="none" stroke="{track}" stroke-width="8"/>
      <circle cx="120" cy="120" r="100" fill="none" stroke="{color}" stroke-width="8"
        stroke-linecap="round" stroke-dasharray="628" stroke-dashoffset="{offset}"
        transform="rotate(-90 120 120)"/></svg>'''

def mini_ring(color="#F5A524", offset=38, track="rgba(245,165,36,0.15)"):
    return f'''<svg viewBox="0 0 56 56">
      <circle cx="28" cy="28" r="22" fill="none" stroke="{track}" stroke-width="4"/>
      <circle cx="28" cy="28" r="22" fill="none" stroke="{color}" stroke-width="4"
        stroke-linecap="round" stroke-dasharray="138" stroke-dashoffset="{offset}"/></svg>'''

# ===== HOME: one hero fact =====
def home_busy(theme="dark"):
    track = "rgba(245,165,36,0.12)" if theme=="dark" else "rgba(245,165,36,0.15)"
    return f'''
<div class="phone {theme}">
  <div class="glow amber"></div>{notch()}{sbar("08:51", theme)}
  <div class="home {theme}">
    <div class="body">
      <div class="top-row">
        <div class="brand">Guard</div>
        <div class="chip"><span class="dot"></span>Cover is on · gold, EUR</div>
      </div>
      <div class="ring-hero" style="flex-direction:column;align-items:center;text-align:center;gap:14px;padding:24px 16px 22px">
        <div class="phase amber" style="font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase">Opens soon</div>
        <div class="ring-wrap" style="width:168px;height:168px">
          <svg viewBox="0 0 168 168" style="width:168px;height:168px;transform:rotate(-90deg)">
            <circle cx="84" cy="84" r="74" fill="none" stroke="{track}" stroke-width="8"/>
            <circle cx="84" cy="84" r="74" fill="none" stroke="#F5A524" stroke-width="8"
              stroke-linecap="round" stroke-dasharray="465" stroke-dashoffset="128"/>
          </svg>
          <div class="num"><div class="t amber" style="font-size:40px">04:12</div>
          <div class="u">until cover starts</div></div>
        </div>
        <div>
          <div class="sym" style="font-family:Poppins,sans-serif;font-size:26px;font-weight:600">Gold · EUR CPI</div>
          <div class="when" style="margin-top:6px;font-size:14px">Today · 8:55–9:05</div>
        </div>
      </div>
      <div class="peek-row">
        <div class="peek-k">Also today</div>
        <div class="peek-items">
          <span class="peek-item">{impact_bars("high")} BoE Rate <span class="t">10:55</span></span>
        </div>
      </div>
      <div class="metrics">
        <div class="metric"><div class="k">Loss room</div><div class="v">$1,880</div></div>
        <div class="metric"><div class="k">Days</div><div class="v">3 of 4</div></div>
        <div class="metric"><div class="k">Tomorrow</div><div class="v">1</div></div>
      </div>
      <div class="promise">We never touch your trades.</div>
    </div>
    {nav("Home")}
  </div>
</div>'''

def home_clear(theme="dark"):
    return f'''
<div class="phone {theme}">
  {notch()}{sbar("08:51", theme)}
  <div class="home {theme}">
    <div class="body">
      <div class="top-row">
        <div class="brand">Guard</div>
        <div class="chip"><span class="dot clear"></span>Cover is on · gold, EUR</div>
      </div>
      <div class="ring-hero" style="flex-direction:column;align-items:center;text-align:center;gap:14px;padding:36px 16px">
        <div class="phase sky" style="font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:var(--sky)">All clear</div>
        <div class="ring-wrap" style="width:168px;height:168px">
          <svg viewBox="0 0 168 168" style="width:168px;height:168px;transform:rotate(-90deg)">
            <circle cx="84" cy="84" r="74" fill="none" stroke="rgba(91,200,245,0.15)" stroke-width="8"/>
            <circle cx="84" cy="84" r="74" fill="none" stroke="#5BC8F5" stroke-width="8"
              stroke-linecap="round" stroke-dasharray="465" stroke-dashoffset="0"/>
          </svg>
          <div class="num"><div class="t sky" style="font-size:36px">Clear</div>
          <div class="u">nothing today</div></div>
        </div>
        <div style="font-size:15px;opacity:0.65;max-width:280px;line-height:1.4">No high impact news for you today.</div>
      </div>
      <div class="peek-row">
        <div class="peek-k">Next cover</div>
        <div class="peek-items">
          <span class="peek-item">{impact_bars("high")} Crude Inventories <span class="t">Tomorrow · 13:25</span></span>
        </div>
      </div>
      <div class="metrics">
        <div class="metric"><div class="k">Loss room</div><div class="v">$1,880</div></div>
        <div class="metric"><div class="k">Days</div><div class="v">3 of 4</div></div>
        <div class="metric"><div class="k">Tomorrow</div><div class="v">1</div></div>
      </div>
      <div class="promise">We never touch your trades.</div>
    </div>
    {nav("Home")}
  </div>
</div>'''

def gate(phase="amber", block=False, time="08:51"):
    if phase == "amber":
        pcls, kicker, count, until, color, track, offset, mode, glow = (
            "amber-phase","Opens soon","04:12","until cover starts",
            "#F5A524","rgba(245,165,36,0.1)",172,"Cover · look ok","amber")
    else:
        pcls, kicker, count, until, color, track, offset, mode, glow = (
            "red-phase","Cover is on","08:30","until you can trade again",
            "#E5484D","rgba(229,72,77,0.12)",314,"Cover · look ok","red")
        if block:
            kicker, mode = "Block is on", "Block · no look"
    hold = "" if block else '<button class="btn-hold"><span class="hold-ring"></span> Hold to look only</button>'
    promise = ("We never touch your trades. Trading now may break your firm's rules."
               if block else
               "We never touch your trades. Looking is fine. Trading now may break your firm's rules.")
    return f'''
<div class="phone dark">
  <div class="glow {glow}"></div>{notch()}
  <div class="gate {pcls}">
    <div class="gate-frame"><span class="corner-bl"></span><span class="corner-br"></span></div>
    {sbar(time)}
    <div class="body">
      <div class="gate-kicker">{kicker}</div>
      <div class="gate-arc-wrap">{gate_arc(color, offset, track)}
        <div class="gate-arc-num"><div class="t">{count}</div><div class="u">{until}</div></div>
      </div>
      <div class="gate-info">
        <div class="gi"><div class="k">What</div><div class="v">Gold · EUR CPI</div></div>
        <div class="gi"><div class="k">When</div><div class="v sky">Today · 8:55–9:05</div></div>
        <div class="gi"><div class="k">Mode</div><div class="v sky">{mode}</div></div>
        <div class="gi"><div class="k">Impact</div><div class="v" style="color:#E5484D;display:flex;align-items:center;gap:6px">{impact_bars("high")} High</div></div>
      </div>
      <div class="gate-promise">{promise}</div>
      <div class="gate-actions">
        <button class="btn-stay">Stay out</button>{hold}
      </div>
    </div>
  </div>
</div>'''

def lock_activity(phase="amber"):
    configs = {
        "sky_hour": ("sky","IN 1 HOUR","59:12","Gold · EUR CPI · cover at 8:55","#5BC8F5","rgba(91,200,245,0.18)",20,"08:00","High · Cover 8:55–9:05","F 2.4% · P 2.5%"),
        "amber": ("amber","OPENS SOON","04:12","Gold · EUR CPI · until cover starts","#F5A524","rgba(245,165,36,0.18)",38,"08:51","High · Cover 8:55–9:05","F 2.4% · P 2.5%"),
        "red": ("red","COVER ON","08:30","Gold · EUR CPI · until 9:05","#E5484D","rgba(229,72,77,0.18)",70,"08:56","High · Cover 8:55–9:05","Stay out · look ok"),
        "clear": ("sky","ALL CLEAR","Clear","You're clear · trade at your pace","#5BC8F5","rgba(91,200,245,0.18)",0,"09:06","Cover ended","Trade at your own pace"),
    }
    border, label, count, sub, color, track, off, clock, detail, micro = configs[phase]
    return f'''
<div class="phone dark">{notch()}
  <div class="lock">
    <div class="di-pill" aria-hidden="true"></div>
    <div class="lock-time">{clock}</div>
    <div class="lock-date">Tuesday 1 October</div>
    <div class="la {border}">
      <div class="la-row">
        <div class="la-app"><div class="la-ico"><img src="../icon/icon-1024.png" alt="" width="14" height="14"/></div> Guard</div>
        <div class="la-phase {border}">{label}</div>
      </div>
      <div class="la-main">
        <div class="la-mini-ring">{mini_ring(color, off, track)}</div>
        <div class="la-copy">
          <div class="la-count {border}">{count}</div>
          <div class="la-sub">{sub}</div>
          <div class="la-detail">{detail}<span class="la-dot">·</span>{micro}</div>
        </div>
      </div>
    </div>
    <div class="lock-hint">Swipe up to unlock</div>
  </div>
</div>'''

def dynamic_island(mode="compact"):
    ico = '<div class="la-ico"><img src="../icon/icon-1024.png" alt="" width="14" height="14"/></div>'
    if mode == "compact":
        return f'''
<div class="phone dark"><div class="di-stage">
  <div class="di-compact"><span class="l">SOON</span><span class="r">04:12</span></div>
  <div class="di-label">Compact · opens soon · SOON · 04:12</div>
  <div class="di-meta">Gold · EUR CPI · cover at 8:55 · High</div>
  <div class="di-compact red" style="margin-top:28px"><span class="l">ON</span><span class="r">08:30</span></div>
  <div class="di-label">Compact · cover on · ON · 08:30</div>
  <div class="di-meta">Gold · EUR CPI · until 9:05 · High</div>
</div></div>'''
    return f'''
<div class="phone dark"><div class="di-stage">
  <div class="di-expanded">
    <div class="di-exp-top"><div class="la-app">{ico} Guard</div>
      <div class="la-phase amber">OPENS SOON</div></div>
    <div class="di-exp-count">04:12</div>
    <div class="di-exp-sub">Gold · EUR CPI · cover at 8:55</div>
    <div class="di-exp-rail"><span>High</span><span>Cover 8:55–9:05</span><span>F 2.4%</span></div>
  </div>
  <div class="di-label">Expanded · opens soon</div>
  <div class="di-expanded red" style="margin-top:12px">
    <div class="di-exp-top"><div class="la-app">{ico} Guard</div>
      <div class="la-phase red">COVER ON</div></div>
    <div class="di-exp-count">08:30</div>
    <div class="di-exp-sub">Gold · EUR CPI · until 9:05</div>
    <div class="di-exp-rail"><span>High</span><span>Stay out</span><span>Look ok</span></div>
  </div>
  <div class="di-label">Expanded · cover on</div>
</div></div>'''

def shield_mock():
    return '''
<div class="phone dark"><div class="shield">
  <div class="shield-glow"></div>
  <div class="ico-wrap"><img src="../icon/icon-1024.png" alt="Guard" width="40" height="40" style="border-radius:10px"/></div>
  <div class="title">Stay out of your trading app</div>
  <div class="subtitle">Gold · EUR CPI until 9:05. We never touch your trades.</div>
  <div class="shield-meta">
    <div class="sm"><span class="k">What</span><span class="v">Gold · EUR CPI</span></div>
    <div class="sm"><span class="k">When</span><span class="v">Until 9:05</span></div>
    <div class="sm"><span class="k">Impact</span><span class="v high">High</span></div>
  </div>
  <div class="btns">
    <button class="btn-p">Stay out</button>
    <button class="btn-s">Hold to look only</button>
  </div>
</div></div>'''

def shield_doc():
    return '''
<div style="width:900px;height:600px;background:#070D18;color:#EDF2F8;font-family:Inter,sans-serif;padding:40px 48px;display:flex;gap:40px">
  <div style="flex:1">
    <div style="font-family:Poppins,sans-serif;font-size:22px;font-weight:600;margin-bottom:8px">iPhone Screen Time shield</div>
    <div style="font-size:13px;color:#8B9AAE;margin-bottom:24px">Apple's fixed template. Customer words only. Plain English only. No product jargon.</div>
    <table style="width:100%;font-size:13px;border-collapse:collapse">
      <tr style="border-bottom:1px solid #1A2740"><td style="padding:8px 0;color:#8B9AAE">Background</td><td style="padding:8px 0;font-weight:600">#08306B</td></tr>
      <tr style="border-bottom:1px solid #1A2740"><td style="padding:8px 0;color:#8B9AAE">Title</td><td style="padding:8px 0">Stay out of your trading app · #EDF2F8</td></tr>
      <tr style="border-bottom:1px solid #1A2740"><td style="padding:8px 0;color:#8B9AAE">Subtitle</td><td style="padding:8px 0">Gold · EUR CPI until 9:05. We never touch your trades. · #5BC8F5</td></tr>
      <tr style="border-bottom:1px solid #1A2740"><td style="padding:8px 0;color:#8B9AAE">Primary</td><td style="padding:8px 0">Stay out · bg #F5A524 · label #08306B</td></tr>
      <tr style="border-bottom:1px solid #1A2740"><td style="padding:8px 0;color:#8B9AAE">Secondary</td><td style="padding:8px 0">Hold to look only · #5BC8F5. Omit for Block.</td></tr>
    </table>
  </div>
  <div style="width:280px;height:520px;border-radius:32px;overflow:hidden;border:1px solid #1A2740">
    <div style="height:100%;background:#08306B;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:28px 20px;text-align:center;gap:10px">
      <div style="width:56px;height:56px;border-radius:14px;background:linear-gradient(135deg,#08306B,#0B5CAD);border:1px solid rgba(91,200,245,0.35);color:#5BC8F5;font-size:22px;display:flex;align-items:center;justify-content:center">◈</div>
      <div style="font-family:Poppins,sans-serif;font-size:17px;font-weight:600;color:#EDF2F8">Stay out of your trading app</div>
      <div style="font-size:13px;color:#5BC8F5;line-height:1.4">Gold · EUR CPI until 9:05. We never touch your trades.</div>
      <div style="width:100%;margin-top:20px;display:flex;flex-direction:column;gap:8px">
        <div style="height:44px;border-radius:10px;background:#F5A524;color:#08306B;font-weight:600;font-size:14px;display:flex;align-items:center;justify-content:center">Stay out</div>
        <div style="height:44px;border-radius:10px;background:rgba(91,200,245,0.15);color:#5BC8F5;font-weight:500;font-size:13px;display:flex;align-items:center;justify-content:center">Hold to look only</div>
      </div>
    </div>
  </div>
</div>'''

NOTIFS = [
    ("60 min", "Gold cover in 60 min", "EUR CPI. Stay flat from 8:55 to 9:05."),
    ("15 min", "Gold cover in 15 min", "EUR CPI. Be flat by 8:55."),
    ("5 min", "Gold cover in 5 min", "EUR CPI. Close or hold. Cover starts at 8:55."),
    ("1 min", "One minute · gold", "EUR CPI. Hands off until 9:05."),
    ("open", "Cover is on · gold", "EUR CPI. Stay out until 9:05."),
    ("clear", "You're clear · gold", "Cover ended. Trade at your own pace."),
]

def notif_banner(kind, title, body, time="now"):
    return f'''
<div class="phone dark"><div class="notif-stage">
  <div class="notif-kicker">Alert · {kind}</div>
  <div class="notif">
    <div class="notif-top">
      <div class="notif-ico"><img src="../icon/icon-1024.png" alt="" width="18" height="18"/></div>
      <div class="notif-app">GUARD</div>
      <div class="notif-time">{time}</div>
    </div>
    <div class="notif-title">{title}</div>
    <div class="notif-body">{body}</div>
  </div>
  <div class="notif-foot">Local times · Plain English · We never touch your trades.</div>
</div></div>'''

def notif_tomorrow():
    """Night-before push — journey step 2."""
    return notif_banner(
        "tomorrow",
        "Tomorrow: 1 high impact window",
        "Tomorrow's news is ready. Gold · Crude Inventories at 13:25. Cover is on.",
        time="21:30",
    )

def android_fsi():
    return '''
<div class="phone dark"><div class="fsi">
  <div class="fsi-glow"></div>
  <div class="fsi-brand"><img src="../icon/icon-1024.png" alt="" width="28" height="28" style="border-radius:7px"/> Guard</div>
  <div class="phase">Cover is on</div>
  <div class="big">08:30</div>
  <div class="sub">until you can trade again</div>
  <div class="fsi-card">
    <div class="fc"><span class="k">What</span><span class="v">Gold · EUR CPI</span></div>
    <div class="fc"><span class="k">When</span><span class="v">Today · 8:55–9:05</span></div>
    <div class="fc"><span class="k">Impact</span><span class="v high">High</span></div>
  </div>
  <div class="fsi-promise">We never touch your trades.</div>
  <div class="actions">
    <button class="btn-stay" style="background:linear-gradient(180deg,#F06266,#E5484D,#C53A40);color:#fff">Stay out</button>
    <button class="btn-hold"><span class="hold-ring"></span> Hold to look only</button>
  </div>
</div></div>'''

def setup(step=1):
    """Journey step 0: trade what → alerts+apps → you're set."""
    dots = "".join([f'<div class="setup-dot {"on" if i<=step else ""}"></div>' for i in range(1,4)])
    if step == 1:
        content = (
      '<div class="page-title">What do you trade?</div>'
      '<div class="page-sub">Pick what Guard should watch. Free watches two. We cover '
      '<span style="color:#E5484D;font-weight:600">High</span> impact by default.</div>'
      '<div class="choice sel"><div class="ck">✓</div><div><div style="font-weight:600">Gold</div>'
      '<div style="font-size:12px;opacity:0.55;margin-top:2px">High impact that moves gold</div></div></div>'
      '<div class="choice sel"><div class="ck">✓</div><div><div style="font-weight:600">EUR pairs</div>'
      '<div style="font-size:12px;opacity:0.55;margin-top:2px">Euro news · CPI, ECB</div></div></div>'
      '<div class="choice"><div class="ck"></div><div><div style="font-weight:600">US indices</div>'
      '<div style="font-size:12px;opacity:0.55;margin-top:2px">US30, NAS100, US500</div></div></div>'
      '<div class="choice"><div class="ck"></div><div><div style="font-weight:600">GBP pairs</div>'
      '<div style="font-size:12px;opacity:0.55;margin-top:2px">Sterling news · BoE</div></div></div>'
        )
        btn = "Continue"
    elif step == 2:
        content = (
      '<div class="page-title">Alerts and apps</div>'
      '<div class="page-sub">So Guard can warn you and cover MT5 when High news hits.</div>'
      '<div class="card" style="padding:4px 16px">'
      '<div class="row-item"><div><div style="font-weight:600">Notifications</div>'
      '<div style="font-size:11.5px;opacity:0.5;margin-top:2px">60 · 15 · 5 · 1 min ladder</div></div><div class="toggle"></div></div>'
      '<div class="row-item"><div><div style="font-weight:600">Cover trading apps</div>'
      '<div style="font-size:11.5px;opacity:0.5;margin-top:2px">MT5, MT4</div></div><div class="toggle"></div></div>'
      '<div class="row-item"><div><div style="font-weight:600">Alarms on time</div>'
      '<div style="font-size:11.5px;opacity:0.5;margin-top:2px">Cover on the minute</div></div><div class="toggle off"></div></div>'
      '<div class="row-item"><div><div style="font-weight:600">Tomorrow\'s news</div>'
      '<div style="font-size:11.5px;opacity:0.5;margin-top:2px">Night-before High windows</div></div><div class="toggle"></div></div>'
      '</div>'
      '<div class="card" style="padding:12px 14px;border-color:rgba(245,165,36,0.35);'
      'background:linear-gradient(180deg,rgba(245,165,36,0.1),rgba(245,165,36,0.03))">'
      '<div style="font-size:12px;font-weight:700;letter-spacing:0.8px;text-transform:uppercase;color:#F5A524;margin-bottom:4px">'
      'Alarms still off</div>'
      '<div style="font-size:13px;line-height:1.4;opacity:0.8">Turn on Alarms on time or cover may land late.</div>'
      '</div>'
      '<div style="font-size:12.5px;color:#8B9AAE;line-height:1.45;padding:0 4px">We never touch your trades.</div>'
        )
        btn = "Continue"
    else:
        preview = cal_row("08:55", "🇪🇺", "EUR", "EUR CPI", "Cover 8:55–9:05", "high", None, "later",
                          actual="—", forecast="2.4%", previous="2.5%", soon=True)
        content = (
      '<div class="page-title">You\'re set</div>'
      '<div class="page-sub">Cover is on for gold and EUR. First High window today:</div>'
      f'<div class="card" style="padding:0">{preview}</div>'
      '<div class="card" style="padding:14px 16px">'
      '<div style="font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;opacity:0.45;margin-bottom:8px">'
      'What happens next</div>'
      '<div style="font-size:14px;line-height:1.5;opacity:0.8">'
      'We\'ll warn you at 60, 15, 5 and 1 minute, then cover the app when news opens.</div>'
      '<div style="font-size:12.5px;margin-top:12px;opacity:0.4">We never touch your trades.</div>'
      '</div>'
        )
        btn = "Go to Home"
    return (
f'<div class="phone dark">{notch()}{sbar()}'
f'<div class="screen dark"><div class="body" style="padding-top:12px">'
f'<div class="setup-step">{dots}</div>{content}'
f'<div style="margin-top:auto;padding-bottom:8px"><button class="btn-primary">{btn}</button></div>'
f'</div></div></div>'
    )



def today_screen(theme="dark"):
    """Myfxbook-style calendar. Default filter: High only. Premium density."""
    chips = filter_chips(low=2, mid=2, high=2, selected=("high",))
    rows = (
        cal_row("08:55", "🇪🇺", "EUR", "EUR CPI", "Cover 8:55–9:05", "high", "04:12", "soon",
                actual="—", forecast="2.4%", previous="2.5%", soon=True)
        + cal_row("10:55", "🇬🇧", "GBP", "BoE Rate Decision", "Cover 10:55–11:05", "high", "later", "later",
                actual="—", forecast="5.00%", previous="5.00%")
    )
    return f"""
<div class="phone {theme}">{notch()}{sbar("08:51", theme)}
  <div class="screen {theme}">
    <div class="body">
      <div class="page-title">Today</div>
      <div class="page-sub">Tue 1 Oct · local times</div>
      {chips}
      <div class="filter-hint">Showing High · 2 mid &amp; 2 low hidden</div>
      <div class="group-label">Cover windows</div>
      <div class="card" style="padding:0">{rows}
      </div>
      <div class="group-label">Tomorrow · Wed 2 Oct</div>
      <div class="card" style="padding:0">
        {cal_row("13:25", "🇺🇸", "USD", "Crude Inventories", "Cover 13:25–13:35", "high", "1", "cover",
                 actual="—", forecast="−1.2M", previous="−0.8M")}
      </div>
    </div>
    {nav("Today")}
  </div>
</div>"""

def tomorrows_news(theme="dark"):
    """Tomorrow's news · Myfxbook rows + High-default filter. Premium density."""
    chips = filter_chips(low=1, mid=2, high=1, selected=("high",))
    row = cal_row("13:25", "🇺🇸", "USD", "Crude Inventories", "Cover 13:25–13:35", "high",
                  actual="—", forecast="−1.2M", previous="−0.8M")
    return f"""
<div class="phone {theme}">{notch()}{sbar("21:30", theme)}
  <div class="screen {theme}">
    <div class="body">
      <div class="page-title">Tomorrow's news</div>
      <div class="page-sub">Wed 2 Oct · local times</div>
      {chips}
      <div class="filter-hint">Showing High · 2 mid &amp; 1 low hidden</div>
      <div class="group-label">1 high impact window</div>
      <div class="card" style="padding:0">{row}
      </div>
      <div class="card" style="padding:14px 16px">
        <div style="font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;opacity:0.45;margin-bottom:8px">Cover plan</div>
        <div style="font-size:14px;font-weight:500;line-height:1.45;opacity:0.8">Cover is on. We'll warn you at 60, 15, 5 and 1 minute, then cover the trading app when news opens.</div>
      </div>
      <div class="card" style="padding:4px 16px">
        <div class="row-item"><span>Loss room left</span><span class="val">$1,880 of $2,500</span></div>
        <div class="row-item"><span>Trading days</span><span class="val">3 of 4 · 1 to go</span></div>
      </div>
      <div class="promise" style="opacity:0.4">We never touch your trades.</div>
    </div>
    {nav("Home")}
  </div>
</div>"""

def log_screen():
    """Journey step 5: streak reward + outcomes. Impact marks align with Today."""
    return f'''
<div class="phone dark">{notch()}{sbar()}
  <div class="screen dark">
    <div class="body">
      <div class="page-title">Log</div>
      <div class="page-sub">You stayed out. That's the win.</div>
      <div class="streak-banner">
        <div class="streak-num">12</div>
        <div>
          <div style="font-family:Poppins,sans-serif;font-size:16px;font-weight:600">stayed out this month</div>
          <div class="streak-label">Your best month yet · keep the streak</div>
        </div>
      </div>
      <div class="group-label">Today</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item">
          <div>
            <div style="font-weight:600;display:flex;align-items:center;gap:8px">{impact_bars("high")} EUR CPI · Gold</div>
            <div style="font-size:12px;opacity:0.5;margin-top:3px">8:55 · Cover · 10 min</div>
          </div>
          <span style="color:#5BC8F5;font-size:13px;font-weight:700">Stayed out</span>
        </div>
      </div>
      <div class="group-label">Yesterday</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item">
          <div>
            <div style="font-weight:600;display:flex;align-items:center;gap:8px">{impact_bars("high")} FOMC Minutes · Gold</div>
            <div style="font-size:12px;opacity:0.5;margin-top:3px">19:00 · Cover</div>
          </div>
          <span style="color:#5BC8F5;font-size:13px;font-weight:700">Stayed out</span>
        </div>
        <div class="row-item">
          <div>
            <div style="font-weight:600;display:flex;align-items:center;gap:8px">{impact_bars("high")} Core PCE · EUR</div>
            <div style="font-size:12px;opacity:0.5;margin-top:3px">13:30 · Looked 40s</div>
          </div>
          <span style="color:#8B9AAE;font-size:13px;font-weight:700">Looked</span>
        </div>
        <div class="row-item">
          <div>
            <div style="font-weight:600;display:flex;align-items:center;gap:8px">{impact_bars("mid")} Chicago PMI · Gold</div>
            <div style="font-size:12px;opacity:0.5;margin-top:3px">14:45 · Traded in window</div>
          </div>
          <span style="color:#E5484D;font-size:13px;font-weight:700">Traded anyway</span>
        </div>
      </div>
    </div>
    {nav("Log")}
  </div>
</div>'''



def tracker():
    return f'''
<div class="phone dark">{notch()}{sbar()}
  <div class="screen dark">
    <div class="body">
      <div class="page-title">Daily limits</div>
      <div class="page-sub">Loss room and trading days</div>
      <div class="card">
        <div style="font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;opacity:0.45">Loss room</div>
        <div style="font-family:Poppins,sans-serif;font-size:36px;font-weight:600;margin-top:4px">$1,880</div>
        <div style="font-size:13px;color:#8B9AAE;margin-top:2px">of $2,500 · 75% left</div>
        <div style="height:6px;border-radius:3px;background:#1A2740;margin-top:12px;overflow:hidden">
          <div style="width:75%;height:100%;background:#5BC8F5;border-radius:3px"></div>
        </div>
      </div>
      <div class="card">
        <div style="font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;opacity:0.45">Trading days</div>
        <div style="font-family:Poppins,sans-serif;font-size:36px;font-weight:600;margin-top:4px">3 <span style="font-size:18px;opacity:0.4">of 4</span></div>
        <div style="font-size:13px;color:#8B9AAE;margin-top:2px">1 to go this week</div>
      </div>
      <button class="btn-secondary">Log today's P&amp;L</button>
    </div>
    {nav("Settings")}
  </div>
</div>'''

def settings():
    return f'''
<div class="phone dark">{notch()}{sbar()}
  <div class="screen dark">
    <div class="body" style="overflow-y:auto">
      <div class="page-title">Settings</div>
      <div class="group-label">Cover</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item"><span>Mode</span><span class="val">Cover · look ok</span></div>
        <div class="row-item"><span>Apps covered</span><span class="val">MT5, MT4</span></div>
        <div class="row-item"><span>Window</span><span class="val">5 min before and after</span></div>
      </div>
      <div class="group-label">What you trade</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item"><span>Watching</span><span class="val">gold, EUR</span></div>
        <div class="row-item"><span>Your firm's rules</span><span class="val">None · Free</span></div>
      </div>
      <div class="group-label">Alerts</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item"><span>Warnings</span><span class="val">60 · 15 · 5 · 1</span></div>
        <div class="row-item"><span>Tomorrow's news</span><div class="toggle"></div></div>
      </div>
      <div class="group-label">Account</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item"><span>Plan</span><span class="val">Free</span></div>
        <div class="row-item"><span>Go Pro</span><span class="chev">›</span></div>
        <div class="row-item"><span>Permissions</span><span class="chev">›</span></div>
        <div class="row-item"><span>Daily limits</span><span class="chev">›</span></div>
      </div>
      <div class="promise" style="margin:12px 0">We never touch your trades.</div>
    </div>
    {nav("Settings")}
  </div>
</div>'''

def paywall():
    return f'''
<div class="phone dark">{notch()}{sbar()}
  <div class="screen dark">
    <div class="body">
      <div style="font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:#5BC8F5;margin-top:4px">When Free isn't enough</div>
      <div class="page-title" style="margin-top:6px">Your firm's exact rules</div>
      <div class="page-sub">Pro adds your firm's rules, Block, unlimited markets, and a full stay-out log.</div>
      <div class="price-row">
        <div class="price-card"><div style="font-size:12px;opacity:0.5;font-weight:600">Monthly</div>
          <div class="amt">£4.99</div><div class="per">a month</div></div>
        <div class="price-card sel"><div class="badge">BEST VALUE</div>
          <div style="font-size:12px;opacity:0.5;font-weight:600;margin-top:6px">Yearly</div>
          <div class="amt">£39</div><div class="per">£3.25/mo</div></div>
      </div>
      <div class="card" style="padding:8px 14px">
        <div class="feat"><span class="tick">✓</span> Your firm's rules, matched</div>
        <div class="feat"><span class="tick">✓</span> Block (no look)</div>
        <div class="feat"><span class="tick">✓</span> Unlimited markets</div>
        <div class="feat"><span class="tick">✓</span> Full log + streak</div>
        <div class="feat"><span class="tick">✓</span> Custom cover windows</div>
        <div class="feat"><span class="tick">✓</span> No ads</div>
      </div>
      <button class="btn-primary">Start Pro · £39/year</button>
      <div class="promise">Cancel anytime. We never touch your trades.</div>
    </div>
  </div>
</div>'''



def permissions():
    return f'''
<div class="phone dark">{notch()}{sbar()}
  <div class="screen dark">
    <div class="body">
      <div class="page-title">Permissions</div>
      <div class="page-sub">So cover can land on time.</div>
      <div class="card" style="padding:0 16px">
        <div class="row-item"><div><div style="font-weight:600">Notifications</div><div style="font-size:12px;opacity:0.5">Warnings and Tomorrow's news</div></div><div class="toggle"></div></div>
        <div class="row-item"><div><div style="font-weight:600">Usage access</div><div style="font-size:12px;opacity:0.5">See when MT5 is in front</div></div><div class="toggle"></div></div>
        <div class="row-item"><div><div style="font-weight:600">Display over apps</div><div style="font-size:12px;opacity:0.5">Show the cover</div></div><div class="toggle"></div></div>
        <div class="row-item"><div><div style="font-weight:600">Alarms on time</div><div style="font-size:12px;opacity:0.5">Cover on the minute</div></div><div class="toggle off"></div></div>
        <div class="row-item"><div><div style="font-weight:600">Full screen alarms</div><div style="font-size:12px;opacity:0.5">Alarm style when locked</div></div><div class="toggle"></div></div>
        <div class="row-item"><div><div style="font-weight:600">Battery unrestricted</div><div style="font-size:12px;opacity:0.5">Keep watching in the background</div></div><div class="toggle off"></div></div>
      </div>
      <div style="font-size:12px;opacity:0.4;line-height:1.4;padding:0 4px">We never read your trades or log into any account.</div>
    </div>
  </div>
</div>'''

def tablet_home():
    return '''
<div class="tablet"><div class="glow amber" style="border-radius:24px"></div>
  <div style="display:flex;height:100%">
    <div style="width:88px;background:#0C1422;border-right:1px solid #1A2740;display:flex;flex-direction:column;align-items:center;padding:28px 0;gap:32px">
      <div style="font-family:Poppins,sans-serif;font-size:16px;font-weight:600;color:#5BC8F5">◈</div>
      <div style="color:#5BC8F5;font-size:11px;text-align:center;font-weight:600">Home</div>
      <div style="color:#8B9AAE;font-size:11px;text-align:center;opacity:0.5">Today</div>
      <div style="color:#8B9AAE;font-size:11px;text-align:center;opacity:0.5">Log</div>
      <div style="color:#8B9AAE;font-size:11px;text-align:center;opacity:0.5">Settings</div>
    </div>
    <div style="flex:1;padding:40px 48px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px">
      <div class="chip" style="border:1px solid #1A2740;color:#8B9AAE;background:#0C1422;padding:6px 12px;border-radius:6px"><span style="display:inline-block;width:6px;height:6px;border-radius:50%;background:#F5A524;margin-right:6px"></span>Cover is on · gold, EUR</div>
      <div style="font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#F5A524">Opens soon</div>
      <div style="position:relative;width:220px;height:220px">
        <svg viewBox="0 0 220 220" style="width:220px;height:220px;transform:rotate(-90deg)">
          <circle cx="110" cy="110" r="96" fill="none" stroke="rgba(245,165,36,0.12)" stroke-width="10"/>
          <circle cx="110" cy="110" r="96" fill="none" stroke="#F5A524" stroke-width="10" stroke-linecap="round" stroke-dasharray="603" stroke-dashoffset="165"/>
        </svg>
        <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center">
          <div style="font-family:Poppins,sans-serif;font-size:48px;font-weight:600;color:#F5A524;letter-spacing:-1.5px">04:12</div>
          <div style="font-size:12px;opacity:0.5;margin-top:4px">until cover starts</div>
        </div>
      </div>
      <div style="text-align:center">
        <div style="font-family:Poppins,sans-serif;font-size:28px;font-weight:600">Gold · EUR CPI</div>
        <div style="font-size:15px;color:#5BC8F5;margin-top:6px">Today · 8:55–9:05</div>
      </div>
      <div class="peek-row" style="max-width:420px"><div class="peek-k">Also today</div><div class="peek-items"><span class="peek-item"><span class="impact-bars high"><span class="bar"></span><span class="bar"></span><span class="bar"></span></span> BoE Rate <span class="t">10:55</span></span></div></div>
      <div class="promise">We never touch your trades.</div>
    </div>
  </div>
</div>'''

def tablet_gate(phase="amber"):
    color = "#F5A524" if phase=="amber" else "#E5484D"
    glow = "amber" if phase=="amber" else "red"
    count = "04:12" if phase=="amber" else "08:30"
    until = "until cover starts" if phase=="amber" else "until you can trade again"
    kicker = "Opens soon" if phase=="amber" else "Cover is on"
    pcls = "amber-phase" if phase=="amber" else "red-phase"
    track = "rgba(245,165,36,0.1)" if phase=="amber" else "rgba(229,72,77,0.12)"
    offset = 172 if phase=="amber" else 314
    return f'''
<div class="tablet"><div class="glow {glow}" style="border-radius:24px"></div>
  <div class="gate {pcls}" style="height:100%">
    <div class="gate-frame" style="inset:48px 80px 48px"><span class="corner-bl"></span><span class="corner-br"></span></div>
    <div class="body" style="padding:48px 120px;max-width:640px;margin:0 auto;width:100%">
      <div class="gate-kicker">{kicker}</div>
      <div class="gate-arc-wrap" style="margin:40px auto">{gate_arc(color, offset, track)}
        <div class="gate-arc-num"><div class="t">{count}</div><div class="u">{until}</div></div>
      </div>
      <div class="gate-info">
        <div class="gi"><div class="k">What</div><div class="v" style="font-size:15px">Gold · EUR CPI</div></div>
        <div class="gi"><div class="k">When</div><div class="v sky">Today · 8:55–9:05</div></div>
        <div class="gi"><div class="k">Mode</div><div class="v sky">Cover · look ok</div></div>
        <div class="gi"><div class="k">Promise</div><div class="v sky" style="font-size:12px">Never touch trades</div></div>
      </div>
      <div class="gate-promise" style="margin-top:32px">We never touch your trades. Looking is fine. Trading now may break your firm's rules.</div>
      <div class="gate-actions" style="max-width:400px;margin:16px auto 0">
        <button class="btn-stay">Stay out</button>
        <button class="btn-hold"><span class="hold-ring"></span> Hold to look only</button>
      </div>
    </div>
  </div>
</div>'''

def desktop_home():
    return '''
<div class="desktop"><div class="glow amber" style="border-radius:12px"></div>
  <div style="display:flex;height:100%">
    <div style="width:220px;background:#0C1422;border-right:1px solid #1A2740;padding:28px 20px;display:flex;flex-direction:column;gap:8px">
      <div style="font-family:Poppins,sans-serif;font-size:20px;font-weight:600;margin-bottom:20px">Guard</div>
      <div style="padding:10px 12px;border-radius:8px;background:rgba(91,200,245,0.1);color:#5BC8F5;font-weight:600;font-size:14px">Home</div>
      <div style="padding:10px 12px;border-radius:8px;color:#8B9AAE;font-size:14px">Today</div>
      <div style="padding:10px 12px;border-radius:8px;color:#8B9AAE;font-size:14px">Log</div>
      <div style="padding:10px 12px;border-radius:8px;color:#8B9AAE;font-size:14px">Settings</div>
      <div style="margin-top:auto;font-size:12px;opacity:0.4;line-height:1.4">We never touch your trades.</div>
    </div>
    <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px;padding:40px">
      <div class="chip" style="border:1px solid #1A2740;color:#8B9AAE;background:#0C1422;padding:6px 12px;border-radius:6px"><span style="display:inline-block;width:6px;height:6px;border-radius:50%;background:#F5A524;margin-right:6px"></span>Cover is on · gold, EUR</div>
      <div style="font-size:12px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#F5A524">Opens soon</div>
      <div style="position:relative;width:240px;height:240px">
        <svg viewBox="0 0 240 240" style="width:240px;height:240px;transform:rotate(-90deg)">
          <circle cx="120" cy="120" r="104" fill="none" stroke="rgba(245,165,36,0.12)" stroke-width="12"/>
          <circle cx="120" cy="120" r="104" fill="none" stroke="#F5A524" stroke-width="12" stroke-linecap="round" stroke-dasharray="653" stroke-dashoffset="180"/>
        </svg>
        <div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center">
          <div style="font-family:Poppins,sans-serif;font-size:56px;font-weight:600;color:#F5A524;letter-spacing:-2px">04:12</div>
          <div style="font-size:13px;opacity:0.5;margin-top:4px">until cover starts</div>
        </div>
      </div>
      <div style="text-align:center">
        <div style="font-family:Poppins,sans-serif;font-size:28px;font-weight:600">Gold · EUR CPI</div>
        <div style="font-size:15px;color:#5BC8F5;margin-top:6px">Today · 8:55–9:05</div>
        <div class="peek-row" style="max-width:420px;margin:12px auto 0;text-align:left"><div class="peek-k">Also today</div><div class="peek-items"><span class="peek-item"><span class="impact-bars high"><span class="bar"></span><span class="bar"></span><span class="bar"></span></span> BoE Rate <span class="t">10:55</span></span></div></div>
      </div>
    </div>
  </div>
</div>'''

def desktop_gate(phase="amber"):
    color = "#F5A524" if phase=="amber" else "#E5484D"
    pcls = "amber" if phase=="amber" else "red"
    count = "04:12" if phase=="amber" else "08:30"
    until = "until cover starts" if phase=="amber" else "until you can trade again"
    kicker = "Opens soon" if phase=="amber" else "Cover is on"
    btn_fg = "#08306B" if phase=="amber" else "#fff"
    return f'''
<div class="desktop" style="background:#1a1f2e">
  <div style="position:absolute;inset:0;padding:40px;opacity:0.35;font-family:monospace;font-size:12px;color:#5a6a7e">
    <div style="font-size:16px;color:#8B9AAE;margin-bottom:20px">MetaTrader 5 · XAUUSD,H1</div>
    <div style="height:400px;border:1px solid #2a3548;border-radius:4px;background:linear-gradient(180deg,#151a28,#0e121c)">
      <svg width="100%" height="100%" viewBox="0 0 800 400" preserveAspectRatio="none">
        <polyline fill="none" stroke="#3a7abd" stroke-width="2" points="0,280 80,270 160,250 240,230 320,210 400,190 480,170 560,150 640,145 720,135 800,125"/>
      </svg>
    </div>
  </div>
  <div class="desktop-gate-overlay">
    <div class="gate-panel {pcls}" style="width:420px">
      <div style="font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:{color};margin-bottom:16px">{kicker}</div>
      <div style="text-align:center;margin:20px 0">
        <div style="font-family:Poppins,sans-serif;font-size:56px;font-weight:600;color:{color};letter-spacing:-2px">{count}</div>
        <div style="font-size:13px;color:#8B9AAE;margin-top:6px">{until}</div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;border-top:1px solid rgba(91,200,245,0.15);padding-top:16px">
        <div><div style="font-size:10px;font-weight:600;letter-spacing:1px;text-transform:uppercase;color:#8B9AAE">What</div><div style="font-family:Poppins,sans-serif;font-size:15px;font-weight:600;margin-top:3px">Gold · EUR CPI</div></div>
        <div><div style="font-size:10px;font-weight:600;letter-spacing:1px;text-transform:uppercase;color:#8B9AAE">When</div><div style="font-size:14px;color:#5BC8F5;margin-top:3px">Today · 8:55–9:05</div></div>
      </div>
      <div style="font-size:13px;color:#8B9AAE;text-align:center;margin:20px 0 12px;line-height:1.4">We never touch your trades. Looking is fine. Trading now may break your firm's rules.</div>
      <button style="width:100%;height:52px;border-radius:8px;border:none;background:{color};color:{btn_fg};font-size:16px;font-weight:600;margin-bottom:10px">Stay out</button>
      <button style="width:100%;height:52px;border-radius:8px;background:transparent;border:1px solid rgba(91,200,245,0.4);color:#EDF2F8;font-size:15px;font-weight:500">Hold to look only</button>
    </div>
  </div>
</div>'''

screens = {
    "phone/gate-amber": (wrap("Cover soon", gate("amber")), "phone"),
    "phone/gate-red": (wrap("Cover on", gate("red", time="08:56")), "phone"),
    "phone/gate-hard-block": (wrap("Block", gate("red", block=True, time="08:56")), "phone"),
    "phone/home-busy-dark": (wrap("Home busy dark", home_busy("dark")), "phone"),
    "phone/home-busy-light": (wrap("Home busy light", home_busy("light")), "phone"),
    "phone/home-clear-dark": (wrap("Home clear dark", home_clear("dark")), "phone"),
    "phone/home-clear-light": (wrap("Home clear light", home_clear("light")), "phone"),
    "phone/edge-glow-detail": (wrap("Edge glow", home_busy("dark")), "phone"),
    "phone/lock-sky-hour": (wrap("Lock hour", lock_activity("sky_hour")), "phone"),
    "phone/lock-amber-5min": (wrap("Lock amber", lock_activity("amber")), "phone"),
    "phone/lock-red-open": (wrap("Lock open", lock_activity("red")), "phone"),
    "phone/lock-sky-clear": (wrap("Lock clear", lock_activity("clear")), "phone"),
    "phone/di-compact": (wrap("DI compact", dynamic_island("compact")), "phone"),
    "phone/di-expanded": (wrap("DI expanded", dynamic_island("expanded")), "phone"),
    "phone/shield-mock": (wrap("Shield", shield_mock()), "phone"),
    "phone/shield-config-doc": (wrap("Shield doc", shield_doc(), 900, 600, "capture wide-cap"), "phone"),
    "phone/notif-60": (wrap("N60", notif_banner(*NOTIFS[0])), "phone"),
    "phone/notif-15": (wrap("N15", notif_banner(*NOTIFS[1])), "phone"),
    "phone/notif-5": (wrap("N5", notif_banner(*NOTIFS[2])), "phone"),
    "phone/notif-1": (wrap("N1", notif_banner(*NOTIFS[3])), "phone"),
    "phone/notif-open": (wrap("Nopen", notif_banner(*NOTIFS[4])), "phone"),
    "phone/notif-clear": (wrap("Nclear", notif_banner(*NOTIFS[5])), "phone"),
    "phone/notif-tomorrow": (wrap("Ntomorrow", notif_tomorrow()), "phone"),
    "phone/android-fsi": (wrap("FSI", android_fsi()), "phone"),
    "phone/setup-1": (wrap("Setup1", setup(1)), "phone"),
    "phone/setup-2": (wrap("Setup2", setup(2)), "phone"),
    "phone/setup-3": (wrap("Setup3", setup(3)), "phone"),
    "phone/today": (wrap("Today", today_screen("dark")), "phone"),
    "phone/today-light": (wrap("Today light", today_screen("light")), "phone"),
    "phone/tomorrows-news": (wrap("Tomorrow's news", tomorrows_news("dark")), "phone"),
    "phone/tomorrows-news-light": (wrap("Tomorrow's news light", tomorrows_news("light")), "phone"),
    "phone/log": (wrap("Log", log_screen()), "phone"),
    "phone/tracker": (wrap("Daily limits", tracker()), "phone"),
    "phone/settings": (wrap("Settings", settings()), "phone"),
    "phone/paywall": (wrap("Paywall", paywall()), "phone"),
    "phone/permissions": (wrap("Permissions", permissions()), "phone"),
    "tablet/home": (wrap("Tablet home", tablet_home(), 834, 1194, "capture tablet-cap"), "tablet"),
    "tablet/gate-amber": (wrap("Tablet cover soon", tablet_gate("amber"), 834, 1194, "capture tablet-cap"), "tablet"),
    "tablet/gate-red": (wrap("Tablet cover on", tablet_gate("red"), 834, 1194, "capture tablet-cap"), "tablet"),
    "desktop/home": (wrap("Desktop home", desktop_home(), 1440, 900, "capture desktop-cap"), "desktop"),
    "desktop/gate-amber": (wrap("Desktop cover soon", desktop_gate("amber"), 1440, 900, "capture desktop-cap"), "desktop"),
    "desktop/gate-red": (wrap("Desktop cover on", desktop_gate("red"), 1440, 900, "capture desktop-cap"), "desktop"),
}

# Remove obsolete html names
for old in OUT.glob("phone-windows.html"):
    old.unlink(missing_ok=True)
for old in OUT.glob("phone-digest.html"):
    old.unlink(missing_ok=True)
for old in OUT.glob("phone-journal.html"):
    old.unlink(missing_ok=True)

manifest = []
for key, (html, folder) in screens.items():
    fname = key.replace("/", "-") + ".html"
    path = OUT / fname
    path.write_text(html, encoding="utf-8")
    png_folder = OUT.parent / folder
    png_folder.mkdir(parents=True, exist_ok=True)
    png_name = key.split("/", 1)[1] + ".png"
    m = re.search(r"width:(\d+)px;height:(\d+)px", html)
    w, h = (int(m.group(1)), int(m.group(2))) if m else (428, 926)
    manifest.append({"html": str(path), "png": str(png_folder / png_name), "w": w, "h": h, "key": key})

(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(f"Generated {len(manifest)} screens")
# Ban check
banned = ["Soft gate", "Soft cover", "Night before", "Hold to view", "Firm match", "Sample data", "Conservative", " UTC"]
for m in manifest:
    t = Path(m["html"]).read_text()
    for b in banned:
        if b in t:
            print(f"BAN HIT {m['key']}: {b}")
print("ban scan done")
