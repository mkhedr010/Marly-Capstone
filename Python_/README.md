# ECG Streamer - Python Application

Stream ECG data from PC to Spartan-3E FPGA via UART.

---

## Installation

### 1. Install Python Dependencies

```bash
pip install -r requirements.txt
```

This installs:
- `pyserial` - Serial port communication
- `numpy` - Numerical operations
- `pandas` - CSV file reading

---

## Usage

### Basic Usage

```bash
python ecg_streamer.py --port COM3 --file data/normal_ecg.csv
```

### With Options

```bash
# Loop playback
python ecg_streamer.py --port COM3 --file data/normal_ecg.csv --loop

# Custom sample rate
python ecg_streamer.py --port COM3 --file data/pvc_ecg.csv --rate 500

# Linux/Mac
python ecg_streamer.py --port /dev/ttyUSB0 --file data/afib_ecg.csv
```

---

## Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--port` | `-p` | Serial port (COM3, /dev/ttyUSB0, etc.) | *Required* |
| `--file` | `-f` | ECG data file (CSV format) | *Required* |
| `--rate` | `-r` | Sample rate in Hz | 360 |
| `--baud` | `-b` | UART baud rate | 115200 |
| `--loop` | `-l` | Loop playback indefinitely | False |

---

## Finding Your COM Port

### Windows
1. Open Device Manager
2. Expand "Ports (COM & LPT)"
3. Look for "USB Serial Port (COMX)"
4. Use COMX in command (e.g., COM3)

### Linux/Mac
```bash
# List available ports
ls /dev/tty*

# Common names:
# /dev/ttyUSB0  (Linux)
# /dev/cu.usbserial-XXX  (Mac)
```

---

## ECG Data Format

### CSV File Requirements

The CSV file should contain ECG samples as numbers. Supported formats:

**Option 1: Single column (no header)**
```
0.123
0.456
0.789
...
```

**Option 2: With header**
```
ECG
0.123
0.456
0.789
...
```

**Option 3: MIT-BIH format**
```
time,ECG
0.000,0.123
0.003,0.456
0.006,0.789
...
```

The script automatically detects the format and extracts ECG values.

### Data Conversion

The script automatically:
1. Normalizes data to [-1, 1] range (z-score normalization)
2. Scales to 12-bit signed integers (-2048 to +2047)
3. Clips outliers to valid range
4. Converts to two's complement for UART transmission

---

## Waveform Types

### Included Sample Data

Three sample waveform types are provided in `data/`:

1. **normal_ecg.csv** - Normal sinus rhythm (360 samples)
2. **pvc_ecg.csv** - Premature Ventricular Contraction (360 samples)
3. **afib_ecg.csv** - Atrial Fibrillation (360 samples)

### Adding Your Own Data

1. Obtain ECG data (MIT-BIH database, Kaggle, etc.)
2. Save as CSV with one sample per line
3. Use with `--file your_data.csv`

**Recommended sample count**: 360 samples (1 second @ 360 Hz)

---

## Testing

### Test UART Connection

```bash
# Send counting pattern to verify FPGA receives data
python -c "
import serial
import time
ser = serial.Serial('COM3', 115200)
for i in range(100):
    ser.write(bytes([i & 0xFF, (i >> 8) & 0x0F]))
    time.sleep(0.01)
ser.close()
"
```

Watch LEDs on FPGA - LED[0] should blink when receiving data.

---

## Troubleshooting

### "Error opening serial port"

**Problem**: COM port not found or in use

**Solutions**:
- Verify FPGA is connected via USB
- Check correct COM port in Device Manager
- Close other programs using the port
- Try unplugging and replugging USB cable

### "Permission denied" (Linux/Mac)

**Problem**: User doesn't have serial port permissions

**Solution**:
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Log out and log back in, or:
sudo chmod 666 /dev/ttyUSB0
```

### "No ECG visible on VGA"

**Problem**: Data not reaching FPGA or FPGA not programmed

**Checklist**:
- [ ] FPGA is programmed with bitstream
- [ ] VGA monitor is connected
- [ ] USB cable is connected
- [ ] Python script is running
- [ ] LED[0] is blinking (UART active)
- [ ] Check UART RX pin in UCF file

### "Waveform scrolls too fast/slow"

**Problem**: Sample rate mismatch

**Solution**:
```bash
# Adjust rate with --rate option
python ecg_streamer.py --port COM3 --file data/normal_ecg.csv --rate 300
```

---

## Example Session

```
$ python ecg_streamer.py --port COM3 --file data/normal_ecg.csv --loop

✓ Connected to COM3 at 115200 baud
✓ Loaded 360 samples from data/normal_ecg.csv
✓ Converted to 12-bit: min=-1856, max=2012

▶ Streaming 360 samples at 360 Hz
  Sample period: 2.778 ms
  Loop mode: True
  Press Ctrl+C to stop

  Sent: 360 samples, Elapsed: 1.0s, Rate: 359.8 Hz
  Sent: 720 samples, Elapsed: 2.0s, Rate: 360.1 Hz
  ↻ Looping playback...
  Sent: 1080 samples, Elapsed: 3.0s, Rate: 360.0 Hz
^C

✓ Stopped streaming
  Total samples sent: 1234
  Total time: 3.4s
  Average rate: 360.2 Hz
✓ Serial port closed
```

---

## Advanced Usage

### Create Custom Test Waveforms

```python
import numpy as np
import pandas as pd

# Generate sine wave
t = np.linspace(0, 1, 360)
sine_wave = 1000 * np.sin(2 * np.pi * 5 * t)  # 5 Hz sine
pd.DataFrame({'ECG': sine_wave}).to_csv('data/test_sine.csv', index=False)

# Generate square wave
square_wave = 1000 * np.sign(np.sin(2 * np.pi * 2 * t))
pd.DataFrame({'ECG': square_wave}).to_csv('data/test_square.csv', index=False)
```

Then stream:
```bash
python ecg_streamer.py --port COM3 --file data/test_sine.csv
```

---

## Data Format Details

### 12-bit Signed Integer Encoding

**Range**: -2048 to +2047  
**Representation**: Two's complement

**UART Transmission** (2 bytes per sample):
```
Byte 1: bits [7:0]   (lower 8 bits)
Byte 2: 0000 + bits [11:8]  (upper 4 bits with padding)
```

**Example**:
- Sample value: 1443 (0x5A3)
- Byte 1: 0xA3 (163 decimal)
- Byte 2: 0x05 (5 decimal)

**FPGA receives and assembles**: 0x5A3 = 1443 ✓

---

## Performance

### Timing Accuracy

Python `time.sleep()` has ~1-10 ms resolution on most systems.

**For 360 Hz** (2.778 ms period):
- Expected accuracy: ±0.5-1 ms
- Actual measured: ~359-361 Hz
- Good enough for ECG display!

**For higher accuracy**, use dedicated timing libraries or hardware timer.

---

**Version**: 1.0  
**Created**: January 21, 2026  
**License**: MIT (for coursework)  
**Author**: Marly
