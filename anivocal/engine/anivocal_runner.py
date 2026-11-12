import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

AUDIO_EXTS = {".mp3", ".wav", ".m4a", ".aac", ".ogg", ".oga", ".flac", ".aif", ".aiff"}
VIDEO_EXTS = {".mp4", ".mov", ".webm", ".m4v", ".mkv", ".avi"}

def log(message: str) -> None:
    print(f"[AniVocal] {message}", flush=True)

def safe_name(name: str) -> str:
    bad = '<>:"/\\|?*'
    out = "".join("_" if c in bad else c for c in name)
    out = out.strip().strip(".")
    return out or "anivocal"

def get_ffmpeg() -> str:
    base = Path(__file__).resolve().parents[1]
    local_ffmpeg = base / "ffmpeg" / "ffmpeg.exe"
    if local_ffmpeg.exists():
        return str(local_ffmpeg)

    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        pass

    return "ffmpeg"

def run(cmd, cwd=None):
    log("Command: " + " ".join(f'"{x}"' if " " in str(x) else str(x) for x in cmd))
    process = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    for line in process.stdout:
        line = line.rstrip()
        if line:
            print(line, flush=True)

    return process.wait()

def parse_optional_float(value):
    value = str(value or "").strip()
    if not value:
        return None

    try:
        return max(0.0, float(value))
    except Exception:
        return None

def build_cut_args(cut_start, cut_end):
    start = parse_optional_float(cut_start)
    end = parse_optional_float(cut_end)
    args = []

    if start is not None and start > 0:
        args += ["-ss", str(start)]

    if end is not None:
        if start is not None and end > start:
            args += ["-t", str(end - start)]
        elif start is None and end > 0:
            args += ["-t", str(end)]

    return args

def prepare_audio(input_path: Path, work_dir: Path, cut_start=None, cut_end=None) -> Path:
    ext = input_path.suffix.lower()
    has_cut = bool(str(cut_start or "").strip() or str(cut_end or "").strip())
    ffmpeg = get_ffmpeg()

    if ext not in AUDIO_EXTS and ext not in VIDEO_EXTS:
        raise RuntimeError(f"Unsupported input extension: {ext}")

    if ext in AUDIO_EXTS and not has_cut:
        log("Audio input detected.")
        return input_path

    if ext in AUDIO_EXTS:
        log("Audio input detected. Creating cut/normalized WAV with FFmpeg...")
    else:
        log("Video input detected. Extracting audio with FFmpeg...")

    extracted = work_dir / "input_audio.wav"
    cut_args = build_cut_args(cut_start, cut_end)

    if has_cut:
        log(f"Cut enabled. Start: {cut_start or '0'} | End: {cut_end or 'end'}")

    cmd = [
        ffmpeg,
        "-y",
    ]

    # -ss before -i is much faster and good enough for audio separation.
    cmd += cut_args
    cmd += [
        "-i", str(input_path),
        "-vn",
        "-ac", "2",
        "-ar", "44100",
        "-c:a", "pcm_s16le",
        str(extracted),
    ]

    code = run(cmd)

    if code != 0 or not extracted.exists():
        raise RuntimeError("FFmpeg could not prepare audio.")

    return extracted

def choose_model(mode: str) -> str:
    mode = (mode or "balanced").lower().strip()

    if mode == "fast":
        return "mdx_extra_q"

    if mode == "best":
        return "htdemucs_ft"

    return "htdemucs"

def run_demucs(audio_path: Path, output_root: Path, mode: str, output_mode: str) -> Path:
    model = choose_model(mode)
    output_mode = (output_mode or "vocals_instrumental").lower().strip()

    log(f"Running Demucs model: {model}")
    log(f"Output mode: {output_mode}")

    cmd = [
        sys.executable,
        "-m",
        "demucs.separate",
        "-n",
        model,
        "-o",
        str(output_root),
    ]

    if output_mode in {"vocals_instrumental", "vocals_only"}:
        cmd += ["--two-stems", "vocals"]

    device = os.environ.get("ANIVOCAL_DEVICE", "").strip()
    if device:
        cmd += ["--device", device]

    cmd.append(str(audio_path))

    code = run(cmd)

    if code != 0:
        if model != "htdemucs":
            log(f"Model {model} failed. Trying fallback model: htdemucs")
            cmd = [
                sys.executable,
                "-m",
                "demucs.separate",
                "-n",
                "htdemucs",
                "-o",
                str(output_root),
            ]

            if output_mode in {"vocals_instrumental", "vocals_only"}:
                cmd += ["--two-stems", "vocals"]

            if device:
                cmd += ["--device", device]

            cmd.append(str(audio_path))
            code = run(cmd)

    if code != 0:
        raise RuntimeError(f"Demucs failed with exit code {code}")

    stem_root = output_root / model / audio_path.stem
    if not stem_root.exists():
        # Fallback scan in case Demucs used a fallback model.
        candidates = [p for p in output_root.rglob(audio_path.stem) if p.is_dir()]
        if candidates:
            stem_root = candidates[0]

    if not stem_root.exists():
        raise RuntimeError("Could not find Demucs output folder.")

    return stem_root

def copy_outputs(stem_root: Path, final_output: Path, output_mode: str) -> None:
    output_mode = (output_mode or "vocals_instrumental").lower().strip()
    final_output.mkdir(parents=True, exist_ok=True)

    candidates = [p for p in stem_root.glob("*") if p.is_file() and p.suffix.lower() in AUDIO_EXTS]

    def find_exact_or_contains(exact_names, include_keys, exclude_keys=None):
        exclude_keys = exclude_keys or []

        for p in candidates:
            lower = p.name.lower()
            if lower in exact_names:
                return p

        for p in candidates:
            lower = p.name.lower()
            if any(ex in lower for ex in exclude_keys):
                continue
            if any(k in lower for k in include_keys):
                return p

        return None

    # Important:
    # Demucs two-stems creates "vocals.wav" and "no_vocals.wav".
    # "no_vocals.wav" contains the word "vocals", so vocals detection must exclude it.
    instrumental = find_exact_or_contains(
        {"no_vocals.wav", "novocals.wav", "instrumental.wav", "accompaniment.wav"},
        ["no_vocals", "novocals", "instrumental", "accompaniment"],
        []
    )

    vocals = find_exact_or_contains(
        {"vocals.wav", "vocal.wav", "voice.wav"},
        ["vocals", "vocal", "voice"],
        ["no_vocals", "novocals", "instrumental", "accompaniment"]
    )

    if vocals and output_mode in {"vocals_instrumental", "vocals_only", "all_stems"}:
        shutil.copy2(vocals, final_output / "vocals.wav")
        log(f"Saved vocals: {final_output / 'vocals.wav'}")

    if instrumental and output_mode in {"vocals_instrumental", "all_stems"}:
        shutil.copy2(instrumental, final_output / "instrumental.wav")
        log(f"Saved instrumental: {final_output / 'instrumental.wav'}")

    if output_mode == "all_stems":
        for p in candidates:
            if p == vocals or p == instrumental:
                continue

            out = final_output / safe_name(p.stem + p.suffix)

            if out.name.lower() not in {"vocals.wav", "instrumental.wav"}:
                shutil.copy2(p, out)
                log(f"Saved stem: {out}")

    if not any(final_output.glob("*.wav")) and not any(final_output.glob("*.mp3")) and not any(final_output.glob("*.flac")):
        raise RuntimeError("No output stems were created.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--mode", default="balanced", choices=["fast", "balanced", "best"])
    parser.add_argument("--output-mode", default="vocals_instrumental", choices=["vocals_instrumental", "vocals_only", "all_stems"])
    parser.add_argument("--cut-start", default="")
    parser.add_argument("--cut-end", default="")
    args = parser.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    final_output = Path(args.output).expanduser().resolve()
    work_dir = final_output / "_temp"

    if not input_path.exists():
        raise RuntimeError(f"Input file not found: {input_path}")

    work_dir.mkdir(parents=True, exist_ok=True)
    final_output.mkdir(parents=True, exist_ok=True)

    log("AniVocal Engine v0.1")
    log(f"Input: {input_path}")
    log(f"Output folder: {final_output}")

    audio_path = prepare_audio(input_path, work_dir, args.cut_start, args.cut_end)
    demucs_out = work_dir / "demucs"
    stem_root = run_demucs(audio_path, demucs_out, args.mode, args.output_mode)
    copy_outputs(stem_root, final_output, args.output_mode)

    log("Done.")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        log("ERROR: " + str(exc))
        sys.exit(1)
