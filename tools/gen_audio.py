#!/usr/bin/env python3
"""
Procedural sound effect generator for KESSLER WORKS.
Generates every sound in ../audio as 16-bit mono WAV so the game needs
no external assets.  Re-run any time:  python3 tools/gen_audio.py
Requires: numpy
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = np.random.default_rng(1987)


# ---------------------------------------------------------------- helpers
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def brown(dur):
    w = rng.normal(0, 1, int(dur * SR))
    b = np.cumsum(w)
    b -= np.convolve(b, np.ones(2048) / 2048, mode="same")  # remove drift
    return b / (np.max(np.abs(b)) + 1e-9)


def fft_filter(x, lo=None, hi=None):
    """Brick-ish band filter in the frequency domain (fast)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    m = np.ones_like(f)
    if lo is not None:
        m *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi is not None:
        m *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X * m, n)


def bandpass(x, center, q=4.0):
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    bw = center / q
    m = np.exp(-0.5 * ((f - center) / bw) ** 2)
    return np.fft.irfft(X * m, n)


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def exp_env(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def reverb(x, size=1.5, decay=0.6, wet=0.35):
    n = int(size * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR / decay)
    ir = fft_filter(ir, hi=5000)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    total = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, total) * np.fft.rfft(ir, total), total)
    out = np.zeros(total)
    out[: len(x)] += x * (1 - wet)
    out += y * wet
    return out


def pad_to(x, dur):
    n = int(dur * SR)
    if len(x) >= n:
        return x[:n]
    return np.pad(x, (0, n - len(x)))


def make_loop(x, fade=0.5):
    """Crossfade the tail into the head so the sound loops seamlessly."""
    f = int(fade * SR)
    head = x[:f].copy()
    tail = x[-f:].copy()
    ramp = np.linspace(0, 1, f)
    x = x[:-f].copy()
    x[:f] = head * ramp + tail * (1 - ramp)
    return x


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def distort(x, amt=3.0):
    return np.tanh(x * amt) / np.tanh(amt)


def save(name, x, peak=0.9):
    x = norm(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {name:22s} {len(x) / SR:5.2f}s")


def sine(f, dur, phase=0):
    t = t_axis(dur)
    return np.sin(2 * np.pi * f * t + phase)


def sweep(f0, f1, dur, kind="exp"):
    t = t_axis(dur)
    if kind == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph), f


def saw(f, dur):
    t = t_axis(dur)
    return 2 * ((t * f) % 1.0) - 1


def place(buf, snd, at):
    i = int(at * SR)
    j = min(len(buf), i + len(snd))
    if i < len(buf):
        buf[i:j] += snd[: j - i]


# ---------------------------------------------------------------- ambience
def amb_drone():
    d = 24.0
    t = t_axis(d)
    x = np.zeros_like(t)
    # integer number of cycles over the loop so it wraps cleanly
    for f, a in [(41.25, 0.5), (55.0, 0.35), (61.25, 0.25), (82.5, 0.12), (123.75, 0.05)]:
        x += a * np.sin(2 * np.pi * f * t) * (0.7 + 0.3 * np.sin(2 * np.pi * t / d * 2))
    x += 0.6 * fft_filter(brown(d), hi=180)
    # far away metallic groans
    for at in [3.0, 11.5, 18.0]:
        g, _ = sweep(180, 120, 3.0)
        g = g * env_adsr(len(g), 1.0, 0.5, 0.6, 1.2) * 0.12
        g += 0.05 * bandpass(noise(3.0), 900, 10) * env_adsr(len(g), 1.0, 0.5, 0.6, 1.2)
        place(x, g, at)
    x = reverb(x, 2.5, 1.2, 0.3)[: len(t)]
    save("amb_drone", make_loop(x, 1.0), 0.7)


def amb_machine():
    d = 4.0
    t = t_axis(d)
    x = 0.4 * np.sin(2 * np.pi * 60 * t) + 0.2 * np.sin(2 * np.pi * 120 * t) + 0.1 * np.sin(2 * np.pi * 180 * t)
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * 4 * t)
    x += 0.15 * fft_filter(noise(d), 200, 1200)
    for at in [0.0, 1.0, 2.0, 3.0]:
        n = int(0.25 * SR)
        clank = (np.sin(2 * np.pi * 420 * t_axis(0.25)) + 0.6 * np.sin(2 * np.pi * 1130 * t_axis(0.25))) * exp_env(n, 0.05)
        clank += 0.6 * noise(0.25) * exp_env(n, 0.01)
        place(x, 0.5 * clank, at + 0.02)
    save("amb_machine", make_loop(x, 0.05), 0.6)


def amb_vent():
    d = 8.0
    t = t_axis(d)
    x = fft_filter(noise(d), 300, 1500)
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * t / 4.0)
    whistle = bandpass(noise(d), 700, 20) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0))
    x = x + 2.5 * whistle
    save("amb_vent", make_loop(x, 0.6), 0.5)


def steam_hiss():
    d = 3.0
    x = fft_filter(noise(d), 2500, 9000)
    t = t_axis(d)
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * 7 * t)
    save("steam_hiss", make_loop(x, 0.3), 0.5)


def furnace_roar():
    d = 6.0
    t = t_axis(d)
    x = fft_filter(brown(d), hi=400) * 1.5 + 0.3 * fft_filter(noise(d), 100, 900)
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * t / 3)
    crackle = np.zeros_like(t)
    for _ in range(60):
        at = rng.uniform(0, d - 0.05)
        c = noise(0.02) * exp_env(int(0.02 * SR), 0.004)
        place(crackle, c * rng.uniform(0.3, 1.0), at)
    x += 0.4 * crackle
    save("furnace_roar", make_loop(x, 0.5), 0.6)


def drip():
    d = 0.6
    s, _ = sweep(1800, 600, 0.06)
    s *= exp_env(len(s), 0.02)
    x = pad_to(s, d)
    save("drip", reverb(x, 1.0, 0.4, 0.5)[: int(d * SR * 2)], 0.6)


def generator_loop():
    d = 2.0
    t = t_axis(d)
    # 25 Hz "combustion" pulses
    x = np.zeros_like(t)
    for i in range(int(d * 25)):
        n = int(0.035 * SR)
        p = noise(0.035) * exp_env(n, 0.008) + 0.8 * np.sin(2 * np.pi * 70 * t_axis(0.035)) * exp_env(n, 0.015)
        place(x, p, i / 25)
    x = fft_filter(x, hi=1500)
    x += 0.3 * np.sin(2 * np.pi * 50 * t)
    save("generator_loop", make_loop(x, 0.04), 0.7)


def alarm_loop():
    d = 2.0
    t = t_axis(d)
    f = np.where((t % 1.0) < 0.5, 660, 520)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sign(np.sin(ph)) * 0.4 + np.sin(ph) * 0.6
    x = fft_filter(x, hi=3000)
    x = reverb(x, 1.2, 0.6, 0.3)[: len(t)]
    save("alarm_loop", make_loop(x, 0.05), 0.6)


# ---------------------------------------------------------------- footsteps
def footsteps():
    for i in range(4):
        d = 0.35
        n = int(d * SR)
        thump = np.sin(2 * np.pi * rng.uniform(70, 95) * t_axis(d)) * exp_env(n, 0.03)
        grit = fft_filter(noise(d), 800, 5000) * exp_env(n, rng.uniform(0.02, 0.04))
        scrape = fft_filter(noise(d), 1500, 7000) * env_adsr(n, 0.05, 0.05, 0.2, 0.1) * 0.2
        x = 0.9 * thump + 0.7 * grit + scrape
        save(f"step_concrete_{i + 1}", x, 0.7)
    for i in range(3):
        d = 0.6
        n = int(d * SR)
        f0 = rng.uniform(300, 420)
        ring = sum(np.sin(2 * np.pi * f0 * k * t_axis(d)) * exp_env(n, 0.12 / k) for k in [1, 2.71, 4.13])
        x = 0.4 * ring + 0.8 * fft_filter(noise(d), 600, 6000) * exp_env(n, 0.02)
        x += np.sin(2 * np.pi * 80 * t_axis(d)) * exp_env(n, 0.04)
        save(f"step_metal_{i + 1}", x, 0.7)


# ---------------------------------------------------------------- monster
def monster_step():
    for i in range(2):
        d = 1.2
        n = int(d * SR)
        boom = np.sin(2 * np.pi * rng.uniform(38, 48) * t_axis(d)) * exp_env(n, 0.15)
        clank = sum(np.sin(2 * np.pi * f * t_axis(d)) * exp_env(n, 0.2) for f in rng.uniform(250, 900, 4)) * 0.25
        chain = np.zeros(n)
        for k in range(6):
            c = fft_filter(noise(0.04), 2000, 8000) * exp_env(int(0.04 * SR), 0.01)
            place(chain, c * 0.3, 0.05 + k * rng.uniform(0.03, 0.07))
        x = boom + clank + chain + 0.5 * fft_filter(noise(d), hi=300) * exp_env(n, 0.05)
        save(f"monster_step_{i + 1}", reverb(x, 1.2, 0.5, 0.3), 0.85)


def growl(d, f_base, rough=1.0):
    t = t_axis(d)
    f = f_base * (1 + 0.15 * np.sin(2 * np.pi * 0.7 * t) + 0.05 * rng.normal(0, 1, len(t)).cumsum() / np.sqrt(len(t)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    mod = 1 + rough * np.sin(2 * np.pi * 31 * t)  # rattle
    src = (np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.4 * saw(1, d) * 0) * mod
    src += 0.6 * fft_filter(noise(d), 80, 1200) * mod
    out = bandpass(src, 300, 2) + bandpass(src, 750, 3) * 0.6 + bandpass(src, 2300, 5) * 0.3 + src * 0.2
    return distort(out, 2.5)


def monster_growl():
    for i in range(3):
        d = rng.uniform(2.0, 3.2)
        x = growl(d, rng.uniform(55, 75), 0.8) * env_adsr(int(d * SR), 0.3, 0.3, 0.8, 0.8)
        save(f"monster_growl_{i + 1}", reverb(x, 1.5, 0.7, 0.35), 0.85)


def monster_scream():
    d = 2.4
    n = int(d * SR)
    s1, _ = sweep(260, 900, d * 0.4)
    s2, _ = sweep(900, 340, d * 0.6)
    s = np.concatenate([s1, s2])[:n]
    s = pad_to(s, d)
    voices = s + 0.5 * pad_to(np.concatenate([sweep(273, 950, d * 0.4)[0], sweep(950, 320, d * 0.6)[0]]), d)
    harsh = fft_filter(noise(d), 1000, 6000) * 0.8
    x = distort((voices + harsh) * (1 + 0.8 * np.sin(2 * np.pi * 45 * t_axis(d))), 4)
    x = bandpass(x, 1200, 1.2) + 0.4 * x
    x *= env_adsr(n, 0.05, 0.2, 0.8, 0.9)
    save("monster_scream", reverb(x, 2.0, 0.9, 0.4), 0.95)


def monster_breath():
    d = 3.0
    n = int(d * SR)
    t = t_axis(d)
    x = fft_filter(noise(d), 150, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 2 - np.pi / 2)) ** 2
    x += 0.4 * growl(d, 45, 1.0) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 2 - np.pi / 2)) ** 3
    save("monster_breath", make_loop(x, 0.2), 0.6)


# ---------------------------------------------------------------- stingers / music
def jumpscare():
    d = 2.5
    n = int(d * SR)
    x = np.zeros(n)
    for f in [233, 247, 311, 330, 466, 494, 622]:
        x += saw(f * rng.uniform(0.99, 1.01), d) * 0.2
    x += noise(d) * 0.8
    x += np.sin(2 * np.pi * 40 * t_axis(d)) * 1.2
    x = distort(x, 3) * exp_env(n, 0.6)
    x[: int(0.005 * SR)] *= np.linspace(0, 1, int(0.005 * SR))
    save("jumpscare", reverb(x, 1.5, 0.8, 0.3), 0.98)


def stinger_spotted():
    d = 3.0
    n = int(d * SR)
    x = np.zeros(n)
    for f in [110, 116.5, 164.8, 174.6]:
        x += saw(f, d) * 0.25
    x = fft_filter(x, hi=2500)
    hit = np.sin(2 * np.pi * 50 * t_axis(d)) * exp_env(n, 0.3) * 1.5
    x = (x * env_adsr(n, 0.02, 0.4, 0.5, 1.5)) + hit + fft_filter(noise(d), 300, 3000) * exp_env(n, 0.1)
    save("stinger_spotted", reverb(x, 2.0, 1.0, 0.4), 0.9)


def stinger_low():
    d = 5.0
    n = int(d * SR)
    s, _ = sweep(80, 30, d)
    x = s * env_adsr(n, 1.5, 0.5, 0.8, 2.0)
    x += 0.3 * bandpass(noise(d), 3000, 30) * env_adsr(n, 2.0, 0.5, 0.6, 2.0)  # high violin-like whine
    save("stinger_low", reverb(x, 2.5, 1.2, 0.4), 0.8)


def chase_music():
    bpm = 150
    beat = 60 / bpm
    bars = 4
    d = beat * 4 * bars
    n = int(d * SR)
    x = np.zeros(n)
    for b in range(bars * 4):
        k = np.sin(2 * np.pi * 55 * t_axis(0.3)) * exp_env(int(0.3 * SR), 0.08)
        k += fft_filter(noise(0.3), hi=200) * exp_env(int(0.3 * SR), 0.03)
        place(x, k * 1.2, b * beat)
        if b % 2 == 1:
            m = sum(np.sin(2 * np.pi * f * t_axis(0.5)) for f in [523, 1307, 2011]) * exp_env(int(0.5 * SR), 0.1)
            m += noise(0.5) * exp_env(int(0.5 * SR), 0.02)
            place(x, m * 0.25, b * beat)
        for s in range(4):
            h = fft_filter(noise(0.05), 6000) * exp_env(int(0.05 * SR), 0.01)
            place(x, h * 0.15, b * beat + s * beat / 4)
    t = t_axis(d)
    drone = (saw(55, d) + saw(58.27, d) * 0.7 + saw(82.4, d) * 0.5) * (0.6 + 0.4 * np.sin(2 * np.pi * t * 8 / beat / 4))
    x += fft_filter(drone, hi=900) * 0.25
    sq = np.sign(np.sin(2 * np.pi * 440 * (1 + 0.06 * np.sin(2 * np.pi * t / d * 2)) * t))
    x += fft_filter(sq, hi=1800) * 0.04
    save("chase_music", x, 0.8)


def menu_music():
    d = 32.0
    t = t_axis(d)
    x = np.zeros_like(t)
    for f, ph in [(55, 0), (82.5, 1), (110, 2), (130.8, 0.5), (164.8, 1.3)]:
        x += np.sin(2 * np.pi * f * t + ph) * (0.6 + 0.4 * np.sin(2 * np.pi * t / d * rng.integers(1, 4) + ph))
    x += 0.15 * bandpass(noise(d), 1760, 40) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 3))
    # sparse music box notes (out of tune)
    notes = [659, 587, 523, 494, 523, 440, 415, 440]
    for i, nf in enumerate(notes * 2):
        nd = 2.5
        nn = int(nd * SR)
        nt = (np.sin(2 * np.pi * nf * 0.995 * t_axis(nd)) + 0.3 * np.sin(2 * np.pi * nf * 3.01 * t_axis(nd))) * exp_env(nn, 0.5)
        place(x, nt * 0.25, 1.0 + i * 1.9)
    x = reverb(x, 3.0, 1.6, 0.45)[: len(t)]
    save("menu_music", make_loop(x, 2.0), 0.7)


def ending_music():
    d = 20.0
    t = t_axis(d)
    x = np.zeros_like(t)
    for f in [130.8, 196, 261.6, 329.6]:
        x += np.sin(2 * np.pi * f * t) * env_adsr(len(t), 4.0, 1.0, 0.8, 8.0)
    x += 0.2 * fft_filter(brown(d), hi=300)
    save("ending_music", reverb(x, 3.0, 1.6, 0.5)[: len(t)], 0.6)


# ---------------------------------------------------------------- player / ui
def heartbeat():
    d = 0.7
    n = int(d * SR)
    x = np.zeros(n)
    for at, a in [(0.0, 1.0), (0.22, 0.7)]:
        b = np.sin(2 * np.pi * 52 * t_axis(0.2)) * exp_env(int(0.2 * SR), 0.05)
        place(x, b * a, at)
    save("heartbeat", fft_filter(x, hi=200), 0.9)


def breath_heavy():
    d = 2.4
    t = t_axis(d)
    env = np.zeros_like(t)
    env += np.exp(-((t - 0.35) / 0.18) ** 2)
    env += 0.8 * np.exp(-((t - 1.0) / 0.25) ** 2)
    env += np.exp(-((t - 1.55) / 0.18) ** 2)
    env += 0.8 * np.exp(-((t - 2.15) / 0.22) ** 2)
    x = bandpass(noise(d), 900, 1.5) * env + 0.4 * bandpass(noise(d), 2500, 3) * env
    save("breath_heavy", make_loop(x, 0.1), 0.5)


def flashlight_click():
    d = 0.12
    n = int(d * SR)
    x = noise(d) * exp_env(n, 0.004) + np.sin(2 * np.pi * 2400 * t_axis(d)) * exp_env(n, 0.008) * 0.5
    place(x, noise(0.02) * exp_env(int(0.02 * SR), 0.003) * 0.6, 0.04)
    save("flashlight_click", x, 0.6)


def pickup():
    d = 0.5
    n = int(d * SR)
    x = (np.sin(2 * np.pi * 880 * t_axis(d)) * exp_env(n, 0.1) + 0.6 * np.sin(2 * np.pi * 1318 * t_axis(d)) * np.concatenate([np.zeros(int(0.08 * SR)), exp_env(n - int(0.08 * SR), 0.12)]))
    x += 0.3 * fft_filter(noise(d), 1000, 4000) * exp_env(n, 0.03)
    save("pickup", reverb(x, 0.8, 0.3, 0.3), 0.6)


def paper():
    d = 0.8
    n = int(d * SR)
    x = np.zeros(n)
    for _ in range(14):
        c = fft_filter(noise(0.06), 1500, 8000) * env_adsr(int(0.06 * SR), 0.005, 0.02, 0.5, 0.03)
        place(x, c * rng.uniform(0.3, 1), rng.uniform(0, d - 0.07))
    save("paper", x, 0.6)


def battery():
    d = 0.4
    n = int(d * SR)
    x = noise(d) * exp_env(n, 0.01)
    place(x, (np.sin(2 * np.pi * 1600 * t_axis(0.1)) * exp_env(int(0.1 * SR), 0.03)), 0.12)
    place(x, noise(0.05) * exp_env(int(0.05 * SR), 0.005), 0.2)
    save("battery", x, 0.6)


def ui_click():
    d = 0.08
    n = int(d * SR)
    save("ui_click", np.sin(2 * np.pi * 1200 * t_axis(d)) * exp_env(n, 0.015) + 0.3 * noise(d) * exp_env(n, 0.003), 0.4)


def ui_hover():
    d = 0.06
    n = int(d * SR)
    save("ui_hover", np.sin(2 * np.pi * 700 * t_axis(d)) * exp_env(n, 0.01), 0.25)


def objective():
    d = 1.6
    n = int(d * SR)
    x = np.zeros(n)
    for i, f in enumerate([220, 277, 330]):
        nn = int(1.2 * SR)
        tone = (np.sin(2 * np.pi * f * t_axis(1.2)) + 0.3 * np.sin(2 * np.pi * f * 2 * t_axis(1.2))) * exp_env(nn, 0.4)
        place(x, tone * 0.5, i * 0.12)
    save("objective", reverb(x, 1.5, 0.8, 0.4), 0.55)


# ---------------------------------------------------------------- world interactions
def door_open():
    d = 2.0
    n = int(d * SR)
    t = t_axis(d)
    grind = fft_filter(noise(d), 200, 2500) * env_adsr(n, 0.1, 0.2, 0.7, 0.4)
    squeal_f = 600 + 150 * np.sin(2 * np.pi * 1.3 * t)
    squeal = np.sin(2 * np.pi * np.cumsum(squeal_f) / SR) * env_adsr(n, 0.3, 0.3, 0.4, 0.6) * 0.3
    x = grind + squeal
    clunk = np.sin(2 * np.pi * 70 * t_axis(0.4)) * exp_env(int(0.4 * SR), 0.08) * 1.5 + noise(0.4) * exp_env(int(0.4 * SR), 0.02)
    place(x, clunk, 1.55)
    save("door_open", reverb(x, 1.5, 0.7, 0.3), 0.8)


def door_locked():
    d = 0.9
    n = int(d * SR)
    x = np.zeros(n)
    for at in [0.0, 0.18, 0.33]:
        c = sum(np.sin(2 * np.pi * f * t_axis(0.25)) for f in [190, 530, 1240]) * exp_env(int(0.25 * SR), 0.05) + noise(0.25) * exp_env(int(0.25 * SR), 0.01)
        place(x, c * rng.uniform(0.6, 1), at)
    save("door_locked", reverb(x, 1.0, 0.4, 0.3), 0.7)


def shutter_open():
    d = 6.0
    n = int(d * SR)
    t = t_axis(d)
    rattle = np.zeros(n)
    for i in range(int(d * 18)):
        c = fft_filter(noise(0.04), 400, 5000) * exp_env(int(0.04 * SR), 0.012)
        place(rattle, c * rng.uniform(0.4, 1.0), i / 18 + rng.uniform(0, 0.02))
    motor = 0.4 * np.sin(2 * np.pi * np.cumsum(90 + 30 * t / d) / SR) + 0.2 * fft_filter(noise(d), 80, 400)
    x = (rattle + motor) * env_adsr(n, 0.3, 0.2, 0.9, 0.5)
    clunk = np.sin(2 * np.pi * 55 * t_axis(0.6)) * exp_env(int(0.6 * SR), 0.12) * 2
    place(x, clunk, d - 0.6)
    save("shutter_open", reverb(x, 2.0, 1.0, 0.3), 0.85)


def locker():
    d = 0.9
    n = int(d * SR)
    t = t_axis(d)
    creak_f = 300 + 200 * t / d + 40 * np.sin(2 * np.pi * 9 * t)
    x = np.sin(2 * np.pi * np.cumsum(creak_f) / SR) * env_adsr(n, 0.05, 0.1, 0.6, 0.3) * 0.4
    x = x * (1 + 0.8 * np.sign(np.sin(2 * np.pi * 23 * t)))
    slam = sum(np.sin(2 * np.pi * f * t_axis(0.4)) for f in [180, 410, 960]) * exp_env(int(0.4 * SR), 0.07) + noise(0.4) * exp_env(int(0.4 * SR), 0.01)
    place(x, slam, 0.55)
    save("locker", reverb(x, 1.0, 0.4, 0.25), 0.75)


def fuse_insert():
    d = 1.2
    n = int(d * SR)
    x = np.zeros(n)
    clunk = sum(np.sin(2 * np.pi * f * t_axis(0.3)) for f in [140, 620]) * exp_env(int(0.3 * SR), 0.05) + noise(0.3) * exp_env(int(0.3 * SR), 0.008)
    place(x, clunk, 0.0)
    zap = fft_filter(noise(0.5), 1500) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 60 * t_axis(0.5)))) * exp_env(int(0.5 * SR), 0.15)
    zap += 0.5 * np.sign(np.sin(2 * np.pi * 120 * t_axis(0.5))) * exp_env(int(0.5 * SR), 0.2)
    place(x, zap * 0.6, 0.25)
    save("fuse_insert", x, 0.8)


def electric_zap():
    d = 0.7
    n = int(d * SR)
    x = fft_filter(noise(d), 1000) * (rng.uniform(0, 1, n) > 0.6) * exp_env(n, 0.2)
    x += 0.5 * np.sign(np.sin(2 * np.pi * 120 * t_axis(d))) * exp_env(n, 0.15)
    save("electric_zap", x, 0.7)


def generator_start():
    d = 4.0
    n = int(d * SR)
    x = np.zeros(n)
    # starter cranking
    for i in range(14):
        c = np.sin(2 * np.pi * 90 * t_axis(0.12)) * exp_env(int(0.12 * SR), 0.03) + fft_filter(noise(0.12), 300, 2000) * exp_env(int(0.12 * SR), 0.02)
        place(x, c * 0.7, i * 0.12)
    # sputters
    for at in [1.8, 2.05, 2.2, 2.5]:
        s = noise(0.1) * exp_env(int(0.1 * SR), 0.03) + np.sin(2 * np.pi * 60 * t_axis(0.1)) * exp_env(int(0.1 * SR), 0.05)
        place(x, s, at)
    # catches and runs
    run_d = d - 2.7
    tt = t_axis(run_d)
    rate = 10 + 15 * np.minimum(tt / 0.8, 1)
    ph = np.cumsum(rate) / SR
    run = (np.sin(2 * np.pi * ph) > 0.7).astype(float)
    run = fft_filter(run, hi=800) + 0.3 * np.sin(2 * np.pi * 50 * tt)
    place(x, run * 0.8, 2.7)
    save("generator_start", x, 0.85)


def power_on():
    d = 4.0
    n = int(d * SR)
    x = np.zeros(n)
    thunk = np.sin(2 * np.pi * 45 * t_axis(1.0)) * exp_env(int(1.0 * SR), 0.25) * 2 + noise(1.0) * exp_env(int(1.0 * SR), 0.03)
    place(x, thunk, 0.0)
    t = t_axis(d - 0.2)
    f = 30 + 30 * np.minimum(t / 2.0, 1)
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR)
    place(x, hum * env_adsr(len(t), 1.5, 0.5, 0.7, 1.0) * 0.6, 0.2)
    for k in range(6):  # lights clicking on one by one
        c = noise(0.05) * exp_env(int(0.05 * SR), 0.006) + np.sin(2 * np.pi * 3000 * t_axis(0.05)) * exp_env(int(0.05 * SR), 0.01) * 0.5
        place(x, c * 0.8, 0.8 + k * 0.35)
    save("power_on", reverb(x, 2.0, 1.0, 0.35), 0.9)


def power_down():
    d = 3.0
    n = int(d * SR)
    s, _ = sweep(120, 20, d)
    x = s * exp_env(n, 1.0) + noise(d) * exp_env(n, 0.05)
    save("power_down", reverb(x, 2.0, 1.0, 0.35), 0.8)


def light_burst():
    d = 1.5
    n = int(d * SR)
    x = np.zeros(n)
    pop = noise(0.05) * exp_env(int(0.05 * SR), 0.01) * 1.5
    place(x, pop, 0.0)
    for _ in range(25):  # glass tinkles
        f = rng.uniform(3000, 7000)
        g = np.sin(2 * np.pi * f * t_axis(0.15)) * exp_env(int(0.15 * SR), 0.03)
        place(x, g * rng.uniform(0.1, 0.4), rng.uniform(0.02, 0.6))
    zap = fft_filter(noise(0.3), 1500) * exp_env(int(0.3 * SR), 0.08)
    place(x, zap * 0.6, 0.0)
    save("light_burst", reverb(x, 1.2, 0.6, 0.3), 0.85)


def metal_bang():
    for i in range(3):
        d = 3.0
        n = int(d * SR)
        x = np.zeros(n)
        fs = rng.uniform(120, 900, 6)
        hit = sum(np.sin(2 * np.pi * f * t_axis(d)) * exp_env(n, rng.uniform(0.2, 0.8)) for f in fs) * 0.3
        hit += noise(d) * exp_env(n, 0.02)
        hit += np.sin(2 * np.pi * 50 * t_axis(d)) * exp_env(n, 0.2)
        x += hit
        x = fft_filter(x, hi=2500)  # distant
        save(f"metal_bang_{i + 1}", reverb(x, 3.0, 1.5, 0.6), 0.8)


def chain_rattle():
    d = 2.5
    n = int(d * SR)
    x = np.zeros(n)
    for _ in range(50):
        c = sum(np.sin(2 * np.pi * f * t_axis(0.08)) for f in rng.uniform(2000, 6000, 2)) * exp_env(int(0.08 * SR), 0.015)
        place(x, c * rng.uniform(0.2, 1), rng.uniform(0, d - 0.1) * (0.5 + 0.5 * rng.uniform()))
    save("chain_rattle", reverb(x, 1.5, 0.8, 0.4), 0.6)


def keycard_ok():
    d = 0.6
    x = np.zeros(int(d * SR))
    for i, f in enumerate([1200, 1600]):
        b = np.sign(np.sin(2 * np.pi * f * t_axis(0.12))) * 0.5 * env_adsr(int(0.12 * SR), 0.005, 0.01, 0.8, 0.02)
        place(x, b, i * 0.14)
    save("keycard_ok", fft_filter(x, hi=5000), 0.5)


def keycard_denied():
    d = 0.6
    b = np.sign(np.sin(2 * np.pi * 300 * t_axis(0.45))) * env_adsr(int(0.45 * SR), 0.005, 0.01, 0.8, 0.02)
    save("keycard_denied", fft_filter(pad_to(b, d), hi=3000), 0.5)


def lever():
    d = 1.0
    n = int(d * SR)
    x = fft_filter(noise(d), 300, 3000) * env_adsr(n, 0.05, 0.1, 0.4, 0.3) * 0.4
    clunk = sum(np.sin(2 * np.pi * f * t_axis(0.4)) for f in [95, 380, 870]) * exp_env(int(0.4 * SR), 0.08) + noise(0.4) * exp_env(int(0.4 * SR), 0.01)
    place(x, clunk, 0.45)
    save("lever", reverb(x, 1.2, 0.6, 0.3), 0.8)


# ---------------------------------------------------------------- radio
def radio_click():
    d = 0.35
    n = int(d * SR)
    x = noise(d) * exp_env(n, 0.08) * 0.7
    x = fft_filter(x, 500, 3500)
    place(x, noise(0.01) * 1.5, 0.0)
    save("radio_click", x, 0.6)


def radio_static():
    d = 4.0
    x = fft_filter(noise(d), 600, 4000)
    t = t_axis(d)
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * 3 * t) * np.sin(2 * np.pi * 0.37 * t)
    save("radio_static", make_loop(x, 0.2), 0.4)


def radio_voice(name, d, pitch, seed, creepy=False):
    """Garbled radio speech: pitched buzz through moving formants, chopped into syllables."""
    local = np.random.default_rng(seed)
    n = int(d * SR)
    t = t_axis(d)
    # syllable envelope
    env = np.zeros(n)
    pos = 0.1
    while pos < d - 0.3:
        syl = local.uniform(0.09, 0.22)
        e = env_adsr(int(syl * SR), 0.02, 0.03, 0.8, 0.04)
        place(env, e, pos)
        pos += syl + (local.uniform(0.25, 0.5) if local.uniform() < 0.15 else local.uniform(0.01, 0.06))
    f0 = pitch * (1 + 0.12 * np.sin(2 * np.pi * 1.7 * t) + 0.05 * np.sin(2 * np.pi * 5.3 * t))
    if creepy:
        f0 *= np.linspace(1.0, 0.55, n)
    ph = 2 * np.pi * np.cumsum(f0) / SR
    src = sum(np.sin(k * ph) / k for k in range(1, 25))
    src += 0.2 * noise(d)
    # formants hopping per syllable
    out = np.zeros(n)
    seg = int(0.12 * SR)
    for i in range(0, n, seg):
        f1 = local.uniform(300, 800)
        f2 = local.uniform(900, 2300)
        chunk = src[i:i + seg]
        if len(chunk) < 32:
            continue
        y = bandpass(chunk, f1, 3) + 0.6 * bandpass(chunk, f2, 5)
        out[i:i + len(y)] += y * np.hanning(len(y)) * 2
    out *= env
    out = fft_filter(out, 400, 3200)  # radio band
    out = distort(out * 2.0, 2)
    out += 0.12 * fft_filter(noise(d), 600, 4000)
    if creepy:
        out = reverb(out, 2.0, 1.0, 0.5)[:n]
    save(name, out, 0.6)


def whisper():
    for i in range(3):
        d = 2.5
        n = int(d * SR)
        env = np.zeros(n)
        pos = 0.1
        while pos < d - 0.3:
            syl = rng.uniform(0.1, 0.25)
            place(env, env_adsr(int(syl * SR), 0.04, 0.05, 0.7, 0.06), pos)
            pos += syl + rng.uniform(0.02, 0.15)
        src = noise(d)
        out = np.zeros(n)
        seg = int(0.15 * SR)
        for k in range(0, n, seg):
            chunk = src[k:k + seg]
            if len(chunk) < 32:
                continue
            y = bandpass(chunk, rng.uniform(1500, 3000), 4) + bandpass(chunk, rng.uniform(4000, 7000), 4) * 0.6
            out[k:k + len(y)] += y * np.hanning(len(y))
        out *= env
        save(f"whisper_{i + 1}", reverb(out, 2.0, 1.2, 0.5), 0.5)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("Generating audio into", os.path.normpath(OUT))
    for fn in [amb_drone, amb_machine, amb_vent, steam_hiss, furnace_roar, drip, generator_loop, alarm_loop,
               footsteps, monster_step, monster_growl, monster_scream, monster_breath,
               jumpscare, stinger_spotted, stinger_low, chase_music, menu_music, ending_music,
               heartbeat, breath_heavy, flashlight_click, pickup, paper, battery, ui_click, ui_hover, objective,
               door_open, door_locked, shutter_open, locker, fuse_insert, electric_zap, generator_start,
               power_on, power_down, light_burst, metal_bang, chain_rattle, keycard_ok, keycard_denied, lever,
               radio_click, radio_static, whisper]:
        fn()
    radio_voice("radio_voice_1", 3.0, 118, 1)
    radio_voice("radio_voice_2", 4.5, 112, 2)
    radio_voice("radio_voice_3", 6.0, 120, 3)
    radio_voice("radio_voice_creepy", 5.0, 110, 4, creepy=True)


if __name__ == "__main__":
    main()
