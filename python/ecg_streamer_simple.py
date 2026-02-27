#!/usr/bin/env python3
"""
ECG Simple Streamer - Stream ECG data to FPGA with real-time visualization
Simplified version without threading for reliable demo

Usage:
    python ecg_streamer_simple.py --port COM4 --file data/normal_ecg.csv --loop

Author: Marly
Date: February 27, 2026
Version: 1.0 (Simplified)
"""

import serial
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from collections import deque
import time
import argparse
import sys
from pathlib import Path

# Import our MIT-BIH reader
try:
    from ecg_dat_reader import MITBIHReader
except ImportError:
    MITBIHReader = None


class ECGSimpleStreamer:
    """Simple ECG streamer with live plot - no threading"""
    
    def __init__(self, port, baud=115200, window_size=1000):
        """Initialize streamer"""
        # Serial connection
        try:
            self.ser = serial.Serial(port, baud, timeout=1)
            print(f"✓ Connected to {port} at {baud} baud")
        except serial.SerialException as e:
            print(f"✗ Error opening serial port: {e}")
            print(f"\nTip: Check Device Manager for the correct COM port number")
            sys.exit(1)
        
        # Display settings
        self.window_size = window_size
        self.sample_rate = 360
        
        # Set up matplotlib in interactive mode
        plt.ion()
        self.fig, self.ax = plt.subplots(figsize=(14, 7))
        self.line, = self.ax.plot([], [], 'g-', linewidth=1.5, label='ECG Signal')
        
        self.ax.set_xlim(0, window_size)
        self.ax.set_ylim(-1.2, 1.2)
        self.ax.set_xlabel('Sample Number', fontsize=12)
        self.ax.set_ylabel('Amplitude (normalized)', fontsize=12)
        self.ax.set_title('ECG Live Streaming to FPGA', fontsize=14, fontweight='bold')
        self.ax.grid(True, alpha=0.3, linestyle='--')
        self.ax.legend(loc='upper right')
        
        # Status text
        self.status_text = self.ax.text(
            0.02, 0.95, '', transform=self.ax.transAxes,
            verticalalignment='top', fontsize=11,
            bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.7),
            family='monospace'
        )
        
        plt.tight_layout()
        plt.show(block=False)
        plt.pause(0.1)
        
        print("✓ Matplotlib window initialized")
    
    def load_ecg_csv(self, filename, max_samples=None):
        """Load CSV file"""
        df = pd.read_csv(filename)
        
        # Look for ECG column
        ecg_col = None
        for col in ['ECG', 'ecg', 'signal', 'value', '0']:
            if col in df.columns:
                ecg_col = col
                break
        
        if ecg_col is None:
            ecg_data = df.iloc[:, 0].values
        else:
            ecg_data = df[ecg_col].values
        
        # Limit samples if requested
        if max_samples and len(ecg_data) > max_samples:
            ecg_data = ecg_data[:max_samples]
            print(f"✓ Loaded CSV: {len(ecg_data)} samples (limited from larger file)")
        else:
            print(f"✓ Loaded CSV: {len(ecg_data)} samples")
        
        return ecg_data
    
    def load_ecg_dat(self, record_path, signal_num=0, max_samples=None):
        """Load MIT-BIH .dat file"""
        if MITBIHReader is None:
            print("✗ MITBIHReader not available")
            sys.exit(1)
        
        reader = MITBIHReader(record_path)
        signal = reader.read_signal(signal_num)
        info = reader.get_info()
        
        self.sample_rate = info['sample_rate']
        
        # Limit samples if requested
        if max_samples and len(signal) > max_samples:
            signal = signal[:max_samples]
            print(f"✓ Loaded MIT-BIH: {len(signal)} samples @ {self.sample_rate} Hz (limited)")
        else:
            print(f"✓ Loaded MIT-BIH: {len(signal)} samples @ {self.sample_rate} Hz")
        
        return signal
    
    def convert_to_12bit(self, ecg_data):
        """Convert to 12-bit signed integers"""
        ecg_normalized = (ecg_data - np.mean(ecg_data)) / np.std(ecg_data)
        ecg_normalized = np.clip(ecg_normalized, -1.0, 1.0)
        
        ecg_12bit = (ecg_normalized * 2047).astype(int)
        ecg_12bit = np.clip(ecg_12bit, -2048, 2047)
        
        print(f"✓ Converted to 12-bit: range {ecg_12bit.min()} to {ecg_12bit.max()}")
        return ecg_12bit
    
    def send_sample(self, sample):
        """Send one 12-bit sample as 2 bytes"""
        if sample < 0:
            sample_unsigned = (1 << 12) + sample
        else:
            sample_unsigned = sample
        
        sample_unsigned = sample_unsigned & 0xFFF
        
        byte1 = sample_unsigned & 0xFF
        byte2 = (sample_unsigned >> 8) & 0x0F
        
        self.ser.write(bytes([byte1, byte2]))
    
    def stream_and_plot(self, ecg_data, loop=False):
        """Stream data and update plot in simple loop"""
        sample_period = 1.0 / self.sample_rate
        sample_count = 0
        start_time = time.perf_counter()
        
        # Data buffers for display
        plot_buffer = deque(maxlen=self.window_size)
        x_buffer = deque(maxlen=self.window_size)
        
        print(f"\n▶ Starting streaming at {self.sample_rate} Hz")
        print(f"  Total samples: {len(ecg_data)}")
        print(f"  Loop mode: {'ON' if loop else 'OFF'}")
        print(f"  Press Ctrl+C to stop\n")
        
        try:
            iteration = 0
            while True:
                print(f"DEBUG: Entering loop iteration {iteration}")
                for i, sample in enumerate(ecg_data):
                    if i == 0:
                        print(f"DEBUG: Starting to send sample {i}")
                    
                    # Send to FPGA
                    self.send_sample(sample)
                    
                    if i == 0:
                        print(f"DEBUG: First sample sent successfully")
                    
                    sample_count += 1
                    
                    # Add to plot buffer
                    plot_buffer.append(sample / 2047.0)  # Normalize
                    x_buffer.append(sample_count)
                    
                    # Update plot every 10 samples (36 Hz update rate)
                    if sample_count % 10 == 0:
                        # Update line data
                        self.line.set_data(list(x_buffer), list(plot_buffer))
                        
                        # Update x-axis to follow data
                        if len(x_buffer) > 0:
                            x_max = x_buffer[-1]
                            x_min = max(0, x_max - self.window_size)
                            self.ax.set_xlim(x_min, x_max)
                        
                        # Update status
                        elapsed = time.perf_counter() - start_time
                        rate = sample_count / elapsed if elapsed > 0 else 0
                        self.status_text.set_text(
                            f'Samples: {sample_count:6d} | '
                            f'Time: {elapsed:5.1f}s | '
                            f'Rate: {rate:6.1f} Hz'
                        )
                        
                        # Redraw
                        self.fig.canvas.draw()
                        self.fig.canvas.flush_events()
                    
                    # Print progress every second
                    if sample_count % self.sample_rate == 0:
                        elapsed = time.perf_counter() - start_time
                        rate = sample_count / elapsed
                        print(f"  Sent: {sample_count:6d} samples | "
                              f"Time: {elapsed:5.1f}s | Rate: {rate:6.1f} Hz")
                    
                    # Timing
                    time.sleep(sample_period)
                
                # Loop or finish
                if not loop:
                    print("\n✓ Finished streaming all samples")
                    print("  Keeping plot open - close window to exit")
                    # Keep plot alive
                    while plt.fignum_exists(self.fig.number):
                        plt.pause(0.5)
                    break
                    
                iteration += 1
                print(f"\n  ↻ Loop iteration {iteration} - restarting...")
                
        except KeyboardInterrupt:
            print("\n\n✓ Stopped by user (Ctrl+C)")
        except Exception as e:
            print(f"\n✗ Error during streaming: {e}")
            import traceback
            traceback.print_exc()
        
        finally:
            elapsed = time.perf_counter() - start_time
            print(f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(f"  Final Statistics:")
            print(f"  Total samples sent: {sample_count}")
            print(f"  Total time: {elapsed:.1f}s")
            if elapsed > 0:
                print(f"  Average rate: {sample_count/elapsed:.1f} Hz")
            print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    
    def close(self):
        """Close serial port"""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("✓ Serial port closed")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Stream ECG data to FPGA with live visualization (Simplified)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ecg_streamer_simple.py --port COM4 --file data/normal_ecg.csv
  python ecg_streamer_simple.py --port COM4 --file "../ECG signals/15814" --signal 0 --loop
        """
    )
    
    parser.add_argument('--port', '-p', required=True,
                        help='Serial port (e.g., COM4)')
    parser.add_argument('--file', '-f', required=True,
                        help='ECG file (.dat or .csv)')
    parser.add_argument('--signal', '-s', type=int, default=0,
                        help='Signal number for .dat files (default: 0)')
    parser.add_argument('--baud', '-b', type=int, default=115200,
                        help='Baud rate (default: 115200)')
    parser.add_argument('--window', '-w', type=int, default=1000,
                        help='Display window samples (default: 1000)')
    parser.add_argument('--max-samples', '-m', type=int, default=None,
                        help='Limit number of samples to stream (useful for large files)')
    parser.add_argument('--loop', '-l', action='store_true',
                        help='Loop playback')
    
    args = parser.parse_args()
    
    # Create streamer
    streamer = ECGSimpleStreamer(args.port, args.baud, args.window)
    
    try:
        # Load data
        file_path = Path(args.file)
        
        if file_path.suffix in ['.dat', '.hea'] or not file_path.suffix:
            record_path = str(file_path.with_suffix(''))
            ecg_data_raw = streamer.load_ecg_dat(record_path, args.signal, args.max_samples)
        else:
            ecg_data_raw = streamer.load_ecg_csv(args.file, args.max_samples)
        
        # Convert to 12-bit
        ecg_data_12bit = streamer.convert_to_12bit(ecg_data_raw)
        
        print("\n" + "="*50)
        print("  ECG LIVE STREAMING DEMO")
        print("="*50)
        print(f"  Port: {args.port} @ {args.baud} baud")
        print(f"  File: {args.file}")
        print(f"  Samples: {len(ecg_data_12bit)}")
        print(f"  Rate: {streamer.sample_rate} Hz")
        print("="*50 + "\n")
        
        # Stream and plot
        streamer.stream_and_plot(ecg_data_12bit, args.loop)
        
    except KeyboardInterrupt:
        print("\n✓ Interrupted by user")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        streamer.close()


if __name__ == '__main__':
    main()
