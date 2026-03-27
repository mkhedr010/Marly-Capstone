#!/usr/bin/env python3
"""
Extract first 16 samples from ECG .dat files and generate VHDL pattern constants.
Usage: python extract_patterns.py record_A record_B record_C
Example: python extract_patterns.py "ECG signals/Normal/100" "ECG signals/PVC/208" "ECG signals/LBBB/214"
"""

import sys
import numpy as np
from pathlib import Path

# Import existing ECG reader
sys.path.insert(0, str(Path(__file__).parent / "python"))
from ecg_dat_reader import MITBIHReader

def read_ecg_record(record_path, num_samples=16):
    """Read ECG record and return first N samples in 12-bit UART format"""
    try:
        # Read using existing MITBIHReader
        reader = MITBIHReader(record_path)
        signal_mv = reader.read_signal(0)  # Read first signal

        # Convert to 12-bit format (same as ecg_stream_visualize.py)
        # Min-max normalization to [-1, 1] then scale to 12-bit signed
        data_min = float(signal_mv.min())
        data_max = float(signal_mv.max())

        ecg_norm = 2.0 * (signal_mv - data_min) / (data_max - data_min) - 1.0
        ecg_12bit_signed = np.clip((ecg_norm * 2047).astype(int), -2048, 2047)

        # Convert signed (-2048 to +2047) to unsigned (0 to 4095) for FPGA
        ecg_12bit_unsigned = np.where(ecg_12bit_signed < 0,
                                       (1 << 12) + ecg_12bit_signed,
                                       ecg_12bit_signed) & 0xFFF

        return ecg_12bit_unsigned[:num_samples]

    except Exception as e:
        print(f"Error reading {record_path}: {e}")
        sys.exit(1)

def sample_to_12bit(sample):
    """Ensure sample is valid 12-bit unsigned integer (0-4095)"""
    value = int(sample) & 0xFFF  # Clamp to 12-bit
    return value

def generate_vhdl_pattern(samples, pattern_name):
    """Generate VHDL constant declaration for pattern"""
    vhdl = f"constant {pattern_name} : pattern_array := (\n"

    for i, sample in enumerate(samples):
        value = sample_to_12bit(sample)

        # Format 8 values per line for readability
        if i % 8 == 0:
            vhdl += "    "

        vhdl += f"to_signed({value}, 12)"

        if i < len(samples) - 1:
            vhdl += ", "

        if (i + 1) % 8 == 0:
            vhdl += "\n"

    if len(samples) % 8 != 0:
        vhdl += "\n"

    vhdl += ");\n"
    return vhdl

def main():
    if len(sys.argv) != 4:
        print("Usage: python extract_patterns.py record_A record_B record_C")
        print('Example: python extract_patterns.py "ECG signals/Normal/100" "ECG signals/PVC/208" "ECG signals/LBBB/214"')
        sys.exit(1)

    record_A, record_B, record_C = sys.argv[1:4]

    # Read samples
    print(f"\nReading {record_A}...")
    samples_A = read_ecg_record(record_A, num_samples=16)
    print(f"First 16 samples (unsigned 12-bit): {samples_A}\n")

    print(f"Reading {record_B}...")
    samples_B = read_ecg_record(record_B, num_samples=16)
    print(f"First 16 samples (unsigned 12-bit): {samples_B}\n")

    print(f"Reading {record_C}...")
    samples_C = read_ecg_record(record_C, num_samples=16)
    print(f"First 16 samples (unsigned 12-bit): {samples_C}\n")

    # Generate VHDL
    vhdl_output = "-- Generated ECG pattern constants\n"
    vhdl_output += "-- Pattern A: " + record_A + "\n"
    vhdl_output += "-- Pattern B: " + record_B + "\n"
    vhdl_output += "-- Pattern C: " + record_C + "\n\n"

    vhdl_output += generate_vhdl_pattern(samples_A, "PATTERN_A")
    vhdl_output += "\n"
    vhdl_output += generate_vhdl_pattern(samples_B, "PATTERN_B")
    vhdl_output += "\n"
    vhdl_output += generate_vhdl_pattern(samples_C, "PATTERN_C")

    # Print to console
    print("\n" + "="*60)
    print("GENERATED VHDL CONSTANTS:")
    print("="*60)
    print(vhdl_output)

    # Also save to file
    with open("patterns.vhd", "w") as f:
        f.write(vhdl_output)

    print("="*60)
    print("[OK] Saved to patterns.vhd")
    print("[OK] Copy these constants into src/cnn/zolotyhnet_top.vhd")
    print("="*60)

if __name__ == "__main__":
    main()
