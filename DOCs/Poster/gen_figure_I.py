"""
Generate Figure I: Model Accuracy vs FPGA Feasibility Chart
Horizontal bar chart comparing ZolotyhNet against alternative models.
Saved at 300 DPI for poster print quality.
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Models: (label, accuracy, fpga_feasible, num_params)
models = [
    ('EcgResNet34\n(~500K params)',   99.38, False),
    ('HeartNetIEEE\n(~48K params)',   98.64, False),
    ('ZolotyhNet (Ours)\n(~14.7K params)', 95.75, True),
]

labels   = [m[0] for m in models]
accs     = [m[1] for m in models]
feasible = [m[2] for m in models]

NAVY    = '#1B2A4A'
BLUE    = '#1565C0'
GRAY    = '#BDBDBD'
GREEN   = '#2E7D32'
RED_ACC = '#DA251D'

colors = [GRAY, GRAY, RED_ACC]   # highlight ours

fig, ax = plt.subplots(figsize=(6, 3.2), dpi=300)
fig.patch.set_facecolor('white')

y = np.arange(len(models))
bar_height = 0.45

bars = ax.barh(y, accs, height=bar_height, color=colors, zorder=3,
               edgecolor='white', linewidth=0.5)

# Accuracy labels
for bar, acc, fp in zip(bars, accs, feasible):
    color = 'white' if fp else '#333333'
    ax.text(bar.get_width() - 0.3, bar.get_y() + bar.get_height()/2,
            f'{acc:.2f}%', ha='right', va='center',
            fontsize=11, fontweight='bold', color=color)

# FPGA feasibility badges
for i, (acc, fp) in enumerate(zip(accs, feasible)):
    badge_text = '✓ FPGA' if fp else '✗ FPGA'
    badge_color = GREEN if fp else '#999999'
    ax.text(acc + 0.3, i, badge_text,
            ha='left', va='center', fontsize=9,
            color=badge_color, fontweight='bold')

ax.set_xlim(90, 101.5)
ax.set_ylim(-0.6, len(models) - 0.4)
ax.set_yticks(y)
ax.set_yticklabels(labels, fontsize=10, color=NAVY)
ax.set_xlabel('Validation Accuracy (%)', fontsize=10, color=NAVY)
ax.set_title('Model Accuracy vs. FPGA Deployability\n(MIT-BIH Arrhythmia Database)',
             fontsize=11, fontweight='bold', color=NAVY, pad=8)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.tick_params(axis='x', labelsize=9)
ax.set_xticks([90, 93, 96, 99])
ax.xaxis.grid(True, alpha=0.3, linestyle='--')
ax.set_axisbelow(True)

# Accuracy trade-off annotation
ax.annotate('3.6% accuracy\ntrade-off for\nFPGA feasibility',
            xy=(95.75, 0), xytext=(92.5, 0.85),
            fontsize=7.5, color='#555555',
            arrowprops=dict(arrowstyle='->', color='#888888', lw=1.0),
            ha='center')

plt.tight_layout()
out_path = os.path.join(OUTPUT_DIR, 'figure_I_model_comparison.png')
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"Saved: {out_path}")
plt.close()
