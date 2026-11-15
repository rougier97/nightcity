#!/usr/bin/env python3
"""Generates the placeholder ORIGINAL slow-jazz soundtrack and SFX for
HITMAN: NIGHTCITY 13+. Everything is synthesised from scratch (no samples),
so it is fully original and licence-free. Outputs .ogg files into ../audio.

Run:  python3 tools/gen_audio.py
"""
import numpy as np, subprocess, os, sys, tempfile, wave

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(1949)

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

def midi(name):
    n, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE[n]

def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)

# ------------------------------------------------------------------ DSP utils
def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x); acc = 0.0
    # vectorised-ish one-pole using cumulative trick is unstable; loop in chunks via lfilter replacement
    from itertools import accumulate
    b = 1 - a
    out = np.fromiter(accumulate(x, lambda s, v: a * s + b * v), dtype=np.float64, count=len(x))
    return out

def onepole_fft(x, cutoff, order=1):
    """Fast frequency-domain low-pass (approximating a 1-pole^order)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    H = 1.0 / np.sqrt(1 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(X * H, n)

def highpass_fft(x, cutoff, order=1):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    H = 1.0 - 1.0 / np.sqrt(1 + (f / cutoff) ** (2 * order))
    return np.fft.irfft(X * H, n)

def bandpass_fft(x, lo, hi):
    return highpass_fft(onepole_fft(x, hi, 2), lo, 2)

def reverb(x, seconds=2.4, mix=0.28, damp=3500):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
    ir = onepole_fft(ir, damp)
    ir[: int(0.012 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    L = len(x) + n
    N = 1 << (L - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:L]
    # wrap the tail back to the start so loops are seamless
    tail = wet[len(x):]
    wet = wet[:len(x)].copy()
    wet[: len(tail)] += tail[: len(x)]
    return x * (1 - mix) + wet * mix * 0.9

def env_adsr(n, a=0.005, d=0.1, s=0.7, r=0.08):
    e = np.ones(n)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = max(na, 1)
    e[:na] = np.linspace(0, 1, na)
    if nd > 0:
        e[na:na + nd] = np.linspace(1, s, len(e[na:na + nd]))
        e[na + nd:] = s
    if nr > 0 and nr < n:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e

def add(buf, sig, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    if i + len(sig) > len(buf):
        # wrap around for seamless loops
        first = len(buf) - i
        buf[i:] += sig[:first]
        rest = sig[first:]
        buf[: len(rest)] += rest[: len(buf)]
    else:
        buf[i:i + len(sig)] += sig

# ------------------------------------------------------------------ instruments
def piano(m, dur, vel=0.6, bright=1.0):
    f = hz(m)
    n = int((dur + 1.6) * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    B = 0.00035
    decay = 1.1 + (m - 40) * 0.035
    for k in range(1, 11):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR / 2.2:
            break
        amp = (1.0 / k ** 1.25) * (vel ** (0.4 * (k - 1) / bright + 0.0))
        sig += amp * np.sin(2 * np.pi * fk * t + rng.random() * 0.3) * np.exp(-t * decay * (1 + 0.35 * k))
    # second string, slightly detuned (chorus warmth)
    sig += 0.35 * np.sin(2 * np.pi * f * 1.0018 * t) * np.exp(-t * decay * 1.2)
    att = np.minimum(1, t / 0.004)
    rel = np.ones(n)
    off = int(dur * SR)
    if off < n:
        rel[off:] = np.exp(-(np.arange(n - off) / SR) * 9.0)
    hammer = onepole_fft(rng.standard_normal(n) * np.exp(-t * 90), 2500) * 0.15
    return (sig * att * rel + hammer) * vel * 0.25

def bass(m, dur, vel=0.8):
    f = hz(m)
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for k, a in zip(range(1, 7), [1.0, 0.55, 0.3, 0.16, 0.08, 0.05]):
        sig += a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (1.6 + k * 1.2))
    thump = onepole_fft(rng.standard_normal(n) * np.exp(-t * 60), 400) * 0.6
    att = np.minimum(1, t / 0.008)
    rel = np.ones(n); off = int(dur * SR)
    if off < n:
        rel[off:] = np.exp(-(np.arange(n - off) / SR) * 14)
    return (sig * att * rel + thump) * vel * 0.42

def sax(m, dur, vel=0.6, breathy=0.06, muted=False):
    f = hz(m)
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.4, 0, 1)
    phase = 2 * np.pi * f * np.cumsum(vib) / SR
    sig = np.zeros(n)
    formant = 1300 if muted else 900
    for k in range(1, 16):
        fk = f * k
        if fk > 7000:
            break
        amp = (1 / k) * np.exp(-((fk - formant) / (1100 if not muted else 600)) ** 2) + 0.15 / k ** 2
        sig += amp * np.sin(k * phase)
    breath = bandpass_fft(rng.standard_normal(n), formant * 0.8, formant * 2.5) * breathy
    a = 0.07
    e = np.clip(t / a, 0, 1) * np.clip((dur + 0.2 - t) / 0.2, 0, 1)
    swell = 0.8 + 0.2 * np.clip(t / max(dur, 0.1), 0, 1)
    return (sig + breath) * e * swell * vel * 0.33

def ride(vel=0.4, length=1.6):
    n = int(length * SR)
    t = np.arange(n) / SR
    partials = [3120, 4420, 5280, 6650, 7810, 9050, 10400]
    sig = sum(np.sin(2 * np.pi * p * t + rng.random() * 6) for p in partials) / len(partials)
    noise = highpass_fft(rng.standard_normal(n), 6000, 2) * 0.6
    stick = highpass_fft(rng.standard_normal(n) * np.exp(-t * 400), 3000) * 0.8
    return ((sig * 0.5 + noise) * np.exp(-t * 3.2) + stick) * vel * 0.10

def brush_tap(vel=0.5):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    s = bandpass_fft(rng.standard_normal(n), 1500, 7000) * np.exp(-t * 28)
    return s * vel * 0.18

def brush_sweep(length, vel=0.3):
    n = int(length * SR)
    t = np.arange(n) / SR
    s = bandpass_fft(rng.standard_normal(n), 2000, 8000)
    e = np.sin(np.pi * t / length) ** 1.5
    return s * e * vel * 0.07

def kick_soft(vel=0.5):
    n = int(0.35 * SR); t = np.arange(n) / SR
    f = 60 + 50 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * vel * 0.35

# ------------------------------------------------------------------ harmony
def chord_notes(root, kind, octave_base=52):
    """Rootless jazz voicings around octave_base (midi)."""
    r = NOTE[root]
    shapes = {
        "m9": [3, 7, 10, 14], "m7": [3, 7, 10, 15], "maj9": [4, 7, 11, 14], "maj7": [4, 7, 11, 16],
        "13": [4, 10, 14, 21], "7b9": [4, 10, 13, 19], "m7b5": [3, 6, 10, 15], "7alt": [4, 10, 15, 20],
        "6/9": [4, 9, 14, 19], "m6": [3, 7, 9, 14], "7": [4, 7, 10, 14], "mMaj7": [3, 7, 11, 14],
    }
    base = octave_base + ((r - octave_base) % 12)
    if base > octave_base + 6:
        base -= 12
    return [base + iv for iv in shapes[kind]], r

def bass_root(root, low=36):
    r = NOTE[root]
    m = low + ((r - low) % 12)
    return m

def swing_time(beat, bpm, swing=0.62):
    b = 60.0 / bpm
    whole = int(np.floor(beat)); frac = beat - whole
    if abs(frac - 0.5) < 1e-6:
        frac = swing
    return (whole + frac) * b

# ------------------------------------------------------------------ tracks
def render_track(name, bpm, prog, bars_per_chord_list, sections, length_bars, melody=None,
                 lead="sax", rev=0.3, lp=None, crackle=False):
    pass  # (kept for clarity; the explicit composers below are used)

def compose_ballad(name, piano_only=False, bpm=62, warm_lp=None, crackle=False, melody_on=True, reps=2):
    prog = [("D", "m9"), ("G", "m9"), ("C", "13"), ("F", "maj9"), ("Bb", "maj7"), ("E", "m7b5"), ("A", "7b9"), ("D", "m9"),
            ("G", "m9"), ("C", "13"), ("A", "m7"), ("D", "m9"), ("G", "m7"), ("A", "7alt"), ("D", "m6"), ("A", "7b9")]
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * len(prog) * reps
    buf = np.zeros(int(total * SR) + 1)
    # melody: (bar, beat, midi, beats)
    mel = [(0, 0, "A4", 1.5), (0, 1.5, "F4", 0.5), (0, 2, "E4", 2), (1, 0, "D4", 1), (1, 1, "F4", 1), (1, 2, "Bb4", 2),
           (2, 0, "A4", 3), (2, 3, "G4", 1), (3, 0, "A4", 4),
           (4, 0, "D5", 1.5), (4, 1.5, "C5", 0.5), (4, 2, "A4", 2), (5, 0, "G4", 1), (5, 1, "Bb4", 1), (5, 2, "D5", 2),
           (6, 0, "C#5", 2), (6, 2, "Bb4", 1), (6, 3, "G4", 1), (7, 0, "A4", 4),
           (8, 0, "Bb4", 1), (8, 1, "D5", 1), (8, 2, "F5", 2), (9, 0, "E5", 2), (9, 2, "D5", 1), (9, 3, "Bb4", 1),
           (10, 0, "C5", 2), (10, 2, "A4", 2), (11, 0, "F4", 4), (12, 0, "Bb4", 1.5), (12, 1.5, "A4", 0.5), (12, 2, "G4", 2),
           (13, 0, "C#5", 2), (13, 2, "E5", 2), (14, 0, "D5", 4), (15, 0, "E4", 2), (15, 2, "C#5", 2)]
    for rep in range(reps):
        for i, (root, kind) in enumerate(prog):
            t0 = (rep * len(prog) + i) * bar
            notes, r = chord_notes(root, kind, 54)
            # piano comping: rolled chord on 1, soft re-strike on the 'and' of 2 sometimes
            for j, m in enumerate(notes):
                add(buf, piano(m, bar * 0.95, 0.42 + rng.random() * 0.08, 0.8), t0 + j * 0.025)
            if (i + rep) % 2 == 1:
                for j, m in enumerate(notes[1:]):
                    add(buf, piano(m, beat * 1.2, 0.3, 0.8), t0 + swing_time(2.5, bpm) + j * 0.02)
            if piano_only:
                lm = bass_root(root, 38)
                add(buf, piano(lm, bar * 0.9, 0.5, 0.6), t0)
                add(buf, piano(lm + 12 if kind != "7b9" else lm + 7, beat * 1.5, 0.3, 0.6), t0 + beat * 2)
            else:
                lm = bass_root(root, 38)
                add(buf, bass(lm, beat * 1.9, 0.8), t0)
                fifth = lm + 7 if lm + 7 < 50 else lm - 5
                add(buf, bass(fifth, beat * 1.9, 0.7), t0 + beat * 2)
                for b in range(4):
                    add(buf, brush_sweep(beat * 0.98, 0.35), t0 + b * beat)
                add(buf, brush_tap(0.45), t0 + beat)
                add(buf, brush_tap(0.5), t0 + 3 * beat)
                add(buf, ride(0.25), t0)
                add(buf, ride(0.2), t0 + 2 * beat)
        if melody_on:
            for (bi, bt, nn, ln) in mel:
                t0 = (rep * len(prog) + bi) * bar + swing_time(bt, bpm)
                m = midi(nn) + (12 if piano_only and rep == 1 else 0)
                add(buf, piano(m, ln * beat, 0.62 if rep == 0 else 0.55, 1.3), t0)
    out = reverb(buf, 2.8, 0.32)
    if warm_lp:
        out = onepole_fft(out, warm_lp, 1)
    if crackle:
        n = len(out)
        cr = np.zeros(n)
        idx = rng.integers(0, n, int(total * 14))
        cr[idx] = rng.standard_normal(len(idx)) * 0.25
        cr = highpass_fft(cr, 1500)
        hiss = onepole_fft(rng.standard_normal(n), 6000) * 0.006
        out = out + cr * 0.4 + hiss
    return out

def compose_velvet(bpm=84, reps=2):
    # 12-bar minor blues in C, walking bass, sax melody, ride + brushes
    prog = [("C", "m9"), ("F", "m9"), ("C", "m9"), ("C", "m7"), ("F", "m9"), ("F", "m7"), ("C", "m9"), ("A", "7"),
            ("D", "m7b5"), ("G", "7alt"), ("C", "m9"), ("G", "7alt")]
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * len(prog) * reps
    buf = np.zeros(int(total * SR) + 1)
    scale_tones = {"C": [0, 3, 7, 10], "F": [5, 8, 0, 3], "A": [9, 1, 4, 7], "D": [2, 5, 8, 0], "G": [7, 11, 2, 5]}
    for rep in range(reps):
        for i, (root, kind) in enumerate(prog):
            t0 = (rep * len(prog) + i) * bar
            notes, r = chord_notes(root, kind, 55)
            # Charleston-ish comping
            for j, m in enumerate(notes):
                add(buf, piano(m, beat * 1.0, 0.36, 0.9), t0 + j * 0.012)
            if i % 2 == 0:
                for j, m in enumerate(notes):
                    add(buf, piano(m, beat * 0.6, 0.28, 0.9), t0 + swing_time(1.5, bpm) + j * 0.01)
            else:
                for j, m in enumerate(notes):
                    add(buf, piano(m, beat * 0.8, 0.3, 0.9), t0 + swing_time(2.5, bpm) + j * 0.01)
            # walking bass
            nxt = prog[(i + 1) % len(prog)][0]
            lm = bass_root(root, 36)
            tones = scale_tones.get(root, [0, 3, 7, 10])
            walk = [lm, 36 + ((tones[1] - 36) % 12), 36 + ((tones[2] - 36) % 12)]
            approach = bass_root(nxt, 36) + rng.choice([-1, 1])
            walk.append(approach)
            for b, m in enumerate(walk):
                while m < 33: m += 12
                while m > 48: m -= 12
                add(buf, bass(m, beat * 0.92, 0.75 + (0.1 if b == 0 else 0)), t0 + b * beat)
            # ride: ding, ding-da ding-da
            for b in range(4):
                add(buf, ride(0.3 if b % 2 == 0 else 0.22), t0 + b * beat)
                if b % 2 == 1:
                    add(buf, ride(0.16, 0.8), t0 + swing_time(b + 0.5, bpm))
                add(buf, brush_sweep(beat, 0.25), t0 + b * beat)
            add(buf, brush_tap(0.4), t0 + beat)
            add(buf, brush_tap(0.45), t0 + 3 * beat)
            if i % 4 == 0:
                add(buf, kick_soft(0.35), t0)
    # sax melody (second chorus louder, first sparse)
    mel = [(0, 0.5, "G4", 1.0), (0, 1.5, "Bb4", 0.5), (0, 2, "C5", 2.5), (1, 1, "Ab4", 0.5), (1, 1.5, "G4", 0.5), (1, 2, "F4", 2),
           (2, 0, "Eb4", 1), (2, 1, "G4", 1), (2, 2, "C4", 2), (3, 2, "Bb3", 0.5), (3, 2.5, "C4", 1.5),
           (4, 0.5, "Ab4", 1), (4, 1.5, "C5", 0.5), (4, 2, "Eb5", 2), (5, 0, "D5", 1), (5, 1, "C5", 1), (5, 2, "Ab4", 2),
           (6, 0, "G4", 3), (7, 0, "C#5", 1.5), (7, 1.5, "E4", 0.5), (7, 2, "G4", 2),
           (8, 0, "F4", 1), (8, 1, "Ab4", 1), (8, 2, "C5", 2), (9, 0, "B4", 2), (9, 2, "Ab4", 1), (9, 3, "F4", 1),
           (10, 0, "G4", 1.5), (10, 1.5, "Eb4", 0.5), (10, 2, "C4", 2), (11, 0, "D4", 1), (11, 1, "F4", 1), (11, 2, "B3", 2)]
    for rep in range(reps):
        for (bi, bt, nn, ln) in mel:
            if rep == 0 and bi in (1, 5, 9) and bt < 1.5:
                continue
            t0 = (rep * 12 + bi) * bar + swing_time(bt, bpm)
            add(buf, sax(midi(nn), ln * beat * 0.95, 0.55 if rep == 0 else 0.62), t0)
    out = reverb(buf, 2.2, 0.26)
    return out

def compose_tension(bpm=72, bars=16):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * bars
    buf = np.zeros(int(total * SR) + 1)
    ost = ["E2", "E2", "G2", "F#2", "E2", "B1", "D2", "Eb2"]
    for b in range(bars):
        t0 = b * bar
        for k in range(2):
            m = midi(ost[(b * 2 + k) % len(ost)])
            add(buf, bass(m, beat * 1.8, 0.85), t0 + k * 2 * beat)
        for q in range(4):
            add(buf, brush_tap(0.25 if q % 2 == 0 else 0.15), t0 + swing_time(q + 0.5, bpm))
        add(buf, brush_sweep(bar, 0.25), t0)
        if b % 2 == 0:
            cl = ["E3", "G3", "B3", "F4"] if b % 4 == 0 else ["Eb3", "G3", "C4", "D4"]
            for j, nn in enumerate(cl):
                add(buf, piano(midi(nn), bar * 1.6, 0.32, 0.6), t0 + j * 0.04)
        if b % 4 == 3:
            add(buf, piano(midi("F5"), beat, 0.4, 1.2), t0 + beat * 2.5)
            add(buf, piano(midi("E5"), beat * 2, 0.35, 1.2), t0 + beat * 3)
        if b in (4, 5, 12, 13):
            add(buf, sax(midi("B3") if b < 8 else midi("C4"), bar * 1.8, 0.35, 0.1, muted=True), t0)
        add(buf, ride(0.12, 1.2), t0)
        add(buf, ride(0.1, 1.2), t0 + 2 * beat)
    out = reverb(buf, 3.2, 0.36, 2500)
    return out

# ------------------------------------------------------------------ SFX
def sfx_rain(seconds=16.0, muffled=False):
    n = int(seconds * SR)
    w = rng.standard_normal(n)
    pink = onepole_fft(w, 1200, 1) * 0.6 + onepole_fft(w, 5000, 1) * 0.25
    drops = np.zeros(n)
    idx = rng.integers(0, n, int(seconds * (220 if not muffled else 120)))
    drops[idx] = rng.standard_normal(len(idx))
    drops = bandpass_fft(drops, 1500, 7000) * 1.4
    s = pink + drops * 0.5
    if muffled:
        s = onepole_fft(s, 900, 2) * 1.6
        # occasional heavy drips on the glass
        for k in range(int(seconds * 1.5)):
            i = rng.integers(0, n - 2000)
            tt = np.arange(1500) / SR
            s[i:i + 1500] += np.sin(2 * np.pi * rng.uniform(900, 1600) * tt) * np.exp(-tt * 70) * 0.25
    # loopable: crossfade end into start
    xf = int(0.8 * SR)
    fade = np.linspace(0, 1, xf)
    s[:xf] = s[:xf] * fade + s[-xf:] * (1 - fade)
    s = s[:-xf]
    return s / (np.max(np.abs(s)) + 1e-9) * 0.5

def sfx_thunder():
    n = int(4.5 * SR); t = np.arange(n) / SR
    s = onepole_fft(rng.standard_normal(n), 140, 2) * 6
    crack = highpass_fft(rng.standard_normal(n), 800) * np.exp(-t * 12) * 0.5
    e = np.clip(t / 0.05, 0, 1) * np.exp(-t * 0.9) * (1 + 0.5 * np.sin(2 * np.pi * 1.3 * t))
    return (s * e + crack) * 0.6

def sfx_phone():
    seq = [(0, 0.4), (0.6, 0.4)]
    n = int(3.0 * SR)
    buf = np.zeros(n)
    for st, ln in seq:
        m = int(ln * SR); t = np.arange(m) / SR
        trill = (np.sin(2 * np.pi * 25 * t) > 0).astype(float) * 0.6 + 0.4
        tone = (np.sin(2 * np.pi * 400 * t) + np.sin(2 * np.pi * 450 * t) * 0.8 + 0.3 * np.sin(2 * np.pi * 1350 * t)) * trill
        tone *= np.clip(t / 0.01, 0, 1) * np.clip((ln - t) / 0.02, 0, 1)
        buf[int(st * SR):int(st * SR) + m] += tone * 0.25
    return buf

def tone(f, ln, decay=8.0, vol=0.3, harm=(1.0, 0.3, 0.1)):
    m = int(ln * SR); t = np.arange(m) / SR
    s = sum(a * np.sin(2 * np.pi * f * (k + 1) * t) for k, a in enumerate(harm))
    return s * np.exp(-t * decay) * np.clip(t / 0.003, 0, 1) * vol

def click(vol=0.4, hp=2000, ln=0.03):
    m = int(ln * SR); t = np.arange(m) / SR
    return highpass_fft(rng.standard_normal(m), hp) * np.exp(-t * 300) * vol

def sfx_ui():
    s = np.zeros(int(0.15 * SR)); s[:] += tone(1320, 0.15, 30, 0.12)
    s[:len(click())] += click(0.25)
    return s

def sfx_back():
    s = tone(880, 0.15, 30, 0.1); s[:len(click())] += click(0.2)
    return s

def sfx_cash():
    n = int(1.0 * SR); s = np.zeros(n)
    s[:len(click(0.5, 1000, 0.05))] += click(0.5, 1000, 0.05)
    for i, f in enumerate([2093, 2637, 3136]):
        seg = tone(f, 0.8, 5, 0.12, (1, 0.5, 0.2))
        st = int((0.05 + i * 0.06) * SR)
        s[st:st + len(seg)] += seg[: n - st]
    return s

def sfx_deny():
    m = int(0.35 * SR); t = np.arange(m) / SR
    return (np.sign(np.sin(2 * np.pi * 110 * t)) * 0.08 + np.sin(2 * np.pi * 116 * t) * 0.1) * np.exp(-t * 6)

def sfx_door():
    n = int(1.2 * SR); t = np.arange(n) / SR
    thud = onepole_fft(rng.standard_normal(n), 300, 2) * np.exp(-t * 10) * 3
    creak = np.sin(2 * np.pi * (300 + 80 * np.sin(2 * np.pi * 3 * t)) * t) * np.exp(-((t - 0.45) / 0.25) ** 2) * 0.08
    latch = np.zeros(n); latch[:len(click(0.5, 1500, 0.05))] += click(0.5, 1500, 0.05)
    return thud * 0.4 + creak + latch

def sfx_step():
    m = int(0.18 * SR); t = np.arange(m) / SR
    splash = bandpass_fft(rng.standard_normal(m), 800, 6000) * np.exp(-t * 25)
    heel = onepole_fft(rng.standard_normal(m), 400) * np.exp(-t * 50) * 2
    return (splash * 0.25 + heel * 0.3)

def sfx_safe_tick():
    s = click(0.5, 2500, 0.04); s = s + tone(3400, 0.04, 80, 0.05)
    return s

def sfx_safe_open():
    n = int(1.2 * SR); t = np.arange(n) / SR
    clunk = onepole_fft(rng.standard_normal(n), 500) * np.exp(-t * 15) * 2.5
    ring = tone(220, 1.2, 3, 0.1, (1, 0.6, 0.3, 0.2))
    return clunk * 0.3 + ring

def sfx_alert():
    n = int(1.6 * SR); buf = np.zeros(n)
    for m in [midi("C3"), midi("Db3"), midi("G3"), midi("Ab3"), midi("C4")]:
        p = piano(m, 1.0, 0.8, 1.5); buf[:len(p)] += p[:n]
    s = sax(midi("Gb4"), 0.8, 0.6, 0.1, muted=True); buf[:len(s)] += s
    return reverb(buf, 1.4, 0.3)

def sfx_success():
    n = int(3.0 * SR); buf = np.zeros(n)
    for i, nn in enumerate(["F3", "A3", "C4", "E4", "G4", "A4", "E5"]):
        p = piano(midi(nn), 2.0, 0.55, 1.2); st = int(i * 0.07 * SR)
        buf[st:st + len(p)] += p[: n - st]
    return reverb(buf, 2.0, 0.35)

def sfx_blip():
    m = int(0.05 * SR); t = np.arange(m) / SR
    return bandpass_fft(rng.standard_normal(m), 1200, 4500) * np.exp(-t * 120) * 0.5 + tone(700, 0.05, 90, 0.06)

def sfx_car():
    n = int(3.5 * SR); t = np.arange(n) / SR
    e = np.exp(-((t - 1.6) / 0.7) ** 2)
    hiss = bandpass_fft(rng.standard_normal(n), 300, 3000) * e * 0.6
    f = 70 * (1 + 0.08 * np.tanh((1.6 - t) * 3))
    eng = np.sin(2 * np.pi * np.cumsum(f) / SR) * e * 0.15
    return hiss + eng

def sfx_hangup():
    s = np.zeros(int(0.9 * SR)); c = click(0.4, 800, 0.06); s[:len(c)] += c
    b = tone(480, 0.25, 0.5, 0.08); s[int(0.3 * SR):int(0.3 * SR) + len(b)] += b
    return s

def sfx_takedown():
    n = int(0.9 * SR); t = np.arange(n) / SR
    punch = onepole_fft(rng.standard_normal(n), 260, 2) * np.exp(-t * 22) * 3.0
    cloth = bandpass_fft(rng.standard_normal(n), 900, 4000) * np.exp(-t * 30) * 0.4
    fall = np.zeros(n); st = int(0.38 * SR)
    m = n - st; tt = np.arange(m) / SR
    fall[st:] = onepole_fft(rng.standard_normal(m), 180, 2) * np.exp(-tt * 14) * 2.2
    return punch + cloth + fall

def sfx_vinyl():
    return compose_ballad("x", piano_only=True, melody_on=False)  # unused

# ------------------------------------------------------------------ export
def write(name, x, loop=False, q=4):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * (0.9 if not loop else 0.8)
    pcm = (x * 32767).astype(np.int16)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False).name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), out], check=True)
    os.unlink(tmp)
    print("wrote", out, "%.1fs" % (len(x) / SR))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["all"]
    def want(k): return "all" in which or k in which
    if want("music"):
        write("music_intro", compose_ballad("intro", piano_only=True, bpm=58, reps=2), loop=True)
        write("music_menu", compose_ballad("menu", piano_only=False, bpm=62, reps=2), loop=True)
        write("music_velvet", compose_velvet(), loop=True)
        write("music_tension", compose_tension(), loop=True)
        write("music_safehouse", compose_ballad("safe", piano_only=True, bpm=54, warm_lp=2600, crackle=True, reps=1), loop=True)
    if want("sfx"):
        write("sfx_rain", sfx_rain(), loop=True, q=3)
        write("sfx_rain_inside", sfx_rain(14, muffled=True), loop=True, q=3)
        write("sfx_thunder", sfx_thunder())
        write("sfx_phone", sfx_phone())
        write("sfx_ui", sfx_ui()); write("sfx_back", sfx_back())
        write("sfx_cash", sfx_cash()); write("sfx_deny", sfx_deny())
        write("sfx_door", sfx_door()); write("sfx_step", sfx_step())
        write("sfx_safe_tick", sfx_safe_tick()); write("sfx_safe_open", sfx_safe_open())
        write("sfx_alert", sfx_alert()); write("sfx_success", sfx_success())
        write("sfx_blip", sfx_blip()); write("sfx_car", sfx_car()); write("sfx_hangup", sfx_hangup()); write("sfx_takedown", sfx_takedown())
