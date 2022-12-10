# synth layout

* 16 channels consisting of two operators (oscillator + envelop generator) and one extra envelop generator. Channels can be individually paired up for more complex tones and algorithms (12), at the cost of poliphony (8, if every channel is paired).
* Two LFOs, one for pitch control (vibrato), one for amplitude (tremolo/ring modulation).
* 4 outputs. One pair for main stereo out, and two individual mono auxiliary outputs for effect send, etc. Each output has a 12db/o low-pass filter to either remove some of the aliasing artifacts, or to even use them for improvised substractive synthesis

# Operator

## Theory of operation

This synth uses the Chowning-formula most commonly associated with phase modulation (Digital FM and Phase Distortion) synthesis engines.

Simplified formula of such engines for two operators and sine waveforms is:

y = a₁ * sin(x * n₁ + a₂ * sin(x * n²))                (a = amplitude of the given operator ; n = freqency multiplier)

One can manipulate the waveform of the carrier (1) by manipulating the amplitude and frequency of the modulator (2), thus making the waveform richer in upper harmonics. By using a frequency multiplier of 2 for the modulator, the carrier can be turned into a square wave. 

## Diagram

```
               /|[fbAmp]               
  |-----------<-|-----------------| [fbMode]
  |            \|                  \
  |  |--------------------|         \
  |->|fb    /\            |    o     o
     |     /  \           |    | |\  |
---->|in  -----------  out|----->| >---->
     |          \  /      | [amp]|/   [out_a]
     |           \/       |       |
     |--------------------|       |
        [wavetable osc.]          |
    |------------------|          |
    |      /\___       |          |
    |     /     \      |---->-----|
    |  --------------- |[ADSREnvGen]
    |------------------|
```

## Envelop generators

```
     /\
    /  \
   /    \_______
  /             \
 /               \
/                 \
A    |D  |S     |R
```

All time values are exponential (y = x¹∙⁸ if 0⩽x⩽2), except for the sustain control.

### Envelop shaping

The envelop generator can be shaped with a shaping value, using a fast and inaccurate power of x function. The general formula is `fastpow(x, shp)`, where x is between 0 and 1, and shp is between 0.5 and 3.5, with 2 being the default. There's two shaping values, one for the attack stage, one for the rest, the latter one is also affects the sustain level.

### Attack stage

The attack stage is the initial stage of the envelop generation. When a note-on command is received on MIDI, the channel's envelop generators step into this very first stage, and keeps in it until it reaches the maximum output of the envelop. If the attack value is zero, this will be skipped. The attack stage has its own shaping coefficient.

### Decay stage

The envelop generator steps into the decay stage right after the attack stage. It makes the output value descend from the maximum output value to the sustain level in the set amount of time. If the decay value is zero, this will be skipped and immediately steps to the sustain stage

### Sustain stage

The envelop generator then steps into the sustain phase. Depending on the sustain control value, it'll either keep it's value until a note-off command is received, or will change the output value.

Sustain control value ranges:
* 0: No sustain, percussive mode. The envelop generator will step into the release phase regardless of whether a note-off command was received or not.
* 1-63: The sustain is slowly fading out (4.5s - 70s), thus emulating the behavior of a real-life stringed instrument slowly losing its volume after getting plucked.
* 64: The sustain level is kept as is.
* 65-127: Swell mode. The output level is slowly rising to maximum output (70s - 4.5s).

### Release stage

The envelop generator steps into this stage once a note-off command was received. If the value is zero, the note will immediately fut of, however it is recommended to keep at least a minimum value of 1 or 2 here to remove some of the audible pops when the oscillator stops.

## operator controllers

Operator control parameters can be set through the Control Change command. However, the original (1.0) MIDI implementation has limited public namespace, with many defaults posing other limitations. So to avoid running out from controls without breaking standards, the unregistered parameter bank is being used to extend the available namespace as well as adding 14 bit precision for many values. Also every value between 0-31 has extended precision (LSB) in the 32-63 region with control numbers shifted by 32. In case of MIDI 2.0, there's enough for everything.

Unregistered parameter bank 0 and 1 belong to operator controls. Numbers in square brackets mean number of unregistered parameter. Curly brackets contain legacy control change numbers if available.

* `Level` [0]: Controls the output level of the operator. Exponential (y = x²). {O0: 18 ; O1: 19}
* `Attack` [1]: Controls the attack time of the operator. Range is between 0s to ~3.5s. {O0: 78 ; O1: 73}
* `Decay` [2]: Controls the decay time of the operator. Range is between 0s to ~7s. {O0: 79 ; O1: 74}
* `SusLevel` [3]: Controls the sustain level of the operator. Actual value is affected by ShpR. {O0: 16 ; O1: 17}
* `SusCtrl` [4]: Controls how the sustain phase behaves. 0 sets the envelop generator into percussive mode (no sustain), 1-63 selects a descending curve, 64 selects a continuous output (infinite sustain), 65-127 selects an ascending curve (swell). {O0: 85 ; O1: 86}
* `Release` [5]: Controls the release time of the operator. Range is between 0s to ~7s. {O0: 77 ; O1: 72}
* `Waveform` [6]: Selects which waveform will be used from the 128 shared ones. {O0: 75 ; O1: 70}
* `Feedback` [7]: Controls the feedback of this operator. Exponential (y = ²∙⁵). Up to around half way, it can be used to add timbre to the sound, after that point the signal becomes noisier. {O0: 76 ; O1: 71}
* `TuneCor` [8]: Sets the coarse tuning. By default, it uses a so called "EasyTune" system, allowing the user to select integer multiples of the base note's frequency. Turning it off the operator then can be tuned at this point by whole steps, or precisely if "ContiTune" is enabled. {O0: 87 ; O1: 88}
* `TuneFine` [9]: Sets the fine tuning within a seminote. Disabled with "EasyTune". {O0: 30 ; O1: 31}
* `ShpA` [10]: Sets the envelop-shape for the attack phase between (y = x³∙⁵) and (y = √x) if (0 ≤ x ≤ 1). {O0: 20 ; O1: 22}
* `ShpR` [11]: Sets the envelop-shape for the decay, sustain, and release phase between (y = x³∙⁵) and (y =√x) if (0 ≤ x ≤ 1). {O0: 21 ; O1: 23}
* `VelToLevel` [12]: Sets how much velocity is affecting the output level of the operator.
* `MWToLevel` [13]: Sets how much the MW/Expr is affecting the output level of the operator.
* `LFOToLevel` [14]: Sets how much the amplitude LFO is affecting the output level of the operator.
* `OpCtrl` [15]: Sets the operator control flags at once directly.
* `VelToFB` [16]: Sets how much velocity is affecting the feedback level of the operator.
* `MWToFB` [17]: Sets how much the MW/Expr is affecting the feedback level of the operator.
* `LFOToFB` [18]: Sets how much the amplitude LFO is affecting the feedback level of the operator.
* `EEGToFB` [19]: Sets how much the channel-assignable envelop generator is affecting the feedback level of the operator.
* `VelToShpA` [20]: Sets how much velocity is affecting the attack portion of the EG's output curve.
* `VelToShpR` [21]: Sets how much velocity is affecting the decay, sustain, and release portion of the EG's output curve.
* `KSLBegin` [22]: Selects where the Key Scale Level (KSL) attennuation begins. Many instruments in real life has less timbre, less amplitude, etc as played in higher pitches, this can emulate this behavior.
* `KSLAttenOut` [23]: Sets the amount of attennuation on the output level (up to 6db/oct).
* `KSLAttenFB` [24]: Sets the amount of attennuation on the feedback level (up to 6db/oct).
* `KSLAttenADSR` [25]: Sets the amount of how much shorter the attack and decay phases of the envelop must be (up to 4% per note).

### Operator control flags

Notation: [bit index in parameter settings]{bit index in the operator itself}

* `FBMode` [0]{7}: If set, then feedback bypasses the operator's envelop generator. Channel EG can still be used on feedback.
* `FBNeg` [1]{8}: Inverts the feedback output.
* `MWNeg` [2]{9}: Inverts the modulation wheel.
* `VelNeg` [3]{10}: Inverts the velocity.
* `EGRelAdaptive` [4]{11}: Sets the release to be at a fixed time regardless of sustain level. Otherwise release time might be affected how the sustain changes.
* `FixedPitch` [5]{12}: Sets the operator into fixed pitch mode, thus not being affected by key pitch changes.
* `EasyTune` [6]{13}: Sets the operator into a fixed frequency ratio tune mode. Enabled by default.
* `ContiTune` [7]{14}: Enables the use extra precision for TuneCor, which enables the continuous tuning of the operator from a single data source.
* `ExprToMW` [8]{15}: Replaces MW controls with expression value controls for this operator.

### EasyTune prelimiters

* 0: ×1/8
* 1 - 4: ×1/6
* 5 - 7: ×1/5
* 8 - 12: ×1/4
* 13 - 18: ×1/3
* 19 - 24: ×1/2
* 25 - 42: ×1
* 43 - 47: ×1.5
* 48 - 54: ×2
* 55 - 59: ×3
* 60 - 63: ×4
* 64 - 66: ×5
* 67 - 69: ×6
* 70 - 71: ×7
* 72 - 73: ×8
* 74 - 75: ×9
* 76 - 77: ×10
* 78: ×11
* 79 - 80: ×12
* 81: ×13
* 82: ×14
* 83: ×15
* 84 - 128: ×16

## Formula

The operators use the following formula to generate tone:

`out = wavetable[((step>>22) + (in>>2) + (fb>>3)) & 1023]`

where `wavetable` is a waveform selected from 128 waveforms shared between the operators (both predefined and user-supplied), `step` is the current position of the the oscillator with 22 bits of fraction, `in` is the input from other operators (if any), `fb` is feedback (global feedback also goes there).

For each cycle, increment `step` by `rate`, and let it overflow, generating a continuous cycle.

# Channel

A single channel consists of:

* Two operators, each with its own envelop generator
* An extra, assignable envelop generator

Two channels can be combined, this is explained further in this text.

## master controls

### registered parameters

### unregistered parameters

Numbers in square brackets mean number of unregistered parameter. Curly brackets contain legacy control change numbers if available.

* `MasterVol` [0]: Output volume of the channel, or left channel volume if `IndivOutChLev` is set. {7}
* `Bal` [1]: Balance between left and right channels, or right channel volume if `IndivOutChLev` is set. {8}
* `AuxSLA` [2]: Output level for auxilliary channel A. {91}
* `AuxSLB` [3]: Output level for auxilliary channel B. {92}
* `EEGDetune` [4]: Enables and sets the amount of detune by channel envelop (up to two octaves). {93}
* `PLFO` [5]: Enables and sets the amount of detune by vibrato. {94}
* `Attack` [6]: Sets the attack rate of the channel envelop generator. {102}
* `Decay` [7]: Sets the attack rate of the channel envelop generator. {103}
* `SusLevel` [8]: Sets the attack rate of the channel envelop generator. {104}
* `SusCtrl` [9]:  Controls how the sustain phase behaves. 0 sets the envelop generator into percussive mode (no sustain), 1-63 selects a descending curve, 64 selects a continuous output (infinite sustain), 65-127 selects an ascending curve (swell). {105}
* `Release` [10]: Sets the attack rate of the channel envelop generator. {106}
* `ShpA` [11]: Sets the envelop-shape for the attack phase between (y = x³∙⁵) and (y = √x) if (0 ≤ x ≤ 1). {24}
* `ShpR` [12]: Sets the envelop-shape for the decay, sustain, and release phase between (y = x³∙⁵) and (y = √x) if (0 ≤ x ≤ 1). {25}
* `GlobalFB` [13]: Sets the amount of the channel feedback. {107}
* `ChCtrl` [16]: Sets channel control flags at once.
* `EEGToLeft` [18]: Sets the channel envelop amount for the left channel.
* `EEGToRight` [19]: Sets the channel envelop amount for the right channel.
* `EEGToAuxA` [20]: Sets the channel envelop amount for the Aux A channel.
* `EEGToAuxB` [21]: Sets the channel envelop amount for the Aux B channel.
* `LFOToLeft` [22]: Sets the tremolo amount for the left channel.
* `LFOToRight` [23]: Sets the tremolo amount for the right channel.
* `LFOToAuxA` [24]: Sets the tremolo amount for the Aux A channel.
* `LFOToAuxB` [25]: Sets the tremolo amount for the Aux B channel.
* `MWToGFB` [26]: Sets the MW/Expr amount for the channel feedback.
* `VelToGFB` [27]: Sets the velocity amount for the channel feedback.

#### channel control flags

* `ComboMode` [0-1]: Enables and sets the combination mode for the channel.
* `Algorithm` [2]: Toggles the algorithm of the channel.
* `IndivOutChLev` [3]: Enables the individual control of the left and right channel.
* `LFOPan` [4]: Inverts the tremolo phase for the right channel, enabling panning.
* `EEGPan` [5]: Inverts the channel envelop for the right channel, enabling panning.
* `MWToTrem` [6]: Enables modulation wheel control of the tremolo.
* `MWToVibr` [7]: Enables modulation wheel control of the vibrato.
* `MWToAux` [8]: Enables modulation wheel control of the Aux levels.
* `ResetOnKeyOn` [9]: If set, key-on events will reset the oscillators to a zero position.
* `ResetMode` [10]: If set, reset only occurs if all operator envelops reached the off position.
* `FBMode` [11]: If set, then channel feedback will bypass the source operator's envelop control
* `FBNeg` [12]: If set, then the feedback is inverted.
* `ResMode` [13]: Enables resonant mode on select algorithms.
* `ResSrc` [14]: Toggles the source for the resonant oscillator on algorithm 3/10

## Algorithms and channel combinations

By default, the FM synth has two operators per channel, for 16 channels, with each channel being monophonic.

In this mode, each channel has two algorithms:

```
algorithm 0:
 ┌──────┐
[O0]->[O1]->

algorithm 1:
[O0]->
[O1]->
```

The line that goes from O1 to O0 is the channel feedback. This adds even more timbre to the sound than the per-operator approach.

By combining channels, one can trade poliphony for more complex algorithms:
```
Combination mode 1:

algorithm 00:
 ┌──────────────────┐
[S0]->[S1]->[P0]->[P1]->

algorithm 10:
 ┌─────────────┐
[S0]\          │
     ->[P0]->[P1]->
[S1]/

algorithm 01:
 ┌────────────┐
[S0]->[S1]->[P0]->
            [P1]->

algorithm 11
┌────────┐
[S0]\    │
     ->[P0]->
[S1]/  [P1]->

Combination mode 2:

algorithm 00:
 ┌─────────────┐
[S0]->[S1]\    │
           ->[P1]->
      [P0]/

algorithm 10:
 ┌───────┐
[S0]\    │
[S1]-->[P1]->
[P0]/

algorithm 01:
 ┌───────────┐
 │        /[P0]->
[S0]->[S1]
          \[P1]->

algorithm 11:
 ┌───────┐
[S0]\ /[P0]->
     -
[S1]/ \[P1]->

combination mode 3:

algorithm 00:
 ┌──────┐
[S0]->[S1]->
[P0]->[P1]->

algorithm 10:
      [S0]->
      [S1]->
[P0]->[P1]->
 └──────┘

algorithm 01:
 ┌──────┐
 │  />[S1]->
[S0]->[P0]->
    \>[P1]->

algorithm 11:
[S0]->
[S1]->
[P0]->
[P1]->
```

Later on, there will be some further explanations for the algorithms.

### Note on combinations

Pitch, and output can be set only with the lower half's parameters, either envelop can be set to change output levels if needed. Lower half's envelop can only affect P0 and P1 operators, upper half only affects S0 and S1.

### Resonant mode

The resonant mode can mimic the resonant waveforms of phase distortion synthesis engines, but with greater control over the waveform, and can generate a resonant form of any waveform, including the result of phase modulation synthesis. It is available on M0/1, M1/01, M1/11, M3/10, M3/11, with the last one has an additional ability of selecting between two sources (P1 output or S0 output).

In this mode, the output levels of P1 (or S1 in case of Mode 3) control the amount of resonance output. Since the source is taken from the unattenuated output of the source oscillator, its output does not affect the output levels of the resonant waveform, and can be turned off completely if the original waveform is not wanted in the audio output.

# Global settings

The synth shares two LFOs (tremolo and vibrato) and four filters between channels. MSB 16 selects global parameters on any channel.

`PLFORate` [0]: Sets the frequency of the vibrato (0-16Hz).
`PLFOWF` [1]: Selects a waveform for the vibrato.
`ALFORate` [2]: Sets the frequency of the tremolo (0-16Hz, or a MIDI note if changed to ring modulation).
`ALFOWF` [3]: Selects a waveform for the tremolo.
`FilterLCFreq` [4]: Sets the filter frequency for the left channel (0-20 000Hz).
`FilterLCQ` [5]: Sets the filter resonance for the left channel.
`FilterRCFreq` [6]: Sets the filter frequency for the right channel (0-20 000Hz).
`FilterRCQ` [7]: Sets the filter resonance for the right channel.
`FilterACFreq` [8]: Sets the filter frequency for the Aux A channel (0-20 000Hz).
`FilterACQ` [9]: Sets the filter resonance for the Aux A channel.
`FilterBCFreq` [10]: Sets the filter frequency for the Aux B channel (0-20 000Hz).
`FilterBCQ` [11]: Sets the filter resonance for the Aux B channel.
`HPFLFreq` [12]: Sets the high-pass filter frequency for the left channel (0-20 000Hz)
`HPFRFreq` [13]: Sets the high-pass filter frequency for the right channel (0-20 000Hz)
`HPFAFreq` [14]: Sets the high-pass filter frequency for the Aux A channel (0-20 000Hz)
`HPFBFreq` [15]: Sets the high-pass filter frequency for the Aux B channel (0-20 000Hz)
`Ringmod` [16]: Enables ring modulation, by setting the tremolo frequency into audible territory and bypassing the aliasing filter.

# Setting guidelines

* Small amounts of release times can function as a pop filter.
* Feedback control works in conjunction with the output level in many cases, unless the envelop generator is bypassed.
* Some overtones will naturally occur due to the lack of an aliasing filter and using a nearest interpolation. This must be taken into account when designing sounds, some of it can be filtered out.
* There used to be some nasty artifacting at every A note when high amounts of feedback was applied to oscillators. This seems to have been fixed by introducing an inaudible tuning error, but I cannot guarantee it won't reappear with pitch-bends or whatever.

## General differences from other phase modulation-based synthesis engines

* Use of linear sinewaves. Some chips, like the OPL-series instead used a prelogarithmized sine wave in ROM, alongside with an exponential table, to avoid the use of multipliers. Meaning that the OPL series can get pretty close to other FM chips, and the main limitations come from the lack of a more-adjustable sustain curve and lack of algorithms, it's not a mig deal.
* Use of both user- and pre-defined wavetables.
* All operators have feedback capabilities, for both to have more tonal capabilities and to ease the confusions around algorithms where the main difference is different operators having the feedback loop.
* Almost all algorithms have one "channel feedback" instead of often having to choose between a single operator or channel feedback.
* Its resonant-mode can mimic the resonant waveforms of phase distortion synthesis engines, but without the 8 stage envelop for output level control, but might has more control in other aspects.