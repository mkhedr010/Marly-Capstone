# POSTER CONTENT — Ready to Paste into PowerPoint
## "Hardware Implementation of CNN as Part of SoC Design for ECG Analysis and Classification"
### Marly Barsoum | Toronto Metropolitan University | ECBE Dept. | 2026

---

## HEADER (full-width, dark navy background, white text)

**Title (60–72pt bold):**
Hardware Implementation of CNN as Part of SoC Design
for ECG Analysis and Classification

**Author line (24pt):**
Marly Barsoum — B.Eng. Electrical & Computer Engineering
Toronto Metropolitan University, 2026
Supervisor: [Supervisor name]

---

---

## COLUMN 1 — LEFT

---

### Section A: MOTIVATION

**Section header:** Why This Matters

**Bullets (use heart/lightning icons, 22pt):**
- Cardiovascular Whydisease: #1 cause of death worldwide — 17.9 million deaths per year
- ECG is the primary diagnostic tool — but manual reading is slow and requires specialists
- FPGAs enable real-time, deterministic, low-power AI inference at the edge — no cloud, no CPU
- Goal: Classify arrhythmias in **2.2 ms** on a $100 FPGA board

**Figure A label (16pt, below figure):**
Figure 1: Representative 128-sample beat windows for three arrhythmia classes extracted from
the MIT-BIH Arrhythmia Database (Record 100, 208, 214) at 360 Hz.

---

### Section B: SYSTEM OVERVIEW

**Section header:** System Architecture

**Bullets (22pt):**
- Python streams ECG records at 360 Hz via RS-232 UART from PC to FPGA
- CNN classifies each 128-sample beat window entirely in hardware
- Result displayed on LCD ("Normal" / "Abnormal") and green LED array
- No external memory — all 18 weight files stored in on-chip M4K ROM

**Figure B label:**
Figure 2: System block diagram. ECG records stream from the PC via UART; the FPGA
hardware accelerator classifies each beat and drives the LCD and LEDs.

*(Figure B = system block diagram — draw in PowerPoint, see layout instructions)*

**Figure C label:**
Figure 3: Python ECG visualizer displaying a scrolling real-time ECG waveform on the PC.

*(Figure C = screenshot of ecg_stream_visualize.py — user provides this)*

---

---

## COLUMN 2 — MIDDLE

---

### Section C: CNN ARCHITECTURE

**Section header:** ZolotyhNet — Dual-Path 1D CNN

**Bullets (22pt):**
- **Dual-path design:** Conv1D upper path (local morphology) + FC lower path (global statistics)
- **5 Conv1D layers** + 4 MaxPool → **3 Linear layers** → element-wise ADD fusion → Argmax
- **~14,700 parameters** — 34× smaller than EcgResNet34, fits entirely in on-chip ROM
- Trained on MIT-BIH Arrhythmia Database — 9,368-sample validation set
- Weights quantized to **Q8.8 fixed-point** (16-bit) — no floating-point hardware needed

**Figure D label:**
Figure 4: ZolotyhNet dual-path architecture. Upper convolutional path extracts local beat
morphology; lower fully-connected path captures global signal statistics. Paths fuse via
element-wise addition before the final 8-class classifier.

*(Figure D = architecture diagram — draw in PowerPoint, see layout instructions)*

**Small key-specs table (insert as PowerPoint table, 18pt):**

| Parameter      | Value                    |
|----------------|--------------------------|
| Input          | 128 samples @ 360 Hz     |
| Parameters     | ~14,700                  |
| Output classes | 8 arrhythmia types       |
| Quantization   | Q8.8 fixed-point (16-bit)|
| Weight storage | 18 on-chip M4K ROM files |

---

### Section D: HARDWARE IMPLEMENTATION

**Section header:** FPGA Hardware Accelerator

**Bullets (22pt):**
- **Time-multiplexed MAC engine:** 1 Conv1D engine handles all 5 conv layers sequentially
- **1 Linear engine** handles all 4 FC layers — keeps logic element usage to only 13%
- **18 on-chip M4K weight ROMs** — zero external memory bandwidth required
- 128-sample input buffer with automatic 12-bit → Q8.8 conversion pipeline
- HD44780 LCD + green LEDs display real-time classification result

**Figure G label:**
Figure 5: FPGA resource utilization on Cyclone II EP2C35F672C6. M4K RAM blocks
are the binding constraint at 61%; logic elements remain at only 13%.

**Figure E label:**
Figure 6 (left): Board during "Normal" classification — LCD reads "Normal."

**Figure F label:**
Figure 6 (right): Board during "Abnormal" classification — LCD reads "Abnormal."

*(Figures E and F = board photos — user provides these, place side by side)*

---

---

## COLUMN 3 — RIGHT

---

### Section E: RESULTS

**Section header:** Classification Performance

**Bullets (22pt):**
- **95.75% overall accuracy** on 9,368 MIT-BIH validation beats (8,970 correct)
- Normal (N): **99.37%** — near-perfect, dominates dataset
- LBBB (L): **96.41%** | RBBB (R): **94.76%** — well-classified
- Rare classes (E, !) underperform due to severe class imbalance (<0.6% of data)
- **2.2 ms** inference per beat window — 160× faster than the 355 ms UART fill time

**Figure H label:**
Figure 7: Confusion matrix for ZolotyhNet on the 9,368-sample MIT-BIH validation set.
Rows = actual class; columns = predicted class. Values shown as row percentage and count.

**Figure I label:**
Figure 8: Accuracy comparison. ZolotyhNet trades 3.6% accuracy vs. the best software-only
model (EcgResNet34) to achieve full FPGA deployability within Cyclone II resource limits.

**Figure J label — timing callout boxes (draw in PowerPoint):**

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   2.2 ms     │   │   360 Hz     │   │   357 ms     │
│              │   │              │   │              │
│ CNN inference│   │  UART stream │   │ End-to-end   │
│ per window   │   │  rate        │   │ latency      │
└──────────────┘   └──────────────┘   └──────────────┘
```

---

### Section F: CONCLUSIONS

**Section header:** Key Contributions

**Bullets with checkmarks (22pt):**
- ✓ Designed ZolotyhNet — a 14,700-parameter CNN deployable entirely within on-chip M4K ROM
- ✓ Q8.8 fixed-point quantization pipeline: PyTorch → 18 MIF files → VHDL ROM
- ✓ Time-multiplexed Conv1D + Linear MAC engines: **13% LEs, 61% M4K** on Cyclone II
- ✓ **95.75%** classification accuracy across 8 arrhythmia types
- ✓ **2.2 ms** FPGA inference — 160× within the per-beat timing budget
- ✓ Validated across ~32 different MIT-BIH ECG records: LCD and LED outputs correct

**Future Work (smaller text, 18pt, no header bar):**
- Implement batch normalization in fixed-point hardware to close accuracy gap
- INT8 quantization to halve M4K usage and enable larger architectures
- Port to Cyclone V to evaluate EcgResNet34 at 99.38% accuracy

---

### Section G: REFERENCES

*(14pt, condensed font)*

[1] G. B. Moody & R. G. Mark, "The impact of the MIT-BIH Arrhythmia Database," *IEEE Eng. Med. Biol. Mag.*, vol. 20, no. 3, pp. 45–50, 2001.

[2] A. Y. Hannun et al., "Cardiologist-level arrhythmia detection," *Nature Medicine*, vol. 25, pp. 65–69, 2019.

[3] M. Lyashuk & N. Zolotykh, "ecg-classification," GitHub, 2019–2021.

---

*(Optional QR code in bottom-right corner — link to GitHub repo)*

---

## NOTES FOR FIGURES THE USER MUST PROVIDE

**Figure C** — Screenshot of Python ECG visualizer:
- Run: `python python/ecg_stream_visualize.py --port COM[x] --file "ECG signals/Normal/100.dat"`
- Take a full-window screenshot while the ECG is scrolling
- Crop to just the matplotlib window
- Save as high-res PNG

**Figures E & F** — Board photos:
- Take with a proper camera, not phone camera if possible (or phone but good lighting)
- Get close enough that LCD text is clearly readable
- Take two: one showing "Normal" on LCD, one showing "Abnormal"
- Minimum 3000×2000 pixels for print quality
- Good lighting — no glare on the LCD
