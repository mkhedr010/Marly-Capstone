#!/usr/bin/env python3
"""
ECG Visualizer - Live scrolling ECG display (NO FPGA needed)
For demonstration and testing purposes

Usage:
    python ecg_visualizer.py --file data/normal_ecg.csv --loop
    python ecg_visualizer.py --file "../ECG signals/15814" --signal 0 --max-samples 5000

Author: Marly
Date: February 27, 2026
Version: 1.0
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from collections import deque
import time
import argparse
import sys
from pathlib import Path

# Import MIT-BIH reader
try:
    from ecg_dat_reader import MITBIHReader
except ImportError:
    MITBIHReader = None


class ECGVisualizer:
    """Display live scrolling ECG waveform"""
    
    def __init__(self, window_size=1000):
        """Initialize visualizer"""
        self.window_size = window_size
        self.sample_rate = 360
        
        # Data storage
        self.ecg_data = None
        self.current_index = 0
        self.sample_count = 0
        self.start_time = None
        self.loop_mode = False
        
        # Display buffers
        self.plot_buffer = deque(maxlen=window_size)
        self.x_buffer = deque(maxlen=window_size)
        
        # Set up plot
        plt.style.use('seaborn-v0_8-darkgrid')
        self.fig, self.ax = plt.subplots(figsize=(14, 7))
        self.line, = self.ax.plot([], [], 'g-', linewidth=2, label='ECG Signal')
        
        self.ax.set_xlim(0, window_size)
        self.ax.set_ylim(-1.2, 1.2)
        self.ax.set_xlabel('Sample Number', fontsize=13, fontweight='bold')
        self.ax.set_ylabel('Amplitude (normalized)', fontsize=13, fontweight='bold')
        self.ax.set_title('ECG Live Streaming Visualization', fontsize=16, fontweight='bold')
        self.ax.grid(True, alpha=0.4, linestyle='--', linewidth=0.8)
        self.ax.legend(loc='upper right', fontsize=11)
        
        # Status display
        self.status_text = self.ax.text(
            0.02, 0.98, '', transform=self.ax.transAxes,
            verticalalignment='top', fontsize=12,
            bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.9, edgecolor='black'),
            family='monospace', fontweight='bold'
        )
        
        plt.tight_layout()
    
    def load_csv(self, filename, max_samples=None):
        """Load ECG from CSV"""
        df = pd.read_csv(filename)
        
        ecg_col = None
        for col in ['ECG', 'ecg', 'signal', 'value', '0']:
            if col in df.columns:
                ecg_col = col
                break
        
        if ecg_col is None:
            data = df.iloc[:, 0].values
        else:
            data = df[ecg_col].values
        
        if max_samples and len(data) > max_samples:
            data = data[:max_samples]
        
        print(f"✓ Loaded CSV: {len(data)} samples")
        return data
    
    def load_dat(self, record_path, signal_num=0, max_samples=None):
        """Load ECG from MIT-BIH .dat file"""
        if MITBIHReader is None:
            print("✗ MIT-BIH reader not available")
            sys.exit(1)
        
        reader = MITBIHReader(record_path)
        signal = reader.read_signal(signal_num)
        info = reader.get_info()
        
        self.sample_rate = info['sample_rate']
        
        if max_samples and len(signal) > max_samples:
            signal = signal[:max_samples]
        
        print(f"✓ Loaded MIT-BIH: {len(signal)} samples @ {self.sample_rate} Hz")
        return signal
    
    def normalize(self, data):
        """Normalize to [-1, 1] range"""
        normalized = (data - np.mean(data)) / np.std(data)
        normalized = np.clip(normalized, -1.0, 1.0)
        print(f"✓ Normalized: range {normalized.min():.2f} to {normalized.max():.2f}")
        return normalized
    
    def update_frame(self, frame):
        """Animation update callback"""
        if self.ecg_data is None or len(self.ecg_data) == 0:
            return self.line, self.status_text
        
        # Add next sample
        if self.current_index < len(self.ecg_data):
            sample = self.ecg_data[self.current_index]
            self.plot_buffer.append(sample)
            self.x_buffer.append(self.sample_count)
            
            self.current_index += 1
            self.sample_count += 1
        else:
            # End of data
            if self.loop_mode:
                # Loop back to start
                self.current_index = 0
                print(f"\n  ↻ Looping playback...")
            else:
                # Stop animation
                print(f"\n✓ Finished playback ({self.sample_count} samples)")
                return self.line, self.status_text
        
        # Update line
        if len(self.plot_buffer) > 0:
            self.line.set_data(list(self.x_buffer), list(self.plot_buffer))
            
            # Update x-axis to follow
            if len(self.x_buffer) > 0:
                x_max = self.x_buffer[-1]
                x_min = max(0, x_max - self.window_size)
                self.ax.set_xlim(x_min, x_max)
            
            # Update status
            if self.start_time:
                elapsed = time.time() - self.start_time
                rate = self.sample_count / elapsed if elapsed > 0 else 0
                self.status_text.set_text(
                    f'Samples: {self.sample_count:6d} | '
                    f'Time: {elapsed:6.1f}s | '
                    f'Rate: {rate:6.1f} Hz'
                )
        
        # Print progress
        if self.sample_count % self.sample_rate == 0:
            elapsed = time.time() - self.start_time
            rate = self.sample_count / elapsed
            print(f"  Samples: {self.sample_count:6d} | Time: {elapsed:5.1f}s | Rate: {rate:6.1f} Hz")
        
        return self.line, self.status_text
    
    def visualize(self, ecg_data, loop=False):
        """Start visualization"""
        self.ecg_data = ecg_data
        self.current_index = 0
        self.sample_count = 0
        self.loop_mode = loop
        self.start_time = time.time()
        
        print(f"\n{'='*60}")
        print(f"  ECG LIVE VISUALIZATION (PC Display Only)")
        print(f"{'='*60}")
        print(f"  Samples: {len(ecg_data)}")
        print(f"  Sample Rate: {self.sample_rate} Hz")
        print(f"  Window Size: {self.window_size} samples")
        print(f"  Loop Mode: {'ON' if loop else 'OFF'}")
        print(f"{'='*60}\n")
        print(f"▶ Starting visualization...")
        print(f"  Close plot window to stop\n")
        
        # Create animation
        # Update interval = 1000ms / sample_rate (milliseconds per sample)
        interval_ms = 1000.0 / self.sample_rate
        
        ani = FuncAnimation(
            self.fig,
            self.update_frame,
            interval=interval_ms,
            blit=True,
            cache_frame_data=False,
            repeat=False
        )
        
        # Show plot (blocking - waits for window close)
        plt.show()
        
        # Final stats
        if self.start_time:
            elapsed = time.time() - self.start_time
            print(f"\n{'='*60}")
            print(f"  Final Statistics:")
            print(f"  Total Samples Displayed: {self.sample_count}")
            print(f"  Total Time: {elapsed:.1f}s")
            if elapsed > 0:
                print(f"  Average Rate: {self.sample_count/elapsed:.1f} Hz")
            print(f"{'='*60}\n")


def main():
    """Main function"""
    parser = argparse.ArgumentParser(
        description='ECG Live Visualization (PC Display Only)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ecg_visualizer.py --file data/normal_ecg.csv
  python ecg_visualizer.py --file data/normal_ecg.csv --loop
  python ecg_visualizer.py --file "../ECG signals/15814" --signal 0 --max-samples 5000
  python ecg_visualizer.py --file "../ECG signals/15814" --signal 0 --max-samples 10000 --loop --window 2000
        """
    )
    
    parser.add_argument('--file', '-f', required=True,
                        help='ECG file (.dat or .csv)')
    parser.add_argument('--signal', '-s', type=int, default=0,
                        help='Signal number for .dat files (default: 0)')
    parser.add_argument('--window', '-w', type=int, default=1000,
                        help='Display window size in samples (default: 1000)')
    parser.add_argument('--max-samples', '-m', type=int, default=None,
                        help='Limit samples (default: all)')
    parser.add_argument('--loop', '-l', action='store_true',
                        help='Loop playback')
    
    args = parser.parse_args()
    
    try:
        # Create visualizer
        viz = ECGVisualizer(window_size=args.window)
        
        # Load data
        file_path = Path(args.file)
        
        if file_path.suffix in ['.dat', '.hea'] or not file_path.suffix:
            record_path = str(file_path.with_suffix(''))
            ecg_data_raw = viz.load_dat(record_path, args.signal, args.max_samples)
        else:
            ecg_data_raw = viz.load_csv(args.file, args.max_samples)
        
        # Normalize
        ecg_normalized = viz.normalize(ecg_data_raw)
        
        # Visualize
        viz.visualize(ecg_normalized, args.loop)
        
    except KeyboardInterrupt:
        print("\n✓ Stopped by user")
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
