"""Geräusche synthetisieren (reines Python): Klick auf Gebäude je Rolle, Bedienelemente, Bau-Platzierung, Einheit fertig.

Aufruf:  python tools/audio/make_sfx.py
Ergebnis: audio/sfx/<name>.wav (22,05 kHz, 16 Bit, mono).
Die Klänge sind klein und kurz gehalten: jedes Gebäude hat seinen eigenen Charakter.
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "audio", "sfx")
random.seed(5)
TAU = math.tau


def n(sec):
    return int(sec * RATE)


def sine(f, sec, amp=1.0, phase=0.0):
    return [amp * math.sin(TAU * f * i / RATE + phase) for i in range(n(sec))]


def sweep(f0, f1, sec, amp=1.0, saw=0.0):
    out, ph = [], 0.0
    N = n(sec)
    for i in range(N):
        f = f0 + (f1 - f0) * i / max(1, N - 1)
        ph += TAU * f / RATE
        v = math.sin(ph)
        if saw:
            v += saw * (2.0 * ((ph / TAU) % 1.0) - 1.0)
        out.append(amp * v)
    return out


def noise(sec, amp=1.0):
    return [amp * random.uniform(-1, 1) for _ in range(n(sec))]


def env(x, attack=0.005, decay=None, hold=0.0):
    """Hüllkurve: Anstieg, optional Halten, dann exponentielles Abklingen (decay in Sekunden bis ~-60 dB)."""
    out = []
    a = max(1, n(attack))
    h = n(hold)
    total = len(x)
    d = decay if decay is not None else total / RATE
    for i, v in enumerate(x):
        if i < a:
            e = i / a
        elif i < a + h:
            e = 1.0
        else:
            e = math.exp(-6.9 * (i - a - h) / (d * RATE))
        out.append(v * e)
    return out


def lowpass(x, f):
    a = 1 - math.exp(-TAU * f / RATE)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def highpass(x, f):
    lp = lowpass(x, f)
    return [v - l for v, l in zip(x, lp)]


def mix(*parts, offsets=None):
    offsets = offsets or [0.0] * len(parts)
    length = max(len(p) + n(o) for p, o in zip(parts, offsets))
    out = [0.0] * length
    for p, o in zip(parts, offsets):
        s = n(o)
        for i, v in enumerate(p):
            out[s + i] += v
    return out


def gain(x, g):
    return [v * g for v in x]


def clip(x, drive=1.0):
    return [math.tanh(v * drive) for v in x]


def save(name, x, peak=0.8):
    m = max(abs(v) for v in x) or 1.0
    k = peak / m
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(x), *[max(-32767, min(32767, int(v * k * 32767))) for v in x]))
    print("ok", name, "%.2f s" % (len(x) / RATE))


def clank(f=420, sec=0.5, amp=1.0):
    """Metallisches Klacken: Rauschstoß plus unharmonische Schwingungen."""
    parts = [env(noise(0.03, 0.9), 0.0005, 0.03)]
    for k, r in enumerate((1.0, 1.58, 2.31, 3.17)):
        parts.append(env(sine(f * r, sec, 0.5 / (k + 1)), 0.0005, sec * 0.8))
    return gain(mix(*parts), amp)


def thud(f=70, sec=0.4, amp=1.0):
    return gain(env(sweep(f * 1.8, f, sec, 1.0), 0.002, sec * 0.7), amp)


# --------------------------------------------------------------- Bedienung
save("ui_click", mix(env(sine(2100, 0.02), 0.0003, 0.02, ), env(sine(820, 0.07, 0.6), 0.0005, 0.06)))
save("place", mix(thud(80, 0.5), clank(300, 0.4, 0.5), env(noise(0.25, 0.3), 0.001, 0.25), offsets=[0, 0.02, 0.02]))
save("ready", mix(env(sine(880, 0.12, 0.6), 0.003, 0.1), env(sine(1320, 0.25, 0.6), 0.003, 0.22), offsets=[0, 0.1]))

# --------------------------------------------------------------- Gebäude
# Hauptquartier: tiefer Schlag, Metallklang, aufsteigender Gong
save("building_hq", mix(thud(55, 0.7, 1.0), clank(520, 0.9, 0.55),
                       env(sweep(330, 660, 0.5, 0.35), 0.02, 0.5), offsets=[0, 0.01, 0.12]))
# Kraftwerk: elektrisches Brummen mit Knistern
hum = mix(sweep(118, 122, 0.7, 0.6, saw=0.4), sine(240, 0.7, 0.25))
trem = [v * (0.65 + 0.35 * math.sin(TAU * 11 * i / RATE)) for i, v in enumerate(hum)]
zaps = [0.0] * n(0.7)
for t in (0.05, 0.19, 0.31, 0.47, 0.58):
    for i, v in enumerate(env(highpass(noise(0.05, 0.9), 2500), 0.0003, 0.05)):
        if n(t) + i < len(zaps):
            zaps[n(t) + i] += v
save("building_power", mix(env(trem, 0.04, 0.9, hold=0.3), zaps))
# Nachschub: zwei Kistenschläge und Gabelstapler-Piepen
box = mix(env(lowpass(noise(0.12, 1.0), 900), 0.001, 0.1), thud(95, 0.25, 0.9))
beep = env(sine(1000, 0.09, 0.45), 0.002, 0.09)
save("building_supply", mix(box, box, beep, beep, offsets=[0, 0.16, 0.38, 0.52]))
# Kaserne: Riegel, Stiefelschlag, kurzer Pfiff
save("building_barracks", mix(clank(900, 0.15, 0.8), clank(650, 0.2, 0.7), thud(110, 0.3, 0.9),
                              env(sweep(1900, 2500, 0.22, 0.4), 0.02, 0.2), offsets=[0, 0.1, 0.16, 0.3]))
# Fabrik: Servo-Surren, Schlag
servo = mix(sweep(180, 820, 0.55, 0.7, saw=0.6), sweep(360, 1640, 0.55, 0.25))
save("building_factory", mix(env(lowpass(servo, 2600), 0.05, 0.5, hold=0.25), clank(300, 0.5, 0.9), offsets=[0, 0.5]))
# Flugfeld: Turbinenheulen, ansteigend und wieder abfallend
spool = mix(sweep(380, 1900, 0.45, 0.5, saw=0.3), highpass(noise(0.85, 0.35), 1500))
fall = sweep(1900, 700, 0.4, 0.5, saw=0.3)
save("building_airfield", mix(env(spool, 0.05, 0.5, hold=0.2), env(fall, 0.01, 0.35), offsets=[0, 0.45]))
# Werft: Schiffshorn und Wasserplatschen
horn = mix(sine(110, 1.0, 0.7), sine(165, 1.0, 0.5), sine(111.2, 1.0, 0.4), sine(220, 1.0, 0.2))
splash = env(lowpass(noise(0.45, 0.9), 1700), 0.01, 0.4)
save("building_dock", mix(env(horn, 0.07, 0.9, hold=0.45), splash, offsets=[0, 0.7]))
# Abwehr: Verschlussklicks und kurzer Antrieb
save("building_defense", mix(clank(1200, 0.12, 0.9), clank(800, 0.12, 0.8),
                             env(lowpass(sweep(150, 500, 0.3, 0.6, saw=0.5), 1800), 0.03, 0.3), offsets=[0, 0.1, 0.18]))
# Forschung: aufsteigende Tonfolge mit Funkeln
arp = []
for k, f in enumerate((523, 659, 784, 1047, 1319)):
    arp.append(env(mix(sine(f, 0.3, 0.6), sine(f * 2, 0.3, 0.2)), 0.003, 0.18))
save("building_tech", mix(*arp, offsets=[0, 0.07, 0.14, 0.21, 0.28]))
# Superwaffe: Bedrohliches Dröhnen mit zwei Alarmrufen
alarm = env(sweep(600, 920, 0.28, 0.5, saw=0.3), 0.01, 0.28)
alarm2 = env(sweep(920, 600, 0.28, 0.5, saw=0.3), 0.01, 0.28)
drone = env(mix(sine(42, 1.3, 0.9), sine(63, 1.3, 0.5), lowpass(noise(1.3, 0.3), 200)), 0.1, 1.2, hold=0.4)
save("building_super", mix(drone, alarm, alarm2, alarm, alarm2, offsets=[0, 0.05, 0.33, 0.61, 0.89]))
