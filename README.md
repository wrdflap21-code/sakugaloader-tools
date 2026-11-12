# Sakugaloader Tools

Companion tools used by the [Sakugaloader](https://github.com/wrdflap21-code/sakugloader-updates) After Effects panel. This repository holds **only the tools**; Sakugaloader itself and its updates live in `sakugloader-updates`.

| Tool | What it does | Folder | Release tag |
|------|--------------|--------|-------------|
| AniVocal engine | Splits vocals and instrumentals (installs Python + Demucs on first setup) | `anivocal/` | `anivocal-v<version>` |

Each tool gets its own release per version, named `<Tool> <version> — <subtitle>`, with one ZIP asset and its SHA256. Sakugaloader pins the SHA256 of the package it downloads and refuses anything that does not match.

FFmpeg and Real-ESRGAN are not mirrored here: Sakugaloader downloads them from their official sources and verifies them.
