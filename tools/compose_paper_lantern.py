"""Original SL score. Requires Python 3 + NumPy; no samples or network.

Run from any directory. Produces a loopable stereo WAV, editable MIDI, score
and measured audio report in assets/music/. Timing is in quarter-note beats.
"""
from pathlib import Path
import json
import math
import struct
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets" / "music"
RATE, BPM, BARS = 32000, 80, 32
BEAT = 60 / BPM
N = round(BARS * 4 * BEAT * RATE)
RNG = np.random.default_rng(251025)
EVENTS = []

# D major / B minor, with add9 and suspended voicings. Newly written melody.
HARMONY = [
    (38, [62, 66, 69, 76]), (43, [62, 66, 67, 71]),
    (40, [62, 64, 67, 71]), (45, [61, 64, 69, 71]),
    (42, [61, 64, 66, 69]), (35, [61, 62, 66, 69]),
    (43, [62, 66, 69, 71]), (45, [62, 64, 69, 73]),
]
# (offset, MIDI pitch, duration), one list per bar. Rests are intentional.
THEME = [
    [(0, 78, .75), (1, 76, .5), (1.75, 73, 1), (3, 74, .65)],
    [(.5, 71, 1), (2, 74, .5), (2.75, 78, .9)],
    [(0, 76, 1.25), (1.5, 74, .5), (2.5, 71, 1)],
    [(.25, 73, .5), (1, 69, .75), (2.5, 71, .4), (3.25, 73, .55)],
    [(0, 76, .5), (.75, 78, 1.1), (2.5, 73, 1)],
    [(.5, 74, 1.5), (2.5, 73, .5), (3.25, 69, .5)],
    [(0, 71, .75), (1.25, 74, .5), (2, 78, 1.25)],
    [(.5, 76, 1), (2, 73, .75), (3, 69, .6)],
]
BRIDGE = [
    [(0, 81, 1), (1.5, 78, .5), (2.5, 76, 1)],
    [(.25, 78, .5), (1, 74, 1), (2.75, 71, .8)],
    [(0, 79, .75), (1, 78, .5), (2, 76, 1.4)],
    [(.5, 73, .75), (2, 76, .5), (3, 81, .7)],
    [(0, 78, 1.25), (1.75, 76, .5), (2.75, 73, .75)],
    [(.5, 74, .5), (1.5, 78, .75), (2.75, 81, .75)],
    [(0, 79, 1), (1.5, 78, .5), (2.5, 74, 1)],
    [(.5, 76, 1), (2.25, 73, 1.25)],
]


def note(kind, beat, pitch, length, gain, pan=0):
    EVENTS.append(dict(kind=kind, beat=beat, pitch=pitch, length=length,
                       gain=gain, pan=pan))


def arrange():
    for bar in range(BARS):
        part, j = divmod(bar, 8)
        root, chord = HARMONY[j]
        if part == 1 and j < 4:
            root, chord = [HARMONY[5], HARMONY[1], HARMONY[2], HARMONY[3]][j]
        base = bar * 4
        # Plucked accompaniment leaves small breathing spaces under the melody.
        pattern = [0, 2, 1, 3, 2, 1] if part != 3 else [0, 2, 1, 3]
        offsets = [0, .75, 1.5, 2, 2.75, 3.5] if part != 3 else [0, 1, 2, 3]
        for k, (off, idx) in enumerate(zip(offsets, pattern)):
            note("pluck", base + off, chord[idx], .7, .11 if k == 0 else .075,
                 -.25 if k % 2 == 0 else .22)
        note("bass", base, root, 2.7, .17, 0)
        if part in (1, 2):
            note("bass", base + 3, root + 7, .7, .08, 0)
        for k, pitch in enumerate(chord[:3]):
            note("pad", base, pitch - 12, 3.9, .032 if part in (1, 2) else .018,
                 (k - 1) * .5)
        melody = BRIDGE[j] if part == 1 else THEME[j]
        if part == 3:
            melody = melody[:2]  # Return to open space, leaving room for dialogue.
        for off, pitch, length in melody:
            kind = "bell" if part in (0, 3) else "felt"
            note(kind, base + off, pitch, length, .20 if part != 3 else .16, .08)
            if part == 2 and j in (2, 4, 6):
                note("bell", base + off + .025, pitch + 12, length, .028, -.32)
        if part in (1, 2):
            for off in (1, 3):
                note("brush", base + off, 42, .12, .022, -.38)
        if part == 2 and j in (1, 3, 5):
            note("felt", base + 3.5, chord[1] + 12, .35, .08, -.2)


def synth(e):
    kind = e["kind"]
    hold = e["length"] * BEAT
    tail = {"bell": 2.8, "felt": 1.5, "pluck": .65, "bass": .16,
            "pad": .65, "brush": .08}[kind]
    t = np.arange(round((hold + tail) * RATE)) / RATE
    f = 440 * 2 ** ((e["pitch"] - 69) / 12)
    phase = 2 * np.pi * f * t
    if kind == "bell":
        y = (np.sin(phase) * np.exp(-t / 1.25)
             + .25 * np.sin(phase * 2) * np.exp(-t / .4)
             + .075 * np.sin(phase * 3) * np.exp(-t / .15))
        attack = .009
    elif kind == "felt":
        y = sum((1 / h**1.65) * np.sin(phase * h)
                * np.exp(-t * (1.05 + h * .30)) for h in range(1, 7))
        attack = .008
    elif kind == "pluck":
        y = sum(((-1)**(h + 1) / h**1.5) * np.sin(phase * h)
                * np.exp(-t * (2.8 + h * .9)) for h in range(1, 9))
        attack = .004
    elif kind == "pad":
        y = (.8 * np.sin(phase) + .13 * np.sin(phase * 2 + .03 * np.sin(t * 4))
             + .07 * np.sin(phase * 3))
        attack = .45
    elif kind == "bass":
        y = np.sin(phase) + .19 * np.sin(phase * 2)
        y *= np.exp(-t / 1.7)
        attack = .015
    else:
        y = RNG.normal(0, 1, len(t))
        y = np.convolve(y, np.ones(7) / 7, mode="same") * np.exp(-t / .025)
        attack = .003
    y *= np.minimum(t / attack, 1)
    # Smooth note release; every tail is wrapped into the next loop.
    release = np.clip((hold + tail - t) / tail, 0, 1)
    y *= release * release * (3 - 2 * release)
    return y * e["gain"]


def vlq(n):
    b = [n & 127]
    while n >> 7:
        n >>= 7
        b.insert(0, (n & 127) | 128)
    return bytes(b)


def write_midi(path):
    tracks = []
    tempo = b"\x00\xff\x51\x03" + round(60000000 / BPM).to_bytes(3, "big")
    tracks.append(tempo + b"\x00\xff\x58\x04\x04\x02\x18\x08\x00\xff\x2f\x00")
    for channel, (kind, program) in enumerate(
            [("bell", 10), ("felt", 0), ("pluck", 24), ("bass", 32), ("pad", 89)]):
        events = []
        for e in EVENTS:
            if e["kind"] != kind:
                continue
            start, end = round(e["beat"] * 480), round((e["beat"] + e["length"]) * 480)
            velocity = max(20, min(110, round(55 + 22 * math.log2(e["gain"] / .1))))
            events.extend([(start, 1, bytes([0x90 + channel, e["pitch"], velocity])),
                           (end, 0, bytes([0x80 + channel, e["pitch"], 0]))])
        name = kind.encode()
        data = b"\x00\xff\x03" + vlq(len(name)) + name + bytes([0, 0xC0 + channel, program])
        previous = 0
        for tick, _, message in sorted(events):
            data += vlq(tick - previous) + message
            previous = tick
        data += vlq(max(0, BARS * 4 * 480 - previous)) + b"\xff\x2f\x00"
        tracks.append(data)
    path.write_bytes(b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), 480)
                     + b"".join(b"MTrk" + struct.pack(">I", len(t)) + t for t in tracks))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    arrange()
    dry = np.zeros((N, 2), dtype=np.float64)
    for e in EVENTS:
        y = synth(e)
        start = round(e["beat"] * BEAT * RATE)
        pan = (e["pan"] + 1) * np.pi / 4
        stereo = y[:, None] * np.array([np.cos(pan), np.sin(pan)])
        left = min(len(y), N - start)
        dry[start:start + left] += stereo[:left]
        if left < len(y):
            dry[:len(y) - left] += stereo[left:]
    # Circular early reflections preserve room tails across the loop seam.
    mix = dry.copy()
    for delay, gain in [(.119, .12), (.233, .09), (.377, .075), (.541, .055), (.733, .035)]:
        mix += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain
    mix -= np.mean(mix, axis=0)
    mix *= 10 ** (-2 / 20) / np.max(np.abs(mix))
    pcm = np.round(mix * 32767).astype("<i2")
    target = OUT / "paper_lantern.wav"
    with wave.open(str(target), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    write_midi(OUT / "paper_lantern.mid")
    report = dict(title="留白里的灯 / Paper Lantern", bpm=BPM, bars=BARS,
                  seconds=N / RATE, sample_rate=RATE, channels=2,
                  peak_dbfs=float(20 * np.log10(np.max(np.abs(mix)))),
                  rms_dbfs=float(20 * np.log10(np.sqrt(np.mean(mix**2)))),
                  loop_boundary_step=float(np.max(np.abs(mix[-1] - mix[0]))),
                  max_adjacent_step=float(np.max(np.abs(np.diff(mix, axis=0)))),
                  clipped_samples=int(np.sum(np.abs(pcm.astype(np.int32)) >= 32767)),
                  note_events=len(EVENTS), seed=251025)
    assert report["clipped_samples"] == 0
    assert report["loop_boundary_step"] < .01, "Loop seam needs repair"
    (OUT / "paper_lantern.analysis.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    score = dict(title=report["title"], bpm=BPM, meter="4/4", key="D major / B minor",
                 sections=["0–24s: lantern", "24–48s: memory", "48–72s: companionship", "72–96s: blank page"],
                 events=EVENTS)
    (OUT / "paper_lantern.score.json").write_text(json.dumps(score, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
