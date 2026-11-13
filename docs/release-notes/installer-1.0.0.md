# Installer Updates 1.0.0

## New standalone installer
- The installer now ships on its own and downloads the latest Sakugaloader panel from the official Sakuga-Upadate repository, checks its SHA256 and installs it. Internet is needed to install.
- The setup window shows a green notice with a Download button when a newer installer is available.

## Tools
- Tools tab: install or remove FFmpeg, Real-ESRGAN (Upscale) and AniVocal with fast parallel downloads, checksum verification and real progress.
- Your own data (custom models, separated audio) is kept when you remove a tool.

## Safety
- The downloaded panel is verified (SHA256 and per-file hashes) before anything is installed, and an existing install is backed up and restored if something fails.
