#!/usr/bin/env python3
"""
ECG Streamer - Stream ECG data from PC to FPGA via UART

Loads ECG datasets (CSV format) and streams 12-bit samples to FPGA
at configurable rate (default 360 Hz for MIT-BIH compatibility).

Usage:
    python ecg_streamer.py --port COM3 --file data/normal_ecg.csv --rate 360

Author: Marly
Date: January 21, 2026
Version: 1.0
"""

import serial
import numpy as np
import pandas as pd
import time
import argparse
import sys
from pathlib import Path

class ECGStreamer:
    """Stream ECG data to FPGA via UART"""
    
    def __init__(self, port, baud=115200):
        """
        Initialize UART connection
        
        Args:
            port: COM port (e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux)
            baud: Baud rate (default 115200)
        """
        try:
            self.ser = serial.Serial(port, baud, timeout=1)
            print(f"✓ Connected to {port} at {baud} baud")
        except serial.SerialException as e:
            print(f"✗ Error opening serial port: {e}")
            sys.exit(1)
    
    def load_ecg_csv(self, filename):
        """
        Load ECG data from CSV file
        
        Args:
            filename: Path to CSV file with ECG column
            
        Returns:
            numpy array of ECG samples
        """
        try:
            # Try to load with pandas
            df = pd.read_csv(filename)
            
            # Look for common ECG column names
            ecg_col = None
            for col in ['ECG', 'ecg', 'signal', 'value', '0']:
                if col in df.columns:
                    ecg_col = col
                    break
            
            if ecg_col is None:
                # Assume first column is ECG data
                ecg_data = df.iloc[:, 0].values
            else:
                ecg_data = df[ecg_col].values
            
            print(f"✓ Loaded {len(ecg_data)} samples from {filename}")
            return ecg_data
            
        except Exception as e:
            print(f"✗ Error loading CSV: {e}")
            sys.exit(1)
    
    def convert_to_12bit(self, ecg_data):
        """
        Convert ECG data to 12-bit signed integers
        
        Args:
            ecg_data: numpy array of ECG samples (any scale)
            
        Returns:
            numpy array of 12-bit signed integers (-2048 to +2047)
        """
        # Normalize to [-1, 1] range
        ecg_normalized = (ecg_data - np.mean(ecg_data)) / np.std(ecg_data)
        ecg_normalized = np.clip(ecg_normalized, -1.0, 1.0)
        
        # Scale to 12-bit signed range
        ecg_12bit = (ecg_normalized * 2047).astype(int)
        ecg_12bit = np.clip(ecg_12bit, -2048, 2047)
        
        print(f"✓ Converted to 12-bit: min={ecg_12bit.min()}, max={ecg_12bit.max()}")
        return ecg_12bit
    
    def send_sample(self, sample):
        """
        Send one 12-bit ECG sample as 2 bytes via UART
        
        Args:
            sample: 12-bit signed integer (-2048 to +2047)
        """
        # Convert to unsigned 12-bit (two's complement if negative)
        if sample < 0:
            sample_unsigned = (1 << 12) + sample
        else:
            sample_unsigned = sample
        
        # Ensure 12-bit range
        sample_unsigned = sample_unsigned & 0xFFF
        
        # Split into 2 bytes
        byte1 = sample_unsigned & 0xFF         # Lower 8 bits
        byte2 = (sample_unsigned >> 8) & 0x0F  # Upper 4 bits
        
        # Send via UART
        self.ser.write(bytes([byte1, byte2]))
    
    def stream_ecg(self, ecg_data, sample_rate=360, loop=False):
        """
        Stream ECG data to FPGA at specified rate
        
        Args:
            ecg_data: numpy array of 12-bit ECG samples
            sample_rate: Samples per second (default 360 Hz)
            loop: Loop playback indefinitely (default False)
        """
        sample_period = 1.0 / sample_rate
        sample_count = 0
        start_time = time.perf_counter()
        
        print(f"\n▶ Streaming {len(ecg_data)} samples at {sample_rate} Hz")
        print(f"  Sample period: {sample_period*1000:.3f} ms")
        print(f"  Loop mode: {loop}")
        print(f"  Press Ctrl+C to stop\n")
        
        try:
            while True:
                for i, sample in enumerate(ecg_data):
                    # Send sample
                    self.send_sample(sample)
                    sample_count += 1
                    
                    # Print progress every 360 samples (~1 second)
                    if sample_count % 360 == 0:
                        elapsed = time.perf_counter() - start_time
                        actual_rate = sample_count / elapsed
                        print(f"  Sent: {sample_count} samples, "
                              f"Elapsed: {elapsed:.1f}s, "
                              f"Rate: {actual_rate:.1f} Hz")
                    
                    # Wait for next sample time
                    time.sleep(sample_period)
                
                # Break if not looping
                if not loop:
                    break
                    
                print(f"  ↻ Looping playback...")
                
        except KeyboardInterrupt:
            print(f"\n\n✓ Stopped streaming")
            print(f"  Total samples sent: {sample_count}")
            elapsed = time.perf_counter() - start_time
            print(f"  Total time: {elapsed:.1f}s")
            print(f"  Average rate: {sample_count/elapsed:.1f} Hz")
    
    def close(self):
        """Close serial port"""
        self.ser.close()
        print("✓ Serial port closed")


def main():
    """Main function with command-line interface"""
    
    parser = argparse.ArgumentParser(
        description='Stream ECG data to FPGA via UART',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ecg_streamer.py --port COM3 --file data/normal_ecg.csv
  python ecg_streamer.py --port /dev/ttyUSB0 --file data/pvc_ecg.csv --loop
  python ecg_streamer.py --port COM3 --file data/afib_ecg.csv --rate 500
        """
    )
    
    parser.add_argument('--port', '-p', required=True,
                        help='Serial port (e.g., COM3, /dev/ttyUSB0)')
    parser.add_argument('--file', '-f', required=True,
                        help='ECG data file (CSV format)')
    parser.add_argument('--rate', '-r', type=int, default=360,
                        help='Sample rate in Hz (default: 360)')
    parser.add_argument('--baud', '-b', type=int, default=115200,
                        help='UART baud rate (default: 115200)')
    parser.add_argument('--loop', '-l', action='store_true',
                        help='Loop playback indefinitely')
    
    args = parser.parse_args()
    
    # Validate file exists
    if not Path(args.file).exists():
        print(f"✗ Error: File not found: {args.file}")
        sys.exit(1)
    
    # Create streamer
    streamer = ECGStreamer(args.port, args.baud)
    
    try:
        # Load ECG data
        ecg_data_raw = streamer.load_ecg_csv(args.file)
        
        # Convert to 12-bit
        ecg_data_12bit = streamer.convert_to_12bit(ecg_data_raw)
        
        # Stream to FPGA
        streamer.stream_ecg(ecg_data_12bit, args.rate, args.loop)
        
    finally:
        # Clean up
        streamer.close()


if __name__ == '__main__':
    main()
