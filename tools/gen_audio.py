#!/usr/bin/env python3
"""All sound effects and music for mario-clone — synthesized, all original.

    python3 tools/gen_audio.py            # everything
    python3 tools/gen_audio.py sfx        # only effects
    python3 tools/gen_audio.py music      # only music + jingles

A tiny NES-style synth: pulse (variable duty), triangle and noise voices
with ADSR-ish envelopes, pitch slides and vibrato. Music is written below in
a compact tracker notation ("E5:2" = E5 for two 16th steps, "r:4" = rest).
The melodies are composed for this project — deliberately NOT the Nintendo
themes (see CLAUDE.md "Sound").

SFX -> assets/sounds/<key>.wav (mono 16-bit 44.1 kHz)
Music/jingles -> assets/music/<key>.ogg (Vorbis via ffmpeg); looping pieces
are rendered so their tails wrap into the start -> seamless loop.
"""
import math
import os
import subprocess
import sys
import wave
import zlib

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SND = os.path.join(ROOT, "assets", "sounds")
MUS = os.path.join(ROOT, "assets", "music")
SR = 44100
rng = np.random.default_rng(1234)

NOTE_IDX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
            "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(name):
    name = name.strip()
    n, o = name[:-1], int(name[-1])
    midi = 12 * (o + 1) + NOTE_IDX[n]
    return 440.0 * 2 ** ((midi - 69) / 12)


# ------------------------------------------------------------------ voices --
def osc(kind, f, n, duty=0.5, f_end=None, vib=0.0, vib_rate=5.5, vib_delay=0.12, phase0=0.0):
    """f may slide linearly to f_end; vib = depth in semitones."""
    t = np.arange(n) / SR
    fr = np.full(n, float(f)) if f_end is None else np.linspace(f, f_end, n)
    if vib > 0:
        ramp = np.clip((t - vib_delay) / 0.1, 0, 1)
        fr = fr * 2 ** (vib * ramp * np.sin(2 * np.pi * vib_rate * t) / 12)
    ph = (phase0 + np.cumsum(fr) / SR) % 1.0
    if kind == "pulse":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "saw":
        return 2 * ph - 1
    raise ValueError(kind)


def noise(n, rate=12000.0, rate_end=None):
    """sample-and-hold noise; `rate` = new random value per second (pitch)."""
    rates = np.full(n, rate) if rate_end is None else np.linspace(rate, rate_end, n)
    idx = np.floor(np.cumsum(rates) / SR).astype(int)
    vals = rng.choice([-1.0, 1.0], size=idx[-1] + 2)
    return vals[idx]


def env(n, a=0.004, d=0.05, s=0.7, r=0.03, hold=None):
    """attack / decay to sustain / release at the end (all seconds)."""
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) if na else e[:na]
    end_d = min(n, na + nd)
    if end_d > na:
        e[na:end_d] = np.linspace(1, s, end_d - na)
    if nr and n > nr:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def decay_env(n, tau):
    t = np.arange(n) / SR
    return np.exp(-t / tau)


def lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def seg(dur):
    return int(dur * SR)


def cat(*parts):
    return np.concatenate(parts)


def silence(dur):
    return np.zeros(seg(dur))


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, x):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x)
    # bitexact: deterministic Ogg stream serial numbers + no encoder-version
    # tag, so re-running the generator does not rewrite unchanged files
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5",
                    "-fflags", "+bitexact", "-flags:a", "+bitexact", path], check=True)
    os.remove(tmp)


# =========================================================================
# SOUND EFFECTS
# =========================================================================
def tone(kind, f, dur, duty=0.5, f_end=None, a=0.002, d=0.04, s=0.6, r=0.03, vib=0.0, vol=1.0):
    n = seg(dur)
    return osc(kind, f, n, duty, f_end, vib=vib) * env(n, a, d, s, r) * vol


def reseed(name):
    """per-piece noise seed: output no longer depends on which other pieces
    were rendered before (e.g. `gen_audio.py music` vs. a full run)"""
    global rng
    rng = np.random.default_rng(zlib.crc32(name.encode()))


def sfx():
    os.makedirs(SND, exist_ok=True)
    reseed("sfx")
    S = {}
    # jumps: rising pulse sweep with a soft tail
    n = seg(0.2)
    S["jump"] = osc("pulse", 330, n, 0.25, 990) * env(n, 0.002, 0.05, 0.6, 0.06) * 0.55
    n = seg(0.24)
    S["jump_big"] = osc("pulse", 220, n, 0.25, 740) * env(n, 0.002, 0.06, 0.6, 0.08) * 0.6
    # stomp: squashy low blip + noise
    n = seg(0.13)
    S["stomp"] = (osc("pulse", 520, n, 0.5, 130) * 0.6 + noise(n, 9000) * 0.25) * decay_env(n, 0.05)
    n = seg(0.12)
    S["kick"] = (osc("pulse", 900, n, 0.25, 260) * 0.5 + noise(n, 14000) * 0.3) * decay_env(n, 0.05)
    n = seg(0.09)
    S["bump"] = (osc("tri", 130, n, f_end=70) * 0.9 + noise(n, 3000) * 0.25) * decay_env(n, 0.04)
    n = seg(0.42)
    S["break"] = lowpass(noise(n, 8000, 1500), 5000) * decay_env(n, 0.11) * 0.9
    # coin: two bright notes (C6 -> G6)
    S["coin"] = cat(tone("pulse", freq("C6"), 0.06, 0.5, s=0.8, r=0.005, vol=0.45),
                    tone("pulse", freq("G6"), 0.38, 0.5, d=0.3, s=0.0, r=0.05, vol=0.45))
    # item sprouting: sliding rising wobble
    n = seg(0.55)
    S["sprout"] = osc("pulse", 200, n, 0.5, 800, vib=2.0, vib_rate=14, vib_delay=0) * env(n, 0.01, 0.1, 0.5, 0.1) * 0.45
    # power-up: rising arpeggio with vibrato
    notes = ["C5", "E5", "G5", "C6", "D5", "F#5", "A5", "D6", "E5", "G#5", "B5", "E6"]
    S["powerup"] = cat(*[tone("pulse", freq(x), 0.055, 0.5, s=0.7, r=0.01, vol=0.42) for x in notes])
    notes = ["E6", "B5", "G#5", "E5", "D6", "A5", "F#5", "D5", "C6", "G5", "E5", "C5"]
    S["powerdown"] = cat(*[tone("pulse", freq(x), 0.05, 0.25, s=0.7, r=0.01, vol=0.42) for x in notes])
    S["oneup"] = cat(*[tone("pulse", freq(x), 0.09, 0.5, s=0.8, r=0.02, vol=0.45)
                       for x in ["E5", "G5", "E6", "C6", "D6", "G6"]], silence(0.05))
    n = seg(0.09)
    S["fireball"] = (osc("pulse", 1200, n, 0.25, 400) * 0.35 + noise(n, 16000) * 0.3) * decay_env(n, 0.04)
    # pipe: three descending pulses
    S["pipe"] = cat(*[tone("pulse", f, 0.1, 0.5, f_end=f * 0.6, s=0.6, r=0.02, vol=0.5) for f in (300, 240, 190)],
                    silence(0.05))
    # flag pole: long falling glissando
    n = seg(1.1)
    S["flagpole"] = osc("pulse", freq("C6"), n, 0.5, freq("C4"), vib=0.4, vib_rate=9, vib_delay=0) \
        * env(n, 0.01, 0.2, 0.6, 0.2) * 0.4
    S["tick"] = tone("pulse", 1760, 0.025, 0.5, s=0.6, r=0.008, vol=0.3)
    n = seg(0.16)
    S["skid"] = lowpass(noise(n, 5000), 3000) * env(n, 0.01, 0.05, 0.6, 0.06) * 0.45
    n1, n2 = seg(0.12), seg(0.3)
    S["hatch"] = cat(lowpass(noise(n1, 9000), 6000) * decay_env(n1, 0.04) * 0.8,
                     osc("pulse", 500, n2, 0.25, 1300, vib=1.0, vib_rate=12, vib_delay=0) * env(n2, 0.01, 0.1, 0.5, 0.08) * 0.45)
    S["dino"] = cat(tone("pulse", freq("G5"), 0.07, 0.25, f_end=freq("C6"), s=0.8, r=0.01, vol=0.5),
                    tone("pulse", freq("C6"), 0.14, 0.25, f_end=freq("E6"), s=0.7, r=0.04, vol=0.5))
    n = seg(0.13)
    S["tongue"] = osc("pulse", 300, n, 0.5, 1400) * env(n, 0.002, 0.04, 0.6, 0.04) * 0.4
    n = seg(0.18)
    S["gulp"] = osc("tri", 420, n, f_end=110) * env(n, 0.005, 0.05, 0.8, 0.05) * 0.9
    S["checkpoint"] = cat(tone("pulse", freq("E6"), 0.08, 0.5, s=0.7, r=0.01, vol=0.4),
                          tone("pulse", freq("A6"), 0.3, 0.5, d=0.25, s=0.0, r=0.05, vol=0.4))
    hurry = []
    for rep in range(2):
        for x in ["E5", "G5", "C6", "E5", "G5", "C6", "D6", "C6"]:
            hurry.append(tone("pulse", freq(x), 0.07, 0.25, s=0.8, r=0.01, vol=0.45))
    S["hurry"] = cat(*hurry)
    S["pause"] = cat(tone("pulse", freq("E6"), 0.06, 0.5, s=0.8, r=0.01, vol=0.35), silence(0.03),
                     tone("pulse", freq("C6"), 0.06, 0.5, s=0.8, r=0.01, vol=0.35))
    # double jump: two quick rising chirps (no noise -> rng order unchanged)
    S["jump2"] = cat(tone("pulse", 520, 0.06, 0.125, f_end=1040, s=0.7, r=0.01, vol=0.45),
                     tone("pulse", 780, 0.12, 0.125, f_end=1560, d=0.05, s=0.5, r=0.04, vol=0.45))
    # swim stroke: soft bubbly rising blip (no noise)
    n = seg(0.12)
    S["swim"] = osc("tri", 380, n, f_end=820) * env(n, 0.004, 0.04, 0.5, 0.05) * 0.8
    # ghost house (v1.4; appended: earlier effects keep their noise)
    n1, n2 = seg(0.42), seg(0.14)
    S["door"] = cat(osc("pulse", 170, n1, 0.125, 250, vib=2.5, vib_rate=17, vib_delay=0) * env(n1, 0.02, 0.1, 0.6, 0.08) * 0.4,
                    (osc("tri", 110, n2, f_end=55) * 0.9 + noise(n2, 1500) * 0.2) * decay_env(n2, 0.05))
    n = seg(0.6)
    S["ghost"] = osc("tri", 560, n, f_end=300, vib=1.2, vib_rate=6, vib_delay=0) * env(n, 0.08, 0.1, 0.7, 0.2) * 0.8
    rattle = []
    for k in range(6):
        n = seg(0.022)
        rattle.append(lowpass(noise(n, 9000 - k * 600), 7000) * decay_env(n, 0.008) * 0.9)
        rattle.append(silence(0.028 + 0.004 * k))
    S["bones"] = cat(*rattle)
    for k, x in S.items():
        write_wav(os.path.join(SND, k + ".wav"), norm(x, 0.85))
    print("  %d sound effects -> assets/sounds/" % len(S))


# =========================================================================
# MUSIC
# =========================================================================
class Song:
    def __init__(self, bpm, steps_per_beat=4):
        self.step = 60.0 / bpm / steps_per_beat
        self.tracks = []

    def track(self, kind, notes, vol, duty=0.5, legato=0.9, vib=0.0, a=0.004, d=0.06, s=0.6, r=0.03,
              octave=0, echo=0.0):
        self.tracks.append(dict(kind=kind, notes=notes, vol=vol, duty=duty, legato=legato, vib=vib,
                                a=a, d=d, s=s, r=r, octave=octave, echo=echo))

    def drums(self, pattern, vol):
        self.tracks.append(dict(kind="drums", notes=pattern, vol=vol))

    def render(self, loop=True):
        total_steps = max(sum(int(tok.split(":")[1]) if ":" in tok else 1 for tok in tr["notes"].split())
                          for tr in self.tracks)
        length = int(total_steps * self.step * SR)
        out = np.zeros(length + SR * 2)
        for tr in self.tracks:
            if tr["kind"] == "drums":
                self._drums(out, tr)
                continue
            pos = 0.0
            for tok in tr["notes"].split():
                name, steps = (tok.split(":") + ["1"])[:2]
                dur = int(steps) * self.step
                if name not in ("r", "-"):
                    f = freq(name) * 2 ** tr["octave"]
                    n = int(dur * tr["legato"] * SR)
                    x = osc("tri" if tr["kind"] == "tri" else "pulse", f, n, tr["duty"],
                            vib=tr["vib"] if dur > 0.2 else 0.0)
                    x *= env(n, tr["a"], tr["d"], tr["s"], tr["r"]) * tr["vol"]
                    i = int(pos * SR)
                    out[i:i + n] += x
                    if tr["echo"]:
                        j = i + int(self.step * 3 * SR)
                        out[j:j + n] += x * tr["echo"]
                pos += dur
        if loop:
            tail = out[length:]
            out = out[:length]
            out[:len(tail)] += tail[:length]
        else:
            nz = np.nonzero(np.abs(out) > 1e-4)[0]
            out = out[: (nz[-1] + 1 if len(nz) else length) + seg(0.05)]
        return norm(lowpass(out, 9000), 0.8)

    def _drums(self, out, tr):
        # pattern chars per 16th step: K kick, S snare, h hat, . rest
        pos = 0.0
        for ch in tr["notes"].replace(" ", "").replace("|", ""):
            i = int(pos * SR)
            if ch == "K":
                n = seg(0.12)
                x = (osc("tri", 150, n, f_end=45) * 0.9 + noise(n, 2000) * 0.2) * decay_env(n, 0.05)
            elif ch == "S":
                n = seg(0.14)
                x = (noise(n, 11000) * 0.7 + osc("tri", 220, n, f_end=150) * 0.3) * decay_env(n, 0.05)
            elif ch == "h":
                n = seg(0.04)
                x = noise(n, 22000) * decay_env(n, 0.010) * 0.28
            else:
                x = None
            if x is not None:
                out[i:i + len(x)] += x * tr["vol"]
            pos += self.step


def bars(*b):
    return " ".join(b)


def overworld():
    """'Green Hills' — bright C major, 150 bpm, 16 bars (A + B)."""
    s = Song(150)
    melody = bars(
        "E5:2 G5:2 C6:4 B5:2 G5:2 E5:4",
        "A5:2 C6:2 E6:4 D6:2 C6:2 A5:4",
        "F5:2 A5:2 C6:3 A5:1 G5:2 F5:2 A5:4",
        "G5:4 r:2 D5:2 G5:2 B5:2 D6:4",
        "E6:3 D6:1 C6:2 G5:2 E5:2 G5:2 C6:4",
        "C6:3 B5:1 A5:2 E5:2 C5:2 E5:2 A5:4",
        "D6:2 F6:2 E6:2 D6:2 B5:2 G5:2 D6:4",
        "C6:6 r:2 G5:2 E5:2 C5:4",
        "A5:2 A5:2 r:2 A5:2 C6:2 A5:2 F5:4",
        "B5:2 B5:2 r:2 B5:2 D6:2 B5:2 G5:4",
        "G5:2 B5:2 E6:4 D6:2 B5:2 G5:4",
        "A5:2 C6:2 E6:4 G6:4 E6:4",
        "F6:4 E6:2 D6:2 C6:4 A5:4",
        "B5:4 C6:2 D6:2 G6:4 F6:4",
        "E6:2 C6:2 G5:2 C6:2 E6:4 D6:2 C6:2",
        "D6:4 B5:2 G5:2 A5:2 B5:2 D6:4",
    )
    chords = ["C", "Am", "F", "G", "C", "Am", "DmG", "C", "F", "G", "Em", "Am", "F", "G", "C", "G"]
    roots = {"C": ("C3", "G3"), "Am": ("A2", "E3"), "F": ("F2", "C3"), "G": ("G2", "D3"), "Em": ("E2", "B2"),
             "Dm": ("D3", "A3")}
    thirds = {"C": ("E4", "G4"), "Am": ("C4", "E4"), "F": ("A4", "C5"), "G": ("B4", "D5"), "Em": ("G4", "B4"),
              "Dm": ("F4", "A4")}
    bass, harm_a, harm_b = [], [], []
    for c in chords:
        halves = [c] * 2 if c != "DmG" else ["Dm", "G"]
        for h in halves:
            r, f5 = roots[h]
            oct_up = r[:-1] + str(int(r[-1]) + 1)
            bass.append("%s:2 %s:2 %s:2 %s:2" % (r, oct_up, f5, oct_up))
            t1, t2 = thirds[h]
            harm_a.append("r:2 %s:2 r:2 %s:2" % (t1, t1))
            harm_b.append("r:2 %s:2 r:2 %s:2" % (t2, t2))
    s.track("pulse", melody, 0.34, duty=0.25, legato=0.88, vib=0.25, d=0.08, s=0.7)
    s.track("pulse", melody, 0.10, duty=0.5, legato=0.8, s=0.5, echo=0.0, octave=-1)
    s.track("pulse", " ".join(harm_a), 0.12, duty=0.5, legato=0.5, d=0.03, s=0.4)
    s.track("pulse", " ".join(harm_b), 0.10, duty=0.25, legato=0.5, d=0.03, s=0.4)
    s.track("tri", " ".join(bass), 0.55, legato=0.85, s=0.9)
    s.drums(("K.h.S.h.K.hKS.h." * 16), 0.35)
    return s.render(loop=True)


def cave():
    """'Coin Cave' — A minor, 118 bpm, mysterious walking bass + echoing lead."""
    s = Song(118)
    bass_bar = ["A2:2 E3:2 A3:2 E3:2 G2:2 D3:2 G3:2 D3:2", "F2:2 C3:2 F3:2 C3:2 E2:2 B2:2 E3:2 G#3:2"]
    bass = " ".join(bass_bar * 4)
    melody = bars(
        "r:4 E5:2 A5:2 C6:4 B5:2 A5:2", "G#5:6 E5:2 B5:4 r:4",
        "r:4 E5:2 A5:2 C6:4 D6:2 E6:2", "D6:4 C6:2 B5:2 A5:4 r:4",
        "F5:2 A5:2 C6:4 A5:2 C6:2 F6:4", "E6:4 D6:2 C6:2 B5:4 G#5:4",
        "A5:2 C6:2 E6:4 D6:2 C6:2 B5:2 G#5:2", "A5:8 r:8",
    )
    s.track("pulse", melody, 0.3, duty=0.25, legato=0.7, vib=0.3, d=0.1, s=0.5, echo=0.45)
    s.track("tri", bass, 0.6, legato=0.8, s=0.9)
    s.drums(("K...h...K.h.h..." * 8), 0.25)
    return s.render(loop=True)


def star():
    """'Star Power' — F major, 184 bpm, driving 8 bars."""
    s = Song(184)
    melody = bars(
        "F5:2 A5:2 C6:2 A5:2 F6:4 C6:4", "D6:2 F6:2 D6:2 C6:2 A5:4 C6:4",
        "Bb5:2 D6:2 F6:2 D6:2 Bb5:4 D6:4", "C6:2 E6:2 G6:2 E6:2 C6:8",
        "F5:2 A5:2 C6:2 A5:2 F6:4 C6:4", "D6:2 F6:2 A6:2 F6:2 D6:4 F6:4",
        "Bb5:2 D6:2 G6:2 F6:2 E6:2 D6:2 C6:4", "E6:2 C6:2 G5:2 E5:2 F5:8",
    )
    bass = " ".join(["F2:2 F3:2"] * 8 + ["D2:2 D3:2"] * 8 + ["Bb1:2 Bb2:2"] * 8 + ["C2:2 C3:2"] * 8) * 1
    bass = bass + " " + bass
    s.track("pulse", melody, 0.34, duty=0.5, legato=0.85, d=0.05, s=0.7)
    s.track("pulse", melody, 0.12, duty=0.125, legato=0.6, octave=-1, s=0.5)
    s.track("tri", bass, 0.55, legato=0.8, s=0.9)
    s.drums(("KhShKhShKhShKhSh" * 8), 0.3)
    return s.render(loop=True)


def title():
    """Title theme — G major, 112 bpm, warm and heroic, 8 bars."""
    s = Song(112)
    melody = bars(
        "D5:4 G5:4 B5:6 A5:2", "G5:4 D6:8 B5:4",
        "C6:4 B5:2 A5:2 G5:4 E5:4", "F#5:4 A5:4 D6:8",
        "D5:4 G5:4 B5:6 D6:2", "E6:6 D6:2 C6:4 A5:4",
        "B5:4 G5:2 A5:2 B5:2 C6:2 A5:4", "G5:12 r:4",
    )
    prog = ["G", "Em", "C", "D", "G", "C", "D", "G"]
    arp = {"G": "G3 B3 D4 B3", "Em": "E3 G3 B3 G3", "C": "C3 E3 G3 E3", "D": "D3 F#3 A3 F#3"}
    arps = " ".join(" ".join(n + ":2" for n in (arp[c] + " " + arp[c]).split()) for c in prog)
    bass = " ".join({"G": "G2:8 D3:8", "Em": "E2:8 B2:8", "C": "C3:8 G2:8", "D": "D3:8 A2:8"}[c] for c in prog)
    s.track("pulse", melody, 0.33, duty=0.25, legato=0.9, vib=0.3, d=0.1, s=0.7)
    s.track("pulse", arps, 0.1, duty=0.5, legato=0.6, s=0.4)
    s.track("tri", bass, 0.5, legato=0.95, s=0.9)
    s.drums(("K.......S.......K...K...S......." * 4), 0.22)
    return s.render(loop=True)


def desert():
    """'Dune Drift' — D phrygian dominant, 132 bpm, 16 bars (8 + repeat
    with the lead doubled an octave lower)."""
    s = Song(132)
    melody = bars(
        "D5:2 Eb5:2 F#5:4 G5:2 F#5:2 Eb5:4", "D5:2 Eb5:2 F#5:2 A5:2 G5:4 F#5:4",
        "A5:2 Bb5:2 A5:2 G5:2 F#5:2 G5:2 A5:4", "G5:2 F#5:2 Eb5:2 F#5:2 D5:8",
        "D6:3 C6:1 Bb5:2 A5:2 G5:2 A5:2 Bb5:4", "A5:3 G5:1 F#5:2 Eb5:2 F#5:4 G5:4",
        "A5:2 Bb5:2 C6:2 Bb5:2 A5:2 G5:2 F#5:2 G5:2", "F#5:2 Eb5:2 D5:4 r:8",
    )
    melody = melody + " " + melody
    prog = ["D", "D", "G", "D", "Bb", "Eb", "C", "D"] * 2
    roots = {"D": "D2 A2 D3 A2", "G": "G2 D3 G3 D3", "Bb": "Bb1 F2 Bb2 F2", "Eb": "Eb2 Bb2 Eb3 Bb2",
             "C": "C2 G2 C3 G2"}
    thirds = {"D": ("F#4", "A4"), "G": ("G4", "Bb4"), "Bb": ("D4", "F4"), "Eb": ("Eb4", "G4"), "C": ("C4", "E4")}
    bass = " ".join(" ".join(n + ":2" for n in (roots[c] + " " + roots[c]).split()) for c in prog)
    harm = " ".join("r:2 %s:2 r:2 %s:2 r:2 %s:2 r:2 %s:2" % (thirds[c] * 2) for c in prog)
    s.track("pulse", melody, 0.32, duty=0.25, legato=0.85, vib=0.35, d=0.08, s=0.65)
    s.track("pulse", " ".join(["r:128"] + melody.split()[len(melody.split()) // 2:]), 0.11,
            duty=0.5, legato=0.8, s=0.5, octave=-1)
    s.track("pulse", harm, 0.1, duty=0.5, legato=0.45, d=0.03, s=0.4)
    s.track("tri", bass, 0.55, legato=0.8, s=0.9)
    s.drums(("K..hK.S.K..hKhS." * 16), 0.3)
    return s.render(loop=True)


def snow():
    """'Frosty Peaks' — F major waltz (3/4), 138 bpm, 16 bars, bell lead."""
    s = Song(138)
    melody = bars(
        "C6:4 A5:4 F5:4", "G5:4 A5:2 Bb5:2 C6:4", "D6:4 C6:4 A5:4", "G5:8 r:4",
        "A5:4 F5:4 C5:4", "D5:4 E5:2 F5:2 G5:4", "A5:4 G5:4 E5:4", "F5:8 r:4",
        "F6:4 E6:4 D6:4", "C6:4 A5:2 Bb5:2 C6:4", "Bb5:4 A5:4 G5:4", "A5:8 r:4",
        "D6:4 C6:4 Bb5:4", "A5:4 G5:2 F5:2 E5:4", "G5:4 F5:4 E5:4", "F5:8 r:4",
    )
    prog = ["F", "C", "Dm", "C", "F", "Bb", "C", "F", "Dm", "F", "Gm", "F", "Bb", "C", "C", "F"]
    roots = {"F": ("F2", "C3"), "C": ("C2", "G2"), "Dm": ("D2", "A2"), "Bb": ("Bb1", "F2"), "Gm": ("G2", "D3")}
    thirds = {"F": ("A4", "C5"), "C": ("G4", "C5"), "Dm": ("F4", "A4"), "Bb": ("F4", "Bb4"), "Gm": ("G4", "Bb4")}
    bass = " ".join("%s:6 %s:6" % roots[c] for c in prog)
    pah_a = " ".join("r:4 %s:4 %s:4" % (thirds[c][0], thirds[c][0]) for c in prog)
    pah_b = " ".join("r:4 %s:4 %s:4" % (thirds[c][1], thirds[c][1]) for c in prog)
    s.track("pulse", melody, 0.3, duty=0.125, legato=0.7, vib=0.2, a=0.002, d=0.18, s=0.3, echo=0.35)
    s.track("tri", melody, 0.14, legato=0.5, s=0.4, octave=1)
    s.track("pulse", pah_a, 0.09, duty=0.5, legato=0.4, d=0.03, s=0.4)
    s.track("pulse", pah_b, 0.08, duty=0.25, legato=0.4, d=0.03, s=0.4)
    s.track("tri", bass, 0.5, legato=0.9, s=0.9)
    s.drums(("K.h.h.h.h.h." * 16), 0.2)
    return s.render(loop=True)


def sky():
    """'Cloud Nine' — airy D major with a Lydian G# (the E chord), 124 bpm,
    16 bars: harp-like 16th arpeggios, singing lead with echo, soft bass."""
    s = Song(124)
    melody = bars(
        "F#5:4 A5:4 D6:6 C#6:2", "B5:4 G#5:4 E5:6 F#5:2", "D6:4 C#6:2 B5:2 F#5:8", "G5:4 A5:4 B5:4 D6:4",
        "F#5:4 A5:4 D6:6 E6:2", "F#6:4 E6:2 D6:2 B5:8", "C#6:4 A5:4 F#5:4 A5:4", "E5:8 A5:4 C#6:4",
        "D6:6 B5:2 G5:8", "E6:6 C#6:2 A5:8", "F#6:4 E6:4 C#6:4 A5:4", "B5:6 C#6:2 D6:8",
        "B5:4 D6:4 G6:4 F#6:4", "E6:4 D6:4 B5:4 G#5:4", "A5:4 B5:4 C#6:4 E6:4", "D6:12 r:4",
    )
    prog = ["D", "E", "Bm", "G", "D", "E", "F#m", "A", "G", "A", "F#m", "Bm", "G", "E", "A", "D"]
    tones = {"D": ["D4", "F#4", "A4", "D5"], "E": ["E4", "G#4", "B4", "E5"], "Bm": ["B3", "D4", "F#4", "B4"],
             "G": ["G3", "B3", "D4", "G4"], "F#m": ["F#3", "A3", "C#4", "F#4"], "A": ["A3", "C#4", "E4", "A4"]}
    roots = {"D": ("D2", "A2"), "E": ("E2", "B2"), "Bm": ("B1", "F#2"), "G": ("G1", "D2"),
             "F#m": ("F#1", "C#2"), "A": ("A1", "E2")}
    pat = [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 1, 2, 3]
    arp = " ".join(" ".join("%s:1" % tones[c][i] for i in pat) for c in prog)
    bass = " ".join("%s:8 %s:8" % roots[c] for c in prog)
    s.track("pulse", melody, 0.3, duty=0.25, legato=0.85, vib=0.25, d=0.1, s=0.6, echo=0.3)
    s.track("tri", melody, 0.12, legato=0.6, s=0.5, octave=-1)
    s.track("pulse", arp, 0.08, duty=0.125, legato=0.6, a=0.002, d=0.05, s=0.3)
    s.track("tri", bass, 0.45, legato=0.85, s=0.9)
    s.drums(("K..h..h.K..h.hh." * 16), 0.16)
    return s.render(loop=True)


def sea():
    """'Coral Waltz' — dreamy Eb major waltz (3/4), 100 bpm, 16 bars:
    vibrato lead with echo over an oom-pah-pah accompaniment."""
    s = Song(100)
    melody = bars(
        "G5:6 F5:3 Eb5:3", "Bb5:9 G5:3", "Ab5:6 G5:3 F5:3", "Eb5:12",
        "C6:6 Bb5:3 Ab5:3", "G5:6 Eb5:6", "F5:3 G5:3 Ab5:3 C6:3", "Bb5:12",
        "Eb6:6 D6:3 C6:3", "Bb5:6 G5:6", "Ab5:6 F5:3 D5:3", "Eb5:6 G5:6",
        "C6:6 Ab5:3 F5:3", "G5:6 Eb5:3 C5:3", "D5:6 F5:3 Ab5:3", "Eb5:12",
    )
    prog = ["Eb", "Eb", "Ab", "Eb", "Ab", "Eb", "Fm", "Bb", "Eb", "Gm", "Bb", "Eb", "Ab", "Cm", "Bb", "Eb"]
    roots = {"Eb": ("Eb2", "Bb2"), "Ab": ("Ab1", "Eb2"), "Fm": ("F2", "C3"), "Bb": ("Bb1", "F2"),
             "Gm": ("G2", "D3"), "Cm": ("C2", "G2")}
    thirds = {"Eb": ("G4", "Bb4"), "Ab": ("Ab4", "C5"), "Fm": ("Ab4", "C5"), "Bb": ("F4", "Bb4"),
              "Gm": ("G4", "Bb4"), "Cm": ("G4", "C5")}
    bass = " ".join("%s:4 %s:4 %s:4" % (roots[c][0], roots[c][1], roots[c][1]) for c in prog)
    pah_a = " ".join("r:4 %s:4 %s:4" % (thirds[c][0], thirds[c][0]) for c in prog)
    pah_b = " ".join("r:4 %s:4 %s:4" % (thirds[c][1], thirds[c][1]) for c in prog)
    s.track("pulse", melody, 0.3, duty=0.25, legato=0.92, vib=0.35, a=0.01, d=0.12, s=0.65, echo=0.35)
    s.track("tri", melody, 0.12, legato=0.8, s=0.6, octave=-1)
    s.track("pulse", pah_a, 0.08, duty=0.5, legato=0.5, d=0.04, s=0.4)
    s.track("pulse", pah_b, 0.07, duty=0.25, legato=0.5, d=0.04, s=0.4)
    s.track("tri", bass, 0.45, legato=0.7, s=0.9)
    s.drums(("K...h...h..." * 16), 0.08)
    return s.render(loop=True)


def world_map():
    """'Adventure Map' — cheerful C major march, 116 bpm, 8 bars: bouncy
    lead, off-beat chord stabs, walking bass (world map, v1.1)."""
    s = Song(116)
    melody = bars(
        "C5:2 E5:2 G5:4 E5:2 G5:2 C6:4", "A5:2 G5:2 E5:2 C5:2 D5:8",
        "E5:2 G5:2 A5:4 G5:2 E5:2 C5:4", "D5:2 E5:2 F5:2 D5:2 C5:8",
        "F5:4 A5:4 G5:4 E5:4", "F5:2 E5:2 D5:2 C5:2 D5:8",
        "E5:4 G5:4 C6:4 B5:2 A5:2", "G5:2 F5:2 E5:2 D5:2 C5:8",
    )
    prog = ["C", "F", "Am", "G", "F", "G", "C", "C"]
    roots = {"C": ("C3", "G2"), "F": ("F2", "C3"), "Am": ("A2", "E2"), "G": ("G2", "D3")}
    third = {"C": "E4", "F": "A4", "Am": "C5", "G": "B4"}
    bass = " ".join(" ".join(["%s:2 %s:2" % roots[c]] * 4) for c in prog)
    stabs = " ".join(" ".join(["r:2 %s:2" % third[c]] * 4) for c in prog)
    s.track("pulse", melody, 0.3, duty=0.5, legato=0.8, vib=0.15, d=0.06, s=0.6, echo=0.2)
    s.track("pulse", stabs, 0.1, duty=0.25, legato=0.5, d=0.03, s=0.4)
    s.track("tri", bass, 0.5, legato=0.7, s=0.9)
    s.drums(("K...S...K.K.S..." * 8), 0.18)
    return s.render(loop=True)


def castle():
    """'Castle' — tense D minor ostinato, 140 bpm, 8 bars: driving triangle
    bass in 8ths, stabbing chords, a chromatic lead."""
    s = Song(140)
    lead = bars(
        "D5:4 r:2 F5:2 E5:4 C#5:4", "D5:4 r:2 A5:2 G#5:4 A5:4",
        "Bb5:4 A5:2 G5:2 F5:4 E5:4", "F5:2 E5:2 D5:2 C#5:2 D5:8",
        "D6:4 r:2 C6:2 Bb5:4 A5:4", "G5:4 r:2 F5:2 E5:4 D5:4",
        "Eb5:4 D5:2 C#5:2 D5:2 E5:2 F5:2 G5:2", "A5:4 C#5:4 D5:8",
    )
    prog = ["Dm", "Dm", "Bb", "A", "Dm", "Gm", "Eb", "A"]
    root = {"Dm": "D2", "Bb": "Bb1", "A": "A1", "Gm": "G1", "Eb": "Eb2"}
    stab = {"Dm": "F4", "Bb": "D4", "A": "C#4", "Gm": "Bb3", "Eb": "G4"}
    bass = " ".join(" ".join(["%s:2 %s:2" % (root[c], root[c][:-1] + str(int(root[c][-1]) + 1))] * 4) for c in prog)
    stabs = " ".join("%s:1 r:3 %s:1 r:3 r:4 %s:1 r:3" % (stab[c], stab[c], stab[c]) for c in prog)
    s.track("pulse", lead, 0.3, duty=0.25, legato=0.8, vib=0.25, d=0.08, s=0.6, echo=0.25)
    s.track("pulse", stabs, 0.14, duty=0.5, legato=0.9, d=0.04, s=0.3)
    s.track("tri", bass, 0.55, legato=0.7, s=0.9)
    s.drums(("K.hhS.hhK.KhS.hh" * 8), 0.3)
    return s.render(loop=True)


def ghost():
    """'Haunted Waltz' — E minor waltz (3/4), 92 bpm, 16 bars: a wobbly
    lead with long echo, chromatic turns, a thin eerie line an octave up
    (ghost house, v1.4)."""
    s = Song(92)
    melody = bars(
        "B4:3 E5:3 G5:3 F#5:3", "E5:6 B4:6", "C5:3 E5:3 A5:3 G5:3", "F#5:6 D#5:6",
        "E5:3 G5:3 B5:3 A#5:3", "B5:6 G5:6", "E5:3 G5:3 C6:3 B5:3", "A5:6 F#5:3 D#5:3",
        "C6:6 B5:3 A5:3", "G#5:6 A5:6", "B5:3 G5:3 E5:3 D#5:3", "E5:9 r:3",
        "C6:6 A5:3 F#5:3", "D#5:6 F#5:3 A5:3", "G5:3 F#5:3 E5:3 D#5:3", "E5:12",
    )
    prog = ["Em", "Em", "Am", "B7", "Em", "Em", "C", "B7", "Am", "Am", "Em", "Em", "F#o", "B7", "Em", "Em"]
    roots = {"Em": ("E2", "B2"), "Am": ("A1", "E2"), "B7": ("B1", "F#2"), "C": ("C2", "G2"), "F#o": ("F#2", "C3")}
    pah = {"Em": ("G4", "B4"), "Am": ("A4", "C5"), "B7": ("D#4", "A4"), "C": ("E4", "G4"), "F#o": ("A4", "C5")}
    bass = " ".join("%s:4 %s:4 %s:4" % (roots[c][0], roots[c][1], roots[c][1]) for c in prog)
    pah_a = " ".join("r:4 %s:4 %s:4" % (pah[c][0], pah[c][0]) for c in prog)
    pah_b = " ".join("r:4 %s:4 %s:4" % (pah[c][1], pah[c][1]) for c in prog)
    s.track("pulse", melody, 0.28, duty=0.25, legato=0.9, vib=0.6, a=0.02, d=0.12, s=0.65, echo=0.45)
    s.track("tri", melody, 0.07, legato=0.85, vib=0.9, s=0.6, octave=1)
    s.track("pulse", pah_a, 0.07, duty=0.125, legato=0.5, d=0.04, s=0.4)
    s.track("pulse", pah_b, 0.06, duty=0.125, legato=0.5, d=0.04, s=0.4)
    s.track("tri", bass, 0.45, legato=0.7, s=0.9)
    s.drums(("K...h...h..." * 16), 0.06)
    return s.render(loop=True)


def jingle_world():
    """world clear fanfare after the boss"""
    s = Song(150)
    lead = "C5:2 E5:2 G5:2 C6:4 G5:2 C6:4 r:2 D6:2 E6:2 F6:2 G6:6 E6:2 C6:8"
    s.track("pulse", lead, 0.34, duty=0.25, legato=0.9, s=0.7, vib=0.2)
    s.track("pulse", lead, 0.12, duty=0.5, legato=0.9, s=0.5, octave=-1)
    s.track("tri", "C3:8 G2:4 C3:6 B2:4 G2:6 C3:8", 0.55, legato=0.9, s=0.9)
    return s.render(loop=False)


def jingle_clear():
    s = Song(160)
    lead = "G4:1 C5:1 E5:1 G5:1 C6:1 E6:1 G6:4 E6:4 Ab4:1 C5:1 Eb5:1 Ab5:1 C6:1 Eb6:1 Ab6:4 Eb6:4 " \
           "Bb4:1 D5:1 F5:1 Bb5:1 D6:1 F6:1 Bb6:4 Bb6:1 Bb6:1 Bb6:1 C7:12"
    s.track("pulse", lead, 0.35, duty=0.25, legato=0.9, s=0.7, vib=0.2)
    s.track("pulse", lead, 0.12, duty=0.5, legato=0.9, s=0.5, octave=-1)
    s.track("tri", "C3:10 C3:4 Ab2:10 Ab2:4 Bb2:10 Bb2:3 C3:12", 0.55, legato=0.9, s=0.9)
    return s.render(loop=False)


def jingle_death():
    s = Song(120)
    lead = "G5:1 F#5:1 F5:1 E5:1 r:2 C6:3 B5:1 A5:2 F5:2 G5:3 E5:1 C5:2 G4:2 C5:8"
    s.track("pulse", lead, 0.35, duty=0.5, legato=0.85, s=0.7)
    s.track("tri", "r:6 F3:4 D3:4 G2:4 C3:10", 0.5, legato=0.9, s=0.9)
    return s.render(loop=False)


def jingle_gameover():
    s = Song(84)
    lead = "E5:2 D5:2 C5:4 A4:2 B4:2 C5:4 D5:2 B4:2 G4:4 r:2 A4:2 G#4:2 A4:10"
    s.track("pulse", lead, 0.33, duty=0.25, legato=0.9, s=0.7, vib=0.3)
    s.track("tri", "A2:8 F2:8 G2:8 E2:4 A2:12", 0.5, legato=0.95, s=0.9)
    return s.render(loop=False)


def music():
    os.makedirs(MUS, exist_ok=True)
    pieces = {
        "music_overworld": overworld,
        "music_cave": cave,
        "music_star": star,
        "music_title": title,
        "music_desert": desert,
        "music_snow": snow,
        "music_castle": castle,
        "music_sky": sky,
        "music_sea": sea,
        "music_map": world_map,
        "jingle_world": jingle_world,
        "jingle_clear": jingle_clear,
        "jingle_death": jingle_death,
        "jingle_gameover": jingle_gameover,
        "music_ghost": ghost,
    }
    for k, fn in pieces.items():
        reseed(k)
        x = fn()
        write_ogg(os.path.join(MUS, k + ".ogg"), x)
        print("  %-16s %5.1f s" % (k, len(x) / SR))


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "sfx"):
        sfx()
    if what in ("all", "music"):
        music()
