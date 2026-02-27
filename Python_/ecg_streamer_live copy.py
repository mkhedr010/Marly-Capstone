#!/usr/bin/env python3
"""
ECG Live Streamer - Stream ECG data to FPGA with real-time visualization

Shows live scrolling ECG waveform on PC as data streams to FPGA.
Supports both MIT-BIH .dat files and CSV files.

Usage:
    python ecg_streamer_live.py --port COM3 --file "ECG signals/15814" --signal 0
    python ecg_streamer_live.py --port COM3 --file data/normal_ecg.csv

Author: Marly
Date: February 26, 2026
Version: 1.0
"""

import serial
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from collections import deque
import time
import argparse
import sys
import threading
from pathlib import Path

# Import our MIT-BIH reader
from ecg_dat_reader import MITBIHReader


class ECGLiveStreamer:
    """Stream ECG data to FPGA with live visualization"""
    
    def __init__(self, port, baud=115200, window_size=1000):
        """
        Initialize live streamer
        
        Args:
            port: COM port
            baud: Baud rate
            window_size: Number of samples to show in scrolling window
        """
        # Serial connection
        try:
            self.ser = serial.Serial(port, baud, timeout=1)
            print(f"✓ Connected to {port} at {baud} baud")
        except serial.SerialException as e:
            print(f"✗ Error opening serial port: {e}")
            sys.exit(1)
        
        # Data buffers
        self.window_size = window_size
        self.plot_data = deque(maxlen=window_size)
        self.time_data = deque(maxlen=window_size)
        
        # Streaming state
        self.streaming = False
        self.sample_count = 0
        self.start_time = None
        
        # Thread for UART transmission
        self.stream_thread = None
        self.ecg_data = None
        self.sample_rate = 360
        
    def load_ecg_dat(self, record_path, signal_num=0):
        """Load MIT-BIH .dat file"""
        reader = MITBIHReader(record_path)
        signal = reader.read_signal(signal_num)
        info = reader.get_info()
        
        self.sample_rate = info['sample_rate']
        print(f"✓ Loaded MIT-BIH record: {len(signal)} samples @ {self.sample_rate} Hz")
        
        return signal
    
    def load_ecg_csv(self, filename):
        """Load CSV file"""
        try:
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
            
            print(f"✓ Loaded CSV: {len(ecg_data)} samples")
            return ecg_data
            
        except Exception as e:
            print(f"✗ Error loading CSV: {e}")
            sys.exit(1)
    
    def convert_to_12bit(self, ecg_data):
        """Convert to 12-bit signed integers"""
        # Normalize to [-1, 1]
        ecg_normalized = (ecg_data - np.mean(ecg_data)) / np.std(ecg_data)
        ecg_normalized = np.clip(ecg_normalized, -1.0, 1.0)
        
        # Scale to 12-bit signed range
        ecg_12bit = (ecg_normalized * 2047).astype(int)
        ecg_12bit = np.clip(ecg_12bit, -2048, 2047)
        
        print(f"✓ Converted to 12-bit: range {ecg_12bit.min()} to {ecg_12bit.max()}")
        return ecg_12bit
    
    def send_sample(self, sample):
        """Send one 12-bit sample as 2 bytes"""
        # Convert to unsigned 12-bit
        if sample < 0:
            sample_unsigned = (1 << 12) + sample
        else:
            sample_unsigned = sample
        
        sample_unsigned = sample_unsigned & 0xFFF
        
        # Split into 2 bytes
        byte1 = sample_unsigned & 0xFF
        byte2 = (sample_unsigned >> 8) & 0x0F
        
        # Send via UART
        self.ser.write(bytes([byte1, byte2]))
    
    def stream_worker(self, loop=False):
        """Worker thread for streaming data"""
        sample_period = 1.0 / self.sample_rate
        self.sample_count = 0
        self.start_time = time.perf_counter()
        
        print(f"\n▶ Streaming started")
        print(f"  Rate: {self.sample_rate} Hz")
        print(f"  Sample period: {sample_period*1000:.3f} ms")
        print(f"  Loop mode: {loop}\n")
        
        try:
            while self.streaming:
                for i, sample in enumerate(self.ecg_data):
                    if not self.streaming:
                        break
                    
                    # Send sample
                    self.send_sample(sample)
                    
                    # Update plot data
                    self.plot_data.append(sample / 2047.0)  # Normalize for display
                    current_time = time.perf_counter() - self.start_time
                    self.time_data.append(current_time)
                    
                    self.sample_count += 1
                    
                    # Print progress
                    if self.sample_count % self.sample_rate == 0:
                        elapsed = time.perf_counter() - self.start_time
                        actual_rate = self.sample_count / elapsed
                        print(f"  Sent: {self.sample_count} samples | "
                              f"Time: {elapsed:.1f}s | Rate: {actual_rate:.1f} Hz")
                    
                    # Timing
                    time.sleep(sample_period)
                
                # Loop or stop
                if not loop:
                    break
                print(f"  ↻ Looping...")
                
        except Exception as e:
            print(f"\n✗ Streaming error: {e}")
        
        print(f"\n✓ Streaming stopped")
        print(f"  Total samples: {self.sample_count}")
        if self.start_time:
            elapsed = time.perf_counter() - self.start_time
            print(f"  Total time: {elapsed:.1f}s")
            if elapsed > 0:
                print(f"  Average rate: {self.sample_count/elapsed:.1f} Hz")
    
    def start_streaming(self, ecg_data, loop=False):
        """Start streaming in background thread"""
        self.ecg_data = ecg_data
        self.streaming = True
        self.plot_data.clear()
        self.time_data.clear()
        
        self.stream_thread = threading.Thread(
            target=self.stream_worker,
            args=(loop,),
            daemon=True
        )
        self.stream_thread.start()
    
    def stop_streaming(self):
        """Stop streaming"""
        self.streaming = False
        if self.stream_thread:
            self.stream_thread.join(timeout=2.0)
    
    def setup_plot(self):
        """Set up matplotlib live plot"""
        plt.ion()  # Enable interactive mode
        self.fig, self.ax = plt.subplots(figsize=(12, 6))
        self.line, = self.ax.plot([], [], 'g-', linewidth=1.5)
        
        self.ax.set_xlim(0, self.window_size / self.sample_rate)
        self.ax.set_ylim(-1.2, 1.2)
        self.ax.set_xlabel('Time (seconds)', fontsize=12)
        self.ax.set_ylabel('Amplitude (normalized)', fontsize=12)
        self.ax.set_title('ECG Live Streaming to FPGA', fontsize=14, fontweight='bold')
        self.ax.grid(True, alpha=0.3)
        
        # Add status text
        self.status_text = self.ax.text(
            0.02, 0.95, '', transform=self.ax.transAxes,
            verticalalignment='top', fontsize=10,
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5)
        )
        
        plt.tight_layout()
        plt.show(block=False)  # Non-blocking show
        plt.pause(0.1)  # Give time to render
        
    def run_live_stream(self, ecg_data, loop=False):
        """Run live streaming with visualization"""
        # Start streaming thread
        self.start_streaming(ecg_data, loop)
        
        # Wait a moment for thread to start
        time.sleep(0.2)
        
        # Set up plot
        self.setup_plot()
        
        # Manual update loop (simpler than FuncAnimation)
        print("📊 Plot window open - streaming data...\n")
        try:
            while self.streaming and plt.fignum_exists(self.fig.number):
                # Update plot
                if len(self.plot_data) > 0:
                    y_data = list(self.plot_data)
                    t_data = list(self.time_data)
                    
                    if len(t_data) > 0:
                        t_min = t_data[0]
                        t_relative = [t - t_min for t in t_data]
                        
                        self.line.set_data(t_relative, y_data)
                        
                        # Update x-axis to follow data
                        if len(t_relative) > 0:
                            self.ax.set_xlim(0, max(t_relative[-1], self.window_size / self.sample_rate))
                        
                        # Update status text
                        if self.sample_count > 0 and self.start_time:
                            elapsed = time.perf_counter() - self.start_time
                            rate = self.sample_count / elapsed if elapsed > 0 else 0
                            self.status_text.set_text(
                                f'Samples: {self.sample_count} | '
                                f'Time: {elapsed:.1f}s | '
                                f'Rate: {rate:.1f} Hz'
                            )
                
                # Redraw
                self.fig.canvas.draw()
                self.fig.canvas.flush_events()
                
                # Update every 100ms
                plt.pause(0.1)
                
        except KeyboardInterrupt:
            pass
        
        # Stop streaming when window closes
        self.stop_streaming()
    
    def close(self):
        """Clean up"""
        self.stop_streaming()
        self.ser.close()
        print("✓ Serial port closed")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='Stream ECG data to FPGA with live visualization',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Stream MIT-BIH .dat file
  python ecg_streamer_live.py --port COM3 --file "ECG signals/15814" --signal 0
  
  # Stream CSV file
  python ecg_streamer_live.py --port COM3 --file data/normal_ecg.csv
  
  # Loop playback
  python ecg_streamer_live.py --port COM3 --file "ECG signals/15814" --loop
        """
    )
    
    parser.add_argument('--port', '-p', required=True,
                        help='Serial port (e.g., COM3)')
    parser.add_argument('--file', '-f', required=True,
                        help='ECG file (.dat record or .csv)')
    parser.add_argument('--signal', '-s', type=int, default=0,
                        help='Signal number for .dat files (default: 0)')
    parser.add_argument('--baud', '-b', type=int, default=115200,
                        help='Baud rate (default: 115200)')
    parser.add_argument('--window', '-w', type=int, default=1000,
                        help='Display window size in samples (default: 1000)')
    parser.add_argument('--loop', '-l', action='store_true',
                        help='Loop playback')
    
    args = parser.parse_args()
    
    # Create streamer
    streamer = ECGLiveStreamer(args.port, args.baud, args.window)
    
    try:
        # Determine file type and load
        file_path = Path(args.file)
        
        if file_path.suffix in ['.dat', '.hea'] or not file_path.suffix:
            # MIT-BIH format (record without extension)
            record_path = str(file_path.with_suffix(''))
            ecg_data_raw = streamer.load_ecg_dat(record_path, args.signal)
        else:
            # CSV format
            ecg_data_raw = streamer.load_ecg_csv(args.file)
        
        # Convert to 12-bit
        ecg_data_12bit = streamer.convert_to_12bit(ecg_data_raw)
        
        # Run live stream with visualization
        print("\n📊 Starting live visualization...")
        print("   Close the plot window to stop streaming\n")
        
        streamer.run_live_stream(ecg_data_12bit, args.loop)
        
    except KeyboardInterrupt:
        print("\n\n✓ Interrupted by user")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        streamer.close()


if __name__ == '__main__':
    main()
