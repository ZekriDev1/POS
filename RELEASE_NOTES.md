# CashManager POS — Release Notes

## v0.2.0 — Remote Access, Installer, & Polish

### 🚀 New Features

**Remote Access (Public URL)**
- Built-in HTTP server with REST API, WebSocket support, and a static web client
- **bore tunnel** (replaces SSH) — app auto-downloads `bore.exe` on first run, no manual setup needed
- Unique persistent device ID — each installation gets its own stable URL
- Remote user management — create, edit, delete, enable/disable users with role-based access
- JWT authentication with session tracking and auto-disconnect
- QR code for quick URL sharing
- Real-time active sessions view with device/browser/country info

**Installer (Windows)**
- Inno Setup installer with custom icon
- Install directory selection
- Start Menu folder selection
- Optional: desktop shortcut
- Optional: launch at Windows startup (registry `HKCU\...\Run`)
- Optional: pin to taskbar (Windows 10)
- Clean uninstall — removes registry keys, taskbar pin, and all app files

### 🎨 UI / Polish

- App icon changed from default Flutter icon to custom `Logo.png` (multi-resolution `.ico`, 16×16 through 256×256)
- Copyright footer in Settings: "Akram Zekri | +212 691157363"
- Connection Details card with working Copy URL (clipboard) and Open URL (browser) buttons
- Restart Tunnel button to regenerate the public URL

### 🐛 Bug Fixes

- **Dashboard loading** — added `snap.hasError` branches to all `FutureBuilder`s (was stuck on spinner)
- **Dashboard FormatException** — wrapped each of the 7 DB queries in `_loadStats` with individual try/catch (fallback values)
- **Safe casts** — changed `as double` → `(as num).toDouble()` to prevent runtime type errors
- **Date migration (v3)** — Drift's `_readDateTime` with `storeDateTimesAsText: false` crashed on string dates; added schema v3 migration converting string dates to Unix integers via `DateTime.parse`
- **SQLite syntax** — fixed double-quote error: `"text"` → `'text'` in migration SQL
- **Tunnel URL parsing** — buffered stdout stream to handle split chunks; regex now matches `http://bore.pub:<port>` reliably

### 🧰 Technical Changes

- Replaced `cloudflared` and SSH with **bore** (lightweight Rust tunnel, auto-downloaded)
- Added packages: `url_launcher`
- Updated installer scripts to match the new bore-based tunnel approach
