"""
Generate Figure A: ECG Arrhythmia Waveform Types (3-panel)
Shows 128-sample beat windows for Normal (N), PVC (V), and LBBB (L)
Saved at 300 DPI for poster print quality.
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import scipy.signal

# ── path setup to use the project's ecg_dat_reader ──────────────────────────
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(PROJECT_ROOT, 'python'))

from ecg_dat_reader import MITBIHReader

ECG_DIR = os.path.join(PROJECT_ROOT, 'ECG signals')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

RECORDS = {
    'Normal (N)':  os.path.join(ECG_DIR, 'Normal', '100'),
    'PVC (V)':     os.path.join(ECG_DIR, 'PVC',    '208'),
    'LBBB (L)':    os.path.join(ECG_DIR, 'LBBB',   '214'),
}

COLORS = {
    'Normal (N)': '#2196F3',   # blue
    'PVC (V)':    '#F44336',   # red
    'LBBB (L)':   '#4CAF50',   # green
}

WINDOW = 128   # samples
FS     = 360   # Hz
TIME   = np.arange(WINDOW) / FS * 1000  # milliseconds

def extract_beat_window(signal, beat_idx):
    """Return a 128-sample window centered on beat_idx."""
    start = beat_idx - WINDOW // 2
    end   = beat_idx + WINDOW // 2
    if start < 0 or end > len(signal):
        return None
    return signal[start:end]

def find_good_beat(signal, skip_beats=5):
    """Find R-peaks and return one clean beat window (skip the first few)."""
    peaks, _ = scipy.signal.find_peaks(signal, distance=180, height=np.percentile(signal, 70))
    for peak in peaks[skip_beats:]:
        window = extract_beat_window(signal, peak)
        if window is not None:
            return window
    return None

# ── load signals ─────────────────────────────────────────────────────────────
windows  = {}
for label, path in RECORDS.items():
    reader = MITBIHReader(path)
    sig    = reader.read_signal(0)
    win    = find_good_beat(sig)
    if win is None:
        raise RuntimeError(f"Could not find a clean beat in {path}")
    windows[label] = win
    print(f"  [{label}] beat window extracted, range {win.min():.3f}–{win.max():.3f} mV")

# ── plot ──────────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 3, figsize=(12, 3.8), dpi=300)
fig.patch.set_facecolor('white')

for ax, (label, win) in zip(axes, windows.items()):
    color = COLORS[label]
    ax.plot(TIME, win, color=color, linewidth=1.8, antialiased=True)
    ax.set_title(label, fontsize=14, fontweight='bold', color=color, pad=8)
    ax.set_xlabel('Time (ms)', fontsize=11)
    if ax == axes[0]:
        ax.set_ylabel('Amplitude (mV)', fontsize=11)
    ax.tick_params(labelsize=9)
    ax.set_xlim(TIME[0], TIME[-1])
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(True, alpha=0.25, linestyle='--', linewidth=0.6)
    ax.axvline(x=TIME[WINDOW//2], color='gray', linestyle=':', linewidth=0.8, alpha=0.6)

plt.suptitle('ECG Arrhythmia Beat Types (128-sample window @ 360 Hz)',
             fontsize=13, fontweight='bold', y=1.02, color='#1B2A4A')
plt.tight_layout()

out_path = os.path.join(OUTPUT_DIR, 'figure_A_ecg_waveforms.png')
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"\nSaved: {out_path}")
plt.close()
