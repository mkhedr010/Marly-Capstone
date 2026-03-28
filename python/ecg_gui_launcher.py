#!/usr/bin/env python3
"""
ECG Stream Visualizer - GUI Launcher




A tkinter-based GUI for launching ecg_stream_visualize.py without command-line arguments.
Provides file browser, COM port selection, and signal number selection.




Author: Claude Code
Date: March 2026
Version: 1.0
"""




import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import subprocess
import threading
import sys
import os
from pathlib import Path
import queue
import serial.tools.list_ports








class ECGVisualizerGUI:
    """GUI launcher for ECG stream visualizer."""




    def __init__(self, root):
        self.root = root
        self.root.title("ECG Stream Visualizer - FPGA Launcher")
        self.root.geometry("700x500")
        self.root.resizable(False, False)




        # State variables
        self.process = None
        self.process_running = False
        self.output_queue = queue.Queue()




        # Get project root (parent of python directory)
        self.project_root = Path(__file__).parent.parent
        self.default_ecg_dir = self.project_root / "ECG signals"




        # Create GUI components
        self.create_widgets()




        # Start output queue monitor
        self.root.after(100, self.check_output_queue)




    def create_widgets(self):
        """Create all GUI widgets."""




        # Main container with padding
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))




        # Title label
        title_label = ttk.Label(main_frame, text="ECG Stream Visualizer Launcher",
                               font=('Segoe UI', 14, 'bold'))
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 20))




        # ===== ECG File Selection =====
        row = 1
        ttk.Label(main_frame, text="ECG Signal File:", font=('Segoe UI', 10)).grid(
            row=row, column=0, sticky=tk.W, pady=5)




        self.file_var = tk.StringVar()
        file_entry = ttk.Entry(main_frame, textvariable=self.file_var, width=50, state='readonly')
        file_entry.grid(row=row, column=1, sticky=(tk.W, tk.E), padx=5)




        browse_btn = ttk.Button(main_frame, text="Browse...", command=self.browse_file)
        browse_btn.grid(row=row, column=2, padx=5)




        # ===== COM Port Selection =====
        row += 1
        ttk.Label(main_frame, text="COM Port:", font=('Segoe UI', 10)).grid(
            row=row, column=0, sticky=tk.W, pady=5)




        self.port_var = tk.StringVar(value="COM3")
        self.port_combo = ttk.Combobox(main_frame, textvariable=self.port_var,
                                       values=[f"COM{i}" for i in range(8)],
                                       width=15, state='readonly')
        self.port_combo.grid(row=row, column=1, sticky=tk.W, padx=5)




        refresh_btn = ttk.Button(main_frame, text="Refresh Ports", command=self.refresh_ports)
        refresh_btn.grid(row=row, column=2, padx=5)




        # ===== Signal Number Selection =====
        row += 1
        ttk.Label(main_frame, text="Signal Number:", font=('Segoe UI', 10)).grid(
            row=row, column=0, sticky=tk.W, pady=5)




        self.signal_var = tk.StringVar(value="0")
        signal_combo = ttk.Combobox(main_frame, textvariable=self.signal_var,
                                    values=[str(i) for i in range(11)],
                                    width=15, state='readonly')
        signal_combo.grid(row=row, column=1, sticky=tk.W, padx=5)




        ttk.Label(main_frame, text="(For multi-channel .dat files)",
                 font=('Segoe UI', 8), foreground='gray').grid(
            row=row, column=2, sticky=tk.W)




        # ===== Action Buttons =====
        row += 1
        button_frame = ttk.Frame(main_frame)
        button_frame.grid(row=row, column=0, columnspan=3, pady=20)




        self.run_btn = ttk.Button(button_frame, text="Run Visualization",
                                  command=self.run_visualization)
        self.run_btn.grid(row=0, column=0, padx=5)




        self.stop_btn = ttk.Button(button_frame, text="Stop",
                                   command=self.stop_visualization, state='disabled')
        self.stop_btn.grid(row=0, column=1, padx=5)




        clear_btn = ttk.Button(button_frame, text="Clear", command=self.clear_form)
        clear_btn.grid(row=0, column=2, padx=5)




        # ===== Status Label =====
        row += 1
        self.status_var = tk.StringVar(value="Status: Ready")
        status_label = ttk.Label(main_frame, textvariable=self.status_var,
                                font=('Segoe UI', 10, 'bold'), foreground='green')
        status_label.grid(row=row, column=0, columnspan=3, pady=(0, 10))




        # ===== Log/Output Display =====
        row += 1
        ttk.Label(main_frame, text="Log Output:", font=('Segoe UI', 10)).grid(
            row=row, column=0, columnspan=3, sticky=tk.W, pady=(5, 0))




        row += 1
        log_frame = ttk.Frame(main_frame)
        log_frame.grid(row=row, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=5)




        # Create text widget with scrollbar
        scrollbar = ttk.Scrollbar(log_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)




        self.log_text = tk.Text(log_frame, height=12, width=80,
                               yscrollcommand=scrollbar.set,
                               font=('Consolas', 9), state='disabled')
        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.log_text.yview)




        # Configure text tags for colored output
        self.log_text.tag_config('success', foreground='green')
        self.log_text.tag_config('error', foreground='red')
        self.log_text.tag_config('info', foreground='blue')




        # Grid configuration for expansion
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(row, weight=1)
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)




    def browse_file(self):
        """Open file dialog to select ECG file."""
        initial_dir = self.default_ecg_dir if self.default_ecg_dir.exists() else Path.home()




        # Allow selecting .dat files or directories (for MIT-BIH format)
        file_path = filedialog.askopenfilename(
            title="Select ECG Signal File",
            initialdir=initial_dir,
            filetypes=[
                ("DAT files", "*.dat"),
                ("All files", "*.*")
            ]
        )




        if file_path:
            # Convert to Path and remove .dat extension if present (MIT-BIH format)
            path = Path(file_path)
            if path.suffix == '.dat':
                # Remove extension for MIT-BIH format
                file_path = str(path.with_suffix(''))




            self.file_var.set(file_path)
            self.log_message(f"Selected file: {file_path}", 'info')




    def refresh_ports(self):
        """Refresh available COM ports."""
        ports = self.get_available_ports()
        self.port_combo['values'] = ports




        if ports:
            self.log_message(f"Found {len(ports)} COM port(s): {', '.join(ports)}", 'success')
        else:
            self.log_message("No COM ports detected. Using default list (COM0-COM7).", 'info')




    def get_available_ports(self):
        """Get list of available COM ports."""
        try:
            ports = serial.tools.list_ports.comports()
            available = sorted([port.device for port in ports])




            # Fallback to COM0-COM7 if none detected
            if not available:
                return [f"COM{i}" for i in range(8)]




            return available
        except Exception as e:
            self.log_message(f"Error detecting ports: {e}", 'error')
            return [f"COM{i}" for i in range(8)]




    def validate_inputs(self):
        """Validate all inputs before running."""
        # Check file path
        file_path = self.file_var.get().strip()
        if not file_path:
            messagebox.showerror("Validation Error", "Please select an ECG signal file.")
            return False




        # Check file exists
        path = Path(file_path)




        # For MIT-BIH format, check both .dat and .hea exist
        dat_file = path.with_suffix('.dat')
        hea_file = path.with_suffix('.hea')




        if not dat_file.exists():
            messagebox.showerror("Validation Error",
                               f"ECG data file not found:\n{dat_file}\n\nPlease check the file path.")
            return False




        if not hea_file.exists():
            self.log_message(f"Warning: Header file not found: {hea_file}", 'error')
            response = messagebox.askyesno("Missing Header File",
                                          f"Header file (.hea) not found:\n{hea_file}\n\n" +
                                          "The visualization may not work correctly.\n\n" +
                                          "Continue anyway?")
            if not response:
                return False




        # Check COM port format
        port = self.port_var.get()
        if not port.startswith("COM"):
            messagebox.showerror("Validation Error", "Invalid COM port format. Use COMx (e.g., COM3).")
            return False




        # Check signal number
        try:
            signal = int(self.signal_var.get())
            if signal < 0 or signal > 10:
                messagebox.showerror("Validation Error", "Signal number must be between 0 and 10.")
                return False
        except ValueError:
            messagebox.showerror("Validation Error", "Signal number must be a valid integer.")
            return False




        return True




    def run_visualization(self):
        """Launch the visualization subprocess."""
        if self.process_running:
            messagebox.showwarning("Already Running", "Visualization is already running.")
            return




        # Validate inputs
        if not self.validate_inputs():
            return




        # Get parameters
        port = self.port_var.get()
        file_path = Path(self.file_var.get()).resolve()
        signal = self.signal_var.get()




        # Build command
        script_path = Path(__file__).parent / "ecg_stream_visualize.py"




        cmd = [
            sys.executable,
            str(script_path),
            "--port", port,
            "--file", str(file_path),
            "--signal", signal
        ]




        # Log the command
        self.log_message(f"Launching: {' '.join(cmd)}", 'info')
        self.log_message("-" * 80, 'info')




        # Launch subprocess in background thread
        thread = threading.Thread(target=self.run_subprocess, args=(cmd,), daemon=True)
        thread.start()




        # Update UI state
        self.process_running = True
        self.status_var.set("Status: Running...")
        self.run_btn['state'] = 'disabled'
        self.stop_btn['state'] = 'normal'




    def run_subprocess(self, cmd):
        """Run subprocess and capture output."""
        try:
            # Set UTF-8 encoding for Windows
            env = os.environ.copy()
            env['PYTHONIOENCODING'] = 'utf-8'
           
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True,
                env=env
            )




            # Stream output to queue
            for line in iter(self.process.stdout.readline, ''):
                if line:
                    self.output_queue.put(('output', line.rstrip()))




            # Wait for process to complete
            return_code = self.process.wait()




            # Report completion
            if return_code == 0:
                self.output_queue.put(('success', 'Visualization completed successfully.'))
            else:
                self.output_queue.put(('error', f'Process exited with code {return_code}'))




        except Exception as e:
            self.output_queue.put(('error', f'Error running subprocess: {e}'))




        finally:
            self.output_queue.put(('done', None))




    def stop_visualization(self):
        """Stop the running subprocess."""
        if self.process and self.process_running:
            try:
                self.process.terminate()
                self.log_message("Stopping visualization...", 'info')
                self.process.wait(timeout=5)
                self.log_message("Visualization stopped by user.", 'success')
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.log_message("Visualization forcefully terminated.", 'error')
            except Exception as e:
                self.log_message(f"Error stopping process: {e}", 'error')




            self.reset_ui_state()




    def check_output_queue(self):
        """Check output queue and update log widget."""
        try:
            while True:
                msg_type, msg = self.output_queue.get_nowait()




                if msg_type == 'done':
                    self.reset_ui_state()
                elif msg_type == 'output':
                    # Determine tag based on content
                    tag = 'info'
                    if  'Connected' in msg or 'Loaded' in msg:
                        tag = 'success'
                    elif  'Error' in msg or 'error' in msg.lower():
                        tag = 'error'




                    self.log_message(msg, tag)
                elif msg_type == 'success':
                    self.log_message(msg, 'success')
                elif msg_type == 'error':
                    self.log_message(msg, 'error')




        except queue.Empty:
            pass




        # Schedule next check
        self.root.after(100, self.check_output_queue)




    def log_message(self, message, tag='info'):
        """Add message to log widget."""
        self.log_text.config(state='normal')
        self.log_text.insert(tk.END, message + '\n', tag)
        self.log_text.see(tk.END)
        self.log_text.config(state='disabled')




    def reset_ui_state(self):
        """Reset UI to ready state."""
        self.process_running = False
        self.process = None
        self.status_var.set("Status: Ready")
        self.run_btn['state'] = 'normal'
        self.stop_btn['state'] = 'disabled'




    def clear_form(self):
        """Clear all form fields."""
        self.file_var.set("")
        self.port_var.set("COM3")
        self.signal_var.set("0")




        # Clear log
        self.log_text.config(state='normal')
        self.log_text.delete('1.0', tk.END)
        self.log_text.config(state='disabled')




        self.log_message("Form cleared. Ready for new input.", 'info')








def main():
    """Main entry point."""
    root = tk.Tk()
    app = ECGVisualizerGUI(root)




    # Center window on screen
    root.update_idletasks()
    width = root.winfo_width()
    height = root.winfo_height()
    x = (root.winfo_screenwidth() // 2) - (width // 2)
    y = (root.winfo_screenheight() // 2) - (height // 2)
    root.geometry(f'{width}x{height}+{x}+{y}')




    root.mainloop()








if __name__ == "__main__":
    main()


