# PowerPoint Layout Instructions
## ECG CNN Poster — 24" × 36" Portrait

---

## STEP 1: Set Up the Slide Canvas

1. Open PowerPoint → **Design** tab → **Slide Size** → **Custom Slide Size**
2. Set:
   - Width: **24 inches**
   - Height: **36 inches**
   - Orientation: **Portrait**
3. Click **Ensure Fit** when prompted
4. Save the file immediately as `ECG_CNN_Poster.pptx`

---

## STEP 2: Color Palette & Fonts

| Element            | Color Hex   | Notes                        |
|--------------------|-------------|------------------------------|
| Header background  | `#1B2A4A`   | Dark navy                    |
| Section header bar | `#1B2A4A`   | Same navy, full-width strip  |
| Body text          | `#2C2C2C`   | Dark gray, not pure black    |
| Accent / highlight | `#DA251D`   | TMU red for key numbers      |
| Secondary accent   | `#1565C0`   | Blue for architecture        |
| Background         | `#FFFFFF`   | White                        |
| Figure borders     | `#E0E0E0`   | Light gray, 1pt              |

**Font stack (all sans-serif):**
- Title: **Calibri Bold**, 64pt, white, centered
- Author line: **Calibri**, 24pt, white
- Section headers: **Calibri Bold**, 28pt, white on navy bar
- Body bullets: **Calibri**, 21pt, dark gray
- Table content: **Calibri**, 18pt
- Figure captions: **Calibri Italic**, 15pt, dark gray
- References: **Calibri**, 13pt

---

## STEP 3: Grid Layout (Absolute Positions)

All measurements are in inches from top-left corner of slide.

### HEADER BAND
| Element        | Left | Top  | Width | Height |
|----------------|------|------|-------|--------|
| Header bg rect | 0"   | 0"   | 24"   | 3.5"   |
| Title textbox  | 0.5" | 0.2" | 23"   | 2.2"   |
| Author textbox | 0.5" | 2.4" | 23"   | 0.9"   |
| TMU logo       | 21"  | 0.2" | 2.5"  | 1.2"   |

### COLUMN BOUNDARIES
| Column   | Left edge | Right edge | Width  |
|----------|-----------|------------|--------|
| Column 1 | 0.5"      | 7.75"      | 7.25"  |
| Column 2 | 8.25"     | 15.75"     | 7.5"   |
| Column 3 | 16.25"    | 23.5"      | 7.25"  |

Column content starts at **Top = 3.75"** (just below header).
Column content ends at **Top = 35.25"** (0.75" from bottom).
Usable column height: **31.5"**

---

## STEP 4: Section Header Bars

For each section, insert a **rectangle shape**:
- Width: full column width (7.25" or 7.5")
- Height: 0.4"
- Fill: `#1B2A4A` (navy)
- No border
- Text: section title, Calibri Bold 20pt, white, vertically centered, left-align with 0.15" left padding

---

## STEP 5: Column 1 Layout (Left)

### A — Motivation  (Top: 3.75", Height: ~12")
| Element                     | Top   | Height |
|-----------------------------|-------|--------|
| Section header bar "Why This Matters" | 3.75" | 0.4"   |
| Bullet textbox (4 bullets)  | 4.25" | 3.0"   |
| Figure A (ECG waveforms PNG)| 7.35" | 4.5"   |
| Figure A caption            | 11.9" | 0.7"   |

**Figure A import:**
- Insert → Pictures → `DOCs/Poster/figures/figure_A_ecg_waveforms.png`
- Resize to: Width = 7.25", Height ≈ 2.7" (maintain aspect ratio — lock it)
- Position: Left = 0.5", Top = 7.4"

---

### B — System Overview  (Top: ~12.7", Height: ~11.5")
| Element                         | Top    | Height |
|---------------------------------|--------|--------|
| Section header bar "System Architecture" | 12.7" | 0.4"  |
| Bullet textbox (4 bullets)      | 13.2"  | 2.5"  |
| Figure B — block diagram        | 15.8"  | 3.0"  |
| Figure B caption                | 18.85" | 0.7"  |
| Figure C — PC screenshot        | 19.65" | 3.5"  |
| Figure C caption                | 23.2"  | 0.7"  |

**Figure B: Draw directly in PowerPoint**
- Insert a set of rectangles + arrows to represent:
  `[MIT-BIH Files] → [Python PC] ──UART──→ [DE2 FPGA] → [LCD]`
- Use navy rectangles, white text, 12pt font, thin arrows in `#1565C0`
- Keep it simple: 4 boxes + 3 arrows, horizontal left-to-right flow

**Figure C:** Insert user-provided screenshot, crop to matplotlib window only.

---

## STEP 6: Column 2 Layout (Middle)

### C — CNN Architecture  (Top: 3.75", Height: ~17")
| Element                         | Top    | Height |
|---------------------------------|--------|--------|
| Section header "ZolotyhNet — Dual-Path 1D CNN" | 3.75" | 0.4"  |
| Bullet textbox (5 bullets)      | 4.25"  | 3.5"  |
| Figure D — architecture diagram | 7.85"  | 7.5"  |
| Figure D caption                | 15.4"  | 0.9"  |
| Key specs table                 | 16.4"  | 3.5"  |

**Figure D: Architecture diagram — draw in PowerPoint**

Draw a vertical dual-path diagram:

```
         [INPUT: 128 samples]
              /          \
    [Conv Path]        [FC Path]
    Conv(1→8)          Flatten(128)
    MaxPool             Linear(128→64)
    Conv(8→16)          Linear(64→16)
    MaxPool             Linear(16→8)
    Conv(16→32)              |
    MaxPool                  |
    Conv(32→32)              |
    MaxPool                  |
    Conv(32→1) → 8 vals      8 vals
              \          /
           [Element-wise ADD]
                  |
           Linear(8→8) Classifier
                  |
               [ARGMAX]
                  |
          [Class Output: 0–7]
```

Tips for drawing this in PowerPoint:
- Use blue rounded rectangles for Conv layers, green for FC layers
- Gray rounded rectangle for fusion and classifier
- Dark navy for input/output boxes
- Thin navy arrows, 1.5pt weight
- Keep all text at 9–11pt
- Target size: 7.4" wide × 7.2" tall

**Key specs table:**
- Insert → Table, 2 columns × 6 rows
- Header row: navy fill, white text, 12pt bold
- Body rows: alternating white and `#F5F5F5`
- Content from `poster_content.md` table

---

### D — Hardware Implementation  (Top: ~21", Height: ~14")
| Element                            | Top    | Height |
|------------------------------------|--------|--------|
| Section header "FPGA Hardware Accelerator" | 21.0" | 0.4"  |
| Bullet textbox (5 bullets)         | 21.5"  | 3.2"  |
| Figure G — resource chart PNG      | 24.8"  | 2.8"  |
| Figure G caption                   | 27.65" | 0.7"  |
| Figure E (board photo "Normal")    | 28.45" | 2.8"  |
| Figure F (board photo "Abnormal")  | 28.45" | 2.8"  |  ← side by side!
| Board photo caption                | 31.3"  | 0.8"  |

**Figure G import:**
- `DOCs/Poster/figures/figure_G_resource_utilization.png`
- Width = 7.4", maintain aspect ratio
- Position: Left = 8.25", Top = 24.8"

**Figures E & F (board photos):**
- Place side by side — each photo: Width = 3.5", Height ≈ 2.6"
- Figure E: Left = 8.25", Top = 28.45"
- Figure F: Left = 12.0", Top = 28.45"
- Add a small label below each: "Normal" and "Abnormal" in 14pt bold

---

## STEP 7: Column 3 Layout (Right)

### E — Results  (Top: 3.75", Height: ~19")
| Element                            | Top    | Height |
|------------------------------------|--------|--------|
| Section header "Classification Performance" | 3.75" | 0.4"  |
| Bullet textbox (5 bullets)         | 4.25"  | 3.5"  |
| Figure H — confusion matrix PNG    | 7.85"  | 6.8"  |
| Figure H caption                   | 14.7"  | 0.9"  |
| Figure I — model comparison PNG    | 15.7"  | 4.0"  |
| Figure I caption                   | 19.75" | 0.7"  |
| Figure J — timing callout boxes    | 20.55" | 2.5"  |
| Figure J caption                   | 23.1"  | 0.5"  |

**Figure H import:**
- `DOCs/Poster/figures/figure_H_confusion_matrix.png`
- Width = 7.25", maintain aspect ratio
- Position: Left = 16.25", Top = 7.85"

**Figure I import:**
- `DOCs/Poster/figures/figure_I_model_comparison.png`
- Width = 7.25", maintain aspect ratio
- Position: Left = 16.25", Top = 15.7"

**Figure J — Timing callout boxes (draw in PowerPoint):**
- Draw 3 rounded rectangle boxes side by side, equal size (~2.2" × 2.0" each)
- Fill: `#1B2A4A` (navy), white text
- Box 1: Large number `2.2 ms` (36pt bold white), label `CNN inference per window` (14pt white)
- Box 2: `360 Hz` (36pt bold white), label `UART stream rate` (14pt white)
- Box 3: `357 ms` (36pt bold white), label `End-to-end latency` (14pt white)
- Space evenly across 7.25" width with 0.1" gaps

---

### F — Conclusions  (Top: ~23.7", Height: ~9")
| Element                        | Top    | Height |
|--------------------------------|--------|--------|
| Section header "Key Contributions" | 23.7" | 0.4"  |
| Checkmark bullets (6 items)    | 24.2"  | 5.2"  |
| "Future Work" label (no bar)   | 29.5"  | 0.3"  |
| Future work bullets (3 items)  | 29.85" | 1.9"  |

For the checkmark bullets: use a custom bullet character ✓ in `#2E7D32` (green)
Set bullet character: Insert Symbol → Unicode 2713

---

### G — References  (Top: ~31.85", Height: ~2.5")
| Element                    | Top    | Height |
|----------------------------|--------|--------|
| Thin divider line          | 31.85" | 0.05"  |
| References textbox         | 31.95" | 2.2"   |
| (Optional QR code)         | 34.25" | 0.9"   |

References: 13pt, Calibri, single spaced, dark gray `#555555`

---

## STEP 8: Footer Band

| Element           | Left | Top    | Width | Height |
|-------------------|------|--------|-------|--------|
| Footer bg rect    | 0"   | 35.25" | 24"   | 0.75"  |
| Footer text       | 0.5" | 35.3"  | 23"   | 0.6"   |

Footer fill: `#1B2A4A`, text color: white, 14pt
Footer text: `Toronto Metropolitan University  |  Dept. of Electrical, Computer and Biomedical Engineering  |  2026`

---

## STEP 9: Final Checklist Before Printing

- [ ] Slide size confirmed: exactly 24" × 36"
- [ ] All text readable from ~1.5 meters (arm's length) — minimum 20pt body text
- [ ] Figures E and F (board photos) inserted and sharp — zoom in to verify no pixelation
- [ ] Figure C (PC screenshot) inserted
- [ ] All figure captions present
- [ ] Header TMU logo placed (get high-res PNG from TMU website)
- [ ] Supervisor name added to author line
- [ ] Reference list complete (add GK02 citation if available)
- [ ] Export as PDF: File → Save As → PDF, ensure "Standard" quality selected
- [ ] Verify PDF page size = 24" × 36" (open in Acrobat, check Document Properties)

---

## STEP 10: Export to PDF

**File → Save As → PDF**
- Quality: Standard (publishing and printing)
- Check "Optimize for: Standard"

After export:
- Open PDF in Acrobat Reader
- File → Properties → Description → check page size is 24" × 36"

Send the PDF to the printer exactly as-is. Do NOT let the printer scale it.

---

## TMU Logo

Download the official TMU logo from:
`https://www.torontomu.ca/brand/visual-identity/logo/`
Use the **horizontal full-colour logo** on white backgrounds.
Use the **reversed (white) version** on the navy header.
Minimum logo width: 1.5" at 300 DPI = 450 px wide.
