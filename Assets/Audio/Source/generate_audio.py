#!/usr/bin/env python3
"""Synthesizes the game's original music and sound effects.

Every file in Assets/Audio/Music and Assets/Audio/Sfx comes from this script,
so the audio can be regenerated or tweaked without any external assets.
Pure Python 3 (no dependencies). Run from the project root:

    python3 Assets/Audio/Source/generate_audio.py           # everything
    python3 Assets/Audio/Source/generate_audio.py sfx       # effects only
    python3 Assets/Audio/Source/generate_audio.py music     # music only
    python3 Assets/Audio/Source/generate_audio.py hit_slash stage_won

Output is 16-bit mono WAV at 32 kHz. Music is written as one seamless loop
(note tails and reverb wrap around), and Godot imports it with a forward loop
(see the .import files next to each track). To use real assets instead,
replace a file with one of the same name, or point the SoundEffect resources
in Ressources/Audio at different streams.
"""

import math
import random
import sys
import wave
from array import array
from pathlib import Path

SAMPLE_RATE = 32000
TAU = math.tau
AUDIO_DIR = Path(__file__).resolve().parents[1]
MUSIC_DIR = AUDIO_DIR / "Music"
SFX_DIR = AUDIO_DIR / "Sfx"
PEAK_LEVEL = 0.89  # -1 dBFS

NOTE_INDEX = {
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
    "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11,
}
CHORDS = {
    "C": (0, "major"), "D": (2, "major"), "Dm": (2, "minor"), "Em": (4, "minor"),
    "F": (5, "major"), "Gm": (7, "minor"), "A": (9, "major"), "Am": (9, "minor"),
    "Bb": (10, "major"), "B": (11, "major"),
}
TRIADS = {"major": (0, 4, 7), "minor": (0, 3, 7)}


# ============================================
# BASICS
# ============================================

def samples_for(duration_seconds):
    return max(1, int(duration_seconds * SAMPLE_RATE))


def note_number(name):
    """'C#5' -> MIDI note number."""
    return NOTE_INDEX[name[:-1]] + (int(name[-1]) + 1) * 12


def note_frequency(midi_note):
    return 440.0 * 2.0 ** ((midi_note - 69) / 12.0)


def silence(duration_seconds):
    return [0.0] * samples_for(duration_seconds)


def noise(sample_count, rng):
    uniform = rng.uniform
    return [uniform(-1.0, 1.0) for _ in range(sample_count)]


def _blep(phase, phase_step):
    """PolyBLEP correction: removes most aliasing from saw / square edges."""
    if phase < phase_step:
        phase /= phase_step
        return phase + phase - phase * phase - 1.0
    if phase > 1.0 - phase_step:
        phase = (phase - 1.0) / phase_step
        return phase * phase + phase + phase + 1.0
    return 0.0


def oscillator(sample_count, start_hz, end_hz=None, kind="sine", duty=0.5,
               vibrato_depth=0.0, vibrato_rate=5.5, vibrato_delay=0.0):
    """A (pitch-swept, exponentially) oscillator without envelope."""
    end_hz = start_hz if end_hz is None else end_hz
    sweep = (end_hz / start_hz) ** (1.0 / sample_count)
    vibrato_start = samples_for(vibrato_delay)
    vibrato_step = TAU * vibrato_rate / SAMPLE_RATE
    output = [0.0] * sample_count
    frequency = start_hz
    phase = 0.0
    dc_offset = 2.0 * duty - 1.0
    sin = math.sin
    for index in range(sample_count):
        current_hz = frequency
        if vibrato_depth and index > vibrato_start:
            current_hz *= 1.0 + vibrato_depth * sin((index - vibrato_start) * vibrato_step)
        step = current_hz / SAMPLE_RATE
        phase += step
        if phase >= 1.0:
            phase -= 1.0
        if kind == "sine":
            value = sin(TAU * phase)
        elif kind == "triangle":
            value = 4.0 * abs(phase - 0.5) - 1.0
        elif kind == "saw":
            value = 2.0 * phase - 1.0 - _blep(phase, step)
        else:  # square / pulse
            value = (1.0 if phase < duty else -1.0) + _blep(phase, step)
            # Narrow pulses aren't centered on zero; remove the offset.
            value -= _blep((phase + 1.0 - duty) % 1.0, step) + dc_offset
        output[index] = value
        frequency *= sweep
    return output


def lowpass(signal, start_hz, end_hz=None, passes=1):
    """One-pole low-pass (per pass ~6 dB/oct), cutoff optionally swept."""
    end_hz = start_hz if end_hz is None else end_hz
    sample_count = len(signal)
    sweep = (end_hz / start_hz) ** (1.0 / max(1, sample_count))
    exp = math.exp
    for _ in range(passes):
        cutoff = start_hz
        state = 0.0
        for index in range(sample_count):
            state += (1.0 - exp(-TAU * cutoff / SAMPLE_RATE)) * (signal[index] - state)
            signal[index] = state
            cutoff *= sweep
    return signal


def highpass(signal, cutoff_hz):
    coefficient = 1.0 - math.exp(-TAU * cutoff_hz / SAMPLE_RATE)
    state = 0.0
    for index in range(len(signal)):
        state += coefficient * (signal[index] - state)
        signal[index] -= state
    return signal


def bandpass(signal, low_hz, high_hz):
    return lowpass(highpass(signal, low_hz), high_hz)


def decay_envelope(signal, attack_seconds, decay_seconds):
    """Linear attack, then exponential decay with time constant decay_seconds."""
    attack = samples_for(attack_seconds)
    decay_factor = math.exp(-1.0 / (decay_seconds * SAMPLE_RATE))
    level = 1.0
    for index in range(len(signal)):
        if index < attack:
            signal[index] *= index / attack
        else:
            signal[index] *= level
            level *= decay_factor
    return signal


def adsr_envelope(signal, gate_samples, attack, decay, sustain, release):
    attack_count = samples_for(attack)
    decay_count = samples_for(decay)
    release_count = samples_for(release)
    held_level = 0.0
    for index in range(len(signal)):
        if index < gate_samples:
            if index < attack_count:
                level = index / attack_count
            elif index < attack_count + decay_count:
                level = 1.0 - (1.0 - sustain) * (index - attack_count) / decay_count
            else:
                level = sustain
            held_level = level
        else:
            level = held_level * max(0.0, 1.0 - (index - gate_samples) / release_count)
        signal[index] *= level
    return signal


def fade_out(signal, fade_seconds):
    fade_count = min(len(signal), samples_for(fade_seconds))
    start = len(signal) - fade_count
    for index in range(fade_count):
        signal[start + index] *= 1.0 - index / fade_count
    return signal


def scaled(signal, gain):
    return [value * gain for value in signal]


def mix_into(destination, source, start_index, gain=1.0, wrap=False):
    """Adds source into destination at start_index (wrap: tails loop to the start)."""
    destination_length = len(destination)
    for offset, value in enumerate(source):
        index = start_index + offset
        if index >= destination_length:
            if not wrap:
                break
            index %= destination_length
        destination[index] += value * gain


def layered(duration_seconds, *parts):
    """Mixes (start_seconds, signal, gain) parts into one buffer."""
    output = silence(duration_seconds)
    for start_seconds, signal, gain in parts:
        mix_into(output, signal, samples_for(start_seconds), gain)
    return output


def reverb(send, room=0.8, damping=0.3, loop=False, tail_seconds=1.2):
    """Small Schroeder reverb. loop=True wraps the tail into the start."""
    source_length = len(send)
    source = send + send if loop else send + [0.0] * samples_for(tail_seconds)
    wet = [0.0] * len(source)
    for delay in (1031, 1123, 1201, 1307):
        buffer = [0.0] * delay
        position = 0
        filtered = 0.0
        for index, value in enumerate(source):
            delayed = buffer[position]
            filtered = delayed * (1.0 - damping) + filtered * damping
            buffer[position] = value + filtered * room
            position += 1
            if position == delay:
                position = 0
            wet[index] += delayed * 0.25
    for delay in (347, 113):
        buffer = [0.0] * delay
        position = 0
        for index in range(len(wet)):
            delayed = buffer[position]
            value = wet[index]
            buffer[position] = value + delayed * 0.5
            wet[index] = delayed - value * 0.5
            position += 1
            if position == delay:
                position = 0
    return wet[source_length:] if loop else wet


def bell(frequency, duration_seconds, decay_seconds=0.35):
    """Inharmonic partials, like a small bell or crystal."""
    sample_count = samples_for(duration_seconds)
    output = [0.0] * sample_count
    for ratio, gain, decay_scale in ((1.0, 1.0, 1.0), (2.76, 0.5, 0.6), (5.4, 0.25, 0.35), (8.93, 0.12, 0.2)):
        partial = decay_envelope(oscillator(sample_count, frequency * ratio), 0.002, decay_seconds * decay_scale)
        mix_into(output, partial, 0, gain)
    return output


def write_wav(path, signal, peak=PEAK_LEVEL):
    loudest = max((abs(value) for value in signal), default=0.0) or 1.0
    gain = peak / loudest
    pcm = array("h", (int(max(-1.0, min(1.0, value * gain)) * 32767.0) for value in signal))
    if sys.byteorder == "big":
        pcm.byteswap()
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(pcm.tobytes())


# ============================================
# SOUND EFFECT BUILDING BLOCKS
# ============================================

def whoosh(rng, duration_seconds, low_hz, high_hz, rise_seconds):
    sample_count = samples_for(duration_seconds)
    signal = bandpass(noise(sample_count, rng), low_hz, high_hz)
    rise = samples_for(rise_seconds)
    for index in range(sample_count):
        if index < rise:
            signal[index] *= index / rise
        else:
            signal[index] *= max(0.0, 1.0 - (index - rise) / (sample_count - rise)) ** 2
    return signal


def boom(rng, duration_seconds, start_hz=110.0, end_hz=38.0, decay_seconds=0.14):
    sample_count = samples_for(duration_seconds)
    body = decay_envelope(oscillator(sample_count, start_hz, end_hz), 0.003, decay_seconds)
    rumble = decay_envelope(lowpass(noise(sample_count, rng), 1200.0, 180.0, passes=2), 0.002, decay_seconds * 0.9)
    crack = decay_envelope(highpass(noise(samples_for(0.05), rng), 2000.0), 0.0005, 0.012)
    return layered(duration_seconds, (0.0, body, 1.0), (0.0, rumble, 1.6), (0.0, crack, 0.5))


def chime_note(frequency, duration_seconds, kind="square", duty=0.25, decay_seconds=0.12, cutoff_hz=5000.0):
    sample_count = samples_for(duration_seconds)
    tone = lowpass(oscillator(sample_count, frequency, kind=kind, duty=duty), cutoff_hz)
    return decay_envelope(tone, 0.002, decay_seconds)


def brass_note(frequency, duration_seconds, release_seconds=0.12, cutoff_hz=2600.0, vibrato_depth=0.004):
    gate = samples_for(duration_seconds)
    sample_count = gate + samples_for(release_seconds)
    tone = oscillator(sample_count, frequency, kind="saw", vibrato_depth=vibrato_depth, vibrato_delay=0.1)
    second = oscillator(sample_count, frequency * 1.004, kind="saw")
    mixed = [first + other * 0.6 for first, other in zip(tone, second)]
    lowpass(mixed, cutoff_hz, passes=2)
    return adsr_envelope(mixed, gate, 0.02, 0.1, 0.75, release_seconds)


def sparkle(rng, duration_seconds, count, low_hz=2500.0, high_hz=5200.0):
    output = silence(duration_seconds)
    for _ in range(count):
        ping = decay_envelope(oscillator(samples_for(0.12), rng.uniform(low_hz, high_hz)), 0.001, 0.03)
        mix_into(output, ping, rng.randrange(0, max(1, len(output) - len(ping))), rng.uniform(0.3, 0.7))
    return output


def crackle(rng, duration_seconds, density=0.35, hp_hz=1500.0):
    """Gated noise: fire, electricity."""
    signal = highpass(noise(samples_for(duration_seconds), rng), hp_hz)
    gate_length = samples_for(0.004)
    for start in range(0, len(signal), gate_length):
        if rng.random() > density:
            for index in range(start, min(len(signal), start + gate_length)):
                signal[index] = 0.0
    return signal


# ============================================
# SOUND EFFECTS
# ============================================

def sfx_hit_slash(rng, ring_hz=2400.0):
    swish = decay_envelope(bandpass(noise(samples_for(0.16), rng), 900.0, 7000.0), 0.002, 0.035)
    lowpass(swish, 9000.0, 1500.0)
    ring = decay_envelope(oscillator(samples_for(0.16), ring_hz), 0.001, 0.045)
    ring_high = decay_envelope(oscillator(samples_for(0.16), ring_hz * 1.53), 0.001, 0.03)
    return layered(0.16, (0.0, swish, 1.0), (0.004, ring, 0.22), (0.004, ring_high, 0.12))


def sfx_hit_blunt(rng):
    thud = decay_envelope(oscillator(samples_for(0.2), 170.0, 70.0), 0.002, 0.055)
    knock = decay_envelope(lowpass(noise(samples_for(0.2), rng), 1600.0), 0.001, 0.025)
    clank = decay_envelope(oscillator(samples_for(0.2), 1100.0), 0.001, 0.04)
    clank_high = decay_envelope(oscillator(samples_for(0.2), 1690.0), 0.001, 0.03)
    return layered(0.2, (0.0, thud, 1.0), (0.0, knock, 0.8), (0.003, clank, 0.25), (0.003, clank_high, 0.15))


def sfx_shot_arrow(rng):
    twang = decay_envelope(lowpass(oscillator(samples_for(0.12), 440.0, 380.0, kind="triangle"), 3000.0), 0.001, 0.035)
    air = whoosh(rng, 0.2, 1500.0, 5500.0, 0.03)
    return layered(0.2, (0.0, twang, 0.35), (0.01, air, 1.0))


def sfx_shot_magic(rng):
    sample_count = samples_for(0.26)
    shimmer = oscillator(sample_count, 900.0, 1800.0, vibrato_depth=0.03, vibrato_rate=28.0)
    fifth = oscillator(sample_count, 1350.0, 2700.0)
    tone = decay_envelope([first + other * 0.4 for first, other in zip(shimmer, fifth)], 0.008, 0.08)
    hiss = decay_envelope(highpass(noise(sample_count, rng), 4000.0), 0.005, 0.05)
    return layered(0.26, (0.0, tone, 1.0), (0.0, hiss, 0.15))


def sfx_shot_cannon(rng):
    return boom(rng, 0.45)


def sfx_shot_zap(rng):
    sample_count = samples_for(0.22)
    buzz = oscillator(sample_count, 1400.0, 600.0, kind="square", duty=0.3)
    gate = crackle(rng, 0.22, density=0.55, hp_hz=200.0)
    zap = decay_envelope([value * (1.0 if abs(gated) > 0.0 else 0.25) for value, gated in zip(buzz, gate)], 0.002, 0.07)
    lowpass(zap, 6000.0)
    sizzle = decay_envelope(crackle(rng, 0.22, density=0.3, hp_hz=3000.0), 0.002, 0.06)
    return layered(0.22, (0.0, zap, 0.8), (0.0, sizzle, 0.5))


def sfx_monster_bite(rng):
    crunch = decay_envelope(lowpass(noise(samples_for(0.14), rng), 1300.0), 0.002, 0.03)
    chomp = decay_envelope(oscillator(samples_for(0.14), 230.0, 110.0, kind="triangle"), 0.002, 0.04)
    return layered(0.14, (0.0, crunch, 1.0), (0.0, chomp, 0.8))


def sfx_monster_spit(rng):
    splat = decay_envelope(oscillator(samples_for(0.16), 820.0, 240.0), 0.003, 0.05)
    spray = decay_envelope(bandpass(noise(samples_for(0.16), rng), 1500.0, 4000.0), 0.002, 0.03)
    return layered(0.16, (0.0, splat, 1.0), (0.0, spray, 0.5))


def coin_ping():
    first = chime_note(note_frequency(note_number("E6")), 0.06, decay_seconds=0.04)
    second = chime_note(note_frequency(note_number("A6")), 0.2, decay_seconds=0.07)
    return layered(0.26, (0.0, first, 1.0), (0.055, second, 1.0))


def sfx_monster_defeated(rng):
    poof = decay_envelope(lowpass(noise(samples_for(0.25), rng), 3200.0, 300.0), 0.002, 0.06)
    pop = decay_envelope(oscillator(samples_for(0.06), 480.0, 950.0), 0.001, 0.02)
    return layered(0.36, (0.0, poof, 1.0), (0.0, pop, 0.5), (0.06, coin_ping(), 0.32))


def sfx_boss_defeated(rng):
    parts = [(0.0, boom(rng, 0.9, 90.0, 30.0, 0.3), 1.0)]
    for coin_index in range(6):
        ping = chime_note(note_frequency(note_number("C6") + (0, 4, 7, 12, 16, 19)[coin_index]), 0.18, decay_seconds=0.07)
        parts.append((0.25 + coin_index * 0.07, ping, 0.3))
    return layered(1.0, *parts)


def sfx_hero_defeated(rng):
    sample_count = samples_for(0.45)
    tone = decay_envelope(lowpass(oscillator(sample_count, 520.0, 250.0, kind="triangle", vibrato_depth=0.02, vibrato_rate=7.0), 2500.0), 0.005, 0.15)
    thump = decay_envelope(lowpass(noise(samples_for(0.1), rng), 900.0), 0.002, 0.03)
    return layered(0.45, (0.0, tone, 1.0), (0.0, thump, 0.5))


def sfx_hero_respawned(rng):
    sample_count = samples_for(0.5)
    rise = adsr_envelope(oscillator(sample_count, 420.0, 1250.0), samples_for(0.3), 0.05, 0.1, 0.7, 0.2)
    octave = adsr_envelope(oscillator(sample_count, 840.0, 2500.0), samples_for(0.3), 0.05, 0.1, 0.5, 0.2)
    return layered(0.55, (0.0, rise, 0.7), (0.0, octave, 0.25), (0.08, sparkle(rng, 0.45, 5), 0.25))


def sfx_base_hit(rng):
    thunk = decay_envelope(oscillator(samples_for(0.18), 150.0, 90.0), 0.002, 0.05)
    wood = decay_envelope(bandpass(noise(samples_for(0.18), rng), 300.0, 2500.0), 0.001, 0.022)
    return layered(0.18, (0.0, thunk, 1.0), (0.0, wood, 0.9))


def sfx_base_destroyed(rng):
    sample_count = samples_for(1.6)
    rumble = decay_envelope(lowpass(noise(sample_count, rng), 2600.0, 140.0, passes=2), 0.004, 0.5)
    body = decay_envelope(oscillator(sample_count, 72.0, 34.0), 0.004, 0.35)
    debris = silence(1.6)
    for debris_index in range(26):
        chunk = decay_envelope(bandpass(noise(samples_for(0.06), rng), 600.0, 4500.0), 0.001, rng.uniform(0.008, 0.02))
        start = rng.uniform(0.05, 1.25)
        mix_into(debris, chunk, samples_for(start), rng.uniform(0.3, 0.9) * (1.0 - start / 1.4))
    return fade_out(layered(1.6, (0.0, rumble, 2.2), (0.0, body, 1.0), (0.0, debris, 0.45)), 0.2)


def stinger(dry, room=0.75, wet_gain=0.35):
    wet = reverb(dry, room=room, tail_seconds=0.8)
    output = dry + [0.0] * (len(wet) - len(dry))
    mix_into(output, wet, 0, wet_gain)
    return fade_out(output, 0.25)


def sfx_stage_won(rng):
    # Starts 0.25 s late so it lands right after the base's collapse sound.
    lead_in = 0.25
    parts = []
    for note_index, name in enumerate(("D5", "F#5", "A5")):
        parts.append((lead_in + note_index * 0.1, brass_note(note_frequency(note_number(name)), 0.08), 0.5))
    for name in ("D5", "F#5", "A5", "D6"):
        parts.append((lead_in + 0.3, brass_note(note_frequency(note_number(name)), 0.75, release_seconds=0.35), 0.38))
    parts.append((lead_in + 0.32, sparkle(rng, 0.8, 9, 2800.0, 6000.0), 0.18))
    return stinger(layered(1.7, *parts))


def sfx_stage_lost(rng):
    lead_in = 0.3
    parts = []
    for note_index, name in enumerate(("A4", "F4", "D4")):
        parts.append((lead_in + note_index * 0.24, brass_note(note_frequency(note_number(name)), 0.2, cutoff_hz=1400.0, vibrato_depth=0.0), 0.5))
    sample_count = samples_for(0.9)
    final = oscillator(sample_count, note_frequency(note_number("C#4")), note_frequency(note_number("C4")), kind="saw", vibrato_depth=0.012, vibrato_rate=5.0, vibrato_delay=0.2)
    lowpass(final, 1300.0, 500.0, passes=2)
    adsr_envelope(final, samples_for(0.6), 0.03, 0.1, 0.8, 0.3)
    parts.append((lead_in + 0.72, final, 0.5))
    return stinger(layered(2.0, *parts), wet_gain=0.25)


def sfx_boss_arrived(rng):
    sample_count = samples_for(1.7)
    horn = [0.0] * sample_count
    for frequency, gain in ((note_frequency(note_number("E2")), 1.0), (note_frequency(note_number("E3")), 0.6), (note_frequency(note_number("B2")), 0.5)):
        voice = oscillator(sample_count, frequency, kind="saw", vibrato_depth=0.006, vibrato_rate=4.5, vibrato_delay=0.3)
        mix_into(horn, voice, 0, gain)
    lowpass(horn, 500.0, 1300.0, passes=2)
    adsr_envelope(horn, samples_for(1.3), 0.25, 0.3, 0.8, 0.4)
    drum = decay_envelope(oscillator(samples_for(0.6), 95.0, 55.0), 0.003, 0.18)
    return stinger(layered(1.8, (0.0, horn, 0.8), (0.0, drum, 1.0), (0.42, drum, 0.8)), room=0.82, wet_gain=0.3)


def sfx_hero_recruited(rng):
    parts = []
    for note_index, name in enumerate(("G5", "C6", "E6")):
        parts.append((note_index * 0.07, chime_note(note_frequency(note_number(name)), 0.1, decay_seconds=0.06), 0.5))
    parts.append((0.21, brass_note(note_frequency(note_number("G6")), 0.35, release_seconds=0.2, cutoff_hz=4000.0), 0.35))
    for name in ("C5", "E5", "G5"):
        parts.append((0.21, adsr_envelope(oscillator(samples_for(0.6), note_frequency(note_number(name))), samples_for(0.35), 0.01, 0.1, 0.7, 0.25), 0.18))
    return stinger(layered(0.9, *parts), wet_gain=0.25)


def sfx_hero_level_up(rng):
    parts = []
    for note_index, name in enumerate(("C6", "E6", "G6")):
        parts.append((note_index * 0.05, chime_note(note_frequency(note_number(name)), 0.12, decay_seconds=0.05), 0.6))
    parts.append((0.1, sparkle(rng, 0.2, 3, 3500.0, 6000.0), 0.15))
    return layered(0.32, *parts)


def sfx_star_up(rng):
    parts = []
    for note_index, name in enumerate(("C6", "E6", "G6", "C7")):
        parts.append((note_index * 0.08, bell(note_frequency(note_number(name)), 0.9, 0.4), 0.45))
    parts.append((0.05, sparkle(rng, 0.8, 10, 3000.0, 7000.0), 0.2))
    return stinger(layered(1.1, *parts), wet_gain=0.25)


def sfx_shard_dropped(rng):
    return layered(0.65, (0.0, bell(note_frequency(note_number("G6")), 0.6, 0.2), 0.6), (0.09, bell(note_frequency(note_number("C7")), 0.55, 0.2), 0.5))


def sfx_rebirth(rng):
    sample_count = samples_for(2.3)
    rise = noise(sample_count, rng)
    lowpass(rise, 250.0, 6000.0, passes=2)
    swell = samples_for(1.4)
    for index in range(sample_count):
        rise[index] *= index / swell if index < swell else max(0.0, 1.0 - (index - swell) / (sample_count - swell)) ** 2
    choir = [0.0] * sample_count
    for name in ("C4", "G4", "C5", "E5", "G5"):
        frequency = note_frequency(note_number(name))
        for detune in (1.0, 1.006):
            mix_into(choir, oscillator(sample_count, frequency * detune, kind="saw", vibrato_depth=0.004, vibrato_rate=5.0), 0, 0.2)
    lowpass(choir, 1500.0, passes=2)
    adsr_envelope(choir, samples_for(1.5), 0.7, 0.2, 0.85, 0.7)
    return stinger(layered(2.4, (0.0, rise, 0.5), (0.3, choir, 0.6), (1.35, bell(note_frequency(note_number("C7")), 0.9, 0.35), 0.35)), room=0.85)


def sfx_chest_opened(rng):
    sample_count = samples_for(0.45)
    creak = oscillator(sample_count, 140.0, 95.0, kind="saw", vibrato_depth=0.08, vibrato_rate=14.0)
    lowpass(creak, 1200.0, 600.0)
    adsr_envelope(creak, samples_for(0.3), 0.02, 0.1, 0.7, 0.15)
    thunk = decay_envelope(oscillator(samples_for(0.2), 160.0, 90.0), 0.002, 0.05)
    rise = whoosh(rng, 0.6, 600.0, 6000.0, 0.45)
    parts = [(0.0, creak, 0.5), (0.0, thunk, 0.8), (0.25, rise, 0.4)]
    for note_index, name in enumerate(("C6", "E6", "G6", "C7")):
        parts.append((0.55 + note_index * 0.06, bell(note_frequency(note_number(name)), 0.7, 0.3), 0.35))
    parts.append((0.6, sparkle(rng, 0.7, 10, 3000.0, 7000.0), 0.22))
    return stinger(layered(1.5, *parts), wet_gain=0.3)


def sfx_skill_volley(rng):
    parts = []
    for arrow_index in range(5):
        parts.append((arrow_index * 0.07 + rng.uniform(0.0, 0.02), whoosh(rng, 0.2, rng.uniform(1200.0, 1800.0), rng.uniform(4500.0, 6500.0), 0.03), 0.8))
    return layered(0.6, *parts)


def sfx_skill_lightning(rng):
    zap = decay_envelope(crackle(rng, 0.6, density=0.45, hp_hz=900.0), 0.002, 0.18)
    buzz = decay_envelope(lowpass(oscillator(samples_for(0.6), 220.0, 160.0, kind="square", duty=0.4), 2000.0), 0.002, 0.15)
    thunder = decay_envelope(lowpass(noise(samples_for(0.6), rng), 700.0, 150.0), 0.02, 0.2)
    return layered(0.6, (0.0, zap, 0.7), (0.0, buzz, 0.3), (0.05, thunder, 1.0))


def sfx_skill_holy(rng):
    chord = layered(0.8, *[(0.0, bell(note_frequency(note_number(name)), 0.8, 0.3), 0.35) for name in ("A5", "C#6", "E6")])
    beam = decay_envelope(oscillator(samples_for(0.5), 1500.0, 3000.0, vibrato_depth=0.02, vibrato_rate=24.0), 0.02, 0.15)
    return stinger(layered(0.8, (0.0, chord, 1.0), (0.0, beam, 0.3), (0.0, sparkle(rng, 0.6, 8), 0.2)), wet_gain=0.3)


def sfx_skill_heal(rng):
    parts = []
    for note_index, name in enumerate(("C5", "E5", "G5", "C6", "E6")):
        frequency = note_frequency(note_number(name))
        tone = decay_envelope(oscillator(samples_for(0.6), frequency), 0.01, 0.25)
        chorus = decay_envelope(oscillator(samples_for(0.6), frequency * 1.005), 0.01, 0.25)
        parts.append((note_index * 0.07, tone, 0.35))
        parts.append((note_index * 0.07, chorus, 0.25))
    parts.append((0.1, sparkle(rng, 0.6, 7), 0.18))
    return stinger(layered(0.9, *parts), wet_gain=0.35)


def sfx_skill_barrage(rng):
    return layered(1.0, (0.0, boom(rng, 0.5), 1.0), (0.18, boom(rng, 0.5, 120.0), 0.8), (0.36, boom(rng, 0.6, 100.0), 0.9))


def sfx_skill_fireball(rng):
    rush = whoosh(rng, 0.3, 400.0, 3500.0, 0.2)
    fire = decay_envelope(crackle(rng, 0.5, density=0.3, hp_hz=800.0), 0.01, 0.15)
    return layered(0.75, (0.0, rush, 0.8), (0.22, boom(rng, 0.5, 130.0, 45.0, 0.12), 1.0), (0.22, fire, 0.4))


def sfx_skill_dive(rng):
    swoop = noise(samples_for(0.4), rng)
    highpass(swoop, 800.0)
    lowpass(swoop, 1200.0, 5000.0)
    peak = samples_for(0.3)
    for index in range(len(swoop)):
        swoop[index] *= (index / peak) ** 1.5 if index < peak else max(0.0, 1.0 - (index - peak) / (len(swoop) - peak))
    return layered(0.55, (0.0, swoop, 0.7), (0.3, sfx_hit_blunt(rng), 1.0))


def sfx_skill_clang(rng):
    sample_count = samples_for(0.45)
    output = [0.0] * sample_count
    for frequency, gain, decay_seconds in ((520.0, 1.0, 0.16), (1240.0, 0.6, 0.11), (1870.0, 0.4, 0.07), (2650.0, 0.3, 0.05)):
        mix_into(output, decay_envelope(oscillator(sample_count, frequency), 0.001, decay_seconds), 0, gain)
    thud = decay_envelope(oscillator(samples_for(0.2), 140.0, 70.0), 0.002, 0.05)
    return layered(0.45, (0.0, output, 0.45), (0.0, thud, 1.0))


def sfx_skill_vines(rng):
    sample_count = samples_for(0.7)
    creak = oscillator(sample_count, 95.0, 70.0, kind="saw", vibrato_depth=0.12, vibrato_rate=9.0)
    lowpass(creak, 900.0)
    adsr_envelope(creak, samples_for(0.5), 0.05, 0.1, 0.8, 0.2)
    rustle = bandpass(noise(sample_count, rng), 1800.0, 5000.0)
    for index in range(sample_count):
        rustle[index] *= 0.5 + 0.5 * math.sin(index * TAU * 13.0 / SAMPLE_RATE)
    adsr_envelope(rustle, samples_for(0.45), 0.05, 0.1, 0.7, 0.25)
    return layered(0.7, (0.0, creak, 0.6), (0.0, rustle, 0.5))


def sfx_skill_frenzy(rng):
    sample_count = samples_for(0.6)
    rise = oscillator(sample_count, 300.0, 1200.0, kind="square", duty=0.3)
    for index in range(sample_count):
        rise[index] *= 0.6 + 0.4 * math.sin(index * TAU * 20.0 / SAMPLE_RATE)
    lowpass(rise, 3500.0)
    adsr_envelope(rise, samples_for(0.45), 0.02, 0.1, 0.8, 0.15)
    ticks = silence(0.6)
    for tick_index in range(8):
        mix_into(ticks, decay_envelope(highpass(noise(samples_for(0.02), rng), 3000.0), 0.0005, 0.005), samples_for(tick_index * 0.065))
    return layered(0.6, (0.0, rise, 0.5), (0.0, ticks, 0.4))


def sfx_skill_horn(rng):
    first = brass_note(note_frequency(note_number("A3")), 0.28, cutoff_hz=1500.0)
    second = brass_note(note_frequency(note_number("E4")), 0.5, release_seconds=0.25, cutoff_hz=1800.0)
    return stinger(layered(1.0, (0.0, first, 0.7), (0.3, second, 0.8)), wet_gain=0.3)


SOUND_EFFECTS = {
    "hit_slash": lambda rng: sfx_hit_slash(rng),
    "hit_slash_2": lambda rng: sfx_hit_slash(rng, 2100.0),
    "hit_blunt": sfx_hit_blunt,
    "shot_arrow": sfx_shot_arrow,
    "shot_magic": sfx_shot_magic,
    "shot_cannon": sfx_shot_cannon,
    "shot_zap": sfx_shot_zap,
    "monster_bite": sfx_monster_bite,
    "monster_spit": sfx_monster_spit,
    "monster_defeated": sfx_monster_defeated,
    "boss_defeated": sfx_boss_defeated,
    "hero_defeated": sfx_hero_defeated,
    "hero_respawned": sfx_hero_respawned,
    "base_hit": sfx_base_hit,
    "base_destroyed": sfx_base_destroyed,
    "stage_won": sfx_stage_won,
    "stage_lost": sfx_stage_lost,
    "boss_arrived": sfx_boss_arrived,
    "hero_recruited": sfx_hero_recruited,
    "hero_level_up": sfx_hero_level_up,
    "star_up": sfx_star_up,
    "shard_dropped": sfx_shard_dropped,
    "rebirth": sfx_rebirth,
    "chest_opened": sfx_chest_opened,
    "skill_volley": sfx_skill_volley,
    "skill_lightning": sfx_skill_lightning,
    "skill_holy": sfx_skill_holy,
    "skill_heal": sfx_skill_heal,
    "skill_barrage": sfx_skill_barrage,
    "skill_fireball": sfx_skill_fireball,
    "skill_dive": sfx_skill_dive,
    "skill_clang": sfx_skill_clang,
    "skill_vines": sfx_skill_vines,
    "skill_frenzy": sfx_skill_frenzy,
    "skill_horn": sfx_skill_horn,
}


# ============================================
# MUSIC
# ============================================

def chord_tones(symbol, low_note):
    """Triad of chord [symbol] with its root in [low_note, low_note + 11]."""
    root_class, quality = CHORDS[symbol]
    root = low_note + (root_class - low_note) % 12
    return [root + interval for interval in TRIADS[quality]]


def parse_melody(text):
    """'D5:1 F5:.5 r:1' -> [(start_beat, length_beats, midi or None)]."""
    notes = []
    beat = 0.0
    for token in text.split():
        name, length = token.split(":")
        length_beats = float(length)
        notes.append((beat, length_beats, None if name == "r" else note_number(name)))
        beat += length_beats
    return notes


class Instruments:
    """Renders (and caches) one note of each instrument."""

    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.cache = {}

    def note(self, instrument, midi_note, gate_seconds):
        key = (instrument, midi_note, round(gate_seconds, 4))
        if key not in self.cache:
            self.cache[key] = getattr(self, "_" + instrument)(note_frequency(midi_note) if midi_note else 0.0, gate_seconds)
        return self.cache[key]

    def _lead(self, frequency, gate_seconds):
        gate = samples_for(gate_seconds)
        tone = oscillator(gate + samples_for(0.06), frequency, kind="square", duty=0.25, vibrato_depth=0.004, vibrato_delay=0.14)
        lowpass(tone, 3200.0, passes=2)
        return adsr_envelope(tone, gate, 0.008, 0.12, 0.65, 0.06)

    def _flute(self, frequency, gate_seconds):
        gate = samples_for(gate_seconds)
        sample_count = gate + samples_for(0.12)
        tone = oscillator(sample_count, frequency, kind="triangle", vibrato_depth=0.006, vibrato_delay=0.2)
        breath = oscillator(sample_count, frequency * 2.0)
        mixed = [first + other * 0.15 for first, other in zip(tone, breath)]
        lowpass(mixed, 2600.0)
        return adsr_envelope(mixed, gate, 0.04, 0.15, 0.75, 0.12)

    def _boss_lead(self, frequency, gate_seconds):
        gate = samples_for(gate_seconds)
        sample_count = gate + samples_for(0.05)
        tone = oscillator(sample_count, frequency, kind="square", duty=0.5, vibrato_depth=0.005, vibrato_delay=0.12)
        edge = oscillator(sample_count, frequency * 1.003, kind="saw")
        mixed = [first + other * 0.5 for first, other in zip(tone, edge)]
        lowpass(mixed, 2800.0, passes=2)
        return adsr_envelope(mixed, gate, 0.005, 0.08, 0.7, 0.05)

    def _bass(self, frequency, gate_seconds):
        gate = samples_for(gate_seconds)
        sample_count = gate + samples_for(0.04)
        body = oscillator(sample_count, frequency, kind="triangle")
        bite = oscillator(sample_count, frequency, kind="square")
        mixed = [first * 0.7 + other * 0.35 for first, other in zip(body, bite)]
        lowpass(mixed, 950.0, passes=2)
        return adsr_envelope(mixed, gate, 0.004, 0.1, 0.65, 0.03)

    def _boss_bass(self, frequency, gate_seconds):
        gate = samples_for(gate_seconds)
        sample_count = gate + samples_for(0.03)
        tone = oscillator(sample_count, frequency, kind="square")
        growl = oscillator(sample_count, frequency * 1.006, kind="saw")
        mixed = [first * 0.6 + other * 0.5 for first, other in zip(tone, growl)]
        lowpass(mixed, 1400.0, 500.0, passes=2)
        return adsr_envelope(mixed, gate, 0.003, 0.08, 0.6, 0.03)

    def _pluck(self, frequency, gate_seconds):
        sample_count = samples_for(0.5)
        tone = oscillator(sample_count, frequency, kind="saw")
        lowpass(tone, 5000.0, 500.0)
        return decay_envelope(tone, 0.002, 0.16)

    def _pad(self, frequency, gate_seconds):
        gate = samples_for(gate_seconds)
        sample_count = gate + samples_for(0.35)
        voice = oscillator(sample_count, frequency, kind="saw")
        detuned = oscillator(sample_count, frequency * 1.0047, kind="saw")
        mixed = [first + other for first, other in zip(voice, detuned)]
        lowpass(mixed, 1500.0, passes=2)
        return adsr_envelope(mixed, gate, 0.25, 0.3, 0.8, 0.35)

    def _stab(self, frequency, gate_seconds):
        sample_count = samples_for(0.16)
        tone = oscillator(sample_count, frequency, kind="saw")
        body = oscillator(sample_count, frequency * 0.5, kind="square")
        mixed = [first + other * 0.4 for first, other in zip(tone, body)]
        lowpass(mixed, 2400.0, 900.0)
        return decay_envelope(mixed, 0.003, 0.06)

    def _kick(self, frequency, gate_seconds):
        sample_count = samples_for(0.24)
        body = oscillator(sample_count, 150.0, 42.0)
        decay_envelope(body, 0.001, 0.08)
        click = decay_envelope(lowpass(noise(samples_for(0.01), self.rng), 4000.0), 0.0005, 0.002)
        mix_into(body, click, 0, 0.4)
        return body

    def _snare(self, frequency, gate_seconds):
        sample_count = samples_for(0.2)
        rattle = decay_envelope(bandpass(noise(sample_count, self.rng), 1000.0, 7000.0), 0.001, 0.055)
        tone = decay_envelope(oscillator(sample_count, 195.0, 160.0), 0.001, 0.03)
        mix_into(rattle, tone, 0, 0.7)
        return rattle

    def _hat(self, frequency, gate_seconds):
        return decay_envelope(highpass(noise(samples_for(0.05), self.rng), 6500.0), 0.0005, 0.012)

    def _open_hat(self, frequency, gate_seconds):
        return decay_envelope(highpass(noise(samples_for(0.3), self.rng), 6000.0), 0.001, 0.09)

    def _crash(self, frequency, gate_seconds):
        return decay_envelope(highpass(noise(samples_for(1.4), self.rng), 4500.0), 0.002, 0.45)

    def _tom(self, frequency, gate_seconds):
        sample_count = samples_for(0.3)
        return decay_envelope(oscillator(sample_count, frequency * 1.5, frequency), 0.001, 0.11)


DRUM_PATTERNS = {
    # beat -> instrument (per 4/4 bar)
    "full": {"kick": (0.0, 2.0, 2.5), "snare": (1.0, 3.0), "hat": (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5)},
    "drive": {"kick": (0.0, 1.5, 2.0), "snare": (1.0, 3.0), "hat": (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0), "open_hat": (3.5,)},
    "sparse": {"kick": (0.0, 2.0), "hat": (0.0, 1.0, 2.0, 3.0)},
    "fill": {"kick": (0.0, 2.0), "snare": (1.0, 2.0, 2.5, 3.0, 3.25, 3.5, 3.75), "hat": (0.0, 0.5, 1.0, 1.5)},
    "boss": {"kick": (0.0, 1.0, 1.5, 2.0, 3.0), "snare": (1.0, 3.0), "hat": (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5)},
    "boss_fill": {"kick": (0.0, 1.0, 2.0), "snare": (1.0,), "tom": (2.0, 2.5, 3.0, 3.5), "hat": (0.0, 0.5, 1.0, 1.5)},
}
DRUM_GAINS = {"kick": 0.6, "snare": 0.34, "hat": 0.07, "open_hat": 0.08, "crash": 0.12, "tom": 0.32}
TOM_NOTES = (55, 50, 45, 40)
ARP_STEPS = (0, 1, 2, 3, 4, 3, 2, 1)
BASS_PATTERNS = {
    "walk": (0, 0, 12, 0, 7, 0, 12, 7),
    "drive": (0, 0, 0, 0, 0, 0, 12, 0),
    "boss": (0, 0, 12, 0, 0, 0, 12, 0),
}


def render_song(bars, bpm, seed, lead_gain=0.3):
    """bars: dicts with chord, melody, lead, drums, bass, arp, pad, stabs, crash, double."""
    instruments = Instruments(seed)
    beat_seconds = 60.0 / bpm
    bar_samples = samples_for(beat_seconds * 4.0)
    loop_length = bar_samples * len(bars)
    dry = [0.0] * loop_length
    send = [0.0] * loop_length

    def place(signal, bar_index, beat, gain, reverb_send=0.0):
        start = bar_index * bar_samples + samples_for(beat * beat_seconds)
        mix_into(dry, signal, start, gain, wrap=True)
        if reverb_send:
            mix_into(send, signal, start, gain * reverb_send, wrap=True)

    for bar_index, bar in enumerate(bars):
        chord = bar["chord"]
        for start_beat, length_beats, midi_note in parse_melody(bar["melody"]):
            if midi_note is None:
                continue
            gate = length_beats * beat_seconds * 0.92
            place(instruments.note(bar.get("lead", "lead"), midi_note, gate), bar_index, start_beat, lead_gain, 0.3)
            if bar.get("double"):
                place(instruments.note("flute", midi_note - 12, gate), bar_index, start_beat, lead_gain * 0.45, 0.3)
        bass_root = chord_tones(chord, 36)[0]
        bass_style = bar.get("bass", "walk")
        if bass_style == "half":
            for half_index, interval in enumerate((0, 7)):
                place(instruments.note("bass", bass_root + interval, beat_seconds * 1.9), bar_index, half_index * 2.0, 0.38)
        else:
            instrument = "boss_bass" if bass_style == "boss" else "bass"
            for step, interval in enumerate(BASS_PATTERNS[bass_style]):
                place(instruments.note(instrument, bass_root + interval, beat_seconds * 0.45), bar_index, step * 0.5, 0.36)
        arp_style = bar.get("arp", "eighths")
        if arp_style != "none":
            tones = chord_tones(chord, 55)
            tones = tones + [tones[0] + 12, tones[1] + 12]
            step_beats = 0.5 if arp_style == "eighths" else 1.0
            for step in range(int(4.0 / step_beats)):
                place(instruments.note("pluck", tones[ARP_STEPS[step % len(ARP_STEPS)]], 0.3), bar_index, step * step_beats, 0.13, 0.35)
        pad_gain = bar.get("pad", 0.06)
        if pad_gain:
            for tone in chord_tones(chord, 50):
                place(instruments.note("pad", tone, beat_seconds * 4.0 * 0.97), bar_index, 0.0, pad_gain, 0.5)
        if bar.get("stabs"):
            for beat in (0.5, 1.5, 2.5, 3.5):
                for tone in chord_tones(chord, 55):
                    place(instruments.note("stab", tone, 0.12), bar_index, beat, 0.07, 0.2)
        pattern = DRUM_PATTERNS[bar.get("drums", "full")]
        for drum_name, beats in pattern.items():
            for hit_index, beat in enumerate(beats):
                if drum_name == "tom":
                    signal = instruments.note("tom", TOM_NOTES[hit_index % len(TOM_NOTES)], 0.1)
                else:
                    signal = instruments.note(drum_name, 0, 0.1)
                place(signal, bar_index, beat, DRUM_GAINS[drum_name], 0.25 if drum_name == "snare" else 0.0)
        if bar.get("crash"):
            place(instruments.note("crash", 0, 0.1), bar_index, 0.0, DRUM_GAINS["crash"], 0.3)

    wet = reverb(send, room=0.8, damping=0.35, loop=True)
    mix_into(dry, wet, 0, 0.35)
    # DC blocker; run over two passes so the filter state wraps with the loop.
    looped = highpass(dry + dry, 20.0)
    dry = looped[loop_length:]
    loudest = max(abs(value) for value in dry) or 1.0
    # Gentle limiter so peaks never clip after normalizing.
    return [math.tanh(1.3 * value / loudest) / math.tanh(1.3) for value in dry]


def battle_theme_bars():
    section_a = [
        ("Dm", "D5:1 F5:.5 A5:.5 G5:1 F5:1"),
        ("Bb", "D5:1.5 C5:.5 D5:1 F5:1"),
        ("F", "C5:1 F5:.5 A5:.5 C6:1.5 A5:.5"),
        ("C", "G5:2 E5:1 C5:1"),
        ("Dm", "D5:1 F5:.5 A5:.5 D6:1 C6:.5 A5:.5"),
        ("Bb", "Bb5:1.5 A5:.5 G5:1 F5:1"),
        ("C", "E5:1 G5:1 C6:1 Bb5:1"),
        ("A", "A5:3 r:1"),
    ]
    section_b = [
        ("Bb", "F5:.5 F5:.5 Bb5:1 A5:.5 G5:.5 F5:1"),
        ("C", "E5:.5 E5:.5 G5:1 C6:1 G5:1"),
        ("Dm", "A5:1.5 F5:.5 D5:1 F5:1"),
        ("Dm", "A5:2 D6:2"),
        ("Bb", "D6:1 C6:.5 Bb5:.5 A5:1 Bb5:1"),
        ("C", "C6:1 Bb5:.5 A5:.5 G5:1 E5:1"),
        ("Gm", "D5:1 G5:1 Bb5:1 D6:1"),
        ("A", "C#6:2 E6:1 A5:1"),
    ]
    section_bridge = [
        ("Gm", "Bb5:2 A5:1 G5:1"),
        ("Dm", "F5:3 A5:1"),
        ("Bb", "D6:2 C6:1 Bb5:1"),
        ("F", "A5:3 F5:1"),
        ("Gm", "G5:2 Bb5:1 D6:1"),
        ("Bb", "F6:2 D6:2"),
        ("C", "E6:1 D6:1 C6:1 Bb5:1"),
        ("A", "A5:2 G5:1 E5:1"),
    ]
    bars = []
    for index, (chord, melody) in enumerate(section_a):
        bars.append({"chord": chord, "melody": melody, "crash": index == 0, "drums": "fill" if index == 7 else "full"})
    for index, (chord, melody) in enumerate(section_b):
        bars.append({"chord": chord, "melody": melody, "crash": index == 0, "drums": "fill" if index == 7 else "drive", "bass": "drive"})
    for index, (chord, melody) in enumerate(section_a):
        if index == 7:
            melody = "A5:1 C#6:1 E6:1.5 r:.5"
        bars.append({"chord": chord, "melody": melody, "crash": index == 0, "drums": "fill" if index == 7 else "full", "double": True})
    for index, (chord, melody) in enumerate(section_bridge):
        bars.append({"chord": chord, "melody": melody, "lead": "flute", "drums": "fill" if index == 7 else "sparse", "bass": "half", "arp": "quarters", "pad": 0.09})
    return bars


def boss_theme_bars():
    verse = [
        ("Em", "E5:.5 E5:.5 G5:.5 E5:.5 B5:1 A5:1"),
        ("Em", "G5:.5 F#5:.5 E5:1 D5:1 E5:1"),
        ("C", "C6:1 B5:.5 A5:.5 G5:1 E5:1"),
        ("D", "F#5:1 A5:1 D6:2"),
        ("Em", "E6:1 D6:.5 B5:.5 G5:1 B5:1"),
        ("Em", "A5:.5 G5:.5 F#5:1 E5:2"),
        ("C", "G5:1 C6:1 E6:1 D6:1"),
        ("B", "D#6:2 B5:2"),
    ]
    chorus = [
        ("Am", "A5:1 C6:1 E6:1 C6:1"),
        ("Em", "B5:1.5 G5:.5 E5:2"),
        ("C", "E5:.5 G5:.5 C6:1 B5:1 G5:1"),
        ("B", "F#5:2 D#5:2"),
        ("Am", "C6:1 B5:.5 A5:.5 E5:1 A5:1"),
        ("C", "G5:1 E6:1 D6:1 C6:1"),
        ("D", "D6:1 A5:1 F#5:1 A5:1"),
        ("B", "B5:1 D#6:1 F#6:2"),
    ]
    bars = []
    for section in (verse, chorus):
        for index, (chord, melody) in enumerate(section):
            bars.append({"chord": chord, "melody": melody, "lead": "boss_lead", "crash": index == 0, "drums": "boss_fill" if index == 7 else "boss", "bass": "boss", "arp": "none", "pad": 0.04, "stabs": True})
    return bars


MUSIC = {
    "battle_theme": lambda: render_song(battle_theme_bars(), 112, seed=7),
    "boss_theme": lambda: render_song(boss_theme_bars(), 140, seed=11, lead_gain=0.28),
}


# ============================================
# ENTRY POINT
# ============================================

def main(arguments):
    wanted = set(arguments)
    build_all = not wanted
    for name, build in SOUND_EFFECTS.items():
        if build_all or "sfx" in wanted or name in wanted:
            # A short fade so no effect ends on a click.
            write_wav(SFX_DIR / (name + ".wav"), fade_out(build(random.Random(name)), 0.01))
            print("sfx   ", name)
    for name, build in MUSIC.items():
        if build_all or "music" in wanted or name in wanted:
            write_wav(MUSIC_DIR / (name + ".wav"), build())
            print("music ", name)


if __name__ == "__main__":
    main(sys.argv[1:])
