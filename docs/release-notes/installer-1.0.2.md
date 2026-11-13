# Installer Updates 1.0.2

## One-click installer updates
- When a newer installer exists, the green notice now has an **Update now** button: it downloads the new installer, checks its SHA256, opens it and closes the old one. No browser needed.
- The update is only ever downloaded from the official release address and is never written over the running installer; it is unpacked under `%LOCALAPPDATA%\Sakugaloader-Installer`.
- If anything fails (offline, checksum, unexpected package) nothing is changed and the button falls back to opening the download page.

## Installer
- Centered logo and the Open After Effects button (shown only when Sakugaloader is installed).
