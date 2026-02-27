#!/usr/bin/env python3
"""
Minimal UART Test - NO matplotlib, just streaming
Tests basic UART transmission to FPGA

Usage:
    python test_uart_only.py --port COM4

Author: Marly
Date: February 27, 2026
"""

import serial
import time
import argparse

def test_uart_streaming(port, baud=115200):
    """Test UART streaming with simple pattern"""
    
    print(f"\n{'='*60}")
    print(f"  UART STREAMING TEST (NO PLOT)")
    print(f"{'='*60}\n")
    
    # Connect
    try:
        ser = serial.Serial(port, baud, timeout=1)
        print(f"✓ Connected to {port} at {baud} baud\n")
    except Exception as e:
        print(f"✗ Error: {e}")
        return
    
    # Create simple test pattern (sine wave, 20 samples)
    import math
    test_samples = []
    for i in range(20):
        value = int(1000 * math.sin(2 * math.pi * i / 10))
        test_samples.append(value)
    
    print(f"Test Pattern: {len(test_samples)} samples")
    print(f"Values: {test_samples[:5]}... (showing first 5)\n")
    
    # Stream samples
    print("▶ Streaming started...\n")
    
    for idx, sample in enumerate(test_samples):
        # Convert to unsigned 12-bit
        if sample < 0:
            sample_unsigned = (1 << 12) + sample
        else:
            sample_unsigned = sample
        
        sample_unsigned = sample_unsigned & 0xFFF
        
        # Split into 2 bytes
        byte1 = sample_unsigned & 0xFF
        byte2 = (sample_unsigned >> 8) & 0x0F
        
        # Send
        ser.write(bytes([byte1, byte2]))
        
        # Print each sample
        print(f"  [{idx+1:2d}/20] Sent: {sample:5d} → bytes: 0x{byte1:02X} 0x{byte2:02X}")
        
        # Wait a bit (slow enough to see)
        time.sleep(0.1)  # 100ms = 10 Hz for visibility
    
    print(f"\n✓ Finished sending {len(test_samples)} samples")
    print(f"  Check FPGA LED[0] - should have toggled {len(test_samples)} times")
    print(f"  Check FPGA LED[1] - should be ON (UART active)\n")
    
    ser.close()
    print("✓ Serial port closed\n")


def main():
    parser = argparse.ArgumentParser(description='Test UART streaming (minimal)')
    parser.add_argument('--port', '-p', required=True, help='COM port (e.g., COM4)')
    parser.add_argument('--baud', '-b', type=int, default=115200, help='Baud rate')
    
    args = parser.parse_args()
    
    test_uart_streaming(args.port, args.baud)


if __name__ == '__main__':
    main()
