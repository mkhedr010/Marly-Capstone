"""
Generate Figure H: Confusion Matrix Heatmap (8x8)
Reads confusion_matrix.txt from the ecg-classification directory.
Saved at 300 DPI for poster print quality.
"""
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CONF_FILE    = os.path.join(PROJECT_ROOT, 'ECG CNN 1', 'ecg-classification', 'confusion_matrix.txt')
OUTPUT_DIR   = os.path.join(os.path.dirname(__file__), 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Class labels — MIT-BIH 8-class order
CLASS_LABELS = ['N', 'L', 'R', 'V', 'A', 'E', '!', '_']

# ── load data ─────────────────────────────────────────────────────────────────
conf = np.loadtxt(CONF_FILE, dtype=int)
print(f"Confusion matrix loaded: {conf.shape}")
print(f"Total samples: {conf.sum()}")
print(f"Overall accuracy: {np.trace(conf)/conf.sum()*100:.2f}%")

# Normalize to row percentages for display
row_sums = conf.sum(axis=1, keepdims=True)
conf_norm = np.where(row_sums > 0, conf / row_sums * 100, 0)

# ── plot ──────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(7, 6), dpi=300)
fig.patch.set_facecolor('white')

# Custom colormap: white → navy
cmap = mcolors.LinearSegmentedColormap.from_list(
    'ecg_cm', ['#FFFFFF', '#BBDEFB', '#1565C0', '#0D2B6E']
)

im = ax.imshow(conf_norm, cmap=cmap, vmin=0, vmax=100, aspect='auto')

# Color bar
cbar = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
cbar.set_label('Row %', fontsize=10, labelpad=6)
cbar.ax.tick_params(labelsize=9)

# Axis labels
ax.set_xticks(range(8))
ax.set_yticks(range(8))
ax.set_xticklabels(CLASS_LABELS, fontsize=11, fontweight='bold')
ax.set_yticklabels(CLASS_LABELS, fontsize=11, fontweight='bold')
ax.set_xlabel('Predicted Class', fontsize=12, labelpad=8)
ax.set_ylabel('Actual Class', fontsize=12, labelpad=8)
ax.set_title('Confusion Matrix — ZolotyhNet (95.75% Overall Accuracy)',
             fontsize=11, fontweight='bold', pad=12, color='#1B2A4A')

# Annotate cells
for i in range(8):
    for j in range(8):
        val_pct = conf_norm[i, j]
        val_cnt = conf[i, j]
        text_color = 'white' if val_pct > 50 else '#1B2A4A'
        if val_cnt > 0:
            ax.text(j, i, f'{val_pct:.0f}%\n({val_cnt})',
                    ha='center', va='center', fontsize=7.5,
                    color=text_color, fontweight='bold' if i == j else 'normal')
        else:
            ax.text(j, i, '0', ha='center', va='center',
                    fontsize=8, color='#AAAAAA')

# Highlight diagonal
for k in range(8):
    ax.add_patch(plt.Rectangle((k-0.5, k-0.5), 1, 1,
                                fill=False, edgecolor='#FFD600', linewidth=1.5))

plt.tight_layout()
out_path = os.path.join(OUTPUT_DIR, 'figure_H_confusion_matrix.png')
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"Saved: {out_path}")
plt.close()
