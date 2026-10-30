"""Rebuild original procedural game audio. Standard library only; no sampled recordings."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'godot/assets/audio'
RATE = 22050
TAU = math.tau

def save(name, samples):
    ROOT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b''.join(struct.pack('<h', round(max(-.95, min(.95, v)) * 32767)) for v in samples))

def tone(name, duration, start, end, gain=.25, noise=0):
    rng = random.Random(name)
    phase = 0
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        phase += TAU * (start + (end-start)*t/duration) / RATE
        envelope = min(1, t/.006) * (1-t/duration)**2
        samples.append(gain * envelope * ((1-noise)*math.sin(phase) + noise*rng.uniform(-1, 1)))
    save(name, samples)

def main():
    # Sparse, soft piano-like synthesized notes; no sustained bass or pad.
    duration = 32
    notes = [523.251,659.255,587.33,783.991,659.255,523.251,440,587.33]
    samples = []
    for i in range(duration*RATE):
        t = i/RATE
        beat = int(t//4)
        local = t%4
        pluck = math.sin(TAU*notes[beat]*local) * math.exp(-local*2) * min(1,local/.02) * .055
        samples.append(pluck)
    save('journey-ambient', samples)
    tone('menu',.07,620,800,.10)
    tone('pipe-turn',.09,430,240,.20,.12)
    tone('success',.42,440,880,.22)
    chime=[]
    for i in range(int(.8*RATE)):
        t=i/RATE
        value=0
        for delay,note in ((0,523.25),(.13,659.25),(.26,783.99)):
            local=t-delay
            if local>=0:value+=math.sin(TAU*note*local)*math.exp(-local*7)*min(1,local/.014)*.085
        chime.append(value)
    save('unlock',chime)
    tone('error',.18,180,110,.18)
    tone('shot',.09,920,280,.13)
    tone('hit',.13,180,65,.22,.55)
    tone('damage',.22,120,55,.22,.35)
    # Soft shoe rustle instead of a pitched tap; smooth both ends and filter hiss.
    rng = random.Random('soft-step')
    filtered = 0.0
    samples = []
    duration = .12
    for i in range(int(duration * RATE)):
        t = i / RATE
        filtered += .12 * (rng.uniform(-1, 1) - filtered)
        envelope = math.sin(math.pi*t/duration)**2
        samples.append(filtered * envelope * .02)
    save('step', samples)

if __name__ == '__main__':
    main()
