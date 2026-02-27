# Milestones Compliance Report
## ECG Simulation Component - UART Streaming Implementation

**Student**: Marly  
**Course**: COE 70B Capstone Project (GK02)  
**Component**: ECG Simulation & Visualization System  
**Report Period**: January 2026  
**Date**: January 22, 2026

---

## Tasks Outlined

The primary task for this reporting period was to develop a mechanism for streaming ECG signal data from a PC to the FPGA hardware model used by team members (students B and D - Ayoub's CNN classifier). This required three main components: manipulating the ECG signal data into an appropriate format for transmission, configuring the PC-to-FPGA connection interface, and implementing the streaming script that would handle continuous data transfer. The ECG data, sourced from MIT-BIH datasets in CSV format, needed to be processed and normalized into 12-bit signed integer samples suitable for both FPGA processing and CNN classification. The connection configuration involved setting up UART serial communication at 115200 baud rate through the USB interface on the Spartan-3E FPGA board. The streaming mechanism required developing a Python application capable of loading various ECG waveforms (Normal, PVC, Atrial Fibrillation), converting them to the correct bit width and format, and transmitting them at the physiologically-accurate rate of 360 Hz to match the MIT-BIH standard sampling frequency. Additionally, the FPGA side required implementation of a UART receiver module that could accept the serial data stream, deserialize the bytes, assemble multi-byte samples, and make them available to both the VGA display subsystem and the CNN classifier interface.

---

## Progress Made

The task was accomplished through parallel development of both PC-side and FPGA-side components. On the Python side, I developed `ecg_streamer.py`, a command-line application that handles the complete data pipeline. The script uses pandas to load ECG data from CSV files, applies z-score normalization to standardize the signal amplitude, converts floating-point values to 12-bit signed integers in the range -2048 to +2047, and transmits each sample as two sequential bytes via pyserial. Here's the core streaming logic:

```python
def send_sample(self, sample):
    # Convert to unsigned 12-bit (two's complement if negative)
    if sample < 0:
        sample_unsigned = (1 << 12) + sample
    else:
        sample_unsigned = sample
    sample_unsigned = sample_unsigned & 0xFFF
    
    # Split into 2 bytes
    byte1 = sample_unsigned & 0xFF         # Lower 8 bits
    byte2 = (sample_unsigned >> 8) & 0x0F  # Upper 4 bits
    
    # Send via UART
    self.ser.write(bytes([byte1, byte2]))

def stream_ecg(self, ecg_data, sample_rate=360):
    sample_period = 1.0 / sample_rate
    for sample in ecg_data:
        self.send_sample(sample)
        time.sleep(sample_period)  # 360 Hz timing
```

On the FPGA side, I implemented the `uart_receiver.vhd` module in VHDL, which handles serial reception at 115200 baud. The module uses a state machine (IDLE → START_BIT → DATA_BITS → STOP_BIT) with precise timing control based on dividing the 50 MHz system clock by 434 to achieve the correct baud rate. The receiver samples the UART RX line at 16× oversampling rate for robust bit detection. Here's the multi-byte assembly logic:

```vhdl
-- UART byte reception state machine
case uart_state is
    when IDLE =>
        if uart_rx = '0' then  -- Detect start bit
            uart_state <= START_BIT;
        end if;
    when DATA_BITS =>
        rx_data(bit_index) <= uart_rx;  -- Sample at midpoint
        if bit_index < 7 then
            bit_index <= bit_index + 1;
        else
            uart_state <= STOP_BIT;
        end if;
end case;

-- Multi-byte assembly (2 bytes → 12-bit sample)
case byte_state is
    when WAIT_BYTE1 =>
        byte1_data <= rx_data;      -- Store lower 8 bits
        byte_state <= WAIT_BYTE2;
    when WAIT_BYTE2 =>
        byte2_data <= rx_data;
        ecg_sample <= rx_data(3 downto 0) & byte1_data;  -- Assemble 12 bits
        sample_valid <= '1';        -- Signal new sample ready
        byte_state <= WAIT_BYTE1;
end case;
```

The connection configuration involved identifying the correct UART pins on the Spartan-3E board (the FT232 USB-UART bridge chip uses pin R7 for RX), setting the baud rate to 115200 with 8 data bits, no parity, and 1 stop bit (8N1 configuration). The UCF constraints file was configured to map the UART_RX signal to the physical pin location. Testing and verification were performed using a simple testbench that simulates UART transmission and verifies correct byte reception and 12-bit sample assembly. The Python script was tested with a sine wave test pattern before moving to real ECG data, confirming proper data flow from PC to FPGA.

---

## Difficulties Encountered

The most significant challenge during this period was a fundamental change in the system architecture. Initially, the plan called for using two FPGA boards: one (DE2-115) would store and play ECG waveforms, transmitting them to the second FPGA (Spartan-3E) which would run the CNN classifier and display. This approach seemed attractive because it would demonstrate inter-FPGA communication and allow both team members to work with physical hardware. However, several practical difficulties emerged. First, the DE2-115 board uses a different FPGA family (Altera Cyclone IV) requiring Quartus software, while the Spartan-3E uses Xilinx ISE, meaning two separate development environments and toolchains would be needed. Second, coordinating pin assignments and signal levels between two different FPGA families proved complex, particularly for the data transfer interface which would need multiple GPIO pins, clock synchronization, and handshaking signals. Third, the added complexity of programming and debugging two boards simultaneously would significantly increase development time and the potential for integration issues. Most critically, we realized that having the DE2-115 board simply store and replay ECG data was an inefficient use of FPGA resources—a PC could perform this task more flexibly while allowing unlimited waveform selection and easier data updates. The decision was made to pivot to a single-FPGA architecture where the PC streams ECG data via UART to the Spartan-3E board, which handles both display and CNN classification. This change actually simplified the overall system, reduced hardware dependencies, eliminated the need for Quartus/Altera tools, and provided greater flexibility for testing different ECG datasets without reprogramming the FPGA. The transition required rethinking the data source approach and implementing the UART streaming infrastructure, but ultimately resulted in a more elegant and practical solution.

---

## Tasks to Be Completed in Next Report

The primary task for the next reporting period is to determine the optimal approach for real-time signal display and implement the visualization subsystem. A critical decision point is whether the scrolling ECG waveform display should be generated by the FPGA hardware driving a VGA monitor directly, or alternatively rendered on the PC screen using the Python application. The FPGA-based VGA approach offers a true embedded system demonstration with hardware-generated graphics at 640×480 resolution, scrolling the waveform across the screen in real-time as samples arrive from the UART receiver. This would involve completing the VGA timing generator and ECG renderer modules already designed in VHDL, implementing the circular buffer for waveform storage, and mapping 12-bit sample values to Y-coordinates on the display. The PC-based display approach would add a matplotlib or tkinter GUI to the Python streaming application, showing the transmitted waveform in real-time on the computer screen, which offers easier debugging and requires less FPGA resource usage. Both approaches have merit: the VGA solution provides more impressive hardware demonstration and teaches important FPGA display techniques, while the PC solution offers faster development and simpler troubleshooting. The next steps include hardware testing of the UART receiver on the actual Spartan-3E board using LED indicators to verify correct data reception, followed by implementing whichever display approach is selected and testing with real ECG datasets (Normal, PVC, AFib waveforms). Integration with the CNN classifier module from team member Ayoub will also begin, requiring definition of the internal FPGA signal interface for passing ECG samples and receiving classification results. Finally, performance characterization will measure end-to-end latency and verify the system can sustain continuous 360 Hz streaming without data loss.

---

**Report Prepared By**: Marly  
**Date**: January 22, 2026  
**Status**: On Schedule
