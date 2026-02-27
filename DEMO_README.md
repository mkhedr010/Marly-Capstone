# ECG Live Streaming Demo - Quick Start Guide

**Date**: February 26, 2026  
**Author**: Marly  
**Purpose**: Demo ECG data streaming from PC to FPGA with live visualization

---

## 🎯 What This Demo Does

1. **PC Side**: Streams ECG data via UART with live matplotlib visualization
2. **FPGA Side**: Receives data and shows activity via blinking LEDs
3. **Real-time**: See the ECG waveform scroll on your PC as it streams to the board

---

## 📦 What's Included

### Python Files (PC Side)
- `python/ecg_dat_reader.py` - Reads MIT-BIH .dat format files
- `python/ecg_streamer_live.py` - Main streaming app with live plot
- `python/requirements.txt` - Python dependencies

### VHDL Files (FPGA Side)
- `src/uart_receiver.vhd` - UART receiver (existing)
- `src/led_indicator.vhd` - LED blinker for visual feedback (NEW)
- `src/simple_demo_top.vhd` - Simplified top-level (NEW)
- `src/simple_demo.ucf` - Pin constraints (NEW)

### Data Files
- `ECG signals/15814.dat` - MIT-BIH ECG record
- `ECG signals/15814.hea` - Header file
- `python/data/*.csv` - CSV format ECG data

---

## 🚀 Setup Instructions

### Step 1: Install Python Dependencies

```bash
cd python
pip install -r requirements.txt
```

This installs:
- pyserial (UART communication)
- numpy (data processing)
- pandas (CSV loading)
- matplotlib (live plotting)

### Step 2: Set Up ISE Project

1. **Open Xilinx ISE**
2. **Create New Project**:
   - Name: `ecg_demo`
   - Location: `c:/Users/bakkhedr/Desktop/marly capstone/src`
   - Top-level: HDL
   - Device: Spartan-3E XC3S500E (your specific part)

3. **Add Source Files**:
   - `src/uart_receiver.vhd`
   - `src/led_indicator.vhd`
   - `src/simple_demo_top.vhd` (set as TOP MODULE)
   - `src/simple_demo.ucf`

4. **Synthesize**:
   - Click green check mark
   - Wait for synthesis to complete
   - Check for errors

5. **Implement Design**:
   - Generate Programming File
   - Wait for bitstream generation

### Step 3: Program the FPGA

1. Connect Spartan-3E board via USB
2. Power on the board
3. In ISE, right-click "Generate Programming File"
4. Select "Configure Target Device"
5. Program the `.bit` file to FPGA
6. **Verify LED[3] is blinking** (heartbeat - shows system is alive)

---

## 🎮 Running the Demo

### Quick Test with CSV File

```bash
cd python
python ecg_streamer_live.py --port COM3 --file data/normal_ecg.csv
```

**Replace COM3** with your actual COM port (check Device Manager on Windows)

### Full Demo with MIT-BIH Data

```bash
python ecg_streamer_live.py --port COM3 --file "ECG signals/15814" --signal 0 --loop
```

### What You Should See

**On PC**:
- Terminal shows connection status and streaming stats
- Matplotlib window opens with live scrolling ECG waveform
- Updates every 100ms (10 FPS)
- Shows sample count, time, and transmission rate

**On FPGA Board**:
- **LED[0]**: Toggles rapidly (on each sample received ~360 Hz)
- **LED[1]**: ON solid (UART receiving data)
- **LED[2]**: OFF (no errors)
- **LED[3]**: Blinks slowly (~1 Hz heartbeat)

---

## 🎛️ Command-Line Options

```bash
python ecg_streamer_live.py [options]

Required:
  --port COM3              # Serial port
  --file <path>            # ECG data file

Optional:
  --signal 0               # Signal number for .dat files (default: 0)
  --baud 115200            # Baud rate (default: 115200)
  --window 1000            # Display window samples (default: 1000)
  --loop                   # Loop playback indefinitely
```

### Examples

**CSV file, no loop**:
```bash
python ecg_streamer_live.py --port COM3 --file data/test_sine.csv
```

**MIT-BIH record, looping, larger window**:
```bash
python ecg_streamer_live.py --port COM3 --file "ECG signals/15814" --signal 0 --window 2000 --loop
```

**Different signal from same record**:
```bash
python ecg_streamer_live.py --port COM3 --file "ECG signals/15814" --signal 1
```

---

## 🔧 Troubleshooting

### Python Issues

**Error: "No module named pyserial"**
```bash
pip install pyserial
```

**Error: "No module named matplotlib"**
```bash
pip install matplotlib
```

**Error: "Could not open port COM3"**
- Check Device Manager for correct COM port
- Close any other programs using the port
- Try different COM port (COM4, COM5, etc.)

### FPGA Issues

**No LEDs blinking**:
1. Check FPGA is powered on
2. Check bitstream was programmed successfully
3. Press reset button on board
4. Verify UCF pin locations match your board

**LED[3] not blinking (no heartbeat)**:
- FPGA not programmed or in reset
- Check clock input (C9 pin)
- Check reset_n pin (B18)

**LED[0] not toggling during streaming**:
- Check UART RX pin (R7) - may need to verify with board schematic
- Try different baud rate: `--baud 9600`
- Check USB cable connection

**LED[2] blinking (errors)**:
- UART framing errors
- Wrong baud rate
- Verify UART RX pin location in UCF
- Check clock frequency settings

### Data File Issues

**Error: "File not found"**
- Use quotes for paths with spaces: `"ECG signals/15814"`
- Check file actually exists
- For .dat files, omit the extension

**Error: "Format not implemented"**
- The .dat reader supports formats 310, 212, and 16
- Check the .hea file to see the format number
- May need to convert to CSV first

---

## 📊 LED Indicator Guide

| LED | Name | Behavior | Meaning |
|-----|------|----------|---------|
| LED[0] | Data | Toggles rapidly | New sample received (~360 Hz) |
| LED[1] | Active | Solid ON | UART actively receiving |
| LED[2] | Error | Fast blink (5 Hz) | UART error detected |
| LED[3] | Heartbeat | Slow blink (1 Hz) | System alive |

**Normal operation**: LED[0] blinking fast, LED[1] ON, LED[2] OFF, LED[3] slow blink

---

## 🎯 Demo Checklist

- [ ] Python dependencies installed
- [ ] ISE project created with correct files
- [ ] FPGA programmed successfully
- [ ] LED[3] heartbeat blinking (FPGA alive)
- [ ] Identified correct COM port
- [ ] Python script runs without errors
- [ ] Matplotlib window opens
- [ ] LED[0] toggles when streaming
- [ ] LED[1] turns ON during streaming
- [ ] Live plot shows scrolling ECG waveform

---

## 📈 Expected Performance

- **Sample Rate**: ~360 Hz (MIT-BIH standard)
- **Baud Rate**: 115200 bps
- **Data per sample**: 2 bytes
- **Bandwidth used**: ~7200 bps (16× margin)
- **Display update**: 10 FPS (smooth scrolling)
- **Latency**: < 100ms PC to FPGA

---

## 🔄 Next Steps (After Demo Works)

1. **Test with different ECG types**:
   - Normal sinus rhythm
   - PVC (premature ventricular contractions)
   - Atrial fibrillation

2. **Add VGA display** (use full ecg_system_top.vhd):
   - Shows waveform on monitor connected to FPGA
   - More impressive demo

3. **Integrate CNN classifier**:
   - Connect to Ayoub's CNN module
   - Show classification results on LEDs/display

4. **Optimize performance**:
   - Adjust buffer sizes
   - Fine-tune display update rate
   - Add more status information

---

## 📝 Files Created for This Demo

```
python/
├── ecg_dat_reader.py          # MIT-BIH .dat file reader (NEW)
├── ecg_streamer_live.py       # Live streaming with plot (NEW)
└── requirements.txt           # Updated with matplotlib

src/
├── uart_receiver.vhd          # UART RX (EXISTING)
├── led_indicator.vhd          # LED blinker (NEW)
├── simple_demo_top.vhd        # Simple top-level (NEW)
└── simple_demo.ucf            # Pin constraints (NEW)

DEMO_README.md                 # This file (NEW)
```

---

## 🎓 Understanding the System

### Data Flow

```
MIT-BIH File (.dat)
    ↓
Python Reader (ecg_dat_reader.py)
    ↓
Normalize to 12-bit signed
    ↓
Split into 2 bytes per sample
    ↓
UART @ 115200 baud
    ↓
FPGA UART Receiver (uart_receiver.vhd)
    ↓
Assemble 12-bit samples
    ↓
├─→ LED Indicator (visual feedback)
└─→ Ready for VGA display / CNN classifier
```

### Live Plot

The Python script uses **threading** to separate:
- **Stream thread**: Sends data via UART at precise timing
- **Main thread**: Updates matplotlib plot every 100ms

This ensures smooth streaming without blocking the display.

---

## 💡 Tips

1. **Start simple**: Test with CSV file first before .dat files
2. **Verify COM port**: Check Device Manager on Windows
3. **Check LEDs first**: Heartbeat should blink even without streaming
4. **Use loop mode**: Great for continuous demo `--loop`
5. **Window size**: Larger = more data shown but slower updates
6. **Close plot to stop**: Closing matplotlib window stops streaming

---

## ✅ Success Criteria

**You know it's working when**:
1. ✓ Matplotlib window shows scrolling ECG waveform
2. ✓ Status updates show samples sent and rate
3. ✓ LED[0] on FPGA board blinks rapidly
4. ✓ LED[1] stays ON during streaming
5. ✓ No errors in terminal output
6. ✓ LEDs stop activity when plot window closes

---

**Good luck with your demo! 🚀**

Questions? Check:
- `docs_uart/system_architecture.md` for system details
- `docs_uart/technical_reference.md` for UART specs
- `python/README.md` for Python usage

**Last Updated**: February 26, 2026
