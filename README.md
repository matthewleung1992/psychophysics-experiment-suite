# Psychophysics Experiment Suite

Real-time behavioral experiment control system for visual perception studies. Features millisecond-precision stimulus timing, eye-tracking integration, and automated behavioral monitoring.

## Overview

MATLAB-based experiment control and analysis system developed for behavioral neuroscience research at RIKEN Center for Brain Science. Integrates real-time stimulus presentation, eye-tracking, and electrophysiology recording with automated behavioral control and signal preprocessing pipelines.

## Features

- **Precision Timing**: Millisecond-accurate stimulus presentation using PsychToolbox
- **Eye-Tracking Integration**: Real-time fixation monitoring with configurable detection windows
- **Flexible Grid System**: Configurable spatial layouts (4×4, 6×6, or 8×8 grids)
- **Automated Behavioral Control**: Fixation-contingent stimulus delivery with reward systems
- **Comprehensive Logging**: Trial-by-trial event recording with CSV export
- **Dummy Mode**: Mouse-based simulation for development/testing without hardware

## System Architecture

### Stimulus Presentation Pipeline

1. **Fixation Detection**: Monitors eye position within configurable spatial window (50×50px default)
2. **Contingent Triggering**: Delivers peripheral flash stimuli upon successful fixation (500ms threshold)
3. **Reward Delivery**: Automated reinforcement for trial completion above success threshold (70% default)
4. **Trial Logging**: Records all events with microsecond timestamps

### Key Parameters
```matlab
GRID_SIZE = 4;              % Spatial grid resolution (4, 6, or 8)
TRIAL_DURATION = 10;        % Trial length in seconds
FLASH_DURATION = 20;        % Stimulus duration (ms)
FIXATION_THRESHOLD = 500;   % Required fixation duration (ms)
GAZE_WINDOW = 50;           % Fixation tolerance (pixels)
SUCCESS_THRESHOLD = 0.7;    % Completion criterion (70%)
```

## Requirements
```matlab
MATLAB R2018b or later
Psychtoolbox-3
Eyelink Toolbox (for eye-tracking)
```

**Install Psychtoolbox:**
```matlab
% In MATLAB:
DownloadPsychtoolbox
```

## Usage

### Basic Execution
```matlab
% Run main experiment:
monkey_stimuli_presentation()
```

### Configuration

Edit hardcoded parameters at top of script (lines 8-27):
- Grid layout and stimulus properties
- Timing parameters
- Eye-tracking thresholds
- Behavioral criteria

### Dummy Mode (Development)
```matlab
DUMMY_MODE = 1;  % Mouse simulation (no eye-tracker required)
```

Use keyboard controls for testing:
- **A** = Left fixation point
- **S** = Center fixation point
- **D** = Right fixation point
- **ESC** = Terminate (3× to exit completely)

## Output

Trial logs saved as CSV files:
```
trial_log_001_20231018_143022.csv
```

## Signal Analysis Pipeline

Companion analysis tools for preprocessing neural recordings captured during experiments.

### Preprocessing Features

- **Band-pass filtering**: Low-pass and notch filters for artifact removal
- **FieldTrip integration**: Uses FieldTrip toolbox data structures
- **Multi-channel processing**: Handles 16+ electrode channels simultaneously
- **Time alignment**: Synchronizes neural data with behavioral events

### Data Structure
```matlab
Data_ThisRun.trial{1}     % Raw amplifier data (channels × samples)
Data_ThisRun.time{1}      % Sample timestamps
Data_ThisRun.label        % Channel names from amplifier config
Data_ThisRun.fsample      % Sampling frequency
```

### Typical Workflow

1. **Stimulus presentation**: `monkey_stimuli_presentation.m` logs behavioral events
2. **Neural recording**: Simultaneous electrophysiology data acquisition
3. **Preprocessing**: Filter and artifact rejection using FieldTrip
4. **Event alignment**: Sync neural signals to stimulus/fixation timestamps
5. **Analysis**: Trial-averaged responses, spectral analysis, etc.

### Requirements (Analysis)
```matlab
FieldTrip toolbox (http://www.fieldtriptoolbox.org/)
MATLAB Signal Processing Toolbox
```

**Install FieldTrip:**
```matlab
% Download from http://www.fieldtriptoolbox.org/download/
addpath('/path/to/fieldtrip');
ft_defaults
```

**Log Structure:**
- **CONFIG**: Experimental parameters
- **TRIAL_INFO**: Performance metrics
- **EVENTS**: Timestamped event log (fixations, flashes, rewards)

**Example Event Log:**
```csv
EVENTS
timestamp,event,details
1697625622.450,fixation_started,at TC
1697625622.951,fixation_successful,TC->R2C3
1697625622.952,flash_started,at R2C3
1697625622.972,flash_ended,at R2C3
```

## Experimental Design

**Fixation-Contingent Paradigm:**
- Subject fixates on designated point (TL/TC/TR)
- Upon successful fixation (duration + stability criteria), peripheral stimulus appears
- Flash presented in predetermined grid cell
- Trial success based on completion percentage
- Reward delivered for successful trials

**Spatial Configuration:**
- **TC (Center)**: Triggers all grid cells
- **TL (Left)**: Triggers opposite (rightmost) columns
- **TR (Right)**: Triggers opposite (leftmost) columns

## Technical Implementation

### Eye-Tracking Integration
```matlab
function [gazeX, gazeY, gazeValid] = getGazePosition(window, dummymode)
```

- Interfaces with Eyelink eye-tracker (SR Research)
- Real-time gaze position sampling
- Configurable fixation windows and stability criteria
- Fallback to mouse simulation for development

### Timing Precision

- PsychToolbox VBL-synced flips for frame-accurate presentation
- Sub-millisecond event logging using `GetSecs()`
- Controlled inter-stimulus intervals (cooldown periods)

### Data Management

- Trial-by-trial CSV export
- Hierarchical event logging (config → trial → events)
- Automatic file naming with timestamps
- Checkpoint saves during blank periods

## Performance

**Timing Accuracy:**
- Stimulus onset: ±1 frame (≈8ms at 120Hz)
- Eye-tracking sampling: 1000Hz (Eyelink default)
- Event logging precision: Sub-millisecond

**Tested Configuration:**
- 4×4 to 8×8 grid layouts
- 10-second trials with 2-second inter-trial intervals
- Multi-hour continuous operation
- 99.9% uptime with automated logging

## Use Cases

Originally developed for:
- Peripheral vision perception studies
- Attention and fixation behavior analysis
- Visual stimulus-response mapping
- Neural correlates of visual attention
- **Electrophysiology signal analysis (LFP/spike data)**

Applicable to:
- Psychophysics experiments
- Behavioral training paradigms
- Eye-tracking research
- Real-time stimulus control systems

## Hardware Setup (Production)

**Required:**
- Stimulus display with 120Hz+ refresh
- Eyelink eye-tracker with 500Hz+ sampling
- Behavioral control system (reward delivery)

**Optional:**
- Neural recording system (integration via TTL triggers)
- Response input device (button box, joystick)

## Disclaimer

This code is provided for educational and portfolio purposes. Hardware-specific configurations have been sanitized. Not intended for direct clinical or research deployment without proper validation and IRB approval.

---

## Troubleshooting

**Issue: "Eyelink not found"**
- Check `DUMMY_MODE = 1` for mouse simulation
- Verify Eyelink Toolbox installation
- Confirm eye-tracker IP address configuration

**Issue: Timing drift**
- Disable vertical sync checks: `Screen('Preference', 'SkipSyncTests', 0)`
- Check system load (close other applications)
- Verify display refresh rate (120Hz recommended)

**Issue: Fixation not detected**
- Adjust `GAZE_WINDOW` (larger = more lenient)
- Check eye-tracker calibration quality
- Verify gaze data validity in debug mode (`DEBUG_MODE = 1`)

---

*MATLAB R2020b | Psychtoolbox-3.0.19 | Eyelink 1000 Plus*
