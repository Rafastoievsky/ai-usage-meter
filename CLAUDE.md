# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This directory is a workspace, not itself a git repo. The actual project lives in the `clawd-meter/` subdirectory, which has its own git repo (remote: `git@github.com:Rafastoievsky/clawd-meter.git`). Run all `git` commands from inside `clawd-meter/`.

- `clawd-meter/` — the firmware project (see below). Do your work here.
- `Docs/AI_USAGE_METER_ESP32_SPEC_DRIVEN_PLAN.md` — a Spanish-language spec-driven plan (not yet implemented) for extending clawd-meter with a local "bridge" that adds Codex/ChatGPT Plus usage alongside Claude, run from a Mac and exposed read-only to the ESP32 over LAN. Treat it as a design proposal, not current architecture — nothing under `bridge/`, `specs/`, `scripts/`, etc. it describes exists in the tree yet.

## What clawd-meter is

Firmware for a cheap ESP32 touchscreen ("Cheap Yellow Display", ESP32-2432S028R) that shows your Claude usage (5-hour + weekly windows) and an animated mascot ("Clawd") whose mood follows quota consumed. It's a Claude-only fork of [glimmer](https://github.com/Avinava/glimmer) (dashboard/channel engine + TFT_eSPI rendering) merged with the mascot idea from [clawd-mochi](https://github.com/yousifamanuel/clawd-mochi). The code and comments still say "SmallTV" / "glimmer" in places — that's the ESP8266 predecessor this was ported from, not a separate project.

Two build targets share one codebase via `#if defined(ESP32)` and `src/core/compat.h`:
- `nodemcuv2` — original ESP8266 GeekMagic SmallTV-Ultra target (240×240 ST7789, active-low backlight on GPIO5).
- `cyd` — the actively developed ESP32 target (320×240 landscape ILI9341, active-high backlight on GPIO21, XPT2046 resistive touch). This is the one referenced throughout README and the one to build/flash by default.

## Build / flash commands

Requires [PlatformIO](https://platformio.org/) (`pio` CLI).

```bash
cd clawd-meter
pio run -e cyd -t buildfs   # build LittleFS image (fonts + web UI) — needed after editing data/web or data/fonts
pio run -e cyd              # compile firmware
pio run -e cyd -t upload    # flash firmware over USB
pio run -e cyd -t uploadfs  # flash filesystem over USB — WIPES saved settings (rewrites whole FS)
pio device monitor -b 115200   # serial log (matches monitor_speed in platformio.ini)
```

Before `uploadfs`, back up device settings: `curl http://<device-ip>/api/export` (restore via `POST /api/import`).

There is no unit test suite — this is embedded firmware; verification is compile + flash + observe on hardware (or reason carefully about the change when hardware isn't available).

### Regenerating fonts

`tools/genfonts.py` converts TTF sources in `tools/ttf/` into TFT_eSPI-compatible `.vlw` bitmap fonts in `data/fonts/`, at fixed pixel sizes baked into the filename (e.g. `DMMono-11.vlw`). Needs the `freetype` Python package. Re-run it, then `pio run -e cyd -t buildfs` + `uploadfs`, any time a font size/family changes.

## Architecture

`src/main.cpp` is the orchestrator; the comment at its top is the map:
```
core/     hardware + I/O (display, wifi, time, storage, web, OTA)
data/     external API clients (Claude, weather, ...)
channels/ self-contained screen renderers, registered in kChannels[]
```

### Channel system (the core extension point)

A "channel" is one screen (Clawd, Claude, Home, Weather, Forecast, Clock, Info, Push). Each is a single `.cpp` in `src/channels/` exposing three free functions matching `channel.h`'s `Channel` struct: `enabled(ctx)`, `draw(ctx)`, and an optional `tick(ctx)`. All channels are registered in the `kChannels[]` table in `src/main.cpp`. **Adding a channel = one new `.cpp` + one row in that table — no other wiring needed.**

The one rule that matters most here is the **partial-redraw discipline** (documented in `src/channels/channel.h`):
- `draw(ctx)` — full repaint, called once when a channel becomes active. Clears and paints everything.
- `tick(ctx)` — called at 5 Hz while the channel stays active. Must **never** clear/fillScreen; it repaints only the specific pixel regions that changed (clock seconds, countdown bars, animation frames, etc). This is what keeps the display flicker-free instead of full-refreshing 5x/second.

When touching any channel's `tick()`, preserve this: any add must track exactly what changed and blit only that region.

`main.cpp`'s `loop()` also drives: WiFi reconnect/health-check, periodic `refreshAll()` (fetches Claude + weather on a timer, `DEFAULT_REFRESH_MIN`), touch-to-advance, auto-rotate between enabled channels, the self-heal reboot (reboots only after `Api::claudeOkSinceBoot()` is true *and* 5+ consecutive **connection-level** failures — see the long comment above it before changing this logic, it's deliberately narrow to avoid reboot loops during a real outage).

### Core modules (`src/core/`)

- `display.h/.cpp` — all TFT_eSPI drawing primitives: VLW font loading/caching (`useFont`/`releaseFont`, 1-slot cache), `statusBar()`/`pixelBar()`/`dotsDivider()` design-system primitives shared across channels, splash/connecting/error/OTA system screens.
- `theme.h` — the color palette (`Theme::BG/PANEL/INK/CORAL/AMBER/MINT/SKY/LILAC/ORANGE`, RGB565 constants) and per-channel color lookup. One accent color per screen is the design rule.
- `layout.h` — screen geometry constants (`SCREEN_W`/`SCREEN_H` come from `config.h`, board-dependent).
- `config.h` — physical panel config per board (`#if defined(ESP32)` branches), AP SSID, mDNS hostname (`glimmer`), refresh/rotation defaults.
- `compat.h` — the ESP8266/ESP32 portability shim (WiFi/mDNS/hostname/heap-query differences). Only put things here that are needed nearly everywhere; anything WebServer/HTTPClient/TLS-related stays local to the few files that need it (conflicts with TFT_eSPI's FS usage otherwise).
- `storage.h/.cpp` — `Settings` struct (everything persisted to `/config.json` on LittleFS) and load/save/factoryReset. Adding a setting = add a field here + wire it into `web.cpp`'s get/set JSON handlers + the web UI.
- `web.cpp` — the on-device HTTP API + settings web UI server. Routes: `GET/POST /api/settings`, `GET /api/state`, `GET /api/export` / `POST /api/import` (raw config.json backup/restore), `POST /api/factory-reset`, `POST /api/reboot`, `POST /push` and `POST /mcp` (bearer-token-authed JSON-RPC subset, used for external integrations).

### Data layer (`src/data/`)

- `api.cpp/.h` — `Api::fetchClaude()` hits claude.ai's internal (undocumented) usage endpoint using the user's own `sessionKey` cookie, populates `ClaudeData` (session/weekly % used, reset times, per-model breakdown). Also tracks `claudeConnFails()`/`claudeOkSinceBoot()` used by main.cpp's self-heal reboot — see note above.
- `weather.cpp/.h` — Open-Meteo client (no API key required), populates `WeatherData` (current + 3-day forecast).

### UI helpers (`src/ui/`)

- `mood.cpp/.h` — maps Claude usage % to Clawd's mood/expression bands (excited/happy/normal/stressed/squish/dizzy) and suggests auto-brightness by time of day (night-dim window).
- `weather_icons.cpp/.h` — WMO weather code → icon glyph mapping.

### Web UI (`data/web/`)

Static files served from LittleFS: `index.html` + `css/style.css` (Pico CSS, gzipped) + `js/alpine.min.js.gz` (Alpine.js for reactivity). No build step — edit directly, then `pio run -e cyd -t buildfs && pio run -e cyd -t uploadfs` to push to the device.

## Conventions worth knowing before editing

- **Settings persistence**: every field in `Settings` (`storage.h`) round-trips through `/config.json`; a new field needs a default, a JSON key in `web.cpp`, and (usually) a UI control in `data/web/index.html`.
- **Secrets**: `claudeKey` (the `sessionKey` cookie) and `apiToken` live in plaintext in `/config.json` on-device — masked as `"***"` in `GET /api/settings` responses but present in `/api/export`. `.gitignore` excludes `secrets.h`, `config.json`, `*.config.json` — never commit real credentials.
- **RGB565 everywhere**: display colors are 16-bit RGB565 constants (see `theme.h`), not standard hex/RGB — when adding a color, convert accordingly and keep it in `Theme`.
- **Board branching**: prefer `#if defined(ESP32)` (matches existing usage) over inventing new feature-detection macros; keep ESP8266 (`nodemcuv2`) support working since it's still a build target in `platformio.ini`, even though `cyd` is the actively developed board.
