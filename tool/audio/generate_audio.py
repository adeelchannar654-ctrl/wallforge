#!/usr/bin/env python3
"""Generate Wallforge's Phase 12 audio assets by synthesis.

Every sound in `assets/audio/` is produced by this script — no sampled or
third-party audio — so the assets are original to the project and released
under CC0 (see `assets/audio/LICENCE.txt`). Re-running this script
reproduces the shipped files byte-for-byte (the noise burst uses a fixed
seed).

Effects are 22050 Hz mono 16-bit WAV (small, universally supported,
including Safari on the web). The music loop is rendered here as WAV and
then encoded to MP3 by the caller (ffmpeg, 96 kbps mono) for size.

Run:  python3 tool/audio/generate_audio.py
Then: ffmpeg -y -i /tmp/wallforge_music.wav -codec:a libmp3lame -b:a 96k \
        -ac 1 assets/audio/music.mp3
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)


def save_wav(name, samples):
    path = os.path.join(OUT, name)
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
        for s in samples
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print(path, len(samples) / SR, "s")


def tone(freq, dur, vol=0.5, sweep_to=None, attack=0.005):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / n)
        env = math.exp(-3.0 * i / n) * min(1.0, t / attack)
        out.append(vol * env * math.sin(2 * math.pi * f * t))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max(1.0, max(abs(s) for s in out))
    return [s / peak * 0.9 for s in out]


def place(track, segment, at_seconds):
    start = int(at_seconds * SR)
    need = start + len(segment)
    if len(track) < need:
        track.extend([0.0] * (need - len(track)))
    for i, s in enumerate(segment):
        track[start + i] += s
    return track


# --- Effects ---------------------------------------------------------------

# Button press: a tiny high blip (micro feedback, design.md §25).
save_wav("button.wav", tone(1150, 0.045, vol=0.35))

# Move: a soft rising sweep, like a piece gliding one cell.
save_wav("move.wav", tone(540, 0.12, vol=0.5, sweep_to=720))

# Wall placement: a low knock — sine body plus a seeded noise burst.
rng = random.Random(12)
knock = tone(160, 0.15, vol=0.7)
burst = [
    (rng.random() * 2 - 1) * 0.4 * math.exp(-40 * i / SR) for i in range(1200)
]
save_wav("wall.wav", mix(knock, burst))

# Invalid action: two low pulses — distinct in shape, not just pitch.
pulse = tone(150, 0.09, vol=0.55)
invalid = place(place([], pulse, 0.0), pulse, 0.11)
save_wav("invalid.wav", invalid)

# Turn change: two-note chime (your turn).
turn = place(place([], tone(660, 0.07, vol=0.4), 0.0), tone(880, 0.09, vol=0.4), 0.07)
save_wav("turn.wav", turn)

# Victory: a rising four-note arpeggio inside the 500-1000 ms band.
victory = []
for j, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
    victory = place(victory, tone(f, 0.42, vol=0.45), j * 0.12)
save_wav("victory.wav", victory)

# --- Background music ------------------------------------------------------
# A slow four-chord pad (Am - F - C - G), 1.6 s per chord, sine partials
# only, kept quiet under the effects. The tail is crossfaded into the head
# so the file loops seamlessly.

CHORDS = [
    [110.00, 164.81, 220.00, 261.63],  # Am
    [87.31, 174.61, 220.00, 349.23],  # F
    [130.81, 196.00, 261.63, 329.63],  # C
    [98.00, 196.00, 246.94, 392.00],  # G
]
CHORD_LEN = 1.6
music = []
for chord in CHORDS:
    seg = [0.0] * int(SR * CHORD_LEN)
    for f in chord:
        for i in range(len(seg)):
            t = i / SR
            env = min(1.0, t / 0.3) * min(1.0, (CHORD_LEN - t) / 0.3)
            seg[i] += 0.16 * env * (
                math.sin(2 * math.pi * f * t)
                + 0.3 * math.sin(4 * math.pi * f * t)
                + 0.12 * math.sin(6 * math.pi * f * t)
            )
    music.extend(seg)

# Loop crossfade: fold the last 0.4 s into the first 0.4 s.
fade = int(SR * 0.4)
for i in range(fade):
    w = i / fade
    music[i] = music[i] * w + music[len(music) - fade + i] * (1 - w)
music = music[: len(music) - fade]

tmp = "/tmp/wallforge_music.wav"
frames = b"".join(
    struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in music
)
with wave.open(tmp, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(frames)
print(tmp, len(music) / SR, "s (encode to assets/audio/music.mp3)")
