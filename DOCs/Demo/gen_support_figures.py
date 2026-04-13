"""
Generate 2 support figures for the demo slides:
  1. figure_SYS_block_diagram.png  — system overview block diagram
  2. figure_QUANT_pipeline.png     — quantization pipeline flow

Run from project root:
    python "DOCs/Demo/gen_support_figures.py"
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', 'Poster', 'figures'
)
os.makedirs(OUTPUT_DIR, exist_ok=True)

NAVY  = '#1B2A4A'
BLUE  = '#1565C0'
RED   = '#DA251D'
LIGHT = '#BBDEFB'
GREEN = '#2E7D32'
WHITE = '#FFFFFF'
LGRAY = '#F5F5F5'
DGRAY = '#555555'

# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE SYS — System Architecture Block Diagram
# ═══════════════════════════════════════════════════════════════════════════════
def add_box(ax, x, y, w, h, label, sublabel='', color=BLUE, fontsize=11):
    box = FancyBboxPatch((x - w/2, y - h/2), w, h,
                          boxstyle="round,pad=0.02",
                          facecolor=color, edgecolor=WHITE, linewidth=1.5)
    ax.add_patch(box)
    ax.text(x, y + (0.04 if sublabel else 0), label,
            ha='center', va='center', fontsize=fontsize,
            fontweight='bold', color=WHITE)
    if sublabel:
        ax.text(x, y - 0.09, sublabel,
                ha='center', va='center', fontsize=8, color='#BBDEFB')

def arrow(ax, x1, y1, x2, y2, label='', color=DGRAY):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle='->', color=color, lw=2.0))
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        ax.text(mx, my + 0.06, label, ha='center', va='bottom',
                fontsize=8.5, color=color, style='italic')

fig, ax = plt.subplots(figsize=(13, 4), dpi=200)
fig.patch.set_facecolor(LGRAY)
ax.set_facecolor(LGRAY)
ax.set_xlim(0, 13)
ax.set_ylim(0, 4)
ax.axis('off')

# ── Row 1: main data flow ──────────────────────────────────────────────────
add_box(ax, 1.6, 2.2, 2.6, 1.0, 'MIT-BIH', 'ECG Database', color='#37474F', fontsize=10)
add_box(ax, 4.5, 2.2, 2.6, 1.0, 'Python PC', '360 Hz streaming', color=BLUE)
add_box(ax, 8.0, 2.2, 3.2, 1.0, 'Altera DE2 FPGA', 'Cyclone II', color=NAVY)
add_box(ax, 11.6, 2.2, 2.2, 1.0, 'LCD + LEDs', '"Normal" / "Abnormal"', color=GREEN)

# arrows main flow
arrow(ax, 2.95, 2.2, 3.2, 2.2, 'read .dat')
arrow(ax, 5.85, 2.2, 6.45, 2.2, 'UART RS-232\n115,200 baud')
arrow(ax, 9.65, 2.2, 10.5, 2.2, 'class result')

# ── Python internals (below PC box) ───────────────────────────────────────
add_box(ax, 3.5, 0.75, 1.8, 0.55, 'ECGStreamer', '360 Hz daemon', color='#1976D2', fontsize=9)
add_box(ax, 5.5, 0.75, 2.0, 0.55, 'ECGVisualizer', 'main thread', color='#1976D2', fontsize=9)
ax.annotate('', xy=(4.4, 0.75), xytext=(3.5, 0.75),
            arrowprops=dict(arrowstyle='->', color=BLUE, lw=1.5))
ax.text(3.95, 0.88, 'queue', ha='center', fontsize=7.5, color=BLUE)
ax.text(4.5, 0.45, '↓  PC screen visualization', ha='center', fontsize=8, color=DGRAY)
# connector python box down
ax.plot([4.5, 4.5], [1.7, 1.04], color='#90CAF9', lw=1.2, linestyle='--')

# ── FPGA internals ─────────────────────────────────────────────────────────
add_box(ax, 7.2, 0.75, 2.0, 0.55, 'UART Receiver', '2-byte framing', color=NAVY, fontsize=9)
add_box(ax, 9.3, 0.75, 1.8, 0.55, 'buffer_128', '12-bit → Q8.8', color=NAVY, fontsize=9)
add_box(ax, 11.2, 0.75, 2.2, 0.55, 'ZolotyhNet\nAccelerator', color=RED, fontsize=8.5)
ax.annotate('', xy=(8.2, 0.75), xytext=(7.2, 0.75),
            arrowprops=dict(arrowstyle='->', color='#90CAF9', lw=1.5))
ax.annotate('', xy=(10.1, 0.75), xytext=(9.3, 0.75),
            arrowprops=dict(arrowstyle='->', color='#90CAF9', lw=1.5))
ax.annotate('', xy=(11.2, 0.75), xytext=(10.2, 0.75),
            arrowprops=dict(arrowstyle='->', color='#90CAF9', lw=1.5))
ax.plot([8.0, 8.0], [1.7, 1.04], color='#90CAF9', lw=1.2, linestyle='--')
ax.plot([11.2, 11.2], [1.04, 1.7], color='#90CAF9', lw=1.2, linestyle='--')

# title
ax.text(6.5, 3.7, 'System Architecture Overview',
        ha='center', fontsize=14, fontweight='bold', color=NAVY)

plt.tight_layout(pad=0.3)
out = os.path.join(OUTPUT_DIR, 'figure_SYS_block_diagram.png')
plt.savefig(out, dpi=200, bbox_inches='tight', facecolor=LGRAY)
plt.close()
print(f"Saved: {out}")

# ═══════════════════════════════════════════════════════════════════════════════
# FIGURE QUANT — Quantization Pipeline
# ═══════════════════════════════════════════════════════════════════════════════
fig, ax = plt.subplots(figsize=(13, 3.5), dpi=200)
fig.patch.set_facecolor(LGRAY)
ax.set_facecolor(LGRAY)
ax.set_xlim(0, 13)
ax.set_ylim(0, 3.5)
ax.axis('off')

steps = [
    (1.3,  1.75, 2.2, 1.0, 'Train\nZolotyhNet', 'PyTorch float32',  '#37474F'),
    (3.9,  1.75, 2.2, 1.0, 'Extract\nWeights', 'extract_weights.py', BLUE),
    (6.5,  1.75, 2.2, 1.0, 'Q8.8 Conversion', 'round(w × 256)\n→ int16', BLUE),
    (9.1,  1.75, 2.2, 1.0, '18 MIF Files', 'Altera ROM format',    NAVY),
    (11.7, 1.75, 2.2, 1.0, 'M4K On-Chip\nROM', '61% utilized',     RED),
]
for x, y, w, h, lbl, sub, col in steps:
    add_box(ax, x, y, w, h, lbl, sub, color=col, fontsize=10)

for i in range(len(steps)-1):
    x1 = steps[i][0] + steps[i][2]/2
    x2 = steps[i+1][0] - steps[i+1][2]/2
    arrow(ax, x1, 1.75, x2, 1.75, color='#555555')

# Q8.8 annotation below
ax.text(6.5, 0.65, 'Q8.8:  [sign | 7 integer bits | 8 fractional bits]  →  range: −128 to +127.996',
        ha='center', fontsize=9, color=NAVY,
        bbox=dict(boxstyle='round,pad=0.3', facecolor=LIGHT, edgecolor=BLUE, alpha=0.8))
ax.text(6.5, 0.22, 'MAC: Q8.8 × Q8.8 → Q16.16 (32-bit accumulator)  →  right-shift 8  →  Q8.8',
        ha='center', fontsize=8.5, color=DGRAY, style='italic')

ax.text(6.5, 3.2, 'Fixed-Point Quantization Pipeline: PyTorch → FPGA Hardware',
        ha='center', fontsize=13, fontweight='bold', color=NAVY)

plt.tight_layout(pad=0.3)
out = os.path.join(OUTPUT_DIR, 'figure_QUANT_pipeline.png')
plt.savefig(out, dpi=200, bbox_inches='tight', facecolor=LGRAY)
plt.close()
print(f"Saved: {out}")

print("\nDone. Both support figures saved to DOCs/Poster/figures/")
