## ============================================================
## setup_waveform.do
## ModelSim script: compiles, simulates, and formats the
## ECG timing waveform for screenshot
##
## HOW TO RUN:
##   In ModelSim menu: File > Load Script > select this file
##   OR in ModelSim console type:
##     do setup_waveform.do
## ============================================================

# ── 1. Create work library ────────────────────────────────────────────────────
vlib work
vmap work work

# ── 2. Compile design files ───────────────────────────────────────────────────
vcom -93 -work work ecg_timing_demo.vhd
vcom -93 -work work ecg_timing_demo_tb.vhd

# ── 3. Load simulation ────────────────────────────────────────────────────────
vsim -t 1ps work.ecg_timing_demo_tb

# ── 4. Open and clear waveform window ─────────────────────────────────────────
delete wave *

# ── 5. Add signals with labels ────────────────────────────────────────────────

# Divider: UART Phase
add wave -divider "── UART Accumulation ──────────────────────────"
add wave -label "UART: Receive 128 samples (355 ms)" \
         -color "Cyan" \
         -height 30 \
         /ecg_timing_demo_tb/uart_accumulate

# Divider: CNN phases (group)
add wave -divider "── CNN Inference (2.2 ms total) ───────────────"
add wave -label "CNN Active" \
         -color "Yellow" \
         -height 30 \
         /ecg_timing_demo_tb/cnn_active

# Individual CNN layers
add wave -divider "   Conv Layers"
add wave -label "Conv1  (1→8,  len=128,  307 µs)" \
         -color "Green" \
         -height 25 \
         /ecg_timing_demo_tb/conv1_active

add wave -label "Conv2  (8→16, len=64,   307 µs)" \
         -color "Green" \
         -height 25 \
         /ecg_timing_demo_tb/conv2_active

add wave -label "Conv3  (16→32,len=32,   307 µs)" \
         -color "Green" \
         -height 25 \
         /ecg_timing_demo_tb/conv3_active

add wave -label "Conv4  (32→32,len=16,   154 µs)" \
         -color "Green" \
         -height 25 \
         /ecg_timing_demo_tb/conv4_active

add wave -label "Conv5  (32→1, len=8,      2 µs)" \
         -color "Green" \
         -height 25 \
         /ecg_timing_demo_tb/conv5_active

add wave -divider "   Linear Layers"
add wave -label "Linear1 (128→64,        983 µs)" \
         -color "Orange" \
         -height 25 \
         /ecg_timing_demo_tb/linear1_active

add wave -label "Linear2+3 (64→16→8,     138 µs)" \
         -color "Orange" \
         -height 25 \
         /ecg_timing_demo_tb/linear2_3_active

add wave -divider "   Fusion / Classifier / Argmax"
add wave -label "Fusion + Classifier (8→8,  8 µs)" \
         -color "Magenta" \
         -height 25 \
         /ecg_timing_demo_tb/fusion_cls_active

add wave -label "Argmax (find max class,    1 µs)" \
         -color "Magenta" \
         -height 25 \
         /ecg_timing_demo_tb/argmax_active

# Divider: Output
add wave -divider "── Classification Output ──────────────────────"
add wave -label "result_valid: LCD/LED update (20 µs)" \
         -color "Red" \
         -height 30 \
         /ecg_timing_demo_tb/result_valid

# ── 6. Run simulation (just past 358 ms to capture everything) ────────────────
run 358 ms

# ── 7. Zoom to fit ────────────────────────────────────────────────────────────
wave zoom full

# ── 8. Print instructions ─────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Waveform ready for screenshot!"
echo " - Zoom in on the right side (~355-358 ms) to see CNN detail"
echo " - Use View > Zoom > Range to zoom to a specific time window"
echo " - For the full picture: View > Zoom > Full"
echo " - For CNN zoom only: set time range 355ms to 358ms"
echo "============================================================"
