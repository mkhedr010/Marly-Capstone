#!/usr/bin/env python3
"""
ECG Stream & Visualize - Combined streamer + live display

Loads ECG data, streams it to FPGA via UART, AND displays it live on PC
simultaneously. The streamer runs in a background thread; the visualizer
runs on the main thread (required by matplotlib).

Usage:
    python ecg_stream_and_visualize.py --port COM3 --file data/normal_ecg.csv
    python ecg_stream_and_visualize.py --port COM3 --file data/normal_ecg.csv --loop
    python ecg_stream_and_visualize.py --port COM3 --file "../ECG signals/15814" --signal 0

Author: Marly
Date: March 2026
Version: 1.3
"""

import serial
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from collections import deque
import threading
import queue
import time
import argparse
import sys
from pathlib import Path

# Optional MIT-BIH reader
try:
    from ecg_dat_reader import MITBIHReader
except ImportError:
    MITBIHReader = None


# ---------------------------------------------------------------------------
# Shared state between streamer thread and visualizer (main thread)
# ---------------------------------------------------------------------------
sample_queue: queue.Queue = queue.Queue(maxsize=2000)
stop_event:   threading.Event = threading.Event()


# ---------------------------------------------------------------------------
# STREAMER  (runs in background thread)
# ---------------------------------------------------------------------------

class ECGStreamer:
    """Stream ECG data to FPGA via UART and push each sample to sample_queue."""

    def __init__(self, port, baud=115200):
        try:
            self.ser = serial.Serial(port, baud, timeout=1)
            print(f"✓ Connected to {port} at {baud} baud")
        except serial.SerialException as e:
            print(f"✗ Error opening serial port: {e}")
            sys.exit(1)

    # ── loaders ─────────────────────────────────────────────────────────────

    def load_ecg_csv(self, filename):
        try:
            df = pd.read_csv(filename)
            ecg_col = None
            for col in ['ECG', 'ecg', 'signal', 'value', '0']:
                if col in df.columns:
                    ecg_col = col
                    break
            data = df.iloc[:, 0].values if ecg_col is None else df[ecg_col].values
            print(f"✓ Loaded {len(data)} samples from {filename}")
            return data
        except Exception as e:
            print(f"✗ Error loading CSV: {e}")
            sys.exit(1)

    def load_dat(self, record_path, signal_num=0, max_samples=None):
        if MITBIHReader is None:
            print("✗ MIT-BIH reader not available (ecg_dat_reader.py missing)")
            sys.exit(1)
        reader = MITBIHReader(record_path)
        signal = reader.read_signal(signal_num)
        if max_samples and len(signal) > max_samples:
            signal = signal[:max_samples]
        print(f"✓ Loaded MIT-BIH: {len(signal)} samples")
        return signal

    # ── conversion ──────────────────────────────────────────────────────────

    def convert_to_12bit(self, ecg_data):
        """
        UART path  : min-max → [-1, 1] → 12-bit signed int  (for FPGA)
        Display path : raw physical values (mV), completely untouched

        These two paths are kept strictly separate so the display always
        shows the true signal amplitude — nothing is clipped or squeezed.
        """
        data_min = float(ecg_data.min())
        data_max = float(ecg_data.max())

        # UART: min-max normalise → 12-bit
        ecg_norm  = 2.0 * (ecg_data - data_min) / (data_max - data_min) - 1.0
        ecg_12bit = np.clip((ecg_norm * 2047).astype(int), -2048, 2047)

        print(f"✓ 12-bit (UART)   : min={ecg_12bit.min()},  max={ecg_12bit.max()}")
        print(f"✓ Display (raw mV): min={data_min:.4f},  max={data_max:.4f}")

        # Return raw physical values for display — NOT normalised
        return ecg_12bit, ecg_data.astype(float)

    # ── sender ───────────────────────────────────────────────────────────────

    def send_sample(self, sample_int):
        if sample_int < 0:
            sample_u = (1 << 12) + sample_int
        else:
            sample_u = sample_int
        sample_u &= 0xFFF
        self.ser.write(bytes([sample_u & 0xFF, (sample_u >> 8) & 0x0F]))

    # ── main stream loop ─────────────────────────────────────────────────────

    def stream_ecg(self, ecg_12bit, ecg_display, sample_rate=360, loop=False):
        period = 1.0 / sample_rate
        count  = 0
        start  = time.perf_counter()

        print(f"\n▶ Streaming {len(ecg_12bit)} samples at {sample_rate} Hz")
        print(f"  Loop: {loop}  |  Close plot window to stop\n")

        try:
            while not stop_event.is_set():
                for i in range(len(ecg_12bit)):
                    if stop_event.is_set():
                        break

                    self.send_sample(int(ecg_12bit[i]))

                    try:
                        sample_queue.put_nowait(float(ecg_display[i]))
                    except queue.Full:
                        pass

                    count += 1
                    if count % sample_rate == 0:
                        elapsed = time.perf_counter() - start
                        print(f"  Sent: {count:6d} | {elapsed:5.1f}s | "
                              f"{count/elapsed:.1f} Hz")

                    time.sleep(period)

                if not loop:
                    break
                print("  ↻ Looping...")

        except Exception as e:
            print(f"\n✗ Streamer error: {e}")
        finally:
            elapsed = time.perf_counter() - start
            print(f"\n✓ Streamer done | {count} samples | {elapsed:.1f}s")
            stop_event.set()
            self.ser.close()
            print("✓ Serial port closed")


# ---------------------------------------------------------------------------
# VISUALIZER  (runs on main thread)
# ---------------------------------------------------------------------------

class ECGVisualizer:
    """Live scrolling ECG display fed from sample_queue."""

    def __init__(self, window_size=1000, sample_rate=360, y_min=-1.0, y_max=1.0):
        self.window_size  = window_size
        self.sample_rate  = sample_rate
        self.sample_count = 0
        self.start_time   = None

        self.plot_buffer = deque(maxlen=window_size)
        self.x_buffer    = deque(maxlen=window_size)

        plt.style.use('seaborn-v0_8-darkgrid')
        self.fig, self.ax = plt.subplots(figsize=(14, 7))
        self.line, = self.ax.plot([], [], 'g-', linewidth=2, label='ECG Signal')

        self.ax.set_xlim(0, window_size)
        self.ax.set_ylim(y_min, y_max)          # set from real data range
        self.ax.set_xlabel('Sample Number',  fontsize=13, fontweight='bold')
        self.ax.set_ylabel('Amplitude (mV)', fontsize=13, fontweight='bold')
        self.ax.set_title('ECG Live Streaming Visualization',
                          fontsize=16, fontweight='bold')
        self.ax.grid(True, alpha=0.4, linestyle='--', linewidth=0.8)
        self.ax.legend(loc='upper right', fontsize=11)

        self.status_text = self.ax.text(
            0.02, 0.98, '', transform=self.ax.transAxes,
            verticalalignment='top', fontsize=12,
            bbox=dict(boxstyle='round', facecolor='lightyellow',
                      alpha=0.9, edgecolor='black'),
            family='monospace', fontweight='bold'
        )
        plt.tight_layout()
        self.fig.canvas.mpl_connect('close_event', self._on_close)

    def _on_close(self, event):
        print("\n  Plot window closed — stopping streamer…")
        stop_event.set()

    def update_frame(self, frame):
        drained = 0
        while not sample_queue.empty() and drained < 20:
            try:
                sample = sample_queue.get_nowait()
                self.plot_buffer.append(sample)
                self.x_buffer.append(self.sample_count)
                self.sample_count += 1
                drained += 1
            except queue.Empty:
                break

        if len(self.plot_buffer) > 0:
            self.line.set_data(list(self.x_buffer), list(self.plot_buffer))
            x_max = self.x_buffer[-1]
            self.ax.set_xlim(max(0, x_max - self.window_size), x_max)

            if self.start_time:
                elapsed = time.time() - self.start_time
                rate = self.sample_count / elapsed if elapsed > 0 else 0
                self.status_text.set_text(
                    f'Samples: {self.sample_count:6d} | '
                    f'Time: {elapsed:6.1f}s | '
                    f'Rate: {rate:6.1f} Hz'
                )

        return self.line, self.status_text

    def run(self):
        self.start_time = time.time()
        ani = FuncAnimation(
            self.fig, self.update_frame,
            interval=max(1, int(1000.0 / self.sample_rate)),
            blit=True, cache_frame_data=False, repeat=False
        )
        plt.show()


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='ECG Stream + Visualize (combined)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ecg_stream_and_visualize.py --port COM3 --file data/normal_ecg.csv
  python ecg_stream_and_visualize.py --port COM3 --file data/normal_ecg.csv --loop
  python ecg_stream_and_visualize.py --port COM3 --file "../ECG signals/15814" --signal 0
        """
    )
    parser.add_argument('--port',        '-p', required=True)
    parser.add_argument('--file',        '-f', required=True)
    parser.add_argument('--signal',      '-s', type=int, default=0)
    parser.add_argument('--rate',        '-r', type=int, default=360)
    parser.add_argument('--baud',        '-b', type=int, default=115200)
    parser.add_argument('--loop',        '-l', action='store_true')
    parser.add_argument('--window',      '-w', type=int, default=1000)
    parser.add_argument('--max-samples', '-m', type=int, default=None)
    args = parser.parse_args()

    file_path = Path(args.file)
    is_dat    = file_path.suffix in ['.dat', '.hea'] or not file_path.suffix

    if not is_dat and not file_path.exists():
        print(f"✗ File not found: {args.file}")
        sys.exit(1)

    # ── Load ────────────────────────────────────────────────────────────────
    streamer = ECGStreamer(args.port, args.baud)

    if is_dat:
        ecg_raw = streamer.load_dat(str(file_path.with_suffix('')),
                                    args.signal, args.max_samples)
    else:
        ecg_raw = streamer.load_ecg_csv(args.file)
        if args.max_samples:
            ecg_raw = ecg_raw[:args.max_samples]

    ecg_12bit, ecg_display = streamer.convert_to_12bit(ecg_raw)

    # ── Y-axis range ────────────────────────────────────────────────────────
    # PROBLEM: absolute min/max is skewed by outlier samples that exist in
    # the full dataset but are never visible in the scrolling window. This
    # makes the real signal look like a tiny squished band in empty space.
    # FIX: use 1st-99th percentile to capture the true signal band, then
    # add only 10% padding so peaks have breathing room without wasted space.
    sig_min = float(np.percentile(ecg_raw, 1))
    sig_max = float(np.percentile(ecg_raw, 99))
    padding = (sig_max - sig_min) * 0.10
    y_min   = sig_min - padding
    y_max   = sig_max + padding
    print(f"Signal band  : [{sig_min:.4f}, {sig_max:.4f}] mV  (1st-99th percentile)")
    print(f"Plot y-range : [{y_min:.4f}, {y_max:.4f}] mV  (+/-10% padding)")

    # ── Streamer thread ─────────────────────────────────────────────────────
    stream_thread = threading.Thread(
        target=streamer.stream_ecg,
        args=(ecg_12bit, ecg_display, args.rate, args.loop),
        daemon=True, name='ECGStreamer'
    )
    stream_thread.start()
    print("✓ Streamer thread started")

    # ── Visualizer (main thread, blocking) ──────────────────────────────────
    viz = ECGVisualizer(window_size=args.window, sample_rate=args.rate,
                        y_min=y_min, y_max=y_max)
    print("✓ Visualizer starting  (close the plot window to quit)\n")
    viz.run()

    # ── Cleanup ─────────────────────────────────────────────────────────────
    stop_event.set()
    stream_thread.join(timeout=3)
    print("\n✓ All done.")


if __name__ == '__main__':
    main()