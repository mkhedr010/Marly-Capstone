#!/usr/bin/env python3
"""
MIT-BIH ECG Data Reader
Reads MIT-BIH format ECG files (.dat and .hea)

Author: Marly
Date: February 26, 2026
Version: 1.0
"""

import numpy as np
import struct
from pathlib import Path


class MITBIHReader:
    """Read MIT-BIH format ECG data files"""
    
    def __init__(self, record_path):
        """
        Initialize reader with record path (without extension)
        
        Args:
            record_path: Path to record without extension (e.g., 'ECG signals/15814')
        """
        self.record_path = Path(record_path)
        self.header_file = self.record_path.with_suffix('.hea')
        self.data_file = self.record_path.with_suffix('.dat')
        
        self.num_signals = 0
        self.sample_rate = 0
        self.num_samples = 0
        self.signal_info = []
        
        # Read header first
        self._read_header()
    
    def _read_header(self):
        """Parse .hea header file"""
        if not self.header_file.exists():
            raise FileNotFoundError(f"Header file not found: {self.header_file}")
        
        with open(self.header_file, 'r') as f:
            lines = f.readlines()
        
        # First line: record_name num_signals sampling_freq num_samples
        parts = lines[0].split()
        self.num_signals = int(parts[1])
        self.sample_rate = int(parts[2])
        self.num_samples = int(parts[3])
        
        # Signal info lines
        for i in range(1, self.num_signals + 1):
            parts = lines[i].split()
            signal_info = {
                'filename': parts[0],
                'format': int(parts[1]),
                'gain': float(parts[2]) if parts[2] != '0' else 200.0,  # Default gain
                'baseline': int(parts[3]),
                'units': int(parts[4]),
                'adc_res': int(parts[5]),
                'adc_zero': int(parts[6]),
                'description': parts[8] if len(parts) > 8 else f'Signal {i}'
            }
            self.signal_info.append(signal_info)
        
        print(f"✓ Header parsed: {self.num_signals} signals, {self.sample_rate} Hz, {self.num_samples} samples")
    
    def read_signal(self, signal_num=0):
        """
        Read a specific signal from the .dat file
        
        Args:
            signal_num: Signal index (0-based)
            
        Returns:
            numpy array of signal samples in physical units
        """
        if not self.data_file.exists():
            raise FileNotFoundError(f"Data file not found: {self.data_file}")
        
        if signal_num >= self.num_signals:
            raise ValueError(f"Signal {signal_num} not found (only {self.num_signals} signals)")
        
        signal_info = self.signal_info[signal_num]
        format_code = signal_info['format']
        
        # Format 310: 3 signals, 10-bit resolution, packed
        # Format 212: 2 signals, 12-bit resolution
        # Format 16: 1 signal, 16-bit
        
        if format_code == 310:
            # 3 signals, 10-bit each, packed into 4 bytes per 3 samples
            samples = self._read_format_310(signal_num)
        elif format_code == 212:
            # 2 signals, 12-bit each
            samples = self._read_format_212(signal_num)
        elif format_code == 16:
            # Single 16-bit signal
            samples = self._read_format_16()
        else:
            raise NotImplementedError(f"Format {format_code} not implemented")
        
        # Convert ADC values to physical units
        gain = signal_info['gain']
        baseline = signal_info['baseline']
        adc_zero = signal_info['adc_zero']
        
        # Physical value = (ADC - ADC_zero - baseline) / gain
        physical = (samples - adc_zero - baseline) / gain
        
        print(f"✓ Read signal {signal_num}: {len(physical)} samples")
        print(f"  Range: {physical.min():.2f} to {physical.max():.2f} mV")
        
        return physical
    
    def _read_format_310(self, signal_num):
        """Read format 310 (3 signals, 10-bit)"""
        with open(self.data_file, 'rb') as f:
            data = f.read()
        
        samples = []
        bytes_per_sample_group = 4  # 4 bytes for 3 10-bit samples
        
        for i in range(0, len(data), bytes_per_sample_group):
            if i + 3 >= len(data):
                break
            
            # Read 4 bytes
            b0, b1, b2, b3 = struct.unpack('BBBB', data[i:i+4])
            
            # Decode 3 10-bit samples from 4 bytes
            # Sample 0: b0 and lower 2 bits of b1
            # Sample 1: upper 6 bits of b1 and lower 4 bits of b2
            # Sample 2: upper 4 bits of b2 and b3
            
            s0 = b0 | ((b1 & 0x03) << 8)
            s1 = ((b1 >> 2) & 0x3F) | ((b2 & 0x0F) << 6)
            s2 = ((b2 >> 4) & 0x0F) | (b3 << 4)
            
            # Sign extend 10-bit to signed integer
            if s0 & 0x200:  # Negative
                s0 = s0 - 1024
            if s1 & 0x200:
                s1 = s1 - 1024
            if s2 & 0x200:
                s2 = s2 - 1024
            
            samples.append([s0, s1, s2])
        
        # Convert to numpy array and extract requested signal
        samples = np.array(samples)
        return samples[:, signal_num]
    
    def _read_format_212(self, signal_num):
        """Read format 212 (2 signals, 12-bit)"""
        with open(self.data_file, 'rb') as f:
            data = f.read()
        
        samples = []
        
        for i in range(0, len(data), 3):
            if i + 2 >= len(data):
                break
            
            # Read 3 bytes containing 2 12-bit samples
            b0, b1, b2 = struct.unpack('BBB', data[i:i+3])
            
            # Sample 0: b0 and lower 4 bits of b1
            # Sample 1: upper 4 bits of b1 and b2
            s0 = b0 | ((b1 & 0x0F) << 8)
            s1 = ((b1 >> 4) & 0x0F) | (b2 << 4)
            
            # Sign extend 12-bit
            if s0 & 0x800:
                s0 = s0 - 4096
            if s1 & 0x800:
                s1 = s1 - 4096
            
            samples.append([s0, s1])
        
        samples = np.array(samples)
        return samples[:, signal_num]
    
    def _read_format_16(self):
        """Read format 16 (single 16-bit signal)"""
        with open(self.data_file, 'rb') as f:
            data = f.read()
        
        # Read as signed 16-bit integers
        num_samples = len(data) // 2
        samples = np.frombuffer(data, dtype=np.int16, count=num_samples)
        
        return samples
    
    def get_info(self):
        """Get record information"""
        return {
            'num_signals': self.num_signals,
            'sample_rate': self.sample_rate,
            'num_samples': self.num_samples,
            'signal_names': [s['description'] for s in self.signal_info]
        }


# Test/example usage
if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python ecg_dat_reader.py <record_path>")
        print("Example: python ecg_dat_reader.py 'ECG signals/15814'")
        sys.exit(1)
    
    record = sys.argv[1]
    
    # Read the record
    reader = MITBIHReader(record)
    info = reader.get_info()
    
    print(f"\nRecord Information:")
    print(f"  Signals: {info['num_signals']}")
    print(f"  Sample Rate: {info['sample_rate']} Hz")
    print(f"  Total Samples: {info['num_samples']}")
    print(f"  Signal Names: {info['signal_names']}")
    
    # Read first signal
    signal = reader.read_signal(0)
    print(f"\nFirst signal stats:")
    print(f"  Mean: {signal.mean():.2f}")
    print(f"  Std: {signal.std():.2f}")
    print(f"  Min: {signal.min():.2f}")
    print(f"  Max: {signal.max():.2f}")
