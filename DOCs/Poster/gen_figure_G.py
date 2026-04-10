"""
Generate Figure G: FPGA Resource Utilization Chart
Horizontal bar chart showing LE and M4K usage on Cyclone II.
Saved at 300 DPI for poster print quality.
"""
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'figures')
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Resource data
resources = ['Logic Elements\n(LEs)', 'M4K RAM\nBlocks']
used       = [13, 61]        # percentage used
available  = [100-13, 100-61]  # remaining

NAVY = '#1B2A4A'
BLUE = '#1565C0'
LIGHT = '#BBDEFB'
RED_ACC = '#DA251D'

fig, ax = plt.subplots(figsize=(5.5, 2.8), dpi=300)
fig.patch.set_facecolor('white')

bar_height = 0.45
y = np.arange(len(resources))

# Background bars (total capacity)
ax.barh(y, [100, 100], height=bar_height, color=LIGHT, zorder=2, label='Available')
# Used bars
bars = ax.barh(y, used, height=bar_height, color=[BLUE, RED_ACC], zorder=3)

# Percentage labels inside bars
for bar, pct in zip(bars, used):
    ax.text(pct/2, bar.get_y() + bar.get_height()/2,
            f'{pct}%', ha='center', va='center',
            fontsize=14, fontweight='bold', color='white', zorder=5)

# Total availability label at right
for i, (pct, avail) in enumerate(zip(used, [33216, 105])):
    ax.text(102, i, f'{pct}% of {avail:,}',
            ha='left', va='center', fontsize=9, color='#444444')

ax.set_xlim(0, 130)
ax.set_ylim(-0.5, len(resources) - 0.5)
ax.set_yticks(y)
ax.set_yticklabels(resources, fontsize=11, fontweight='bold', color=NAVY)
ax.set_xlabel('Utilization (%)', fontsize=10, color=NAVY)
ax.set_title('FPGA Resource Utilization\n(Cyclone II EP2C35F672C6)',
             fontsize=11, fontweight='bold', color=NAVY, pad=8)
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.tick_params(axis='x', labelsize=9)
ax.set_xticks([0, 25, 50, 75, 100])
ax.xaxis.grid(True, alpha=0.3, linestyle='--')
ax.set_axisbelow(True)

# Constraint label
ax.annotate('← M4K is binding\nconstraint', xy=(61, 0), xytext=(75, 0),
            fontsize=8, color=RED_ACC,
            arrowprops=dict(arrowstyle='->', color=RED_ACC, lw=1.2),
            va='center')

plt.tight_layout()
out_path = os.path.join(OUTPUT_DIR, 'figure_G_resource_utilization.png')
plt.savefig(out_path, dpi=300, bbox_inches='tight', facecolor='white')
print(f"Saved: {out_path}")
plt.close()
