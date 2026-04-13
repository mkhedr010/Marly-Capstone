# Demo Script — ECG CNN Capstone
## Hardware Implementation of CNN as Part of SoC Design for ECG Analysis and Classification
### Marly Barsoum | Toronto Metropolitan University | 2026

---

> **How to use this script:**
> Read it aloud a few times before the demo. Don't memorize word for word — internalize the ideas. The script is written to sound natural, not formal. Aim for confident conversation, not a rehearsed speech. Bold text marks the key technical terms you need to land clearly.

---

## SLIDE 1 — Title

*[Click to start. Pause a second. Look at the audience.]*

"So my project is about taking a neural network — a real convolutional neural network — and implementing it directly in hardware on an FPGA. The application is ECG classification, so the board is actually detecting different types of arrhythmias in real time. I'll walk you through everything: the neural network architecture, how I got the weights onto the chip, the hardware implementation itself, and then we'll run a live demo at the end."

---

## SLIDE 2 — Motivation

*[Gesture toward the stats boxes on the right.]*

"Cardiovascular disease kills about 17.9 million people a year — it's the number one cause of death globally. The standard diagnostic tool is the ECG, but interpreting it manually requires a trained specialist, and that's a bottleneck, especially in remote or high-volume settings.

The idea of automating this with machine learning is well-established — there are papers from Stanford and elsewhere showing neural networks can match cardiologist accuracy. The harder problem is *where* you run that inference. Sending data to the cloud introduces latency and dependency on connectivity. A CPU-based solution works but it's not real-time in the deterministic sense.

FPGAs are interesting here because you get deterministic latency, low power, and you can implement the neural network as actual logic circuits. So the goal of this project was to build a complete system: a CNN that classifies arrhythmias, implemented entirely in hardware, running on a real FPGA board."

---

## SLIDE 3 — System Architecture

*[Point to the block diagram.]*

"The system has two main parts. On the PC side, I have a Python program that reads ECG records from the MIT-BIH Arrhythmia Database, preprocesses the signal, and streams it to the FPGA board over a serial UART connection at the real ECG sampling rate — 360 Hz. The Python program also displays a scrolling ECG waveform on screen in real time.

On the FPGA side — this is the Altera DE2 board with a Cyclone II chip — there's a UART receiver that captures the incoming samples, a 128-sample circular buffer that fills up one beat window at a time, and then the CNN hardware accelerator that processes that window and outputs a classification.

The result shows up on the LCD on the board — it displays either 'Normal' or 'Abnormal' — and there's also a green LED array that indicates the result.

The key thing to understand is that the CNN is not running on a processor. The entire classification happens inside the FPGA logic — state machines, multipliers, accumulators — all synthesized into the actual gates of the chip."

---

## SLIDE 4 — Dataset & Preprocessing

*[Point to the ECG panels on the right.]*

"The dataset is the MIT-BIH Arrhythmia Database from PhysioNet — it's the standard benchmark for ECG arrhythmia research. It has 48 records sampled at 360 Hz with 8 annotated beat classes.

You can see three of them here: Normal on the left, PVC in the middle — that's a Premature Ventricular Contraction, which has this wide unusual QRS complex — and LBBB on the right, which is Left Bundle Branch Block. These are pretty visually distinct once you know what you're looking for.

For each beat, I extract a **128-sample window centered on the R-peak** — so about ±64 samples, which is roughly 356 milliseconds. That window goes into the CNN.

On the preprocessing side, the Python code does two things simultaneously. For the display, it just plots the raw millivolt values — that's the scrolling ECG you'll see on screen. For the UART stream, it min-max normalizes the signal and converts it to a **12-bit signed integer**, then packs each sample into two bytes to send over the serial link."

---

## SLIDE 5 — CNN Architecture

*[Point to the architecture diagram.]*

"The neural network I used is called **ZolotyhNet** — it's a dual-path 1D CNN that was designed specifically to be small enough to fit within the resource limits of the Cyclone II.

The key idea is that there are two separate processing paths operating on the same input. The upper path uses **five Conv1D layers** with MaxPooling to extract local morphological features — things like the shape of the QRS complex. The lower path uses **three fully-connected linear layers** to process the raw signal globally. Then these two paths are fused together by an **element-wise addition**, and a final classifier layer maps to one of the 8 output classes.

The whole network has about **14,700 parameters**. To put that in context, the best-performing model I looked at — EcgResNet34 — has about 500,000 parameters and achieves 99.4% accuracy. ZolotyhNet trades about 3.6% accuracy for a 34× reduction in parameter count, which is what made it feasible to implement on this particular chip.

All the weights are stored in **on-chip M4K RAM blocks** — there's no external memory involved at all."

---

## SLIDE 6 — Quantization Pipeline

*[Point to the pipeline diagram.]*

"Before the weights can go onto the FPGA, they need to be converted from floating-point to fixed-point. The hardware doesn't have floating-point arithmetic units — everything runs in integer arithmetic.

I used **Q8.8 fixed-point** — 16-bit signed integers, with 8 bits for the integer part and 8 bits for the fractional part. The conversion is simple: multiply each weight by 256 and round to the nearest integer. That gives you 0.004 resolution, which is more than enough precision for this application.

I wrote a script called `extract_weights.py` that loads the trained PyTorch model and walks through each layer, converts all the weights and biases to Q8.8, and exports them as **Altera MIF files** — that's the Memory Initialization File format that Quartus uses to initialize on-chip RAM.

There are 18 of these files in total — one for weights and one for biases of each layer.

In hardware, the MAC operation works like this: Q8.8 times Q8.8 gives you a **Q16.16 result** in a 32-bit accumulator. After accumulating all the products, you right-shift by 8 to get back to Q8.8. This all happens inside the hardware engines I'll describe next."

---

## SLIDE 7 — Python Infrastructure

*[Show the screenshot if it's on screen.]*

"On the Python side, the main file is `ecg_stream_visualize.py`. It uses a **two-thread architecture** because matplotlib — which I'm using for the live visualization — has to run on the main thread. So the actual ECG streaming happens in a separate daemon thread called ECGStreamer, which reads samples from the file and puts them into a thread-safe queue at 360 Hz using `time.sleep(1/360)`. The main thread runs ECGVisualizer, which pulls from that queue and updates the plot.

For the serial transmission, every 12-bit sample gets split across two bytes. Byte 1 is the lower 8 bits, Byte 2 is the upper 4 bits zero-padded to a full byte. On the FPGA side, the UART receiver reassembles these two bytes back into the 12-bit sample.

You can see the visualizer running here — it shows the ECG waveform scrolling in real time as samples are being sent to the board."

---

## SLIDE 8 — FPGA: UART & Input Buffer

*[Point to the FSM diagram.]*

"On the FPGA side, the first thing that happens is the serial data comes into `uart_receiver.vhd`. This has two nested state machines. The inner one handles individual byte reception — it detects the start bit, samples each of the 8 data bits at the middle of each bit period using a counter based on the clock frequency divided by the baud rate, and then checks the stop bit. At 50 MHz and 115,200 baud, that's 434 clock cycles per bit.

The outer state machine handles the two-byte protocol. It waits for Byte 1, stores it, waits for Byte 2, then combines the two to reconstruct the 12-bit ECG sample and pulses a `sample_valid` signal for one clock cycle.

These samples go into `buffer_128.vhd`, which is a 128-entry circular buffer implemented in M4K RAM. As each sample comes in, there's a 3-clock pipeline that sign-extends the 12-bit value and arithmetic right-shifts it by 4 to convert it to Q8.8 format. When 128 samples are accumulated, the buffer triggers the CNN state machine to start processing."

---

## SLIDE 9 — FPGA: CNN Accelerator

*[Point to the FSM/engine diagram.]*

"The CNN accelerator is the core of the project. The top-level module implements a **13-state FSM** that sequences through the entire network: it runs Conv layers 1 through 5, then Linear layers 1 through 3, then the fusion step, then the classifier, then Argmax to find the winning class.

To keep the logic element usage down, I used a **time-multiplexed design**. Instead of instantiating separate hardware for each conv layer — which would multiply the resource usage by 5 — there's a **single Conv1D engine** that gets reused for all five conv layers, just reconfigured by the FSM with different size parameters each time. Same idea for the linear layers — one Linear engine handles all four linear operations.

The Conv1D engine has a 9-state FSM internally: it loads a weight, loads the corresponding input, multiplies, accumulates into a 32-bit register, adds the bias, applies ReLU, writes the output, then moves to the next position. The 32-bit accumulator handles the Q16.16 intermediate result without overflow.

The 18 weight ROMs are dual-port M4K blocks initialized from the MIF files at synthesis time. The Quartus attribute `ramstyle='M4K'` forces the tool to map them to block RAM rather than using distributed logic.

With this design I'm using **13% of the logic elements** and **61% of the M4K RAM blocks** on the Cyclone II. The 61% M4K is actually the binding constraint — the biggest single consumer is the Linear1 weight matrix which is 128 by 64 = 8,192 entries."

---

## SLIDE 10 — Live Demo

*[This is the moment. Have the board running or start it now.]*

"OK, so let me actually show you the system running."

*[If board is already running:]*
"So here you can see the FPGA board. On screen you can see the Python visualizer showing the ECG waveform scrolling in real time — these are samples from the MIT-BIH database being read by the Python script and streamed to the board over the serial port.

And on the LCD here — you can see it says 'Normal'. That's because right now I'm streaming record 100, which is a normal sinus rhythm.

*[Switch to an abnormal file]*

Now I'm switching to record 208, which contains PVC beats — Premature Ventricular Contractions. You can see the waveform changes and... the LCD now shows 'Abnormal'. The FPGA classified that correctly.

This classification is happening entirely inside the FPGA. The Python script sends raw samples, the board accumulates 128 of them, runs them through the ZolotyhNet hardware — 13 state machine states, about 110,000 clock cycles — and outputs the result. That takes about 2.2 milliseconds. End-to-end from the first sample to the LCD update it's about 357 milliseconds, which is dominated by the UART fill time."

*[If something goes wrong: stay calm, explain what it should be doing, offer to show the board photos.]*

---

## SLIDE 11 — Results

*[Point to the confusion matrix.]*

"In terms of accuracy, I ran ZolotyhNet on the 9,368-sample validation set and got **95.75% overall accuracy**. You can see the confusion matrix here — each row is the actual class, each column is what the network predicted.

The Normal class — that's N — is 99.37% accurate, which makes sense because it's by far the most common class in the dataset. LBBB and RBBB are both above 94%. PVC is 83.5%, and then the rare classes E and exclamation mark are essentially 0% — these have only 11 and 47 samples respectively in the validation set, so the network basically never saw enough examples to learn them.

Over on the right, this comparison chart shows ZolotyhNet against the two best alternatives I considered. EcgResNet34 achieves 99.4% but has 500,000 parameters — it simply cannot fit on this chip. HeartNetIEEE gets 98.6% with about 48,000 parameters — still too large for the M4K budget. ZolotyhNet at 14,700 parameters is the one that actually fits and works.

The 3.6% gap compared to the best model is real — it's partly the smaller architecture and partly the fact that I couldn't implement batch normalization in hardware, which the software model uses."

---

## SLIDE 12 — Conclusions

*[Wrap up confidently.]*

"So to summarize what I built: a complete hardware-software co-design for ECG arrhythmia classification. On the software side, a full Python pipeline for reading MIT-BIH records, preprocessing, streaming, and visualization. On the hardware side, a VHDL implementation of ZolotyhNet with time-multiplexed MAC engines, 18 on-chip weight ROMs, UART receiver, and LCD controller — all synthesized and running on a real Cyclone II FPGA.

The system achieves 95.75% accuracy, uses only 13% of the logic elements and 61% of the M4K RAM, and classifies each beat window in 2.2 milliseconds. I validated it against about 32 different ECG records from the MIT-BIH database and the LCD output was correct every time.

The main limitation is the class imbalance in the dataset and the absence of batch normalization in hardware, which accounts for most of the gap versus the best software models.

Happy to take questions."

---

## Anticipated Questions & Answers

**Q: Why didn't you use a processor like a soft-core CPU instead of pure VHDL state machines?**
A: "A soft-core CPU like NIOS II would have made the implementation easier, but you'd lose the deterministic latency guarantees. The whole point is that the CNN inference runs in a fixed number of clock cycles — 110,000 cycles every time, no OS scheduling, no cache misses. That's what makes FPGA inference attractive for medical devices."

**Q: Why not use INT8 instead of Q8.8?**
A: "INT8 has no fractional bits, so for weights close to zero — which most CNN weights are — you lose all the precision. Q8.8 gives you 0.004 resolution, which is about right for the weight range in ZolotyhNet. You could do INT8 but you'd need to retrain the network with quantization-aware training and you'd lose some accuracy."

**Q: How accurate is this in clinical terms?**
A: "95.75% overall sounds good but the class imbalance matters a lot. The rare arrhythmia types — ventricular escape beats and flutter — basically aren't classified correctly at all because there are so few training examples. For a real clinical deployment you'd want much more balanced training data and probably a more sophisticated architecture. This is a proof-of-concept for FPGA-based CNN acceleration, not a clinical device."

**Q: Why does M4K usage dominate instead of logic elements?**
A: "Because neural network weights are essentially a lookup table — a huge amount of static data that needs to be accessed fast. On Cyclone II, M4K blocks are the only way to store that much data efficiently. The MAC logic itself is actually quite small — one multiplier and an accumulator — and reusing it across all layers keeps the LE count low. So you end up memory-bound rather than logic-bound."

**Q: Could you extend this to run on a smaller FPGA?**
A: "The binding constraint is M4K. If you cut ZolotyhNet's parameters in half — say by reducing the width of the linear layers — you could probably fit on something like a Cyclone IV EP4CE22 which has 66 M4K blocks. But you'd also lose accuracy. There's a real three-way trade-off between accuracy, parameter count, and FPGA resource usage."

**Q: What's the batch normalization issue?**
A: "In the PyTorch model, every Conv1D and Linear layer is followed by batch normalization — that's a learnable scale and shift applied to the activation. At training time the network learns to rely on that normalization. In hardware, batch norm can be folded into the preceding layer's weights and biases for inference — it's a linear transformation — but I didn't implement that folding step, which means the hardware is running without the normalization that the network expects. That's the main source of the software-hardware accuracy gap."
