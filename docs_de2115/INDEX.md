# ECG Simulation Component - Documentation Index
## DE2-115 Two-Board System - Quick Navigation Guide

**Last Updated**: November 28, 2025  
**Version**: 2.0 (DE2-115 + Audio Interface)  
**Status**: Complete & Ready

---

## 📖 HOW TO USE THIS DOCUMENTATION

### For Mid-Term Presentation (COE 70A) - **THIS WEEK**

**Start Here**: 
1. 📊 **[presentation_slides.md](presentation_slides.md)** - Your 6 slides (10 min presentation)
   - Read completely (30-40 min)
   - Focus on Slide 4: Design Choices (50% of grade!)
   - Study Q&A section at end
   - Practice explaining audio interface decision

**Then**:
2. 📋 **[CHANGES_SUMMARY.md](CHANGES_SUMMARY.md)** - Quick comparison with original
   - Understand what changed and why (10 min)
   - Memorize key talking points
   - Review "Questions Likely to Arise"

**Reference During Prep**:
3. 🏗️ **[system_architecture.md](system_architecture.md)** - Block diagrams
   - Use for visual aids
   - Print two-board diagram (Slide 3)
   - Study data flow

**If Professor Asks Details**:
4. 📚 **[technical_reference.md](technical_reference.md)** - Complete specs
   - Quick reference for numbers
   - Audio protocol details
   - Pin assignments

---

### For Implementation (COE 70B) - **NEXT TERM**

**Your Bible**:
1. 🗺️ **[implementation_roadmap.md](implementation_roadmap.md)** - Week-by-week plan
   - Follow week-by-week (start Week 1, Day 1)
   - Check off tasks as you complete them
   - Use weekly checkpoint format
   - Refer to risk mitigation sections when stuck

**Constant Reference**:
2. 📚 **[technical_reference.md](technical_reference.md)** - All specifications
   - VGA timing values
   - I2S/I2C protocols
   - DE2-115 pin assignments
   - Code examples and patterns

**Architecture Reference**:
3. 🏗️ **[system_architecture.md](system_architecture.md)** - Module specs
   - Module port lists
   - Interface definitions
   - Timing diagrams
   - Resource estimates

**Project Overview**:
4. 📖 **[README.md](README.md)** - High-level summary
   - Quick specs lookup
   - Module list
   - Timeline
   - Success criteria

---

## 📂 DOCUMENT DESCRIPTIONS

### 1. README.md
**Purpose**: Project overview and navigation  
**Length**: ~500 lines  
**Read Time**: 15 minutes  
**When to Use**: First time orientation, quick reference

**Contains**:
- Project summary (two-board concept)
- What your component does
- Key specifications (hardware, data, audio, VGA)
- Module architecture (12 modules)
- Timeline (COE 70A + 70B)
- Design highlights
- Success criteria
- Resources & tools
- Team integration
- Quick-start guides

**Best For**: Getting oriented, explaining project to others

---

### 2. technical_reference.md
**Purpose**: Complete technical knowledge base  
**Length**: ~600 lines  
**Read Time**: 45 minutes (full read), 2 min (lookups)  
**When to Use**: During implementation, when you need exact specs

**Contains**:
- VGA specifications (640×480 @ 60Hz timings)
- ECG signal characteristics (MIT-BIH dataset)
- DE2-115 FPGA specs (Cyclone IV details)
- Sample rate generation (360 Hz math)
- **Audio interface specs** (WM8731, I2S, I2C) ⭐
- Memory initialization (M9K, .mif format)
- Pin constraints (QSF format)
- Testing strategies
- Design decisions rationale

**Best For**: Looking up exact values, understanding protocols, implementation reference

---

### 3. system_architecture.md
**Purpose**: Detailed design specifications  
**Length**: ~500 lines  
**Read Time**: 30 minutes  
**When to Use**: Architecture review, coding modules, understanding system

**Contains**:
- **Two-board system overview** ⭐
- Detailed Board 1 architecture (DE2-115)
- Data flow diagrams (updated for audio)
- Timing diagrams (3 clock domains)
- Module hierarchy (all 12 modules)
- Module specifications (port lists, functionality)
- Resource estimation (5% logic, 1.5% RAM)
- Integration checklists
- Critical timing paths

**Best For**: Understanding overall system, designing modules, integration planning

---

### 4. presentation_slides.md
**Purpose**: 6 slides for mid-term oral exam  
**Length**: ~700 lines  
**Read Time**: 40 minutes  
**When to Use**: Presentation prep, Q&A practice

**Contains**:
- **Slide 1**: Problem definition (two-board concept)
- **Slide 2**: Requirements & specs
- **Slide 3**: System architecture (diagrams)
- **Slide 4**: Design choices ⭐ (50% of grade - audio focus!)
- **Slide 5**: Technical challenges & solutions
- **Slide 6**: COE 70B implementation plan
- Presentation notes & timing
- **Q&A preparation** (comprehensive!)

**Best For**: Presentation practice, answering professor's questions

---

### 5. implementation_roadmap.md
**Purpose**: Week-by-week implementation guide  
**Length**: ~900 lines  
**Read Time**: 60 minutes (full), 5 min (weekly sections)  
**When to Use**: Throughout COE 70B, every single week

**Contains**:
- 8-week detailed timeline
- Daily task breakdowns
- **Week 1-2**: PLL + I2C + codec init
- **Week 3**: I2S transmitter + test tone
- **Week 4**: ECG upsampling + audio output ⭐
- **Week 5**: VGA timing + test pattern
- **Week 6**: VGA rendering + simultaneous operation
- **Week 7**: User interface + LED enhancements
- **Week 8**: Two-board integration + demo ⭐
- Risk mitigation strategies (per risk)
- Weekly checkpoint format
- Deliverables checklist
- Success criteria

**Best For**: Execution phase, tracking progress, staying on schedule

---

### 6. CHANGES_SUMMARY.md
**Purpose**: Quick comparison with original design  
**Length**: ~400 lines  
**Read Time**: 20 minutes  
**When to Use**: Understanding what changed, presentation prep

**Contains**:
- One-sentence summary of changes
- Side-by-side comparison table
- Key changes breakdown (5 major changes)
- Resource impact analysis
- Educational value comparison
- Timeline impact
- New tools & equipment needed
- Signal specification changes
- Risk assessment changes
- Demo flow differences
- Migration guide

**Best For**: Explaining changes to team/professor, justifying decisions

---

## 🎯 RECOMMENDED READING ORDER

### First Time (Getting Oriented)
1. **README.md** (15 min) - Overview
2. **CHANGES_SUMMARY.md** (20 min) - What changed
3. **presentation_slides.md** (40 min) - Your presentation
4. **system_architecture.md** (30 min) - How it works

**Total**: ~2 hours for complete understanding

### For Mid-Term Prep (This Week)
1. **presentation_slides.md** (40 min) - Read fully
2. **CHANGES_SUMMARY.md** (20 min) - Key talking points
3. **system_architecture.md** (Slide 3 block diagrams) (10 min)
4. **Practice presentation** (2-3 hours)

**Total**: ~4 hours prep time

### For Implementation (Next Term)
1. **implementation_roadmap.md** - Week 1 section (Day 1)
2. **technical_reference.md** - Relevant sections as needed
3. **system_architecture.md** - Module details when coding
4. **Repeat weekly** - Follow roadmap progression

---

## 🔍 QUICK REFERENCE LOOKUPS

### Need a Specific Number?

| What You Need | Where to Find It |
|---------------|------------------|
| VGA timings (H/V sync, porches) | `technical_reference.md` §1 |
| Sample rate calculation (360 Hz) | `technical_reference.md` §4 |
| DE2-115 resource availability | `technical_reference.md` §3 |
| Audio sample rate (48 kHz) | `technical_reference.md` §7 |
| Upsampling ratio (133x) | `technical_reference.md` §7 |
| Pin assignments (QSF) | `technical_reference.md` §10 |
| Resource estimates | `system_architecture.md` §6 |
| Module port lists | `system_architecture.md` §5 |
| I2S timing | `technical_reference.md` §7 |
| I2C protocol | `technical_reference.md` §7 |

### Need a Specific Diagram?

| Diagram Type | Document | Section |
|--------------|----------|---------|
| Two-board overview | `system_architecture.md` | §1 |
| Board 1 detailed | `system_architecture.md` | §2 |
| Data flow | `system_architecture.md` | §3 |
| Timing diagram | `system_architecture.md` | §4 |
| Module hierarchy | `README.md` | Module Architecture |
| Clock domains | `system_architecture.md` | §4 |

### Need Implementation Help?

| Task | Document | Section |
|------|----------|---------|
| PLL configuration | `implementation_roadmap.md` | Week 1 |
| I2C master | `implementation_roadmap.md` | Week 2 |
| I2S transmitter | `implementation_roadmap.md` | Week 3 |
| Audio upsampling | `implementation_roadmap.md` | Week 4 |
| VGA timing | `implementation_roadmap.md` | Week 5 |
| VGA rendering | `implementation_roadmap.md` | Week 6 |
| User interface | `implementation_roadmap.md` | Week 7 |
| Two-board integration | `implementation_roadmap.md` | Week 8 |

---

## 📊 DOCUMENT STATISTICS

### File Sizes & Complexity

| Document | Lines | Words | Topics | Difficulty |
|----------|-------|-------|--------|------------|
| README.md | ~500 | ~3,500 | 15 | Medium |
| technical_reference.md | ~600 | ~4,500 | 15 | High |
| system_architecture.md | ~500 | ~3,500 | 10 | High |
| presentation_slides.md | ~700 | ~5,000 | 6 | Medium |
| implementation_roadmap.md | ~900 | ~7,000 | 8 | Medium |
| CHANGES_SUMMARY.md | ~400 | ~3,000 | 12 | Low |
| INDEX.md | ~300 | ~2,000 | - | Low |

**Total Documentation**: ~3,900 lines, ~28,500 words

---

## 🎓 LEARNING PATH

### Recommended Study Sequence

#### Phase 1: Understanding (This Week - Before Mid-Term)
1. Read **README.md** - Get big picture
2. Read **CHANGES_SUMMARY.md** - Understand what changed
3. Study **presentation_slides.md** - Prepare to present
4. Review **system_architecture.md** §1-3 - Visualize system

**Goal**: Can explain two-board architecture and defend audio interface choice

#### Phase 2: Deep Dive (Winter Break - Optional)
1. Read **technical_reference.md** §7 - Audio protocols (I2S, I2C)
2. Study WM8731 datasheet (external resource)
3. Review Altera audio examples (external resource)
4. Practice I2C simulation (using testbench)

**Goal**: Comfortable with audio codec concepts before implementation

#### Phase 3: Execution (COE 70B - 8 Weeks)
1. Follow **implementation_roadmap.md** week-by-week
2. Reference **technical_reference.md** for specs
3. Reference **system_architecture.md** for module details
4. Update weekly checkpoints in roadmap

**Goal**: Complete working system by Week 8

---

## 🆘 TROUBLESHOOTING GUIDE

### "I'm Lost - Where Do I Start?"
→ Read **README.md** first (15 minutes)

### "I Need to Present in 2 Days!"
→ Study **presentation_slides.md** + practice (4 hours)

### "Professor Asked Technical Question I Can't Answer"
→ Check **technical_reference.md** for exact specs

### "I Don't Understand the Audio Interface"
→ Read **CHANGES_SUMMARY.md** §2 (Inter-Board Connection)

### "I Don't Know What Module to Build First"
→ Follow **implementation_roadmap.md** Week 1, Day 1

### "I'm Stuck on Audio Codec"
→ **implementation_roadmap.md** Week 2 + **technical_reference.md** §7

### "VGA Not Working"
→ **implementation_roadmap.md** Week 5 + **technical_reference.md** §1

### "Two Boards Won't Connect"
→ **implementation_roadmap.md** Week 8 + risk mitigation

---

## 📁 FILE TREE

```
docs_de2115/                           ← USE THIS FOLDER!
├── INDEX.md                           ← This file (you are here)
├── README.md                          ← Start here for overview
├── CHANGES_SUMMARY.md                 ← What changed from original
├── technical_reference.md             ← All technical specs
├── system_architecture.md             ← Design & modules
├── presentation_slides.md             ← 6 slides for mid-term
└── implementation_roadmap.md          ← Week-by-week plan

docs/                                  ← Original docs (reference only)
├── technical_reference.md             ← Spartan-3E version
├── system_architecture.md             ← Single-board version
├── presentation_slides.md             ← Original slides
├── implementation_roadmap.md          ← Original plan
└── README.md                          ← Original overview

Root:
├── GK02-Hardware Implementation....pdf   ← Project manual
├── Oral Exam Presentation (1).pdf       ← Team's current progress
└── README.md                             ← Old (superseded by docs_de2115/)
```

**USE `docs_de2115/` FOR ALL CURRENT WORK!**

---

## 🎯 TASK-BASED NAVIGATION

### "I need to..."

| Task | Go To | Section |
|------|-------|---------|
| **Understand the project** | README.md | Project Summary |
| **Prepare presentation** | presentation_slides.md | All 6 slides |
| **Answer design questions** | presentation_slides.md | Q&A Preparation |
| **Explain audio choice** | CHANGES_SUMMARY.md | §2 (Audio vs GPIO) |
| **Find VGA timings** | technical_reference.md | §1 |
| **Configure WM8731** | technical_reference.md | §7 |
| **See block diagram** | system_architecture.md | §1, §2 |
| **Build Week 1** | implementation_roadmap.md | Week 1 |
| **Build audio modules** | implementation_roadmap.md | Week 1-4 |
| **Integrate two boards** | implementation_roadmap.md | Week 8 |
| **Check my progress** | implementation_roadmap.md | Weekly Checkpoint |
| **Handle audio failure** | implementation_roadmap.md | Risk Mitigation §2 |
| **Get exact pin names** | technical_reference.md | §10 |
| **Size my resources** | system_architecture.md | §6 |

---

## 🏆 SUCCESS CHECKLIST

### Mid-Term Presentation (COE 70A)
- [ ] Read all presentation slides
- [ ] Understand two-board architecture
- [ ] Can explain audio interface decision (2 min)
- [ ] Can defend against "why not GPIO?" question
- [ ] Know resource usage (~5% logic, ~1.5% RAM)
- [ ] Know timeline (8 weeks, Weeks 1-4 audio focus)
- [ ] Know risks & mitigations
- [ ] Practiced presentation (10 min)

### Implementation Start (COE 70B Week 1)
- [ ] Quartus Prime installed
- [ ] DE2-115 board access secured
- [ ] Read implementation_roadmap.md Week 1
- [ ] Ready to create PLL
- [ ] Ready to implement I2C master
- [ ] Lab equipment reserved (oscilloscope!)

### Implementation End (COE 70B Week 8)
- [ ] All 12 modules implemented
- [ ] VGA displays ECG waveform
- [ ] Audio outputs ECG via 3.5mm
- [ ] Two boards connected and working
- [ ] CNN can classify all 3 waveforms
- [ ] Demo rehearsed and ready

---

## 📱 QUICK FACTS CHEAT SHEET

### Board Specs
- **Board 1**: DE2-115 (Cyclone IV, 114K LEs, 4 Mbits RAM)
- **Board 2**: Spartan-3E (10K cells, 360 Kbits RAM) - Team's CNN
- **Connection**: 3.5mm stereo audio cable

### Sample Specs
- **Rate**: 360 Hz (original ECG)
- **Format**: 12-bit signed integer
- **Waveforms**: 3 types (Normal, PVC, AFib), 360 samples each

### Audio Specs
- **Codec**: WM8731 (built-in on DE2-115)
- **Sample Rate**: 48 kHz I2S
- **Upsampling**: 133x (hold-and-repeat)
- **Protocols**: I2S (audio data), I2C (codec config)

### Display Specs
- **Resolution**: 640×480 @ 60 Hz
- **Color**: 10-bit RGB (4-4-4)
- **Rendering**: Scrolling waveform (1 sample/pixel)

### Clocks
- **50 MHz**: System (from oscillator)
- **48 MHz**: Audio (from PLL)
- **25 MHz**: VGA (from PLL)

### Modules
- **Total**: 12 modules
- **New (audio)**: 5 modules (I2C, I2S, upsampler, config, controller)
- **Core**: 7 modules (adapted from original)

### Resources
- **Logic**: ~6K / 114K = 5%
- **RAM**: 5-7 / 432 blocks = 1.5%
- **PLLs**: 1 / 4 = 25%
- **Pins**: ~35 / 528 = 7%

---

## 🎯 CRITICAL DEADLINES

### COE 70A
- **This Week**: Mid-term presentation (10 min)
- **Focus**: Slide 4 (design choices) - 50% of grade
- **Must**: Defend audio interface decision

### COE 70B
- **Week 4**: Audio output working (oscilloscope verification)
- **Week 6**: VGA + Audio simultaneous
- **Week 8**: Two-board demo ready

---

## 💬 GETTING HELP

### When Stuck During Presentation Prep
1. Check **presentation_slides.md** Q&A section
2. Review **CHANGES_SUMMARY.md** talking points
3. Re-read **system_architecture.md** §1 (two-board overview)

### When Stuck During Implementation
1. Check **implementation_roadmap.md** risk mitigation
2. Review **technical_reference.md** for specs
3. Check **system_architecture.md** for module details
4. Ask team (Ayoub for CNN integration)
5. Check Altera forums/examples

---

## 📦 WHAT'S NOT IN THESE DOCS

### You'll Need to Get Separately
- **WM8731 Datasheet** (Google: "WM8731 datasheet PDF")
- **I2S Specification** (Google: "I2S bus specification Philips")
- **I2C Specification** (Google: "I2C specification NXP")
- **DE2-115 User Manual** (Terasic website)
- **Altera Audio Examples** (University Program CD-ROM or website)
- **MIT-BIH ECG Data** (PhysioNet.org or Kaggle)
- **Quartus Tutorial** (Intel FPGA University Program)

---

## ✅ DOCUMENT COMPLETENESS CHECK

| Document | Technical Content | Diagrams | Code Examples | Complete? |
|----------|------------------|----------|---------------|-----------|
| README.md | ✓ | ✓ | Minimal | ✅ Yes |
| technical_reference.md | ✓✓✓ | ✓ | ✓✓✓ | ✅ Yes |
| system_architecture.md | ✓✓✓ | ✓✓✓ | ✓✓ | ✅ Yes |
| presentation_slides.md | ✓✓ | ✓✓✓ | ✓ | ✅ Yes |
| implementation_roadmap.md | ✓✓ | ✓ | ✓✓ | ✅ Yes |
| CHANGES_SUMMARY.md | ✓✓ | ✓ | ✓ | ✅ Yes |

**Status**: All documentation complete and ready to use! ✅

---

## 🚀 NEXT STEPS

### Immediate (Today)
1. ✅ Documentation complete (you're reading it!)
2. ⏭️ **Next**: Read presentation_slides.md
3. ⏭️ **Then**: Practice 10-minute presentation
4. ⏭️ **Finally**: Review Q&A preparation

### This Week (Before Mid-Term)
- Study presentation thoroughly
- Practice explaining audio interface
- Memorize key specs (5% resources, 48 kHz audio, 133x upsampling)
- Prepare for design choice questions

### Next Term (COE 70B)
- Start implementation_roadmap.md Week 1
- Build modules incrementally
- Test continuously
- Integrate with CNN board Week 8

---

**Happy Building! 🎉**

**Document Version**: 1.0  
**Created**: November 28, 2025  
**Purpose**: Navigation & Quick Reference  
**Status**: Complete
