import math
import os
import struct
import wave
import numpy as np

music_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "music")
os.makedirs(music_dir, exist_ok=True)

Fs = 44100 # Standard CD quality sample rate

def write_wav(filename, audio_data, sample_rate=Fs):
    audio_data = np.clip(audio_data, -0.95, 0.95)
    int_data = (audio_data * 32767).astype(np.int16)
    filepath = os.path.join(music_dir, filename)
    with wave.open(filepath, "w") as wav_file:
        wav_file.setnchannels(2) # Stereo
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        # Interleave stereo channels
        if len(int_data.shape) == 1:
            stereo = np.column_stack((int_data, int_data))
        else:
            stereo = int_data
        wav_file.writeframes(stereo.tobytes())
    print(f"Generated {filepath} ({round(len(audio_data)/sample_rate, 1)}s)")

# Drum generators
def make_kick(duration=0.25, punch=130.0, end_freq=40.0):
    t = np.linspace(0, duration, int(Fs * duration), False)
    # Exponential frequency sweep
    freq = end_freq + (punch - end_freq) * np.exp(-25 * t)
    phase = 2 * np.pi * np.cumsum(freq) / Fs
    envelope = np.exp(-12 * t)
    click = np.random.uniform(-0.3, 0.3, len(t)) * np.exp(-120 * t)
    return np.tanh(1.5 * (np.sin(phase) * envelope + click)) * 0.85

def make_snare(duration=0.22):
    t = np.linspace(0, duration, int(Fs * duration), False)
    # Body tone
    body = np.sin(2 * np.pi * 180 * t) * np.exp(-20 * t)
    # Noise rattle
    noise = np.random.uniform(-1, 1, len(t)) * np.exp(-14 * t)
    return (0.4 * body + 0.6 * noise) * 0.7

def make_hihat(duration=0.08, open_hh=False):
    dur = 0.25 if open_hh else duration
    t = np.linspace(0, dur, int(Fs * dur), False)
    noise = np.random.uniform(-1, 1, len(t))
    decay = 12 if open_hh else 60
    return noise * np.exp(-decay * t) * 0.35

def synth_poly(notes, duration, wave_type='saw'):
    t = np.linspace(0, duration, int(Fs * duration), False)
    signal = np.zeros(len(t))
    for f in notes:
        if wave_type == 'saw':
            # Rich sawtooth (approximated with harmonics)
            chord_tone = np.zeros(len(t))
            for h in range(1, 8):
                chord_tone += (1.0 / h) * np.sin(2 * np.pi * f * h * t)
            signal += chord_tone * 0.25
        elif wave_type == 'rhodes':
            # Warm electric piano with bell tone
            signal += (np.sin(2 * np.pi * f * t) + 
                       0.4 * np.sin(4 * np.pi * f * t) + 
                       0.15 * np.sin(6 * np.pi * f * t) +
                       0.25 * np.sin(2 * np.pi * (f * 2.75) * t) * np.exp(-8 * t))
        else:
            signal += np.sin(2 * np.pi * f * t)
    
    # Envelope
    env = np.ones(len(t))
    attack = int(0.015 * Fs)
    env[:attack] = np.linspace(0, 1, attack)
    env[attack:] = np.exp(-2.0 * t[attack:] / duration)
    return signal * env

# ================= 1. HAPPY (Upbeat Pop / Tropical EDM - 122 BPM) =================
print("Generating Happy beat...")
bpm = 122
beat_len = 60.0 / bpm
bar_len = beat_len * 4
bars = 8
total_len = int(bars * bar_len * Fs)

happy_left = np.zeros(total_len)
happy_right = np.zeros(total_len)

kick = make_kick(0.3, 140, 45)
snare = make_snare(0.2)
hihat = make_hihat(0.07, open_hh=False)
open_hh = make_hihat(0.18, open_hh=True)

# Chord progression: C -> G -> Am -> F (2 bars each, repeat)
prog = [
    ([261.63, 329.63, 392.00, 523.25], 130.81), # C maj
    ([196.00, 246.94, 293.66, 392.00], 98.00),  # G maj
    ([220.00, 261.63, 329.63, 440.00], 110.00), # A min
    ([174.61, 220.00, 261.63, 349.23], 87.31)   # F maj
]

for b in range(bars):
    chord_notes, bass_freq = prog[(b // 2) % len(prog)]
    bar_start = int(b * bar_len * Fs)
    
    # Drums: 4-on-the-floor kick, offbeat hi-hat, snare on 2 & 4
    for beat in range(4):
        t_kick = bar_start + int(beat * beat_len * Fs)
        # Kick
        end_k = min(t_kick + len(kick), total_len)
        happy_left[t_kick:end_k] += kick[:end_k-t_kick]
        happy_right[t_kick:end_k] += kick[:end_k-t_kick]
        
        # Snare on 2 and 4
        if beat in [1, 3]:
            end_s = min(t_kick + len(snare), total_len)
            happy_left[t_kick:end_s] += snare[:end_s-t_kick] * 0.9
            happy_right[t_kick:end_s] += snare[:end_s-t_kick] * 0.9
            
        # Off-beat hi-hat ("and" of each beat)
        t_hh = t_kick + int(0.5 * beat_len * Fs)
        end_h = min(t_hh + len(open_hh), total_len)
        happy_left[t_hh:end_h] += open_hh[:end_h-t_hh] * 0.6
        happy_right[t_hh:end_h] += open_hh[:end_h-t_hh] * 0.7

    # Chords (play on upbeat rhythm)
    for rhythm_step in [0.0, 1.0, 1.5, 2.5, 3.0]:
        t_c = bar_start + int(rhythm_step * beat_len * Fs)
        dur = 0.45 * beat_len
        chord_audio = synth_poly(chord_notes, dur, 'saw') * 0.22
        end_c = min(t_c + len(chord_audio), total_len)
        happy_left[t_c:end_c] += chord_audio[:end_c-t_c] * 0.8
        happy_right[t_c:end_c] += chord_audio[:end_c-t_c] * 1.0

    # Bouncy Bass
    for bass_step, pitch_mult in [(0.0, 1.0), (0.75, 1.0), (1.5, 1.5), (2.0, 1.0), (2.75, 1.25), (3.5, 1.0)]:
        t_b = bar_start + int(bass_step * beat_len * Fs)
        b_len = int(0.3 * beat_len * Fs)
        t_arr = np.linspace(0, 0.3 * beat_len, b_len, False)
        bass_note = np.sin(2 * np.pi * (bass_freq * pitch_mult) * t_arr) * np.exp(-4 * t_arr) * 0.55
        end_b = min(t_b + b_len, total_len)
        happy_left[t_b:end_b] += bass_note[:end_b-t_b]
        happy_right[t_b:end_b] += bass_note[:end_b-t_b]

write_wav("happy.wav", np.column_stack((happy_left, happy_right)))

# ================= 2. SAD (Melancholic Lo-Fi Ballad - 70 BPM) =================
print("Generating Sad beat...")
bpm = 70
beat_len = 60.0 / bpm
bar_len = beat_len * 4
bars = 6
total_len = int(bars * bar_len * Fs)

sad_left = np.zeros(total_len)
sad_right = np.zeros(total_len)

kick_soft = make_kick(0.35, 95, 36) * 0.75
snare_soft = make_snare(0.28) * 0.55

# Minor emotional progression: Am -> F -> C -> Em
sad_prog = [
    ([220.00, 261.63, 329.63, 392.00], 55.00), # Am7
    ([174.61, 220.00, 261.63, 329.63], 43.65), # Fmaj7
    ([130.81, 164.81, 196.00, 246.94], 65.41), # Cmaj7
    ([164.81, 196.00, 246.94, 293.66], 41.20)  # Em7
]

for b in range(bars):
    chord_notes, bass_freq = sad_prog[b % len(sad_prog)]
    bar_start = int(b * bar_len * Fs)

    # Slow relaxed Lo-Fi drum pattern
    for beat in [0, 1.75, 2.5]: # Kick syncopation
        t_k = bar_start + int(beat * beat_len * Fs)
        end_k = min(t_k + len(kick_soft), total_len)
        sad_left[t_k:end_k] += kick_soft[:end_k-t_k]
        sad_right[t_k:end_k] += kick_soft[:end_k-t_k]

    for beat in [1, 3]: # Soft rim/snare on 2 & 4
        t_s = bar_start + int(beat * beat_len * Fs)
        end_s = min(t_s + len(snare_soft), total_len)
        sad_left[t_s:end_s] += snare_soft[:end_s-t_s]
        sad_right[t_s:end_s] += snare_soft[:end_s-t_s]

    # Gentle 8th note hi-hat
    for step in range(8):
        t_h = bar_start + int(step * 0.5 * beat_len * Fs)
        h = make_hihat(0.04) * (0.35 if step % 2 == 0 else 0.2)
        end_h = min(t_h + len(h), total_len)
        sad_left[t_h:end_h] += h[:end_h-t_h]
        sad_right[t_h:end_h] += h[:end_h-t_h]

    # Expressive Rhodes piano arpeggio
    dur = beat_len * 1.5
    for i, n in enumerate(chord_notes):
        t_n = bar_start + int(i * 0.75 * beat_len * Fs)
        note_snd = synth_poly([n], dur, 'rhodes') * 0.35
        end_n = min(t_n + len(note_snd), total_len)
        sad_left[t_n:end_n] += note_snd[:end_n-t_n] * (0.9 if i % 2 == 0 else 0.5)
        sad_right[t_n:end_n] += note_snd[:end_n-t_n] * (0.5 if i % 2 == 0 else 0.9)

    # Deep warm sub-bass
    t_b = bar_start
    b_len = int(bar_len * Fs)
    t_arr = np.linspace(0, bar_len, b_len, False)
    bass = np.sin(2 * np.pi * bass_freq * t_arr) * 0.45 * np.exp(-0.25 * t_arr)
    end_b = min(t_b + b_len, total_len)
    sad_left[t_b:end_b] += bass[:end_b-t_b]
    sad_right[t_b:end_b] += bass[:end_b-t_b]

# Subtle warm vinyl atmosphere
vinyl = np.random.normal(0, 0.015, total_len)
sad_left += vinyl
sad_right += vinyl

write_wav("sad.wav", np.column_stack((sad_left, sad_right)))

# ================= 3. SURPRISE (Energetic Synthwave / 128 BPM) =================
print("Generating Surprise beat...")
bpm = 128
beat_len = 60.0 / bpm
bar_len = beat_len * 4
bars = 8
total_len = int(bars * bar_len * Fs)

surp_left = np.zeros(total_len)
surp_right = np.zeros(total_len)
kick_fast = make_kick(0.22, 160, 50) * 0.9
snare_crisp = make_snare(0.18) * 0.85

prog_fast = [
    ([293.66, 349.23, 440.00, 587.33], 73.42), # Dm
    ([233.08, 293.66, 349.23, 466.16], 58.27), # Bb
    ([174.61, 220.00, 261.63, 349.23], 43.65), # F
    ([261.63, 329.63, 392.00, 523.25], 65.41)  # C
]

for b in range(bars):
    chord_notes, bass_freq = prog_fast[(b // 2) % len(prog_fast)]
    bar_start = int(b * bar_len * Fs)

    for beat in range(4):
        t_k = bar_start + int(beat * beat_len * Fs)
        end_k = min(t_k + len(kick_fast), total_len)
        surp_left[t_k:end_k] += kick_fast[:end_k-t_k]
        surp_right[t_k:end_k] += kick_fast[:end_k-t_k]

        if beat in [1, 3]:
            end_s = min(t_k + len(snare_crisp), total_len)
            surp_left[t_k:end_s] += snare_crisp[:end_s-t_k]
            surp_right[t_k:end_s] += snare_crisp[:end_s-t_k]

    # Fast 16th-note arpeggiator
    for sixteenth in range(16):
        t_a = bar_start + int(sixteenth * 0.25 * beat_len * Fs)
        note = chord_notes[sixteenth % len(chord_notes)] * (2 if (sixteenth // 4) % 2 == 1 else 1)
        dur = 0.2 * beat_len
        arp = synth_poly([note], dur, 'saw') * 0.28
        end_a = min(t_a + len(arp), total_len)
        pan = (sixteenth % 4) / 4.0
        surp_left[t_a:end_a] += arp[:end_a-t_a] * pan
        surp_right[t_a:end_a] += arp[:end_a-t_a] * (1.0 - pan)

    # Rolling bass
    for b_step in range(8):
        t_b = bar_start + int(b_step * 0.5 * beat_len * Fs)
        dur = 0.45 * beat_len
        b_len = int(dur * Fs)
        t_arr = np.linspace(0, dur, b_len, False)
        bass = (np.sin(2*np.pi*bass_freq*t_arr) + 0.3*np.sin(4*np.pi*bass_freq*t_arr)) * 0.45 * np.exp(-3*t_arr)
        end_b = min(t_b + b_len, total_len)
        surp_left[t_b:end_b] += bass[:end_b-t_b]
        surp_right[t_b:end_b] += bass[:end_b-t_b]

write_wav("surprise.wav", np.column_stack((surp_left, surp_right)))

# ================= 4. ANGRY (Heavy Industrial Cyberpunk - 132 BPM) =================
print("Generating Angry beat...")
bpm = 132
beat_len = 60.0 / bpm
bar_len = beat_len * 4
bars = 8
total_len = int(bars * bar_len * Fs)

angry_left = np.zeros(total_len)
angry_right = np.zeros(total_len)
kick_hard = np.clip(make_kick(0.24, 180, 40) * 1.5, -0.9, 0.9)
snare_dist = np.clip(make_snare(0.20) * 1.3, -0.85, 0.85)

for b in range(bars):
    bar_start = int(b * bar_len * Fs)
    # Driving heavy rhythm
    for beat in [0, 0.75, 1.5, 2.0, 2.75]:
        t_k = bar_start + int(beat * beat_len * Fs)
        end_k = min(t_k + len(kick_hard), total_len)
        angry_left[t_k:end_k] += kick_hard[:end_k-t_k]
        angry_right[t_k:end_k] += kick_hard[:end_k-t_k]

    for beat in [1, 3]:
        t_s = bar_start + int(beat * beat_len * Fs)
        end_s = min(t_s + len(snare_dist), total_len)
        angry_left[t_s:end_s] += snare_dist[:end_s-t_s]
        angry_right[t_s:end_s] += snare_dist[:end_s-t_s]

    # Distorted saw bass riff (E minor low drive)
    root = 41.20 # Low E1
    for riff_step, pitch_off in [(0.0, 1.0), (0.5, 1.0), (1.0, 1.2), (1.5, 1.0), (2.0, 1.33), (2.5, 1.2), (3.0, 1.0), (3.5, 0.9)]:
        t_r = bar_start + int(riff_step * beat_len * Fs)
        dur = 0.45 * beat_len
        r_len = int(dur * Fs)
        t_arr = np.linspace(0, dur, r_len, False)
        # Distortion / saturation
        saw = np.zeros(r_len)
        for h in range(1, 9):
            saw += (1.0/h) * np.sin(2 * np.pi * (root * pitch_off) * h * t_arr)
        dist_bass = np.tanh(2.5 * saw) * 0.45 * np.exp(-1.5 * t_arr)
        end_r = min(t_r + r_len, total_len)
        angry_left[t_r:end_r] += dist_bass[:end_r-t_r]
        angry_right[t_r:end_r] += dist_bass[:end_r-t_r]

write_wav("angry.wav", np.column_stack((angry_left, angry_right)))

# ================= 5. NEUTRAL (Chillhop / Lo-Fi Study Beats - 82 BPM) =================
print("Generating Neutral beat...")
bpm = 82
beat_len = 60.0 / bpm
bar_len = beat_len * 4
bars = 6
total_len = int(bars * bar_len * Fs)

neut_left = np.zeros(total_len)
neut_right = np.zeros(total_len)

kick_lofi = make_kick(0.3, 105, 42) * 0.7
snare_lofi = make_snare(0.24) * 0.6

# Smooth jazz 7th chords
neut_chords = [
    ([261.63, 329.63, 392.00, 493.88], 65.41), # Cmaj7
    ([220.00, 261.63, 329.63, 392.00], 55.00), # Am7
    ([293.66, 349.23, 440.00, 523.25], 73.42), # Dm7
    ([196.00, 246.94, 293.66, 349.23], 49.00)  # G7
]

for b in range(bars):
    chord_notes, bass_freq = neut_chords[b % len(neut_chords)]
    bar_start = int(b * bar_len * Fs)

    for beat in [0, 1.5, 2.75]:
        t_k = bar_start + int(beat * beat_len * Fs)
        end_k = min(t_k + len(kick_lofi), total_len)
        neut_left[t_k:end_k] += kick_lofi[:end_k-t_k]
        neut_right[t_k:end_k] += kick_lofi[:end_k-t_k]

    for beat in [1, 3]:
        t_s = bar_start + int(beat * beat_len * Fs)
        end_s = min(t_s + len(snare_lofi), total_len)
        neut_left[t_s:end_s] += snare_lofi[:end_s-t_s]
        neut_right[t_s:end_s] += snare_lofi[:end_s-t_s]

    for step in range(8):
        t_h = bar_start + int(step * 0.5 * beat_len * Fs)
        h = make_hihat(0.04) * 0.22
        end_h = min(t_h + len(h), total_len)
        neut_left[t_h:end_h] += h[:end_h-t_h]
        neut_right[t_h:end_h] += h[:end_h-t_h]

    # Warm mellow chords
    t_c = bar_start
    c_audio = synth_poly(chord_notes, bar_len * 0.9, 'rhodes') * 0.32
    end_c = min(t_c + len(c_audio), total_len)
    neut_left[t_c:end_c] += c_audio[:end_c-t_c]
    neut_right[t_c:end_c] += c_audio[:end_c-t_c]

    # Warm bass
    t_b = bar_start
    b_len = int(bar_len * Fs)
    t_arr = np.linspace(0, bar_len, b_len, False)
    bass = np.sin(2 * np.pi * bass_freq * t_arr) * 0.42 * np.exp(-0.2 * t_arr)
    end_b = min(t_b + b_len, total_len)
    neut_left[t_b:end_b] += bass[:end_b-t_b]
    neut_right[t_b:end_b] += bass[:end_b-t_b]

write_wav("neutral.wav", np.column_stack((neut_left, neut_right)))
print("All professional music beats successfully generated!")
