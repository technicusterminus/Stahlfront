"""Rohe Sprachzeilen (tools/audio/raw) zuschneiden, mit Funkfilter je Fraktion versehen und unter audio/voice ablegen.

Aufruf:  python tools/audio/process_voice.py
Westbund: sauberer Digitalfunk mit leichter Sättigung. Rote Allianz: dumpfes, kräftig verzerrtes Funkgerät.
Schattenfront: raues Notfunkgerät mit Bitreduktion und Rauschen. Alle Zeilen beginnen und enden mit einem kurzen Funkknacken.
"""
import json, math, os, random, struct, wave

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "audio", "voice")
RATE = 24000
random.seed(11)

# (Hochpass Hz, Tiefpass Hz, Übersteuerung, Bits, Rauschen, Funkknacken)
CHAIN = {
    "west": (260.0, 4200.0, 1.3, 16, 0.002, 0.05),
    "red": (330.0, 2700.0, 2.4, 16, 0.006, 0.12),
    "shadow": (380.0, 3200.0, 2.0, 10, 0.012, 0.16),
}


def read(path):
    with wave.open(path, "rb") as w:
        data = w.readframes(w.getnframes())
    n = len(data) // 2
    return [s / 32768.0 for s in struct.unpack("<%dh" % n, data)]


def trim(x, thresh=0.015, pad=0.05):
    first = next((i for i, v in enumerate(x) if abs(v) > thresh), 0)
    last = next((i for i in range(len(x) - 1, -1, -1) if abs(x[i]) > thresh), len(x) - 1)
    p = int(pad * RATE)
    return x[max(0, first - p): min(len(x), last + p)]


def biquad(x, kind, f0, q=0.707):
    w0 = 2 * math.pi * f0 / RATE
    al = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    else:
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = []
    x1 = x2 = y1 = y2 = 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, o
        y.append(o)
    return y


def process(x, faction):
    hp, lp, drive, bits, noise, squelch = CHAIN[faction]
    x = trim(x)
    x = biquad(biquad(x, "hp", hp), "lp", lp)
    x = [math.tanh(v * drive) / math.tanh(drive) for v in x]
    if bits < 16:
        levels = 2 ** (bits - 1)
        x = [round(v * levels) / levels for v in x]
    x = [v + random.uniform(-noise, noise) for v in x]
    # Funkknacken am Anfang und am Ende
    n = int(0.03 * RATE)
    pre = [random.uniform(-1, 1) * squelch * (1 - i / n) for i in range(n)]
    post = [random.uniform(-1, 1) * squelch * (1 - i / n) * 1.3 for i in range(int(0.05 * RATE))]
    x = pre + x + post
    peak = max(abs(v) for v in x) or 1.0
    k = 0.7 / peak
    return [v * k for v in x]


def write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(x), *[max(-32767, min(32767, int(v * 32767))) for v in x]))


def main():
    index = {}
    total = 0
    for f in os.listdir(RAW):
        d = os.path.join(RAW, f)
        if not os.path.isdir(d) or f not in CHAIN:
            continue
        index[f] = {}
        for name in sorted(os.listdir(d)):
            if not name.endswith(".wav"):
                continue
            kind = name.rsplit("_", 1)[0]
            out = process(read(os.path.join(d, name)), f)
            write(os.path.join(OUT, f, name), out)
            index[f][kind] = index[f].get(kind, 0) + 1
            total += 1
    json.dump(index, open(os.path.join(OUT, "index.json"), "w", encoding="utf-8"), indent=1)
    print("Verarbeitet:", total, "Sprachzeilen ->", OUT)


if __name__ == "__main__":
    main()
