# synth layout

* 16 channels consisting of two operators (oscillator + envelop generator) and one extra envelop generator. Channels can be individually paired up for more complex tones and algorithms (12), at the cost of poliphony (8, if every channel is paired)
* Two LFOs, one for pitch control, one for amplitude.
* 4 outputs. One pair for main stereo out, and two individual mono auxiliary outputs for effect send, etc. Each output has a 12db/o low-pass filter to either remove some of the aliasing artifacts, or to even use them for improvised substractive synthesis

# Operator

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
## operator controllers

Operator control parameters can be set through the Control Change command. However, the original (1.0) MIDI implementation has limited public namespace, with many defaults posing other limitations. So to avoid running out from controls without breaking standards, the unregistered parameter bank is being used to extend the available namespace as well as adding 14 bit precision for many values. Also every value between 0-31 has extended precision (LSB) in the 32-63 region with control numbers shifted by 32. In case of MIDI 2.0, there's enough for everything.

Unregistered parameter bank 0 and 1 belong to operator controls. Numbers in square brackets mean number of unregistered parameter. Curly brackets contain legacy control change numbers if available.

All time values are exponential (y = x¹∙⁸)

* `Level` [0]: Controls the output level of the operator. Exponential (y = x²). {O0: 18 ; O1: 19}
* `Attack` [1]: Controls the attack time of the operator. Range is between 0s to ~3.5s. {O0: 78 ; O1: 73}
* `Decay` [2]: Controls the decay time of the operator. Range is between 0s to ~7s. {O0: 79 ; O1: 74}
* `SusLevel` [3]: Controls the sustain level of the operator. Actual value is affected by ShpR. {O0: 16 ; O1: 17}
* `SusCtrl` [4]: Controls how the sustain phase behaves. 0 sets the envelop generator into percussive mode (no sustain), 1-63 selects a descending curve, 64 selects a continuous output (infinite sustain), 65-127 selects an ascending curve (swell). {O0: 85 ; O1: 86}
* `Release` [5]: Controls the release time of the operator. Range is between 0s to ~7s. {O0: 77 ; O1: 72}
* `Waveform` [6]: Selects which waveform will be used from the 128 shared ones. {O0: 75 ; O1: 70}
* `Feedback` [7]: Controls the feedback of this operator. Exponential (y = x⁴). Up to around half way, it can be used to add timbre to the sound, after that point the signal becomes noisier. {O0: 76 ; O1: 71}
* `TuneCor` [8]: Sets the coarse tuning. By default, it uses a so called "EasyTune" system, allowing the user to select integer multiples of the base note's frequency. Turning it off the operator then can be tuned at this point by whole steps, or precisely if "ContiTune" is enabled. {O0: 87 ; O1: 88}
* `TuneFine` [9]: Sets the fine tuning within a seminote. Disabled with "EasyTune". {O0: 30 ; O1: 31}
* `ShpA` [10]: Sets the envelop-shape for the attack phase between (y = x⁴) and (y =⁴√x) if (0 ≤ x ≤ 1).
* `ShpR` [11]: Sets the envelop-shape for the decay, sustain, and release phase between (y = x⁴) and (y =⁴√x) if (0 ≤ x ≤ 1).
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

* `FBMode` [0]{7}: If set, then feedback bypasses the operator's envelop generator. Channel EG can still be used.
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

`out = wavetable[((step>>21) + (in>>2) + (fb>>3)) & 1023]`

where `wavetable` is a waveform selected from 128 waveforms shared between the operators (both predefined and user-supplied), `step` is the current position of the the oscillator with 21 bits of fraction, `in` is the input from other operators (if any), `fb` is feedback (global feedback also goes there).

For each cycle, increment `step` by `rate`, and let it overflow, generating a continuous cycle.

# Channel

A single channel consists of:

* Two operators, each with its own envelop generator
* An extra, assignable envelop generator

## master controls

### registered parameters

### unregistered parameters

* `MasterVol` [0]:
* `Bal` [1]:
* `AuxSLA` [2]:
* `AuxSLB` [3]:
* `EEGDetune` [4]:
* `PLFO` [5]:
* `Attack` [6]:
* `Decay` [7]:
* `SusLevel` [8]:
* `SusCtrl` [9]:
* `Release` [10]:
* `ShpA` [11]:
* `ShpR` [12]:
* `GlobalFB` [13]:
* `ChCtrl` [16]:
* `EEGToLeft` [18]:
* `EEGToRight` [19]:
* `EEGToAuxA` [20]:
* `EEGToAuxB` [21]:
* `LFOToLeft` [22]:
* `LFOToRight` [23]:
* `LFOToAuxA` [24]:
* `LFOToAuxB` [25]:
* `MWToGFB` [26]:
* `VelToGFB` [27]:

#### channel control flags

* `ComboMode` [0-1]:
* `Algorithm` [2]:
* `IndivOutChLev` [3]:
* `LFOPan` [4]:
* `EEGPan` [5]:
* `MWToTrem` [6]:
* `MWToVibr` [7]:
* `MWToAux` [8]:
* `ResetOnKeyOn` [9]:
* `ResetMode` [10]:
* `FBMode` [11]:
* `FBNeg` [12]:

## channel combination

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

# Global settings

# Setting guidelines

* Small amounts of release times can function as a pop filter.
* Feedback adds tibre up to half way, then it adds various types of noises, some are very cyclic by nature.