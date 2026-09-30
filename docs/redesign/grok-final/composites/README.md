# Guard · Springboard / lock composites

Full-phone mockups showing how Guard appears on people's home and lock screens — Dynamic Island, Live Activities, banners, and the trading-app overlay. Not isolated widgets.

**Size:** 428×926 · dark wallpaper · realistic iPhone chrome with Dynamic Island  
**Sources:** `final/html/composites/*.html` · CSS `final/shared/composites.css`  
**Icon:** `final/icon/icon-1024.png`

## Files

| File | Scenario |
|---|---|
| `home-quiet.png` | Unlocked Springboard · Guard icon among apps · no Live Activity (quiet day) |
| `home-island-soon.png` | Unlocked home · Island compact **SOON · 04:12** · optional 5-min banner peek |
| `home-island-on.png` | Unlocked home · Island compact **ON · 08:30** |
| `lock-hour.png` | Lock + Live Activity **IN 1 HOUR** |
| `lock-soon.png` | Lock + amber **OPENS SOON** Live Activity |
| `lock-on.png` | Lock + red **COVER ON** Live Activity |
| `lock-clear.png` | Lock + **ALL CLEAR** briefly |
| `lock-banner-60.png` | Lock · LA hour board + **60 min** notification banner (stack) |
| `unlocked-banner-open.png` | Springboard · **Cover is on** banner + Island **ON** together |
| `overlay-mt5.png` | MT5 under dimmed layer · Guard Screen Time shield / cover on top |

## OS limits (honest)

1. **No glow on Springboard.** Edge glow lives *inside* Guard cover UI only. Composites never paint a glow over other apps or the home screen.
2. **Overlay only over trading apps.** `overlay-mt5` is the real cover case (Screen Time shield / Android FSI). Caption on the board: “Cover overlay over trading app · not Springboard.”
3. **Dynamic Island** on unlocked home is compact Live Activity (SOON / ON). Expanded Island is shown in isolated `phone/di-expanded.png`.
4. **Banners + Live Activity** can coexist on lock (ladder push + LA board). On unlocked home, banner peeks under the Island.
5. **Green never** for all-clear / success. Clear phase uses sky `#5BC8F5`.

## Copy source

All strings from `final/COPY.md` (Live Activity, DI, notifications, shield).

## Regen

```bash
python3 final/generate_composites.py
python3 final/render_pngs.py   # KEY includes composites/*
```
