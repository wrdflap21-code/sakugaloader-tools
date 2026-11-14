<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/banner.png">
    <img src="assets/banner-light.png" alt="SAKUGA loader" width="560">
  </picture>
</p>

# Sakugaloader installer and tools

This repository holds the **Sakugaloader Installer** and the optional **tools** the [Sakugaloader](https://github.com/wrdflap21-code/Sakuga-Upadate) After Effects panel can use. The panel itself and its update channel live in [Sakuga-Upadate](https://github.com/wrdflap21-code/Sakuga-Upadate).

## Get the installer

Download the latest **`Sakugaloader-Installer-v...zip`** from [Releases](https://github.com/wrdflap21-code/sakugaloader-tools/releases/latest), close After Effects, extract it, and run **`Sakugaloader-Setup.exe`**. It downloads and verifies the latest panel for you. Full instructions, requirements and screenshots: [Sakuga-Upadate](https://github.com/wrdflap21-code/Sakuga-Upadate#install).

The installer tells you when a newer installer exists (green notice) and can update itself with one click. Its release notes are in the **What's new** panel.

## What is here

| Item | What it is | Release tag |
|------|------------|-------------|
| Sakugaloader Installer | Windows setup for the panel, with a Tools tab and update notice | `installer-v<version>` |
| AniVocal engine | Splits vocals and instrumentals (installs Python and Demucs on first setup) | `anivocal-v<version>` |

Each release has one ZIP and its SHA256. The installer and the panel pin the SHA256 of what they download and refuse anything that does not match.

FFmpeg and Real-ESRGAN are **not** mirrored here: Sakugaloader downloads fixed versions from their official sources and verifies them by SHA256.

## License

Free for everyone, and not for sale: see the **Sakugaloader Free Use License** summary in [Sakuga-Upadate](https://github.com/wrdflap21-code/Sakuga-Upadate#license). The full text is in the `LICENSE` file inside every package. Third-party tools keep their own licenses.
