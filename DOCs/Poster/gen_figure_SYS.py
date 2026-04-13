"""
Generate figure_SYS_block_diagram.png
Run from project root:
    python "DOCs/Poster/gen_figure_SYS.py"
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

NAVY  = '#1B2A4A'
BLUE  = '#1565C0'
DBLUE = '#0D47A1'
GREEN = '#2E7D32'
GRAY  = '#37474F'
WHITE = '#FFFFFF'
BG    = '#F0F4F8'

fig, ax = plt.subplots(figsize=(16, 6), dpi=200)
fig.patch.set_facecolor(BG)
ax.set_facecolor(BG)
ax.set_xlim(0, 16)
ax.set_ylim(0, 6)
ax.axis('off')

# ── draw_box: cx, cy = center; w, h = size ───────────────────────────────────
def draw_box(cx, cy, w, h, lines, colors, sizes):
    """
    lines  : list of strings (1 per text row)
    colors : list of hex colors per line
    sizes  : list of font sizes per line
    """
    rect = FancyBboxPatch(
        (cx - w/2, cy - h/2), w, h,
        boxstyle='round,pad=0.06',
        facecolor=NAVY if colors[0] == WHITE else colors[0],
        edgecolor='white', linewidth=2.5, zorder=3
    )
    # Use first color as box fill
    fill = colors[0]
    rect.set_facecolor(fill)
    ax.add_patch(rect)

    n = len(lines)
    # distribute lines evenly inside box
    spacing = h / (n + 1)
    for i, (txt, col, sz) in enumerate(zip(lines, colors, sizes)):
        y_pos = (cy + h/2) - spacing * (i + 1)
        ax.text(cx, y_pos, txt,
                ha='center', va='center',
                fontsize=sz, fontweight='bold' if i == 0 else 'normal',
                color=col, zorder=4)

# ── draw_harrow: horizontal arrow with label ABOVE the midpoint ──────────────
def draw_harrow(x1, x2, y, label='', color='#555555'):
    ax.annotate('',
                xy=(x2, y), xytext=(x1, y),
                arrowprops=dict(arrowstyle='->', color=color,
                                lw=2.5, mutation_scale=20),
                zorder=5)
    if label:
        ax.text((x1 + x2) / 2, y + 0.28, label,
                ha='center', va='bottom',
                fontsize=9, color=color, fontweight='bold')

# ── draw_varrow: vertical arrow with label to the RIGHT ──────────────────────
def draw_varrow(x, y1, y2, label='', color='#555555'):
    ax.annotate('',
                xy=(x, y2), xytext=(x, y1),
                arrowprops=dict(arrowstyle='->', color=color,
                                lw=2.2, mutation_scale=18),
                zorder=5)
    if label:
        ax.text(x + 0.2, (y1 + y2) / 2, label,
                ha='left', va='center',
                fontsize=9, color=color, fontweight='bold')

# ════════════════════════════════════════════════════════════════════════════
# MAIN ROW  y = 4.2
# ════════════════════════════════════════════════════════════════════════════
ROW_Y  = 4.2
BOX_H  = 1.3

# Box 1 — MIT-BIH  (x: 0.3 → 2.5)
draw_box(cx=1.4, cy=ROW_Y, w=2.2, h=BOX_H,
         lines=['MIT-BIH', 'ECG Database'],
         colors=[GRAY, WHITE, '#90CAF9'],
         sizes=[13, 9])

# Box 2 — Python PC  (x: 3.5 → 6.9)
draw_box(cx=5.2, cy=ROW_Y, w=3.4, h=BOX_H,
         lines=['Python PC', 'ECGStreamer  +  ECGVisualizer', '360 Hz streaming'],
         colors=[BLUE, WHITE, '#BBDEFB', '#90CAF9'],
         sizes=[13, 9, 8.5])

# Box 3 — FPGA  (x: 8.0 → 13.4)
draw_box(cx=10.7, cy=ROW_Y, w=5.4, h=BOX_H,
         lines=['Altera DE2  —  Cyclone II FPGA',
                'uart_receiver  →  buffer_128  →  ZolotyhNet CNN  →  cnn_interface',
                '50 MHz  |  13% LEs  |  61% M4K'],
         colors=[NAVY, WHITE, '#BBDEFB', '#90CAF9'],
         sizes=[13, 8.5, 8])

# Box 4 — LCD + LEDs  (x: 14.2 → 15.8)
draw_box(cx=15.0, cy=ROW_Y, w=1.8, h=BOX_H,
         lines=['LCD', '"Normal"', '"Abnormal"'],
         colors=[GREEN, WHITE, '#C8E6C9', '#A5D6A7'],
         sizes=[12, 9, 9])

# ── Main row arrows ───────────────────────────────────────────────────────────
# MIT-BIH right edge = 1.4 + 1.1 = 2.5
# Python left edge   = 5.2 - 1.7 = 3.5
draw_harrow(x1=2.5, x2=3.5, y=ROW_Y, label='read  .dat  /  .hea', color='#555555')

# Python right edge = 5.2 + 1.7 = 6.9
# FPGA left edge    = 10.7 - 2.7 = 8.0
draw_harrow(x1=6.9, x2=8.0, y=ROW_Y, label='RS-232 UART  —  115,200 baud  —  8N1', color=BLUE)

# FPGA right edge = 10.7 + 2.7 = 13.4
# LCD  left edge  = 15.0 - 0.9 = 14.1
draw_harrow(x1=13.4, x2=14.1, y=ROW_Y, label='class result', color=GREEN)

# ════════════════════════════════════════════════════════════════════════════
# BRANCH  PC → Visualization  (downward from Python box)
# ════════════════════════════════════════════════════════════════════════════
VIZ_Y = 1.8

# Python bottom = ROW_Y - BOX_H/2 = 4.2 - 0.65 = 3.55
# Viz box top   = VIZ_Y + BOX_H/2 = 1.8 + 0.65 = 2.45
draw_varrow(x=5.2, y1=3.55, y2=2.45, label='ECG display\n(display path)', color='#90CAF9')

draw_box(cx=5.2, cy=VIZ_Y, w=3.4, h=BOX_H,
         lines=['PC Screen', 'Scrolling ECG  —  matplotlib', 'raw mV  |  real-time animation'],
         colors=[DBLUE, WHITE, '#BBDEFB', '#90CAF9'],
         sizes=[13, 9, 8.5])

# ════════════════════════════════════════════════════════════════════════════
# TITLE
# ════════════════════════════════════════════════════════════════════════════
ax.text(8.0, 5.6, 'System Architecture  —  ECG CNN Hardware Accelerator',
        ha='center', va='center', fontsize=14, fontweight='bold', color=NAVY)

plt.tight_layout(pad=0.5)
out = os.path.join(OUTPUT_DIR, 'figure_SYS_block_diagram.png')
plt.savefig(out, dpi=200, bbox_inches='tight', facecolor=BG)
plt.close()
print(f"Saved: {out}")
