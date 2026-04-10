"""
Master figure generation script for the poster.
Run this from the project root:
    cd "c:/Users/bakkhedr/Desktop/marly capstone"
    python "DOCs/Poster/generate_all_figures.py"

Generates:
    DOCs/Poster/figures/figure_A_ecg_waveforms.png          (300 DPI)
    DOCs/Poster/figures/figure_G_resource_utilization.png   (300 DPI)
    DOCs/Poster/figures/figure_H_confusion_matrix.png       (300 DPI)
    DOCs/Poster/figures/figure_I_model_comparison.png       (300 DPI)
"""

import sys
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import scipy.signal

# ── paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
OUTPUT_DIR   = os.path.join(SCRIPT_DIR, 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

sys.path.insert(0, os.path.join(PROJECT_ROOT, 'python'))
from ecg_dat_reader import MITBIHReader

ECG_DIR   = os.path.join(PROJECT_ROOT, 'ECG signals')
CONF_FILE = os.path.join(PROJECT_ROOT, 'ECG CNN 1', 'ecg-classification', 'confusion_matrix.txt')

NAVY    = '#1B2A4A'
BLUE    = '#1565C0'
LIGHT   = '#BBDEFB'
RED_ACC = '#DA251D'
GREEN   = '#2E7D32'

# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE A — ECG arrhythmia waveforms (3-panel: Normal, PVC, LBBB)
# ═══════════════════════════════════════════════════════════════════════════════
print("\n─── Figure A: ECG Waveforms ───")

RECORDS = {
    'Normal (N)': os.path.join(ECG_DIR, 'Normal', '100'),
    'PVC (V)':    os.path.join(ECG_DIR, 'PVC',    '208'),
    'LBBB (L)':   os.path.join(ECG_DIR, 'LBBB',   '214'),
}
BEAT_COLORS = ['#2196F3', '#F44336', '#4CAF50']
WINDOW = 128
FS     = 360
TIME   = np.arange(WINDOW) / FS * 1000   # ms

def find_beat(signal, skip=5):
    peaks, _ = scipy.signal.find_peaks(signal, distance=180, height=np.percentile(signal, 70))
    for peak in peaks[skip:]:
        s = peak - WINDOW//2
        e = peak + WINDOW//2
        if s >= 0 and e <= len(signal):
            return signal[s:e]
    return None

wins = {}
for label, path in RECORDS.items():
    r = MITBIHReader(path)
    sig = r.read_signal(0)
    w   = find_beat(sig)
    if w is None:
        print(f"  WARNING: could not extract clean beat for {label}")
        w = sig[:WINDOW]
    wins[label] = w
    print(f"  {label}: range {w.min():.2f}–{w.max():.2f} mV")

fig, axes = plt.subplots(1, 3, figsize=(12, 3.8), dpi=300)
fig.patch.set_facecolor('white')
for ax, (label, w), color in zip(axes, wins.items(), BEAT_COLORS):
    ax.plot(TIME, w, color=color, linewidth=1.8)
    ax.set_title(label, fontsize=14, fontweight='bold', color=color, pad=7)
    ax.set_xlabel('Time (ms)', fontsize=11)
    if ax is axes[0]:
        ax.set_ylabel('Amplitude (mV)', fontsize=11)
    ax.tick_params(labelsize=9)
    ax.set_xlim(TIME[0], TIME[-1])
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(True, alpha=0.25, linestyle='--', linewidth=0.6)
    ax.axvline(x=TIME[WINDOW//2], color='gray', linestyle=':', linewidth=0.8, alpha=0.5)

plt.suptitle('ECG Arrhythmia Beat Types  —  128-sample window @ 360 Hz',
             fontsize=12, fontweight='bold', y=1.01, color=NAVY)
plt.tight_layout()
out = os.path.join(OUTPUT_DIR, 'figure_A_ecg_waveforms.png')
plt.savefig(out, dpi=300, bbox_inches='tight', facecolor='white')
plt.close()
print(f"  Saved: {out}")

# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE G — FPGA resource utilization
# ═══════════════════════════════════════════════════════════════════════════════
print("\n─── Figure G: Resource Utilization ───")

resources = ['Logic Elements\n(LEs)', 'M4K RAM\nBlocks']
used       = [13, 61]
totals     = [33216, 105]

fig, ax = plt.subplots(figsize=(5.5, 2.8), dpi=300)
fig.patch.set_facecolor('white')
y = np.arange(len(resources))
bh = 0.45

ax.barh(y, [100, 100], height=bh, color=LIGHT, zorder=2)
bars = ax.barh(y, used, height=bh, color=[BLUE, RED_ACC], zorder=3)

for bar, pct in zip(bars, used):
    ax.text(pct/2, bar.get_y() + bar.get_height()/2,
            f'{pct}%', ha='center', va='center',
            fontsize=14, fontweight='bold', color='white', zorder=5)
for i, (pct, tot) in enumerate(zip(used, totals)):
    ax.text(102, i, f'{pct}% of {tot:,}',
            ha='left', va='center', fontsize=9, color='#444444')

ax.set_xlim(0, 132)
ax.set_ylim(-0.55, len(resources)-0.45)
ax.set_yticks(y)
ax.set_yticklabels(resources, fontsize=11, fontweight='bold', color=NAVY)
ax.set_xlabel('Utilization (%)', fontsize=10, color=NAVY)
ax.set_title('FPGA Resource Utilization  (Cyclone II EP2C35F672C6)',
             fontsize=11, fontweight='bold', color=NAVY, pad=8)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_xticks([0, 25, 50, 75, 100])
ax.tick_params(axis='x', labelsize=9)
ax.xaxis.grid(True, alpha=0.3, linestyle='--')
ax.set_axisbelow(True)
ax.annotate('← binding\nconstraint', xy=(61, 0), xytext=(74, 0),
            fontsize=8, color=RED_ACC,
            arrowprops=dict(arrowstyle='->', color=RED_ACC, lw=1.2),
            va='center')

plt.tight_layout()
out = os.path.join(OUTPUT_DIR, 'figure_G_resource_utilization.png')
plt.savefig(out, dpi=300, bbox_inches='tight', facecolor='white')
plt.close()
print(f"  Saved: {out}")

# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE H — Confusion matrix heatmap
# ═══════════════════════════════════════════════════════════════════════════════
print("\n─── Figure H: Confusion Matrix ───")

CLASS_LABELS = ['N', 'L', 'R', 'V', 'A', 'E', '!', '_']
conf = np.loadtxt(CONF_FILE, dtype=int)
row_sums  = conf.sum(axis=1, keepdims=True)
conf_norm = np.where(row_sums > 0, conf / row_sums * 100, 0)
overall   = np.trace(conf) / conf.sum() * 100
print(f"  Overall accuracy: {overall:.2f}%  ({np.trace(conf)}/{conf.sum()})")

cmap = mcolors.LinearSegmentedColormap.from_list(
    'ecg', ['#FFFFFF', '#BBDEFB', '#1565C0', '#0D2B6E'])

fig, ax = plt.subplots(figsize=(7, 6), dpi=300)
fig.patch.set_facecolor('white')
im = ax.imshow(conf_norm, cmap=cmap, vmin=0, vmax=100, aspect='auto')
cbar = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
cbar.set_label('Row %', fontsize=10)
cbar.ax.tick_params(labelsize=9)

ax.set_xticks(range(8))
ax.set_yticks(range(8))
ax.set_xticklabels(CLASS_LABELS, fontsize=12, fontweight='bold')
ax.set_yticklabels(CLASS_LABELS, fontsize=12, fontweight='bold')
ax.set_xlabel('Predicted Class', fontsize=12, labelpad=8)
ax.set_ylabel('Actual Class', fontsize=12, labelpad=8)
ax.set_title(f'Confusion Matrix  —  ZolotyhNet ({overall:.2f}% Overall Accuracy)',
             fontsize=11, fontweight='bold', pad=12, color=NAVY)

for i in range(8):
    for j in range(8):
        vp = conf_norm[i, j]
        vc = conf[i, j]
        tc = 'white' if vp > 50 else NAVY
        if vc > 0:
            ax.text(j, i, f'{vp:.0f}%\n({vc})',
                    ha='center', va='center', fontsize=7.5,
                    color=tc, fontweight='bold' if i == j else 'normal')
        else:
            ax.text(j, i, '0', ha='center', va='center', fontsize=8, color='#BBBBBB')
    ax.add_patch(plt.Rectangle((i-0.5, i-0.5), 1, 1,
                                fill=False, edgecolor='#FFD600', linewidth=1.5))

plt.tight_layout()
out = os.path.join(OUTPUT_DIR, 'figure_H_confusion_matrix.png')
plt.savefig(out, dpi=300, bbox_inches='tight', facecolor='white')
plt.close()
print(f"  Saved: {out}")

# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE I — Model accuracy vs FPGA feasibility
# ═══════════════════════════════════════════════════════════════════════════════
print("\n─── Figure I: Model Comparison ───")

models_data = [
    ('EcgResNet34\n(~500K params)',        99.38, False),
    ('HeartNetIEEE\n(~48K params)',         98.64, False),
    ('ZolotyhNet (Ours)\n(~14.7K params)', 95.75, True),
]
labels   = [m[0] for m in models_data]
accs     = [m[1] for m in models_data]
feasible = [m[2] for m in models_data]
colors   = ['#BDBDBD', '#BDBDBD', RED_ACC]

fig, ax = plt.subplots(figsize=(6, 3.2), dpi=300)
fig.patch.set_facecolor('white')
y  = np.arange(len(models_data))
bh = 0.45
bars = ax.barh(y, accs, height=bh, color=colors, edgecolor='white', linewidth=0.5, zorder=3)

for bar, acc, fp in zip(bars, accs, feasible):
    tc = 'white' if fp else '#333333'
    ax.text(bar.get_width() - 0.25, bar.get_y() + bar.get_height()/2,
            f'{acc:.2f}%', ha='right', va='center',
            fontsize=11, fontweight='bold', color=tc)

for i, (acc, fp) in enumerate(zip(accs, feasible)):
    badge = '✓ FPGA' if fp else '✗ FPGA'
    bc    = GREEN if fp else '#999999'
    ax.text(acc + 0.2, i, badge, ha='left', va='center',
            fontsize=9, color=bc, fontweight='bold')

ax.set_xlim(90, 102)
ax.set_ylim(-0.6, len(models_data)-0.4)
ax.set_yticks(y)
ax.set_yticklabels(labels, fontsize=10, color=NAVY)
ax.set_xlabel('Validation Accuracy (%)', fontsize=10, color=NAVY)
ax.set_title('Model Accuracy vs. FPGA Deployability\n(MIT-BIH Arrhythmia Database, 9,368 samples)',
             fontsize=11, fontweight='bold', color=NAVY, pad=8)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_xticks([90, 93, 96, 99])
ax.tick_params(axis='x', labelsize=9)
ax.xaxis.grid(True, alpha=0.3, linestyle='--')
ax.set_axisbelow(True)
ax.annotate('3.6% accuracy\ntrade-off for\nFPGA feasibility',
            xy=(95.75, 0), xytext=(91.5, 0.85),
            fontsize=7.5, color='#555555',
            arrowprops=dict(arrowstyle='->', color='#888888', lw=1.0),
            ha='center')

plt.tight_layout()
out = os.path.join(OUTPUT_DIR, 'figure_I_model_comparison.png')
plt.savefig(out, dpi=300, bbox_inches='tight', facecolor='white')
plt.close()
print(f"  Saved: {out}")

print("\n✓ All 4 poster figures generated in DOCs/Poster/figures/")
